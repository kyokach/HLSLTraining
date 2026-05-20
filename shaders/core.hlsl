#ifndef KPBR_PBR_CORE_INCLUDED
#define KPBR_PBR_CORE_INCLUDED

// =====================================================================
//  KPBR Lighting Core
//
//  Physically based lighting pipeline for VRChat avatars.
//
//  Supported lights:
//    - Directional   (_WorldSpaceLightPos0 / _LightColor0)
//    - Point          (unity_4LightPosX0 ... / unity_LightColor[])
//    - Spot           (manual parameters)
//    - Environment    (Reflection Probe / unity_SpecCube0)
//    - Light Probe    (Spherical Harmonics via ShadeSH9)
//    - VRC Light Vol. (optional, via package or local include)
// =====================================================================

#include "UnityCG.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityImageBasedLighting.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"

#if defined(KPBR_VRCLIGHTVOLUMES)
    #include "Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc"
#elif defined(KPBR_VRCLIGHTVOLUMES_WITHOUTPACKAGE)
    #include "VRCLV/LightVolumes.cginc"
#endif

// ---------------------------------------------------------------------
//  Constants
// ---------------------------------------------------------------------
#define KPBR_PI            3.14159265359
#define KPBR_INV_PI        0.31830988618
#define KPBR_MIN_ROUGHNESS 0.04
#define KPBR_DIELECTRIC_F0 float3(0.04, 0.04, 0.04)
#define KPBR_EPS           1e-7

// ---------------------------------------------------------------------
//  Data Structures
// ---------------------------------------------------------------------
struct KPBRSurface
{
    float3 albedo;
    float  metallic;
    float  roughness;
    float3 N;
    float3 V;
    float3 worldPos;
    float  occlusion;
};

struct KPBRLight
{
    float3 direction;
    float3 color;
    float  NdotL;
};

struct KPBRLightDatas
{
    float3 directDiffuse;
    float3 directSpecular;
    float3 indirectDiffuse;
    float3 indirectSpecular;
    // Resolved main directional light (filled by KPBR_ComputeLights)
    float3 mainLightDir;
    float3 mainLightCol;
};

struct KPBRRimParams
{
    float3 backRimColor;
    float  backRimPower;
    float  backRimIntensity;
    float3 innerRimColor;
    float  innerRimPower;
    float  innerRimIntensity;
};

// ---------------------------------------------------------------------
//  Light Color Clamp (#20 - VRChat world defence)
// ---------------------------------------------------------------------
float3 KPBR_ClampLightColor(float3 color, float maxLuminance)
{
    float lum = dot(color, float3(0.2126, 0.7152, 0.0722));
    return (lum > maxLuminance && lum > 0.0)
        ? color * (maxLuminance / lum)
        : color;
}

// ---------------------------------------------------------------------
//  Spherical Harmonics (static, set per-frame by KPBR_InitializeSH)
// ---------------------------------------------------------------------
static float4 kpbrSHAr = 0;
static float4 kpbrSHAg = 0;
static float4 kpbrSHAb = 0;
static float4 kpbrSHBr = 0;
static float4 kpbrSHBg = 0;
static float4 kpbrSHBb = 0;
static float4 kpbrSHC  = 0;

void KPBR_InitializeSH(float3 worldPos)
{
    kpbrSHAr = unity_SHAr;
    kpbrSHAg = unity_SHAg;
    kpbrSHAb = unity_SHAb;
    kpbrSHBr = unity_SHBr;
    kpbrSHBg = unity_SHBg;
    kpbrSHBb = unity_SHBb;
    kpbrSHC  = unity_SHC;

#if defined(VRC_LIGHT_VOLUMES_INCLUDED)
    if (_UdonLightVolumeEnabled)
    {
        float3 L0, L1r, L1g, L1b;
        LightVolumeSH(worldPos, L0, L1r, L1g, L1b);

        kpbrSHAr = float4(L1r, L0.r);
        kpbrSHAg = float4(L1g, L0.g);
        kpbrSHAb = float4(L1b, L0.b);
        kpbrSHBr = 0;
        kpbrSHBg = 0;
        kpbrSHBb = 0;
        kpbrSHC  = 0;
    }
#endif
}

