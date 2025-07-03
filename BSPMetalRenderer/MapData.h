//
//  MapData.h
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 7/1/25.
//

#ifndef MAPDATA_H
#define MAPDATA_H

#include <stdint.h>

typedef struct {
    float x, y, z;
    float nx, ny, nz;
    float u, v;
    float r, g, b, a;
} MapStaticVertex;

typedef struct {
    uint32_t vertexCount;
    uint32_t indexCount;
    MapStaticVertex* vertices;
    uint32_t* indices;
    char* textureName; // dynamically allocated
} MapMesh;

typedef struct {
    char* assetName;     // dynamically allocated name of the referenced model
    uint32_t modelIndex; // index in model reference table
    float transform[16]; // 4x4 matrix
} MapInstance;

typedef struct {
    char* skyboxName;         // dynamically allocated
    uint32_t modelCount;
    char** modelRefs;         // array of dynamically allocated strings
    uint32_t instanceCount;
    MapInstance* instances;   // array
    uint32_t meshCount;
    MapMesh* meshes;          // array
} MapFile;

MapFile* loadMFEMAP(const char* filepath);
void freeMapFile(MapFile* map);

#endif /* MAPDATA_H */
