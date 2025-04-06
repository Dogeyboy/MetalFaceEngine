//
//  ShaderTypes.h
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 4/3/25.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
#import <Foundation/Foundation.h>
typedef NSInteger EnumBackingType;
#endif

#include <simd/simd.h>

typedef NS_ENUM(EnumBackingType, BufferIndex)
{
    BufferIndexMeshPositions = 0,
    BufferIndexMeshGenerics  = 1,
    BufferIndexUniforms      = 2
};

typedef NS_ENUM(EnumBackingType, VertexAttribute)
{
    VertexAttributePosition  = 0,
    VertexAttributeColor = 1,
    VertexAttributeTexcoord  = 2,
};

typedef NS_ENUM(EnumBackingType, TextureIndex)
{
    TextureIndexColor    = 0,
};

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
} Uniforms;

#ifdef __METAL_VERSION__
// For Metal, define Vertex with position, color, and texCoord.
// Adjust the attribute indices as needed by your shader.
typedef struct {
    float3 position [[attribute(0)]];
    float3 color    [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
} Vertex;
#else
typedef struct {
    vector_float3 position;
    vector_float3 color;
    vector_float2 texCoord;
} Vertex;
#endif

#endif /* ShaderTypes_h */
