#import "AttributeEntry.h"
#import "EnrichedTextInputView.h"
#import "StyleHeaders.h"
#import "TextInsertionUtils.h"

// AI track-changes marks (gap-fill suggestions + correction flags).
// Structurally these are parametrized inline attributes exactly like Mention: a
// custom NSAttributedStringKey carries an AiMarkParams payload over the marked
// range, and the visual is (re)derived from that payload in the
// InputAttributesManager dirty-range cycle. Both kinds share this base; the two
// concrete subclasses below differ only in their attribute key and their
// pending/accepted visual.
//
// The wavy flag underline is custom-drawn by LayoutManagerExtension (which
// reads the EnrichedAiFlag attribute directly); the system underline set here
// is a visible fallback and reserves the underline colour.

static UIColor *AiDynamicColor(UIColor *light, UIColor *dark) {
  return
      [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? dark
                                                                     : light;
      }];
}

// Suggestion = green (matches the web editor's gap-fill styling).
static UIColor *AiSuggestionColor(void) {
  return AiDynamicColor([UIColor colorWithRed:0.118
                                        green:0.604
                                         blue:0.333
                                        alpha:1.0],
                        [UIColor colorWithRed:0.247
                                        green:0.816
                                         blue:0.541
                                        alpha:1.0]);
}
static UIColor *AiSuggestionTint(void) {
  return AiDynamicColor([UIColor colorWithRed:0.118
                                        green:0.604
                                         blue:0.333
                                        alpha:0.12],
                        [UIColor colorWithRed:0.247
                                        green:0.816
                                         blue:0.541
                                        alpha:0.16]);
}
// Flag = amber/red (matches the web editor's correction styling).
static UIColor *AiFlagColor(void) {
  return AiDynamicColor([UIColor colorWithRed:0.882
                                        green:0.114
                                         blue:0.282
                                        alpha:1.0],
                        [UIColor colorWithRed:0.984
                                        green:0.443
                                         blue:0.522
                                        alpha:1.0]);
}

@implementation AiMarkStyle

// Overridden by the concrete subclasses.
- (NSString *)getKey {
  return @"EnrichedAiMark";
}
- (NSString *)aiKind {
  return @"suggestion";
}

- (BOOL)isParagraph {
  return NO;
}

// Don't auto-extend the mark onto adjacent typed text (mirrors Mention).
- (AttributeEntry *)getEntryIfPresent:(NSRange)range {
  return nullptr;
}

- (void)toggle:(NSRange)range {
  // no-op — AI marks are applied/removed explicitly, never toggled
}

- (BOOL)styleCondition:(id _Nullable)value range:(NSRange)range {
  return [value isKindOfClass:[AiMarkParams class]];
}

- (BOOL)detect:(NSRange)range {
  if (range.length >= 1) {
    return [super detect:range];
  }
  return [self paramsAt:range.location] != nullptr;
}

- (void)applyStyling:(NSRange)range {
  if (range.length == 0) {
    return;
  }
  AiMarkParams *params = [self paramsAt:range.location];
  if (params == nullptr) {
    return;
  }
  [self applyVisualForParams:params range:range];
}

// Restore the payload attribute after the dirty-range reset (the visual is then
// re-derived by applyStyling:). No addDirtyRange: — reapply must not re-enter
// the cycle (mirrors HighlightStyle/MentionStyle).
- (void)reapplyFromStylePair:(StylePair *)pair {
  NSRange range = [pair.rangeValue rangeValue];
  AiMarkParams *params = (AiMarkParams *)pair.styleValue;
  if (![params isKindOfClass:[AiMarkParams class]] || range.length == 0) {
    return;
  }
  [self.host.textView.textStorage addAttribute:[self getKey]
                                         value:params
                                         range:range];
}

// Subclass hook: paint the pending/accepted visual for the payload.
- (void)applyVisualForParams:(AiMarkParams *)params range:(NSRange)range {
  // overridden
}

// MARK: - attribute helpers

- (void)applyMeta:(AiMarkParams *)params range:(NSRange)range {
  [self.host.textView.textStorage addAttribute:[self getKey]
                                         value:params
                                         range:range];
}

- (AiMarkParams *)paramsAt:(NSUInteger)location {
  if (location >= self.host.textView.textStorage.length) {
    return nullptr;
  }
  return [self.host.textView.textStorage attribute:[self getKey]
                                           atIndex:location
                                    effectiveRange:nullptr];
}

- (NSArray<StylePair *> *)allPairs {
  NSRange whole = NSMakeRange(0, self.host.textView.textStorage.length);
  if (whole.length == 0) {
    return @[];
  }
  return [self all:whole];
}

// Ranges carrying `aiId`, sorted descending by location so text deletions don't
// shift the ranges that follow.
- (NSArray<NSValue *> *)rangesForId:(NSString *)aiId {
  NSMutableArray<NSValue *> *out = [NSMutableArray new];
  for (StylePair *pair in [self allPairs]) {
    AiMarkParams *p = (AiMarkParams *)pair.styleValue;
    if ([p isKindOfClass:[AiMarkParams class]] &&
        [p.aiId isEqualToString:aiId]) {
      [out addObject:pair.rangeValue];
    }
  }
  [out sortUsingComparator:^NSComparisonResult(NSValue *a, NSValue *b) {
    NSUInteger la = [a rangeValue].location, lb = [b rangeValue].location;
    if (la > lb) {
      return NSOrderedAscending;
    }
    if (la < lb) {
      return NSOrderedDescending;
    }
    return NSOrderedSame;
  }];
  return out;
}

