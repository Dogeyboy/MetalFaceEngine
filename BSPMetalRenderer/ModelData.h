//
//  ModelData.h
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 4/8/25.
//

#ifndef MODELFORMAT_H
#define MODELFORMAT_H

#include <simd/simd.h>
#include <stdint.h>
#import "ShaderTypes.h"

typedef struct {
    char name[64];
    char texture[64];
    Vertex* vertices;
    uint32_t vertexCount;
    uint16_t* indices;
    uint32_t indexCount;
} ModelData;

#endif
