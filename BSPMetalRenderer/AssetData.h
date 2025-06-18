//
//  AssetData.h
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 6/18/25.
//

#ifndef ASSETDATA_H
#define ASSETDATA_H

#include <stdint.h>

typedef struct {
    float x, y, z;
    float u, v;
}AssetVertex;

typedef struct {
    uint32_t vertexCount;
    uint32_t indexCount;
    char* textureName;
    AssetVertex* vertices;
    uint32_t* indices;
}AssetModel;

AssetModel* loadMFEAsset(const char* filepath);
void freeAssetModel(AssetModel* model);

#endif /* ASSETDATA_H */
