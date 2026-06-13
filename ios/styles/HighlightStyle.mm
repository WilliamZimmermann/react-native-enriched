#import "EnrichedTextInputView.h"
#import "StyleHeaders.h"

// Highlight = NSBackgroundColorAttributeName carrying a UIColor over the
// range. Unlike Bold / Italic this style is value-bearing (5+ colors) but
// we don't need a sidecar attribute the way LinkStyle has LinkData — the
// system background-color attribute IS the payload, and a presence check
// is just a non-nil attribute lookup.

@implementation HighlightStyle

+ (StyleType)getType {
  return Highlight;
}

- (NSString *)getKey {
  return NSBackgroundColorAttributeName;
}

- (BOOL)isParagraph {
  return NO;
}

- (void)applyStyling:(NSRange)range {
  // No-op — the attribute IS the visual; no derived state to re-compute.
}

- (AttributeEntry *)getEntryIfPresent:(NSRange)range {
  return nullptr;
}

- (BOOL)styleCondition:(id _Nullable)value range:(NSRange)range {
  // detect:/any: compare each character's attribute value against this
  // predicate. The base impl expects an NSString sentinel; ours is a
  // UIColor, so define presence as "any opaque-ish color set" — that's
  // exactly what the serializer needs to know to wrap in <mark>.
  return [value isKindOfClass:[UIColor class]];
}

- (void)toggle:(NSRange)range {
  // No-op — highlight isn't a binary toggle; callers go through
  // addHighlightAtRange:color: / remove: explicitly.
}

- (void)addHighlightAtRange:(NSRange)range color:(UIColor *)color {
  if (color == nullptr || range.length == 0) {
    return;
  }
  [self.host.textView.textStorage addAttribute:NSBackgroundColorAttributeName
                                         value:color
                                         range:range];
  [self.host.attributesManager addDirtyRange:range];
}

- (void)removeHighlightInRange:(NSRange)range {
  if (range.length == 0) {
    return;
  }
  [self.host.textView.textStorage removeAttribute:NSBackgroundColorAttributeName
                                            range:range];
  [self.host.attributesManager addDirtyRange:range];
}

// CRITICAL: getKey is the *system* attribute NSBackgroundColorAttributeName,
// whose value MUST be a UIColor. The InputAttributesManager dirty-range cycle
// saves present styles (here: the UIColor, via OccurenceUtils.all), resets the
// range, then restores each via reapplyFromStylePair:. The base implementation
// re-adds getKey = getValue (@"AnyValue", an NSString) — fine for marker-keyed
// styles like Bold (@"EnrichedBold"), but for us it would stamp a *string* into
// the background-color attribute. NSLayoutManager then sends -set to that
// string while drawing the glyph background ("-[__NSCFConstantString set]:
// unrecognized selector"), crashing on the next draw after a highlight is
// applied. Restore the saved UIColor instead, mirroring
// Link/Mention/Image/Table. No addDirtyRange: here — reapply must not re-enter
// the cycle.
- (void)reapplyFromStylePair:(StylePair *)pair {
  NSRange range = [pair.rangeValue rangeValue];
  UIColor *color = (UIColor *)pair.styleValue;
  if (![color isKindOfClass:[UIColor class]] || range.length == 0) {
    return;
  }
  [self.host.textView.textStorage addAttribute:NSBackgroundColorAttributeName
                                         value:color
                                         range:range];
}

- (UIColor *)getHighlightColorAt:(NSUInteger)location {
  if (location >= self.host.textView.textStorage.length) {
    return nullptr;
  }
  return
      [self.host.textView.textStorage attribute:NSBackgroundColorAttributeName
                                        atIndex:location
                                 effectiveRange:nullptr];
}

@end
