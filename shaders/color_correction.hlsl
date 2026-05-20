#ifndef KPBR_COLOR_CORRECTION_INCLUDED
#define KPBR_COLOR_CORRECTION_INCLUDED

// =====================================================================
//  KPBR Color Correction
//
//  HSV-based hue shift, saturation, brightness, and contrast.
//  Controlled by a per-texel mask (R channel).
// =====================================================================

float3 KPBR_RGB2HSV(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float  d = q.x - min(q.w, q.y);
    const float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 KPBR_HSV2RGB(float3 c)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

float3 KPBR_ApplyColorCorrection(float3 rawColor, float mask,
                                   float hueShift, float saturation,
                                   float brightness, float contrast)
{
    float3 hsv = KPBR_RGB2HSV(max(rawColor, 0.0));
    hsv.x = frac(hsv.x + hueShift);
    hsv.y = saturate(hsv.y * saturation);
    float3 rgb = KPBR_HSV2RGB(hsv);

    rgb *= brightness;
    rgb  = (rgb - 0.5) * contrast + 0.5;
    rgb  = max(rgb, 0.0);

    return lerp(rawColor, rgb, saturate(mask));
}

#endif // KPBR_COLOR_CORRECTION_INCLUDED
