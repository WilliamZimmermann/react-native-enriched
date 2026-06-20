#import "EnrichedInputTextView.h"
#import "AlignmentUtils.h"
#import "EnrichedTextInputView.h"
#import "HtmlParser.h"
#import "LinkData.h"
#import "StringExtension.h"
#import "StyleHeaders.h"
#import "TextInsertionUtils.h"
#import "TextListsUtils.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// Maximum nesting depth allowed for lists. Past this, Tab is consumed but
// nothing happens — keeps marker widths and indents in a sensible range and
// matches the per-level numbering format's natural cycle length (1 → a → i,
// then back). 5 levels covers any realistic outline.
static const NSInteger kEnrichedListMaxDepth = 4;

// Mirrors the file-scope statics in LinkStyle.mm. Re-declared here so the
// long-press gesture handler can read the per-character link attribute
// without exposing them through a shared header. Keep these in lockstep
// with LinkStyle.mm if either side ever renames.
static NSString *const kKatavManualLinkAttr = @"EnrichedManualLink";
static NSString *const kKatavAutomaticLinkAttr = @"EnrichedAutomaticLink";

// Hold-to-open duration for links inside the editor. Apple's text-selection
// loupe fires at ~0.5s, so picking 1.0s here keeps the system gesture
// undisturbed for non-link presses and surfaces our handler only after the
// user has clearly indicated intent. Bump if accidental opens become a
// complaint, drop if users say it's sluggish.
static const NSTimeInterval kKatavLinkLongPressDuration = 1.0;

@implementation EnrichedInputTextView

// Install our long-press gesture exactly once. EnrichedTextInputView allocs
// us via `[[EnrichedInputTextView alloc] init]` (no nibs), so this routes
// through UITextView's bare-init path which lands here with frame=zero +
// nil text container. cancelsTouchesInView=NO so the system text-selection
// machinery (loupe, caret placement) keeps running underneath.
- (instancetype)initWithFrame:(CGRect)frame
                textContainer:(NSTextContainer *)textContainer {
  self = [super initWithFrame:frame textContainer:textContainer];
  if (self != nil) {
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self
                action:@selector(katavHandleLinkLongPress:)];
    lp.minimumPressDuration = kKatavLinkLongPressDuration;
    lp.cancelsTouchesInView = NO;
    [self addGestureRecognizer:lp];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  // UITextView resets contentSize during its own layout pass (triggered when
  // the frame is set on first mount). Re-schedule a relayout so our explicit
  // contentSize is applied after UITextView finishes its internal layout.
  EnrichedTextInputView *input = (EnrichedTextInputView *)_input;
  if (input != nil) {
    [input scheduleRelayoutIfNeeded];
  }
}

// UITextView places the cursor at the leading edge when a paragraph contains
// zero (or invisible) glyphs because the layout engine has nothing to align.
// We fix this by reading the active alignment and repositioning the caret rect
- (CGRect)caretRectForPosition:(UITextPosition *)position {
  CGRect rect = [super caretRectForPosition:position];
  NSUInteger idx = [self offsetFromPosition:self.beginningOfDocument
                                 toPosition:position];
  NSString *text = self.textStorage.string;
  NSRange paraRange = NSMakeRange(0, 0);
  if (idx <= text.length) {
    paraRange = [text paragraphRangeForRange:NSMakeRange(idx, 0)];
  }

  // Non-empty paragraph gets its caret drawn the usual way.
  if (paraRange.length != 0) {
    return rect;
  }

  NSParagraphStyle *pStyle =
      self.typingAttributes[NSParagraphStyleAttributeName];

  if (pStyle == nil) {
    return rect;
  }

  NSString *marker =
      [TextListsUtils firstTextListWithPrefix:@"EnrichedAlignment"
                                      inArray:pStyle.textLists]
          .markerFormat;
  NSTextAlignment alignment = [AlignmentUtils markerToAlignment:marker];
  CGFloat containerWidth = self.textContainer.size.width;

  if (alignment == NSTextAlignmentCenter) {
    rect.origin.x = (containerWidth - rect.size.width) / 2.0;
  } else if (alignment == NSTextAlignmentRight) {
    rect.origin.x = containerWidth - rect.size.width;
  }

  return rect;
}

