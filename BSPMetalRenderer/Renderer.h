//
//  Renderer.h
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 4/3/25.
//

#import <MetalKit/MetalKit.h>
#import "ShaderTypes.h"

// Our platform independent renderer class.   Implements the MTKViewDelegate protocol which
//   allows it to accept per-frame update and drawable resize callbacks.
@interface Renderer : NSObject <MTKViewDelegate>

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
- (void)updateBSPVertexBufferWithVertices:(Vertex * _Nonnull)vertices count:(NSUInteger)count;
@end
