#ifndef KTB_PBR_CORE_INCLUDED
#define KTB_PBR_CORE_INCLUDED

// =====================================================================
//  KTB/HLSLTraining - PBR Lighting Core (OpenLit-style)
//  https://github.com/lilxyzw/OpenLit
//
//  Supported lights:
//    - Directional Light  (_WorldSpaceLightPos0 / _LightColor0)
//    - Point Light        (unity_4LightPosX0 ... / unity_LightColor[])
//    - Spot Light         (unity_SpotDirection / unity_LightAtten)
//    - Environment Light  (unity_SpecCube0 / Reflection Probe)
//    - Light Probe        (Spherical Harmonics: ShadeSH9)
//
//  Designed to mirror the structure of lilxyzw/OpenLit core.hlsl,
//  but tuned for physically-based shading instead of toon.
// =====================================================================

#include "UnityCG.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityImageBasedLighting.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"

#define KTBPBR_PI            3.14159265359
#define KTBPBR_INV_PI        0.31830988618
#define KTBPBR_MIN_ROUGHNESS 0.04
#define KTBPBR_DIELECTRIC_F0 float3(0.04, 0.04, 0.04)
#define KTBPBR_EPS           1e-7

struct KTBPBRSurface
{
    float3 albedo;
    float  metallic;
    float  roughness;
    float3 N;
    float3 V;
    float3 worldPos;
    float  occlusion;
};

struct KTBPBRLight
{
    float3 direction;
    float3 color;
    float  NdotL;
};

struct KTBPBRLightDatas
{
    float3 directDiffuse;
    float3 directSpecular;
    float3 indirectDiffuse;
    float3 indirectSpecular;
};

struct KTBPBRRimParams
{
    float3 backRimColor;
    float  backRimPower;
    float  backRimIntensity;
    float3 innerRimColor;
    float  innerRimPower;
    float  innerRimIntensity;
};

float KTBPBR_D_GGX(float NdotH, float roughness)
{
    float a  = roughness * roughness;
    float a2 = a * a;
    float d  = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (KTBPBR_PI * d * d + KTBPBR_EPS);
}

float KTBPBR_V_SmithGGXCorrelated(float NdotV, float NdotL, float roughness)
{
    float a  = roughness * roughness;
    float a2 = a * a;
    float GV = NdotL * sqrt(NdotV * NdotV * (1.0 - a2) + a2);
    float GL = NdotV * sqrt(NdotL * NdotL * (1.0 - a2) + a2);
    return 0.5 / (GV + GL + KTBPBR_EPS);
}

float3 KTBPBR_F_Schlick(float cosTheta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(saturate(1.0 - cosTheta), 5.0);
}

float3 KTBPBR_F_SchlickRoughness(float cosTheta, float3 F0, float roughness)
{
    float3 maxF = max((1.0 - roughness).xxx, F0);
    return F0 + (maxF - F0) * pow(saturate(1.0 - cosTheta), 5.0);
}

float3 KTBPBR_DisneyDiffuse(float NdotV, float NdotL, float LdotH, float roughness)
{
    float FD90 = 0.5 + 2.0 * LdotH * LdotH * roughness;
    float lightScatter = 1.0 + (FD90 - 1.0) * pow(1.0 - NdotL, 5.0);
    float viewScatter  = 1.0 + (FD90 - 1.0) * pow(1.0 - NdotV, 5.0);
    return (lightScatter * viewScatter) * KTBPBR_INV_PI;
}

float3 KTBPBR_ComputeRim(KTBPBRSurface s, float3 L, float3 lightCol,
                         float mainAtten, KTBPBRRimParams p)
{
    float NdotV = saturate(dot(s.N, s.V));
    float NdotL = dot(s.N, L);

    float fresnel = 1.0 - NdotV;

    float roughBias = lerp(1.5, 0.6, s.roughness);

    float backMask = saturate(-NdotL * 1.2 + 0.2);
    float backRim  = pow(fresnel, p.backRimPower * roughBias) * backMask;
    float3 backRimCol = backRim * p.backRimColor * lightCol
                      * p.backRimIntensity * lerp(0.3, 1.0, mainAtten);

    float innerMask = saturate(1.0 - NdotL * 0.5 - 0.5);
    float innerRim  = pow(fresnel, p.innerRimPower * roughBias) * innerMask;
    float3 innerRimCol = -innerRim * (1.0 - p.innerRimColor) * p.innerRimIntensity;

    return backRimCol + innerRimCol;
}

void KTBPBR_EvaluateLight(inout KTBPBRLightDatas datas, KTBPBRSurface s, KTBPBRLight l)
{
    if (l.NdotL <= 0.0 || dot(l.color, l.color) < KTBPBR_EPS) return;

    float3 H     = normalize(l.direction + s.V);
    float  NdotV = max(dot(s.N, s.V), KTBPBR_EPS);
    float  NdotH = saturate(dot(s.N, H));
    float  LdotH = saturate(dot(l.direction, H));
    float  VdotH = saturate(dot(s.V, H));

    float3 F0 = lerp(KTBPBR_DIELECTRIC_F0, s.albedo, s.metallic);

    float  D = KTBPBR_D_GGX(NdotH, s.roughness);
    float  V = KTBPBR_V_SmithGGXCorrelated(NdotV, l.NdotL, s.roughness);
    float3 F = KTBPBR_F_Schlick(VdotH, F0);

    float3 spec = D * V * F;
    float3 kD   = (1.0 - F) * (1.0 - s.metallic);
    float3 diff = kD * s.albedo * KTBPBR_DisneyDiffuse(NdotV, l.NdotL, LdotH, s.roughness);

    float3 radiance = l.color * l.NdotL;
    datas.directDiffuse  += diff * radiance;
    datas.directSpecular += spec * radiance;
}

