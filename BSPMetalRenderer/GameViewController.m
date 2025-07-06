//
//  GameViewController.m
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 4/3/25.
//

#import "GameViewController.h"
#import "Renderer.h"
#import "ShaderTypes.h"

@implementation GameViewController
{
    MTKView *_view;

    Renderer *_renderer;
    
    AssetModel *_assetModel;
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
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Earth" ofType:@"mfeassets"];
    _assetModel = loadMFEAsset(path.UTF8String);
    if (!_assetModel) {
      NSLog(@"Failed to load asset");
    } else {
      [self updateAssetData];
    }

    _renderer = [[Renderer alloc] initWithMetalKitView:_view mapFile:_map];
    [_renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];

    _view.delegate = _renderer;
}

- (void)updateAssetData {
  // flatten your AssetModel into the same Vertex struct you use in Renderer:
  NSUInteger vCount = _assetModel->vertexCount;
  Vertex *verts = malloc(sizeof(Vertex)*vCount);
  for (NSUInteger i = 0; i < vCount; i++) {
    AssetVertex *av = &_assetModel->vertices[i];
    verts[i].position = (vector_float3){ av->x, av->y, av->z };
    verts[i].texCoord = (vector_float2){ av->u, av->v };
    verts[i].color    = (vector_float4){ av->r, av->g, av->b, av->a };
  }
  // now tell the renderer about these buffers:
  [_renderer updateModelVertexBufferWithVertices:verts
                                           count:vCount
                                      indexBuffer:_assetModel->indices
                                       indexCount:_assetModel->indexCount
                                     textureName:_assetModel->textureName];
  free(verts);
}
@end
