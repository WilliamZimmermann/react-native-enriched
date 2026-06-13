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
static const CGFloat kKatavTableMaxColumnWidth = 220.0;

@implementation TableAttachment

- (instancetype)initWithTableData:(TableData *)data
                     contentWidth:(CGFloat)contentWidth {
  self = [super init];
  if (self != nil) {
    _tableData = data;
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

// Renders the table to a flat UIImage. Computes per-column widths from the
// widest cell content (capped at kKatavTableMaxColumnWidth), wraps text
// within columns to find row heights, then draws cells in two passes: a
// background + border pass and a text pass. The header row (rows[0]) is
// drawn bold so a TipTap `<th>`-prefixed table reads naturally.
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

  // Maximum table width is capped by the editor's content width minus a
  // small breathing margin so the grid doesn't kiss the editor's right
  // edge.
  CGFloat maxTableWidth = MAX(0, contentWidth - 2);

  // ---- Column widths ----
  // Start each column at its widest cell's natural width (capped) and
  // shrink uniformly afterwards if the total exceeds maxTableWidth.
  CGFloat *colWidths = (CGFloat *)calloc((size_t)cols, sizeof(CGFloat));
  for (NSInteger r = 0; r < (NSInteger)rows.count; r++) {
    NSArray<NSString *> *row = rows[r];
    UIFont *font = (r == 0) ? headerFont : bodyFont;
    for (NSInteger c = 0; c < cols; c++) {
      NSString *txt = (c < (NSInteger)row.count) ? row[c] : @"";
      CGFloat width =
          [txt sizeWithAttributes:@{NSFontAttributeName : font}].width +
          2 * kKatavTableCellPadHorizontal;
      if (width > colWidths[c])
        colWidths[c] = width;
    }
  }
  for (NSInteger c = 0; c < cols; c++) {
    if (colWidths[c] < kKatavTableMinColumnWidth)
      colWidths[c] = kKatavTableMinColumnWidth;
    if (colWidths[c] > kKatavTableMaxColumnWidth)
      colWidths[c] = kKatavTableMaxColumnWidth;
  }
  CGFloat totalContentWidth = 0;
  for (NSInteger c = 0; c < cols; c++)
    totalContentWidth += colWidths[c];
  CGFloat tableWidth = totalContentWidth + (cols + 1) * kKatavTableBorderWidth;
  if (tableWidth > maxTableWidth) {
    CGFloat scale = (maxTableWidth - (cols + 1) * kKatavTableBorderWidth) /
                    totalContentWidth;
    for (NSInteger c = 0; c < cols; c++) {
      colWidths[c] *= scale;
      if (colWidths[c] < kKatavTableMinColumnWidth)
        colWidths[c] = kKatavTableMinColumnWidth;
    }
    totalContentWidth = 0;
    for (NSInteger c = 0; c < cols; c++)
      totalContentWidth += colWidths[c];
    tableWidth = totalContentWidth + (cols + 1) * kKatavTableBorderWidth;
  }

  // ---- Row heights ----
  // For each row, ask each cell for the height required to wrap its text
  // inside its column's width; the row takes the max across cells.
  CGFloat *rowHeights = (CGFloat *)calloc(rows.count, sizeof(CGFloat));
  for (NSInteger r = 0; r < (NSInteger)rows.count; r++) {
    NSArray<NSString *> *row = rows[r];
    UIFont *font = (r == 0) ? headerFont : bodyFont;
    CGFloat maxCellHeight = 0;
    for (NSInteger c = 0; c < cols; c++) {
      NSString *txt = (c < (NSInteger)row.count) ? row[c] : @"";
      CGFloat innerWidth = colWidths[c] - 2 * kKatavTableCellPadHorizontal;
      if (innerWidth < 10)
        innerWidth = 10;
      CGRect r =
          [txt boundingRectWithSize:CGSizeMake(innerWidth, CGFLOAT_MAX)
                            options:NSStringDrawingUsesLineFragmentOrigin |
                                    NSStringDrawingUsesFontLeading
                         attributes:@{NSFontAttributeName : font}
                            context:nil];
      CGFloat h = ceil(r.size.height) + 2 * kKatavTableCellPadVertical;
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
  UIImage *image =
      [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef cg = ctx.CGContext;
        // Background — clear (the parent text container's background shows).
        CGContextSetFillColorWithColor(cg, UIColor.clearColor.CGColor);
        CGContextFillRect(cg, CGRectMake(0, 0, tableWidth, tableHeight));

        // Borders + cell backgrounds
        CGFloat y = kKatavTableBorderWidth;
        for (NSInteger r = 0; r < (NSInteger)rows.count; r++) {
          CGFloat x = kKatavTableBorderWidth;
          for (NSInteger c = 0; c < cols; c++) {
            CGRect cellFrame = CGRectMake(x, y, colWidths[c], rowHeights[r]);
            if (r == 0) {
              // Header row tint — soft fill so it's distinguishable without
              // committing to a theme color.
              CGContextSetFillColorWithColor(
                  cg, [UIColor colorWithWhite:0.93 alpha:1.0].CGColor);
              CGContextFillRect(cg, cellFrame);
            }
            x += colWidths[c] + kKatavTableBorderWidth;
          }
          y += rowHeights[r] + kKatavTableBorderWidth;
        }

        // Grid lines — thin gray
        CGContextSetStrokeColorWithColor(
            cg, [UIColor colorWithWhite:0.6 alpha:1.0].CGColor);
        CGContextSetLineWidth(cg, kKatavTableBorderWidth);

        // Outer + horizontal lines
        CGFloat yLine = 0;
        for (NSInteger r = 0; r <= (NSInteger)rows.count; r++) {
          CGContextMoveToPoint(cg, 0, yLine + kKatavTableBorderWidth / 2);
          CGContextAddLineToPoint(cg, tableWidth,
                                  yLine + kKatavTableBorderWidth / 2);
          CGContextStrokePath(cg);
          if (r < (NSInteger)rows.count)
            yLine += rowHeights[r] + kKatavTableBorderWidth;
        }
        // Vertical lines
        CGFloat xLine = 0;
        for (NSInteger c = 0; c <= cols; c++) {
          CGContextMoveToPoint(cg, xLine + kKatavTableBorderWidth / 2, 0);
          CGContextAddLineToPoint(cg, xLine + kKatavTableBorderWidth / 2,
                                  tableHeight);
          CGContextStrokePath(cg);
          if (c < cols)
            xLine += colWidths[c] + kKatavTableBorderWidth;
        }

        // Cell text
        y = kKatavTableBorderWidth;
        NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
        para.lineBreakMode = NSLineBreakByWordWrapping;
        para.alignment = NSTextAlignmentLeft;
        for (NSInteger r = 0; r < (NSInteger)rows.count; r++) {
          NSArray<NSString *> *row = rows[r];
          UIFont *font = (r == 0) ? headerFont : bodyFont;
          CGFloat x = kKatavTableBorderWidth;
          for (NSInteger c = 0; c < cols; c++) {
            NSString *txt = (c < (NSInteger)row.count) ? row[c] : @"";
            CGRect textRect = CGRectMake(
                x + kKatavTableCellPadHorizontal,
                y + kKatavTableCellPadVertical,
                MAX(1, colWidths[c] - 2 * kKatavTableCellPadHorizontal),
                MAX(1, rowHeights[r] - 2 * kKatavTableCellPadVertical));
            NSDictionary *attrs = @{
              NSFontAttributeName : font,
              NSForegroundColorAttributeName : [UIColor colorWithWhite:0.13
                                                                 alpha:1.0],
              NSParagraphStyleAttributeName : para,
            };
            [txt drawInRect:textRect withAttributes:attrs];
            x += colWidths[c] + kKatavTableBorderWidth;
          }
          y += rowHeights[r] + kKatavTableBorderWidth;
        }
      }];

  free(colWidths);
  free(rowHeights);

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
