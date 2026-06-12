#import "LayoutManagerExtension.h"
#import "ColorExtension.h"
#import "EnrichedViewHost.h"
#import "RangeUtils.h"
#import "StyleHeaders.h"
#import "TextListsUtils.h"
#import "WeakBox.h"
#import <objc/runtime.h>

// Glyph cycle for nested unordered (bullet) lists. depth 0 = filled circle,
// 1 = filled square, 2 = hollow circle; depth >= 3 cycles. Kept short so any
// realistic nesting reads consistently.
typedef NS_ENUM(NSInteger, EnrichedBulletShape) {
  EnrichedBulletShapeFilledCircle = 0,
  EnrichedBulletShapeFilledSquare,
  EnrichedBulletShapeHollowCircle,
};

static EnrichedBulletShape EnrichedBulletShapeForDepth(NSInteger depth) {
  NSInteger n = depth < 0 ? 0 : depth;
  return (EnrichedBulletShape)(n % 3);
}

// Lowercase roman numeral up to 39 (covers any plausible sublist count).
static NSString *EnrichedLowercaseRoman(NSInteger value) {
  if (value <= 0)
    return @"";
  static NSArray<NSString *> *symbols;
  static NSArray<NSNumber *> *values;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    symbols = @[ @"xxx", @"xx", @"x", @"ix", @"v", @"iv", @"i" ];
    values = @[ @30, @20, @10, @9, @5, @4, @1 ];
  });
  NSMutableString *out = [NSMutableString new];
  for (NSUInteger i = 0; i < values.count; i++) {
    NSInteger v = values[i].integerValue;
    while (value >= v) {
      [out appendString:symbols[i]];
      value -= v;
    }
  }
  return out;
}

// Lowercase letter — a, b, c ... z, then aa, ab ... like spreadsheet columns.
// Caps at depth-1 in practice (per-depth counters reset cleanly between
// sublists), so 26 is plenty; the spreadsheet rollover is just for safety.
static NSString *EnrichedLowercaseLetter(NSInteger value) {
  if (value <= 0)
    return @"";
  NSMutableString *out = [NSMutableString new];
  while (value > 0) {
    value--;
    [out
        insertString:[NSString stringWithFormat:@"%c", (char)('a' + value % 26)]
             atIndex:0];
    value /= 26;
  }
  return out;
}

// Ordered-list marker per depth: 0 → "N.", 1 → "x.", 2 → "rn." then cycle.
static NSString *EnrichedOrderedListMarker(NSInteger depth, NSInteger index) {
  NSInteger n = depth < 0 ? 0 : (depth % 3);
  switch (n) {
  case 0:
    return [NSString stringWithFormat:@"%ld.", (long)index];
  case 1:
    return [NSString stringWithFormat:@"%@.", EnrichedLowercaseLetter(index)];
  case 2:
    return [NSString stringWithFormat:@"%@.", EnrichedLowercaseRoman(index)];
  }
  return [NSString stringWithFormat:@"%ld.", (long)index];
}

@implementation NSLayoutManager (LayoutManagerExtension)

static void const *kInputKey = &kInputKey;

- (id)input {
  WeakBox *box = objc_getAssociatedObject(self, kInputKey);
  return box.value;
}

- (void)setInput:(id)value {
  WeakBox *box = [WeakBox new];
  box.value = value;
  objc_setAssociatedObject(self, kInputKey, box,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)load {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class myClass = [NSLayoutManager class];
    SEL originalSelector = @selector(drawBackgroundForGlyphRange:atPoint:);
    SEL swizzledSelector = @selector(my_drawBackgroundForGlyphRange:atPoint:);
    Method originalMethod = class_getInstanceMethod(myClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(myClass, swizzledSelector);

    BOOL didAddMethod = class_addMethod(
        myClass, originalSelector, method_getImplementation(swizzledMethod),
        method_getTypeEncoding(swizzledMethod));

    if (didAddMethod) {
      class_replaceMethod(myClass, swizzledSelector,
                          method_getImplementation(originalMethod),
                          method_getTypeEncoding(originalMethod));
    } else {
      method_exchangeImplementations(originalMethod, swizzledMethod);
    }
  });
}

- (void)my_drawBackgroundForGlyphRange:(NSRange)glyphRange
                               atPoint:(CGPoint)origin {
  [self my_drawBackgroundForGlyphRange:glyphRange atPoint:origin];

  id<EnrichedViewHost> host = self.input;
  if (host == nullptr) {
    return;
  }

  NSRange visibleCharRange = [self characterRangeForGlyphRange:glyphRange
                                              actualGlyphRange:NULL];

  [self drawBlockQuotes:host origin:origin visibleCharRange:visibleCharRange];
  [self drawLists:host origin:origin visibleCharRange:visibleCharRange];
  [self drawCodeBlocks:host origin:origin visibleCharRange:visibleCharRange];
}

