#import "InputHtmlParser.h"
#import "AlignmentEntry.h"
#import "EnrichedTextInputView.h"
#import "HtmlParser.h"
#import "StringExtension.h"
#import "StyleHeaders.h"
#import "StyleUtils.h"
#import "TextInsertionUtils.h"
#import "TextListsUtils.h"
#import <React/RCTLog.h>

@implementation InputHtmlParser {
  EnrichedTextInputView __weak *_input;
}

- (instancetype)initWithInput:(id)input {
  self = [super init];
  _input = (EnrichedTextInputView *)input;
  return self;
}

- (void)replaceWholeFromHtml:(NSString *_Nonnull)html {
  // reset the text first and reset typing attributes
  _input->textView.text = @"";
  _input->textView.typingAttributes = _input->defaultTypingAttributes;

  @try {
    NSArray *processingResult = [HtmlParser getTextAndStylesFromHtml:html];
    NSString *plainText = (NSString *)processingResult[0];
    NSArray *stylesInfo = (NSArray *)processingResult[1];
    NSArray *alignments = (NSArray *)processingResult[2];
    NSArray *listDepths =
        processingResult.count > 3 ? (NSArray *)processingResult[3] : nil;

    // set new text
    _input->textView.text = plainText;

    // re-apply the styles
    [self applyProcessedStyles:stylesInfo
           offsetFromBeginning:0
               plainTextLength:plainText.length];
    [self applyProcessedAlignments:alignments offset:0];
    [self applyProcessedListDepths:listDepths offset:0];
    [_input anyTextMayHaveBeenModified];
  } @catch (NSException *exception) {
    RCTLogWarn(@"[EnrichedTextInput]: Failed to parse HTML: (%@), falling back "
               @"to raw input.",
               exception.reason);

    // set new text
    _input->textView.text = html;
  }
}

- (void)replaceFromHtml:(NSString *_Nonnull)html range:(NSRange)range {
  @try {
    NSArray *processingResult = [HtmlParser getTextAndStylesFromHtml:html];
    NSString *plainText = (NSString *)processingResult[0];
    NSArray *stylesInfo = (NSArray *)processingResult[1];
    NSArray *alignments = (NSArray *)processingResult[2];
    NSArray *listDepths =
        processingResult.count > 3 ? (NSArray *)processingResult[3] : nil;

    // we can use ready replace util
    [TextInsertionUtils replaceText:plainText
                                 at:range
               additionalAttributes:nil
                               host:_input
                      withSelection:YES];

    [self applyProcessedStyles:stylesInfo
           offsetFromBeginning:range.location
               plainTextLength:plainText.length];
    [self applyProcessedAlignments:alignments offset:range.location];
    [self applyProcessedListDepths:listDepths offset:range.location];
    [_input anyTextMayHaveBeenModified];
  } @catch (NSException *exception) {
    RCTLogWarn(@"[EnrichedTextInput]: Failed to parse HTML: (%@), falling back "
               @"to raw input.",
               exception.reason);
    [TextInsertionUtils replaceText:html
                                 at:range
               additionalAttributes:nil
                               host:_input
                      withSelection:YES];
  }
}

- (void)insertFromHtml:(NSString *_Nonnull)html location:(NSInteger)location {
  @try {
    NSArray *processingResult = [HtmlParser getTextAndStylesFromHtml:html];
    NSString *plainText = (NSString *)processingResult[0];
    NSArray *stylesInfo = (NSArray *)processingResult[1];
    NSArray *alignments = (NSArray *)processingResult[2];
    NSArray *listDepths =
        processingResult.count > 3 ? (NSArray *)processingResult[3] : nil;

    // same here, insertion utils got our back
    [TextInsertionUtils insertText:plainText
                                at:location
              additionalAttributes:nil
                              host:_input
                     withSelection:YES];

    [self applyProcessedStyles:stylesInfo
           offsetFromBeginning:location
               plainTextLength:plainText.length];
    [self applyProcessedAlignments:alignments offset:location];
    [self applyProcessedListDepths:listDepths offset:location];
    [_input anyTextMayHaveBeenModified];
  } @catch (NSException *exception) {
    RCTLogWarn(@"[EnrichedTextInput]: Failed to parse HTML: (%@), falling back "
               @"to raw input.",
               exception.reason);
    [TextInsertionUtils insertText:html
                                at:location
              additionalAttributes:nil
                              host:_input
                     withSelection:YES];
  }
}