// =====================================================================
//  BRDF Components (Cook-Torrance + Disney Diffuse)
// =====================================================================

float KPBR_D_GGX(float NdotH, float roughness)
{
    float a  = roughness * roughness;
    float a2 = a * a;
    float d  = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (KPBR_PI * d * d + KPBR_EPS);
}

float KPBR_V_SmithGGXCorrelated(float NdotV, float NdotL, float roughness)
{
    float a  = roughness * roughness;
    float a2 = a * a;
    float GV = NdotL * sqrt(NdotV * NdotV * (1.0 - a2) + a2);
    float GL = NdotV * sqrt(NdotL * NdotL * (1.0 - a2) + a2);
    return 0.5 / (GV + GL + KPBR_EPS);
}

float3 KPBR_F_Schlick(float cosTheta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(saturate(1.0 - cosTheta), 5.0);
}

float3 KPBR_F_SchlickRoughness(float cosTheta, float3 F0, float roughness)
{
    float3 maxF = max((1.0 - roughness).xxx, F0);
    return F0 + (maxF - F0) * pow(saturate(1.0 - cosTheta), 5.0);
}

float3 KPBR_DisneyDiffuse(float NdotV, float NdotL, float LdotH, float roughness)
{
    float FD90         = 0.5 + 2.0 * LdotH * LdotH * roughness;
    float lightScatter = 1.0 + (FD90 - 1.0) * pow(1.0 - NdotL, 5.0);
    float viewScatter  = 1.0 + (FD90 - 1.0) * pow(1.0 - NdotV, 5.0);
    return (lightScatter * viewScatter) * KPBR_INV_PI;
}

// =====================================================================
//  Multi-Bounce AO (Filament approximation)
// =====================================================================
float3 KPBR_MultiBounceAO(float ao, float3 albedo)
{
    float3 a = 2.0404 * albedo - 0.3324;
    float3 b = -4.7951 * albedo + 0.6417;
    float3 c = 2.7552 * albedo + 0.6903;
    return max(float3(ao, ao, ao), ((ao * a + b) * ao + c) * ao);
}

// =====================================================================
//  Rim Lighting
// =====================================================================
float3 KPBR_ComputeRim(KPBRSurface s, float3 L, float3 lightCol,
                         float mainAtten, KPBRRimParams p)
{
    float NdotV = saturate(dot(s.N, s.V));
    float NdotL = dot(s.N, L);
    float fresnel   = 1.0 - NdotV;
    float roughBias = lerp(1.5, 0.6, s.roughness);

    float  backMask    = saturate(-NdotL * 1.2 + 0.2);
    float  backRim     = pow(fresnel, p.backRimPower * roughBias) * backMask;
    float3 backRimCol  = backRim * p.backRimColor * lightCol
                       * p.backRimIntensity * lerp(0.3, 1.0, mainAtten);

    float  innerMask   = saturate(1.0 - NdotL * 0.5 - 0.5);
    float  innerRim    = pow(fresnel, p.innerRimPower * roughBias) * innerMask;
    float3 innerRimCol = -innerRim * (1.0 - p.innerRimColor) * p.innerRimIntensity;

    return backRimCol + innerRimCol;
}

// =====================================================================
//  Per-Light Evaluation
// =====================================================================
void KPBR_EvaluateLight(inout KPBRLightDatas datas, KPBRSurface s, KPBRLight l)
{
    if (l.NdotL <= 0.0 || dot(l.color, l.color) < KPBR_EPS) return;

    float3 H     = normalize(l.direction + s.V);
    float  NdotV = max(dot(s.N, s.V), KPBR_EPS);
    float  NdotH = saturate(dot(s.N, H));
    float  LdotH = saturate(dot(l.direction, H));
    float  VdotH = saturate(dot(s.V, H));

    float3 F0 = lerp(KPBR_DIELECTRIC_F0, s.albedo, s.metallic);

    float  D = KPBR_D_GGX(NdotH, s.roughness);
    float  V = KPBR_V_SmithGGXCorrelated(NdotV, l.NdotL, s.roughness);
    float3 F = KPBR_F_Schlick(VdotH, F0);

    float3 spec = D * V * F;
    float3 kD   = (1.0 - F) * (1.0 - s.metallic);
    float3 diff = kD * s.albedo * KPBR_DisneyDiffuse(NdotV, l.NdotL, LdotH, s.roughness);

    float3 radiance = l.color * l.NdotL;
    datas.directDiffuse  += diff * radiance;
    datas.directSpecular += spec * radiance;
}

