#import "StyleBase.h"
#import "AttributeEntry.h"
#import "OccurenceUtils.h"
#import "RangeUtils.h"
#import "TextListsUtils.h"
#import "ZeroWidthSpaceUtils.h"

@implementation StyleBase

// This method gets overridden
+ (StyleType)getType {
  return None;
}

// This method gets overridden for inline styles
- (NSString *)getKey {
  if ([self isParagraph]) {
    return NSParagraphStyleAttributeName;
  }
  return @"NoneAttribute";
}

// Basic inline styles will use this default value, paragraph styles will
// override it and parametrised ones completely don't use it
- (NSString *)getValue {
  return @"AnyValue";
}

// Paragraph styles that store a family of mutually exclusive markers (e.g.
// alignment variants) should override this to return the shared prefix.
- (NSString *)getMarkerPrefix {
  return nil;
}

// This method gets overridden
- (BOOL)isParagraph {
  return false;
}

- (BOOL)needsZWS {
  return NO;
}

- (BOOL)appliesStylingToTyping {
  return NO;
}

- (instancetype)initWithHost:(id<EnrichedViewHost>)host {
  self = [super init];
  _host = host;
  return self;
}

// aligns range to whole paragraph for the paragraph stlyes
- (NSRange)actualUsedRange:(NSRange)range {
  if (![self isParagraph])
    return range;
  return [self.host.textView.textStorage.string paragraphRangeForRange:range];
}

- (void)toggle:(NSRange)range {
  NSRange actualRange = [self actualUsedRange:range];

  BOOL isPresent = [self detect:actualRange];
  if (actualRange.length >= 1) {
    isPresent ? [self remove:actualRange withDirtyRange:YES]
              : [self add:actualRange withTyping:YES withDirtyRange:YES];
  } else {
    isPresent ? [self removeTyping] : [self addTypingWithValue:[self getValue]];
  }
}

- (void)add:(NSRange)range
        withTyping:(BOOL)withTyping
    withDirtyRange:(BOOL)withDirtyRange {
  [self add:range
           withValue:[self getValue]
          withTyping:withTyping
      withDirtyRange:withDirtyRange];
}

- (void)add:(NSRange)range
         withValue:(NSString *)value
        withTyping:(BOOL)withTyping
    withDirtyRange:(BOOL)withDirtyRange {
  NSRange actualRange = [self actualUsedRange:range];

  if (![self isParagraph]) {
    [self.host.textView.textStorage addAttribute:[self getKey]
                                           value:value
                                           range:actualRange];
  } else {
    [self.host.textView.textStorage
        enumerateAttribute:NSParagraphStyleAttributeName
                   inRange:actualRange
                   options:0
                usingBlock:^(id _Nullable existingValue, NSRange subRange,
                             BOOL *_Nonnull stop) {
                  NSMutableParagraphStyle *pStyle =
                      [(NSParagraphStyle *)existingValue mutableCopy];
                  if (pStyle == nullptr)
                    return;
                  pStyle.textLists =
                      [TextListsUtils textListsByAdding:value
                                    withExclusivePrefix:[self getMarkerPrefix]
                                                toArray:pStyle.textLists];
                  [self.host.textView.textStorage
                      addAttribute:NSParagraphStyleAttributeName
                             value:pStyle
                             range:subRange];
                }];
  }

  if (withTyping) {
    [self addTypingWithValue:value];
  }

  // Notify attributes manager of styling to be re-done if needed.
  if (withDirtyRange) {
    [self.host.attributesManager addDirtyRange:actualRange];
  }
}

- (void)remove:(NSRange)range withDirtyRange:(BOOL)withDirtyRange {
  NSRange actualRange = [self actualUsedRange:range];

  if (![self isParagraph]) {
    [self.host.textView.textStorage removeAttribute:[self getKey]
                                              range:actualRange];
  } else {
    [self.host.textView.textStorage
        enumerateAttribute:NSParagraphStyleAttributeName
                   inRange:actualRange
                   options:0
                usingBlock:^(id _Nullable existingValue, NSRange subRange,
                             BOOL *_Nonnull stop) {
                  NSMutableParagraphStyle *pStyle =
                      [(NSParagraphStyle *)existingValue mutableCopy];
                  if (pStyle == nullptr)
                    return;
                  pStyle.textLists =
                      [TextListsUtils textListsByRemoving:[self getValue]
                                               withPrefix:[self getMarkerPrefix]
                                                fromArray:pStyle.textLists];
                  [self.host.textView.textStorage
                      addAttribute:NSParagraphStyleAttributeName
                             value:pStyle
                             range:subRange];
                }];
  }
  [self removeTyping];

  // Notify attributes manager of styling to be re-done if needed.
  if (withDirtyRange) {
    [self.host.attributesManager addDirtyRange:actualRange];
  }
}