- (void)copy:(id)sender {
  EnrichedTextInputView *typedInput = (EnrichedTextInputView *)_input;
  if (typedInput == nullptr) {
    return;
  }

  // remove zero width spaces before copying the text
  NSString *plainText = [typedInput->textView.textStorage.string
      substringWithRange:typedInput->textView.selectedRange];
  NSString *fixedPlainText =
      [plainText stringByReplacingOccurrencesOfString:@"\u200B" withString:@""];

  NSString *parsedHtml =
      [HtmlParser parseToHtmlFromRange:typedInput->textView.selectedRange
                                  host:typedInput];

  NSMutableAttributedString *attrStr = [[typedInput->textView.textStorage
      attributedSubstringFromRange:typedInput->textView.selectedRange]
      mutableCopy];
  NSRange fullAttrStrRange = NSMakeRange(0, attrStr.length);
  [attrStr.mutableString replaceOccurrencesOfString:@"\u200B"
                                         withString:@""
                                            options:0
                                              range:fullAttrStrRange];

  NSData *rtfData =
      [attrStr dataFromRange:NSMakeRange(0, attrStr.length)
          documentAttributes:@{
            NSDocumentTypeDocumentAttribute : NSRTFTextDocumentType
          }
                       error:nullptr];

  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
  [pasteboard setItems:@[ @{
                UTTypeUTF8PlainText.identifier : fixedPlainText,
                UTTypeHTML.identifier : parsedHtml,
                UTTypeRTF.identifier : rtfData
              } ]];
}

- (void)paste:(id)sender {
  EnrichedTextInputView *typedInput = (EnrichedTextInputView *)_input;
  if (typedInput == nullptr) {
    return;
  }

  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
  NSArray<NSString *> *pasteboardTypes = pasteboard.pasteboardTypes;
  NSRange currentRange = typedInput->textView.selectedRange;

  // Check the pasteboard for supported image formats. If found, save them to
  // temporary storage then emit the 'onPasteImages' event and stop processing
  // further (ignoring any HTML/Text).
  NSMutableArray<NSDictionary *> *foundImages = [NSMutableArray new];

  for (NSDictionary<NSString *, id> *item in pasteboard.items) {
    NSData *imageData = nil;
    BOOL added = NO;
    NSString *ext = nil;
    NSString *mimeType = nil;

    for (int j = 0; j < item.allKeys.count; j++) {
      if (added) {
        break;
      }

      NSString *type = item.allKeys[j];
      if ([type isEqual:UTTypeJPEG.identifier] ||
          [type isEqual:UTTypePNG.identifier] ||
          [type isEqual:UTTypeHEIC.identifier] ||
          [type isEqual:UTTypeTIFF.identifier]) {
        id value = item[type];
        if ([value isKindOfClass:[NSData class]]) {
          // raw bytes available — no re-encoding needed
          imageData = (NSData *)value;
        } else if ([value isKindOfClass:[UIImage class]]) {
          imageData = [self getDataForImageItem:(UIImage *)value type:type];
        }
      } else if ([type isEqual:UTTypeWebP.identifier] ||
                 [type isEqual:UTTypeGIF.identifier]) {
        // webp and gifs: read raw bytes directly — no re-encoding needed
        imageData = [pasteboard dataForPasteboardType:type];
      }
      if (!imageData) {
        continue;
      }

      NSDictionary *info = [self detectImageFormat:type];
      if (!info) {
        continue;
      }
      ext = info[@"ext"];
      mimeType = info[@"mime"];

      UIImage *imageInfo = [UIImage imageWithData:imageData];

      if (imageInfo) {
        NSString *path = [self saveToTempFile:imageData extension:ext];

        if (path) {
          added = YES;
          [foundImages addObject:@{
            @"uri" : path,
            @"type" : mimeType,
            @"width" : @(imageInfo.size.width),
            @"height" : @(imageInfo.size.height)
          }];
        }
      }
    }
  }

  if (foundImages.count > 0) {
    [typedInput emitOnPasteImagesEvent:foundImages];
    return;
  }

  if ([pasteboardTypes containsObject:UTTypeHTML.identifier]) {
    // we try processing the html contents

    NSString *htmlString;
    id htmlValue = [pasteboard valueForPasteboardType:UTTypeHTML.identifier];

    if ([htmlValue isKindOfClass:[NSData class]]) {
      htmlString = [[NSString alloc] initWithData:htmlValue
                                         encoding:NSUTF8StringEncoding];
    } else if ([htmlValue isKindOfClass:[NSString class]]) {
      htmlString = htmlValue;
    }

    // validate the html
    NSString *initiallyProcessedHtml =
        [typedInput->parser initiallyProcessHtml:htmlString];

    if (initiallyProcessedHtml != nullptr) {
      // valid html, let's apply it
      currentRange.length > 0
          ? [typedInput->parser replaceFromHtml:initiallyProcessedHtml
                                          range:currentRange]
          : [typedInput->parser insertFromHtml:initiallyProcessedHtml
                                      location:currentRange.location];
    } else {
      // fall back to plain text, otherwise do nothing
      [self tryHandlingPlainTextItemsIn:pasteboard
                                  range:currentRange
                                  input:typedInput];
    }
  } else {
    [self tryHandlingPlainTextItemsIn:pasteboard
                                range:currentRange
                                input:typedInput];
  }

  [typedInput anyTextMayHaveBeenModified];
}

