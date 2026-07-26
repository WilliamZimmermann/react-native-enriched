#import "EnrichedTextInputView.h"
#import "FontExtension.h"
#import "StyleHeaders.h"

// Per-selection font size.
//
// The size is NOT written into NSFontAttributeName directly: that attribute is
// *derived*. The dirty-range cycle resets a range and rebuilds its font from
// the styles present (bold/italic traits, heading sizes), so a size written
// straight into it is discarded on the next edit that touches the range.
//
// Instead we keep a marker attribute holding the size, and rebuild the font in
// applyStyling: — the same shape HeadingStyleBase uses. That makes the size
// survive the cycle and compose with bold/italic rather than fight them.
static NSString *const kFontSizeAttribute = @"EnrichedFontSize";

@implementation FontSizeStyle

+ (StyleType)getType {
  return FontSize;
}

- (NSString *)getKey {
  return kFontSizeAttribute;
}

- (BOOL)isParagraph {
  return NO;
}

// Runs on every dirty-range pass: re-derive the font from the stored size.
// Headings apply their own size in their applyStyling:; an explicit size is
// meant to win, which it does as long as FontSize sorts after the headings in
// StyleType (it does — it sits just before None).
- (void)applyStyling:(NSRange)range {
  // Collect first, mutate after. Writing NSFontAttributeName from inside an
  // enumeration of the same text storage can invalidate the walk mid-flight,
  // which drops runs silently — collecting the (range, size) pairs up front
  // keeps the enumeration read-only.
  NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
  NSMutableArray<NSNumber *> *sizes = [NSMutableArray array];

  [self.host.textView.textStorage
      enumerateAttribute:kFontSizeAttribute
                 inRange:range
                 options:0
              usingBlock:^(id _Nullable value, NSRange subRange,
                           BOOL *_Nonnull stop) {
                NSNumber *size = (NSNumber *)value;
                if (![size isKindOfClass:[NSNumber class]] ||
                    size.doubleValue <= 0) {
                  return;
                }
                [self.host.textView.textStorage
                    enumerateAttribute:NSFontAttributeName
                               inRange:subRange
                               options:0
                            usingBlock:^(id _Nullable fontValue,
                                         NSRange fontRange,
                                         BOOL *_Nonnull fontStop) {
                              if (fontValue == nullptr)
                                return;
                              [ranges
                                  addObject:[NSValue valueWithRange:fontRange]];
                              [sizes addObject:size];
                            }];
              }];

  for (NSUInteger i = 0; i < ranges.count; i++) {
    NSRange fontRange = [ranges[i] rangeValue];
    UIFont *font = [self.host.textView.textStorage
             attribute:NSFontAttributeName
               atIndex:fontRange.location
        effectiveRange:nullptr];
    if (font == nullptr) {
      continue;
    }
    [self.host.textView.textStorage
        addAttribute:NSFontAttributeName
               value:[font setSize:sizes[i].doubleValue]
               range:fontRange];
  }
}

- (AttributeEntry *)getEntryIfPresent:(NSRange)range {
  return nullptr;
}

// detect:/any: compare each character's attribute against this predicate. Ours
// is an NSNumber rather than the base's NSString sentinel, so presence is
// "a positive number is set" — which is what the serializer needs to know to
// wrap the run in a styled span.
- (BOOL)styleCondition:(id _Nullable)value range:(NSRange)range {
  return [value isKindOfClass:[NSNumber class]] &&
         ((NSNumber *)value).doubleValue > 0;
}

- (void)toggle:(NSRange)range {
  // Not a binary toggle — callers go through add/remove explicitly.
}

- (void)addFontSizeAtRange:(NSRange)range size:(CGFloat)size {
  if (size <= 0 || range.length == 0) {
    return;
  }
  [self.host.textView.textStorage addAttribute:kFontSizeAttribute
                                         value:@(size)
                                         range:range];
  [self.host.attributesManager addDirtyRange:range];
}

- (void)removeFontSizeInRange:(NSRange)range {
  if (range.length == 0) {
    return;
  }
  [self.host.textView.textStorage removeAttribute:kFontSizeAttribute
                                            range:range];
  [self.host.attributesManager addDirtyRange:range];
}

// Value-bearing style: the base implementation restores getKey = getValue (an
// NSString sentinel), which would put a string where applyStyling: expects an
// NSNumber and silently drop the size. Restore the saved number instead —
// same reason HighlightStyle overrides this. No addDirtyRange: here; reapply
// must not re-enter the cycle.
- (void)reapplyFromStylePair:(StylePair *)pair {
  NSRange range = [pair.rangeValue rangeValue];
  NSNumber *size = (NSNumber *)pair.styleValue;
  if (![size isKindOfClass:[NSNumber class]] || range.length == 0) {
    return;
  }
  [self.host.textView.textStorage addAttribute:kFontSizeAttribute
                                         value:size
                                         range:range];
}

- (CGFloat)getFontSizeAt:(NSUInteger)location {
  if (location >= self.host.textView.textStorage.length) {
    return 0;
  }
  NSNumber *size = [self.host.textView.textStorage attribute:kFontSizeAttribute
                                                     atIndex:location
                                              effectiveRange:nullptr];
  return [size isKindOfClass:[NSNumber class]] ? size.doubleValue : 0;
}

@end