- (void)drawCodeBlocks:(id<EnrichedViewHost>)host
                origin:(CGPoint)origin
      visibleCharRange:(NSRange)visibleCharRange {
  CodeBlockStyle *codeBlockStyle = host.stylesDict[@([CodeBlockStyle getType])];
  if (codeBlockStyle == nullptr) {
    return;
  }

  NSArray<StylePair *> *allCodeBlocks = [codeBlockStyle all:visibleCharRange];
  NSArray<StylePair *> *mergedCodeBlocks =
      [self mergeContiguousStylePairs:allCodeBlocks];
  UIColor *bgColor = [[host.config codeBlockBgColor] colorWithResolvedAlpha];
  CGFloat radius = [host.config codeBlockBorderRadius];
  [bgColor setFill];

  for (StylePair *pair in mergedCodeBlocks) {
    NSRange blockCharacterRange = [pair.rangeValue rangeValue];
    if (blockCharacterRange.length == 0)
      continue;

    NSArray *paragraphs =
        [RangeUtils getSeparateParagraphsRangesIn:host.textView
                                            range:blockCharacterRange];
    if (paragraphs.count == 0)
      continue;

    NSRange firstParagraphRange =
        [((NSValue *)[paragraphs firstObject]) rangeValue];
    NSRange lastParagraphRange =
        [((NSValue *)[paragraphs lastObject]) rangeValue];

    for (NSValue *paragraphValue in paragraphs) {
      NSRange paragraphCharacterRange = [paragraphValue rangeValue];

      BOOL isFirstParagraph =
          NSEqualRanges(paragraphCharacterRange, firstParagraphRange);
      BOOL isLastParagraph =
          NSEqualRanges(paragraphCharacterRange, lastParagraphRange);

      NSRange paragraphGlyphRange =
          [self glyphRangeForCharacterRange:paragraphCharacterRange
                       actualCharacterRange:NULL];

      __block BOOL isFirstLineOfParagraph = YES;

      [self
          enumerateLineFragmentsForGlyphRange:paragraphGlyphRange
                                   usingBlock:^(
                                       CGRect rect, CGRect usedRect,
                                       NSTextContainer *_Nonnull textContainer,
                                       NSRange glyphRange,
                                       BOOL *_Nonnull stop) {
                                     CGRect lineBgRect = rect;
                                     lineBgRect.origin.x = origin.x;
                                     lineBgRect.origin.y += origin.y;
                                     lineBgRect.size.width =
                                         textContainer.size.width;

                                     UIRectCorner cornersForThisLine = 0;

                                     if (isFirstParagraph &&
                                         isFirstLineOfParagraph) {
                                       cornersForThisLine =
                                           UIRectCornerTopLeft |
                                           UIRectCornerTopRight;
                                     }

                                     BOOL isLastLineOfParagraph =
                                         (NSMaxRange(glyphRange) >=
                                          NSMaxRange(paragraphGlyphRange));

                                     if (isLastParagraph &&
                                         isLastLineOfParagraph) {
                                       cornersForThisLine =
                                           cornersForThisLine |
                                           UIRectCornerBottomLeft |
                                           UIRectCornerBottomRight;
                                     }

                                     UIBezierPath *path = [UIBezierPath
                                         bezierPathWithRoundedRect:lineBgRect
                                                 byRoundingCorners:
                                                     cornersForThisLine
                                                       cornerRadii:CGSizeMake(
                                                                       radius,
                                                                       radius)];
                                     [path fill];

                                     isFirstLineOfParagraph = NO;
                                   }];
    }
  }
}

