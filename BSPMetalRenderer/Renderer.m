//
//  Renderer.m
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 4/3/25.
//

#import <simd/simd.h>
#import <ModelIO/ModelIO.h>

#import "Renderer.h"

// Include header shared between C code here, which executes Metal API commands, and .metal files
#import "ShaderTypes.h"
#import "AssetData.h"

static const NSUInteger kMaxBuffersInFlight = 3;

static const size_t kAlignedUniformsSize = (sizeof(Uniforms) & ~0xFF) + 0x100;

@implementation Renderer
{
    dispatch_semaphore_t _inFlightSemaphore;
    id <MTLDevice> _device;
    id <MTLCommandQueue> _commandQueue;

    id <MTLBuffer> _dynamicUniformBuffer;
    id <MTLBuffer> _vertexBuffer;
    id <MTLBuffer> _indexBuffer;
    NSUInteger _vertexCount;
    
    id<MTLSamplerState> samplerState;
    
    id <MTLRenderPipelineState> _pipelineState;
    id <MTLDepthStencilState> _depthState;
    id <MTLTexture> _colorMap;
    MTLVertexDescriptor *_mtlVertexDescriptor;

    uint32_t _uniformBufferOffset;
    uint8_t _uniformBufferIndex;
    void* _uniformBufferAddress;

    matrix_float4x4 _projectionMatrix;
    float _rotation;
    MTKMesh *_mesh;
    
}

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
{
    self = [super init];
    if(self)
    {
        _device = view.device;
        _inFlightSemaphore = dispatch_semaphore_create(kMaxBuffersInFlight);
        [self _loadMetalWithView:view];
        [self _loadAssets];
        NSString *assetPath = [[NSBundle mainBundle] pathForResource:@"Earth"
                                                         ofType:@"mfeassets"];
        if (assetPath.length == 0) {
            NSLog(@"Could not find asset model in bundle");
        } else {
            _assetModel = loadMFEAsset(assetPath.UTF8String);
            if (_assetModel) {
                NSLog(@"Texture: %s", _assetModel->textureName);
                for (int i = 0; i < _assetModel->vertexCount; i++) {
                    printf("v[%d] = (%f, %f, %f)\n", i,
                    _assetModel->vertices[i].x,
                    _assetModel->vertices[i].y,
                    _assetModel->vertices[i].z);
                }
                NSUInteger vCount = _assetModel->vertexCount;
                Vertex *verts = malloc(sizeof(Vertex) * vCount);
                for (NSUInteger i = 0; i < vCount; i++) {
                    AssetVertex *av = &_assetModel->vertices[i];
                    verts[i].position = (vector_float3){ av->x, av->y, av->z };
                    verts[i].texCoord = (vector_float2){ av->u, av->v };
                    verts[i].color    = (vector_float4){ av->r, av->g, av->b, av->a };
                }
                [self updateModelVertexBufferWithVertices:verts
                                                    count:vCount
                                               indexBuffer:_assetModel->indices
                                                indexCount:_assetModel->indexCount
                                              textureName:_assetModel->textureName];
                free(verts);
            }
            else {
                NSLog(@"Failed to load asset model");
            }
        }
    }

    MTLSamplerDescriptor *samplerDescriptor = [[MTLSamplerDescriptor alloc] init];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.mipFilter = MTLSamplerMipFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;

    self->samplerState = [_device newSamplerStateWithDescriptor:samplerDescriptor];
    
    return self;
}

- (id<MTLTexture>)_loadTextureNamed:(NSString*)name
{
    // metalKit loader
    MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice:_device];
    if (name.length == 0) {
        NSLog(@"[_loadTextureNamed:] called with empty name, skipping texture load.");
        return nil;
    }
    NSError *error = nil;
    // look in main bundle
    id<MTLTexture> tex = [loader newTextureWithName:name
                                         scaleFactor:1.0
                                              bundle:[NSBundle mainBundle]
                                             options:@{ MTKTextureLoaderOptionSRGB : @YES }
                                               error:&error];
    if (!tex) {
        NSLog(@"Failed to load texture %@: %@", name, error);
    }
    return tex;
}

- (void)updateModelVertexBufferWithVertices:(Vertex*)verts
                                       count:(NSUInteger)vCount
                                 indexBuffer:(uint32_t*)indices
                                  indexCount:(NSUInteger)iCount
                                textureName:(char*)texName
{
    _vertexCount = vCount;
    _vertexBuffer = [_device newBufferWithBytes:verts
                                       length:sizeof(Vertex)*vCount
                                      options:MTLResourceStorageModeShared];
    _indexCount  = iCount;
    _indexBuffer = [_device newBufferWithBytes:indices
                                        length:sizeof(uint32_t)*iCount
                                       options:MTLResourceStorageModeShared];
    _colorMap = [self _loadTextureNamed:[NSString stringWithUTF8String:texName]];
    
    NSLog(@"Loading texture named: %s", texName);
}

