#pragma once
#import <UIKit/UIKit.h>

// NSTextAttachment that renders a horizontal rule (`<hr>`) as a full-width
// divider line. Unlike ImageAttachment/TableAttachment (which reserve empty
// space and overlay a UIView / rasterise a fixed preview), the rule draws
// itself natively via imageForBounds:textContainer:characterIndex: so it can
// span the live text-container width and adapt to light/dark at draw time.
@interface HorizontalRuleAttachment : NSTextAttachment
@end
