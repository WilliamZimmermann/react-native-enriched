#import "AttachmentLayoutUtils.h"

@implementation AttachmentLayoutUtils

+ (void)handleAttachmentUpdate:(MediaAttachment *)attachment
                      textView:(UITextView *)textView
                 onLayoutBlock:(dispatch_block_t)layoutBlock {
  NSTextStorage *storage = textView.textStorage;
  NSRange fullRange = NSMakeRange(0, storage.length);

  __block NSRange foundRange = NSMakeRange(NSNotFound, 0);

  [storage enumerateAttribute:NSAttachmentAttributeName
                      inRange:fullRange
                      options:0
                   usingBlock:^(id value, NSRange range, BOOL *stop) {
                     if (value == attachment) {
                       foundRange = range;
                       *stop = YES;
                     }
                   }];

  if (foundRange.location == NSNotFound) {
    return;
  }

  [storage edited:NSTextStorageEditedAttributes
               range:foundRange
      changeInLength:0];

  dispatch_async(dispatch_get_main_queue(), layoutBlock);
}

+ (NSMutableDictionary<NSValue *, UIImageView *> *)
    layoutAttachmentsInTextView:(UITextView *)textView
                         config:(EnrichedConfig *)config
                  existingViews:
                      (NSMutableDictionary<NSValue *, UIImageView *> *)
                          attachmentViews {
  NSTextStorage *storage = textView.textStorage;
  NSMutableDictionary<NSValue *, UIImageView *> *activeAttachmentViews =
      [NSMutableDictionary dictionary];

  if (storage.length > 0) {
    // Iterate over the entire text to find ImageAttachments
    [storage
        enumerateAttribute:NSAttachmentAttributeName
                   inRange:NSMakeRange(0, storage.length)
                   options:0
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  if ([value isKindOfClass:[ImageAttachment class]]) {
                    ImageAttachment *attachment = (ImageAttachment *)value;

                    CGRect rect = [self frameForAttachment:attachment
                                                   atRange:range
                                                  textView:textView
                                                    config:config];

                    // `rect` (from frameForAttachment:, which sizes off
                    // attachment.bounds) is ALREADY the image-only frame —
                    // ImageAttachment.attachmentBoundsForTextContainer: only
                    // ever assigns `self.bounds` to the fitted IMAGE size; the
                    // larger image+caption rect it computes is returned to
                    // TextKit for line layout but never written back to
                    // `bounds`. So no further adjustment is needed here.
                    //
                    // BUG (fixed): this used to also subtract
                    // captionReservedHeight from rect.size.height, which
                    // double-counted the caption space — caption space was
                    // never part of `rect` to begin with, so this silently
                    // shrank the displayed image by ~the caption's height
                    // every time a caption was present (worse with longer
                    // captions), even though the underlying image/bounds were
                    // never actually corrupted (removing the caption — which
                    // makes captionReservedHeight return 0 — "fixed" it,
                    // which is what made this so easy to misdiagnose as a
                    // data-loss bug instead of a pure layout-math bug).
                    CGRect imageRect = rect;

                    // Get or Create the UIImageView for this specific
                    // attachment key
                    NSValue *key =
                        [NSValue valueWithNonretainedObject:attachment];
                    UIImageView *imgView = attachmentViews[key];

                    if (!imgView) {
                      // It doesn't exist yet, create it
                      imgView = [[UIImageView alloc] initWithFrame:imageRect];
                      imgView.contentMode = UIViewContentModeScaleAspectFit;
                      imgView.tintColor = [UIColor labelColor];
                      imgView.clipsToBounds = NO;

                      // Add it directly to the TextView
                      [textView addSubview:imgView];
                    }

                    // Update position (in case text moved/scrolled)
                    if (!CGRectEqualToRect(imgView.frame, imageRect)) {
                      imgView.frame = imageRect;
                    }

                    [self applyCaption:attachment.imageData.caption
                           toImageView:imgView
                             textColor:[config primaryColor]];
                    UIImage *targetImage =
                        attachment.storedAnimatedImage ?: attachment.image;

                    // Only set if different to avoid resetting the
                    // animation loop
                    if (imgView.image != targetImage) {
                      imgView.image = targetImage;
                    }

                    // Ensure it is visible on top
                    imgView.hidden = NO;
                    [textView bringSubviewToFront:imgView];

                    activeAttachmentViews[key] = imgView;
                    // Remove from the old map so we know it has been
                    // claimed
                    [attachmentViews removeObjectForKey:key];
                  }
                }];
  }

  // Everything remaining in attachmentViews is dead or off-screen
  for (UIImageView *danglingView in attachmentViews.allValues) {
    [danglingView removeFromSuperview];
  }

  return activeAttachmentViews;
}