void KTBPBR_GetDirectionalLight(float3 fallbackDirWS, float3 fallbackColor,
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

void KTBPBR_AccumulatePointLights(inout KTBPBRLightDatas datas, KTBPBRSurface s)
{
#if defined(VERTEXLIGHT_ON)
    [unroll]
    for (int idx = 0; idx < 4; idx++)
    {
        float3 toLight = float3(unity_4LightPosX0[idx], unity_4LightPosY0[idx], unity_4LightPosZ0[idx]) - s.worldPos;
        float  distSqr = dot(toLight, toLight);
        float  atten   = 1.0 / (1.0 + distSqr * unity_4LightAtten0[idx]);

        KTBPBRLight l;
        l.direction = toLight * rsqrt(max(distSqr, KTBPBR_EPS));
        l.color     = unity_LightColor[idx].rgb * atten;
        l.NdotL     = saturate(dot(s.N, l.direction));
        KTBPBR_EvaluateLight(datas, s, l);
    }
#endif
}

void KTBPBR_EvaluateSpotLight(inout KTBPBRLightDatas datas, KTBPBRSurface s,
                              float3 lightPosWS, float3 spotDirWS,
                              float3 lightColor, float range,
                              float innerCosAngle, float outerCosAngle)
{
    float3 toLight = lightPosWS - s.worldPos;
    float  dist    = length(toLight);
    float3 L       = toLight / max(dist, KTBPBR_EPS);

    float distAtten = saturate(1.0 - (dist * dist) / (range * range));
    distAtten *= distAtten;

    float cosOuter = dot(-L, normalize(spotDirWS));
    float coneAtten = saturate((cosOuter - outerCosAngle) / max(innerCosAngle - outerCosAngle, KTBPBR_EPS));

    KTBPBRLight l;
    l.direction = L;
    l.color     = lightColor * distAtten * coneAtten;
    l.NdotL     = saturate(dot(s.N, L));
    KTBPBR_EvaluateLight(datas, s, l);
}

float3 KTBPBR_SampleSH(float3 N)
{
    return max(ShadeSH9(float4(N, 1.0)), 0.0);
}

float3 KTBPBR_SampleReflectionProbe(float3 R, float roughness)
{
    float mip = roughness * (1.7 - 0.7 * roughness) * UNITY_SPECCUBE_LOD_STEPS;
    float4 env = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, R, mip);
    return DecodeHDR(env, unity_SpecCube0_HDR);
}

void KTBPBR_AccumulateIndirect(inout KTBPBRLightDatas datas, KTBPBRSurface s)
{
    float NdotV = max(dot(s.N, s.V), KTBPBR_EPS);
    float3 F0 = lerp(KTBPBR_DIELECTRIC_F0, s.albedo, s.metallic);
    float3 F  = KTBPBR_F_SchlickRoughness(NdotV, F0, s.roughness);
    float3 kD = (1.0 - F) * (1.0 - s.metallic);

    float3 irradiance = KTBPBR_SampleSH(s.N);
    datas.indirectDiffuse += kD * s.albedo * irradiance * s.occlusion;

    float3 R = reflect(-s.V, s.N);
    float3 prefiltered = KTBPBR_SampleReflectionProbe(R, s.roughness);

    float grazingTerm = saturate((1.0 - s.roughness) + (1.0 - kD.r));
    float3 grazingF   = KTBPBR_F_Schlick(NdotV, F0 * grazingTerm);

    float specOcc = saturate(pow(NdotV + s.occlusion, exp2(-16.0 * s.roughness - 1.0)) - 1.0 + s.occlusion);

    float surfaceReduction = 1.0 / (s.roughness * s.roughness + 1.0);
    datas.indirectSpecular += surfaceReduction * prefiltered * grazingF * specOcc;
}

void KTBPBR_ComputeLights(out KTBPBRLightDatas datas, KTBPBRSurface s,
                          float3 fallbackDirWS, float3 fallbackColor,
                          float mainLightAtten)
{
    datas = (KTBPBRLightDatas)0;

    float3 L, lcol;
    KTBPBR_GetDirectionalLight(fallbackDirWS, fallbackColor, L, lcol);
    KTBPBRLight main;
    main.direction = L;
    main.color     = lcol * mainLightAtten;
    main.NdotL     = saturate(dot(s.N, L));
    KTBPBR_EvaluateLight(datas, s, main);

    KTBPBR_AccumulatePointLights(datas, s);

    KTBPBR_AccumulateIndirect(datas, s);
}

float3 KTBPBR_ComposeFinalColor(KTBPBRLightDatas d,
                                float directIntensity, float indirectIntensity)
{
    float3 direct   = (d.directDiffuse + d.directSpecular) * directIntensity;
    float3 indirect = (d.indirectDiffuse + d.indirectSpecular) * indirectIntensity;
    return direct + indirect;
}

float KTBPBR_OneMinusReflectivityFromMetallic(float metallic)
{
    const float oneMinusDielectricSpec = 1.0 - KTBPBR_DIELECTRIC_F0.r; // 0.96
    return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
}

void KTBPBR_PreMultiplyAlpha(inout KTBPBRLightDatas datas,
                             inout float alpha,
                             float metallic)
{
    float oneMinusReflectivity = KTBPBR_OneMinusReflectivityFromMetallic(metallic);

    datas.directDiffuse   *= alpha;
    datas.indirectDiffuse *= alpha;

    alpha = 1.0 - oneMinusReflectivity + alpha * oneMinusReflectivity;
}

#endif