- (NSArray<StylePair *> *)mergeContiguousStylePairs:
    (NSArray<StylePair *> *)pairs {
  if (pairs.count == 0) {
    return @[];
  }

  NSMutableArray<StylePair *> *mergedPairs = [[NSMutableArray alloc] init];
  StylePair *currentPair = pairs[0];
  NSRange currentRange = [currentPair.rangeValue rangeValue];
  for (NSUInteger i = 1; i < pairs.count; i++) {
    StylePair *nextPair = pairs[i];
    NSRange nextRange = [nextPair.rangeValue rangeValue];

    // The Gap Check:
    // NSMaxRange(currentRange) is where the current block ends.
    // nextRange.location is where the next block starts.
    if (NSMaxRange(currentRange) == nextRange.location) {
      // They touch perfectly (no gap). Merge them.
      currentRange.length += nextRange.length;
    } else {
      // There is a gap (indices don't match).
      // 1. Save the finished block.
      StylePair *mergedPair = [[StylePair alloc] init];
      mergedPair.rangeValue = [NSValue valueWithRange:currentRange];
      mergedPair.styleValue = currentPair.styleValue;
      [mergedPairs addObject:mergedPair];

      // 2. Start a brand new block.
      currentPair = nextPair;
      currentRange = nextRange;
    }
  }

  // Add the final block
  StylePair *lastPair = [[StylePair alloc] init];
  lastPair.rangeValue = [NSValue valueWithRange:currentRange];
  lastPair.styleValue = currentPair.styleValue;
  [mergedPairs addObject:lastPair];

  return mergedPairs;
}

- (void)drawBlockQuotes:(id<EnrichedViewHost>)host
                 origin:(CGPoint)origin
       visibleCharRange:(NSRange)visibleCharRange {
  BlockQuoteStyle *bqStyle = host.stylesDict[@([BlockQuoteStyle getType])];
  if (bqStyle == nullptr) {
    return;
  }

  NSArray *allBlockquotes = [bqStyle all:visibleCharRange];

  for (StylePair *pair in allBlockquotes) {
    NSRange paragraphRange = [host.textView.textStorage.string
        paragraphRangeForRange:[pair.rangeValue rangeValue]];
    NSRange paragraphGlyphRange =
        [self glyphRangeForCharacterRange:paragraphRange
                     actualCharacterRange:nullptr];
    [self
        enumerateLineFragmentsForGlyphRange:paragraphGlyphRange
                                 usingBlock:^(
                                     CGRect rect, CGRect usedRect,
                                     NSTextContainer *_Nonnull textContainer,
                                     NSRange glyphRange, BOOL *_Nonnull stop) {
                                   CGFloat paddingLeft = origin.x;
                                   CGFloat paddingTop = origin.y;
                                   CGFloat x = paddingLeft;
                                   CGFloat y = paddingTop + rect.origin.y;
                                   CGFloat width =
                                       [host.config blockquoteBorderWidth];
                                   CGFloat height = rect.size.height;

                                   CGRect lineRect =
                                       CGRectMake(x, y, width, height);
                                   [[host.config blockquoteBorderColor]
                                       setFill];
                                   UIRectFill(lineRect);
                                 }];
  }
}