- (void)_loadMetalWithView:(nonnull MTKView *)view;
{
    /// Load Metal state objects and initialize renderer dependent view properties

    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    view.sampleCount = 1;

    _mtlVertexDescriptor = [[MTLVertexDescriptor alloc] init];

    // Position (attribute 0)
    _mtlVertexDescriptor.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
    _mtlVertexDescriptor.attributes[VertexAttributePosition].offset = offsetof(Vertex, position);
    _mtlVertexDescriptor.attributes[VertexAttributePosition].bufferIndex = 0;

    // Color (attribute 1) – if you want to pass it along (even if the fragment shader currently ignores it)
    _mtlVertexDescriptor.attributes[VertexAttributeColor].format = MTLVertexFormatFloat4;
    _mtlVertexDescriptor.attributes[VertexAttributeColor].offset = offsetof(Vertex, color);
    _mtlVertexDescriptor.attributes[VertexAttributeColor].bufferIndex = 0;

    // TexCoord (attribute 2)
    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].format = MTLVertexFormatFloat2;
    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].offset = offsetof(Vertex, texCoord);
    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].bufferIndex = 0;

    // Set layout for buffer index 0
    _mtlVertexDescriptor.layouts[0].stride = sizeof(Vertex);
    _mtlVertexDescriptor.layouts[0].stepRate = 1;
    _mtlVertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;

    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

    id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];

    id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];

    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"MyPipeline";
    pipelineStateDescriptor.rasterSampleCount = view.sampleCount;
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.vertexDescriptor = _mtlVertexDescriptor;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    pipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    pipelineStateDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;

    NSError *error = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!_pipelineState) {
        NSLog(@"Failed to create pipeline state: %@", error);
        return;
    }

    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];

    NSUInteger uniformBufferSize = kAlignedUniformsSize * kMaxBuffersInFlight;

    _dynamicUniformBuffer = [_device newBufferWithLength:uniformBufferSize
                                                 options:MTLResourceStorageModeShared];

    _dynamicUniformBuffer.label = @"UniformBuffer";

    _commandQueue = [_device newCommandQueue];
}

- (void)_loadAssets
{
    /// Load assets into metal objects

    NSError *error = nil;

    MTKMeshBufferAllocator *metalAllocator = [[MTKMeshBufferAllocator alloc]
                                              initWithDevice: _device];

    MDLMesh *mdlMesh = [MDLMesh newBoxWithDimensions:(vector_float3){4, 4, 4}
                                            segments:(vector_uint3){2, 2, 2}
                                        geometryType:MDLGeometryTypeTriangles
                                       inwardNormals:NO
                                           allocator:metalAllocator];

    MDLVertexDescriptor *mdlVertexDescriptor =
    MTKModelIOVertexDescriptorFromMetal(_mtlVertexDescriptor);

    mdlVertexDescriptor.attributes[VertexAttributePosition].name  = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[VertexAttributeTexcoord].name  = MDLVertexAttributeTextureCoordinate;

    mdlMesh.vertexDescriptor = mdlVertexDescriptor;

    _mesh = [[MTKMesh alloc] initWithMesh:mdlMesh
                                   device:_device
                                    error:&error];

    if(!_mesh || error)
    {
        NSLog(@"Error creating MetalKit mesh %@", error.localizedDescription);
    }

    MTKTextureLoader* textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
    NSDictionary *textureLoaderOptions =
    @{
      MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead),
      MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate)
      };
    
    _colorMap = [textureLoader newTextureWithName:@"WoodCrate"
                                      scaleFactor:1.0
                                           bundle:nil
                                          options:textureLoaderOptions
                                            error:&error];

    if(!_colorMap || error)
    {
        NSLog(@"Error creating texture %@", error.localizedDescription);
    }
}

- (void)_updateDynamicBufferState
{
    /// Update the state of our uniform buffers before rendering

    _uniformBufferIndex = (_uniformBufferIndex + 1) % kMaxBuffersInFlight;

    _uniformBufferOffset = kAlignedUniformsSize * _uniformBufferIndex;

    _uniformBufferAddress = ((uint8_t*)_dynamicUniformBuffer.contents) + _uniformBufferOffset;
}

- (void)_updateGameState
{
    /// Update any game state before encoding renderint commands to our drawable

    Uniforms * uniforms = (Uniforms*)_uniformBufferAddress;

    uniforms->projectionMatrix = _projectionMatrix;

    vector_float3 rotationAxis = {1, 0, 0};
    matrix_float4x4 modelMatrix = matrix4x4_rotation(_rotation, rotationAxis);
    matrix_float4x4 viewMatrix = matrix4x4_translation(0.0, 0.0, -8.0);

    uniforms->modelViewMatrix = matrix_multiply(viewMatrix, modelMatrix);

    _rotation += 0.01;
}

