Shader "KTB/HLSLTraining/PBR"
{
    Properties
    {
        [Header(Surface)]
        _MainTex                        ("Albedo", 2D) = "white" {}
        _Color                          ("Color Tint", Color) = (1,1,1,1)

        [Header(PBR Parameters)]
        _MetallicMap                    ("Metallic Map", 2D) = "white" {}
        _Metallic                       ("Metallic", Range(0,1)) = 0.0
        _RoughnessMap                   ("Roughness Map", 2D) = "white" {}
        _Roughness                      ("Roughness", Range(0.04, 1.0)) = 0.5

        [Header(Normal)]
        _NormalMap                      ("Normal Map", 2D) = "bump" {}
        _NormalMapStrength              ("Normal Map Strength", Range(0,2)) = 1.0

        [Header(MatCap)]
        [Toggle(_MATCAP_ON)]
        _MatCapEnabled                  ("Enable MatCap", Float) = 0
        [KeywordEnum(Additive, Multiply, Screen, Linear)]
        _MatCapBlendMode                ("Blend Mode", Float) = 0
        _MatCap                         ("Material Capture", 2D) = "black" {}
        _MatCapBlur                     ("MatCap Blur", Range(0, 8)) = 0.0
        _MatCapStrength                 ("MatCap Strength", Range(0,1)) = 0.0
        _MatCapMask                     ("MatCap Mask", 2D) = "white" {}

        [Header(Lighting)]
        _DirectLightIntensity           ("Direct Light Intensity", Range(0,10)) = 1.0
        _IndirectLightIntensity         ("Indirect Light Intensity", Range(0,10)) = 1.0

        [Header(Rim Lighting)]
        _BackRimColor                   ("Backlight Rim Color", Color) = (1, 1, 1, 1)
        _BackRimPower                   ("Backlight Rim Power", Range(0.5, 8)) = 3.0
        _BackRimIntensity               ("Backlight Rim Intensity", Range(0, 5)) = 0.3
        _InnerRimColor                  ("Inner Rim Color (Shade)", Color) = (0.5, 0.5, 0.5, 1)
        _InnerRimPower                  ("Inner Rim Power", Range(0.5, 8)) = 4.0
        _InnerRimIntensity              ("Inner Rim Intensity", Range(0, 2)) = 0.5

        [Header(Shadow)]
        _ShadowColor                    ("Shadow Color", Color) = (0.1, 0.1, 0.15, 1)
        _ShadowSoftness                 ("Shadow Softness (Wrap)", Range(0, 0.5)) = 0.0

        [Header(SSAO Settings)]
        [KeywordEnum(Samples_8, Samples_16, Samples_32)]
        _SSAOQuality                    ("Quality (Samples)", Float) = 1
        _SSAORadius                     ("Radius (World)",  Range(0.01, 2.0)) = 0.04
        _SSAOBias                       ("Depth Bias", Range(0.001,0.1)) = 0.005
        _SSAOIntensity                  ("Intensity", Range(0.0, 5.0)) = 1.0
        _SSAOFalloff                    ("Falloff Power", Range(0.5, 4.0)) = 1.0
        _SSAOThickness                  ("Thickness (xRadius)", Range(1.0, 4.0)) = 2.0

        [Header(Fallback Light)]
        _LightDirection                 ("Light Direction", Vector) = (-1,-1,0,0)
        _LightColor                     ("Light Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma multi_compile _ _SSAOQUALITY_SAMPLES_8 _SSAOQUALITY_SAMPLES_32
            #pragma multi_compile _MATCAPBLENDMODE_ADDITIVE _MATCAPBLENDMODE_MULTIPLY _MATCAPBLENDMODE_SCREEN _MATCAPBLENDMODE_LINEAR
            #pragma shader_feature_local _MATCAP_ON
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #include "core.hlsl"

            struct appdata
            {
                float4 pos      : POSITION;
                float2 uv       : TEXCOORD0;
                float3 normal   : NORMAL;
                float4 tangent  : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos       : SV_POSITION;
                float2 uv        : TEXCOORD0;
                float3 normalWS  : TEXCOORD1;
                float3 worldPos  : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
                float3 tangentWS : TEXCOORD4;
                float3 bitanWS   : TEXCOORD5;
                SHADOW_COORDS(6)
                UNITY_FOG_COORDS(7)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            float4      _CameraDepthTexture_TexelSize;

            sampler2D   _MainTex;
            float4      _MainTex_ST;
            fixed4      _Color;
            sampler2D   _MetallicMap;
            float       _Metallic;
            sampler2D   _RoughnessMap;
            float       _Roughness;
            sampler2D   _NormalMap;
            float       _NormalMapStrength;
            sampler2D   _MatCap;
            sampler2D   _MatCapMask;
            float       _MatCapStrength;
            float       _MatCapBlur;
            float       _DirectLightIntensity;
            float       _IndirectLightIntensity;
            fixed4      _BackRimColor;
            float       _BackRimPower;
            float       _BackRimIntensity;
            fixed4      _InnerRimColor;
            float       _InnerRimPower;
            float       _InnerRimIntensity;
            fixed4      _ShadowColor;
            float       _ShadowSoftness;
            float       _SSAORadius;
            float       _SSAOBias;
            float       _SSAOIntensity;
            float       _SSAOFalloff;
            float       _SSAOThickness;
            float4      _LightDirection;
            fixed4      _LightColor;

            #if defined(_SSAOQUALITY_SAMPLES_8)
                #define SSAO_SAMPLE_COUNT 8
            #elif defined(_SSAOQUALITY_SAMPLES_32)
                #define SSAO_SAMPLE_COUNT 32
            #else
                #define SSAO_SAMPLE_COUNT 16
            #endif

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

            float4x4 GetStereoCameraProjection()
            {
            #if defined(USING_STEREO_MATRICES)
                return unity_StereoCameraProjection[unity_StereoEyeIndex];
            #else
                return unity_CameraProjection;
            #endif
            }

            float InterleavedGradientNoise(float2 p)
            {
                return frac(52.9829189 * frac(dot(p, float2(0.06711056, 0.00583715))));
            }

            float SampleDepth(float2 screenUV)
            {
                return SAMPLE_DEPTH_TEXTURE(
                    _CameraDepthTexture,
                    UnityStereoTransformScreenSpaceTex(screenUV)
                );
            }

            float3 ReconstructViewPos(float2 screenUV, float rawDepth)
            {
                float linearDepth = LinearEyeDepth(rawDepth);
                float2 ndc = screenUV * 2.0 - 1.0;

                float4x4 proj = GetStereoCameraProjection();
                float2 viewXY = float2(
                    (ndc.x - proj._m02) / proj._m00,
                    (ndc.y - proj._m12) / proj._m11
                );

                return float3(viewXY * linearDepth, -linearDepth);
            }

            float ComputeSSAO(float2 screenUV, float3 P, float3 N)
            {
                float2 pixelCoord = floor(screenUV * _ScreenParams.xy);

                float3 up = (abs(N.z) < 0.999) ? float3(0, 0, 1) : float3(1, 0, 0);
                float3 T0 = normalize(cross(up, N));
                float3 B0 = cross(N, T0);

                float theta = InterleavedGradientNoise(pixelCoord) * KTBPBR_PI * 2.0;
                float cosT = cos(theta);
                float sinT = sin(theta);

                float3 T_r = T0 * cosT + B0 * sinT;
                float3 B_r = -T0 * sinT + B0 * cosT;
                float3x3 TBN = float3x3(T_r, B_r, N);

                float4x4 proj = GetStereoCameraProjection();

                #if defined(UNITY_REVERSED_Z)
                    const float FAR_EPS_MIN = 1e-6;
                #else
                    const float FAR_EPS_MAX = 1.0 - 1e-6;
                #endif

                float ao = 0.0;
                float validSamples = 0.0;

                [unroll]
                for (int s = 0; s < SSAO_SAMPLE_COUNT; ++s)
                {
                    float3 k = SSAO_KERNEL[s];
                    k.z = abs(k.z);

                    float t = float(s) / float(SSAO_SAMPLE_COUNT);
                    float scale = lerp(0.1, 1.0, t * t);
                    float3 dir = k * scale;

                    float3 sampleOff = mul(dir * _SSAORadius, TBN);
                    float3 samplePos = P + sampleOff;

                    float4 sc = mul(proj, float4(samplePos, 1.0));
                    if (sc.w < 1e-4) continue;

                    float2 sampleUV;
                    sampleUV.x = sc.x / sc.w * 0.5 + 0.5;
                    sampleUV.y = sc.y / sc.w * 0.5 + 0.5;

                    if (any(sampleUV < 0.0) || any(sampleUV > 1.0)) continue;

                    float2 sampleUVStereo = UnityStereoTransformScreenSpaceTex(sampleUV);
                    float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampleUVStereo);

                #if defined(UNITY_REVERSED_Z)
                    if (rawDepth <= FAR_EPS_MIN) continue;
                #else
                    if (rawDepth >= FAR_EPS_MAX) continue;
                #endif

                    float sceneDepth = LinearEyeDepth(rawDepth);
                    float sampleEyeZ = -samplePos.z;

                    float dynamicBias = _SSAOBias * max(1.0, -P.z * 0.05);

                    float diff = sampleEyeZ - sceneDepth;
                    float rangeCheck = smoothstep(1.0, 0.0, abs(diff) / _SSAORadius);

                    bool occluded = (diff > dynamicBias) && (diff < _SSAORadius * _SSAOThickness);
                    ao += occluded ? pow(rangeCheck, _SSAOFalloff) : 0.0;

                    validSamples += 1.0;
                }
                float norm = max(validSamples, 1.0);
                return saturate(1.0 - (ao / norm) * _SSAOIntensity);
            }

            float ComputeSSAOBlurred(float2 screenUV, float3 viewN)
            {
                // サンプリング点の四方でSSAOを計算することでより滑らかなSSAOを算出
                // SSAO計算量が5倍になり非常に高負荷なため注意!!
                float rd = SampleDepth(screenUV);
                float3 vp = ReconstructViewPos(screenUV, rd);
                float aoC = ComputeSSAO(screenUV, vp, viewN);
                float2 texel = _CameraDepthTexture_TexelSize.xy * 2.0;
                float total = aoC, w = 1.0;
                float cd = -vp.z;
                static const float2 offs[4] = { float2(1,0), float2(-1,0), float2(0,1), float2(0,-1) };
                [unroll]
                for (int k = 0; k < 4; k++) {
                    float2 uv = screenUV + offs[k] * texel;
                    float3 vp2 = ReconstructViewPos(uv, SampleDepth(uv));
                    float dw = exp(-abs(-vp2.z - cd) * 5.0);
                    total += ComputeSSAO(uv, vp2, viewN) * dw;
                    w += dw;
                }
                return total / w;
            }

            // -----------------------------------------------------------------
            // Vertex / Fragment
            // -----------------------------------------------------------------
            v2f vert(appdata v)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f,o);
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.pos       = UnityObjectToClipPos(v.pos);
                o.uv        = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS  = UnityObjectToWorldNormal(v.normal);
                o.worldPos  = mul(unity_ObjectToWorld, v.pos).xyz;
                o.screenPos = ComputeScreenPos(o.pos);
                o.tangentWS = UnityObjectToWorldDir(v.tangent.xyz);
                o.bitanWS   = cross(o.normalWS, o.tangentWS) * v.tangent.w;
                TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                fixed4 albedoTex = tex2D(_MainTex, i.uv) * _Color;
                float3 albedo    = albedoTex.rgb;
                float  metallic  = tex2D(_MetallicMap,  i.uv).r * _Metallic;
                float  roughness = tex2D(_RoughnessMap, i.uv).r * _Roughness;
                roughness = max(roughness, KTBPBR_MIN_ROUGHNESS);

                float3 normalTex = UnpackNormal(tex2D(_NormalMap, i.uv));
                normalTex.xy *= _NormalMapStrength;
                normalTex = normalize(normalTex);
                float3x3 TBN = float3x3(normalize(i.tangentWS),
                                        normalize(i.bitanWS),
                                        normalize(i.normalWS));
                float3 N = normalize(mul(normalTex, TBN));
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float3 viewN    = normalize(mul((float3x3)UNITY_MATRIX_V, N));

                float3 P  = mul(UNITY_MATRIX_V, float4(i.worldPos, 1.0)).xyz;
                float  ao = ComputeSSAO(screenUV, P, viewN);

                KTBPBRSurface s;
                s.albedo    = albedo;
                s.metallic  = metallic;
                s.roughness = roughness;
                s.N         = N;
                s.V         = V;
                s.worldPos  = i.worldPos;
                s.occlusion = ao;

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                KTBPBRLightDatas datas;
                KTBPBR_ComputeLights(datas, s,
                                     _LightDirection.xyz,
                                     _LightColor.rgb,
                                     atten);

                float3 rimL, rimLCol;
                KTBPBR_GetDirectionalLight(_LightDirection.xyz, _LightColor.rgb, rimL, rimLCol);

                KTBPBRRimParams rimP;
                rimP.backRimColor      = _BackRimColor.rgb;
                rimP.backRimPower      = _BackRimPower;
                rimP.backRimIntensity  = _BackRimIntensity;
                rimP.innerRimColor     = _InnerRimColor.rgb;
                rimP.innerRimPower     = _InnerRimPower;
                rimP.innerRimIntensity = _InnerRimIntensity;

                float3 rim = KTBPBR_ComputeRim(s, rimL, rimLCol, atten, rimP);

                float NdotL_main = saturate(dot(N, normalize(_WorldSpaceLightPos0.xyz)));
                float wrapped = saturate((NdotL_main + _ShadowSoftness) / (1.0 + _ShadowSoftness));
                float3 shadowTint = lerp(_ShadowColor.rgb, float3(1,1,1), atten * wrapped);

                float3 direct   = (datas.directDiffuse + datas.directSpecular) * _DirectLightIntensity * shadowTint;
                float3 indirect = (datas.indirectDiffuse + datas.indirectSpecular) * _IndirectLightIntensity * ao;
                float3 finalColor = direct + indirect + rim * ao;

                // MatCap
                #if defined(_MATCAP_ON)
                    float2 mUV = viewN.xy * 0.495 + 0.5;
                    float3 matcap = tex2Dlod(_MatCap, float4(mUV, 0, _MatCapBlur)).rgb;
                    fixed  matcapMaskTex  = tex2D(_MatCapMask, i.uv).r;
                    float  matcapFactor   = matcapMaskTex * _MatCapStrength;

                    #if defined(_MATCAPBLENDMODE_ADDITIVE)
                        finalColor = finalColor + matcap * matcapFactor;
                    #elif defined(_MATCAPBLENDMODE_MULTIPLY)
                        finalColor = finalColor * lerp(1.0, matcap, matcapFactor);
                    #elif defined(_MATCAPBLENDMODE_LINEAR)
                        finalColor = lerp(finalColor, matcap, matcapFactor);
                    #else
                        finalColor = lerp(finalColor, 1.0 - (1.0 - finalColor) * (1.0 - matcap * matcapMaskTex), _MatCapStrength);
                    #endif
                #endif

                fixed4 col = fixed4(finalColor, albedoTex.a);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
