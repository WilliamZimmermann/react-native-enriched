#pragma once
#import "AttributeEntry.h"
#import "EnrichedViewHost.h"
#import "StylePair.h"
#import "StyleTypeEnum.h"
#import <UIKit/UIKit.h>

@interface StyleBase : NSObject
@property(nonatomic, weak) id<EnrichedViewHost> host;
+ (StyleType)getType;
- (NSString *)getKey;
- (NSString *)getValue;
- (NSString *)getMarkerPrefix;
- (BOOL)isParagraph;
- (BOOL)needsZWS;
- (BOOL)appliesStylingToTyping;
- (instancetype)initWithHost:(id<EnrichedViewHost>)host;
- (NSRange)actualUsedRange:(NSRange)range;
- (void)toggle:(NSRange)range;
- (void)add:(NSRange)range
        withTyping:(BOOL)withTyping
    withDirtyRange:(BOOL)withDirtyRange;
- (void)add:(NSRange)range
         withValue:(NSString *)value
        withTyping:(BOOL)withTyping
    withDirtyRange:(BOOL)withDirtyRange;
- (void)remove:(NSRange)range withDirtyRange:(BOOL)withDirtyRange;
- (void)addTypingWithValue:(NSString *)value;
- (void)removeTyping;
- (BOOL)styleCondition:(id)value range:(NSRange)range;
- (BOOL)detect:(NSRange)range;
- (BOOL)any:(NSRange)range;
- (NSArray<StylePair *> *)all:(NSRange)range;
- (void)applyStyling:(NSRange)range;
- (void)applyStylingToTypingAttrs:(NSMutableDictionary *)attributes;
- (void)reapplyFromStylePair:(StylePair *)pair;
- (AttributeEntry *)getEntryIfPresent:(NSRange)range;

// List-nesting hooks. Overridden by UL/OL/Checkbox to push/pop NSTextList
// entries onto the paragraph style for the lines intersecting `range`. The
// default StyleBase impl is a no-op so non-list styles ignore Tab/Shift-Tab
// requests cleanly. Callers should hit the topmost detected list style for
// the selection — see EnrichedTextInputView's Tab handling.
//
// `indent:` raises depth by one (caller may clamp). `outdent:` lowers depth;
// when depth drops below 0 the paragraph leaves the list entirely — that
// behaviour is implemented inside the override since it requires knowing the
// family, and lives there rather than in this generic interface.
- (void)indent:(NSRange)range;
- (void)outdent:(NSRange)range;

// Current nesting depth of the (value, prefix) family for the paragraph at
// `location`. 0 = top level (first item, single NSTextList of this family).
// Returns -1 when the paragraph is not in the family. Default StyleBase
// returns -1.
- (NSInteger)depthAtLocation:(NSUInteger)location;

// Shared list-nesting helpers — call from subclass overrides of
// indent:/outdent:/depthAtLocation:. Encapsulate the (value, prefix)
// family lookup, the paragraph-style mutation loop, and the dirty-range
// notification so each list-style subclass stays a one-liner.
- (void)indentList:(NSRange)range;
- (void)outdentList:(NSRange)range;
- (NSInteger)depthForLocation:(NSUInteger)location;

// Pad the (value, prefix) NSTextList family on each paragraph in `range`
// so its count matches the count present on the saved paragraph style
// inside `pair`. Used by list-style overrides of `reapplyFromStylePair:`
// to preserve nesting depth across dirty-range re-styling: the default
// `add:` only ever pushes the first entry (dedup-aware), so without this
// the second-and-up depth levels would be lost the moment any edit
// triggers handleDirtyRangesStyling.
- (void)padListDepthInRange:(NSRange)range
              fromStylePair:(StylePair *)pair
                      value:(NSString *)value
                     prefix:(NSString *)prefix;
@end
