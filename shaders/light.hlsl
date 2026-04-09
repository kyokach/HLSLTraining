struct DirectionLight
{
    // ディレクションライト
    // 位置情報を持たず、どの位置でも同じ向き、同じ影響で光を受ける。
    float3 lightDirection; // 光の向き
    float3 lightColor; // 光の色
};

struct PointLight
{
    // ポイントライト
    // 位置情報を持ち、距離に応じて影響が減衰する。
    float3 lightPosition; // 光の位置
    float3 lightColor; // 光の色
    float lightRange; // ポイントライトの影響範囲
};

struct SpotLight
{
    // スポットライト
    // ポイントライトに加えて放射方向、放射角度も持つ。
    float3 lightDirection; // 光の向き
    float3 lightPosition; // 光の位置
    float3 lightColor; // 光の色
    float lightRange; // スポットライトの影響範囲
    float lightAngle; // スポットライトの放射角度
};
