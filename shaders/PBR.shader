Shader "KTB/HLSLTraining/PBR"
{
    Properties
    {
        [Header(Surface)]
        _MainTex ("Albedo", 2D) = "white" {}
        _Color ("Color Tint", Color) = (1,1,1,1)
        
        [Header(PBR Parameters)]
        _MetallicMap ("Metallic Map", 2D) = "white" {}
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _RoughnessMap ("Roughness Map", 2D) = "white" {}
        _Roughness ("Roughness", Range(0.04, 1.0)) = 0.5
        
        [Header(Normal)]
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalMapStrength ("Normal Map Strength", Range(0,2)) = 1.0
        
        [Header(MatCap)]
        _MatCap ("Material Capture", 2D) = "black" {}
        _MatCapStrength ("MatCap Strength", Range(0,1)) = 0.0
        _MatCapMask ("MatCap Mask", 2D) = "white" {}

        [Header(Lighting)]
        _DirectLightIntensity ("Direct Light Intensity", Range(0,10)) = 1.0
        _IndirectLightIntensity ("Indirect Light Intensity", Range(0,10)) = 1.0
        
        [Header(Shadow)]
        _ShadowColor ("Shadow Color", Color) = (0.1, 0.1, 0.15, 1)
        _ShadowSoftness ("Shadow Softness (Wrap)", Range(0, 0.5)) = 0.0
        
        [Header(SSAO Settings)]
        [KeywordEnum(Samples_8, Samples_16, Samples_32)]
        _SSAOQuality    ("Quality (Samples)", Float)            = 1
        _SSAORadius     ("Radius (World)",  Range(0.01, 2.0))   = 0.3
        _SSAOBias       ("Depth Bias",      Range(0.001,0.1))   = 0.025
        _SSAOIntensity  ("Intensity",       Range(0.0, 5.0))    = 2.0
        _SSAOFalloff    ("Falloff Power",   Range(0.5, 4.0))    = 1.0
        
        [Header(Fallback Light)]
        _LightDirection ("Light Direction", Vector) = (-1,-1,0,0)
        _LightColor ("Light Color", Color) = (1,1,1,1)
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 300

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma multi_compile _ _SSAO_BLUR
            #pragma multi_compile _ _SSAOQUALITY_SAMPLES_8 _SSAOQUALITY_SAMPLES_32
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            // ----- Constants -----
            #define PI 3.14159265359
            #define MIN_ROUGHNESS 0.04
            #define DIELECTRIC_F0 float3(0.04, 0.04, 0.04)

            struct appdata
            {
                float4 pos      : POSITION;
                float2 uv       : TEXCOORD0;
                float3 normal   : NORMAL;
                float4 tangent  : TANGENT;
            };

            struct v2f
            {
                float4 pos       : SV_POSITION;
                float2 uv        : TEXCOORD0;
                float3 normalWS  : TEXCOORD1;
                float3 worldPos  : TEXCOORD2;
                float4 screenPos   : TEXCOORD3;
                float3 tangentWS : TEXCOORD4;
                float3 bitanWS   : TEXCOORD5;
                SHADOW_COORDS(6)
                UNITY_FOG_COORDS(7)
            };

            // ----- Properties -----
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            float4 _CameraDepthTexture_TexelSize;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            sampler2D _MetallicMap;
            float _Metallic;
            sampler2D _RoughnessMap;
            float _Roughness;
            sampler2D _OcclusionMap;
            float _OcclusionStrength;
            sampler2D _NormalMap;
            float _NormalMapStrength;
            sampler2D _MatCap;
            float _MatCapStrength;
            sampler2D _MatCapMask;
            float _DirectLightIntensity;
            float _IndirectLightIntensity;
            fixed4 _ShadowColor;
            float _ShadowSoftness;
            float _SSAORadius;
            float _SSAOBias;
            float _SSAOIntensity;
            float _SSAOFalloff;
            float _SSAOBlurRadius;
            float4 _LightDirection;
            fixed4 _LightColor;

            static const float3 SSAO_KERNEL[32] =
            {
                float3( 0.2024, 0.3868,-0.3220), float3(-0.1551, 0.2711, 0.4906),
                float3( 0.5000, 0.0794,-0.1420), float3(-0.3841, 0.1429, 0.3019),
                float3( 0.0562,-0.0865,-0.7420), float3( 0.0347, 0.0423,-0.1627),
                float3(-0.0235, 0.1960, 0.0984), float3( 0.0159,-0.1762,-0.0523),
                float3(-0.2490,-0.4138,-0.3512), float3(-0.2713, 0.1194, 0.0209),
                float3( 0.0094,-0.4938, 0.0077), float3(-0.0921,-0.4012, 0.3501),
                float3( 0.6207,-0.0172,-0.1043), float3(-0.0611, 0.0687,-0.4920),
                float3( 0.0389,-0.0722, 0.5183), float3(-0.4202, 0.2716,-0.0310),
                float3(-0.1344, 0.3794, 0.0720), float3( 0.3175,-0.2628,-0.4442),
                float3( 0.4516, 0.0557, 0.5278), float3( 0.0994, 0.0214,-0.2381),
                float3( 0.1608, 0.3041, 0.4180), float3(-0.0622,-0.0057,-0.3094),
                float3(-0.0215,-0.2508,-0.1161), float3( 0.3285, 0.2449,-0.2627),
                float3( 0.0894, 0.2960, 0.1853), float3(-0.1561, 0.5153,-0.2131),
                float3(-0.5250,-0.2121,-0.2417), float3(-0.0971,-0.1154, 0.4621),
                float3( 0.2812, 0.4166,-0.3231), float3( 0.1835,-0.2804,-0.2685),
                float3( 0.0994,-0.3512,-0.3168), float3( 0.2677, 0.0574,-0.2622)
            };

            // ==========================================================
            //  PBR 関数群
            // ==========================================================

            // --- GGX Normal Distribution Function (Trowbridge-Reitz) ---
            float DistributionGGX(float NdotH, float roughness)
            {
                float a  = roughness * roughness;
                float a2 = a * a;
                float d  = NdotH * NdotH * (a2 - 1.0) + 1.0;
                return a2 / (PI * d * d + 1e-7);
            }

            // --- Smith-GGX Geometry Function (Height-Correlated) ---
            float GeometrySmithGGX(float NdotV, float NdotL, float roughness)
            {
                float a = roughness * roughness;
                float a2 = a * a;
                
                // Height-correlated Smith G2
                float GGXV = NdotL * sqrt(NdotV * NdotV * (1.0 - a2) + a2);
                float GGXL = NdotV * sqrt(NdotL * NdotL * (1.0 - a2) + a2);
                return 0.5 / (GGXV + GGXL + 1e-7);
            }

            // --- Schlick-Fresnel ---
            float3 FresnelSchlick(float cosTheta, float3 F0)
            {
                return F0 + (1.0 - F0) * pow(saturate(1.0 - cosTheta), 5.0);
            }

            // ラフネス補正付き Fresnel（間接光用）
            float3 FresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
            {
                float3 maxF = max((1.0 - roughness).xxx, F0);
                return F0 + (maxF - F0) * pow(saturate(1.0 - cosTheta), 5.0);
            }

            // --- Disney/Burley Diffuse ---
            float3 DisneyDiffuse(float NdotV, float NdotL, float LdotH, float roughness)
            {
                float FD90 = 0.5 + 2.0 * LdotH * LdotH * roughness;
                float lightScatter = 1.0 + (FD90 - 1.0) * pow(1.0 - NdotL, 5.0);
                float viewScatter  = 1.0 + (FD90 - 1.0) * pow(1.0 - NdotV, 5.0);
                return (lightScatter * viewScatter) / PI;
            }

            // ==========================================================
            //  SSAO 関数群
            // ==========================================================

            float InterleavedGradientNoise(float2 screenPixel)
            {
                float3 vec = float3(0.06711056, 0.00583715, 52.9829189);
                return frac(vec.z * frac(dot(screenPixel, vec.xy)));
            }

            float2x2 RandRotation2D(float2 screenUV)
            {
                float2 screenPixel = screenUV * _ScreenParams.xy;
                float angle = InterleavedGradientNoise(screenPixel) * UNITY_TWO_PI;
                float cosA = cos(angle);
                float sinA = sin(angle);
                return float2x2(cosA, -sinA, sinA, cosA);
            }

            float3 ReconstructViewPos(float2 screenUV, float rawDepth)
            {
                float  linearDepth = LinearEyeDepth(rawDepth);
                float2 ndc = screenUV * 2.0 - 1.0;
                float3 viewPos;
                viewPos.x = ndc.x * linearDepth / unity_CameraProjection._11;
                viewPos.y = ndc.y * linearDepth / unity_CameraProjection._22;
                viewPos.z = -linearDepth;
                return viewPos;
            }

            float SampleDepth(float2 uv)
            {
                uv = clamp(uv, _CameraDepthTexture_TexelSize.xy, 1.0 - _CameraDepthTexture_TexelSize.xy);
                return SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
            }

            float ComputeSSAO(float2 screenUV, float3 viewPos, float3 viewNormal)
            {
                #if defined(_SSAOQUALITY_SAMPLES_8)
                    #define SSAO_SAMPLE_COUNT 8
                #elif defined(_SSAOQUALITY_SAMPLES_32)
                    #define SSAO_SAMPLE_COUNT 32
                #else
                    #define SSAO_SAMPLE_COUNT 16
                #endif

                float2x2 rot = RandRotation2D(screenUV);
                float occlusion = 0.0;
                float currentLinearDepth = -viewPos.z;

                float radiusScale = _SSAORadius / max(currentLinearDepth, 0.1);

                [unroll(32)]
                for (int i = 0; i < SSAO_SAMPLE_COUNT; i++)
                {
                    float3 sampleDir = SSAO_KERNEL[i];
                    sampleDir.xy = mul(rot, sampleDir.xy);
                    sampleDir = sampleDir * sign(dot(sampleDir, viewNormal) + 1e-5);

                    float t = float(i + 1) / float(SSAO_SAMPLE_COUNT);
                    float scale = lerp(0.1, 1.0, t * t);
                    float3 samplePos = viewPos + sampleDir * (_SSAORadius * scale);

                    float4 sampleClip = mul(unity_CameraProjection, float4(samplePos, 1.0));
                    float2 sampleUV = (sampleClip.xy / sampleClip.w) * 0.5 + 0.5;

                    float sampleRawDepth = SampleDepth(sampleUV);
                    float sampleLinearDepth = LinearEyeDepth(sampleRawDepth);

                    float expectedDepth = -samplePos.z;

                    float depthDiff = expectedDepth - sampleLinearDepth - _SSAOBias;
                    float occluded = smoothstep(0.0, _SSAORadius * 0.1, depthDiff);

                    float rangeCheck = smoothstep(_SSAORadius, 0.0,
                                                abs(currentLinearDepth - sampleLinearDepth));

                    occlusion += occluded * rangeCheck;
                }

                float aoRaw = occlusion / float(SSAO_SAMPLE_COUNT);
                float ao = 1.0 - saturate(pow(aoRaw, _SSAOFalloff) * _SSAOIntensity);
                return ao;
            }

            float ComputeSSAOBlurred(float2 screenUV, float3 viewNormal)
            {
                float rawDepthC = SampleDepth(screenUV);
                float3 viewPosC = ReconstructViewPos(screenUV, rawDepthC);
                float aoCenter = ComputeSSAO(screenUV, viewPosC, viewNormal);

                float2 texel = _CameraDepthTexture_TexelSize.xy * 2.0;
                float totalAO = aoCenter;
                float totalWeight = 1.0;
                float centerDepth = -viewPosC.z;

                static const float2 offsets[4] = {
                    float2(1, 0), float2(-1, 0),
                    float2(0, 1), float2(0, -1)
                };

                [unroll]
                for (int k = 0; k < 4; k++)
                {
                    float2 uv = screenUV + offsets[k] * texel;
                    float rawD = SampleDepth(uv);
                    float3 vp = ReconstructViewPos(uv, rawD);
                    float sampleDepth = -vp.z;

                    float depthWeight = exp(-abs(sampleDepth - centerDepth) * 5.0);
                    float ao = ComputeSSAO(uv, vp, viewNormal);

                    totalAO += ao * depthWeight;
                    totalWeight += depthWeight;
                }

                return totalAO / totalWeight;
            }

            // ==========================================================
            //  ライト取得
            // ==========================================================
            void GetDirectionalLight(out float3 lightDir, out float3 lightCol)
            {
                if (any(_LightColor0.rgb))
                {
                    lightDir = normalize(_WorldSpaceLightPos0.xyz);
                    lightCol = _LightColor0.rgb;
                }
                else
                {
                    lightDir = -normalize(_LightDirection.xyz);
                    lightCol = _LightColor.rgb;
                }
            }

            // ==========================================================
            //  Vertex Shader
            // ==========================================================
            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.pos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.pos).xyz;
                o.screenPos = ComputeScreenPos(o.pos);
                o.tangentWS = UnityObjectToWorldDir(v.tangent.xyz);
                o.bitanWS = cross(o.normalWS, o.tangentWS) * v.tangent.w;

                TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            // ==========================================================
            //  Fragment Shader
            // ==========================================================
            fixed4 frag(v2f i) : SV_Target
            {
                // --- Surface Data ---
                fixed4 albedoTex = tex2D(_MainTex, i.uv) * _Color;
                float3 albedo    = albedoTex.rgb;
                
                float metallic  = tex2D(_MetallicMap, i.uv).r * _Metallic;
                float roughness = tex2D(_RoughnessMap, i.uv).r * _Roughness;
                roughness = max(roughness, MIN_ROUGHNESS);

                // --- Normal Mapping ---
                float3 normalTS = UnpackNormal(tex2D(_NormalMap, i.uv));
                normalTS.xy *= _NormalMapStrength;
                normalTS = normalize(normalTS);

                float3x3 TBN = float3x3(
                    normalize(i.tangentWS),
                    normalize(i.bitanWS),
                    normalize(i.normalWS)
                );
                float3 N = normalize(mul(normalTS, TBN));

                // --- Vectors ---
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);
                float NdotV = max(dot(N, V), 1e-7);

                // --- Light ---
                float3 L, lightColor;
                GetDirectionalLight(L, lightColor);

                float3 H = normalize(L + V);
                float NdotL = max(dot(N, L), 0.0);
                float NdotH = max(dot(N, H), 0.0);
                float LdotH = max(dot(L, H), 0.0);
                float VdotH = max(dot(V, H), 0.0);
                float3 F0 = lerp(DIELECTRIC_F0, albedo, metallic);

                //  Cook-Torrance Specular BRDF
                float  D = DistributionGGX(NdotH, roughness);
                float  G = GeometrySmithGGX(NdotV, NdotL, roughness);
                float3 F = FresnelSchlick(VdotH, F0);

                float3 specular = D * G * F;

                //  Disney Diffuse (Energy Conserving)
                float3 kD = (1.0 - F) * (1.0 - metallic);
                float3 diffuse = kD * albedo * DisneyDiffuse(NdotV, NdotL, LdotH, roughness);

                //  Shadow (Wrap Lighting + Color)
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                // Wrap Lighting
                float wrappedNdotL = (NdotL + _ShadowSoftness) / (1.0 + _ShadowSoftness);
                wrappedNdotL = saturate(wrappedNdotL);

                float shadow = atten * wrappedNdotL;
                float3 shadowTint = lerp(_ShadowColor.rgb, float3(1,1,1), shadow);

                // SSAO
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float3 viewNormal = normalize(mul(UNITY_MATRIX_V, float4(N, 0.0)).xyz);

                float ao = saturate(ComputeSSAOBlurred(screenUV, viewNormal));

                // 直接光
                float3 directLighting = (diffuse + specular) * lightColor * NdotL * atten * _DirectLightIntensity;

                // 環境光
                float3 irradiance = max(ShadeSH9(float4(N, 1.0)), 0.005);
                float3 indirectDiffuse = kD * albedo * irradiance * ao * _IndirectLightIntensity;

                // 間接スペキュラ（近似: Fresnel + SH）
                float3 F_indirect = FresnelSchlickRoughness(NdotV, F0, roughness);
                float3 indirectSpecular = irradiance * F_indirect * (1.0 - roughness * 0.7) * saturate(pow(ao + NdotV, roughness));

                float3 indirectLighting = (indirectDiffuse + indirectSpecular);

                float3 finalColor = directLighting * shadowTint + indirectLighting;

                // =====================================================
                //  MatCap
                // =====================================================
                float2 matcapUV = viewNormal.xy * 0.495 + 0.5;
                float3 matcap = tex2D(_MatCap, matcapUV).rgb;
                fixed matcapMask = tex2D(_MatCapMask, i.uv).r;

                float3 matCapBlended = lerp(
                    finalColor, 
                    1.0 - (1.0 - finalColor) * (1.0 - matcap * matcapMask),
                    _MatCapStrength
                );
                finalColor = matCapBlended;

                // =====================================================
                //  Fog
                // =====================================================
                fixed4 col = fixed4(finalColor, albedoTex.a);
                UNITY_APPLY_FOG(i.fogCoord, col);

                return col;
            }
            ENDCG
        }
    }
    
    Fallback "Diffuse"
}
