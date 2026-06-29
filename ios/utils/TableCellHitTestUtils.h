#pragma once
#import <UIKit/UIKit.h>

@class EnrichedTextInputView;

NS_ASSUME_NONNULL_BEGIN

// Result of mapping a tap to a table cell. All indices are 0-based.
@interface TableCellHitResult : NSObject
// Location of the table's Object Replacement Character in the text storage.
@property(nonatomic, assign) NSInteger charIndex;
// Ordinal of the tapped table among all tables in the document (0-based) —
// lets JS target the Nth `<table>` in the serialized HTML.
@property(nonatomic, assign) NSInteger tableIndex;
@property(nonatomic, assign) NSInteger row;
@property(nonatomic, assign) NSInteger col;
// The tapped cell's frame in the text view's own coordinate space (points).
@property(nonatomic, assign) CGRect cellRect;
// The table's rendered column widths as fractions of the total (sum ≈ 1).
@property(nonatomic, copy, nullable) NSArray<NSNumber *> *columnFractions;
@end

// Maps a tap point to the table cell underneath it, mirroring
// CheckboxHitTestUtils. Returns nil when the point isn't over a table cell.
@interface TableCellHitTestUtils : NSObject
+ (nullable TableCellHitResult *)
    hitTestTableCellAtPoint:(CGPoint)point
                    inInput:(EnrichedTextInputView *)input;
// Resolves a specific cell by table ordinal + row/col (no tap), reporting its
// rect the same way hitTest does. Used for keyboard navigation (Tab → next
// cell). Returns nil when the table or cell doesn't exist.
+ (nullable TableCellHitResult *)cellAtTableIndex:(NSInteger)tableIndex
                                              row:(NSInteger)row
                                              col:(NSInteger)col
                                          inInput:
                                              (EnrichedTextInputView *)input;
@end

NS_ASSUME_NONNULL_END
