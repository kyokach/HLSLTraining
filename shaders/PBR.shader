Shader "KTB/KPBR"
{
    Properties
    {
        [Header(Surface)]
        _MainTex                        ("Albedo", 2D) = "white" {}
        _Color                          ("Color Tint", Color) = (1,1,1,1)

        [Header(Color Correction)]
        [Toggle(_COLOR_CORRECTION_ON)]
        _ColorCorrectionEnabled         ("Enable Color Correction", Float) = 0
        _ColorCorrectionMask            ("Correction Mask (R)", 2D) = "white" {}
        _CCHueShift                     ("Hue Shift", Range(-0.5, 0.5)) = 0.0
        _CCSaturation                   ("Saturation", Range(0, 2)) = 1.0
        _CCBrightness                   ("Brightness", Range(0, 2)) = 1.0
        _CCContrast                     ("Contrast", Range(0, 2)) = 1.0

        // ------------------------------------------------------------------
        //  Rendering Mode
        //  推奨設定:
        //    Opaque       : SrcBlend=One,      DstBlend=Zero,             ZWrite=On,  Queue=Geometry(2000)
        //    Cutout       : SrcBlend=One,      DstBlend=Zero,             ZWrite=On,  Queue=AlphaTest(2450)
        //    Transparent  : SrcBlend=SrcAlpha, DstBlend=OneMinusSrcAlpha, ZWrite=Off, Queue=Transparent(3000)
        // ------------------------------------------------------------------
        [Header(Rendering Mode)]
        [KeywordEnum(Opaque, Cutout, Fade, Transparent)]
        _SurfaceMode                    ("Surface Mode", Float) = 0
        _Cutoff                         ("Alpha Cutoff (Cutout)", Range(0,1)) = 0.5
        [Enum(UnityEngine.Rendering.BlendMode)]
        _SrcBlend                       ("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)]
        _DstBlend                       ("Dst Blend", Float) = 0
        [Enum(Off, 0, On, 1)]
        _ZWrite                         ("ZWrite", Float) = 1
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                           ("Cull Mode (Off=Both, Front=裏面のみ, Back=表面のみ)", Float) = 2

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
        [Toggle(_RIM_ON)]
        _RimEnabled                     ("Enable Rim", Float) = 0
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
        [Toggle(_SSAO_ON)]
        _SSAOEnabled                    ("Enable SSAO", Float) = 0
        [KeywordEnum(Samples_8, Samples_16, Samples_32)]
        _SSAOQuality                    ("Quality (Samples)", Float) = 1
        _SSAORadius                     ("Radius (World)",  Range(0.01, 2.0)) = 0.04
        _SSAOBias                       ("Depth Bias", Range(0.001,0.1)) = 0.005
        _SSAOIntensity                  ("Intensity", Range(0.0, 5.0)) = 1.0
        _SSAOFalloff                    ("Falloff Power", Range(0.5, 4.0)) = 1.0
        _SSAOThickness                  ("Thickness (xRadius)", Range(1.0, 4.0)) = 2.0

        [Header(VRChat Lighting)]
        [Toggle(KPBR_VRCLIGHTVOLUMES_WITHOUTPACKAGE)]
        _VRCLightVolumesEnabled         ("Enable VRC Light Volumes", Float) = 0
        [Toggle(KPBR_VRCLIGHTVOLUMES)]
        _VRCLightVolumesEnabledOrg      ("Enable VRC Light Volumes", Float) = 0

        [Header(Fallback Light)]
        _LightDirection                 ("Light Direction", Vector) = (-1,-1,0,0)
        _LightColor                     ("Light Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" "IgnoreProjector"="True" }
        LOD 100

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            Blend  [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull   [_Cull]

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma shader_feature_local _ VERTEXLIGHT_ON
            #pragma shader_feature_local _ _SSAOQUALITY_SAMPLES_8 _SSAOQUALITY_SAMPLES_32
            #pragma shader_feature_local _MATCAPBLENDMODE_ADDITIVE _MATCAPBLENDMODE_MULTIPLY _MATCAPBLENDMODE_SCREEN _MATCAPBLENDMODE_LINEAR
            #pragma shader_feature_local _MATCAP_ON
            #pragma shader_feature_local _RIM_ON
            #pragma shader_feature_local _SSAO_ON
            #pragma shader_feature_local _SURFACEMODE_OPAQUE _SURFACEMODE_CUTOUT _SURFACEMODE_TRANSPARENT
            #pragma shader_feature_local _COLOR_CORRECTION_ON
            #pragma shader_feature_local _VRCLIGHTVOLUMES_WITHOUTPACKAGE
            #pragma shader_feature_local _VRCLIGHTVOLUMES
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
            sampler2D   _ColorCorrectionMask;
            float       _CCHueShift;
            float       _CCSaturation;
            float       _CCBrightness;
            float       _CCContrast;
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
            float       _Cutoff;

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

            float4x4 GetStereoCameraInvProjection()
            {
            #if defined(USING_STEREO_MATRICES)
                return unity_StereoCameraInvProjection[unity_StereoEyeIndex];
            #else
                return unity_CameraInvProjection;
            #endif
            }

            float GetLinearDepth(float zDepthFromMap, float2 screenUV)
            {
            #if defined(UNITY_REVERSED_Z)
                zDepthFromMap = 1.0 - zDepthFromMap;
                if (zDepthFromMap >= 1.0) return _ProjectionParams.z;
            #endif

                float4 clipPos = float4(screenUV.xy, zDepthFromMap, 1.0);
                clipPos.xyz = 2.0f * clipPos.xyz - 1.0f;
                float4 camPos = mul(GetStereoCameraInvProjection(), clipPos);
                return -camPos.z / camPos.w;
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
                float z = rawDepth;
            #if defined(UNITY_REVERSED_Z)
                z = 1.0 - z;
            #endif

                float4 clipPos = float4(screenUV * 2.0 - 1.0, z * 2.0 - 1.0, 1.0);
                float4 viewPos = mul(GetStereoCameraInvProjection(), clipPos);
                viewPos.xyz /= viewPos.w;
                return viewPos.xyz;
            }

            float ComputeSSAO(float2 screenUV, float3 P, float3 N)
            {
                float2 pixelCoord = floor(screenUV * _ScreenParams.xy);

                float3 up = (abs(N.z) < 0.999) ? float3(0, 0, 1) : float3(1, 0, 0);
                float3 T0 = normalize(cross(up, N));
                float3 B0 = cross(N, T0);

                float theta = InterleavedGradientNoise(pixelCoord) * KPBR_PI * 2.0;
                float cosT = cos(theta);
                float sinT = sin(theta);

                float3 T_r = T0 * cosT + B0 * sinT;
                float3 B_r = -T0 * sinT + B0 * cosT;
                float3x3 TBN = float3x3(T_r, B_r, N);

                // View→Clip の順方向は通常の射影行列で問題ない
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

                    // サンプル点を View → Clip → Screen UV に射影
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

                    float sceneDepth = GetLinearDepth(rawDepth, sampleUV);
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

            // -----------------------------------------------------------------
            // Color Correction (HSV + Brightness/Contrast)
            // -----------------------------------------------------------------
            float3 KTBCC_RGB2HSV(float3 c)
            {
                float4 K = float4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
                float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
                float  d = q.x - min(q.w, q.y);
                const float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }

            float3 KTBCC_HSV2RGB(float3 c)
            {
                float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
            }

            float3 KTBCC_Apply(float3 rawColor, float mask)
            {
                float3 hsv = KTBCC_RGB2HSV(max(rawColor, 0.0));
                hsv.x = frac(hsv.x + _CCHueShift);
                hsv.y = saturate(hsv.y * _CCSaturation);
                float3 rgb = KTBCC_HSV2RGB(hsv);

                rgb *= _CCBrightness;
                rgb  = (rgb - 0.5) * _CCContrast + 0.5;

                rgb = max(rgb, 0.0);
                return lerp(rawColor, rgb, saturate(mask));
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

            fixed4 frag(v2f i, float facing : VFACE) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float faceSign = (facing > 0.0) ? 1.0 : -1.0;

                fixed4 mainTex = tex2D(_MainTex, i.uv);

                #if defined(_COLOR_CORRECTION_ON)
                    float ccMask = tex2D(_ColorCorrectionMask, i.uv).r;
                    mainTex.rgb = KTBCC_Apply(mainTex.rgb, ccMask);
                #endif

                fixed4 albedoTex = mainTex * _Color;
                float3 albedo    = albedoTex.rgb;
                float  alpha     = albedoTex.a;

                #if defined(_SURFACEMODE_CUTOUT)
                    clip(alpha - _Cutoff);
                #endif

                float  metallic  = tex2D(_MetallicMap,  i.uv).r * _Metallic;
                float  roughness = tex2D(_RoughnessMap, i.uv).r * _Roughness;
                roughness = max(roughness, KPBR_MIN_ROUGHNESS);

                float3 normalTex = UnpackNormal(tex2D(_NormalMap, i.uv));
                normalTex.xy *= _NormalMapStrength;
                normalTex = normalize(normalTex);

                float3x3 TBN = float3x3(normalize(i.tangentWS) * faceSign,
                                        normalize(i.bitanWS)   * faceSign,
                                        normalize(i.normalWS)  * faceSign);
                float3 N = normalize(mul(normalTex, TBN));
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float3 viewN    = normalize(mul((float3x3)UNITY_MATRIX_V, N));

                #if defined(_SSAO_ON)
                    float3 P  = mul(UNITY_MATRIX_V, float4(i.worldPos, 1.0)).xyz;
                    float ao = ComputeSSAO(screenUV, P, viewN);
                #else
                    float ao = 1.0;
                #endif

                KPBRSurface s;
                s.albedo    = albedo;
                s.metallic  = metallic;
                s.roughness = roughness;
                s.N         = N;
                s.V         = V;
                s.worldPos  = i.worldPos;
                s.occlusion = ao;

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                KPBRLightDatas datas;
                KPBR_ComputeLights(datas, s,
                                     _LightDirection.xyz,
                                     _LightColor.rgb,
                                     atten);

                float3 rimL, rimLCol;
                KPBR_GetDirectionalLight(_LightDirection.xyz, _LightColor.rgb, rimL, rimLCol);

                // Rim
                #if defined(_RIM_ON)
                    KPBRRimParams rimP;
                    rimP.backRimColor      = _BackRimColor.rgb;
                    rimP.backRimPower      = _BackRimPower;
                    rimP.backRimIntensity  = _BackRimIntensity;
                    rimP.innerRimColor     = _InnerRimColor.rgb;
                    rimP.innerRimPower     = _InnerRimPower;
                    rimP.innerRimIntensity = _InnerRimIntensity;

                    float3 rim = KPBR_ComputeRim(s, rimL, rimLCol, atten, rimP);
                #else
                    float3 rim = 0.0;
                #endif

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

                #if defined(_SURFACEMODE_OPAQUE) || defined(_SURFACEMODE_CUTOUT)
                    alpha = 1.0;
                #elif defined(_SURFACEMODE_TRANSPARENT)
                    alpha = saturate(alpha);
                #endif

                fixed4 col = fixed4(finalColor, alpha);

                // #if defined(_SURFACEMODE_TRANSPARENT)
                //     #if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD)
                //         float fogCoord = i.fogCoord;
                //         #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
                //             UNITY_CALC_FOG_FACTOR_RAW(fogCoord);
                //             col.rgb = lerp(unity_FogColor.rgb, col.rgb, saturate(unityFogFactor));
                //         #endif
                //     #endif
                // #else
                //     UNITY_APPLY_FOG(i.fogCoord, col);
                // #endif

                UNITY_APPLY_FOG(i.fogCoord, col);

                return col;
            }
            ENDCG
        }

        Pass
        {
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            CGPROGRAM
            #pragma vertex   vertShadow
            #pragma fragment fragShadow
            #pragma multi_compile_shadowcaster
            #pragma shader_feature_local _SURFACEMODE_OPAQUE _SURFACEMODE_CUTOUT _SURFACEMODE_TRANSPARENT

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4    _MainTex_ST;
            fixed4    _Color;
            float     _Cutoff;

            struct appdataShadow
            {
                float4 vertex  : POSITION;
                float3 normal  : NORMAL;
                float2 uv      : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2fShadow
            {
                V2F_SHADOW_CASTER;
                float2 uv : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2fShadow vertShadow(appdataShadow v)
            {
                v2fShadow o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 fragShadow(v2fShadow i) : SV_Target
            {
                fixed4 c = tex2D(_MainTex, i.uv) * _Color;

                #if defined(_SURFACEMODE_CUTOUT)
                    clip(c.a - _Cutoff);
                #endif

                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