// MARK: - public mutations (invoked from the view command handlers)

- (void)applyAiMarkAtRange:(NSRange)range params:(AiMarkParams *)params {
  if (range.length == 0) {
    return;
  }
  [self applyMeta:params range:range];
  [self.host.attributesManager addDirtyRange:range];
}

- (void)acceptId:(NSString *)aiId {
  for (NSValue *rv in [self rangesForId:aiId]) {
    NSRange range = [rv rangeValue];
    AiMarkParams *p = [self paramsAt:range.location];
    if (p == nullptr) {
      continue;
    }
    p.status = @"accepted";
    [self.host.textView.textStorage addAttribute:[self getKey]
                                           value:p
                                           range:range];
    [self.host.attributesManager addDirtyRange:range];
  }
}

- (void)stripId:(NSString *)aiId {
  for (NSValue *rv in [self rangesForId:aiId]) {
    NSRange range = [rv rangeValue];
    [self.host.textView.textStorage removeAttribute:[self getKey] range:range];
    [self.host.attributesManager addDirtyRange:range];
  }
}

- (void)deleteId:(NSString *)aiId {
  for (NSValue *rv in [self rangesForId:aiId]) {
    [TextInsertionUtils replaceText:@""
                                 at:[rv rangeValue]
               additionalAttributes:nullptr
                               host:self.host
                      withSelection:NO];
  }
}

- (void)acceptAllPending {
  for (StylePair *pair in [self allPairs]) {
    AiMarkParams *p = (AiMarkParams *)pair.styleValue;
    if (![p isKindOfClass:[AiMarkParams class]] ||
        [p.status isEqualToString:@"accepted"]) {
      continue;
    }
    NSRange range = [pair.rangeValue rangeValue];
    p.status = @"accepted";
    [self.host.textView.textStorage addAttribute:[self getKey]
                                           value:p
                                           range:range];
    [self.host.attributesManager addDirtyRange:range];
  }
}

- (void)deleteAllPending {
  NSMutableArray<NSValue *> *ranges = [NSMutableArray new];
  for (StylePair *pair in [self allPairs]) {
    AiMarkParams *p = (AiMarkParams *)pair.styleValue;
    if ([p isKindOfClass:[AiMarkParams class]] &&
        ![p.status isEqualToString:@"accepted"]) {
      [ranges addObject:pair.rangeValue];
    }
  }
  [ranges sortUsingComparator:^NSComparisonResult(NSValue *a, NSValue *b) {
    NSUInteger la = [a rangeValue].location, lb = [b rangeValue].location;
    if (la > lb) {
      return NSOrderedAscending;
    }
    if (la < lb) {
      return NSOrderedDescending;
    }
    return NSOrderedSame;
  }];
  for (NSValue *rv in ranges) {
    [TextInsertionUtils replaceText:@""
                                 at:[rv rangeValue]
               additionalAttributes:nullptr
                               host:self.host
                      withSelection:NO];
  }
}

- (void)stripAllPending {
  for (StylePair *pair in [self allPairs]) {
    AiMarkParams *p = (AiMarkParams *)pair.styleValue;
    if ([p isKindOfClass:[AiMarkParams class]] &&
        ![p.status isEqualToString:@"accepted"]) {
      NSRange range = [pair.rangeValue rangeValue];
      [self.host.textView.textStorage removeAttribute:[self getKey]
                                                range:range];
      [self.host.attributesManager addDirtyRange:range];
    }
  }
}

@end

@implementation AiSuggestionStyle

+ (StyleType)getType {
  return AiSuggestion;
}

- (NSString *)getKey {
  return @"EnrichedAiSuggestion";
}

- (NSString *)aiKind {
  return @"suggestion";
}

- (void)applyVisualForParams:(AiMarkParams *)params range:(NSRange)range {
  BOOL accepted = [params.status isEqualToString:@"accepted"];
  UIColor *color = AiSuggestionColor();
  NSMutableDictionary *attrs = [@{
    NSUnderlineColorAttributeName : color,
    NSUnderlineStyleAttributeName :
        @(accepted ? NSUnderlineStyleSingle
                   : (NSUnderlineStyleSingle | NSUnderlinePatternDash)),
  } mutableCopy];
  if (!accepted) {
    attrs[NSBackgroundColorAttributeName] = AiSuggestionTint();
  }
  [self.host.textView.textStorage addAttributes:attrs range:range];
}

@end

@implementation AiFlagStyle

+ (StyleType)getType {
  return AiFlag;
}

- (NSString *)getKey {
  return @"EnrichedAiFlag";
}

- (NSString *)aiKind {
  return @"flag";
}

- (void)applyVisualForParams:(AiMarkParams *)params range:(NSRange)range {
  // The faithful wavy stroke is custom-drawn by LayoutManagerExtension (Task
  // 11) reading the EnrichedAiFlag attribute; this dotted system underline is a
  // visible fallback that also reserves the underline colour.
  UIColor *color = AiFlagColor();
  NSDictionary *attrs = @{
    NSUnderlineColorAttributeName : color,
    NSUnderlineStyleAttributeName :
        @(NSUnderlineStyleSingle | NSUnderlinePatternDot),
  };
  [self.host.textView.textStorage addAttributes:attrs range:range];
}

@end
