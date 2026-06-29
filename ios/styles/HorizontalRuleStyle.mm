#import "EnrichedTextInputView.h"
#import "HorizontalRuleAttachment.h"
#import "StyleHeaders.h"
#import "TextInsertionUtils.h"

// Custom NSAttributedStringKey marking the object-replacement character that
// stands in for the rule. The value is a sentinel (@YES) — the rule carries no
// payload, it always renders the same full-width divider.
static NSString *const HorizontalRuleAttributeName = @"EnrichedHorizontalRule";

@implementation HorizontalRuleStyle

+ (StyleType)getType {
  return HorizontalRule;
}

- (NSString *)getKey {
  return HorizontalRuleAttributeName;
}

- (BOOL)isParagraph {
  return NO;
}

- (void)applyStyling:(NSRange)range {
  // no-op for horizontal rule
}

- (void)reapplyFromStylePair:(StylePair *)pair {
  NSRange range = [pair.rangeValue rangeValue];
  if (range.length == 0) {
    return;
  }

  HorizontalRuleAttachment *attachment =
      [[HorizontalRuleAttachment alloc] init];
  [self.host.textView.textStorage addAttributes:@{
    NSAttachmentAttributeName : attachment,
    HorizontalRuleAttributeName : @YES
  }
                                          range:range];
}

- (AttributeEntry *)getEntryIfPresent:(NSRange)range {
  return nullptr;
}

- (void)toggle:(NSRange)range {
  // no-op for horizontal rule
}

- (void)remove:(NSRange)range withDirtyRange:(BOOL)withDirtyRange {
  [self.host.textView.textStorage beginEditing];
  [self.host.textView.textStorage removeAttribute:HorizontalRuleAttributeName
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
  NSMutableDictionary *currentAttributes =
      [self.host.textView.typingAttributes mutableCopy];
  [currentAttributes removeObjectForKey:HorizontalRuleAttributeName];
  [currentAttributes removeObjectForKey:NSAttachmentAttributeName];
  [self.host.attributesManager
      didRemoveTypingAttribute:HorizontalRuleAttributeName];
  self.host.textView.typingAttributes = currentAttributes;
}

- (BOOL)styleCondition:(id _Nullable)value range:(NSRange)range {
  return [value isKindOfClass:[NSNumber class]];
}

- (BOOL)isHorizontalRuleAt:(NSUInteger)location {
  if (location >= self.host.textView.textStorage.length) {
    return NO;
  }
  NSRange effective = NSMakeRange(0, 0);
  id value =
      [self.host.textView.textStorage attribute:HorizontalRuleAttributeName
                                        atIndex:location
                                 effectiveRange:&effective];
  return [value isKindOfClass:[NSNumber class]];
}

- (void)addHorizontalRuleAtRange:(NSRange)range
                   withSelection:(BOOL)withSelection
                  withDirtyRange:(BOOL)withDirtyRange {
  HorizontalRuleAttachment *attachment =
      [[HorizontalRuleAttachment alloc] init];

  NSDictionary *attributes = @{
    NSAttachmentAttributeName : attachment,
    HorizontalRuleAttributeName : @YES
  };

  // Object Replacement Character — same placeholder TextKit uses for images;
  // signals "non-text glyph goes here".
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

// Inserts the rule at the caret, forcing it onto its own line: a leading
// newline is added when the caret isn't already at the start of a line, and a
// trailing newline so the user lands on a fresh empty line below the rule.
- (void)insertHorizontalRule {
  NSTextStorage *ts = self.host.textView.textStorage;
  NSString *str = ts.string;
  NSUInteger loc = self.host.textView.selectedRange.location;
  if (loc > str.length) {
    loc = str.length;
  }

  NSCharacterSet *newlines = [NSCharacterSet newlineCharacterSet];

  BOOL needLeading =
      (loc > 0) && ![newlines characterIsMember:[str characterAtIndex:loc - 1]];
  if (needLeading) {
    [TextInsertionUtils insertText:@"\n"
                                at:loc
              additionalAttributes:nil
                              host:self.host
                     withSelection:YES];
    loc += 1;
  }

  [self addHorizontalRuleAtRange:NSMakeRange(loc, 0)
                   withSelection:YES
                  withDirtyRange:YES];

  NSUInteger afterRule = loc + 1;
  NSString *updated = self.host.textView.textStorage.string;
  BOOL needTrailing =
      (afterRule >= updated.length) ||
      ![newlines characterIsMember:[updated characterAtIndex:afterRule]];
  if (needTrailing) {
    [TextInsertionUtils insertText:@"\n"
                                at:afterRule
              additionalAttributes:nil
                              host:self.host
                     withSelection:YES];
  }
}

@end