+ (void)applyCaption:(NSString *)caption
         toImageView:(UIImageView *)imgView
           textColor:(UIColor *)textColor {
  static const NSInteger kCaptionLabelTag = 0x43415054; // 'CAPT'
  UILabel *label = (UILabel *)[imgView viewWithTag:kCaptionLabelTag];
  if (caption == nil || caption.length == 0) {
    [label removeFromSuperview];
    return;
  }
  if (label == nil) {
    label = [[UILabel alloc] init];
    label.tag = kCaptionLabelTag;
    label.font = [ImageAttachment captionFont];
    label.textAlignment = NSTextAlignmentCenter;
    // 0 = wrap across as many lines as the caption needs.
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    [imgView addSubview:label];
  }
  // Tint the caption from the editor's body text color (config primaryColor,
  // driven by the JS `color` style and therefore theme-aware), dimmed to read
  // as secondary. Set on EVERY layout pass — not just on first creation — so a
  // light/dark toggle (which re-applies styles and re-lays the attachments)
  // recolors an existing caption. Deliberately NOT secondaryLabelColor: that
  // dynamic color follows the iOS SYSTEM appearance, so when the in-app theme
  // differed from the system the caption was wrong — a caption added in the
  // app's dark mode stayed light/invisible after switching the app to light.
  label.textColor = textColor != nil ? [textColor colorWithAlphaComponent:0.6]
                                     : [UIColor secondaryLabelColor];
  label.text = caption;
  CGFloat width = imgView.bounds.size.width;
  CGFloat textH = [ImageAttachment captionHeightForCaption:caption width:width];
  if (textH <= 0) {
    textH = ceil([ImageAttachment captionFont].lineHeight);
  }
  // Sits just below the image (imgView covers only the image portion). Height
  // is the wrapped text height so long captions show every line (must match
  // ImageAttachment.captionReservedHeight so reserved space == drawn space).
  label.frame = CGRectMake(0, imgView.bounds.size.height + 4.0, width, textH);
}

+ (CGRect)frameForAttachment:(ImageAttachment *)attachment
                     atRange:(NSRange)range
                    textView:(UITextView *)textView
                      config:(EnrichedConfig *)config {
  NSLayoutManager *layoutManager = textView.layoutManager;
  NSTextContainer *textContainer = textView.textContainer;
  NSTextStorage *storage = textView.textStorage;

  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range
                                             actualCharacterRange:NULL];
  CGRect glyphRect = [layoutManager boundingRectForGlyphRange:glyphRange
                                              inTextContainer:textContainer];

  CGRect lineRect =
      [layoutManager lineFragmentRectForGlyphAtIndex:glyphRange.location
                                      effectiveRange:NULL];
  CGSize attachmentSize = attachment.bounds.size;

  UIFont *font = [storage attribute:NSFontAttributeName
                            atIndex:range.location
                     effectiveRange:NULL];
  if (!font) {
    font = [config primaryFont];
  }

  // Calculate (Baseline Alignment)
  // The attachment reserves the caption space BELOW the baseline (see
  // attachmentBoundsForTextContainer: origin.y = descender - caption), so the
  // line's true descent is |descender| + caption. font.descender alone locates
  // only the |descender| part, which would land the image `caption` px below
  // the true baseline and leave an empty band above it. Subtract the caption
  // reserved height so the image sits at the TOP of its glyph box; the caption
  // label is then drawn directly below the image inside the reserved descent.
  // caption == 0 (no caption) makes this identical to the prior behavior.
  CGFloat caption = [attachment captionReservedHeight];
  CGFloat targetY = CGRectGetMaxY(lineRect) + font.descender -
                    attachmentSize.height - caption;
  CGRect rect =
      CGRectMake(glyphRect.origin.x + textView.textContainerInset.left,
                 targetY + textView.textContainerInset.top,
                 attachmentSize.width, attachmentSize.height);

  return CGRectIntegral(rect);
}

@end