- (void)addTypingWithValue:(NSString *)value {
  NSMutableDictionary *newTypingAttrs =
      [self.host.textView.typingAttributes mutableCopy];

  if (![self isParagraph]) {
    newTypingAttrs[[self getKey]] = value;
  } else {
    NSMutableParagraphStyle *pStyle =
        [newTypingAttrs[NSParagraphStyleAttributeName] mutableCopy];
    pStyle.textLists = [TextListsUtils textListsByAdding:value
                                     withExclusivePrefix:[self getMarkerPrefix]
                                                 toArray:pStyle.textLists];
    newTypingAttrs[NSParagraphStyleAttributeName] = pStyle;
  }

  self.host.textView.typingAttributes = newTypingAttrs;
}

- (void)removeTyping {
  NSMutableDictionary *newTypingAttrs =
      [self.host.textView.typingAttributes mutableCopy];

  if (![self isParagraph]) {
    [newTypingAttrs removeObjectForKey:[self getKey]];
    // attributes manager also needs to be notified of custom attributes that
    // shouldn't be extended
    [self.host.attributesManager didRemoveTypingAttribute:[self getKey]];
  } else {
    NSMutableParagraphStyle *pStyle =
        [newTypingAttrs[NSParagraphStyleAttributeName] mutableCopy];
    pStyle.textLists = pStyle.textLists =
        [TextListsUtils textListsByRemoving:[self getValue]
                                 withPrefix:[self getMarkerPrefix]
                                  fromArray:pStyle.textLists];
    newTypingAttrs[NSParagraphStyleAttributeName] = pStyle;
  }

  self.host.textView.typingAttributes = newTypingAttrs;
}

// custom styles (e.g. ImageStyle, MentionStyle) will likely need to override
// this method
- (BOOL)styleCondition:(id)value range:(NSRange)range {
  if (![self isParagraph]) {
    NSString *valueString = (NSString *)value;
    return valueString != nullptr &&
           [valueString isEqualToString:[self getValue]];
  } else {
    NSParagraphStyle *pStyle = (NSParagraphStyle *)value;
    return pStyle != nullptr && [TextListsUtils textLists:pStyle.textLists
                                            containsValue:[self getValue]];
  }
}

- (BOOL)detect:(NSRange)range {
  if (range.length >= 1) {
    return [OccurenceUtils detect:[self getKey]
                         withHost:self.host
                          inRange:range
                    withCondition:^BOOL(id _Nullable value, NSRange range) {
                      return [self styleCondition:value range:range];
                    }];
  } else {
    return [OccurenceUtils detect:[self getKey]
                         withHost:self.host
                          atIndex:range.location
                    checkPrevious:[self isParagraph]
                    withCondition:^BOOL(id _Nullable value, NSRange range) {
                      return [self styleCondition:value range:range];
                    }];
  }
}

- (BOOL)any:(NSRange)range {
  return [OccurenceUtils any:[self getKey]
                    withHost:self.host
                     inRange:range
               withCondition:^BOOL(id _Nullable value, NSRange range) {
                 return [self styleCondition:value range:range];
               }];
}

- (NSArray<StylePair *> *)all:(NSRange)range {
  return [OccurenceUtils all:[self getKey]
                    withHost:self.host
                     inRange:range
               withCondition:^BOOL(id _Nullable value, NSRange range) {
                 return [self styleCondition:value range:range];
               }];
}

// This method gets overridden
- (void)applyStyling:(NSRange)range {
}

// This method gets overridden when the style needs to apply certain typing
// attributes
- (void)applyStylingToTypingAttrs:(NSMutableDictionary *)attributes {
}

