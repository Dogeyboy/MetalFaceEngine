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

// The input structure (from the Vertex buffer)
struct VertexIn {
    float3 position [[attribute(0)]];
    float4 color    [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

// The output structure
typedef struct
{
    float4 position [[position]];
    float4 color;
    float2 texCoord;
} ColorInOut;

// Vertex shader: transform position and pass along color and texCoord.
vertex ColorInOut vertexShader(VertexIn in [[stage_in]],
                               constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]])
{
    ColorInOut out;

    float4 pos = float4(in.position, 1.0);
    // Model-view-projection matrix:
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * pos;
    out.color = in.color;
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               texture2d<float> colorTexture [[texture(0)]],
                               sampler colorSampler [[sampler(0)]])
{
    // Output the sampled texture color:
    float4 color = colorTexture.sample(colorSampler, in.texCoord);
    return color;
}
