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
vec<T, 4> grain(vec<T, 4> input, T noise, float strength)
{
    return input + noise * strength;
}

template<typename V, typename T>
V distort(V coord, T noise, float strength)
{
    return coord + noise * strength;
}

half4 glitch(float2 uv, float time)
{
    constexpr float glitchFrequency = 0.005;
    constexpr float2 glitchGrid = float2(10.0);
    constexpr float artifactThickness = 0.02;
    constexpr float artifactSmoothness = 10.0;
    constexpr float artifactVerticalAxis = 0.5;

    uv = uv * glitchGrid;
    const auto integer = floor(uv);
    const auto fractional = fract(uv);
    
    const auto vertical = artifactThickness * round(artifactSmoothness * (1.0 - fractional.y)) / artifactSmoothness;
    const auto horizontal = 1.0 - (step(fractional.x, artifactVerticalAxis-vertical) +
                                   step(artifactVerticalAxis+vertical, fractional.x));

    const float noise = float(rand(integer + time) > (1.0 - glitchFrequency));
    return half4(horizontal * noise);
}

half makeVerticalScanLine(float2 uv, float time, float frequency, float thickness)
{
    constexpr float scanLinePosition = 0.5;

    const float base = scanLinePosition * frequency;
    const float delta = thickness;
    
    const float cycledX = fmod(uv.x + time, frequency);
    return smoothstep(base - delta, base, cycledX) - smoothstep(base, base + delta, cycledX);
}

half makeVerticalDistortion(float2 uv, float time)
{
    constexpr float numberOfHorizontalSegments = 25.0;
    constexpr float verticalDistortionFrequency = 0.03;
    
    const float x = floor(uv.x * numberOfHorizontalSegments);
    return rand(float2(x, 1.0) + time) > 1.0 - verticalDistortionFrequency;
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

half4x4 makeBCSMatrix(half brightness, half contrast, half saturation)
{
    return makeBrightnessMatrix(brightness) * makeContrastMatrix(contrast) * makeSaturationMatrix(saturation);
}

kernel void vhs(texture2d<half, access::sample> sourceTexture [[ texture(0) ]],
                texture2d<half, access::write> destinationTexture [[ texture(1) ]],
                constant float& time [[ buffer(0) ]],
                uint2 gridPosition [[ thread_position_in_grid ]])
{
    constexpr sampler s;
    constexpr float distortionStrength = 0.0015;

    constexpr float vsSpeed = 0.25;
    constexpr float vsFreq = 2.0;
    constexpr float vsThickness = 0.01;
    constexpr float vsStrength = 0.00125;
    
    constexpr float verticalGlitchStrength = 0.0015;

    constexpr float colorsPerChannel = 32.0;
    
    constexpr float grainStrength = 0.1;
    
    constexpr float brightness = -0.15;
    constexpr float contrast = 1.35;
    constexpr float saturation = 0.65;
    
    const float2 sourceSize = float2(sourceTexture.get_width(), sourceTexture.get_height());
    const float2 uv = float2(gridPosition) / sourceSize;
    const half noise = rand(uv + time);

    float2 distortedUV = distort(uv, noise, distortionStrength);
    const float verticalScanline = makeVerticalScanLine(distortedUV, time * vsSpeed, vsFreq, vsThickness);
    const float verticalDistortion = makeVerticalDistortion(uv, time);
    distortedUV.y += verticalScanline * vsStrength;
    distortedUV.y += verticalDistortion * verticalGlitchStrength;
    
    const half4 sourceTexel = sourceTexture.sample(s, distortedUV);
    const half4 artifacts = glitch(distortedUV, time);
    const half4 withArtifacts = mix(sourceTexel, artifacts, artifacts.a);
    const half4 bitDepthReduced = quantitize(withArtifacts, colorsPerChannel);
    const half4 grained = grain(bitDepthReduced, noise, grainStrength);
    
    const auto bcsMatrix = makeBCSMatrix(brightness, contrast, saturation);
    
    destinationTexture.write(bcsMatrix * grained, gridPosition);
}
