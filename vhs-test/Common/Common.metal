//
//  Common.metal
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

#ifndef Common_metal
#define Common_metal

#include <metal_stdlib>
using namespace metal;

template <typename T>
float2 uv2coord(T uv) {
    return fma(uv, 2, float2(-1, 1));
}

template <typename T>
float2 coord2uv(T coord) {
    return fma(coord, float2(0.5, -0.5), 0.5);
}

template<typename T>
float rand(vec<T, 2> xy)
{
    vec<T, 2> frequency = 2.0 * M_PI_F * vec<T, 2>(12.9898, 78.233);
    T amplitude = 43758.5453;
    return fract(sin(dot(xy, frequency)) * amplitude);
}

#endif // Common_metal
