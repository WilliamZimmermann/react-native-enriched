#import "EnrichedImageAuth.h"
#import <React/RCTBridgeModule.h>

@interface EnrichedImageAuth () <RCTBridgeModule>
@end

@implementation EnrichedImageAuth

RCT_EXPORT_MODULE();

static NSString *gToken = nil;
static NSURLComponents *gOrigin = nil; // scheme + host + port of the API base
static dispatch_queue_t gQueue;

+ (void)initialize {
  if (self == [EnrichedImageAuth class]) {
    gQueue = dispatch_queue_create("com.swmansion.enriched.imageauth",
                                   DISPATCH_QUEUE_CONCURRENT);
  }
}

// JS: NativeModules.EnrichedImageAuth.setAuthHeader(token, origin)
RCT_EXPORT_METHOD(setAuthHeader
                  : (nullable NSString *)token origin
                  : (nullable NSString *)origin) {
  NSURLComponents *originComps = nil;
  if (origin.length > 0) {
    NSURLComponents *c = [NSURLComponents componentsWithString:origin];
    if (c.host.length > 0) {
      originComps = [[NSURLComponents alloc] init];
      originComps.scheme = c.scheme;
      originComps.host = c.host;
      originComps.port = c.port;
    }
  }
  dispatch_barrier_async(gQueue, ^{
    gToken = token.length > 0 ? [token copy] : nil;
    gOrigin = originComps;
  });
}

+ (nullable NSString *)tokenForURL:(NSURL *)url {
  __block NSString *token = nil;
  __block NSURLComponents *origin = nil;
  dispatch_sync(gQueue, ^{
    token = gToken;
    origin = gOrigin;
  });
  if (token == nil || origin == nil || url == nil)
    return nil;

  BOOL schemeOk =
      [url.scheme caseInsensitiveCompare:origin.scheme] == NSOrderedSame;
  BOOL hostOk = [url.host caseInsensitiveCompare:origin.host] == NSOrderedSame;
  BOOL portOk = (url.port == nil && origin.port == nil) ||
                [url.port isEqualToNumber:origin.port];
  BOOL pathOk = [url.path hasPrefix:@"/api/mobile/"];
  return (schemeOk && hostOk && portOk && pathOk) ? token : nil;
}

- (dispatch_queue_t)methodQueue {
  return dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
}
+ (BOOL)requiresMainQueueSetup {
  return NO;
}

@end
