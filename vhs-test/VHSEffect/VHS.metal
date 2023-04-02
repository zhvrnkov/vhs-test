//
//  VHS.metal
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

#include <metal_stdlib>

#include "../Common/Common.metal"
#include "../SharedTypes.h"

using namespace metal;

template<typename T>
T quantitize(T rgb, float colorsPerChannel)
{
    T output = rgb;
    output.rgb = discreted(output.rgb, colorsPerChannel - 1.0);
    return output;
}

template<typename T>
vec<T, 4> grain(vec<T, 4> input, T noise, float strength)
{
    return input + noise * strength;
}

template<typename V, typename T>
V distort(V coord, T noise, float strength)
{
    return coord + noise * strength;
}

half4 glitch(float2 uv, float time, GlitchParameters params)
{
    uv = uv * params.grid;
    const auto integer = floor(uv);
    const auto fractional = fract(uv);
    
    const auto vertical = params.artifactThickness * discreted((1.0 - fractional.y), params.artifactSmoothness);
    
    const auto artifactVerticalAxis = params.artifactVerticalAxis;
    const auto horizontal = 1.0 - (step(fractional.x, artifactVerticalAxis-vertical) +
                                   step(artifactVerticalAxis+vertical, fractional.x));

    const float noise = float(rand(integer + time) > (1.0 - params.frequency));
    return half4(horizontal * noise);
}

half makeVerticalScanLine(float2 uv, float time, VerticalScanLineParameters params)
{
    constexpr float scanLinePosition = 0.5;

    const float base = scanLinePosition * params.frequency;
    const float delta = params.thickness;
    
    const float cycledX = fmod(uv.x + time * params.speed, params.frequency);
    const float scanLine = smoothstep(base - delta, base, cycledX) -
                           smoothstep(base, base + delta, cycledX);
    
    return scanLine * params.strength;
}

half makeVerticalDistortion(float2 uv, float time, VerticalDistortionParameters params)
{
    const float x = floor(uv.x * params.numberOfHorizontalSegments);
    const float distortion = rand(float2(x, 1.0) + time) > 1.0 - params.frequency;
    return distortion * params.strength;
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
    
    half4x4 output = half4x4(1.0);
    output[0].rgb = half3(luminance.x * oneMinusSat) + half3(saturation, 0, 0);
    output[1].rgb = half3( luminance.y * oneMinusSat ) + half3(0, saturation, 0);
    output[2].rgb = half3(luminance.z * oneMinusSat) + half3(0, 0, saturation);
 
    return output;
}

half4x4 makeColorCorrectionMatrix(ColorCorrectionParameters params)
{
    return makeBrightnessMatrix(params.brightness) *
           makeContrastMatrix(params.contrast) *
           makeSaturationMatrix(params.saturation);
}

kernel void vhs(texture2d<half, access::sample> sourceTexture [[ texture(0) ]],
                texture2d<half, access::write> destinationTexture [[ texture(1) ]],
                constant float& time [[ buffer(0) ]],
                constant VHSParameters& params [[ buffer(1) ]],
                uint2 gridPosition [[ thread_position_in_grid ]])
{
    constexpr sampler s;
    
    const float2 sourceSize = float2(sourceTexture.get_width(), sourceTexture.get_height());
    const float2 uv = float2(gridPosition) / sourceSize;
    const half noise = rand(uv + time);

    float2 distortedUV = distort(uv, noise, params.randomUVDistortionStrength);
    const float verticalScanline = makeVerticalScanLine(distortedUV, time, params.scanLineParameters);
    const float verticalDistortion = makeVerticalDistortion(uv, time, params.verticalDistortionParameters);
    distortedUV.y += verticalScanline;
    distortedUV.y += verticalDistortion;

    const half4 artifacts = glitch(distortedUV, time, params.glitchParameters);
    
    const half4 sourceTexel = sourceTexture.sample(s, distortedUV);
    const half4 withArtifacts = mix(sourceTexel, artifacts, artifacts.a);
    const half4 bitDepthReduced = quantitize(withArtifacts, params.colorsPerChannel);
    const half4 grained = grain(bitDepthReduced, noise, params.grainStrength);
    
    const auto colorCorrectionMatrix = makeColorCorrectionMatrix(params.colorCorrectionParameters);
    
    destinationTexture.write(colorCorrectionMatrix * grained, gridPosition);
}
