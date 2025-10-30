Shader "GenshinToon/Face"
{
    Properties //public 成员变量
    {
        [Header(Textures)]
        //基础纹理
        _BaseMap ("Base Map", 2D) = "white"{}

        [Header(Shadow Options)]
        [Toggle(_USE_SDF_SHADOW)] _UseSDFShadow ("Use SDF Shadow", Range(0,1)) = 1
        //距离场纹理
        _SDF ("SDF", 2D) = "white"{}
        //阴影遮罩
        _ShadowMask("Shadow Mask", 2D) = "white"{}
        _ShadowColor("Shadow Color", Color) = (1,0.87,0.87,1)

        [Header(Head Direction)]
        [HideInInspector] _HeadForward ("Head Forward", Vector) = (0,0,1,0)
        [HideInInspector] _HeadRight ("Head Right", Vector) = (1,0,0,0)
        [HideInInspector] _HeadUp ("Head Up", Vector) = (0,1,0,0)

        [Header(Face Blush)]
        _FaceBlushColor ("Face Blush Color", Color) = (1,0,0,1)
        _FaceBlushStrength ("Face Blush Strength", Range(0,1)) = 0

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

            #pragma shader_feature_local _USE_SDF_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" //核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" //光照库
        
            CBUFFER_START(UnityPerMaterial)
                //基础纹理
                sampler2D _BaseMap;
                //Shadow Option
                sampler2D _SDF;
                sampler2D _ShadowMask;
                float4 _ShadowColor;
                //Head Direction
                float4 _HeadForward;
                float4 _HeadRight;
                float4 _HeadUp;
                //Face Blush
                float4 _FaceBlushColor;
                float _FaceBlushStrength;
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

                    half3 normalDir = normalize(input.normalWS);
                    half3 lightDir = normalize(light.direction);
                    half3 headForwardDir = normalize(_HeadForward);
                    half3 headUpDir = normalize(_HeadUp);
                    half3 headRightDir = normalize(_HeadRight);

                    //采样纹理贴图
                    half4 baseMap = tex2D(_BaseMap, input.uv0);
                    half4 shadowMask = tex2D(_ShadowMask, input.uv0);

                    //兰伯特光照 [-1,1]
                    half lambert = dot(normalDir,lightDir);

                    //半兰伯特光照 [0,1]
                    half halfLambert = lambert * 0.5 + 0.5;

                    //make it darker
                    halfLambert = pow(halfLambert,2);

                    //face shadow
                    half3 LpU = dot(lightDir, headUpDir) / pow(length(headUpDir), 2) * headUpDir; // 计算光源方向在面部上方的投影
                    half3 LpHeadHorizon = normalize(lightDir - LpU); // 光照方向在头部水平面上的投影
                    half value = acos(dot(LpHeadHorizon, headRightDir)) / 3.141592654; // 计算光照方向与面部右方的夹角
                    half exposeRight = step(value, 0.5); // 判断光照是来自右侧还是左侧
                    half valueR = pow(1 - value * 2, 3); // 右侧阴影强度
                    half valueL = pow(value * 2 - 1, 3); // 左侧阴影强度
                    half mixValue = lerp(valueL, valueR, exposeRight); // 混合阴影强度
                    half sdfLeft = tex2D(_SDF, half2(1 - input.uv0.x, input.uv0.y)).r; // 左侧距离场
                    half sdfRight = tex2D(_SDF, input.uv0).r; // 右侧距离场
                    half mixSdf = lerp(sdfRight, sdfLeft, exposeRight); // 采样SDF纹理
                    half sdf = step(mixValue, mixSdf); // 计算硬边界阴影
                    sdf = lerp(0, sdf, step(0, dot(LpHeadHorizon, headForwardDir))); // 计算右侧阴影
                    sdf *= shadowMask.g; // 使用G通道控制阴影强度
                    sdf = lerp(sdf, 1, shadowMask.a); // 使用A通道作为阴影遮罩

                    half faceBlushStrength = lerp(0,baseMap.a,_FaceBlushStrength);

                    //合并颜色
                    half3 finalColor;
                    
                    #if _USE_SDF_SHADOW
                        finalColor = lerp(_ShadowColor.rgb*baseMap.rgb,baseMap.rgb,sdf);
                    #else
                        finalColor = baseMap.rgb * halfLambert;
                    #endif

                    finalColor = lerp(finalColor, finalColor *_FaceBlushColor.rgb, faceBlushStrength);

                    return float4(finalColor,1);
                }

            ENDHLSL
        }
    }
}