// Called during dirty range re-application to restore a style from a saved
// StylePair
- (void)reapplyFromStylePair:(StylePair *)pair {
  NSRange range = [pair.rangeValue rangeValue];
  [self add:range withTyping:NO withDirtyRange:NO];
}

// Gets a custom attribtue entry for the typingAttributes.
// Only used with inline styles.
- (AttributeEntry *)getEntryIfPresent:(NSRange)range {
  if (![self detect:range]) {
    return nullptr;
  }

  AttributeEntry *entry = [[AttributeEntry alloc] init];
  entry.key = [self getKey];
  entry.value = [self getValue];
  return entry;
}

// List-nesting hooks — default no-ops. UL / OL / Checkbox override these.
- (void)indent:(NSRange)range {
}

- (void)outdent:(NSRange)range {
}

- (NSInteger)depthAtLocation:(NSUInteger)location {
  return -1;
}

// Shared list-nesting implementation. List style subclasses override
// indent:/outdent:/depthAtLocation: with one-liners that forward to these
// helpers. The work is identical across UL/OL/Checkbox apart from the
// (value, prefix) pair that identifies the family — already exposed via
// getValue/getMarkerPrefix — so this lives here to keep the subclasses thin.

// Mutate every paragraph intersecting `range`: applies `transform` to its
// `pStyle.textLists` and writes it back. Marks the range dirty so applyStyling
// runs again (so headIndent picks up the new depth).
//
// IMPORTANT: collect all (subRange, newPStyle) tuples inside the enumerate
// block and only write attributes after the enumeration completes. Calling
// `addAttribute:` from inside `enumerateAttribute:usingBlock:` is "may
// invalidate the enumeration" per Apple's docs — and in practice the second
// observed pass starts from the already-mutated pStyle, so a non-idempotent
// transform like `textListsByIncreasingDepth` pushes an extra entry. The
// symptom is depth advancing by 2 (or more) per Tab. Collect-then-apply
// keeps the enumeration's view of the storage stable.
- (void)mutateListsInRange:(NSRange)range
           withFamilyValue:(NSString *)value
                    prefix:(NSString *)prefix
                 transform:(NSArray<NSTextList *> * (^)(
                               NSArray<NSTextList *> *existing))transform {
  NSRange paragraphRange = [self actualUsedRange:range];

  NSMutableArray<NSValue *> *subRanges = [NSMutableArray array];
  NSMutableArray<NSMutableParagraphStyle *> *newStyles = [NSMutableArray array];

  [self.host.textView.textStorage
      enumerateAttribute:NSParagraphStyleAttributeName
                 inRange:paragraphRange
                 options:0
              usingBlock:^(id _Nullable existingValue, NSRange subRange,
                           BOOL *_Nonnull stop) {
                NSMutableParagraphStyle *pStyle =
                    [(NSParagraphStyle *)existingValue mutableCopy];
                if (pStyle == nullptr)
                  return;
                pStyle.textLists = transform(pStyle.textLists);
                [subRanges addObject:[NSValue valueWithRange:subRange]];
                [newStyles addObject:pStyle];
              }];

  for (NSUInteger i = 0; i < subRanges.count; i++) {
    [self.host.textView.textStorage addAttribute:NSParagraphStyleAttributeName
                                           value:newStyles[i]
                                           range:[subRanges[i] rangeValue]];
  }

  [self.host.attributesManager addDirtyRange:paragraphRange];
}

- (void)indentList:(NSRange)range {
  NSString *value = [self getValue];
  NSString *prefix = [self getMarkerPrefix];
  [self mutateListsInRange:range
           withFamilyValue:value
                    prefix:prefix
                 transform:^NSArray<NSTextList *> *(
                     NSArray<NSTextList *> *existing) {
                   return [TextListsUtils
                       textListsByIncreasingDepthForValue:value
                                                   prefix:prefix
                                                  inArray:existing];
                 }];
}

- (void)outdentList:(NSRange)range {
  NSString *value = [self getValue];
  NSString *prefix = [self getMarkerPrefix];
  [self mutateListsInRange:range
           withFamilyValue:value
                    prefix:prefix
                 transform:^NSArray<NSTextList *> *(
                     NSArray<NSTextList *> *existing) {
                   return [TextListsUtils
                       textListsByDecreasingDepthForValue:value
                                                   prefix:prefix
                                                  inArray:existing];
                 }];
}

