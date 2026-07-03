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
// Accepted suggestion = blue highlight (matches the web editor) until claimed.
static UIColor *AiAcceptedTint(void) {
  return AiDynamicColor([UIColor colorWithRed:0.231
                                        green:0.510
                                         blue:0.965
                                        alpha:0.18],
                        [UIColor colorWithRed:0.376
                                        green:0.596
                                         blue:1.000
                                        alpha:0.24]);
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

// Subclass hook: paint the pending/accepted visual for the payload. Each
// override MUST first call clearVisualInRange: so a status change (pending →
// accepted) never leaves the previous state's underline/tint behind.
- (void)applyVisualForParams:(AiMarkParams *)params range:(NSRange)range {
  // overridden
}

// Strip every visual attribute this mark paints (underline + background). The
// dirty-range cycle does NOT clear these raw attributes on its own, so accept /
// claim / reject must clear them explicitly, otherwise the green (pending) or
// blue (accepted) highlight lingers after the state changes.
- (void)clearVisualInRange:(NSRange)range {
  if (range.length == 0) {
    return;
  }
  NSTextStorage *ts = self.host.textView.textStorage;
  [ts removeAttribute:NSUnderlineStyleAttributeName range:range];
  [ts removeAttribute:NSUnderlineColorAttributeName range:range];
  [ts removeAttribute:NSBackgroundColorAttributeName range:range];
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
  [self applyVisualForParams:params range:range];
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
    // Re-derive the visual immediately (blue) — the dirty cycle alone leaves
    // the previous pending green behind.
    [self applyVisualForParams:p range:range];
    [self.host.attributesManager addDirtyRange:range];
  }
}

- (void)stripId:(NSString *)aiId {
  for (NSValue *rv in [self rangesForId:aiId]) {
    NSRange range = [rv rangeValue];
    [self.host.textView.textStorage removeAttribute:[self getKey] range:range];
    // Claimed / removed: no mark → no highlight at all.
    [self clearVisualInRange:range];
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
    [self applyVisualForParams:p range:range];
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
      [self clearVisualInRange:range];
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
  // Always start from a clean slate so pending↔accepted transitions don't
  // stack (e.g. the pending green dashed underline surviving under the blue).
  [self clearVisualInRange:range];
  if ([params.status isEqualToString:@"accepted"]) {
    // Accepted but not yet claimed: a BLUE highlight (matches the web editor),
    // no underline. Claiming strips the mark → clearVisualInRange leaves plain
    // user text with no highlight.
    [self.host.textView.textStorage
        addAttributes:@{NSBackgroundColorAttributeName : AiAcceptedTint()}
                range:range];
    return;
  }
  // Pending: green dashed underline + green tint.
  [self.host.textView.textStorage addAttributes:@{
    NSUnderlineColorAttributeName : AiSuggestionColor(),
    NSUnderlineStyleAttributeName :
        @(NSUnderlineStyleSingle | NSUnderlinePatternDash),
    NSBackgroundColorAttributeName : AiSuggestionTint(),
  }
                                          range:range];
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
  [self clearVisualInRange:range];
  // Accepted ("Keep") flag: the user reviewed and kept their text — no visual.
  if ([params.status isEqualToString:@"accepted"]) {
    return;
  }
  // Pending: dotted red underline. (The faithful wavy stroke is a later
  // LayoutManagerExtension task; this system underline is the fallback.)
  [self.host.textView.textStorage addAttributes:@{
    NSUnderlineColorAttributeName : AiFlagColor(),
    NSUnderlineStyleAttributeName :
        @(NSUnderlineStyleSingle | NSUnderlinePatternDot),
  }
                                          range:range];
}

@end
