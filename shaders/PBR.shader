Shader "KTB/KPBR"
{
    Properties
    {
        // =============================================================
        //  Surface
        // =============================================================
        [Header(Surface)]
        _MainTex                        ("Albedo", 2D) = "white" {}
        _Color                          ("Color Tint", Color) = (1,1,1,1)

        // =============================================================
        //  Color Correction
        // =============================================================
        [Header(Color Correction)]
        [Toggle(_COLOR_CORRECTION_ON)]
        _ColorCorrectionEnabled         ("Enable Color Correction", Float) = 0
        _ColorCorrectionMask            ("Correction Mask (R)", 2D) = "white" {}
        _CCHueShift                     ("Hue Shift", Range(-0.5, 0.5)) = 0.0
        _CCSaturation                   ("Saturation", Range(0, 2)) = 1.0
        _CCBrightness                   ("Brightness", Range(0, 2)) = 1.0
        _CCContrast                     ("Contrast", Range(0, 2)) = 1.0

        // =============================================================
        //  Rendering Mode
        //    Opaque      : SrcBlend=One      DstBlend=Zero              ZWrite=On   Queue=Geometry
        //    Cutout      : SrcBlend=One      DstBlend=Zero              ZWrite=On   Queue=AlphaTest
        //    Transparent : SrcBlend=SrcAlpha DstBlend=OneMinusSrcAlpha  ZWrite=Off  Queue=Transparent
        // =============================================================
        [Header(Rendering Mode)]
        [KeywordEnum(Opaque, Cutout, Transparent)]
        _SurfaceMode                    ("Surface Mode", Float) = 0
        _Cutoff                         ("Alpha Cutoff (Cutout)", Range(0,1)) = 0.5
        [Enum(UnityEngine.Rendering.BlendMode)]
        _SrcBlend                       ("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)]
        _DstBlend                       ("Dst Blend", Float) = 0
        [Enum(Off, 0, On, 1)]
        _ZWrite                         ("ZWrite", Float) = 1
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                           ("Cull Mode (Off=Both, Front=Back face, Back=Front face)", Float) = 2

        // =============================================================
        //  PBR Parameters
        // =============================================================
        [Header(PBR Parameters)]
        _MetallicMap                    ("Metallic Map", 2D) = "white" {}
        _Metallic                       ("Metallic", Range(0,1)) = 0.0
        _RoughnessMap                   ("Roughness Map", 2D) = "white" {}
        _Roughness                      ("Roughness", Range(0.04, 1.0)) = 0.5

        // =============================================================
        //  Normal
        // =============================================================
        [Header(Normal)]
        _NormalMap                      ("Normal Map", 2D) = "bump" {}
        _NormalMapStrength              ("Normal Map Strength", Range(0,2)) = 1.0

        // =============================================================
        //  Detail Map
        // =============================================================
        [Header(Detail)]
        [Toggle(_DETAIL_ON)]
        _DetailEnabled                  ("Enable Detail Maps", Float) = 0
        _DetailAlbedoMap                ("Detail Albedo (gray=neutral)", 2D) = "gray" {}
        _DetailAlbedoStrength           ("Detail Albedo Strength", Range(0,1)) = 1.0
        _DetailNormalMap                ("Detail Normal Map", 2D) = "bump" {}
        _DetailNormalMapStrength        ("Detail Normal Strength", Range(0,2)) = 1.0
        _DetailMask                     ("Detail Mask (R)", 2D) = "white" {}
        _DetailUVScale                  ("Detail UV Tiling", Float) = 4.0

        // =============================================================
        //  MatCap
        // =============================================================
        [Header(MatCap)]
        [Toggle(_MATCAP_ON)]
        _MatCapEnabled                  ("Enable MatCap", Float) = 0
        [KeywordEnum(Additive, Multiply, Screen, Linear)]
        _MatCapBlendMode                ("Blend Mode", Float) = 0
        _MatCap                         ("Material Capture", 2D) = "black" {}
        _MatCapBlur                     ("MatCap Blur", Range(0, 8)) = 0.0
        _MatCapStrength                 ("MatCap Strength", Range(0,1)) = 0.0
        _MatCapMask                     ("MatCap Mask", 2D) = "white" {}

        // =============================================================
        //  Emission
        // =============================================================
        [Header(Emission)]
        [Toggle(_EMISSION_ON)]
        _EmissionEnabled                ("Enable Emission", Float) = 0
        _EmissionMap                    ("Emission Map", 2D) = "black" {}
        [HDR]
        _EmissionColor                  ("Emission Color", Color) = (0,0,0,1)
        _EmissionIntensity              ("Emission Intensity", Range(0, 20)) = 1.0

        // =============================================================
        //  Lighting
        // =============================================================
        [Header(Lighting)]
        _DirectLightIntensity           ("Direct Light Intensity", Range(0,10)) = 1.0
        _IndirectLightIntensity         ("Indirect Light Intensity", Range(0,10)) = 1.0
        _LightClampMax                  ("Max Light Luminance", Range(0.1, 10)) = 1.5

        // =============================================================
        //  Rim Lighting
        // =============================================================
        [Header(Rim Lighting)]
        [Toggle(_RIM_ON)]
        _RimEnabled                     ("Enable Rim", Float) = 0
        _BackRimColor                   ("Backlight Rim Color", Color) = (1, 1, 1, 1)
        _BackRimPower                   ("Backlight Rim Power", Range(0.5, 8)) = 3.0
        _BackRimIntensity               ("Backlight Rim Intensity", Range(0, 5)) = 0.3
        _InnerRimColor                  ("Inner Rim Color (Shade)", Color) = (0.5, 0.5, 0.5, 1)
        _InnerRimPower                  ("Inner Rim Power", Range(0.5, 8)) = 4.0
        _InnerRimIntensity              ("Inner Rim Intensity", Range(0, 2)) = 0.5

        // =============================================================
        //  Shadow
        // =============================================================
        [Header(Shadow)]
        _ShadowColor                    ("Shadow Color", Color) = (0.1, 0.1, 0.15, 1)
        _ShadowSoftness                 ("Shadow Softness (Wrap)", Range(0, 0.5)) = 0.0

        // =============================================================
        //  PCSS Soft Shadow
        // =============================================================
        [Header(PCSS Soft Shadow)]
        [Toggle(_PCSS_ON)]
        _PCSSEnabled                    ("Enable PCSS", Float) = 0
        _PCSSSoftness                   ("Shadow Softness", Range(0, 1)) = 0.3

        // =============================================================
        //  SSAO
        // =============================================================
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

        // =============================================================
        //  VRChat Lighting
        // =============================================================
        [Header(VRChat Lighting)]
        [Toggle(KPBR_VRCLIGHTVOLUMES_WITHOUTPACKAGE)]
        _VRCLightVolumesEnabled         ("Enable VRC Light Volumes", Float) = 0
        [Toggle(KPBR_VRCLIGHTVOLUMES)]
        _VRCLightVolumesEnabledOrg      ("Enable VRC Light Volumes", Float) = 0

        // =============================================================
        //  Fallback Light
        // =============================================================
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
            #pragma shader_feature_local _PCSS_ON
            #pragma shader_feature_local _EMISSION_ON
            #pragma shader_feature_local _DETAIL_ON
            #pragma shader_feature_local _SURFACEMODE_OPAQUE _SURFACEMODE_CUTOUT _SURFACEMODE_TRANSPARENT
            #pragma shader_feature_local _COLOR_CORRECTION_ON
            #pragma shader_feature_local _VRCLIGHTVOLUMES_WITHOUTPACKAGE
            #pragma shader_feature_local _VRCLIGHTVOLUMES
            #pragma multi_compile_fog

            // ---------------------------------------------------------
            //  Includes
            // ---------------------------------------------------------
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #include "core.hlsl"
            #include "color_correction.hlsl"

            #if defined(_SSAOQUALITY_SAMPLES_8)
                #define SSAO_SAMPLE_COUNT 8
            #elif defined(_SSAOQUALITY_SAMPLES_32)
                #define SSAO_SAMPLE_COUNT 32
            #else
                #define SSAO_SAMPLE_COUNT 16
            #endif

            #if defined(_SSAO_ON)
                #include "ssao.hlsl"
            #endif

            #if defined(_PCSS_ON)
                #include "pcss.hlsl"
            #endif

            // ---------------------------------------------------------
            //  Vertex I/O
            // ---------------------------------------------------------
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

            // ---------------------------------------------------------
            //  Uniforms
            // ---------------------------------------------------------
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            float4      _CameraDepthTexture_TexelSize;

            // Surface
            sampler2D   _MainTex;
            float4      _MainTex_ST;
            fixed4      _Color;

            // Color Correction
            sampler2D   _ColorCorrectionMask;
            float       _CCHueShift;
            float       _CCSaturation;
            float       _CCBrightness;
            float       _CCContrast;

            // PBR
            sampler2D   _MetallicMap;
            float       _Metallic;
            sampler2D   _RoughnessMap;
            float       _Roughness;
            sampler2D   _NormalMap;
            float       _NormalMapStrength;

            // Detail (#14)
            sampler2D   _DetailAlbedoMap;
            float       _DetailAlbedoStrength;
            sampler2D   _DetailNormalMap;
            float       _DetailNormalMapStrength;
            sampler2D   _DetailMask;
            float       _DetailUVScale;

            // MatCap
            sampler2D   _MatCap;
            sampler2D   _MatCapMask;
            float       _MatCapStrength;
            float       _MatCapBlur;

            // Emission (#9)
            sampler2D   _EmissionMap;
            fixed4      _EmissionColor;
            float       _EmissionIntensity;

            // Lighting
            float       _DirectLightIntensity;
            float       _IndirectLightIntensity;
            float       _LightClampMax;

            // Rim
            fixed4      _BackRimColor;
            float       _BackRimPower;
            float       _BackRimIntensity;
            fixed4      _InnerRimColor;
            float       _InnerRimPower;
            float       _InnerRimIntensity;

            // Shadow
            fixed4      _ShadowColor;
            float       _ShadowSoftness;

            // PCSS (#2)
            float       _PCSSSoftness;

            // SSAO
            float       _SSAORadius;
            float       _SSAOBias;
            float       _SSAOIntensity;
            float       _SSAOFalloff;
            float       _SSAOThickness;

            // Fallback Light
            float4      _LightDirection;
            fixed4      _LightColor;

            // Alpha Cutout
            float       _Cutoff;

            // ---------------------------------------------------------
            //  Vertex Shader
            // ---------------------------------------------------------
            v2f vert(appdata v)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
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

            // ---------------------------------------------------------
            //  Fragment Helpers
            // ---------------------------------------------------------
            float3 ComputeWorldNormal(v2f i, float faceSign)
            {
                float3 normalTex = UnpackNormal(tex2D(_NormalMap, i.uv));
                normalTex.xy *= _NormalMapStrength;
                normalTex = normalize(normalTex);

                #if defined(_DETAIL_ON)
                    float2 detailUV   = i.uv * _DetailUVScale;
                    float  detailMask = tex2D(_DetailMask, i.uv).r;
                    float3 detailN    = UnpackNormal(tex2D(_DetailNormalMap, detailUV));
                    detailN.xy *= _DetailNormalMapStrength;
                    detailN = normalize(detailN);
                    // Whiteout blending via UnityStandardUtils
                    float3 blendedDetail = lerp(float3(0, 0, 1), detailN, detailMask);
                    normalTex = BlendNormals(normalTex, blendedDetail);
                #endif

                float3x3 TBN = float3x3(
                    normalize(i.tangentWS) * faceSign,
                    normalize(i.bitanWS)   * faceSign,
                    normalize(i.normalWS)  * faceSign);

                return normalize(mul(normalTex, TBN));
            }

            float3 ApplyDetailAlbedo(float3 albedo, float2 uv)
            {
                #if defined(_DETAIL_ON)
                    float2 detailUV      = uv * _DetailUVScale;
                    float  detailMask    = tex2D(_DetailMask, uv).r;
                    float3 detailAlbedo  = tex2D(_DetailAlbedoMap, detailUV).rgb;
                    // Unity standard detail blending: gray (0.5) = no change
                    float  blendStrength = detailMask * _DetailAlbedoStrength;
                    albedo *= lerp(1.0, detailAlbedo * 2.0, blendStrength);
                #endif
                return albedo;
            }

            KPBRSurface BuildSurface(float3 albedo, float2 uv,
                                      float3 N, float3 V,
                                      float3 worldPos, float ao)
            {
                KPBRSurface s;
                s.albedo    = albedo;
                s.metallic  = tex2D(_MetallicMap,  uv).r * _Metallic;
                s.roughness = max(tex2D(_RoughnessMap, uv).r * _Roughness, KPBR_MIN_ROUGHNESS);
                s.N         = N;
                s.V         = V;
                s.worldPos  = worldPos;
                s.occlusion = ao;
                return s;
            }

            float3 ComputeShadowTint(float3 N, float atten)
            {
                float NdotL  = saturate(dot(N, normalize(_WorldSpaceLightPos0.xyz)));
                float wrapped = saturate((NdotL + _ShadowSoftness) / (1.0 + _ShadowSoftness));
                return lerp(_ShadowColor.rgb, float3(1, 1, 1), atten * wrapped);
            }

            float3 ApplyMatCap(float3 color, float3 viewN, float2 uv)
            {
                #if defined(_MATCAP_ON)
                    float2 mUV          = viewN.xy * 0.495 + 0.5;
                    float3 matcap       = tex2Dlod(_MatCap, float4(mUV, 0, _MatCapBlur)).rgb;
                    fixed  matcapMask   = tex2D(_MatCapMask, uv).r;
                    float  matcapFactor = matcapMask * _MatCapStrength;

                    #if defined(_MATCAPBLENDMODE_ADDITIVE)
                        color += matcap * matcapFactor;
                    #elif defined(_MATCAPBLENDMODE_MULTIPLY)
                        color *= lerp(1.0, matcap, matcapFactor);
                    #elif defined(_MATCAPBLENDMODE_LINEAR)
                        color = lerp(color, matcap, matcapFactor);
                    #else // Screen — now uses matcapFactor like the others (#6)
                        float3 screenBlend = 1.0 - (1.0 - color) * (1.0 - matcap);
                        color = lerp(color, screenBlend, matcapFactor);
                    #endif
                #endif
                return color;
            }

            float ResolveFinalAlpha(float alpha)
            {
                #if defined(_SURFACEMODE_OPAQUE) || defined(_SURFACEMODE_CUTOUT)
                    return 1.0;
                #elif defined(_SURFACEMODE_TRANSPARENT)
                    return saturate(alpha);
                #else
                    return 1.0;
                #endif
            }

            // ---------------------------------------------------------
            //  Fragment Shader
            // ---------------------------------------------------------
            fixed4 frag(v2f i, float facing : VFACE) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float faceSign = (facing > 0.0) ? 1.0 : -1.0;

                // --- Albedo & Color Correction -----------------------
                fixed4 mainTex = tex2D(_MainTex, i.uv);

                #if defined(_COLOR_CORRECTION_ON)
                    float ccMask = tex2D(_ColorCorrectionMask, i.uv).r;
                    mainTex.rgb = KPBR_ApplyColorCorrection(
                        mainTex.rgb, ccMask,
                        _CCHueShift, _CCSaturation, _CCBrightness, _CCContrast);
                #endif

                fixed4 albedoTex = mainTex * _Color;
                float3 albedo    = albedoTex.rgb;
                float  alpha     = albedoTex.a;

                #if defined(_SURFACEMODE_CUTOUT)
                    clip(alpha - _Cutoff);
                #endif

                // --- Detail Albedo -----------------------------
                albedo = ApplyDetailAlbedo(albedo, i.uv);

                // --- Geometry (with Detail Normal) -------------------
                float3 N = ComputeWorldNormal(i, faceSign);
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float3 viewN    = normalize(mul((float3x3)UNITY_MATRIX_V, N));

                // --- SSAO -----------
                #if defined(_SSAO_ON)
                    float3 viewPos = mul(UNITY_MATRIX_V, float4(i.worldPos, 1.0)).xyz;
                    float  ao = KPBR_ComputeSSAO(
                        screenUV, viewPos, viewN,
                        _SSAORadius, _SSAOBias, _SSAOIntensity,
                        _SSAOFalloff, _SSAOThickness);
                #else
                    float ao = 1.0;
                #endif

                // --- Surface & Lighting ------------------------------
                KPBRSurface s = BuildSurface(albedo, i.uv, N, V, i.worldPos, ao);

                // Shadow attenuation — PCSS or standard
                #if defined(_PCSS_ON) && defined(SHADOWS_SCREEN) && !defined(UNITY_NO_SCREENSPACE_SHADOWS)
                    float atten = KPBR_SamplePCSS(i.screenPos, _PCSSSoftness);
                #else
                    UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
                #endif

                KPBRLightDatas datas;
                KPBR_ComputeLights(datas, s,
                                     _LightDirection.xyz, _LightColor.rgb,
                                     atten, _LightClampMax);

                // --- Rim Lighting ----------
                float3 rim = 0.0;
                #if defined(_RIM_ON)
                    KPBRRimParams rimP;
                    rimP.backRimColor      = _BackRimColor.rgb;
                    rimP.backRimPower      = _BackRimPower;
                    rimP.backRimIntensity  = _BackRimIntensity;
                    rimP.innerRimColor     = _InnerRimColor.rgb;
                    rimP.innerRimPower     = _InnerRimPower;
                    rimP.innerRimIntensity = _InnerRimIntensity;

                    rim = KPBR_ComputeRim(s, datas.mainLightDir,
                                          datas.mainLightCol, atten, rimP);
                #endif

                // --- Compose -----------------------------------------
                float3 shadowTint    = ComputeShadowTint(N, atten);
                float3 aoMultiBounce = KPBR_MultiBounceAO(ao, albedo);

                float3 direct   = (datas.directDiffuse + datas.directSpecular)
                                * _DirectLightIntensity * shadowTint;
                float3 indirect = (datas.indirectDiffuse + datas.indirectSpecular)
                                * _IndirectLightIntensity * aoMultiBounce;

                float3 finalColor = direct + indirect + rim * ao;

                // --- Emission (#9) -----------------------------------
                #if defined(_EMISSION_ON)
                    float3 emission = tex2D(_EmissionMap, i.uv).rgb
                                    * _EmissionColor.rgb * _EmissionIntensity;
                    finalColor += emission;
                #endif

                // --- MatCap ------------------------------------------
                finalColor = ApplyMatCap(finalColor, viewN, i.uv);

                // --- Alpha & Fog -------------------------------------
                fixed4 col = fixed4(finalColor, ResolveFinalAlpha(alpha));
                UNITY_APPLY_FOG(i.fogCoord, col);

                return col;
            }
            ENDCG
        }

        Pass
        {
            Tags { "LightMode"="ForwardAdd" }

            Blend One One
            ZWrite Off
            ZTest LEqual
            Cull [_Cull]

            CGPROGRAM
            #pragma vertex vertAdd
            #pragma fragment fragAdd
            #pragma multi_compile_fwdadd_fullshadows
            #pragma shader_feature_local _SURFACEMODE_OPAQUE _SURFACEMODE_CUTOUT _SURFACEMODE_TRANSPARENT
            #pragma shader_feature_local _DETAIL_ON
            #pragma shader_feature_local _COLOR_CORRECTION_ON
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #include "core.hlsl"
            #include "color_correction.hlsl"

            // ---------------------------------------------------------
            //  Vertex I/O (ForwardAdd)
            // ---------------------------------------------------------
            struct appdataAdd
            {
                float4 pos     : POSITION;
                float2 uv      : TEXCOORD0;
                float3 normal  : NORMAL;
                float4 tangent : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2fAdd
            {
                float4 pos       : SV_POSITION;
                float2 uv        : TEXCOORD0;
                float3 normalWS  : TEXCOORD1;
                float3 worldPos  : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitanWS   : TEXCOORD4;
                SHADOW_COORDS(5)
                UNITY_FOG_COORDS(6)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            // ---------------------------------------------------------
            //  Uniforms (ForwardAdd shares many with ForwardBase)
            // ---------------------------------------------------------
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

            sampler2D   _DetailAlbedoMap;
            float       _DetailAlbedoStrength;
            sampler2D   _DetailNormalMap;
            float       _DetailNormalMapStrength;
            sampler2D   _DetailMask;
            float       _DetailUVScale;

            float       _DirectLightIntensity;
            float       _LightClampMax;

            fixed4      _ShadowColor;
            float       _ShadowSoftness;
            float       _Cutoff;

            // ---------------------------------------------------------
            //  Vertex Shader (ForwardAdd)
            // ---------------------------------------------------------
            v2fAdd vertAdd(appdataAdd v)
            {
                v2fAdd o;
                UNITY_INITIALIZE_OUTPUT(v2fAdd, o);
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.pos       = UnityObjectToClipPos(v.pos);
                o.uv        = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS  = UnityObjectToWorldNormal(v.normal);
                o.worldPos  = mul(unity_ObjectToWorld, v.pos).xyz;
                o.tangentWS = UnityObjectToWorldDir(v.tangent.xyz);
                o.bitanWS   = cross(o.normalWS, o.tangentWS) * v.tangent.w;

                TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            // ---------------------------------------------------------
            //  Fragment Helpers (ForwardAdd)
            // ---------------------------------------------------------
            float3 ComputeWorldNormalAdd(v2fAdd i, float faceSign)
            {
                float3 normalTex = UnpackNormal(tex2D(_NormalMap, i.uv));
                normalTex.xy *= _NormalMapStrength;
                normalTex = normalize(normalTex);

                #if defined(_DETAIL_ON)
                    float2 detailUV   = i.uv * _DetailUVScale;
                    float  detailMask = tex2D(_DetailMask, i.uv).r;
                    float3 detailN    = UnpackNormal(tex2D(_DetailNormalMap, detailUV));
                    detailN.xy *= _DetailNormalMapStrength;
                    detailN = normalize(detailN);
                    float3 blendedDetail = lerp(float3(0, 0, 1), detailN, detailMask);
                    normalTex = BlendNormals(normalTex, blendedDetail);
                #endif

                float3x3 TBN = float3x3(
                    normalize(i.tangentWS) * faceSign,
                    normalize(i.bitanWS)   * faceSign,
                    normalize(i.normalWS)  * faceSign);

                return normalize(mul(normalTex, TBN));
            }

            float3 ApplyDetailAlbedoAdd(float3 albedo, float2 uv)
            {
                #if defined(_DETAIL_ON)
                    float2 detailUV      = uv * _DetailUVScale;
                    float  detailMask    = tex2D(_DetailMask, uv).r;
                    float3 detailAlbedo  = tex2D(_DetailAlbedoMap, detailUV).rgb;
                    float  blendStrength = detailMask * _DetailAlbedoStrength;
                    albedo *= lerp(1.0, detailAlbedo * 2.0, blendStrength);
                #endif
                return albedo;
            }

            // ---------------------------------------------------------
            //  Fragment Shader (ForwardAdd)
            // ---------------------------------------------------------
            fixed4 fragAdd(v2fAdd i, float facing : VFACE) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float faceSign = (facing > 0.0) ? 1.0 : -1.0;

                // --- Albedo ------------------------------------------
                fixed4 mainTex = tex2D(_MainTex, i.uv);

                #if defined(_COLOR_CORRECTION_ON)
                    float ccMask = tex2D(_ColorCorrectionMask, i.uv).r;
                    mainTex.rgb = KPBR_ApplyColorCorrection(
                        mainTex.rgb, ccMask,
                        _CCHueShift, _CCSaturation, _CCBrightness, _CCContrast);
                #endif

                fixed4 albedoTex = mainTex * _Color;
                float3 albedo    = albedoTex.rgb;
                float  alpha     = albedoTex.a;

                #if defined(_SURFACEMODE_CUTOUT)
                    clip(alpha - _Cutoff);
                #endif

                albedo = ApplyDetailAlbedoAdd(albedo, i.uv);

                // --- Geometry ----------------------------------------
                float3 N = ComputeWorldNormalAdd(i, faceSign);
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                // --- Surface -----------------------------------------
                KPBRSurface s;
                s.albedo    = albedo;
                s.metallic  = tex2D(_MetallicMap,  i.uv).r * _Metallic;
                s.roughness = max(tex2D(_RoughnessMap, i.uv).r * _Roughness, KPBR_MIN_ROUGHNESS);
                s.N         = N;
                s.V         = V;
                s.worldPos  = i.worldPos;
                s.occlusion = 1.0; // No SSAO in add pass

                // --- Light direction ---------------------------------
                float3 L;
                #if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
                    L = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
                #else
                    L = normalize(_WorldSpaceLightPos0.xyz);
                #endif

                // --- Shadow & attenuation ----------------------------
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                // --- Evaluate single per-pixel light -----------------
                KPBRLightDatas addDatas;
                KPBR_ComputeForwardAdd(addDatas, s, L, _LightColor0.rgb,
                                        atten, _LightClampMax);

                float3 result = (addDatas.directDiffuse + addDatas.directSpecular)
                              * _DirectLightIntensity;

                // --- Transparency ------------------------------------
                #if defined(_SURFACEMODE_TRANSPARENT)
                    alpha = saturate(alpha);
                #else
                    alpha = 1.0;
                #endif

                fixed4 col = fixed4(result, alpha);
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

            // Interleaved gradient noise for dithered transparency
            float DitherNoise(float2 screenPixel)
            {
                return frac(52.9829189 * frac(dot(screenPixel, float2(0.06711056, 0.00583715))));
            }

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

                #elif defined(_SURFACEMODE_TRANSPARENT)
                    float dither = DitherNoise(i.pos.xy);
                    clip(c.a - dither);
                #endif

                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