// =====================================================================
//  Light Source Helpers
// =====================================================================

void KPBR_GetDirectionalLight(float3 fallbackDirWS, float3 fallbackColor,
                                out float3 dir, out float3 col)
{
    if (any(_LightColor0.rgb))
    {
        dir = normalize(_WorldSpaceLightPos0.xyz);
        col = _LightColor0.rgb;
    }
    else
    {
        dir = -normalize(fallbackDirWS);
        col = fallbackColor;
    }
}

void KPBR_AccumulatePointLights(inout KPBRLightDatas datas, KPBRSurface s,
                                  float lightClamp)
{
#if defined(VERTEXLIGHT_ON)
    [unroll]
    for (int idx = 0; idx < 4; idx++)
    {
        float3 toLight = float3(
            unity_4LightPosX0[idx],
            unity_4LightPosY0[idx],
            unity_4LightPosZ0[idx]) - s.worldPos;
        float distSqr = dot(toLight, toLight);
        float atten   = 1.0 / (1.0 + distSqr * unity_4LightAtten0[idx]);

        KPBRLight l;
        l.direction = toLight * rsqrt(max(distSqr, KPBR_EPS));
        l.color     = KPBR_ClampLightColor(unity_LightColor[idx].rgb * atten, lightClamp);
        l.NdotL     = saturate(dot(s.N, l.direction));
        KPBR_EvaluateLight(datas, s, l);
    }
#endif
}

void KPBR_EvaluateSpotLight(inout KPBRLightDatas datas, KPBRSurface s,
                              float3 lightPosWS, float3 spotDirWS,
                              float3 lightColor, float range,
                              float innerCosAngle, float outerCosAngle)
{
    float3 toLight = lightPosWS - s.worldPos;
    float  dist    = length(toLight);
    float3 L       = toLight / max(dist, KPBR_EPS);

    float distAtten = saturate(1.0 - (dist * dist) / (range * range));
    distAtten *= distAtten;

    float cosOuter  = dot(-L, normalize(spotDirWS));
    float coneAtten = saturate(
        (cosOuter - outerCosAngle) / max(innerCosAngle - outerCosAngle, KPBR_EPS));

    KPBRLight l;
    l.direction = L;
    l.color     = lightColor * distAtten * coneAtten;
    l.NdotL     = saturate(dot(s.N, L));
    KPBR_EvaluateLight(datas, s, l);
}

// =====================================================================
//  Environment / Indirect Lighting
// =====================================================================

float3 KPBR_SampleSH(float3 N, float3 worldPos)
{
    float4 vB = N.xyzz * N.yzzx;
    float3 res = float3(kpbrSHAr.w, kpbrSHAg.w, kpbrSHAb.w);
    res.r += dot(kpbrSHBr, vB);
    res.g += dot(kpbrSHBg, vB);
    res.b += dot(kpbrSHBb, vB);
    res += kpbrSHC.rgb * (N.x * N.x - N.y * N.y);

    float3 l1;
    l1.r = dot(kpbrSHAr.rgb, N);
    l1.g = dot(kpbrSHAg.rgb, N);
    l1.b = dot(kpbrSHAb.rgb, N);

    return max(res + l1, 0.0);
}

float3 KPBR_SampleReflectionProbe(float3 R, float roughness)
{
    float  mip = roughness * (1.7 - 0.7 * roughness) * UNITY_SPECCUBE_LOD_STEPS;
    float4 env = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, R, mip);
    return DecodeHDR(env, unity_SpecCube0_HDR);
}

