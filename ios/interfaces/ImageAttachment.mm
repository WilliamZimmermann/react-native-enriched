#import "ImageAttachment.h"
#import "EnrichedImageAuth.h"
#import "ImageExtension.h"

// NSTextStorage frequently recreates NSTextAttachment objects during attribute
// invalidation (e.g. on every keystroke). Without this cache each recreation
// would trigger a fresh async network/disk load, causing images to flicker or
// disappear temporarily. Caching by URI ensures that once an image is loaded it
// is reused instantly for all subsequent attachment instances with the same
// URI
static NSCache<NSString *, UIImage *> *ImageAttachmentCache(void) {
  static NSCache<NSString *, UIImage *> *cache = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cache = [[NSCache alloc] init];
    cache.totalCostLimit = 100 * 1024 * 1024; // 100 MB
  });
  return cache;
}

@interface ImageAttachment ()
- (NSData *)fetchBytesForURL:(NSURL *)url;
@end

@implementation ImageAttachment

- (instancetype)initWithImageData:(ImageData *)data {
  self = [super initWithURI:data.uri width:data.width height:data.height];
  if (!self)
    return nil;

  _imageData = data;
  UIImage *cachedImage = nil;
  if (self.uri.length > 0) {
    cachedImage = [ImageAttachmentCache() objectForKey:self.uri];
  }

  // Assign an empty image to reserve layout space within the text system.
  // The actual image is not drawn here; it is rendered and overlaid by a
  // separate ImageView.
  self.image = [UIImage new];

  if (cachedImage != nil) {
    // Web-authored notes store <img width="0" height="0">; when the image is
    // already in the cache we never enter loadAsync, so self.width/height stay
    // at 0 and attachmentBoundsForTextContainer returns a 0×0 rect — making
    // the image invisible on navigate-back (warm cache, cold dimensions).
    // Mirror the loadAsync pattern exactly: set width/height/bounds so the
    // first layout pass has non-zero values, then kick notifyUpdate async so
    // the text layout manager repositions the ImageView overlay after init
    // completes (same reason loadAsync dispatches notifyUpdate on main queue).
    if ((self.width <= 0 || self.height <= 0) && cachedImage.size.width > 0 &&
        cachedImage.size.height > 0) {
      self.width = cachedImage.size.width;
      self.height = cachedImage.size.height;
      self.bounds =
          CGRectMake(0, 0, cachedImage.size.width, cachedImage.size.height);
    }
    self.storedAnimatedImage = cachedImage;
    dispatch_async(dispatch_get_main_queue(), ^{
      [self notifyUpdate];
    });
  } else {
    [self loadAsync];
  }
  return self;
}

+ (UIFont *)captionFont {
  return [UIFont systemFontOfSize:13];
}

// Caption is rendered below the image (best-effort; needs on-device tuning).
static const CGFloat kCaptionGap = 4.0;

+ (CGFloat)captionHeightForCaption:(NSString *)caption width:(CGFloat)width {
  if (caption == nil || caption.length == 0 || width <= 0) {
    return 0;
  }
  // Measure the wrapped text height so long captions span multiple lines
  // instead of being clipped to one.
  CGRect rect =
      [caption boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                            options:NSStringDrawingUsesLineFragmentOrigin |
                                    NSStringDrawingUsesFontLeading
                         attributes:@{
                           NSFontAttributeName : [ImageAttachment captionFont]
                         }
                            context:nil];
  return ceil(rect.size.height);
}

