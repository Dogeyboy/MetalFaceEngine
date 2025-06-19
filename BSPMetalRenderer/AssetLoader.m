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

    // 1. Magic + version
    char magic[8];
    if (fread(magic, 1, 8, fle) != 8 || strncmp(magic, "MFEASSET", 8)) {
        fprintf(stderr, "Bad header in '%s'\n", filepath);
        fclose(fle);
        return NULL;
    }

    uint32_t version = 0;
    fread(&version, sizeof(uint32_t), 1, fle);
    if (version != 1) {
        fprintf(stderr, "Unsupported MFE version: %d\n", version);
        fclose(fle);
        return NULL;
    }

    // 2. Counts + flags
    uint32_t meshCount, materialCount, textureCount;
    uint8_t hasArmature, hasAnimations;
    fread(&meshCount, sizeof(uint32_t), 1, fle);
    fread(&materialCount, sizeof(uint32_t), 1, fle);
    fread(&textureCount, sizeof(uint32_t), 1, fle);
    fread(&hasArmature, sizeof(uint8_t), 1, fle);
    fread(&hasAnimations, sizeof(uint8_t), 1, fle);

    // 3. Mesh block
    uint32_t meshNameLen;
    fread(&meshNameLen, sizeof(uint32_t), 1, fle);
    fseek(fle, meshNameLen, SEEK_CUR); // Skip name

    AssetModel* model = malloc(sizeof(AssetModel));
    if (!model) { fclose(fle); return NULL; }

    fread(&model->vertexCount, sizeof(uint32_t), 1, fle);
    fread(&model->indexCount, sizeof(uint32_t), 1, fle);
    uint32_t materialIndex = 0;
    fread(&materialIndex, sizeof(uint32_t), 1, fle);

    model->vertices = malloc(sizeof(AssetVertex) * model->vertexCount);
    model->indices = malloc(sizeof(uint32_t) * model->indexCount);
    if (!model->vertices || !model->indices) {
        free(model->vertices); free(model->indices); free(model);
        fclose(fle);
        return NULL;
    }

    for (uint32_t i = 0; i < model->vertexCount; i++) {
        AssetVertex* v = &model->vertices[i];
        fread(&v->x, sizeof(float), 1, fle);
        fread(&v->y, sizeof(float), 1, fle);
        fread(&v->z, sizeof(float), 1, fle);
        fread(&v->nx, sizeof(float), 1, fle);
        fread(&v->ny, sizeof(float), 1, fle);
        fread(&v->nz, sizeof(float), 1, fle);
        fread(&v->u, sizeof(float), 1, fle);
        fread(&v->v, sizeof(float), 1, fle);
        fread(&v->r, sizeof(float), 1, fle);
        fread(&v->g, sizeof(float), 1, fle);
        fread(&v->b, sizeof(float), 1, fle);
        fread(&v->a, sizeof(float), 1, fle);
    }

    fread(model->indices, sizeof(uint32_t), model->indexCount, fle);

    // 4. Material block
    uint8_t matNameLen = 0;
    fread(&matNameLen, sizeof(uint8_t), 1, fle);
    fseek(fle, matNameLen, SEEK_CUR); // skip material name
    fread(&materialIndex, sizeof(uint32_t), 1, fle); // texture index (unused)

    // 5. Texture block
    uint8_t texNameLen = 0;
    fread(&texNameLen, sizeof(uint8_t), 1, fle);
    model->textureName = malloc(texNameLen + 1);
    fread(model->textureName, 1, texNameLen, fle);
    model->textureName[texNameLen] = '\0';

    // Strip the extension in-place (e.g. ".jpg", ".png")
    char *dot = strrchr(model->textureName, '.');
    if (dot != NULL) {
        *dot = '\0'; // Null-terminate at the dot, removing extension
    }

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
