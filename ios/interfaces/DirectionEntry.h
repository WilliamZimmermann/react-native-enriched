#pragma once
#import <UIkit/UIKit.h>

@interface DirectionEntry : NSObject

@property(nonatomic, assign) NSRange range;
@property(nonatomic, assign) NSWritingDirection direction;

@end
