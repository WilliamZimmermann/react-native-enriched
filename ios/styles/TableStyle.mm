#import "EnrichedTextInputView.h"
#import "StyleHeaders.h"
#import "TableAttachment.h"
#import "TextInsertionUtils.h"

// Mirrors ImageStyle: each `<table>` lands as a single Object Replacement
// Character ('￼') in the text storage, with this custom attribute and
// NSAttachmentAttributeName carrying the TableAttachment renderer.
static NSString *const TableAttributeName = @"EnrichedTable";

// Default content width when we can't read the live container width — the
// editor uses ~344pt content width on a typical iPad split view. Slight
// overshoot is fine: TableAttachment.attachmentBoundsForTextContainer caps
// the actual draw region.
static const CGFloat kKatavTableFallbackContentWidth = 320.0;

@implementation TableStyle

+ (StyleType)getType {
  return Table;
}

- (NSString *)getKey {
  return TableAttributeName;
}

- (BOOL)isParagraph {
  return NO;
}

- (void)applyStyling:(NSRange)range {
  // no-op — TableAttachment owns the visual; nothing to (re)style here.
}

- (CGFloat)contentWidthHint {
  CGFloat hint = self.host.textView.textContainer.size.width;
  if (hint <= 0 || isnan(hint) || isinf(hint)) {
    hint = kKatavTableFallbackContentWidth;
  }
  return hint;
}

- (void)reapplyFromStylePair:(StylePair *)pair {
  NSRange range = [pair.rangeValue rangeValue];
  TableData *data = (TableData *)pair.styleValue;
  if (data == nullptr || range.length == 0) {
    return;
  }
  TableAttachment *attachment =
      [[TableAttachment alloc] initWithTableData:data
                                    contentWidth:[self contentWidthHint]];
  [self.host.textView.textStorage addAttributes:@{
    NSAttachmentAttributeName : attachment,
    TableAttributeName : data,
  }
                                          range:range];
}

- (AttributeEntry *)getEntryIfPresent:(NSRange)range {
  return nullptr;
}

- (void)toggle:(NSRange)range {
  // no-op — tables can't be toggled inline; they're inserted via the
  // setTable surface (or replayed from HTML on load).
}

- (void)remove:(NSRange)range withDirtyRange:(BOOL)withDirtyRange {
  [self.host.textView.textStorage beginEditing];
  [self.host.textView.textStorage removeAttribute:TableAttributeName
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
  NSMutableDictionary *current =
      [self.host.textView.typingAttributes mutableCopy];
  [current removeObjectForKey:TableAttributeName];
  [current removeObjectForKey:NSAttachmentAttributeName];
  [self.host.attributesManager didRemoveTypingAttribute:TableAttributeName];
  self.host.textView.typingAttributes = current;
}

- (BOOL)styleCondition:(id _Nullable)value range:(NSRange)range {
  return [value isKindOfClass:[TableData class]];
}

- (TableData *)getTableDataAt:(NSUInteger)location {
  if (location >= self.host.textView.textStorage.length) {
    return nullptr;
  }
  NSRange effectiveRange = NSMakeRange(0, 0);
  TableData *data = [self.host.textView.textStorage
                  attribute:TableAttributeName
                    atIndex:location
      longestEffectiveRange:&effectiveRange
                    inRange:NSMakeRange(0,
                                        self.host.textView.textStorage.length)];
  return data;
}

- (void)addTableAtRange:(NSRange)range
              tableData:(TableData *)tableData
          withSelection:(BOOL)withSelection
         withDirtyRange:(BOOL)withDirtyRange {
  if (tableData == nullptr) {
    return;
  }

  TableAttachment *attachment =
      [[TableAttachment alloc] initWithTableData:tableData
                                    contentWidth:[self contentWidthHint]];

  NSDictionary *attributes = @{
    NSAttachmentAttributeName : attachment,
    TableAttributeName : tableData,
  };
  // Object Replacement Character — same trick ImageStyle uses to tell
  // TextKit "this glyph hosts an attachment".
  NSString *placeholderChar = @"￼";

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
    NSRange insertedRange = NSMakeRange(range.location, 1);
    [self.host.attributesManager addDirtyRange:insertedRange];
  }
}

@end
