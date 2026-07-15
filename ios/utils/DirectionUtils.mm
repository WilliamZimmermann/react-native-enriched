#import "DirectionUtils.h"
#import "RangeUtils.h"
#import "StyleHeaders.h"

@implementation DirectionUtils

+ (NSString *)directionToString:(NSWritingDirection)direction {
  switch (direction) {
  case NSWritingDirectionLeftToRight:
    return @"ltr";
  case NSWritingDirectionRightToLeft:
    return @"rtl";
  case NSWritingDirectionNatural:
  default:
    return @"auto";
  }
}

+ (NSWritingDirection)stringToDirection:(NSString *)directionString {
  NSString *normalized = [directionString lowercaseString];

  if ([normalized isEqualToString:@"ltr"]) {
    return NSWritingDirectionLeftToRight;
  }
  if ([normalized isEqualToString:@"rtl"]) {
    return NSWritingDirectionRightToLeft;
  }

  return NSWritingDirectionNatural;
}

+ (NSWritingDirection)markerToDirection:(NSString *)marker {
  if ([marker isEqualToString:@"EnrichedDirectionLeftToRight"]) {
    return NSWritingDirectionLeftToRight;
  } else if ([marker isEqualToString:@"EnrichedDirectionRightToLeft"]) {
    return NSWritingDirectionRightToLeft;
  }
  return NSWritingDirectionNatural;
}

+ (NSString *)directionToMarker:(NSWritingDirection)direction {
  if (direction == NSWritingDirectionLeftToRight) {
    return @"EnrichedDirectionLeftToRight";
  } else if (direction == NSWritingDirectionRightToLeft) {
    return @"EnrichedDirectionRightToLeft";
  }

  return @"EnrichedDirectionNatural";
}

+ (NSString *)htmlValueForDirection:(NSWritingDirection)direction {
  switch (direction) {
  case NSWritingDirectionLeftToRight:
    return @"ltr";
  case NSWritingDirectionRightToLeft:
    return @"rtl";
  default:
    return nil;
  }
}

+ (NSWritingDirection)directionFromStyleParams:(NSString *)params {
  if (!params)
    return NSWritingDirectionNatural;

  // Require start-of-string or whitespace before `dir` so we don't match it
  // inside other attributes (e.g. `data-dir="…"`).
  NSString *pattern = @"(?:^|\\s)dir\\s*=\\s*[\"']?\\s*(rtl|ltr)";

  NSRegularExpression *regex = [NSRegularExpression
      regularExpressionWithPattern:pattern
                           options:NSRegularExpressionCaseInsensitive
                             error:nil];

  NSTextCheckingResult *match =
      [regex firstMatchInString:params
                        options:0
                          range:NSMakeRange(0, params.length)];

  if (match) {
    // rangeAtIndex:1 corresponds to the capture group (rtl|ltr)
    NSString *value =
        [[params substringWithRange:[match rangeAtIndex:1]] lowercaseString];
    return [DirectionUtils stringToDirection:value];
  }

  return NSWritingDirectionNatural;
}

@end
