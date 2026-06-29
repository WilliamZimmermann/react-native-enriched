#import "ImageData.h"
#import "MediaAttachment.h"

@interface ImageAttachment : MediaAttachment

@property(nonatomic, strong) ImageData *imageData;
@property(nonatomic, strong) UIImage *storedAnimatedImage;

- (instancetype)initWithImageData:(ImageData *)data;

/** Font used to render the caption below the image. */
+ (UIFont *)captionFont;
/** Height (pts) the caption needs at `width`, wrapping across as many lines as
 *  the text requires. 0 for an empty caption or non-positive width. */
+ (CGFloat)captionHeightForCaption:(NSString *)caption width:(CGFloat)width;
/** Vertical space (pts) reserved below the image for the caption, or 0. */
- (CGFloat)captionReservedHeight;

@end
