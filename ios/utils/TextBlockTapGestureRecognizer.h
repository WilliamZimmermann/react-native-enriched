typedef NS_ENUM(NSInteger, TextBlockTapKind) {
  TextBlockTapKindNone = 0,
  TextBlockTapKindCheckbox,
  TextBlockTapKindTable,
};

@class EnrichedTextInputView;
@class TableCellHitResult;

@interface TextBlockTapGestureRecognizer : UITapGestureRecognizer
- (instancetype _Nonnull)initWithInput:(id _Nonnull)input
                                action:(SEL _Nonnull)action;

@property(nonatomic, weak) EnrichedTextInputView *input;

@property(nonatomic, assign, readonly) TextBlockTapKind tapKind;
@property(nonatomic, assign, readonly) NSInteger characterIndex;
// Set when tapKind == TextBlockTapKindTable: the cell the user tapped.
@property(nonatomic, strong, readonly, nullable) TableCellHitResult *tableHit;

@end
