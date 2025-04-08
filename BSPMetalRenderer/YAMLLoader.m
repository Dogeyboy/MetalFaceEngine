//
//  YAMLLoader.m
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 4/8/25.
//

#import "YAMLLoader.h"
#import "yaml.h"

@implementation YAMLLoader

+ (ModelData *)loadModelFromYAMLFile:(NSString *)path {
    FILE *fh = fopen([path UTF8String], "r");
    if (!fh) return NULL;

    yaml_parser_t parser;
    yaml_parser_initialize(&parser);
    yaml_parser_set_input_file(&parser, fh);

    // Example stub — full parsing logic needed
    ModelData *model = malloc(sizeof(ModelData));
    memset(model, 0, sizeof(ModelData));
    
    // Create mutable arrays to hold vertex components and indices.
    NSMutableArray *verticesArray = [NSMutableArray array];
    NSMutableArray *indicesArray = [NSMutableArray array];

    // Code that loops through yaml_parser_parse(...) and populate `model`
    yaml_event_t event;
    NSString *currentKey = nil;
    BOOL inModel = NO, inVertices = NO, inIndices = NO;

    while (1) {
        if (!yaml_parser_parse(&parser, &event)) break;

        if (event.type == YAML_MAPPING_START_EVENT && !inModel) {
            inModel = YES;
        }
        else if (event.type == YAML_SCALAR_EVENT && inModel) {
            currentKey = [NSString stringWithUTF8String:(char *)event.data.scalar.value];
        }
        else if (event.type == YAML_SEQUENCE_START_EVENT) {
            if ([currentKey isEqualToString:@"vertices"]) inVertices = YES;
            if ([currentKey isEqualToString:@"indices"]) inIndices = YES;
        }
        else if (event.type == YAML_SEQUENCE_END_EVENT) {
            inVertices = NO;
            inIndices = NO;
        }
        else if (event.type == YAML_SCALAR_EVENT && currentKey) {
            NSString *value = [NSString stringWithUTF8String:(char *)event.data.scalar.value];

            if ([currentKey isEqualToString:@"name"]) {
                strncpy(model->name, [value UTF8String], sizeof(model->name));
            } else if ([currentKey isEqualToString:@"texture"]) {
                strncpy(model->texture, [value UTF8String], sizeof(model->texture));
            }
        }
        else if (event.type == YAML_SEQUENCE_START_EVENT && inVertices) {
            // Each vertex is its own sequence
            NSMutableArray *components = [NSMutableArray array];
            while (1) {
                yaml_parser_parse(&parser, &event);
                if (event.type == YAML_SEQUENCE_END_EVENT) break;
                if (event.type == YAML_SCALAR_EVENT) {
                    NSString *scalar = [NSString stringWithUTF8String:(char *)event.data.scalar.value];
                    [components addObject:@([scalar floatValue])];
                }
                yaml_event_delete(&event);
            }

            if (components.count == 5) {
                Vertex v;
                v.position = (vector_float3){[components[0] floatValue], [components[1] floatValue], [components[2] floatValue]};
                v.texCoord = (vector_float2){[components[3] floatValue], [components[4] floatValue]};
                v.color = (vector_float3){ 1.0f, 1.0f, 1.0f }; // default white
                [verticesArray addObject:[NSValue valueWithBytes:&v objCType:(const char *)@encode(Vertex)]];
            }
        }
        else if (event.type == YAML_SEQUENCE_START_EVENT && inIndices) {
            // Each face (6 indices) is its own sequence
            NSMutableArray *components = [NSMutableArray array];
            while (1) {
                yaml_parser_parse(&parser, &event);
                if (event.type == YAML_SEQUENCE_END_EVENT) break;
                if (event.type == YAML_SCALAR_EVENT) {
                    NSString *scalar = [NSString stringWithUTF8String:(char *)event.data.scalar.value];
                    [components addObject:@([scalar intValue])];
                }
                yaml_event_delete(&event);
            }

            for (NSNumber *idx in components) {
                uint16_t val = [idx unsignedShortValue];
                [indicesArray addObject:@(val)];
            }
        }

        yaml_event_delete(&event);
    }
    
    // Convert the mutable arrays into C arrays.
    model->vertexCount = (uint32_t)[verticesArray count];
    model->vertices = malloc(sizeof(Vertex) * model->vertexCount);
    for (NSUInteger i = 0; i < [verticesArray count]; i++) {
        Vertex v;
        [verticesArray[i] getValue:&v];
        model->vertices[i] = v;
    }
    
    model->indexCount = (uint32_t)[indicesArray count];
    model->indices = malloc(sizeof(uint16_t) * model->indexCount);
    for (NSUInteger i = 0; i < [indicesArray count]; i++) {
        model->indices[i] = [indicesArray[i] unsignedShortValue];
    }
    
    yaml_parser_delete(&parser);
    fclose(fh);
    
    return model;
}
@end
