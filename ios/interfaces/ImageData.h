#pragma once
#import <UIKit/UIKit.h>

@interface ImageData : NSObject

@property NSString *uri;
@property CGFloat width;
@property CGFloat height;
/** Optional caption shown below the image; round-trips as `data-caption`. */
@property(nullable) NSString *caption;

@end
