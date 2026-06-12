#pragma once
#import <UIKit/UIKit.h>

@interface TextListsUtils : NSObject

// Appends value to the array. If exclusivePrefix is non-nil, any existing
// entry whose markerFormat starts with that prefix is evicted first, ensuring
// only one value from the family is present at a time.
+ (NSArray<NSTextList *> *_Nonnull)
      textListsByAdding:(NSString *_Nonnull)value
    withExclusivePrefix:(NSString *_Nullable)prefix
                toArray:(NSArray<NSTextList *> *_Nullable)existing;

// Returns a new array without entries whose markerFormat equals value removed
// or whose markerFormat starts with prefix
+ (NSArray<NSTextList *> *_Nonnull)
    textListsByRemoving:(NSString *_Nonnull)value
             withPrefix:(NSString *_Nullable)prefix
              fromArray:(NSArray<NSTextList *> *_Nullable)existing;

// Returns a new array without entries whose markerFormat starts with prefix
+ (NSArray<NSTextList *> *_Nonnull)
    textListsByRemovingPrefix:(NSString *_Nullable)prefix
                    fromArray:(NSArray<NSTextList *> *_Nullable)existing;

// Returns YES if any entry's markerFormat equals value exactly.
+ (BOOL)textLists:(NSArray<NSTextList *> *_Nullable)textLists
    containsValue:(NSString *_Nonnull)value;

// Returns YES if any entry's markerFormat starts with prefix.
+ (BOOL)textLists:(NSArray<NSTextList *> *_Nullable)textLists
    containsPrefix:(NSString *_Nullable)prefix;

// Returns the first entry with a markerFormat that starts with prefix,
// otherwise nil.
+ (NSTextList *_Nullable)
    firstTextListWithPrefix:(NSString *_Nullable)prefix
                    inArray:(NSArray<NSTextList *> *_Nullable)textLists;

// Number of NSTextList entries that belong to the same list family as
// (value, prefix). Family match uses prefix if non-nil (e.g. all "Enriched
// Checkbox*" variants count as one family), otherwise exact value match.
// Depth of a list item = familyCount - 1 (a freshly added list has count 1,
// depth 0). Returns 0 when the paragraph is not in that family at all.
+ (NSInteger)familyCountForValue:(NSString *_Nonnull)value
                          prefix:(NSString *_Nullable)prefix
                         inArray:(NSArray<NSTextList *> *_Nullable)existing;

// Appends one more NSTextList to the array IF the paragraph is already in
// the (value, prefix) family — i.e. raises the nesting depth by one. The
// pushed entry clones the existing family entry's markerFormat (so checkbox
// state, marker variants, etc. round-trip). No-op if not already in the
// family. Use this to implement Tab-indent inside a list.
+ (NSArray<NSTextList *> *_Nonnull)
    textListsByIncreasingDepthForValue:(NSString *_Nonnull)value
                                prefix:(NSString *_Nullable)prefix
                               inArray:
                                   (NSArray<NSTextList *> *_Nullable)existing;

// Removes the LAST NSTextList from the array that belongs to the (value,
// prefix) family — lowering the nesting depth by one. When that pop drops
// the family count to zero, the paragraph leaves the list entirely. Use this
// to implement Shift-Tab inside a list.
+ (NSArray<NSTextList *> *_Nonnull)
    textListsByDecreasingDepthForValue:(NSString *_Nonnull)value
                                prefix:(NSString *_Nullable)prefix
                               inArray:
                                   (NSArray<NSTextList *> *_Nullable)existing;

@end