- (CGFloat)captionReservedHeight {
  NSString *caption = self.imageData.caption;
  if (caption == nil || caption.length == 0) {
    return 0;
  }
  CGFloat textHeight =
      [ImageAttachment captionHeightForCaption:caption
                                         width:self.bounds.size.width];
  if (textHeight <= 0) {
    // No usable width yet (pre-layout) — reserve a single line so the row
    // doesn't collapse; the next layout pass reserves the true wrapped height.
    textHeight = ceil([ImageAttachment captionFont].lineHeight);
  }
  return kCaptionGap + textHeight;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFrag
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex {
  // Fit the image to the editor's content width (preserve aspect). Recomputed
  // from the stored intrinsic/author size every layout so it stays correct
  // across rotation / sidebar resize, and so a large image never overflows.
  if (textContainer != nil) {
    CGFloat available =
        textContainer.size.width - 2 * textContainer.lineFragmentPadding;
    if (available > 0 && self.width > 0 && self.height > 0) {
      CGFloat w = self.width;
      CGFloat h = self.height;
      if (w > available) {
        h = h * (available / w);
        w = available;
      }
      self.bounds = CGRectMake(0, 0, w, h);
    }
  }

  CGRect baseBounds = self.bounds;

  if (!textContainer.layoutManager.textStorage ||
      charIndex >= textContainer.layoutManager.textStorage.length) {
    return baseBounds;
  }

  UIFont *font =
      [textContainer.layoutManager.textStorage attribute:NSFontAttributeName
                                                 atIndex:charIndex
                                          effectiveRange:NULL];
  if (!font) {
    return baseBounds;
  }

  // Extend the layout bounds below the baseline by the font's descender.
  // Without this, a line containing only the attachment has no descender space
  // below the baseline, but adding a text character introduces it — causing
  // the line height to jump.  By reserving descender space upfront the line
  // height stays consistent regardless of whether text is present.
  CGFloat descender = font.descender;
  // Reserve extra space below the image for the caption (drawn by the overlay
  // layout as a label below the UIImageView).
  CGFloat caption = [self captionReservedHeight];
  return CGRectMake(baseBounds.origin.x, descender - caption,
                    baseBounds.size.width,
                    baseBounds.size.height - descender + caption);
}

- (void)loadAsync {
  NSURL *url = [NSURL URLWithString:self.uri];
  if (!url) {
    self.storedAnimatedImage = [UIImage systemImageNamed:@"photo"];
    return;
  }

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSData *bytes = [self fetchBytesForURL:url];

    // We pass all image data (including static formats like PNG or JPEG)
    // through the animated image parser. It safely acts as a universal parser,
    // returning a single-frame UIImage for static formats and an animated
    // UIImage for GIFs and WebPs.
    UIImage *img = bytes ? [UIImage animatedImageWithData:bytes]
                         : [UIImage systemImageNamed:@"photo"];

    dispatch_async(dispatch_get_main_queue(), ^{
      if (bytes != nil && img != nil && self.uri.length > 0) {
        CGFloat scale = img.scale;
        // Calculate true byte cost based on pixels
        // Width (in pixels) * Height (in pixels) * 4 bytes (for RGBA channels)
        NSUInteger cost = (NSUInteger)(img.size.width * scale *
                                       img.size.height * scale * 4.0);
        [ImageAttachmentCache() setObject:img forKey:self.uri cost:cost];
      }
      // Web-authored notes store <img width="0" height="0"> and let CSS size
      // the image; without usable author dimensions the native editor would
      // draw it at 0×0 (invisible). Adopt the loaded image's intrinsic size —
      // the layout pass (attachmentBoundsForTextContainer:) clamps it to the
      // editor's width.
      if (img != nil && (self.width <= 0 || self.height <= 0) &&
          img.size.width > 0 && img.size.height > 0) {
        self.width = img.size.width;
        self.height = img.size.height;
        self.bounds = CGRectMake(0, 0, img.size.width, img.size.height);
      }
      self.storedAnimatedImage = img;
      [self notifyUpdate];
    });
  });
}

// Loads bytes for `url`. When the URL matches the configured API origin we
// attach the session bearer token (the enriched editor can't otherwise send a
// header for plain note <img> tags). Falls back to a plain load otherwise.
- (NSData *)fetchBytesForURL:(NSURL *)url {
  NSString *token = [EnrichedImageAuth tokenForURL:url];
  if (token == nil) {
    return [NSData dataWithContentsOfURL:url];
  }

  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setValue:[NSString stringWithFormat:@"Bearer %@", token]
      forHTTPHeaderField:@"Authorization"];

  __block NSData *result = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  NSURLSessionDataTask *task = [[NSURLSession sharedSession]
      dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response,
                            NSError *error) {
          NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
                                 ? ((NSHTTPURLResponse *)response).statusCode
                                 : 200;
          if (data != nil && error == nil && status >= 200 && status < 300) {
            result = data;
          }
          dispatch_semaphore_signal(sem);
        }];
  [task resume];
  dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER); // already on a bg queue
  return result;
}

@end
