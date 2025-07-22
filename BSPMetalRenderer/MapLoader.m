//
//  MapLoader.m
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 7/2/25.
//

#import "MapData.h"
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

MapFile* loadMFEMAP(const char* filepath) {
    FILE *f = fopen(filepath, "rb");
    if (!f) {
        fprintf(stderr, "Could not open map file '%s'\n", filepath);
        return NULL;
    }
    
    // 1. Magic + version
    char magic[9] = {0};
    if (fread(magic, 1, 8, f) != 8 || strncmp(magic, "MFEMAP01", 8) != 0) {
        fprintf(stderr, "Bad header in '%s'\n", filepath);
        fclose(f);
        return NULL;
    }
    
    uint32_t modelCount, instanceCount, meshCount;
    fread(&modelCount,    sizeof(uint32_t),1,f);
    fread(&instanceCount, sizeof(uint32_t),1,f);
    fread(&meshCount,    sizeof(uint32_t),1,f);
    
    //Allocating MapFile container
    MapFile *map = malloc(sizeof(MapFile));
    map->modelCount    = modelCount;
    map->instanceCount = instanceCount;
    map->meshCount     = meshCount;
    
    // 2. Skybox
    uint8_t skyboxNameLen = 0;
    fread(&skyboxNameLen, sizeof(uint8_t), 1, f);
    map->skyboxName = malloc(skyboxNameLen+1);
    fread(map->skyboxName,1,skyboxNameLen,f);
    map->skyboxName[skyboxNameLen]='\0';
    char *dot = strrchr(map->skyboxName, '.');
    if (dot) *dot = '\0'; // Strip file extension in-place (e.g. ".png")
    
    // 3. Model Reference Table
    map->modelRefs = malloc(sizeof(char*)*modelCount);
    for(uint32_t i=0;i<modelCount;i++){
        uint8_t nm = 0;
        fread(&nm, sizeof(uint8_t),1,f);
        char *n = malloc(nm+1);
        fread(n,1,nm,f);
        n[nm]='\0';
        map->modelRefs[i] = n;
    }
    
    // 4. Instances
    map->instances = malloc(sizeof(MapInstance) * instanceCount);
    for (uint32_t i = 0; i < instanceCount; i++) {
        MapInstance* inst = &map->instances[i];
        fread(&inst->modelIndex, sizeof(uint32_t), 1, f);
        fread(inst->transform, sizeof(float), 16, f);
        inst->assetName = NULL; // optional name, can assign later
    }

    // 5. Meshes
    map->meshes = malloc(sizeof(MapMesh) * meshCount);
    for (uint32_t i = 0; i < meshCount; i++) {
        MapMesh* mesh = &map->meshes[i];
        fread(&mesh->vertexCount, sizeof(uint32_t), 1, f);
        fread(&mesh->indexCount,  sizeof(uint32_t), 1, f);

        mesh->vertices = malloc(sizeof(MapStaticVertex) * mesh->vertexCount);
        fread(mesh->vertices, sizeof(MapStaticVertex), mesh->vertexCount, f);

        mesh->indices = malloc(sizeof(uint32_t) * mesh->indexCount);
        fread(mesh->indices, sizeof(uint32_t), mesh->indexCount, f);

        uint8_t texLen = 0;
        fread(&texLen, sizeof(uint8_t), 1, f);
        mesh->textureName = malloc(texLen + 1);
        fread(mesh->textureName, 1, texLen, f);
        mesh->textureName[texLen] = '\0';

        // Strip file extension in-place (e.g. ".png")
        char *dot = strrchr(mesh->textureName, '.');
        if (dot) *dot = '\0';
    }

    fclose(f);
    return map;
}

void freeMapFile(MapFile* map) {
    if (!map) return;
    free(map->skyboxName);

    for (uint32_t i = 0; i < map->modelCount; i++) {
        free(map->modelRefs[i]);
    }
    free(map->modelRefs);

    if (map->instances) {
        for (uint32_t i = 0; i < map->instanceCount; i++) {
            free(map->instances[i].assetName);
        }
        free(map->instances);
    }

    for (uint32_t i = 0; i < map->meshCount; i++) {
        MapMesh* mesh = &map->meshes[i];
        free(mesh->vertices);
        free(mesh->indices);
        free(mesh->textureName);
    }
    free(map->meshes);

    free(map);
}
