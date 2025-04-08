//
//  GameViewController.m
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 4/3/25.
//

#import "GameViewController.h"
#import "Renderer.h"
#import "ShaderTypes.h"

typedef struct BSPPolygon {
    Vertex vertices[3];
} BSPPolygon;

typedef struct BSPNode {
    BSPPolygon* polygons;
    int polygonCount;
    struct BSPNode* front;
    struct BSPNode* back;
} BSPNode;

BSPNode* createBSPNode(void) {
    BSPNode* node = malloc(sizeof(BSPNode));
    if (!node) {
        fprintf(stderr, "Memory allocation failed for BSPNode!\n");
        exit(1);
    }
    node->polygons = NULL;
    node->polygonCount = 0;
    node->front = NULL;
    node->back = NULL;
    return node;
}

void buildBSP(BSPNode* node, BSPPolygon* polygons, int count) {
    node->polygons = malloc(sizeof(BSPPolygon) * count);
    if (!node->polygons) {
        fprintf(stderr, "Failed to allocate memory for BSP node polygons.\n");
        exit(1);
    }

    // Deep copy each polygon and its vertices
    for (int i = 0; i < count; i++) {
        for (int j = 0; j < 3; j++) {
            node->polygons[i].vertices[j] = polygons[i].vertices[j];
        }
    }

    node->polygonCount = count;
    node->front = NULL;
    node->back = NULL;
}

void freeBSP(BSPNode* node) {
    if (!node) return;
    freeBSP(node->front);
    freeBSP(node->back);
    free(node);
}

// Declare BSP tree functions (if not declared elsewhere)
BSPNode* createBSPNode(void);
void buildBSP(BSPNode* node, BSPPolygon* polygons, int count);
void freeBSP(BSPNode* node);

static int countBSPPolygons(BSPNode *node){
    if (!node) return 0;
    int count = node->polygonCount;
    count += countBSPPolygons(node->front);
    count += countBSPPolygons(node->back);
    return count;
}

static Vertex* flattenBSPTree(BSPNode *node, int *outVertexCount) {
    if (!node) {
        *outVertexCount = 0;
        return NULL;
    }
    // Count total polygons first
    int totalPolygons = countBSPPolygons(node);
    NSLog(@"Total polygons counted: %d", totalPolygons);
    // A polygon has 3 vertices
    int totalVertices = totalPolygons * 3;
    Vertex *vertexArray = malloc(sizeof(Vertex) * totalVertices);
    if (!vertexArray) {
        *outVertexCount = 0;
        return NULL;
    }
    __block int index = 0;
    void (^traverse)(BSPNode *);
    traverse = ^(BSPNode *n) {
        if (!n) return;
        if (index >= totalVertices) {
            NSLog(@"Index out of bounds: %d / %d", index, totalVertices);
            return;
        }
        NSLog(@"Traversing node: %p", n);  // Debugging output
        for (int i = 0; i < n->polygonCount; i++) {
            //Add each vertex to the polygon.
            if (index < totalVertices) {
                vertexArray[index++] = n->polygons[i].vertices[0];
            }
            if (index < totalVertices) {
                vertexArray[index++] = n->polygons[i].vertices[1];
            }
            if (index < totalVertices) {
                vertexArray[index++] = n->polygons[i].vertices[2];
            }
        }
        if (n->front) { // Ensure it's not NULL before using it
            NSLog(@"Traversing front node: %p", n->front);
            traverse(n->front);
        } else {
            NSLog(@"Front node is NULL");
        }

        if (n->back) { // Ensure it's not NULL before using it
            NSLog(@"Traversing back node: %p", n->back);
            traverse(n->back);
        } else {
            NSLog(@"Back node is NULL");
        }
    };
    traverse(node);
    *outVertexCount = totalVertices;
    return vertexArray;
}

@implementation GameViewController
{
    MTKView *_view;

    Renderer *_renderer;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _view = (MTKView *)self.view;
    _view.device = MTLCreateSystemDefaultDevice();

    if(!_view.device)
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
        return;
    }

    _renderer = [[Renderer alloc] initWithMetalKitView:_view];
    [_renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];

    [self updateBSPData];
    _view.delegate = _renderer;
}

