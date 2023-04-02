//
//  VHS.metal
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

#include <metal_stdlib>

#include "../Common/Common.metal"

using namespace metal;

template<typename T>
T quantitize(T rgb, float colorsPerChannel)
{
    T output = rgb;
    output.rgb *= (colorsPerChannel - 1.0);
    output.rgb = round(output.rgb);
    output.rgb /= (colorsPerChannel - 1.0);
    return output;
}

template<typename T>
vec<T, 4> grain(vec<T, 4> input, T noise, T strength)
{
    return input + noise * strength;
}

template<typename V, typename T>
V distort(V coord, T noise, T strength)
{
    return coord + noise * strength;
}

half4 glitch(float2 uv, float time)
{
    uv = uv * 10.0;
    float2 integer = floor(uv);
    float2 fractional = fract(uv);
    
    float vertical = 0.02 * round(10.0 * (1.0 - fractional.y)) / 10.0;
    float horizontal = step(fractional.x, 0.5-vertical) + step(0.5+vertical, fractional.x);
    horizontal = 1.0 - horizontal;

    float noise = float(rand(integer + time) > 0.995);
    return half4(horizontal * noise);
}

half4x4 makeBrightnessMatrix(half brightness) {
    half4x4 output = half4x4(1.0);
    output[3].xyz = brightness;
    return output;
}

half4x4 makeContrastMatrix(half contrast)
{
    const auto t = (1.0 - contrast) / 2.0;
    half4x4 output = half4x4(contrast);
    output[3] = half4(t, t, t, 1);
    return output;
}

half4x4 makeSaturationMatrix(half saturation)
{
    constexpr half3 luminance = half3(0.3086, 0.6094, 0.0820);
    
    float oneMinusSat = 1.0 - saturation;
    
    half3 red = half3( luminance.x * oneMinusSat );
    red += half3( saturation, 0, 0 );
    
    half3 green = half3( luminance.y * oneMinusSat );
    green += half3( 0, saturation, 0 );
    
    half3 blue = half3( luminance.z * oneMinusSat );
    blue += half3( 0, 0, saturation );
    
    return half4x4(half4(red, 0),
                   half4(green, 0),
                   half4(blue, 0),
                   half4(0, 0, 0, 1));
}

kernel void vhs(texture2d<half, access::sample> sourceTexture [[ texture(0) ]],
                texture2d<half, access::write> destinationTexture [[ texture(1) ]],
                constant float& time [[ buffer(0) ]],
                uint2 gridPosition [[ thread_position_in_grid ]])
{
    constexpr sampler s;

    const float2 sourceSize = float2(sourceTexture.get_width(), sourceTexture.get_height());
    const float2 uv = float2(gridPosition) / sourceSize;
    const half noise = rand(uv + time);
    const float2 distortedUV = distort(uv, noise, 0.0015h);

    const half4 artifacts = glitch(distortedUV, time);
    const half4 pixelated = mix(sourceTexture.sample(s, distortedUV), artifacts, artifacts.a);
    const half4 bitDepthReduced = quantitize(pixelated, 32.0);
    const half4 grained = grain(bitDepthReduced, noise, 0.1h);
    
    const auto brightnessMatrix = makeBrightnessMatrix(-0.15);
    const auto contrastMatrix = makeContrastMatrix(1.35);
    const auto saturationMatrix = makeSaturationMatrix(0.65);
    
    destinationTexture.write(brightnessMatrix * contrastMatrix * saturationMatrix * grained, gridPosition);
}
