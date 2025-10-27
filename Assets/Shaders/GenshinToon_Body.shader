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

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" //核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" //光照库
        
            CBUFFER_START(UnityPerMaterial)
                //基础纹理
                sampler2D _BaseMap;
                //光照贴图
                sampler2D _LightMap;
            CBUFFER_END
        
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
                    return output;
                }

                half4 MainFragmentShader(Varyings input) : SV_TARGET
                {
                    Light light = GetMainLight();

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
                    halfLambert = pow(halfLambert,2);

                    //环境光遮蔽
                    half ambientLight;
                    #if _USE_LIGHTMAP_AO
                        ambientLight = lightMap.g;
                    #else
                        ambientLight = halfLambert;
                    #endif

                    half shadow = (ambientLight + halfLambert) * 0.5 + 0.2;
                    shadow = lerp(shadow,1,step(0.95,ambientLight));
                    shadow = lerp(shadow,0,step(ambientLight,0.05));

                    //合并颜色
                    half3 finalColor = baseMap.rgb * halfLambert * shadow;
                    return float4(finalColor.rgb,1);
                }

            ENDHLSL
        }
    }
}
