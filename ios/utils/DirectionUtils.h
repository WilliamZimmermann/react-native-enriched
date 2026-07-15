#import "DirectionEntry.h"
#import "EnrichedTextInputView.h"
#import "StyleHeaders.h"
#import <UIKit/UIKit.h>

@interface DirectionUtils : NSObject

+ (NSString *)directionToString:(NSWritingDirection)direction;

+ (NSWritingDirection)stringToDirection:(NSString *)directionString;

+ (NSString *)directionToMarker:(NSWritingDirection)direction;

+ (NSWritingDirection)markerToDirection:(NSString *)marker;

+ (NSString *)htmlValueForDirection:(NSWritingDirection)direction;

+ (NSWritingDirection)directionFromStyleParams:(NSString *)params;

@end
