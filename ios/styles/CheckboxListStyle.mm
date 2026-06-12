#import "EnrichedTextInputView.h"
#import "RangeUtils.h"
#import "StyleHeaders.h"
#import "TextInsertionUtils.h"
#import "TextListsUtils.h"

@implementation CheckboxListStyle

+ (StyleType)getType {
  return CheckboxList;
}

- (NSString *)getValue {
  return @"EnrichedCheckbox0";
}

- (NSString *)getMarkerPrefix {
  return @"EnrichedCheckbox";
}

- (BOOL)isParagraph {
  return YES;
}

- (BOOL)needsZWS {
  return YES;
}

- (void)applyStyling:(NSRange)range {
  CGFloat unit = [self.host.config checkboxListMarginLeft] +
                 [self.host.config checkboxListGapWidth] +
                 [self.host.config checkboxListBoxSize];

  NSString *value = [self getValue];
  NSString *prefix = [self getMarkerPrefix];

  [self.host.textView.textStorage
      enumerateAttribute:NSParagraphStyleAttributeName
                 inRange:range
                 options:0
              usingBlock:^(id _Nullable existingValue, NSRange subRange,
                           BOOL *_Nonnull stop) {
                NSMutableParagraphStyle *pStyle =
                    [(NSParagraphStyle *)existingValue mutableCopy];
                NSInteger family =
                    [TextListsUtils familyCountForValue:value
                                                 prefix:prefix
                                                inArray:pStyle.textLists];
                NSInteger depth = family > 0 ? family - 1 : 0;
                CGFloat listHeadIndent = unit * (depth + 1);
                pStyle.headIndent = listHeadIndent;
                pStyle.firstLineHeadIndent = listHeadIndent;
                [self.host.textView.textStorage
                    addAttribute:NSParagraphStyleAttributeName
                           value:pStyle
                           range:subRange];
              }];
}

- (BOOL)styleCondition:(id)value range:(NSRange)range {
  NSParagraphStyle *pStyle = (NSParagraphStyle *)value;
  if (pStyle == nil)
    return NO;
  return [TextListsUtils textLists:pStyle.textLists
                    containsPrefix:[self getMarkerPrefix]];
}

- (void)toggleWithChecked:(BOOL)checked range:(NSRange)range {
  NSRange actualRange = [self actualUsedRange:range];
  BOOL isPresent = [self detect:actualRange];

  if (isPresent) {
    [self remove:actualRange withDirtyRange:YES];
  } else {
    [self addWithChecked:checked
                   range:actualRange
              withTyping:YES
          withDirtyRange:YES];
  }
}

- (void)addWithChecked:(BOOL)checked
                 range:(NSRange)range
            withTyping:(BOOL)withTyping
        withDirtyRange:(BOOL)withDirtyRange {
  NSString *value = checked ? @"EnrichedCheckbox1" : @"EnrichedCheckbox0";
  [self add:range
           withValue:value
          withTyping:withTyping
      withDirtyRange:withDirtyRange];
}

// During dirty range re-application the default add: would use getValue
// (EnrichedCheckbox0) and lose the checked state. Instead, read the original
// marker format from the saved StylePair. Also re-pad the nesting depth —
// see StyleBase padListDepthInRange: for why a single add: alone leaves
// indented items stranded at depth 0.
- (void)reapplyFromStylePair:(StylePair *)pair {
  NSRange range = [pair.rangeValue rangeValue];
  NSParagraphStyle *savedPStyle = (NSParagraphStyle *)pair.styleValue;
  BOOL checked = [TextListsUtils textLists:savedPStyle.textLists
                             containsValue:@"EnrichedCheckbox1"];
  [self addWithChecked:checked range:range withTyping:NO withDirtyRange:NO];
  [self
      padListDepthInRange:range
            fromStylePair:pair
                    value:checked ? @"EnrichedCheckbox1" : @"EnrichedCheckbox0"
                   prefix:[self getMarkerPrefix]];
}

- (void)toggleCheckedAt:(NSUInteger)location
         withDirtyRange:(BOOL)withDirtyRange {
  if (location >= self.host.textView.textStorage.length) {
    return;
  }

  NSParagraphStyle *pStyle =
      [self.host.textView.textStorage attribute:NSParagraphStyleAttributeName
                                        atIndex:location
                                 effectiveRange:NULL];
  NSTextList *list =
      [TextListsUtils firstTextListWithPrefix:[self getMarkerPrefix]
                                      inArray:pStyle.textLists];
  BOOL isCurrentlyChecked =
      [list.markerFormat isEqualToString:@"EnrichedCheckbox1"];

  NSRange paragraphRange = [self.host.textView.textStorage.string
      paragraphRangeForRange:NSMakeRange(location, 0)];

  [self addWithChecked:!isCurrentlyChecked
                 range:paragraphRange
            withTyping:NO
        withDirtyRange:withDirtyRange];
}

- (BOOL)getCheckboxStateAt:(NSUInteger)location {
  if (location >= self.host.textView.textStorage.length) {
    return NO;
  }

  NSParagraphStyle *style =
      [self.host.textView.textStorage attribute:NSParagraphStyleAttributeName
                                        atIndex:location
                                 effectiveRange:NULL];

  return [TextListsUtils textLists:style.textLists
                     containsValue:@"EnrichedCheckbox1"];
}

- (void)indent:(NSRange)range {
  [self indentList:range];
}

- (void)outdent:(NSRange)range {
  [self outdentList:range];
}

- (NSInteger)depthAtLocation:(NSUInteger)location {
  return [self depthForLocation:location];
}

- (BOOL)handleNewlinesInRange:(NSRange)range replacementText:(NSString *)text {
  if ([self detect:self.host.textView.selectedRange] && text.length > 0 &&
      [[NSCharacterSet newlineCharacterSet]
          characterIsMember:[text characterAtIndex:text.length - 1]]) {
    // do the replacement manually
    [TextInsertionUtils replaceText:text
                                 at:range
               additionalAttributes:nullptr
                               host:self.host
                      withSelection:YES];
    // apply unchecked checkbox attributes to the new paragraph
    [self addWithChecked:NO
                   range:self.host.textView.selectedRange
              withTyping:YES
          withDirtyRange:YES];
    return YES;
  }
  return NO;
}

@end
