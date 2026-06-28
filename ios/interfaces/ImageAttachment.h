#import "ImageData.h"
#import "MediaAttachment.h"

@interface ImageAttachment : MediaAttachment

@property(nonatomic, strong) ImageData *imageData;
@property(nonatomic, strong) UIImage *storedAnimatedImage;

- (instancetype)initWithImageData:(ImageData *)data;

/** Font used to render the caption below the image. */
+ (UIFont *)captionFont;
/** Vertical space (pts) reserved below the image for the caption, or 0. */
- (CGFloat)captionReservedHeight;

@end
