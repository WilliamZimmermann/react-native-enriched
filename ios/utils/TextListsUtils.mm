#import "TextListsUtils.h"

@implementation TextListsUtils

+ (NSArray<NSTextList *> *_Nonnull)
      textListsByAdding:(NSString *_Nonnull)value
    withExclusivePrefix:(NSString *_Nullable)prefix
                toArray:(NSArray<NSTextList *> *_Nullable)existing {
  NSMutableArray<NSTextList *> *updated =
      existing ? [existing mutableCopy] : [NSMutableArray array];

  if (prefix != nil) {
    NSUInteger i = 0;
    while (i < updated.count) {
      if ([updated[i].markerFormat hasPrefix:prefix]) {
        if ([updated[i].markerFormat isEqualToString:value]) {
          return updated;
        }
        [updated removeObjectAtIndex:i];
      } else {
        i++;
      }
    }
  } else {
    for (NSTextList *list in updated) {
      if ([list.markerFormat isEqualToString:value]) {
        return updated;
      }
    }
  }

  [updated addObject:[[NSTextList alloc] initWithMarkerFormat:value options:0]];
  return updated;
}

+ (NSArray<NSTextList *> *_Nonnull)
    textListsByRemoving:(NSString *_Nonnull)value
             withPrefix:(NSString *_Nullable)prefix
              fromArray:(NSArray<NSTextList *> *_Nullable)existing {
  NSMutableArray<NSTextList *> *updated = [NSMutableArray array];
  for (NSTextList *list in existing) {
    if ((prefix == nullptr && ![list.markerFormat isEqualToString:value]) ||
        (prefix != nullptr && ![list.markerFormat hasPrefix:prefix])) {
      [updated addObject:list];
    }
  }
  return updated;
}

+ (NSArray<NSTextList *> *_Nonnull)
    textListsByRemovingPrefix:(NSString *_Nullable)prefix
                    fromArray:(NSArray<NSTextList *> *_Nullable)existing {
  NSMutableArray<NSTextList *> *updated = [NSMutableArray array];
  for (NSTextList *list in existing) {
    if (![list.markerFormat hasPrefix:prefix]) {
      [updated addObject:list];
    }
  }
  return updated;
}

+ (BOOL)textLists:(NSArray<NSTextList *> *_Nullable)textLists
    containsValue:(NSString *_Nonnull)value {
  for (NSTextList *list in textLists) {
    if ([list.markerFormat isEqualToString:value]) {
      return YES;
    }
  }
  return NO;
}

+ (BOOL)textLists:(NSArray<NSTextList *> *_Nullable)textLists
    containsPrefix:(NSString *_Nullable)prefix {
  for (NSTextList *list in textLists) {
    if ([list.markerFormat hasPrefix:prefix]) {
      return YES;
    }
  }
  return NO;
}

+ (NSTextList *_Nullable)
    firstTextListWithPrefix:(NSString *_Nullable)prefix
                    inArray:(NSArray<NSTextList *> *_Nullable)textLists {
  for (NSTextList *list in textLists) {
    if ([list.markerFormat hasPrefix:prefix]) {
      return list;
    }
  }
  return nil;
}

+ (BOOL)markerFormat:(NSString *_Nonnull)format
    matchesFamilyValue:(NSString *_Nonnull)value
                prefix:(NSString *_Nullable)prefix {
  if (prefix != nil) {
    return [format hasPrefix:prefix];
  }
  return [format isEqualToString:value];
}

+ (NSInteger)familyCountForValue:(NSString *_Nonnull)value
                          prefix:(NSString *_Nullable)prefix
                         inArray:(NSArray<NSTextList *> *_Nullable)existing {
  NSInteger count = 0;
  for (NSTextList *list in existing) {
    if ([self markerFormat:list.markerFormat
            matchesFamilyValue:value
                        prefix:prefix]) {
      count++;
    }
  }
  return count;
}

+ (NSArray<NSTextList *> *_Nonnull)
    textListsByIncreasingDepthForValue:(NSString *_Nonnull)value
                                prefix:(NSString *_Nullable)prefix
                               inArray:
                                   (NSArray<NSTextList *> *_Nullable)existing {
  NSInteger family = [self familyCountForValue:value
                                        prefix:prefix
                                       inArray:existing];
  if (family == 0) {
    // Paragraph isn't in this list family — nothing to indent.
    return existing != nil ? [existing copy] : @[];
  }

  // Reuse the existing markerFormat so subtype state (e.g. checkbox checked)
  // is preserved at the new depth.
  NSString *clonedFormat = value;
  if (prefix != nil) {
    NSTextList *first = [self firstTextListWithPrefix:prefix inArray:existing];
    if (first != nil)
      clonedFormat = first.markerFormat;
  }

  NSMutableArray<NSTextList *> *updated = [existing mutableCopy];
  [updated addObject:[[NSTextList alloc] initWithMarkerFormat:clonedFormat
                                                      options:0]];
  return updated;
}

+ (NSArray<NSTextList *> *_Nonnull)
    textListsByDecreasingDepthForValue:(NSString *_Nonnull)value
                                prefix:(NSString *_Nullable)prefix
                               inArray:
                                   (NSArray<NSTextList *> *_Nullable)existing {
  if (existing == nil || existing.count == 0)
    return @[];

  // Drop the LAST entry that belongs to this family. Other entries (outer
  // family wrappers — not currently modelled, but future-proof) stay put.
  NSMutableArray<NSTextList *> *updated = [existing mutableCopy];
  for (NSInteger i = (NSInteger)updated.count - 1; i >= 0; i--) {
    if ([self markerFormat:updated[i].markerFormat
            matchesFamilyValue:value
                        prefix:prefix]) {
      [updated removeObjectAtIndex:i];
      break;
    }
  }
  return updated;
}

@end
