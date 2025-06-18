//
//  AssetLoader.m
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 6/18/25.
//

#import "AssetData.h"
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

AssetModel* loadMFEAsset(const char* filepath){
    FILE* fle = fopen(filepath, "rb");
    if (!fle){
        fprintf(stderr, "Could not open '%s'\n", filepath);
        return NULL;
    }
    
    char magic[8];
    if (fread(magic, 1, 8, fle) != 8 || strncmp(magic, "MFEASSET", 8)) {
        fprintf(stderr, "Bad header in '%s'\n", filepath);
        fclose(fle); return NULL;
    }
    
    uint32_t version = 0;
    fread(&version, sizeof(uint32_t), 1, fle);
    if (version != 1) {
        fprintf(stderr, "Unsupported MFE version: %d\n", version);
        fclose(fle);
        return NULL;
    }
    
    //Model Allocation
    AssetModel* model = (AssetModel*)malloc(sizeof(AssetModel));
    if (!model) {
        fclose(fle);
        return NULL;
    }
    
    fread(&model->vertexCount, sizeof(uint32_t), 1, fle);
    fread(&model->indexCount, sizeof(uint32_t), 1, fle);
    uint32_t nameLen;
    fread(&nameLen, sizeof(uint32_t), 1, fle);
    
    model->vertices = (AssetVertex*)malloc(sizeof(AssetVertex) * model->vertexCount);
    model->indices = (uint32_t*)malloc(sizeof(uint32_t) * model->indexCount);
    
    if (!model->vertices || !model->indices) {
        fprintf(stderr, "Memory allocation failed\n");
        fclose(fle);
        free(model->vertices);
        free(model->indices);
        free(model);
        return NULL;
    }
    
    fread(model->vertices, sizeof(AssetVertex), model->vertexCount, fle);
    fread(model->indices, sizeof(uint32_t), model->indexCount, fle);
    
    fclose(fle);
    return model;
}

void freeAssetModel(AssetModel* model) {
    if (!model) return;
    free(model->textureName);
    free(model->vertices);
    free(model->indices);
    free(model);
}
