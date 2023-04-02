//
//  ImageRenderer.metal
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

#include <metal_stdlib>
#include <simd/simd.h>

#include "../Common/Common.metal"

using namespace metal;

struct ImageRenderer_VertexOut {
    float4 position [[ position ]];
    float2 uv;
    float2 staticUV;
};

vertex ImageRenderer_VertexOut
ImageRenderer_vertexFunction(uint vid [[vertex_id]],
                             constant matrix_float3x3& viewTransform [[ buffer(0) ]],
                             constant matrix_float3x3& uvTransform [[ buffer(1) ]]) {
    const float2 positions[] = {
        float2(-1, 1), float2(-1, -1),
        float2( 1, 1), float2( 1, -1)
    };
    
    ImageRenderer_VertexOut out;
    const float2 tposition = (viewTransform * float3(positions[vid], 1)).xy;
    out.position = float4(tposition.xy, 0.0, 1.0);

    out.staticUV = coord2uv(positions[vid].xy);
    
    const float2 uvCoord = (uvTransform * float3(positions[vid], 1)).xy;
    out.uv = coord2uv(uvCoord.xy);
    
    return out;
}

fragment float4
ImageRenderer_fragmentFunction(ImageRenderer_VertexOut in [[ stage_in ]],
                               texture2d<float, access::sample> imageTexture [[ texture(0) ]],
                               texture2d<float, access::sample> maskTexture [[ texture(1) ]],
                               texture2d<float, access::sample> overlayTexture [[ texture(2) ]]
                               ) {
    constexpr sampler s(filter::linear, mip_filter::linear, coord::normalized, address::clamp_to_zero);
    const float4 sourceColor = imageTexture.sample(s, in.uv);
    float4 outputColor = sourceColor;
    if (!is_null_texture(maskTexture)) {
        const float4 maskTexel = maskTexture.sample(s, in.staticUV);
        outputColor.a = maskTexel.a;
    }
    if (!is_null_texture(overlayTexture)) {
        const float4 overlayTexel = overlayTexture.sample(s, in.staticUV);
        outputColor.rgb = mix(outputColor.rgb, overlayTexel.rgb, overlayTexel.a);
    }
    return outputColor;
}