- (void)_createModelBuffers {
    // 1) Vertex buffer
    _vertexCount = _assetModel->vertexCount;
    _vertexBuffer = [_device newBufferWithBytes:_assetModel->vertices
                                        length:sizeof(AssetVertex) * _vertexCount
                                       options:MTLResourceStorageModeShared];
    _vertexBuffer.label = @"AssetModel Vertex Buffer";

    // 2) Index buffer
    _indexBuffer = [_device newBufferWithBytes:_assetModel->indices
                                       length:sizeof(uint32_t) * _assetModel->indexCount
                                      options:MTLResourceStorageModeShared];
    _indexBuffer.label = @"AssetModel Index Buffer";

    // 3) Load texture from name stored in model
    if (_assetModel->textureName) {
        NSError *err = nil;
        MTKTextureLoader *texLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
        
        _colorMap = [texLoader newTextureWithName:[NSString stringWithUTF8String:_assetModel->textureName]
                                      scaleFactor:1.0
                                           bundle:nil
                                          options:@{ MTKTextureLoaderOptionSRGB : @YES }
                                            error:&err];
        if (!_colorMap || err) {
            NSLog(@"⚠️ Texture load failed: %@", err.localizedDescription);
        } else {
            _colorMap.label = @"Model Texture";
        }
    }
}

- (void)drawInMTKView:(nonnull MTKView *)view
{
    /// Per frame updates here

    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);

    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer)
     {
         dispatch_semaphore_signal(block_sema);
     }];

    [self _updateDynamicBufferState];

    [self _updateGameState];

    /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
    ///   holding onto the drawable and blocking the display pipeline any longer than necessary
    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil) {

        /// Final pass rendering code here

        id <MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        [renderEncoder pushDebugGroup:@"DrawBox"];

        [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
        [renderEncoder setCullMode:MTLCullModeNone];
        [renderEncoder setRenderPipelineState:_pipelineState];
        [renderEncoder setDepthStencilState:_depthState];

        [renderEncoder setVertexBuffer:_dynamicUniformBuffer
                                offset:_uniformBufferOffset
                               atIndex:BufferIndexUniforms];

        [renderEncoder setFragmentBuffer:_dynamicUniformBuffer
                                  offset:_uniformBufferOffset
                                 atIndex:BufferIndexUniforms];

        /*
        for (NSUInteger bufferIndex = 0; bufferIndex < _mesh.vertexBuffers.count; bufferIndex++)
        {
            MTKMeshBuffer *vertexBuffer = _mesh.vertexBuffers[bufferIndex];
            if((NSNull*)vertexBuffer != [NSNull null])
            {
                [renderEncoder setVertexBuffer:vertexBuffer.buffer
                                        offset:vertexBuffer.offset
                                       atIndex:bufferIndex];
            }
        }
        */

        if (_vertexBuffer && _indexBuffer) {
            [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
            if (_colorMap) {
                [renderEncoder setFragmentTexture:_colorMap atIndex:0];
            }
            if (samplerState) {
                [renderEncoder setFragmentSamplerState:samplerState atIndex:0];
            }
            [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                      indexCount:_indexCount
                                       indexType:MTLIndexTypeUInt32
                                     indexBuffer:_indexBuffer
                               indexBufferOffset:0];
        }

        /*
        for(MTKSubmesh *submesh in _mesh.submeshes)
        {
            [renderEncoder drawIndexedPrimitives:submesh.primitiveType
                                      indexCount:submesh.indexCount
                                       indexType:submesh.indexType
                                     indexBuffer:submesh.indexBuffer.buffer
                               indexBufferOffset:submesh.indexBuffer.offset];
        }
        */

        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];
    }

    [commandBuffer commit];
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    /// Respond to drawable size or orientation changes here

    float aspect = size.width / (float)size.height;
    _projectionMatrix = matrix_perspective_right_hand(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);
}

#pragma mark Matrix Math Utilities

matrix_float4x4 matrix4x4_translation(float tx, float ty, float tz)
{
    return (matrix_float4x4) {{
        { 1,   0,  0,  0 },
        { 0,   1,  0,  0 },
        { 0,   0,  1,  0 },
        { tx, ty, tz,  1 }
    }};
}

static matrix_float4x4 matrix4x4_rotation(float radians, vector_float3 axis)
{
    axis = vector_normalize(axis);
    float ct = cosf(radians);
    float st = sinf(radians);
    float ci = 1 - ct;
    float x = axis.x, y = axis.y, z = axis.z;

    return (matrix_float4x4) {{
        { ct + x * x * ci,     y * x * ci + z * st, z * x * ci - y * st, 0},
        { x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0},
        { x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0},
        {                   0,                   0,                   0, 1}
    }};
}

matrix_float4x4 matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ)
{
    float ys = 1 / tanf(fovyRadians * 0.5);
    float xs = ys / aspect;
    float zs = farZ / (nearZ - farZ);

    return (matrix_float4x4) {{
        { xs,   0,          0,  0 },
        {  0,  ys,          0,  0 },
        {  0,   0,         zs, -1 },
        {  0,   0, nearZ * zs,  0 }
    }};
}

- (void)dealloc
{
    if (_assetModel) {
        freeAssetModel(_assetModel);
        _assetModel = NULL;
    }
}
@end