- (NSInteger)depthForLocation:(NSUInteger)location {
  if (location >= self.host.textView.textStorage.length)
    return -1;

  NSParagraphStyle *pStyle =
      [self.host.textView.textStorage attribute:NSParagraphStyleAttributeName
                                        atIndex:location
                                 effectiveRange:NULL];
  if (pStyle == nullptr)
    return -1;

  NSInteger family = [TextListsUtils familyCountForValue:[self getValue]
                                                  prefix:[self getMarkerPrefix]
                                                 inArray:pStyle.textLists];
  return family == 0 ? -1 : family - 1;
}

// Restore nesting depth lost by InputAttributesManager's dirty-range cycle.
// The cycle saves the paragraph style (with its full textLists array) to a
// StylePair, then resets all attributes in the dirty range, then re-applies
// styles via `reapplyFromStylePair:`. The default `reapplyFromStylePair:`
// calls `add:` once, which only inserts one NSTextList because
// `textListsByAdding` dedups. With nested lists the second-and-deeper
// entries get dropped and depth visually snaps back to 0 on the first edit.
// This helper restores by pushing additional family entries (via
// textListsByIncreasingDepth) until the count matches the saved pStyle.
- (void)padListDepthInRange:(NSRange)range
              fromStylePair:(StylePair *)pair
                      value:(NSString *)value
                     prefix:(NSString *)prefix {
  NSParagraphStyle *savedPStyle = (NSParagraphStyle *)pair.styleValue;
  NSInteger savedFamily =
      [TextListsUtils familyCountForValue:value
                                   prefix:prefix
                                  inArray:savedPStyle.textLists];
  if (savedFamily <= 1)
    return;

  // Idempotent set-to-target. Earlier implementation pushed `savedFamily-1`
  // additional entries which broke when the pad ran more than once for the
  // same range, or when other paragraph-style reapplies ran before it. The
  // overall family count would drift up by extra entries each call.
  //
  // Instead, normalize: filter out all current family entries, then re-add
  // exactly `savedFamily` copies. Calling this once or N times produces the
  // same final family count (= savedFamily).
  //
  // Preserve the saved markerFormat for prefix-style families (e.g. checkbox
  // checked/unchecked state) so depth restore doesn't flip the checked bit.
  NSString *familyMarker = value;
  if (prefix != nil) {
    NSTextList *savedFirst =
        [TextListsUtils firstTextListWithPrefix:prefix
                                        inArray:savedPStyle.textLists];
    if (savedFirst != nil)
      familyMarker = savedFirst.markerFormat;
  }

  NSMutableArray<NSValue *> *subRanges = [NSMutableArray array];
  NSMutableArray<NSMutableParagraphStyle *> *newStyles = [NSMutableArray array];

  [self.host.textView.textStorage
      enumerateAttribute:NSParagraphStyleAttributeName
                 inRange:range
                 options:0
              usingBlock:^(id _Nullable existing, NSRange subRange,
                           BOOL *_Nonnull stop) {
                NSMutableParagraphStyle *pStyle =
                    [(NSParagraphStyle *)existing mutableCopy];
                if (pStyle == nullptr)
                  return;

                NSMutableArray<NSTextList *> *normalized =
                    [NSMutableArray array];
                for (NSTextList *l in pStyle.textLists) {
                  NSString *fmt = l.markerFormat;
                  BOOL inFamily = (prefix != nil) ? [fmt hasPrefix:prefix]
                                                  : [fmt isEqualToString:value];
                  if (!inFamily)
                    [normalized addObject:l];
                }
                for (NSInteger i = 0; i < savedFamily; i++) {
                  [normalized addObject:[[NSTextList alloc]
                                            initWithMarkerFormat:familyMarker
                                                         options:0]];
                }
                pStyle.textLists = normalized;
                [subRanges addObject:[NSValue valueWithRange:subRange]];
                [newStyles addObject:pStyle];
              }];

  for (NSUInteger i = 0; i < subRanges.count; i++) {
    [self.host.textView.textStorage addAttribute:NSParagraphStyleAttributeName
                                           value:newStyles[i]
                                           range:[subRanges[i] rangeValue]];
  }
}

@end
