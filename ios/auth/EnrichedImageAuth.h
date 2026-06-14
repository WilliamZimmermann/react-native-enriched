#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Process-global bearer token + origin shared with the native image loaders.
@interface EnrichedImageAuth : NSObject
/// Returns the bearer token iff `url` matches the configured origin (scheme +
/// host + port) AND its path begins with `/api/mobile/`; nil otherwise.
+ (nullable NSString *)tokenForURL:(NSURL *)url;
@end

NS_ASSUME_NONNULL_END
