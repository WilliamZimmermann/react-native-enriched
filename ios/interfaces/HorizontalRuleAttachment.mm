#import "HorizontalRuleAttachment.h"

// Visual constants for the divider. Tuned for the editor's default body font
// + 16pt container padding; the line sits centred within the vertical padding
// so the rule reads as an airy block separator rather than an underline.
static const CGFloat kRuleLineThickness = 1.0;
static const CGFloat kRuleVerticalPadding = 10.0;
// Used only when no text container is available yet (first measure pass).
static const CGFloat kRuleFallbackWidth = 320.0;

@implementation HorizontalRuleAttachment

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    // No static image — we draw on demand in imageForBounds: so the rule can
    // track the live container width and current appearance.
    self.image = nil;
  }
  return self;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFrag
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex {
  CGFloat width = kRuleFallbackWidth;
  if (textContainer != nil) {
    CGFloat available =
        textContainer.size.width - 2 * textContainer.lineFragmentPadding;
    if (available > 0) {
      width = available;
    }
  }
  CGFloat height = kRuleLineThickness + 2 * kRuleVerticalPadding;
  return CGRectMake(0, 0, width, height);
}

- (UIImage *)imageForBounds:(CGRect)imageBounds
              textContainer:(NSTextContainer *)textContainer
             characterIndex:(NSUInteger)charIndex {
  CGSize size = imageBounds.size;
  if (size.width <= 0 || size.height <= 0) {
    return nil;
  }

  // separatorColor is a dynamic color; resolving its CGColor at draw time
  // picks up the current light/dark appearance. TextKit re-requests the
  // attachment image on relayout (including appearance changes), so the rule
  // re-renders for the active theme.
  UIColor *lineColor = [UIColor separatorColor];

  UIGraphicsImageRendererFormat *fmt =
      [UIGraphicsImageRendererFormat preferredFormat];
  UIGraphicsImageRenderer *renderer =
      [[UIGraphicsImageRenderer alloc] initWithSize:size format:fmt];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    CGContextRef cg = ctx.CGContext;
    CGFloat y = (size.height - kRuleLineThickness) / 2.0;
    CGContextSetFillColorWithColor(cg, lineColor.CGColor);
    CGContextFillRect(cg, CGRectMake(0, y, size.width, kRuleLineThickness));
  }];
}

@end
