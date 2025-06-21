//
//  Renderer.h
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 4/3/25.
//

#import <MetalKit/MetalKit.h>
#import "ShaderTypes.h"
#import "AssetData.h"

#define MAX_INSTANCES 10

// Our platform independent renderer class.   Implements the MTKViewDelegate protocol which
//   allows it to accept per-frame update and drawable resize callbacks.
@interface Renderer : NSObject <MTKViewDelegate> {
    AssetModel *_assetModel;
}

@property (nonatomic, assign) NSUInteger   indexCount;
@property (nonatomic, strong) id<MTLBuffer> _Nonnull indexBuffer;

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
- (void)updateModelVertexBufferWithVertices:(Vertex* _Nonnull)verts
                                       count:(NSUInteger)vCount
                                 indexBuffer:(uint32_t* _Nonnull)indices
                                  indexCount:(NSUInteger)iCount
                                textureName:(char* _Nonnull)texName;
@end
