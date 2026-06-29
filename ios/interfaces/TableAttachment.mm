#import "TableAttachment.h"

// Layout constants — picked to look reasonable in the editor's default
// 17pt body font + 16pt container padding without leaning on per-theme
// theming. Bumping the cell font is the first lever if cells feel cramped.
static const CGFloat kKatavTableCellPadHorizontal = 8.0;
static const CGFloat kKatavTableCellPadVertical = 6.0;
static const CGFloat kKatavTableBorderWidth = 0.5;
static const CGFloat kKatavTableCellFontSize = 14.0;
static const CGFloat kKatavTableHeaderFontSize = 14.0;
static const CGFloat kKatavTableMinColumnWidth = 40.0;

// MARK: - Inline-HTML → attributed string (rich cell content)

static NSString *katavDecodeEntities(NSString *s) {
  s = [s stringByReplacingOccurrencesOfString:@"&nbsp;" withString:@" "];
  s = [s stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
  s = [s stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
  s = [s stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
  s = [s stringByReplacingOccurrencesOfString:@"&#39;" withString:@"'"];
  s = [s stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
  return s;
}

// Parses #rgb / #rrggbb / rgb(r,g,b[,a]) into a UIColor (nil when unparseable).
static UIColor *katavParseCssColor(NSString *value) {
  NSString *v = [value
      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if (v.length == 0) {
    return nil;
  }
  if ([v hasPrefix:@"#"]) {
    NSString *hex = [v substringFromIndex:1];
    if (hex.length == 3) {
      unichar a = [hex characterAtIndex:0];
      unichar b = [hex characterAtIndex:1];
      unichar c = [hex characterAtIndex:2];
      hex = [NSString stringWithFormat:@"%C%C%C%C%C%C", a, a, b, b, c, c];
    }
    if (hex.length >= 6) {
      unsigned int rgb = 0;
      NSScanner *s = [NSScanner scannerWithString:[hex substringToIndex:6]];
      if ([s scanHexInt:&rgb]) {
        return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                               green:((rgb >> 8) & 0xFF) / 255.0
                                blue:(rgb & 0xFF) / 255.0
                               alpha:1.0];
      }
    }
    return nil;
  }
  if ([v hasPrefix:@"rgb"]) {
    NSRange l = [v rangeOfString:@"("];
    NSRange r = [v rangeOfString:@")"];
    if (l.location != NSNotFound && r.location != NSNotFound &&
        r.location > l.location) {
      NSString *inner =
          [v substringWithRange:NSMakeRange(l.location + 1,
                                            r.location - l.location - 1)];
      NSArray<NSString *> *parts = [inner componentsSeparatedByString:@","];
      if (parts.count >= 3) {
        CGFloat alpha = parts.count >= 4 ? [parts[3] doubleValue] : 1.0;
        return [UIColor colorWithRed:[parts[0] doubleValue] / 255.0
                               green:[parts[1] doubleValue] / 255.0
                                blue:[parts[2] doubleValue] / 255.0
                               alpha:alpha];
      }
    }
  }
  return nil;
}

// Pulls a `color: …` value out of a tag's `style="…"` (or a <font color="…">).
// The leading boundary stops `background-color` from matching as a foreground
// colour (pasted Word/Docs HTML puts background-color inside spans).
static UIColor *katavColorFromTag(NSString *tag) {
  NSRegularExpression *re = [NSRegularExpression
      regularExpressionWithPattern:
          @"(?:^|[;\"'\\s])color\\s*[:=]\\s*\"?([^;\"'>]+)"
                           options:NSRegularExpressionCaseInsensitive
                             error:nil];
  NSTextCheckingResult *m = [re firstMatchInString:tag
                                           options:0
                                             range:NSMakeRange(0, tag.length)];
  if (m == nil || m.numberOfRanges < 2) {
    return nil;
  }
  return katavParseCssColor([tag substringWithRange:[m rangeAtIndex:1]]);
}

static UIFont *katavFontWithTraits(UIFont *base,
                                   UIFontDescriptorSymbolicTraits add) {
  if (add == 0) {
    return base;
  }
  UIFontDescriptorSymbolicTraits want =
      base.fontDescriptor.symbolicTraits | add;
  UIFontDescriptor *d =
      [base.fontDescriptor fontDescriptorWithSymbolicTraits:want];
  if (d == nil) {
    return base;
  }
  return [UIFont fontWithDescriptor:d size:base.pointSize];
}

// Extracts a lowercase tag name from a full tag token like `<span style=…>` or
// `</strong>`; sets *closing when it's a closing tag.
static NSString *katavTagName(NSString *tag, BOOL *closing) {
  NSString *body =
      [tag stringByTrimmingCharactersInSet:
               [NSCharacterSet characterSetWithCharactersInString:@"</> "]];
  *closing = [tag hasPrefix:@"</"];
  NSScanner *s = [NSScanner scannerWithString:body];
  NSString *name = nil;
  [s scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet]
                intoString:&name];
  return [name ?: @"" lowercaseString];
}

// Builds an attributed string from a cell's inner HTML, honouring
// bold / italic / underline / strikethrough / colour and <br> / <p> breaks.
static NSAttributedString *katavAttributedFromCellHtml(NSString *html,
                                                       UIFont *baseFont,
                                                       UIColor *baseColor,
                                                       NSParagraphStyle *para) {
  NSMutableAttributedString *out =
      [[NSMutableAttributedString alloc] initWithString:@""];
  if (html.length == 0) {
    return out;
  }
  int bold = 0, italic = 0, underline = 0, strike = 0;
  NSMutableArray<UIColor *> *colorStack = [NSMutableArray array];
  BOOL pendingBreak = NO;

  NSRegularExpression *tokRe =
      [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>|[^<]+"
                                                options:0
                                                  error:nil];
  NSArray<NSTextCheckingResult *> *tokens =
      [tokRe matchesInString:html options:0 range:NSMakeRange(0, html.length)];
  for (NSTextCheckingResult *t in tokens) {
    NSString *tok = [html substringWithRange:t.range];
    if ([tok hasPrefix:@"<"]) {
      BOOL closing = NO;
      NSString *name = katavTagName(tok, &closing);
      int delta = closing ? -1 : 1;
      if ([name isEqualToString:@"br"]) {
        pendingBreak = YES;
      } else if ([name isEqualToString:@"b"] ||
                 [name isEqualToString:@"strong"]) {
        bold = MAX(0, bold + delta);
      } else if ([name isEqualToString:@"i"] || [name isEqualToString:@"em"]) {
        italic = MAX(0, italic + delta);
      } else if ([name isEqualToString:@"u"]) {
        underline = MAX(0, underline + delta);
      } else if ([name isEqualToString:@"s"] ||
                 [name isEqualToString:@"strike"] ||
                 [name isEqualToString:@"del"]) {
        strike = MAX(0, strike + delta);
      } else if ([name isEqualToString:@"span"] ||
                 [name isEqualToString:@"font"]) {
        if (closing) {
          if (colorStack.count > 0) {
            [colorStack removeLastObject];
          }
        } else {
          UIColor *col = katavColorFromTag(tok);
          [colorStack addObject:(col ?: colorStack.lastObject ?: baseColor)];
        }
      } else if ([name isEqualToString:@"p"] || [name isEqualToString:@"div"]) {
        if (closing) {
          pendingBreak = YES;
        }
      }
      continue;
    }
    NSString *text = katavDecodeEntities(tok);
    if (text.length == 0) {
      continue;
    }
    if (pendingBreak && out.length > 0) {
      [out appendAttributedString:[[NSAttributedString alloc]
                                      initWithString:@"\n"]];
    }
    pendingBreak = NO;
    UIFontDescriptorSymbolicTraits traits = 0;
    if (bold > 0) {
      traits |= UIFontDescriptorTraitBold;
    }
    if (italic > 0) {
      traits |= UIFontDescriptorTraitItalic;
    }
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    attrs[NSFontAttributeName] = katavFontWithTraits(baseFont, traits);
    attrs[NSParagraphStyleAttributeName] = para;
    attrs[NSForegroundColorAttributeName] = colorStack.lastObject ?: baseColor;
    if (underline > 0) {
      attrs[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
    }
    if (strike > 0) {
      attrs[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
    }
    [out appendAttributedString:[[NSAttributedString alloc]
                                    initWithString:text
                                        attributes:attrs]];
  }
  return out;
}

// MARK: - Attachment

@interface TableAttachment ()
@property(nonatomic, copy, readwrite) NSArray<NSArray<NSValue *> *> *cellRects;
@property(nonatomic, copy, readwrite) NSArray<NSNumber *> *columnFractions;
@end

@implementation TableAttachment

- (instancetype)initWithTableData:(TableData *)data
                     contentWidth:(CGFloat)contentWidth {
  self = [super init];
  if (self != nil) {
    _tableData = data;
    _cellRects = @[];
    _columnFractions = @[];
    UIImage *image = [self renderImageWithContentWidth:contentWidth];
    self.image = image;
    // The bounds drive how much horizontal + vertical space TextKit
    // reserves on the line that hosts the attachment. We treat the
    // attachment as a block element: full content width, image-tall.
    self.bounds = CGRectMake(0, 0, image.size.width, image.size.height);
  }
  return self;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFrag
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex {
  return self.bounds;
}

// Reads per-column width fractions from the table's own opening tag,
// `<table ... data-col-widths="0.3,0.4,0.3">`. Returns nil when absent.
- (NSArray<NSNumber *> *)columnFractionsFromRawHtml {
  NSString *html = self.tableData.rawHtml;
  if (html.length == 0) {
    return nil;
  }
  NSRange open = [html rangeOfString:@"<table" options:NSCaseInsensitiveSearch];
  if (open.location == NSNotFound) {
    return nil;
  }
  NSRange tail = NSMakeRange(open.location, html.length - open.location);
  NSRange close = [html rangeOfString:@">" options:0 range:tail];
  if (close.location == NSNotFound) {
    return nil;
  }
  NSString *tag =
      [html substringWithRange:NSMakeRange(open.location,
                                           close.location - open.location)];
  NSRegularExpression *re = [NSRegularExpression
      regularExpressionWithPattern:@"data-col-widths\\s*=\\s*\"([^\"]+)\""
                           options:NSRegularExpressionCaseInsensitive
                             error:nil];
  NSTextCheckingResult *m = [re firstMatchInString:tag
                                           options:0
                                             range:NSMakeRange(0, tag.length)];
  if (m == nil || m.numberOfRanges < 2) {
    return nil;
  }
  NSString *list = [tag substringWithRange:[m rangeAtIndex:1]];
  NSMutableArray<NSNumber *> *fractions = [NSMutableArray array];
  for (NSString *part in [list componentsSeparatedByString:@","]) {
    double v = [part doubleValue];
    if (v > 0) {
      [fractions addObject:@(v)];
    }
  }
  return fractions.count > 0 ? fractions : nil;
}

// Renders the table to a flat UIImage. The table ALWAYS fills the editor's
// content width; columns are distributed by `data-col-widths` fractions when
// present, otherwise by their content's natural width scaled to fill. Cell
// content is drawn as rich text (bold / italic / underline / strike / colour)
// parsed from each cell's inner HTML.
- (UIImage *)renderImageWithContentWidth:(CGFloat)contentWidth {
  NSArray<NSArray<NSString *> *> *rows = self.tableData.rows ?: @[];
  NSInteger cols = self.tableData.colCount;
  if (cols <= 0) {
    cols = 0;
    for (NSArray<NSString *> *row in rows) {
      if ((NSInteger)row.count > cols)
        cols = (NSInteger)row.count;
    }
  }
  if (rows.count == 0 || cols <= 0) {
    return [self renderEmptyPlaceholderWithContentWidth:contentWidth];
  }

  UIFont *bodyFont = [UIFont systemFontOfSize:kKatavTableCellFontSize];
  UIFont *headerFont = [UIFont boldSystemFontOfSize:kKatavTableHeaderFontSize];
  UIColor *textColor = [UIColor colorWithWhite:0.13 alpha:1.0];
  NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
  para.lineBreakMode = NSLineBreakByWordWrapping;
  para.alignment = NSTextAlignmentLeft;

  // Pre-build the rich attributed string for every cell (used for both
  // measuring and drawing).
  NSMutableArray<NSMutableArray<NSAttributedString *> *> *cellText =
      [NSMutableArray arrayWithCapacity:rows.count];
  for (NSInteger r = 0; r < (NSInteger)rows.count; r++) {
    NSArray<NSString *> *row = rows[r];
    UIFont *font = (r == 0) ? headerFont : bodyFont;
    NSMutableArray<NSAttributedString *> *rowText =
        [NSMutableArray arrayWithCapacity:(NSUInteger)cols];
    for (NSInteger c = 0; c < cols; c++) {
      NSString *html = (c < (NSInteger)row.count) ? row[c] : @"";
      [rowText
          addObject:katavAttributedFromCellHtml(html, font, textColor, para)];
    }
    [cellText addObject:rowText];
  }

  // Always fill the editor's content width.
  CGFloat maxTableWidth =
      MAX(kKatavTableMinColumnWidth * cols, contentWidth - 2);
  CGFloat borders = (cols + 1) * kKatavTableBorderWidth;
  CGFloat targetContent = MAX(0, maxTableWidth - borders);

  // ---- Column widths ----
  CGFloat *colWidths = (CGFloat *)calloc((size_t)cols, sizeof(CGFloat));
  NSArray<NSNumber *> *fractions = [self columnFractionsFromRawHtml];
  if (fractions.count == (NSUInteger)cols) {
    // Explicit fractions (from resizing): distribute the content width by them.
    double total = 0;
    for (NSNumber *f in fractions)
      total += f.doubleValue;
    if (total <= 0)
      total = 1;
    for (NSInteger c = 0; c < cols; c++) {
      colWidths[c] = MAX(kKatavTableMinColumnWidth,
                         (fractions[c].doubleValue / total) * targetContent);
    }
  } else {
    // Auto: natural width per column (widest cell), then scale to fill.
    for (NSInteger r = 0; r < (NSInteger)rows.count; r++) {
      for (NSInteger c = 0; c < cols; c++) {
        CGFloat w =
            cellText[r][c].size.width + 2 * kKatavTableCellPadHorizontal;
        if (w > colWidths[c])
          colWidths[c] = w;
      }
    }
    CGFloat natural = 0;
    for (NSInteger c = 0; c < cols; c++) {
      if (colWidths[c] < kKatavTableMinColumnWidth)
        colWidths[c] = kKatavTableMinColumnWidth;
      natural += colWidths[c];
    }
    CGFloat scale = natural > 0 ? targetContent / natural : 1.0;
    for (NSInteger c = 0; c < cols; c++) {
      colWidths[c] = MAX(kKatavTableMinColumnWidth, colWidths[c] * scale);
    }
  }

  CGFloat totalContentWidth = 0;
  for (NSInteger c = 0; c < cols; c++)
    totalContentWidth += colWidths[c];
  CGFloat tableWidth = totalContentWidth + borders;

  // Report the actual rendered fractions (for the JS column-resize handles).
  NSMutableArray<NSNumber *> *outFractions =
      [NSMutableArray arrayWithCapacity:(NSUInteger)cols];
  for (NSInteger c = 0; c < cols; c++) {
    [outFractions
        addObject:@(totalContentWidth > 0 ? colWidths[c] / totalContentWidth
                                          : 1.0 / cols)];
  }
  _columnFractions = outFractions;

  // ---- Row heights ----
  CGFloat *rowHeights = (CGFloat *)calloc(rows.count, sizeof(CGFloat));
  for (NSInteger r = 0; r < (NSInteger)rows.count; r++) {
    CGFloat maxCellHeight = 0;
    for (NSInteger c = 0; c < cols; c++) {
      CGFloat innerWidth = colWidths[c] - 2 * kKatavTableCellPadHorizontal;
      if (innerWidth < 10)
        innerWidth = 10;
      CGRect bounds = [cellText[r][c]
          boundingRectWithSize:CGSizeMake(innerWidth, CGFLOAT_MAX)
                       options:NSStringDrawingUsesLineFragmentOrigin |
                               NSStringDrawingUsesFontLeading
                       context:nil];
      CGFloat h = ceil(bounds.size.height) + 2 * kKatavTableCellPadVertical;
      if (h > maxCellHeight)
        maxCellHeight = h;
    }
    if (maxCellHeight < 24)
      maxCellHeight = 24;
    rowHeights[r] = maxCellHeight;
  }

  CGFloat tableHeight = (rows.count + 1) * kKatavTableBorderWidth;
  for (NSInteger r = 0; r < (NSInteger)rows.count; r++)
    tableHeight += rowHeights[r];

  // ---- Render ----
  UIGraphicsImageRendererFormat *fmt =
      [UIGraphicsImageRendererFormat preferredFormat];
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc]
      initWithSize:CGSizeMake(tableWidth, tableHeight)
            format:fmt];
  // Captured per-cell frames (image coordinate space) for hit-testing taps.
  __block NSMutableArray<NSArray<NSValue *> *> *capturedRows =
      [NSMutableArray arrayWithCapacity:rows.count];

  UIImage *image =
      [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef cg = ctx.CGContext;
        CGContextSetFillColorWithColor(cg, UIColor.clearColor.CGColor);
        CGContextFillRect(cg, CGRectMake(0, 0, tableWidth, tableHeight));

        // Borders + header background + capture cell frames.
        CGFloat y = kKatavTableBorderWidth;
        for (NSInteger r = 0; r < (NSInteger)rows.count; r++) {
          CGFloat x = kKatavTableBorderWidth;
          NSMutableArray<NSValue *> *rowRects =
              [NSMutableArray arrayWithCapacity:(NSUInteger)cols];
          for (NSInteger c = 0; c < cols; c++) {
            CGRect cellFrame = CGRectMake(x, y, colWidths[c], rowHeights[r]);
            [rowRects addObject:[NSValue valueWithCGRect:cellFrame]];
            if (r == 0) {
              CGContextSetFillColorWithColor(
                  cg, [UIColor colorWithWhite:0.93 alpha:1.0].CGColor);
              CGContextFillRect(cg, cellFrame);
            }
            x += colWidths[c] + kKatavTableBorderWidth;
          }
          [capturedRows addObject:rowRects];
          y += rowHeights[r] + kKatavTableBorderWidth;
        }

        // Grid lines
        CGContextSetStrokeColorWithColor(
            cg, [UIColor colorWithWhite:0.6 alpha:1.0].CGColor);
        CGContextSetLineWidth(cg, kKatavTableBorderWidth);
        CGFloat yLine = 0;
        for (NSInteger r = 0; r <= (NSInteger)rows.count; r++) {
          CGContextMoveToPoint(cg, 0, yLine + kKatavTableBorderWidth / 2);
          CGContextAddLineToPoint(cg, tableWidth,
                                  yLine + kKatavTableBorderWidth / 2);
          CGContextStrokePath(cg);
          if (r < (NSInteger)rows.count)
            yLine += rowHeights[r] + kKatavTableBorderWidth;
        }
        CGFloat xLine = 0;
        for (NSInteger c = 0; c <= cols; c++) {
          CGContextMoveToPoint(cg, xLine + kKatavTableBorderWidth / 2, 0);
          CGContextAddLineToPoint(cg, xLine + kKatavTableBorderWidth / 2,
                                  tableHeight);
          CGContextStrokePath(cg);
          if (c < cols)
            xLine += colWidths[c] + kKatavTableBorderWidth;
        }

        // Rich cell text
        y = kKatavTableBorderWidth;
        for (NSInteger r = 0; r < (NSInteger)rows.count; r++) {
          CGFloat x = kKatavTableBorderWidth;
          for (NSInteger c = 0; c < cols; c++) {
            CGRect textRect = CGRectMake(
                x + kKatavTableCellPadHorizontal,
                y + kKatavTableCellPadVertical,
                MAX(1, colWidths[c] - 2 * kKatavTableCellPadHorizontal),
                MAX(1, rowHeights[r] - 2 * kKatavTableCellPadVertical));
            [cellText[r][c] drawInRect:textRect];
            x += colWidths[c] + kKatavTableBorderWidth;
          }
          y += rowHeights[r] + kKatavTableBorderWidth;
        }
      }];

  free(colWidths);
  free(rowHeights);

  _cellRects = capturedRows;

  return image;
}

// Fallback when TableData has no rows / cols — happens on an empty
// `<table></table>` round-trip and on malformed source. Renders a
// single-line "(tabela vazia)" hint so the user sees that something is
// there.
- (UIImage *)renderEmptyPlaceholderWithContentWidth:(CGFloat)contentWidth {
  CGFloat width = MIN(220, MAX(120, contentWidth - 2));
  CGFloat height = 32;
  UIGraphicsImageRendererFormat *fmt =
      [UIGraphicsImageRendererFormat preferredFormat];
  UIGraphicsImageRenderer *renderer =
      [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(width, height)
                                             format:fmt];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    CGContextRef cg = ctx.CGContext;
    CGContextSetStrokeColorWithColor(
        cg, [UIColor colorWithWhite:0.6 alpha:1.0].CGColor);
    CGContextSetLineWidth(cg, kKatavTableBorderWidth);
    CGContextStrokeRect(cg, CGRectMake(0.5, 0.5, width - 1, height - 1));
    NSString *txt = @"(tabela vazia)";
    NSDictionary *attrs = @{
      NSFontAttributeName : [UIFont systemFontOfSize:13],
      NSForegroundColorAttributeName : [UIColor colorWithWhite:0.45 alpha:1.0],
    };
    CGSize sz = [txt sizeWithAttributes:attrs];
    [txt drawAtPoint:CGPointMake((width - sz.width) / 2,
                                 (height - sz.height) / 2)
        withAttributes:attrs];
  }];
}

@end
