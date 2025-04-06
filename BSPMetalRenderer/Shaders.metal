//
//  Shaders.metal
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 4/3/25.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color    [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

typedef struct
{
    float4 position [[position]];
    float4 color;
    float2 texCoord;
} ColorInOut;

vertex ColorInOut vertexShader(VertexIn in [[stage_in]],
                               constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]])
{
    ColorInOut out;

    float4 pos = float4(in.position, 1.0);
    // Use your model-view-projection matrix here:
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * pos;
    out.color = in.color;
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]])
{
    return in.color;
}
