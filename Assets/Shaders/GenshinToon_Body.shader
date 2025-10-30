Shader "GenshinToon/Body"
{
    Properties //public 成员变量
    {
        [Header(Textures)]
        //基础纹理
        _BaseMap ("Base Map", 2D) = "white"{} 
        //光照贴图
        _LightMap ("Light Map", 2D) = "white"{}
        //环境光遮蔽开关
        [Toggle(_USE_LIGHTMAP_AO)] _UseLightMapAO ("Use LightMap AO",Range(0,1)) = 1
        

        [Header(Ramp Shadow)]
        //色阶阴影贴图
        _RampTex ("Ramp Tex", 2D) = "white"{}
        //色阶阴影开关
        _ShadowRampWidth ("Shadow Ramp width", Float) = 1
        _ShadowPosition ("Shadow Position", Float) = 0.55
        _ShadowSoftness ("Shadow Softness", Float) = 0.5
        [Toggle(_USE_RAMP_SHADOW)] _UseRampShadow ("Use Ramp Shadow",Range(0,1)) = 1
        [Toggle] _UseRampShadow2 ("Use Ramp Shadow2",Range(0,1)) = 1
        [Toggle] _UseRampShadow3 ("Use Ramp Shadow3",Range(0,1)) = 1
        [Toggle] _UseRampShadow4 ("Use Ramp Shadow4",Range(0,1)) = 1
        [Toggle] _UseRampShadow5 ("Use Ramp Shadow5",Range(0,1)) = 1

        [Header(Lighting Options)]
        _DayOrNight ("Day Or Night", Range(0, 1)) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType" = "Opaque"
        }

        HLSLINCLUDE //公共代码块开始
            //预处理指令、头文件、常量定义、函数定义
            #pragma multi_compile _MAIN_LIGHT_SHADOWS //主光源阴影
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE //主光源阴影级联
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN //主光源阴影屏幕空间

            #pragma multi_compile_fragment _LIGHT_LAYERS //光照层
            #pragma multi_compile_fragment _LIGHT_COOKIES //光照饼干
            #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION //屏幕空间遮挡
            #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS //额外光源阴影
            #pragma multi_compile_fragment _SHADOWS_SOFT //阴影软化
            #pragma multi_compile_fragment _REFLECTION_PROBE_BOX_PROJECTION //反射探针盒投影

            #pragma shader_feature_local _USE_LIGHTMAP_AO
            #pragma shader_feature_local _USE_RAMP_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" //核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" //光照库
        
            CBUFFER_START(UnityPerMaterial)
                //基础纹理
                sampler2D _BaseMap;
                //光照贴图
                sampler2D _LightMap;

                //ramp
                sampler2D _RampTex;
                float _ShadowRampWidth;
                float _ShadowPosition;
                float _ShadowSoftness;

                float _UseRampShadow2;
                float _UseRampShadow3;
                float _UseRampShadow4;
                float _UseRampShadow5;

                //light options
                float _DayOrNight;

            CBUFFER_END

            // 官方版本的RampShadowID函数
            float RampShadowID(float input, float useShadow2, float useShadow3, float useShadow4, float useShadow5, 
                float shadowValue1, float shadowValue2, float shadowValue3, float shadowValue4, float shadowValue5)
            {
                // 根据input值将模型分为5个区域，只会有一个为1
                float v1 = step(0.6, input) * step(input, 0.8); // 0.6-0.8区域
                float v2 = step(0.4, input) * step(input, 0.6); // 0.4-0.6区域
                float v3 = step(0.2, input) * step(input, 0.4); // 0.2-0.4区域
                float v4 = step(input, 0.2);                    // 0-0.2区域

                // 根据开关控制是否使用不同材质的值
                float blend12 = lerp(shadowValue1, shadowValue2, useShadow2);
                float blend13 = lerp(shadowValue1, shadowValue3, useShadow3);
                float blend14 = lerp(shadowValue1, shadowValue4, useShadow4);
                float blend15 = lerp(shadowValue1, shadowValue5, useShadow5);

                // 根据区域选择对应的材质值
                float result = blend12;                // 默认使用材质1或2
                result = lerp(result, blend15, v1);    // 0.6-0.8区域使用材质5
                result = lerp(result, blend13, v2);    // 0.4-0.6区域使用材质3
                result = lerp(result, blend14, v3);    // 0.2-0.4区域使用材质4
                result = lerp(result, shadowValue1, v4); // 0-0.2区域使用材质1

                return result;
            }
        
        ENDHLSL //公共代码块结束

        Pass //渲染通道
        {
            Name "UniversalForward"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM //shader program
                //声明两种shader
                #pragma vertex MainVertexShader
                #pragma fragment MainFragmentShader

                //顶点着色器输入参数
                struct Attributes
                {
                    //本地空间顶点坐标
                    float4 positionObjectSpace : POSITION;
                    //第一套纹理坐标
                    float2 uv0 : TEXCOORD0;
                    //本地坐标法线
                    float3 normalOS : NORMAL;
                    //顶点颜色
                    float4 color : COLOR0;
                };

                //片元着色器输入参数，由顶点着色器传递
                struct Varyings
                {
                    //裁剪空间顶点坐标
                    float4 positionCS : SV_POSITION;
                    //第一套纹理坐标
                    float2 uv0 : TEXCOORD0;
                    //世界空间的法线
                    float3 normalWS : TEXCOORD1;
                    //顶点颜色
                    float4 color : TEXCOORD2;
                };

                Varyings MainVertexShader(Attributes input)
                {
                    Varyings output;
                    //转换顶点空间
                    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionObjectSpace.xyz);
                    //裁剪空间的顶点坐标
                    output.positionCS = vertexInput.positionCS;

                    //转换法线空间
                    VertexNormalInputs vertexNormalInputs = GetVertexNormalInputs(input.normalOS);
                    output.normalWS = vertexNormalInputs.normalWS;

                    //纹理坐标
                    output.uv0 = input.uv0;

                    output.color = input.color;

                    return output;
                }

                half4 MainFragmentShader(Varyings input) : SV_TARGET
                {
                    Light light = GetMainLight();
                    half4 vertexColor = input.color;

                    half3 normalizedNormal = normalize(input.normalWS);
                    half3 normalizedLight = normalize(light.direction);

                    //采样纹理贴图
                    half4 baseMap = tex2D(_BaseMap, input.uv0);
                    half4 lightMap = tex2D(_LightMap, input.uv0);

                    //兰伯特光照 [-1,1]
                    half lambert = dot(normalizedNormal,normalizedLight);

                    //半兰伯特光照 [0,1]，让暗部不要那么黑
                    half halfLambert = lambert * 0.5 + 0.5;

                    //整体压暗
                    halfLambert *= pow(halfLambert,2);

                    half lambertStep = smoothstep(0.01,0.4,halfLambert);
                    half shadowFactor = lerp(0,halfLambert,lambertStep);

                    //环境光遮蔽
                    half ambientLight;
                    #if _USE_LIGHTMAP_AO
                        ambientLight = lightMap.g;
                    #else
                        ambientLight = halfLambert;
                    #endif
 
                    half shadow = (ambientLight + halfLambert) * 0.5;
                    shadow = lerp(shadow,1,step(0.95,ambientLight));
                    shadow = lerp(shadow,0,step(ambientLight,0.05));
                    half isShadowArea = step(shadow, _ShadowPosition);
                    half shadowDepth = (_ShadowPosition-shadow)/_ShadowPosition;
                    shadowDepth = pow(shadowDepth,_ShadowSoftness);
                    shadowDepth = min(shadowDepth,1);
                    //控制ramp宽度
                    half rampWidthFactor = vertexColor.g * 2 * _ShadowRampWidth;
                    half shadowPosition = (_ShadowPosition - shadowFactor) / _ShadowPosition;

                    //Ramp横纵坐标
                    half rampU = 1 - saturate(shadowDepth/rampWidthFactor);
                    half rampID = RampShadowID(lightMap.a,_UseRampShadow2,_UseRampShadow3,_UseRampShadow4,_UseRampShadow5,1,2,3,4,5);
                    //[1,5]->[0.45,0.05]的线性映射
                    half rampV = 0.45-(rampID-1)*0.1;
                    //rampV+0.5，使用下半部分的第二套阴影颜色
                    half2 rampDayUV = half2(rampU,rampV+0.5);
                    half3 rampDayColor = tex2D(_RampTex,rampDayUV);
                    half2 rampNightUV = half2(rampU,rampV);
                    half3 rampNightColor = tex2D(_RampTex,rampNightUV);
                    half3 rampColor = lerp(rampDayColor,rampNightColor,_DayOrNight);

                    half3 finalColor;
                    //合并颜色
                    #if _USE_RAMP_SHADOW
                    //采用ramp阴影
                        finalColor = baseMap.rgb * rampColor * (isShadowArea?1:1.2);
                    #else
                    //采用兰伯特阴影
                        finalColor = baseMap.rgb * halfLambert * (shadow+0.2);
                    #endif
                    return float4(finalColor.rgb,1);
                }

            ENDHLSL
        }
    }
}