- (void)applyProcessedStyles:(NSArray *)processedStyles
         offsetFromBeginning:(NSInteger)offset
             plainTextLength:(NSUInteger)plainTextLength {
  // Some paragraph styles (codeblock, blockquote, etc.) insert \u200B
  // into empty lines, mutating NSTextStorage length. We need to
  // shift subsequent ranges by this offset.
  NSInteger zeroWidthSpaceOffset = 0;

  for (NSArray *arr in processedStyles) {
    // unwrap all info from processed style
    NSNumber *styleType = (NSNumber *)arr[0];
    StylePair *stylePair = (StylePair *)arr[1];
    StyleBase *baseStyle = _input->stylesDict[styleType];
    NSRange parsedRange = [stylePair.rangeValue rangeValue];
    NSUInteger textLengthBeforeStyleApplied =
        _input->textView.textStorage.string.length;
    // range must be taking zeroWidthSpaceOffset and offest into consideration
    // because processed styles ranges are relative to only the new text while
    // we need absolute ranges relative to the whole existing text
    NSRange styleRange =
        NSMakeRange(offset + zeroWidthSpaceOffset + parsedRange.location,
                    parsedRange.length);

    // of course any changes here need to take blocks and conflicts into
    // consideration
    if ([StyleUtils handleStyleBlocksAndConflicts:[[baseStyle class] getType]
                                            range:styleRange
                                          forHost:_input]) {
      BOOL shouldAddTypingAttr =
          styleRange.location + styleRange.length ==
          plainTextLength + offset + zeroWidthSpaceOffset;

      if ([styleType isEqualToNumber:@([LinkStyle getType])]) {
        LinkData *linkData = (LinkData *)stylePair.styleValue;
        [((LinkStyle *)baseStyle) addLink:linkData
                                    range:styleRange
                            withSelection:NO];
      } else if ([styleType isEqualToNumber:@([MentionStyle getType])]) {
        MentionParams *params = (MentionParams *)stylePair.styleValue;
        [((MentionStyle *)baseStyle) addMentionAtRange:styleRange
                                                params:params];
      } else if ([styleType isEqualToNumber:@([ImageStyle getType])]) {
        ImageData *imgData = (ImageData *)stylePair.styleValue;
        [((ImageStyle *)baseStyle) addImageAtRange:styleRange
                                         imageData:imgData
                                     withSelection:NO
                                    withDirtyRange:YES];
      } else if ([styleType isEqualToNumber:@([CheckboxListStyle getType])]) {
        NSDictionary *checkboxStates = (NSDictionary *)stylePair.styleValue;
        CheckboxListStyle *cbLStyle = (CheckboxListStyle *)baseStyle;

        // First apply the checkbox list style to the entire range with
        // unchecked value
        [cbLStyle addWithChecked:NO
                           range:styleRange
                      withTyping:shouldAddTypingAttr
                  withDirtyRange:YES];

        if (checkboxStates && checkboxStates.count > 0) {
          // Then toggle checked checkboxes
          for (NSNumber *key in checkboxStates) {
            NSUInteger checkboxPosition =
                offset + zeroWidthSpaceOffset + [key unsignedIntegerValue];
            BOOL isChecked = [checkboxStates[key] boolValue];
            if (isChecked) {
              [cbLStyle toggleCheckedAt:checkboxPosition withDirtyRange:YES];
            }
          }
        }
      } else {
        [baseStyle add:styleRange
                withTyping:shouldAddTypingAttr
            withDirtyRange:YES];
      }
    }

    NSInteger delta = (NSInteger)_input->textView.textStorage.string.length -
                      (NSInteger)textLengthBeforeStyleApplied;
    // Image shifts are already handled by _precedingImageCount during tag
    // finalization.
    if (delta != 0 && ![styleType isEqualToNumber:@([ImageStyle getType])]) {
      zeroWidthSpaceOffset += delta;
    }
  }
}