- (NSDictionary *)detectImageFormat:(NSString *)type {
  if ([type isEqual:UTTypeJPEG.identifier]) {
    return @{@"ext" : @"jpg", @"mime" : @"image/jpeg"};
  } else if ([type isEqual:UTTypePNG.identifier]) {
    return @{@"ext" : @"png", @"mime" : @"image/png"};
  } else if ([type isEqual:UTTypeGIF.identifier]) {
    return @{@"ext" : @"gif", @"mime" : @"image/gif"};
  } else if ([type isEqual:UTTypeHEIC.identifier]) {
    return @{@"ext" : @"heic", @"mime" : @"image/heic"};
  } else if ([type isEqual:UTTypeWebP.identifier]) {
    return @{@"ext" : @"webp", @"mime" : @"image/webp"};
  } else if ([type isEqual:UTTypeTIFF.identifier]) {
    return @{@"ext" : @"tiff", @"mime" : @"image/tiff"};
  } else {
    return nil;
  }
}

- (NSData *)getDataForImageItem:(UIImage *)image type:(NSString *)type {
  if ([type isEqual:UTTypePNG.identifier]) {
    return UIImagePNGRepresentation(image);
  } else if ([type isEqual:UTTypeHEIC.identifier]) {
    return UIImageHEICRepresentation(image);
  } else {
    return UIImageJPEGRepresentation(image, 1.0);
  }
}

