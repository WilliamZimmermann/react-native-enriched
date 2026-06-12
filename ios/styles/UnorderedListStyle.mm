#import "EnrichedTextInputView.h"
#import "RangeUtils.h"
#import "StyleHeaders.h"
#import "StyleUtils.h"
#import "TextInsertionUtils.h"
#import "TextListsUtils.h"

@implementation UnorderedListStyle

+ (StyleType)getType {
  return UnorderedList;
}

- (NSString *)getValue {
  return @"EnrichedUnorderedList";
}

- (BOOL)isParagraph {
  return YES;
}

- (BOOL)needsZWS {
  return YES;
}

- (void)applyStyling:(NSRange)range {
  // lists are drawn manually
  // margin before bullet + gap between bullet and paragraph; one unit per
  // nesting depth so indented items shift right and their markers still sit
  // in the gutter
  CGFloat unit = [self.host.config unorderedListMarginLeft] +
                 [self.host.config unorderedListGapWidth];

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

- (void)indent:(NSRange)range {
  [self indentList:range];
}

- (void)outdent:(NSRange)range {
  [self outdentList:range];
}

- (NSInteger)depthAtLocation:(NSUInteger)location {
  return [self depthForLocation:location];
}

// Restore nesting depth after the dirty-range cycle wiped textLists. Default
// reapplyFromStylePair: only re-adds the single family entry — see comment on
// StyleBase padListDepthInRange:.
- (void)reapplyFromStylePair:(StylePair *)pair {
  [super reapplyFromStylePair:pair];
  [self padListDepthInRange:[pair.rangeValue rangeValue]
              fromStylePair:pair
                      value:[self getValue]
                     prefix:[self getMarkerPrefix]];
}

@end
