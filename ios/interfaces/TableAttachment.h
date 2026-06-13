#pragma once
#import "TableData.h"
#import <UIKit/UIKit.h>

// NSTextAttachment subclass that renders a TableData payload as a static
// grid image. We rasterise once at init time — the editor is read-only on
// tables for v1, so there's no benefit to a live UIView attachment and the
// image path keeps TextKit's layout / scrolling fast.
@interface TableAttachment : NSTextAttachment

@property(nonatomic, strong) TableData *tableData;

- (instancetype)initWithTableData:(TableData *)data
                     contentWidth:(CGFloat)contentWidth;

@end
