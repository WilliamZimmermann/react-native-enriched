#pragma once
#import <UIKit/UIKit.h>

@interface EnrichedInputTextView : UITextView
@property(nonatomic, weak) id input;
// Sync `typingAttributes`' pStyle.textLists with the current paragraph's
// pStyle.textLists in text storage. Call after any list-depth mutation so
// the next character the user types inherits the correct depth — without
// this iOS reverts the paragraph's pStyle to typingAttributes' (stale)
// pStyle on the next text insertion, producing the visual "indent that
// flickers back" symptom.
- (void)katavSyncTypingAttributesToCurrentParagraph;
@end
