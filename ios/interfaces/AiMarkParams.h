#pragma once
#import <UIKit/UIKit.h>

// Sidecar payload stored under the AI-mark attribute key (one instance per
// marked range), mirroring how MentionParams backs the mention attribute.
// Both aiSuggestion and aiFlag share this shape; `explanation` is empty for
// suggestions and `model` is empty for flags. `status` is "pending" |
// "accepted" and is mutated in place when a mark is accepted.
@interface AiMarkParams : NSObject
@property NSString *aiId;
@property NSString *status;
@property NSString *model;
@property NSString *explanation;
@end