- (void)applyProcessedAlignments:(NSArray<AlignmentEntry *> *)alignments
                          offset:(NSInteger)offset {
  AlignmentStyle *alignmentStyle =
      _input.stylesDict[@([AlignmentStyle getType])];

  if (alignmentStyle == nil) {
    return;
  }

  for (AlignmentEntry *entry in alignments) {
    // Offset the range (e.g. if inserting into the middle of text)
    NSRange finalRange =
        NSMakeRange(offset + entry.range.location, entry.range.length);

    [alignmentStyle addAlignment:entry.alignment
                           range:finalRange
                      withTyping:NO
                  withDirtyRange:NO];
  }
}

- (NSString *_Nullable)initiallyProcessHtml:(NSString *_Nonnull)html {
  return [HtmlParser initiallyProcessHtml:html
                        useHtmlNormalizer:_input->useHtmlNormalizer];
}

// Restores nested-list depth for each <li data-depth="N"> the serializer
// recorded. The surrounding <ul>/<ol> style is applied once over the whole
// list range — that produces a single textLists family entry per paragraph
// (depth 0). For paragraphs that need more depth, we lift them via
// textListsByIncreasingDepth one step at a time so the marker family is
// re-pushed N times.
//
// Detecting which family to lift from the paragraph's current textLists
// (UL, OL, or Checkbox) keeps this entry-point family-agnostic — the
// serializer doesn't need to encode kind, and a malformed mix doesn't blow
// up. Paragraphs that ended up without a list family are skipped.
- (void)applyProcessedListDepths:(NSArray<NSDictionary *> *)depths
                          offset:(NSInteger)offset {
  if (depths.count == 0) {
    return;
  }
  NSTextStorage *ts = _input->textView.textStorage;
  if (ts.length == 0) {
    return;
  }
  for (NSDictionary *entry in depths) {
    NSInteger loc = offset + [entry[@"loc"] integerValue];
    NSInteger depth = [entry[@"depth"] integerValue];
    if (loc < 0 || (NSUInteger)loc >= ts.length || depth <= 0) {
      continue;
    }
    NSRange paragraphRange =
        [ts.string paragraphRangeForRange:NSMakeRange(loc, 0)];
    NSMutableParagraphStyle *pStyle =
        [[ts attribute:NSParagraphStyleAttributeName
                   atIndex:loc
            effectiveRange:nil] mutableCopy];
    if (pStyle == nil) {
      continue;
    }

    NSString *value = nil;
    NSString *prefix = nil;
    if ([TextListsUtils familyCountForValue:@"EnrichedOrderedList"
                                     prefix:nil
                                    inArray:pStyle.textLists] > 0) {
      value = @"EnrichedOrderedList";
    } else if ([TextListsUtils familyCountForValue:@"EnrichedUnorderedList"
                                            prefix:nil
                                           inArray:pStyle.textLists] > 0) {
      value = @"EnrichedUnorderedList";
    } else if ([TextListsUtils familyCountForValue:@"EnrichedCheckbox0"
                                            prefix:@"EnrichedCheckbox"
                                           inArray:pStyle.textLists] > 0) {
      value = @"EnrichedCheckbox0";
      prefix = @"EnrichedCheckbox";
    } else {
      continue;
    }

    NSArray<NSTextList *> *current = pStyle.textLists;
    for (NSInteger i = 0; i < depth; i++) {
      current = [TextListsUtils textListsByIncreasingDepthForValue:value
                                                            prefix:prefix
                                                           inArray:current];
    }
    pStyle.textLists = current;
    [ts addAttribute:NSParagraphStyleAttributeName
               value:pStyle
               range:paragraphRange];
  }
}

@end
