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
        _AOIntensity ("AO Intensity", Range(0,1)) = 0.5
        _AORadius ("AO Radius", Float) = 0.002
        
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
            sampler2D _CameraDepthTexture;
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
            float _AOIntensity;
            float _AORadius;
            float4 _LightDirection;
            fixed4 _LightColor;

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

            float SampleDepth(float2 uv)
            {
                return LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
            }

            float ComputeSSAO(float2 uv, float3 N, float3 V)
            {
                float centerDepth = SampleDepth(uv);

                float ao = 0;
                int SAMPLE_COUNT = 6;

                float2 dirs[6] = {
                    float2(1,0), float2(-1,0),
                    float2(0,1), float2(0,-1),
                    float2(0.7,0.7), float2(-0.7,0.7)
                };

                for(int i=0;i<SAMPLE_COUNT;i++)
                {
                    float2 offset = dirs[i] * _AORadius;
                    float sampleDepth = SampleDepth(uv + offset);

                    float diff = sampleDepth - centerDepth;
                    ao += step(diff, 0.01);
                }

                ao = 1.0 - (ao / SAMPLE_COUNT);

                float NdotV = saturate(dot(N, V));
                ao *= NdotV;

                return lerp(1.0, ao, _AOIntensity);
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
                float ao = ComputeSSAO(screenUV, N, V);
                ao = lerp(1.0, ao, _AOIntensity);

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
                float3 viewNormal = mul((float3x3)UNITY_MATRIX_V, N);
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

        Pass
        {
            Tags { "LightMode"="ShadowCaster" }
            
            CGPROGRAM
            #pragma vertex vertShadow
            #pragma fragment fragShadow
            #pragma multi_compile_shadowcaster

            #include "UnityCG.cginc"

            struct v2f_shadow
            {
                V2F_SHADOW_CASTER;
            };

            v2f_shadow vertShadow(appdata_base v)
            {
                v2f_shadow o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);
                return o;
            }

            fixed4 fragShadow(v2f_shadow i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
    
    Fallback "Diffuse"
}
