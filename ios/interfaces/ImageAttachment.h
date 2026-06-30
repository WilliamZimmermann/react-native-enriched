#import "ImageData.h"
#import "MediaAttachment.h"

@interface ImageAttachment : MediaAttachment

@property(nonatomic, strong) ImageData *imageData;
@property(nonatomic, strong) UIImage *storedAnimatedImage;
/** YES once a REAL image has been decoded (warm-cache reuse or a successful
 *  fetch). NO while a failed load is showing the SF-Symbol placeholder —
 * callers must not seed the cache from a placeholder, or the broken image would
 * stick for the rest of the session. */
@property(nonatomic, assign) BOOL didLoad;

- (instancetype)initWithImageData:(ImageData *)data;

/** Seed the shared by-URI image cache so a subsequent attachment rebuilt for
 *  the same URI reuses this already-decoded image instead of re-fetching it.
 *  Used when an attachment is recreated for a metadata-only change (e.g.
 * setting a caption): the old attachment already holds the decoded image, so
 * handing it to the cache keeps the rebuilt one from hitting the network —
 * which otherwise flickers/duplicates the image online and collapses it to 0×0
 * offline. */
+ (void)seedCacheWithImage:(UIImage *)image forURI:(NSString *)uri;

/** Font used to render the caption below the image. */
+ (UIFont *)captionFont;
/** Height (pts) the caption needs at `width`, wrapping across as many lines as
 *  the text requires. 0 for an empty caption or non-positive width. */
+ (CGFloat)captionHeightForCaption:(NSString *)caption width:(CGFloat)width;
/** Vertical space (pts) reserved below the image for the caption, or 0. */
- (CGFloat)captionReservedHeight;

@end
