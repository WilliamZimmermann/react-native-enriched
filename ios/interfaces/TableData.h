#pragma once
#import <UIKit/UIKit.h>

// Payload of the EnrichedTable attribute. `rawHtml` is the original
// `<table>...</table>` HTML the parser swallowed — we round-trip it
// unchanged on save so the web stack reads back what it wrote without
// us having to faithfully reconstruct attributes / cell formatting on
// the way out. `rows` is a denormalised view used by TableAttachment
// to render the cells; `colCount` is the widest row's column count so
// short rows still draw their trailing cells as empty.
@interface TableData : NSObject <NSCopying>

@property(nonatomic, copy) NSString *rawHtml;
@property(nonatomic, strong) NSArray<NSArray<NSString *> *> *rows;
@property(nonatomic, assign) NSInteger colCount;

@end
