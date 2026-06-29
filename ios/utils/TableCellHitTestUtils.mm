#import "TableCellHitTestUtils.h"
#import "EnrichedTextInputView.h"
#import "TableAttachment.h"

@implementation TableCellHitResult
@end

@implementation TableCellHitTestUtils

// MARK: - Coordinate helpers

+ (CGPoint)containerPointFromViewPoint:(CGPoint)point
                              textView:(UITextView *)textView {
  return CGPointMake(point.x - textView.textContainerInset.left,
                     point.y - textView.textContainerInset.top);
}

// Counts how many table attachments occur before `charIndex` so JS can target
// the matching `<table>` in the serialized HTML (tables serialize in document
// order).
+ (NSInteger)tableOrdinalBefore:(NSUInteger)charIndex
                      inStorage:(NSTextStorage *)storage {
  if (charIndex == 0) {
    return 0;
  }
  __block NSInteger count = 0;
  [storage enumerateAttribute:NSAttachmentAttributeName
                      inRange:NSMakeRange(0, charIndex)
                      options:0
                   usingBlock:^(id _Nullable value, NSRange range,
                                BOOL *_Nonnull stop) {
                     if ([value isKindOfClass:[TableAttachment class]]) {
                       count += 1;
                     }
                   }];
  return count;
}

// Converts a cell's image-space frame to text-view space (image origin →
// container via the ORC glyph rect → text view via the container inset),
// matching the hit-test path.
+ (CGRect)cellRectInTextView:(CGRect)cellImageRect
                forCharIndex:(NSUInteger)charIndex
                    textView:(UITextView *)textView {
  NSLayoutManager *lm = textView.layoutManager;
  NSUInteger glyphIndex = [lm glyphIndexForCharacterAtIndex:charIndex];
  CGRect glyphRect = [lm boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
                                   inTextContainer:textView.textContainer];
  return CGRectMake(cellImageRect.origin.x + glyphRect.origin.x +
                        textView.textContainerInset.left,
                    cellImageRect.origin.y + glyphRect.origin.y +
                        textView.textContainerInset.top,
                    cellImageRect.size.width, cellImageRect.size.height);
}

// MARK: - Public API

+ (nullable TableCellHitResult *)cellAtTableIndex:(NSInteger)tableIndex
                                              row:(NSInteger)row
                                              col:(NSInteger)col
                                          inInput:
                                              (EnrichedTextInputView *)input {
  if (input == nil) {
    return nil;
  }
  UITextView *textView = input->textView;
  NSTextStorage *storage = textView.textStorage;

  // Find the tableIndex-th table attachment + its ORC location.
  __block NSInteger count = 0;
  __block NSUInteger loc = NSNotFound;
  __block TableAttachment *att = nil;
  [storage enumerateAttribute:NSAttachmentAttributeName
                      inRange:NSMakeRange(0, storage.length)
                      options:0
                   usingBlock:^(id _Nullable value, NSRange range,
                                BOOL *_Nonnull stop) {
                     if ([value isKindOfClass:[TableAttachment class]]) {
                       if (count == tableIndex) {
                         loc = range.location;
                         att = value;
                         *stop = YES;
                       }
                       count += 1;
                     }
                   }];
  if (loc == NSNotFound || att == nil) {
    return nil;
  }
  NSArray<NSArray<NSValue *> *> *cellRects = att.cellRects;
  if (row < 0 || row >= (NSInteger)cellRects.count) {
    return nil;
  }
  NSArray<NSValue *> *rowRects = cellRects[row];
  if (col < 0 || col >= (NSInteger)rowRects.count) {
    return nil;
  }

  TableCellHitResult *result = [[TableCellHitResult alloc] init];
  result.charIndex = (NSInteger)loc;
  result.tableIndex = tableIndex;
  result.row = row;
  result.col = col;
  result.columnFractions = att.columnFractions;
  result.cellRect = [self cellRectInTextView:[rowRects[col] CGRectValue]
                                forCharIndex:loc
                                    textView:textView];
  return result;
}

+ (nullable TableCellHitResult *)
    hitTestTableCellAtPoint:(CGPoint)point
                    inInput:(EnrichedTextInputView *)input {
  if (input == nil) {
    return nil;
  }
  UITextView *textView = input->textView;
  NSLayoutManager *lm = textView.layoutManager;
  NSTextContainer *tc = textView.textContainer;
  NSTextStorage *storage = textView.textStorage;

  CGPoint containerPoint = [self containerPointFromViewPoint:point
                                                    textView:textView];

  NSUInteger glyphIndex = [lm glyphIndexForPoint:containerPoint
                                 inTextContainer:tc];
  CGRect glyphRect = [lm boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
                                   inTextContainer:tc];
  // glyphIndexForPoint returns the nearest glyph even for an out-of-bounds tap;
  // bail unless the touch actually lands inside the glyph box.
  if (!CGRectContainsPoint(glyphRect, containerPoint)) {
    return nil;
  }

  NSUInteger charIndex = [lm characterIndexForGlyphAtIndex:glyphIndex];
  if (charIndex >= storage.length) {
    return nil;
  }

  id attachment = [storage attribute:NSAttachmentAttributeName
                             atIndex:charIndex
                      effectiveRange:NULL];
  if (![attachment isKindOfClass:[TableAttachment class]]) {
    return nil;
  }
  TableAttachment *table = (TableAttachment *)attachment;
  NSArray<NSArray<NSValue *> *> *cellRects = table.cellRects;
  if (cellRects.count == 0) {
    return nil;
  }

  // Tap position relative to the rendered table image (image coordinate space).
  CGPoint local = CGPointMake(containerPoint.x - glyphRect.origin.x,
                              containerPoint.y - glyphRect.origin.y);

  for (NSInteger r = 0; r < (NSInteger)cellRects.count; r++) {
    NSArray<NSValue *> *rowRects = cellRects[r];
    for (NSInteger c = 0; c < (NSInteger)rowRects.count; c++) {
      CGRect cell = [rowRects[c] CGRectValue];
      if (CGRectContainsPoint(cell, local)) {
        // Convert the cell frame from image space → container space →
        // text-view space so JS (which positions its overlay relative to the
        // React wrapper) can place the inline editor over the cell.
        CGRect inTextView = CGRectMake(cell.origin.x + glyphRect.origin.x +
                                           textView.textContainerInset.left,
                                       cell.origin.y + glyphRect.origin.y +
                                           textView.textContainerInset.top,
                                       cell.size.width, cell.size.height);

        TableCellHitResult *result = [[TableCellHitResult alloc] init];
        result.charIndex = (NSInteger)charIndex;
        result.tableIndex = [self tableOrdinalBefore:charIndex
                                           inStorage:storage];
        result.row = r;
        result.col = c;
        result.columnFractions = table.columnFractions;
        result.cellRect = inTextView;
        return result;
      }
    }
  }

  return nil;
}

@end