- (void)drawLists:(id<EnrichedViewHost>)host
              origin:(CGPoint)origin
    visibleCharRange:(NSRange)visibleCharRange {
  UnorderedListStyle *ulStyle =
      host.stylesDict[@([UnorderedListStyle getType])];
  OrderedListStyle *olStyle = host.stylesDict[@([OrderedListStyle getType])];
  CheckboxListStyle *cbStyle = host.stylesDict[@([CheckboxListStyle getType])];

  NSMutableArray *allLists = [[NSMutableArray alloc] init];

  if (ulStyle != nullptr) {
    [allLists addObjectsFromArray:[ulStyle all:visibleCharRange]];
  }
  if (olStyle != nullptr) {
    [allLists addObjectsFromArray:[olStyle all:visibleCharRange]];
  }
  if (cbStyle != nullptr) {
    [allLists addObjectsFromArray:[cbStyle all:visibleCharRange]];
  }

  for (StylePair *pair in allLists) {
    NSParagraphStyle *pStyle = (NSParagraphStyle *)pair.styleValue;
    NSDictionary *markerAttributes = @{
      NSFontAttributeName : [host.config orderedListMarkerFont],
      NSForegroundColorAttributeName : [host.config orderedListMarkerColor]
    };
    CGFloat indent = pStyle.firstLineHeadIndent;

    NSArray *paragraphs =
        [RangeUtils getSeparateParagraphsRangesIn:host.textView
                                            range:[pair.rangeValue rangeValue]];

    for (NSValue *paragraph in paragraphs) {
      NSRange paragraphGlyphRange =
          [self glyphRangeForCharacterRange:[paragraph rangeValue]
                       actualCharacterRange:nullptr];

      // Determine list kind + nesting depth ONCE per paragraph. With nesting,
      // pStyle.textLists holds N entries of the same family (one per depth
      // level); iterating them all would draw the marker N times. We pick a
      // single representative entry and derive depth from family count.
      __block NSString *listKind = nil;
      __block NSInteger listDepth = 0;
      __block NSString *checkboxFormat = nil;
      NSInteger ulCount =
          [TextListsUtils familyCountForValue:@"EnrichedUnorderedList"
                                       prefix:nil
                                      inArray:pStyle.textLists];
      NSInteger olCount =
          [TextListsUtils familyCountForValue:@"EnrichedOrderedList"
                                       prefix:nil
                                      inArray:pStyle.textLists];
      NSInteger cbCount =
          [TextListsUtils familyCountForValue:@"EnrichedCheckbox0"
                                       prefix:@"EnrichedCheckbox"
                                      inArray:pStyle.textLists];
      if (olCount > 0) {
        listKind = @"ol";
        listDepth = olCount - 1;
      } else if (ulCount > 0) {
        listKind = @"ul";
        listDepth = ulCount - 1;
      } else if (cbCount > 0) {
        listKind = @"cb";
        listDepth = cbCount - 1;
        NSTextList *firstCheckbox =
            [TextListsUtils firstTextListWithPrefix:@"EnrichedCheckbox"
                                            inArray:pStyle.textLists];
        checkboxFormat = firstCheckbox.markerFormat;
      } else {
        // Paragraph claimed to be list-styled but has no list family entries
        // — only alignment markers etc. Nothing to draw.
        continue;
      }

      [self enumerateLineFragmentsForGlyphRange:paragraphGlyphRange
                                     usingBlock:^(CGRect rect, CGRect usedRect,
                                                  NSTextContainer *container,
                                                  NSRange lineGlyphRange,
                                                  BOOL *stop) {
                                       NSUInteger charIdx =
                                           [self characterIndexForGlyphAtIndex:
                                                     lineGlyphRange.location];
                                       UIFont *font = [host.textView.textStorage
                                                attribute:NSFontAttributeName
                                                  atIndex:charIdx
                                           effectiveRange:nil];
                                       CGRect textUsedRect =
                                           [self getTextAlignedUsedRect:usedRect
                                                                   font:font];

                                       if ([listKind isEqualToString:@"ol"]) {
                                         NSString *marker = [self
                                             getDecimalMarkerForList:host
                                                           charIndex:charIdx
                                                               depth:listDepth];
                                         [self drawDecimal:host
                                                       marker:marker
                                             markerAttributes:markerAttributes
                                                       origin:origin
                                                     usedRect:usedRect
                                                       indent:indent];
                                       } else if ([listKind
                                                      isEqualToString:@"ul"]) {
                                         [self drawBullet:host
                                                    depth:listDepth
                                                   origin:origin
                                                 usedRect:textUsedRect
                                                   indent:indent];
                                       } else if ([listKind
                                                      isEqualToString:@"cb"]) {
                                         [self drawCheckbox:host
                                               markerFormat:checkboxFormat
                                                     origin:origin
                                                   usedRect:textUsedRect
                                                     indent:indent];
                                       }
                                       // only first line of a list gets its
                                       // marker drawn
                                       *stop = YES;
                                     }];
    }
  }
}

- (NSString *)getDecimalMarkerForList:(id<EnrichedViewHost>)host
                            charIndex:(NSUInteger)index
                                depth:(NSInteger)depth {
  // Counter for the paragraph at `index` (assumed OL of depth `depth`).
  // Walk backward through consecutive OL paragraphs:
  //   - paragraph at depth == depth  → counter++  (sibling in our list)
  //   - paragraph at depth >  depth  → skip       (nested child of an earlier
  //                                                 sibling — same outer
  //                                                 sequence, doesn't reset
  //                                                 our counter)
  //   - paragraph at depth <  depth  → STOP       (we've exited the sublist;
  //                                                 outer ancestor starts a
  //                                                 different counter run)
  //   - paragraph not OL             → STOP       (left lists entirely)
  NSString *fullText = host.textView.textStorage.string;
  NSInteger itemNumber = 1;

  NSRange currentParagraph =
      [fullText paragraphRangeForRange:NSMakeRange(index, 0)];
  if (currentParagraph.location > 0) {
    OrderedListStyle *olStyle = host.stylesDict[@([OrderedListStyle getType])];

    NSInteger cursor =
        [fullText paragraphRangeForRange:NSMakeRange(
                                             currentParagraph.location - 1, 0)]
            .location;

    while (true) {
      NSRange probe = NSMakeRange(cursor, 0);
      if (![olStyle detect:probe]) {
        break;
      }
      NSInteger paragraphDepth = [olStyle depthAtLocation:cursor];
      if (paragraphDepth < 0) {
        // Shouldn't happen if detect: returned YES, but defensive.
        break;
      }
      if (paragraphDepth < depth) {
        break;
      }
      if (paragraphDepth == depth) {
        itemNumber++;
      }
      // paragraphDepth > depth → skip (nested children)
      if (cursor == 0)
        break;
      cursor =
          [fullText paragraphRangeForRange:NSMakeRange(cursor - 1, 0)].location;
    }
  }

  return EnrichedOrderedListMarker(depth, itemNumber);
}