- (void)updateBSPData {
    // Step 1: Define cube vertices.
    simd_float3 cubeVertices[] = {
        {-0.5f, -0.5f, -0.5f}, // 0
        { 0.5f, -0.5f, -0.5f}, // 1
        { 0.5f,  0.5f, -0.5f}, // 2
        {-0.5f,  0.5f, -0.5f}, // 3
        {-0.5f, -0.5f,  0.5f}, // 4
        { 0.5f, -0.5f,  0.5f}, // 5
        { 0.5f,  0.5f,  0.5f}, // 6
        {-0.5f,  0.5f,  0.5f}  // 7
    };

    // Step 2: Define 12 triangles (2 per face) via indices.
    unsigned int cubeIndices[] = {
        0, 1, 2, 2, 3, 0,  // Front
        4, 5, 6, 6, 7, 4,  // Back
        0, 4, 7, 7, 3, 0,  // Left
        1, 5, 6, 6, 2, 1,  // Right
        3, 2, 6, 6, 7, 3,  // Top
        0, 1, 5, 5, 4, 0   // Bottom
    };

    // Step 3: Create BSPPolygon array from the cube data.
    const int polygonCount = 12;
    BSPPolygon *polygons = malloc(sizeof(BSPPolygon) * polygonCount);
    if (!polygons) {
        NSLog(@"Memory allocation failed for BSP polygons.");
        return;
    }

    for (int i = 0; i < polygonCount; i++) {
        // RGB(255, 255, 255)
        float r = 255.0f / 255.0f;
        float g = 255.0f / 255.0f;
        float b = 255.0f  / 255.0f;
        
        // Determine UVs based on whether this triangle is the first or second triangle of the face.
        vector_float2 uv[3];
        if ((i % 2) == 0){
            // First Triangle
            uv[0] = (vector_float2){0.0f, 0.0f};
            uv[1] = (vector_float2){1.0f, 0.0f};
            uv[2] = (vector_float2){1.0f, 1.0f};
        } else {
            // Second Triangle
            uv[0] = (vector_float2){1.0f, 1.0f};
            uv[1] = (vector_float2){0.0f, 1.0f};
            uv[2] = (vector_float2){0.0f, 0.0f};
        }

        //Print using i * 3
        NSLog(@"Triangle %d: %d, %d, %d", i,
              cubeIndices[i * 3],
              cubeIndices[i * 3 + 1],
              cubeIndices[i * 3 + 2]);

        for (int j = 0; j < 3; j++) {
            int vertexIndex = cubeIndices[i * 3 + j]; // Use flat indexing into cubeIndices.
            simd_float3 pos = cubeVertices[vertexIndex];
            polygons[i].vertices[j] = (Vertex){
                .position = { pos.x, pos.y, pos.z },
                .color = { r, g, b },
                .texCoord = uv[j]
            };
        }
    }

    // Step 4: Build the BSP tree.
    BSPNode *bspRoot = createBSPNode();
    buildBSP(bspRoot, polygons, polygonCount);

    // Log total polygons for debugging.
    int totalBSPPolygons = countBSPPolygons(bspRoot);
    NSLog(@"Total polygons counted: %d", totalBSPPolygons);

    // Step 5: Flatten the BSP tree into a contiguous vertex array.
    int totalVertices = totalBSPPolygons * 3; // Each polygon is a triangle.
    Vertex *bspVertexArray = malloc(sizeof(Vertex) * totalVertices);
    if (!bspVertexArray) {
        NSLog(@"Failed to allocate vertex array from BSP tree.");
        freeBSP(bspRoot);
        free(polygons);
        return;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    __block int index = 0;
    __block void (^traverse)(BSPNode *);
    traverse = ^(BSPNode *n) {
        if (!n) return;
        for (int i = 0; i < n->polygonCount; i++) {
            if (index < totalVertices)
                bspVertexArray[index++] = n->polygons[i].vertices[0];
                NSLog(@"Vertex[%d]: (%f, %f, %f)", index-1, bspVertexArray[index-1].position.x, bspVertexArray[index-1].position.y, bspVertexArray[index-1].position.z);
            if (index < totalVertices)
                bspVertexArray[index++] = n->polygons[i].vertices[1];
                NSLog(@"Vertex[%d]: (%f, %f, %f)", index-1, bspVertexArray[index-1].position.x, bspVertexArray[index-1].position.y, bspVertexArray[index-1].position.z);
            if (index < totalVertices)
                bspVertexArray[index++] = n->polygons[i].vertices[2];
                NSLog(@"Vertex[%d]: (%f, %f, %f)", index-1, bspVertexArray[index-1].position.x, bspVertexArray[index-1].position.y, bspVertexArray[index-1].position.z);
        }
        traverse(n->front);
        traverse(n->back);
    };
    traverse(bspRoot);
    NSLog(@"Flattened BSP vertex array with %d vertices", index);

    // Step 6: Update the renderer’s vertex buffer.
    [_renderer updateBSPVertexBufferWithVertices:bspVertexArray count:totalVertices];

    // Step 7: Clean up.
    free(bspVertexArray);
    freeBSP(bspRoot);
    free(polygons);
}
@end
