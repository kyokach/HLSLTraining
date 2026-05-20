#ifndef KPBR_SSAO_INCLUDED
#define KPBR_SSAO_INCLUDED

// =====================================================================
//  KPBR Screen-Space Ambient Occlusion
//
//  Depth-buffer based SSAO with rotated hemisphere kernel.
//  Designed to run per-object (no post-process) for VRChat.
//
//  Includes a depth-texture validity check so that SSAO gracefully
//  falls back to ao=1.0 when _CameraDepthTexture is unavailable (#3).
//
//  Requirements:
//    - _CameraDepthTexture declared by the including shader
//    - KPBR_PI defined (from core.hlsl)
//    - SSAO_SAMPLE_COUNT defined before including this file
// =====================================================================

// ---------------------------------------------------------------------
//  Stereo-Aware Projection Helpers
// ---------------------------------------------------------------------
float4x4 KPBR_GetStereoCameraProjection()
{
#if defined(USING_STEREO_MATRICES)
    return unity_StereoCameraProjection[unity_StereoEyeIndex];
#else
    return unity_CameraProjection;
#endif
}

float4x4 KPBR_GetStereoCameraInvProjection()
{
#if defined(USING_STEREO_MATRICES)
    return unity_StereoCameraInvProjection[unity_StereoEyeIndex];
#else
    return unity_CameraInvProjection;
#endif
}

// ---------------------------------------------------------------------
//  Depth Utilities
// ---------------------------------------------------------------------
float KPBR_GetLinearDepth(float zDepthFromMap, float2 screenUV)
{
#if defined(UNITY_REVERSED_Z)
    zDepthFromMap = 1.0 - zDepthFromMap;
    if (zDepthFromMap >= 1.0) return _ProjectionParams.z;
#endif

    float4 clipPos = float4(screenUV * 2.0 - 1.0, zDepthFromMap * 2.0 - 1.0, 1.0);
    float4 camPos  = mul(KPBR_GetStereoCameraInvProjection(), clipPos);
    return -camPos.z / camPos.w;
}

float3 KPBR_ReconstructViewPos(float2 screenUV, float rawDepth)
{
    float z = rawDepth;
#if defined(UNITY_REVERSED_Z)
    z = 1.0 - z;
#endif

    float4 clipPos = float4(screenUV * 2.0 - 1.0, z * 2.0 - 1.0, 1.0);
    float4 viewPos = mul(KPBR_GetStereoCameraInvProjection(), clipPos);
    viewPos.xyz /= viewPos.w;
    return viewPos.xyz;
}

// ---------------------------------------------------------------------
//  Depth Texture Validity Check (#3)
//
//  Returns true if _CameraDepthTexture appears to contain real data.
//  When the world or camera doesn't generate it, the texture reads as
//  all-zero (reversed-Z) or all-one (normal-Z), indicating no data.
// ---------------------------------------------------------------------
bool KPBR_IsDepthTextureValid(float2 screenUV)
{
    float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,
                         UnityStereoTransformScreenSpaceTex(screenUV));
#if defined(UNITY_REVERSED_Z)
    // Reversed-Z: 1 = near, 0 = far / invalid
    return rawDepth > 1e-5;
#else
    // Normal-Z: 0 = near, 1 = far / invalid
    return rawDepth < (1.0 - 1e-5);
#endif
}

// ---------------------------------------------------------------------
//  Noise
// ---------------------------------------------------------------------
float KPBR_InterleavedGradientNoise(float2 p)
{
    return frac(52.9829189 * frac(dot(p, float2(0.06711056, 0.00583715))));
}

// ---------------------------------------------------------------------
//  Hemisphere Kernel (cosine-weighted, 32 samples)
// ---------------------------------------------------------------------
static const float3 KPBR_SSAO_KERNEL[32] =
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

// ---------------------------------------------------------------------
//  Main SSAO Computation
// ---------------------------------------------------------------------
float KPBR_ComputeSSAO(float2 screenUV, float3 viewPos, float3 viewNormal,
                        float radius, float bias, float intensity,
                        float falloff, float thickness)
{
    // --- Depth texture fallback (#3) ---------------------------------
    if (!KPBR_IsDepthTextureValid(screenUV))
        return 1.0;

    float2 pixelCoord = floor(screenUV * _ScreenParams.xy);

    float3 up = (abs(viewNormal.z) < 0.999) ? float3(0, 0, 1) : float3(1, 0, 0);
    float3 T0 = normalize(cross(up, viewNormal));
    float3 B0 = cross(viewNormal, T0);

    float4x4 proj = KPBR_GetStereoCameraProjection();

#if defined(UNITY_REVERSED_Z)
    const float FAR_EPS = 1e-6;
#else
    const float FAR_EPS = 1.0 - 1e-6;
#endif

    const int ROTATION_COUNT  = 4;
    const int SAMPLES_PER_ROT = SSAO_SAMPLE_COUNT / ROTATION_COUNT;
    float     aoAccum         = 0.0;

    for (int r = 0; r < ROTATION_COUNT; ++r)
    {
        float theta = KPBR_InterleavedGradientNoise(
            pixelCoord + float2(r * 73.137, r * 41.291)
        ) * KPBR_PI * 2.0;
        float cosT = cos(theta);
        float sinT = sin(theta);

        float3   T_r = T0 * cosT + B0 * sinT;
        float3   B_r = -T0 * sinT + B0 * cosT;
        float3x3 TBN = float3x3(T_r, B_r, viewNormal);

        float ao           = 0.0;
        float validSamples = 0.0;

        [unroll]
        for (int s = 0; s < SAMPLES_PER_ROT; ++s)
        {
            int    idx = r * SAMPLES_PER_ROT + s;
            float3 k   = KPBR_SSAO_KERNEL[idx];
            k.z = abs(k.z);

            float  t     = float(idx) / float(SSAO_SAMPLE_COUNT);
            float  scale = lerp(0.1, 1.0, t * t);
            float3 dir   = k * scale;

            float3 sampleOff = mul(dir * radius, TBN);
            float3 samplePos = viewPos + sampleOff;

            float4 sc = mul(proj, float4(samplePos, 1.0));
            if (sc.w < 1e-4) continue;

            float2 sampleUV = sc.xy / sc.w * 0.5 + 0.5;
            if (any(sampleUV < 0.0) || any(sampleUV > 1.0)) continue;

            float2 sampleUVStereo = UnityStereoTransformScreenSpaceTex(sampleUV);
            float  rawDepth       = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampleUVStereo);

#if defined(UNITY_REVERSED_Z)
            if (rawDepth <= FAR_EPS) continue;
#else
            if (rawDepth >= FAR_EPS) continue;
#endif

            float sceneDepth  = KPBR_GetLinearDepth(rawDepth, sampleUV);
            float sampleEyeZ  = -samplePos.z;
            float dynamicBias = bias * max(1.0, -viewPos.z * 0.05);
            float diff        = sampleEyeZ - sceneDepth;

            float rangeCheck           = smoothstep(1.0, 0.0, abs(diff) / radius);
            float biasAttenuation      = smoothstep(0.0, dynamicBias * 3.0, diff);
            float thicknessMax         = radius * thickness;
            float thicknessAttenuation = 1.0 - smoothstep(thicknessMax * 0.5, thicknessMax, diff);

            ao += biasAttenuation * thicknessAttenuation * pow(rangeCheck, falloff);
            validSamples += 1.0;
        }

        aoAccum += ao / max(validSamples, 1.0);
    }

    return saturate(1.0 - (aoAccum / float(ROTATION_COUNT)) * intensity);
}

#endif // KPBR_SSAO_INCLUDED
