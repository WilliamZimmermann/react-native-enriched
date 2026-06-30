#import "EnrichedTextInputView.h"
#import "ImageAttachment.h"
#import "StyleHeaders.h"
#import "TextInsertionUtils.h"

// custom NSAttributedStringKey to differentiate the image
static NSString *const ImageAttributeName = @"EnrichedImage";

@implementation ImageStyle

+ (StyleType)getType {
  return Image;
}

- (NSString *)getKey {
  return ImageAttributeName;
}

- (BOOL)isParagraph {
  return NO;
}

- (void)applyStyling:(NSRange)range {
  // no-op for image
}

- (void)reapplyFromStylePair:(StylePair *)pair {
  NSRange range = [pair.rangeValue rangeValue];
  ImageData *imageData = (ImageData *)pair.styleValue;
  if (imageData == nullptr || range.length == 0) {
    return;
  }

  ImageAttachment *attachment =
      [[ImageAttachment alloc] initWithImageData:imageData];
  attachment.delegate = (id)self.host;

  [self.host.textView.textStorage addAttributes:@{
    NSAttachmentAttributeName : attachment,
    ImageAttributeName : imageData
  }
                                          range:range];
}

- (AttributeEntry *)getEntryIfPresent:(NSRange)range {
  return nullptr;
}

- (void)toggle:(NSRange)range {
  // no-op for image
}

- (void)remove:(NSRange)range withDirtyRange:(BOOL)withDirtyRange {
  [self.host.textView.textStorage beginEditing];
  [self.host.textView.textStorage removeAttribute:ImageAttributeName
                                            range:range];
  [self.host.textView.textStorage removeAttribute:NSAttachmentAttributeName
                                            range:range];
  [self.host.textView.textStorage endEditing];

  if (withDirtyRange) {
    [self.host.attributesManager addDirtyRange:range];
  }

  [self removeTyping];
}

- (void)removeTyping {
  NSMutableDictionary *currentAttributes =
      [self.host.textView.typingAttributes mutableCopy];
  [currentAttributes removeObjectForKey:ImageAttributeName];
  [currentAttributes removeObjectForKey:NSAttachmentAttributeName];
  [self.host.attributesManager didRemoveTypingAttribute:ImageAttributeName];
  self.host.textView.typingAttributes = currentAttributes;
}

- (BOOL)styleCondition:(id _Nullable)value range:(NSRange)range {
  return [value isKindOfClass:[ImageData class]];
}

- (ImageData *)getImageDataAt:(NSUInteger)location {
  NSRange imageRange = NSMakeRange(0, 0);
  NSRange inputRange = NSMakeRange(0, self.host.textView.textStorage.length);

  // don't search at the very end of input
  NSUInteger searchLocation = location;
  if (searchLocation == self.host.textView.textStorage.length) {
    return nullptr;
  }

  ImageData *imageData =
      [self.host.textView.textStorage attribute:ImageAttributeName
                                        atIndex:searchLocation
                          longestEffectiveRange:&imageRange
                                        inRange:inputRange];

  return imageData;
}

- (void)addImageAtRange:(NSRange)range
              imageData:(ImageData *)imageData
          withSelection:(BOOL)withSelection
         withDirtyRange:(BOOL)withDirtyRange {
  if (!imageData)
    return;

  ImageAttachment *attachment =
      [[ImageAttachment alloc] initWithImageData:imageData];
  attachment.delegate = (id)self.host;

  NSDictionary *attributes =
      @{NSAttachmentAttributeName : attachment, ImageAttributeName : imageData};

  // Use the Object Replacement Character for Image.
  // This tells TextKit "something non-text goes here".
  NSString *placeholderChar = @"\uFFFC";

  if (range.length == 0) {
    [TextInsertionUtils insertText:placeholderChar
                                at:range.location
              additionalAttributes:attributes
                              host:self.host
                     withSelection:withSelection];
  } else {
    [TextInsertionUtils replaceText:placeholderChar
                                 at:range
               additionalAttributes:attributes
                               host:self.host
                      withSelection:withSelection];
  }

  if (withDirtyRange) {
    NSRange insertedImageRange = NSMakeRange(range.location, 1);
    [self.host.attributesManager addDirtyRange:insertedImageRange];
  }
}

- (void)addImage:(NSString *)uri width:(CGFloat)width height:(CGFloat)height {
  ImageData *data = [[ImageData alloc] init];
  data.uri = uri;
  data.width = width;
  data.height = height;

  [self addImageAtRange:self.host.textView.selectedRange
              imageData:data
          withSelection:YES
         withDirtyRange:YES];
}

- (void)setSelectedImageCaption:(NSString *)caption {
  NSUInteger location = self.host.textView.selectedRange.location;
  ImageData *data = [self getImageDataAt:location];
  if (data == nullptr) {
    return;
  }
  data.caption = (caption.length > 0) ? caption : nil;

  // Find the image's 1-char range and rebuild its attachment so layout reserves
  // caption space and the overlay re-renders.
  NSRange imageRange = NSMakeRange(0, 0);
  NSRange inputRange = NSMakeRange(0, self.host.textView.textStorage.length);
  id existing =
      [self.host.textView.textStorage attribute:NSAttachmentAttributeName
                                        atIndex:location
                          longestEffectiveRange:&imageRange
                                        inRange:inputRange];
  if (imageRange.length == 0) {
    return;
  }

  // Hand the OLD attachment's already-decoded image to the by-URI cache before
  // rebuilding, so the new attachment reuses it instead of re-fetching. The
  // rebuild is only to refresh layout for the caption change — the bytes are
  // unchanged. Without this, the rebuilt attachment re-downloads the image,
  // which flickered/duplicated it online and collapsed it to 0×0 offline (a
  // failed fetch leaves no image) while the glyph box kept the old size.
  if ([existing isKindOfClass:[ImageAttachment class]]) {
    ImageAttachment *existingImage = (ImageAttachment *)existing;
    // Only seed from a REALLY loaded image. If the image failed to load,
    // storedAnimatedImage is the SF-Symbol placeholder; seeding that would warm
    // the cache with the broken image so every rebuild this session skips the
    // re-fetch and shows the placeholder even after the network recovers.
    if (existingImage.didLoad && existingImage.storedAnimatedImage != nil) {
      [ImageAttachment seedCacheWithImage:existingImage.storedAnimatedImage
                                   forURI:data.uri];
    }
  }

  ImageAttachment *attachment =
      [[ImageAttachment alloc] initWithImageData:data];
  attachment.delegate = (id)self.host;
  [self.host.textView.textStorage beginEditing];
  [self.host.textView.textStorage addAttributes:@{
    NSAttachmentAttributeName : attachment,
    ImageAttributeName : data
  }
                                          range:imageRange];
  [self.host.textView.textStorage endEditing];
  // Kept as-is (reserves caption space / re-renders the overlay). It does cause
  // a second rebuild via ImageStyle.reapplyFromStylePair, but with the cache
  // seeded above that rebuild now reuses the decoded image too (no re-fetch),
  // so it's cheap. Left intact to avoid changing the proven layout path; if
  // churn ever matters it can be removed once verified.
  [self.host.attributesManager addDirtyRange:imageRange];
}

@end