- (NSString *)saveToTempFile:(NSData *)data extension:(NSString *)ext {
  if (!data)
    return nil;
  NSString *fileName =
      [NSString stringWithFormat:@"%@.%@", [NSUUID UUID].UUIDString, ext];

  NSString *filePath =
      [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

  if ([data writeToFile:filePath atomically:YES]) {
    return [NSURL fileURLWithPath:filePath].absoluteString;
  }

  return nil;
}

- (void)tryHandlingPlainTextItemsIn:(UIPasteboard *)pasteboard
                              range:(NSRange)range
                              input:(EnrichedTextInputView *)input {
  NSArray *existingTypes = pasteboard.pasteboardTypes;
  NSArray *handledTypes = @[
    UTTypeUTF8PlainText.identifier, UTTypePlainText.identifier,
    UTTypeURL.identifier
  ];
  NSString *plainText;

  for (NSString *type in handledTypes) {
    if (![existingTypes containsObject:type]) {
      continue;
    }

    id value = [pasteboard valueForPasteboardType:type];

    if ([value isKindOfClass:[NSData class]]) {
      plainText = [[NSString alloc] initWithData:value
                                        encoding:NSUTF8StringEncoding];
    } else if ([value isKindOfClass:[NSString class]]) {
      plainText = (NSString *)value;
    } else if ([value isKindOfClass:[NSURL class]]) {
      plainText = [(NSURL *)value absoluteString];
    }
  }

  if (!plainText) {
    return;
  }

  range.length > 0 ? [TextInsertionUtils replaceText:plainText
                                                  at:range
                                additionalAttributes:nullptr
                                                host:input
                                       withSelection:YES]
                   : [TextInsertionUtils insertText:plainText
                                                 at:range.location
                               additionalAttributes:nullptr
                                               host:input
                                      withSelection:YES];
}

- (void)cut:(id)sender {
  EnrichedTextInputView *typedInput = (EnrichedTextInputView *)_input;
  if (typedInput == nullptr) {
    return;
  }

  [self copy:sender];
  [TextInsertionUtils replaceText:@""
                               at:typedInput->textView.selectedRange
             additionalAttributes:nullptr
                             host:typedInput
                    withSelection:YES];

  [typedInput anyTextMayHaveBeenModified];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
  if (action == @selector(paste:)) {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    // Enable Paste if clipboard has Text OR Images
    if (pasteboard.hasStrings || pasteboard.hasImages) {
      return YES;
    }
  }
  return [super canPerformAction:action withSender:sender];
}

#pragma mark - List nesting (Tab / Shift-Tab)

// Returns the list-style instance (UL / OL / Checkbox) that the paragraph at
// the current selection is in, or nil if the selection isn't inside any list.
// Used to dispatch Tab / Shift-Tab to the right family — at most one of the
// three can be active at a time because list types are mutually exclusive on
// a single paragraph.
- (StyleBase *)activeListStyleForSelection {
  EnrichedTextInputView *typedInput = (EnrichedTextInputView *)_input;
  if (typedInput == nullptr)
    return nil;

  NSDictionary<NSNumber *, id> *dict = [typedInput stylesDict];
  NSArray<NSNumber *> *candidates = @[
    @([UnorderedListStyle getType]),
    @([OrderedListStyle getType]),
    @([CheckboxListStyle getType]),
  ];
  NSRange selectedRange = self.selectedRange;
  for (NSNumber *type in candidates) {
    StyleBase *style = dict[type];
    if (style == nil)
      continue;
    if ([style detect:selectedRange])
      return style;
  }
  return nil;
}

// Register Tab and Shift-Tab as UIKeyCommands. UITextView's UITextInput
// conformance consumes \t as plain text BEFORE pressesBegan: ever fires on a
// first-responder text view, so the more-natural pressesBegan: route is a
// dead end here. UIKeyCommand is routed via the keyboard responder chain
// before text insertion, which is the supported way to intercept Tab in an
// editable text view on iOS.
- (NSArray<UIKeyCommand *> *)keyCommands {
  NSArray<UIKeyCommand *> *base = [super keyCommands] ?: @[];
  UIKeyCommand *tab =
      [UIKeyCommand keyCommandWithInput:@"\t"
                          modifierFlags:0
                                 action:@selector(katavHandleTab:)];
  UIKeyCommand *shiftTab =
      [UIKeyCommand keyCommandWithInput:@"\t"
                          modifierFlags:UIKeyModifierShift
                                 action:@selector(katavHandleShiftTab:)];
  // Hardware-keyboard undo / redo. UITextView registers typed text with its
  // built-in undoManager automatically, but the Cmd-Z shortcut isn't surfaced
  // reliably when the view is hosted in a Fabric component, so we register it
  // explicitly and route it to the same undo path as the toolbar buttons.
  //   Cmd-Z        → undo
  //   Cmd-Shift-Z  → redo  (macOS / iPadOS convention)
  //   Cmd-Y        → redo  (external Windows-keyboard convention)
  UIKeyCommand *undo =
      [UIKeyCommand keyCommandWithInput:@"z"
                          modifierFlags:UIKeyModifierCommand
                                 action:@selector(katavHandleUndo:)];
  UIKeyCommand *redoShiftZ = [UIKeyCommand
      keyCommandWithInput:@"z"
            modifierFlags:UIKeyModifierCommand | UIKeyModifierShift
                   action:@selector(katavHandleRedo:)];
  UIKeyCommand *redoY =
      [UIKeyCommand keyCommandWithInput:@"y"
                          modifierFlags:UIKeyModifierCommand
                                 action:@selector(katavHandleRedo:)];
  // Inline-format shortcuts. UITextView exposes system responders for these
  // (toggleBoldface: / toggleItalics: / toggleUnderline:), but — like Cmd-Z —
  // they aren't surfaced reliably when the view is hosted in a Fabric
  // component, so we register them explicitly and route to the same toggle
  // path as the toolbar buttons.
  //   Cmd-B → bold   Cmd-I → italic   Cmd-U → underline
  UIKeyCommand *bold =
      [UIKeyCommand keyCommandWithInput:@"b"
                          modifierFlags:UIKeyModifierCommand
                                 action:@selector(katavHandleBold:)];
  UIKeyCommand *italic =
      [UIKeyCommand keyCommandWithInput:@"i"
                          modifierFlags:UIKeyModifierCommand
                                 action:@selector(katavHandleItalic:)];
  UIKeyCommand *underline =
      [UIKeyCommand keyCommandWithInput:@"u"
                          modifierFlags:UIKeyModifierCommand
                                 action:@selector(katavHandleUnderline:)];
  // wantsPriorityOverSystemBehavior makes UIKit prefer our command over
  // built-in Tab/Shift-Tab semantics (e.g. focus traversal) when this view
  // is first responder. Available since iOS 15.
  if ([tab respondsToSelector:@selector(setWantsPriorityOverSystemBehavior:)]) {
    tab.wantsPriorityOverSystemBehavior = YES;
    shiftTab.wantsPriorityOverSystemBehavior = YES;
    undo.wantsPriorityOverSystemBehavior = YES;
    redoShiftZ.wantsPriorityOverSystemBehavior = YES;
    redoY.wantsPriorityOverSystemBehavior = YES;
    bold.wantsPriorityOverSystemBehavior = YES;
    italic.wantsPriorityOverSystemBehavior = YES;
    underline.wantsPriorityOverSystemBehavior = YES;
  }
  return [base arrayByAddingObjectsFromArray:@[
    tab, shiftTab, undo, redoShiftZ, redoY, bold, italic, underline
  ]];
}

- (void)katavHandleTab:(UIKeyCommand *)cmd {
  [self katavApplyListIndentDelta:+1];
}

- (void)katavHandleShiftTab:(UIKeyCommand *)cmd {
  [self katavApplyListIndentDelta:-1];
}

- (void)katavHandleUndo:(UIKeyCommand *)cmd {
  [self katavUndo];
}

- (void)katavHandleRedo:(UIKeyCommand *)cmd {
  [self katavRedo];
}

// Inline-format key commands. Route to the host (the manager owns the styling
// engine + state emission); the `input` ivar is the concrete
// EnrichedTextInputView host.
- (void)katavHandleBold:(UIKeyCommand *)cmd {
  [(EnrichedTextInputView *)_input katavToggleBold];
}

- (void)katavHandleItalic:(UIKeyCommand *)cmd {
  [(EnrichedTextInputView *)_input katavToggleItalic];
}

- (void)katavHandleUnderline:(UIKeyCommand *)cmd {
  [(EnrichedTextInputView *)_input katavToggleUnderline];
}

// Undo / redo backed by UITextView's built-in undo manager. Typed text is
// registered there automatically; these revert / reapply the last edit. The
// wrapper's textViewDidChange: fires on the resulting change and re-emits the
// HTML so JS autosave stays in sync.
- (void)katavUndo {
  if (self.undoManager.canUndo) {
    [self.undoManager undo];
  }
}

- (void)katavRedo {
  if (self.undoManager.canRedo) {
    [self.undoManager redo];
  }
}

// Long-press-to-open. Fires once when the user has been holding for the
// configured duration (1.0s) — we only act on the .began transition so
// repeated .changed events from finger drift don't re-open the URL. We
// honour both manual and automatic link attributes (the second one is
// applied by the regex auto-detect path on iOS). Anything we can't pass
// to UIApplication.openURL: (malformed, unknown scheme) is dropped
// silently — a broken link shouldn't surface a system alert.
- (void)katavHandleLinkLongPress:(UILongPressGestureRecognizer *)g {
  if (g.state != UIGestureRecognizerStateBegan) {
    return;
  }
  CGPoint loc = [g locationInView:self];
  UITextPosition *pos = [self closestPositionToPoint:loc];
  if (pos == nil) {
    return;
  }
  NSInteger idx = [self offsetFromPosition:self.beginningOfDocument
                                toPosition:pos];
  if (idx < 0 || (NSUInteger)idx >= self.textStorage.length) {
    return;
  }
  LinkData *link = [self.textStorage attribute:kKatavManualLinkAttr
                                       atIndex:(NSUInteger)idx
                                effectiveRange:nullptr];
  if (link == nil) {
    link = [self.textStorage attribute:kKatavAutomaticLinkAttr
                               atIndex:(NSUInteger)idx
                        effectiveRange:nullptr];
  }
  if (link == nil || link.url.length == 0) {
    return;
  }
  NSURL *url = [NSURL URLWithString:link.url];
  if (url == nil) {
    return;
  }
  UIApplication *app = [UIApplication sharedApplication];
  if (![app canOpenURL:url]) {
    return;
  }
  [app openURL:url options:@{} completionHandler:nil];
}

// delta: +1 = indent, -1 = outdent. No-op outside a list (the key command
// fired but we don't have anything to do). At depth 0 with delta -1, the
// line leaves the list entirely.
// Copy the textLists from the current paragraph in the text storage into
// `typingAttributes`. iOS uses typingAttributes' pStyle for newly-inserted
// text AND, empirically, propagates that pStyle across the whole paragraph
// on the next text mutation. If we leave typingAttributes stale after an
// indent change, the next character the user types reverts the entire
// paragraph's depth — the visual "vai e volta" symptom.
- (void)katavSyncTypingAttributesToCurrentParagraph {
  NSUInteger textLen = self.textStorage.length;
  if (textLen == 0)
    return;
  NSUInteger probe = MIN(self.selectedRange.location, textLen);
  if (probe >= textLen && probe > 0)
    probe--;
  NSRange paragraph =
      [self.textStorage.string paragraphRangeForRange:NSMakeRange(probe, 0)];
  if (paragraph.length == 0)
    return;
  if (paragraph.location >= textLen)
    return;

  NSParagraphStyle *paragraphPStyle =
      [self.textStorage attribute:NSParagraphStyleAttributeName
                          atIndex:paragraph.location
                   effectiveRange:NULL];
  if (paragraphPStyle == nil)
    return;

  NSMutableDictionary *newTyping = [self.typingAttributes mutableCopy];
  NSMutableParagraphStyle *typingPStyle =
      [newTyping[NSParagraphStyleAttributeName] mutableCopy];
  if (typingPStyle == nil) {
    typingPStyle = [[NSMutableParagraphStyle alloc] init];
  }
  typingPStyle.textLists = paragraphPStyle.textLists;
  newTyping[NSParagraphStyleAttributeName] = typingPStyle;
  self.typingAttributes = newTyping;
}

- (void)katavApplyListIndentDelta:(NSInteger)delta {
  StyleBase *style = [self activeListStyleForSelection];
  if (style == nil)
    return;

  EnrichedTextInputView *typedInput = (EnrichedTextInputView *)_input;
  NSRange selectedRange = self.selectedRange;
  NSUInteger textLen = self.textStorage.length;

  // Probe inside the containing paragraph rather than at selectedRange
  // directly. Caret-at-end-of-text or caret-at-paragraph-boundary edge cases
  // can land on a position whose pStyle belongs to a neighbouring paragraph
  // (or trigger an NSRangeException from paragraphRangeForRange:). Anchoring
  // to the paragraph start of a clamped location gives a stable read.
  NSUInteger probeLocation = MIN(selectedRange.location, textLen);
  if (probeLocation >= textLen && probeLocation > 0)
    probeLocation--;

  NSInteger depth = -1;
  if (textLen > 0) {
    NSRange probeParagraph = [self.textStorage.string
        paragraphRangeForRange:NSMakeRange(probeLocation, 0)];
    depth = [style depthAtLocation:probeParagraph.location];
  }

  if (delta < 0) {
    if (depth <= 0) {
      // At depth 0: remove from list entirely (Shift-Tab on a top-level
      // bullet produces a plain paragraph, mirroring Enter-on-empty).
      [style remove:selectedRange withDirtyRange:YES];
    } else {
      [style outdent:selectedRange];
    }
  } else {
    if (depth < kEnrichedListMaxDepth) {
      [style indent:selectedRange];
    }
    // Past the cap: no-op — the key command consumed the Tab, no \t leaks.
  }

  // Sync typing attributes BEFORE anyTextMayHaveBeenModified so the dirty
  // cycle's manageTypingAttributes preserves the new depth from typing,
  // not the old depth that was in typingAttributes before the mutation.
  [self katavSyncTypingAttributesToCurrentParagraph];

  [typedInput anyTextMayHaveBeenModified];
}

@end
