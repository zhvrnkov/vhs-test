//
//  SharedTypes.h
//  vhs-test
//
//  Created by Vlad Zhavoronkov on 02.04.2023.
//

#ifndef SharedTypes_h
#define SharedTypes_h

#import <simd/simd.h>

typedef struct {
    float frequency;
    vector_float2 grid;
    float artifactThickness;
    float artifactSmoothness;
    float artifactVerticalAxis;
} GlitchParameters;

GlitchParameters DefaultGlitchParameters() {
    GlitchParameters output;
    output.frequency = 0.0025;
    output.grid.x = 20.0;
    output.grid.y = 10.0;
    output.artifactThickness = 0.02;
    output.artifactSmoothness = 10.0;
    output.artifactVerticalAxis = 0.5;
    return output;
}

typedef struct {
    float speed;
    float frequency;
    float thickness;
    float strength;
} VerticalScanLineParameters;

VerticalScanLineParameters DefaultVerticalScanLineParameters() {
    VerticalScanLineParameters output;
    output.speed = 0.25;
    output.frequency = 2.0;
    output.thickness = 0.01;
    output.strength = 0.00125;
    return output;
}

typedef struct {
    float brightness;
    float contrast;
    float saturation;
} ColorCorrectionParameters;

ColorCorrectionParameters DefaultColorCorrectionParameters() {
    ColorCorrectionParameters output;
    output.brightness = -0.1;
    output.contrast = 1.15;
    output.saturation = 0.75;
    return output;
}

typedef struct {
    float numberOfHorizontalSegments;
    float frequency;
    float strength;
} VerticalDistortionParameters;

VerticalDistortionParameters DefaultVerticalDistortionParameters() {
    VerticalDistortionParameters output;
    output.numberOfHorizontalSegments = 25.0;
    output.frequency = 0.03;
    output.strength = 0.0015;
    return output;
}

typedef struct {
    GlitchParameters glitchParameters;
    VerticalScanLineParameters scanLineParameters;
    ColorCorrectionParameters colorCorrectionParameters;
    VerticalDistortionParameters verticalDistortionParameters;
    float randomUVDistortionStrengthLB;
    float randomUVDistortionStrengthUB;
    float grainStrength;
    float colorsPerChannel;
    float blurSigma;
} VHSParameters;

VHSParameters DefaultVHSParameters() {
    VHSParameters output;
    output.glitchParameters = DefaultGlitchParameters();
    output.scanLineParameters = DefaultVerticalScanLineParameters();
    output.colorCorrectionParameters = DefaultColorCorrectionParameters();
    output.verticalDistortionParameters = DefaultVerticalDistortionParameters();
    output.randomUVDistortionStrengthLB = 0.001;
    output.randomUVDistortionStrengthUB = 0.002;
    output.grainStrength = 0.1;
    output.colorsPerChannel = 32.0;
    output.blurSigma = 1.1;
    return output;
}

#endif /* SharedTypes_h */
