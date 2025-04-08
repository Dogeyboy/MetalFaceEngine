//
//  YAMLLoader.h
//  BSPMetalRenderer
//
//  Created by Joao Da Paixao on 4/8/25.
//

#import <Foundation/Foundation.h>
#import "ModelData.h"

@interface YAMLLoader : NSObject

+ (ModelData *)loadModelFromYAMLFile:(NSString *)path;

@end