void KPBR_AccumulateIndirect(inout KPBRLightDatas datas, KPBRSurface s)
{
    float  NdotV = max(dot(s.N, s.V), KPBR_EPS);
    float3 F0    = lerp(KPBR_DIELECTRIC_F0, s.albedo, s.metallic);
    float3 F     = KPBR_F_SchlickRoughness(NdotV, F0, s.roughness);
    float3 kD    = (1.0 - F) * (1.0 - s.metallic);

    float3 irradiance = KPBR_SampleSH(s.N, s.worldPos);
    datas.indirectDiffuse += kD * s.albedo * irradiance * s.occlusion;

    float3 R           = reflect(-s.V, s.N);
    float3 prefiltered = KPBR_SampleReflectionProbe(R, s.roughness);

    float  grazingTerm = saturate((1.0 - s.roughness) + (1.0 - kD.r));
    float3 grazingF    = KPBR_F_Schlick(NdotV, F0 * grazingTerm);

    float specOcc = saturate(
        pow(NdotV + s.occlusion, exp2(-16.0 * s.roughness - 1.0))
        - 1.0 + s.occlusion);

    float surfaceReduction = 1.0 / (s.roughness * s.roughness + 1.0);
    datas.indirectSpecular += surfaceReduction * prefiltered * grazingF * specOcc;
}

// =====================================================================
//  Full Lighting Pipeline — ForwardBase entry point
//
//  Now also returns resolved mainLightDir / mainLightCol via the
//  KPBRLightDatas struct so callers (e.g. Rim) can reuse them (#5).
// =====================================================================
void KPBR_ComputeLights(out KPBRLightDatas datas, KPBRSurface s,
                          float3 fallbackDirWS, float3 fallbackColor,
                          float mainLightAtten, float lightClamp)
{
    datas = (KPBRLightDatas)0;

    KPBR_InitializeSH(s.worldPos);

    // Main directional light
    float3 L, lcol;
    KPBR_GetDirectionalLight(fallbackDirWS, fallbackColor, L, lcol);
    lcol = KPBR_ClampLightColor(lcol, lightClamp);

    // Store for caller reuse (Rim, etc.)
    datas.mainLightDir = L;
    datas.mainLightCol = lcol;

    KPBRLight main;
    main.direction = L;
    main.color     = lcol * mainLightAtten;
    main.NdotL     = saturate(dot(s.N, L));
    KPBR_EvaluateLight(datas, s, main);

    KPBR_AccumulatePointLights(datas, s, lightClamp);

    KPBR_AccumulateIndirect(datas, s);
}

// =====================================================================
//  ForwardAdd — single per-pixel light evaluation
// =====================================================================
void KPBR_ComputeForwardAdd(out KPBRLightDatas datas, KPBRSurface s,
                              float3 lightDir, float3 lightCol,
                              float atten, float lightClamp)
{
    datas = (KPBRLightDatas)0;
    datas.mainLightDir = lightDir;
    datas.mainLightCol = lightCol;

    KPBRLight l;
    l.direction = lightDir;
    l.color     = KPBR_ClampLightColor(lightCol, lightClamp) * atten;
    l.NdotL     = saturate(dot(s.N, lightDir));
    KPBR_EvaluateLight(datas, s, l);
}

// =====================================================================
//  Transparency Helper
// =====================================================================
float KPBR_OneMinusReflectivityFromMetallic(float metallic)
{
    const float oneMinusDielectricSpec = 1.0 - KPBR_DIELECTRIC_F0.r;
    return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
}

void KPBR_PreMultiplyAlpha(inout KPBRLightDatas datas,
                             inout float alpha,
                             float metallic)
{
    float oneMinusReflectivity = KPBR_OneMinusReflectivityFromMetallic(metallic);

    datas.directDiffuse   *= alpha;
    datas.indirectDiffuse *= alpha;

    alpha = 1.0 - oneMinusReflectivity + alpha * oneMinusReflectivity;
}

#endif // KPBR_PBR_CORE_INCLUDED
