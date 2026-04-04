Shader "KTB/HLSLTraining/Basic"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MatCap ("Material Capture", 2D) = "black" {}
        _MatCapStrength ("MatCap Strength", Range(0,1)) = 0.5
        _MatCapMask ("Material Capture Mask", 2D) = "white" {}
        _NormalMap ("Normal Map", 2D) = "white" {}
        _NormalMapStrength ("Normal Map Strength", Range(-1,1)) = 0
        _LightDirection ("Light Direction", Vector) = (-1,-1,0,0)
        _LightColor ("Base Color", Color) = (1,1,1,1)
        _SpecIntensity ("Specular Intensity", Range(0,1)) = 0 
        _Shininess ("Shininess", Range(8,128)) = 32
        _SpecColor ("Specular Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "lights.hlsl"

            struct appdata
            {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 tangent : TEXCOORD3;
                float3 bitangent : TEXCOORD4;

                UNITY_FOG_COORDS(1)
            };

            sampler2D _MainTex;
            sampler2D _MatCap;
            float _MatCapStrength;
            sampler2D _MatCapMask;
            sampler2D _NormalMap;
            float _NormalMapStrength;
            float4 _LightDirection;
            float4 _LightColor;
            float _SpecIntensity;
            float _Shininess;
            float4 _SpecColor;
            float4 _MainTex_ST;

            // ===== ディレクションライト =====
            DirectionLight CreateDirectionalLight()
            {
                DirectionLight dl;
                dl.lightDirection = normalize(_LightDirection.xyz);
                dl.lightColor = _LightColor.rgb;
                return dl;
            }

            
            float3 ComputeLambert(DirectionLight dl, float3 normal)
            {
                float diffuse = saturate(dot(normal, -dl.lightDirection));
                return diffuse * dl.lightColor;
            }

            float3 ComputePhong(DirectionLight dl, float3 normal, float3 viewDir, float shininess)
            {
                float reflectDir = reflect(dl.lightDirection, normal);
                float specular = pow(saturate(dot(viewDir, reflectDir)), shininess) * _SpecIntensity;
                return specular * dl.lightColor;
            }

            float3 ComputeBlinnPhong(DirectionLight dl, float3 normal, float3 viewDir, float shininess)
            {
                float halfDir = normalize(-dl.lightDirection + viewDir);
                float NdotH = saturate(dot(normal, halfDir));
                float specular = pow(NdotH, shininess) * _SpecIntensity;
                return specular * _SpecColor.rgb * dl.lightColor;
            }

            // ===== Vertex Shader =====
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.pos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.pos).xyz;

                // TangentとBiTangentをワールド座標に変換
                o.tangent = UnityObjectToWorldDir(v.tangent.xyz);
                o.bitangent = cross(o.normal, o.tangent) * v.tangent.w;

                UNITY_TRANSFER_FOG(o,o.pos);
                return o;
            }

            // ===== Fragment Shader =====
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                
                // ノーマルマップ適用
                float3 normalTex = UnpackNormal(tex2D(_NormalMap, i.uv));
                normalTex.xy *= _NormalMapStrength;
                normalTex = normalize(normalTex);

                float3x3 TBN = float3x3(
                    normalize(i.tangent),
                    normalize(i.bitangent),
                    normalize(i.normal)
                );

                float3 N = normalize(mul(normalTex, TBN));

                // ===== Lighting =====
                // ディレクションライトを定義
                DirectionLight dl = CreateDirectionalLight();

                // 反射光
                // Lambert拡散反射
                float3 lambert = ComputeLambert(dl, N);

                // Phong鏡面反射
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                // float phong = ComputePhong(dl, N, viewDir, _Shininess);
                float phong = ComputeBlinnPhong(dl, N, viewDir, _Shininess);

                // 環境光
                float3 ambient = max(ShadeSH9(float4(N, 1.0)), 0.05);
                
                col.rgb = col.rgb * (lambert + ambient) + phong;

                // ===== MatCap =====
                float3 viewNormal = mul((float3x3)UNITY_MATRIX_V, N);
                float2 matcapUV = viewNormal.xy * 0.5 + 0.5;
                float3 matcap = tex2D(_MatCap, matcapUV).rgb;

                // マスク適用
                fixed4 matcapMask = tex2D(_MatCapMask, i.uv);

                float3 matCapApplyed = 1 - (1 - col.rgb) * (1 - matcap * matcapMask);
                col.rgb = lerp(col.rgb, matCapApplyed, _MatCapStrength);

                // ===== Fog =====
                UNITY_APPLY_FOG(i.fogCoord, col);

                return col;
            }
            ENDCG
        }
    }
}
