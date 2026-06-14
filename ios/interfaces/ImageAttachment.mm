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
    self.storedAnimatedImage = cachedImage;
  } else {
    [self loadAsync];
  }
  return self;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFrag
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex {
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
  return CGRectMake(baseBounds.origin.x, descender, baseBounds.size.width,
                    baseBounds.size.height - descender);
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