// Returns a usedRect adjusted to cover only the text portion of the line.
// When minimumLineHeight expands the line box, extra space is added at the top
// and text stays at the bottom. This strips that padding so markers align with
// the text, not the full line box.
- (CGRect)getTextAlignedUsedRect:(CGRect)usedRect font:(UIFont *)font {
  if (font && usedRect.size.height > font.lineHeight) {
    CGFloat extraSpace = usedRect.size.height - font.lineHeight;
    usedRect.origin.y += extraSpace;
    usedRect.size.height = font.lineHeight;
  }
  return usedRect;
}

- (void)drawCheckbox:(id<EnrichedViewHost>)host
        markerFormat:(NSString *)markerFormat
              origin:(CGPoint)origin
            usedRect:(CGRect)usedRect
              indent:(CGFloat)indent {
  BOOL isChecked = [markerFormat isEqualToString:@"EnrichedCheckbox1"];

  UIImage *image = isChecked ? host.config.checkboxCheckedImage
                             : host.config.checkboxUncheckedImage;
  CGFloat gapWidth = [host.config checkboxListGapWidth];
  CGFloat configuredBoxSize = [host.config checkboxListBoxSize];

  CGFloat boxSize = MIN(configuredBoxSize, usedRect.size.height);
  CGFloat centerY = CGRectGetMidY(usedRect) + origin.y;
  CGFloat boxX = origin.x + indent - gapWidth - boxSize;
  CGFloat boxY = centerY - boxSize / 2.0;

  [image drawInRect:CGRectMake(boxX, boxY, boxSize, boxSize)];
}

- (void)drawBullet:(id<EnrichedViewHost>)host
             depth:(NSInteger)depth
            origin:(CGPoint)origin
          usedRect:(CGRect)usedRect
            indent:(CGFloat)indent {
  CGFloat gapWidth = [host.config unorderedListGapWidth];
  CGFloat bulletSize = [host.config unorderedListBulletSize];
  CGFloat bulletX = origin.x + indent - gapWidth - bulletSize / 2;
  CGFloat centerY = CGRectGetMidY(usedRect) + origin.y;

  UIColor *fill = [host.config unorderedListBulletColor];
  EnrichedBulletShape shape = EnrichedBulletShapeForDepth(depth);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSaveGState(context);
  {
    [fill setFill];
    [fill setStroke];
    switch (shape) {
    case EnrichedBulletShapeFilledCircle: {
      CGContextAddArc(context, bulletX, centerY, bulletSize / 2, 0, 2 * M_PI,
                      YES);
      CGContextFillPath(context);
      break;
    }
    case EnrichedBulletShapeFilledSquare: {
      // Square is visually heavier than the circle at the same diameter;
      // shrink slightly so it doesn't dominate the gutter.
      CGFloat side = bulletSize * 0.85;
      CGRect rect =
          CGRectMake(bulletX - side / 2, centerY - side / 2, side, side);
      CGContextFillRect(context, rect);
      break;
    }
    case EnrichedBulletShapeHollowCircle: {
      // Stroke an unfilled circle. Stroke width scales with the bullet so
      // it reads cleanly at small font sizes too.
      CGFloat lineWidth = MAX(1.0, bulletSize * 0.2);
      CGContextSetLineWidth(context, lineWidth);
      CGFloat radius = (bulletSize - lineWidth) / 2;
      CGContextAddArc(context, bulletX, centerY, radius, 0, 2 * M_PI, YES);
      CGContextStrokePath(context);
      break;
    }
    }
  }
  CGContextRestoreGState(context);
}

- (void)drawDecimal:(id<EnrichedViewHost>)host
              marker:(NSString *)marker
    markerAttributes:(NSDictionary *)markerAttributes
              origin:(CGPoint)origin
            usedRect:(CGRect)usedRect
              indent:(CGFloat)indent {
  CGFloat gapWidth = [host.config orderedListGapWidth];
  CGSize markerSize = [marker sizeWithAttributes:markerAttributes];
  CGFloat markerX = origin.x + indent - gapWidth - markerSize.width / 2;
  CGFloat centerY = CGRectGetMidY(usedRect) + origin.y;
  CGFloat markerY = centerY - markerSize.height / 2.0;

  [marker drawAtPoint:CGPointMake(markerX, markerY)
       withAttributes:markerAttributes];
}

@end
