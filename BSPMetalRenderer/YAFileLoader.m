//
//  YAFileLoader.m
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 4/8/25.
//

#import <Foundation/Foundation.h>
#import "YAMLLoader.h"    // Your wrapper for libyaml parsing
#import "ModelData.h"     // Contains your ModelData struct and (optionally) Vertex definition

int main (int argc, const char * argv[]) {
    @autoreleasepool {
        // Locate the YAML file inside the app bundle.
        // Make sure CubeModel.yaml is added to your project and is part of the bundle resources.
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"CubeModel" ofType:@"yaml"];
        if (!filePath) {
            NSLog(@"Failed to find the YAML file in the bundle.");
            return 1;
        }
        
        // Load the model using your YAMLLoader
        ModelData *model = [YAMLLoader loadModelFromYAMLFile:filePath];
        if (model == NULL) {
            NSLog(@"Failed to load model from YAML.");
            return 1;
        }
        
        // Print out some information for debugging
        NSLog(@"Model name: %s", model->name);
        NSLog(@"Texture: %s", model->texture);
        NSLog(@"Vertex count: %u", model->vertexCount);
        NSLog(@"Index count: %u", model->indexCount);
        
        // For example, print the first few vertices:
        for (uint32_t i = 0; i < model->vertexCount; i++) {
            Vertex v = model->vertices[i];
            NSLog(@"Vertex[%u]: Position=(%f, %f, %f), TexCoord=(%f, %f)", i,
                  v.position.x, v.position.y, v.position.z,
                  v.texCoord.x, v.texCoord.y);
        }
        
        // Clean up: free allocated arrays and the ModelData structure.
        free(model->vertices);
        free(model->indices);
        free(model);
    }
    return 0;
}
