#pragma once
#import "TableData.h"
#import <UIKit/UIKit.h>

// NSTextAttachment subclass that renders a TableData payload as a static
// grid image. We rasterise once at init time — the editor is read-only on
// tables for v1, so there's no benefit to a live UIView attachment and the
// image path keeps TextKit's layout / scrolling fast.
@interface TableAttachment : NSTextAttachment

@property(nonatomic, strong) TableData *tableData;

// Per-cell frames in the rendered image's coordinate space (origin = image
// top-left), captured during rasterisation. Outer array is rows, inner is
// columns: `cellRects[r][c]` is an NSValue-wrapped CGRect. Empty until the
// image is rendered (and empty for the "(tabela vazia)" placeholder). Used by
// TableCellHitTestUtils to map a tap to the cell the user touched so the
// tablet can open an inline cell editor over it.
@property(nonatomic, copy, readonly) NSArray<NSArray<NSValue *> *> *cellRects;

// The actual rendered column widths as fractions of the total (sum ≈ 1),
// whether they came from `data-col-widths` or content-based auto-sizing. JS
// reads these (via onTableCellTap) to place per-column resize handles.
@property(nonatomic, copy, readonly) NSArray<NSNumber *> *columnFractions;

- (instancetype)initWithTableData:(TableData *)data
                     contentWidth:(CGFloat)contentWidth;

@end
