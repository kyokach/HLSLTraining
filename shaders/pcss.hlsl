#ifndef KPBR_PCSS_INCLUDED
#define KPBR_PCSS_INCLUDED

// =====================================================================
//  KPBR PCSS-like Soft Shadows
//
//  Depth-aware multi-tap sampling of Unity's screen-space shadow map.
//  Active only when SHADOWS_SCREEN is defined (directional light, PC).
//
//  The kernel radius scales with receiver depth so that shadows are
//  sharp at contact and progressively softer further from the caster,
//  approximating the penumbra behaviour of area light sources.
//
//  Requirements (provided by the including shader):
//    - _CameraDepthTexture  (UNITY_DECLARE_DEPTH_TEXTURE)
//    - _ScreenParams
//    - AutoLight.cginc included (for _ShadowMapTexture)
// =====================================================================

#if defined(SHADOWS_SCREEN) && !defined(UNITY_NO_SCREENSPACE_SHADOWS)

// 16-sample Poisson disk (pre-rotated, unit circle)
static const float2 KPBR_PCSS_POISSON[16] =
{
    float2(-0.9404, -0.1060),  float2( 0.4596, -0.7764),
    float2( 0.3400, -0.1684),  float2(-0.3791,  0.7940),
    float2(-0.5965, -0.6154),  float2( 0.8588,  0.1690),
    float2( 0.1575,  0.8750),  float2(-0.1620, -0.4564),
    float2( 0.7104,  0.5948),  float2(-0.6880,  0.2846),
    float2( 0.0698, -0.9652),  float2(-0.9282,  0.3540),
    float2( 0.5560, -0.4958),  float2(-0.2664, -0.8404),
    float2( 0.9570,  -0.0836), float2(-0.4338,  0.1472)
};

// Interleaved gradient noise for per-pixel sample rotation
float KPBR_PCSS_Noise(float2 screenPixel)
{
    return frac(52.9829189 * frac(dot(screenPixel, float2(0.06711056, 0.00583715))));
}

// -----------------------------------------------------------------
//  Main entry point
//
//  screenPos : float4 from ComputeScreenPos (xy/w = screen UV)
//  softness  : user parameter [0..1], represents relative light size
//
//  Returns shadow attenuation in [0, 1].
// -----------------------------------------------------------------
float KPBR_SamplePCSS(float4 screenPos, float softness)
{
    float2 screenUV = screenPos.xy / screenPos.w;

    // --- Centre sample (fallback & early out) --------------------
    float centerShadow = tex2D(_ShadowMapTexture, screenUV).r;
    if (softness < 0.001) return centerShadow;

    // --- Receiver depth for kernel scaling -----------------------
    float rawDepth   = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,
                           UnityStereoTransformScreenSpaceTex(screenUV));
    float linearDepth = LinearEyeDepth(rawDepth);

    // Kernel radius in pixels: grows with depth, scaled by softness.
    // The 0.15 factor is tuned so that softness=1 gives a
    // visually reasonable penumbra at ~2 m distance.
    float kernelPx = softness * linearDepth * 0.15;
    float2 pixelSize = 1.0 / _ScreenParams.xy;

    // Per-pixel rotation to break banding
    float2 pixelCoord = floor(screenUV * _ScreenParams.xy);
    float  angle = KPBR_PCSS_Noise(pixelCoord) * 6.28318530718;
    float  cosA  = cos(angle);
    float  sinA  = sin(angle);

    float shadowAccum = 0.0;
    float weightAccum = 0.0;

    [unroll]
    for (int i = 0; i < 16; i++)
    {
        float2 p = KPBR_PCSS_POISSON[i];
        // Rotate sample
        float2 rotated = float2(p.x * cosA - p.y * sinA,
                                p.x * sinA + p.y * cosA);
        float2 offset   = rotated * kernelPx * pixelSize;
        float2 sampleUV = screenUV + offset;

        // Shadow sample
        float sShadow = tex2D(_ShadowMapTexture, sampleUV).r;

        // Depth-aware weighting: reduce influence at depth
        // discontinuities to keep contact shadows sharp.
        float sRawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,
                              UnityStereoTransformScreenSpaceTex(sampleUV));
        float sLinear   = LinearEyeDepth(sRawDepth);
        float depthDiff = abs(sLinear - linearDepth);
        float dWeight   = 1.0 / (1.0 + depthDiff * 50.0 / max(linearDepth, 0.01));

        shadowAccum += sShadow * dWeight;
        weightAccum += dWeight;
    }

    return shadowAccum / max(weightAccum, 0.001);
}

#endif // SHADOWS_SCREEN && !UNITY_NO_SCREENSPACE_SHADOWS
#endif // KPBR_PCSS_INCLUDED
