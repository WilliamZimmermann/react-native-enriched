#import "EnrichedTextInputView.h"
#import "AlignmentUtils.h"
#import "AttachmentLayoutUtils.h"
#import "CoreText/CoreText.h"
#import "DotReplacementUtils.h"
#import "HtmlParser.h"
#import "ImageAttachment.h"
#import "KeyboardUtils.h"
#import "LayoutManagerExtension.h"
#import "ParagraphAttributesUtils.h"
#import "RCTFabricComponentsPlugins.h"
#import "ShortcutsUtils.h"
#import "StringExtension.h"
#import "StyleHeaders.h"
#import "StyleUtils.h"
#import "TableCellHitTestUtils.h"
#import "TextBlockTapGestureRecognizer.h"
#import "TextInsertionUtils.h"
#import "UIView+React.h"
#import "WordsUtils.h"
#import "ZeroWidthSpaceUtils.h"
#import <React/RCTConversions.h>
#import <ReactNativeEnriched/EnrichedTextInputViewComponentDescriptor.h>
#import <ReactNativeEnriched/EventEmitters.h>
#import <ReactNativeEnriched/Props.h>
#import <ReactNativeEnriched/RCTComponentViewHelpers.h>
#import <folly/dynamic.h>
#import <react/utils/ManagedObjectWrapper.h>

#define GET_STYLE_STATE(TYPE_ENUM)                                             \
  {                                                                            \
    .isActive = [self isStyleActive:TYPE_ENUM],                                \
    .isBlocking = [self isStyle:TYPE_ENUM activeInMap:blockingStyles],         \
    .isConflicting = [self isStyle:TYPE_ENUM activeInMap:conflictingStyles]    \
  }

using namespace facebook::react;

// Joins column-width fractions into the "0.3,0.4,0.3" wire form for the
// onTableCellTap event (empty string when there are none).
static std::string katavFractionsString(NSArray<NSNumber *> *fractions) {
  if (fractions.count == 0) {
    return std::string();
  }
  NSMutableArray<NSString *> *parts = [NSMutableArray array];
  for (NSNumber *f in fractions) {
    [parts addObject:[NSString stringWithFormat:@"%.4f", f.doubleValue]];
  }
  return std::string([[parts componentsJoinedByString:@","] UTF8String]);
}

@interface EnrichedTextInputView () <
    RCTEnrichedTextInputViewViewProtocol, UITextViewDelegate,
    UIGestureRecognizerDelegate, NSTextStorageDelegate, NSObject>

@end

@implementation EnrichedTextInputView {
  EnrichedTextInputViewShadowNode::ConcreteState::Shared _state;
  int _componentViewHeightUpdateCounter;
  NSMutableSet<NSNumber *> *_activeStyles;
  NSMutableSet<NSNumber *> *_blockedStyles;
  LinkData *_recentlyActiveLinkData;
  NSRange _recentlyActiveLinkRange;
  NSString *_recentInputString;
  MentionParams *_recentlyActiveMentionParams;
  NSRange _recentlyActiveMentionRange;
  NSString *_recentlyEmittedHtml;
  BOOL _emitHtml;
  UILabel *_placeholderLabel;
  UIColor *_placeholderColor;
  BOOL _emitFocusBlur;
  BOOL _emitTextChange;
  NSMutableDictionary<NSValue *, UIImageView *> *_attachmentViews;
  NSArray<NSDictionary *> *_contextMenuItems;
  BOOL _disableNativeSelectionMenu;
  NSString *_submitBehavior;
  NSDictionary<NSAttributedStringKey, id> *_capturedAttributesBeforeChange;
  NSString *_recentlyEmittedAlignment;
  // The configured selection tint (from the selectionColor prop). Restored when
  // the selection isn't over a highlight; see textViewDidChangeSelection:.
  UIColor *_baseSelectionTintColor;
}

@synthesize blockEmitting = blockEmitting;

// MARK: - Component utils

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<
      EnrichedTextInputViewComponentDescriptor>();
}

Class<RCTComponentViewProtocol> EnrichedTextInputViewCls(void) {
  return EnrichedTextInputView.class;
}

+ (BOOL)shouldBeRecycled {
  return NO;
}

// MARK: - EnrichedViewHost protocol

- (UITextView *)textView {
  return textView;
}

- (EnrichedConfig *)config {
  return config;
}

- (NSDictionary<NSNumber *, id> *)stylesDict {
  return stylesDict;
}

- (InputAttributesManager *)attributesManager {
  return attributesManager;
}

- (NSMutableDictionary<NSNumber *, NSArray<NSNumber *> *> *)conflictingStyles {
  return conflictingStyles;
}

- (NSMutableDictionary<NSNumber *, NSArray<NSNumber *> *> *)blockingStyles {
  return blockingStyles;
}

- (NSMutableDictionary<NSAttributedStringKey, id> *)defaultTypingAttributes {
  return defaultTypingAttributes;
}

// MARK: - Init

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps =
        std::make_shared<const EnrichedTextInputViewProps>();
    _props = defaultProps;
    [self setDefaults];
    [self setupTextView];
    [self setupPlaceholderLabel];
    self.contentView = textView;
  }
  return self;
}

- (void)setDefaults {
  _componentViewHeightUpdateCounter = 0;
  _activeStyles = [[NSMutableSet alloc] init];
  _blockedStyles = [[NSMutableSet alloc] init];
  _recentlyActiveLinkRange = NSMakeRange(0, 0);
  _recentlyActiveMentionRange = NSMakeRange(0, 0);
  _recentlyEmittedAlignment = @"left";
  _recentInputString = @"";
  _recentlyEmittedHtml = @"<html>\n<p></p>\n</html>";
  _emitHtml = NO;
  blockEmitting = NO;
  _emitFocusBlur = YES;
  _emitTextChange = NO;
  dotReplacementRange = nullptr;

  defaultTypingAttributes =
      [[NSMutableDictionary<NSAttributedStringKey, id> alloc] init];

  stylesDict = [StyleUtils stylesDictForHost:self isInput:YES];
  conflictingStyles = [[StyleUtils conflictMap] mutableCopy];
  blockingStyles = [[StyleUtils blockingMap] mutableCopy];

  parser = [[InputHtmlParser alloc] initWithInput:self];
  _attachmentViews = [[NSMutableDictionary alloc] init];
  attributesManager = [[InputAttributesManager alloc] initWithInput:self];
}

- (void)setupTextView {
  textView = [[EnrichedInputTextView alloc] init];
  textView.backgroundColor = UIColor.clearColor;
  textView.textContainerInset = UIEdgeInsetsMake(0, 0, 0, 0);
  textView.textContainer.lineFragmentPadding = 0;
  textView.delegate = self;
  textView.input = self;
  textView.layoutManager.input = self;
  textView.textStorage.delegate = self;

  // Note-taking editor — autocorrect / spell-check / smart punctuation all
  // interact badly with rich-text formatting: they trigger silent
  // replacement events (UITextInput inserts a corrected word, which goes
  // through our typing-attributes path and can revert paragraph styling)
  // and they "underline" misspelled words in a way that visually clashes
  // with our own underline mark. Predictive bar adds clutter on iPad. The
  // user can still spell-check from the system context menu when they want
  // to.
  textView.autocorrectionType = UITextAutocorrectionTypeNo;
  textView.spellCheckingType = UITextSpellCheckingTypeNo;
  textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
  textView.smartDashesType = UITextSmartDashesTypeNo;
  textView.smartQuotesType = UITextSmartQuotesTypeNo;
  textView.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
  if (@available(iOS 17.0, *)) {
    textView.inlinePredictionType = UITextInlinePredictionTypeNo;
  }

  textView.adjustsFontForContentSizeCategory = YES;
  [textView addGestureRecognizer:[[TextBlockTapGestureRecognizer alloc]
                                     initWithInput:self
                                            action:@selector(onTextBlockTap:)]];
}

- (void)setupPlaceholderLabel {
  _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
  _placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [textView addSubview:_placeholderLabel];
  [NSLayoutConstraint activateConstraints:@[
    [_placeholderLabel.leadingAnchor
        constraintEqualToAnchor:textView.leadingAnchor],
    [_placeholderLabel.widthAnchor
        constraintEqualToAnchor:textView.widthAnchor],
    [_placeholderLabel.topAnchor constraintEqualToAnchor:textView.topAnchor],
    [_placeholderLabel.bottomAnchor
        constraintEqualToAnchor:textView.bottomAnchor]
  ]];
  _placeholderLabel.lineBreakMode = NSLineBreakByTruncatingTail;
  _placeholderLabel.text = @"";
  _placeholderLabel.hidden = YES;
  _placeholderLabel.adjustsFontForContentSizeCategory = YES;
}

// MARK: - Props

- (void)updateProps:(Props::Shared const &)props
           oldProps:(Props::Shared const &)oldProps {
  const auto &oldViewProps =
      *std::static_pointer_cast<EnrichedTextInputViewProps const>(_props);
  const auto &newViewProps =
      *std::static_pointer_cast<EnrichedTextInputViewProps const>(props);
  BOOL isFirstMount = NO;
  BOOL stylePropChanged = NO;

  // initial config
  if (config == nullptr) {
    isFirstMount = YES;
    config = [[EnrichedConfig alloc] init];
  }

  // any style prop changes:
  // firstly we create the new config for the changes

  EnrichedConfig *newConfig = [config copy];

  if (newViewProps.color != oldViewProps.color) {
    if (isColorMeaningful(newViewProps.color)) {
      UIColor *uiColor = RCTUIColorFromSharedColor(newViewProps.color);
      [newConfig setPrimaryColor:uiColor];
    } else {
      [newConfig setPrimaryColor:nullptr];
    }
    stylePropChanged = YES;
  }

  if (newViewProps.fontSize != oldViewProps.fontSize) {
    if (newViewProps.fontSize) {
      NSNumber *fontSize = @(newViewProps.fontSize);
      [newConfig setPrimaryFontSize:fontSize];
    } else {
      [newConfig setPrimaryFontSize:nullptr];
    }
    stylePropChanged = YES;
  }

  if (newViewProps.lineHeight != oldViewProps.lineHeight) {
    [newConfig setPrimaryLineHeight:newViewProps.lineHeight];
    stylePropChanged = YES;
  }

  if (newViewProps.fontWeight != oldViewProps.fontWeight) {
    if (!newViewProps.fontWeight.empty()) {
      [newConfig
          setPrimaryFontWeight:[NSString
                                   fromCppString:newViewProps.fontWeight]];
    } else {
      [newConfig setPrimaryFontWeight:nullptr];
    }
    stylePropChanged = YES;
  }

  if (newViewProps.fontFamily != oldViewProps.fontFamily) {
    if (!newViewProps.fontFamily.empty()) {
      [newConfig
          setPrimaryFontFamily:[NSString
                                   fromCppString:newViewProps.fontFamily]];
    } else {
      [newConfig setPrimaryFontFamily:nullptr];
    }
    stylePropChanged = YES;
  }

  // rich text style

  if (newViewProps.htmlStyle.h1.fontSize !=
      oldViewProps.htmlStyle.h1.fontSize) {
    [newConfig setH1FontSize:newViewProps.htmlStyle.h1.fontSize];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.h1.bold != oldViewProps.htmlStyle.h1.bold) {
    [newConfig setH1Bold:newViewProps.htmlStyle.h1.bold];

    // Update style blocks and conflicts for bold
    if (newViewProps.htmlStyle.h1.bold) {
      [StyleUtils addStyleBlock:H1 to:Bold forHost:self];
      [StyleUtils addStyleConflict:Bold to:H1 forHost:self];
    } else {
      [StyleUtils removeStyleBlock:H1 from:Bold forHost:self];
      [StyleUtils removeStyleConflict:Bold from:H1 forHost:self];
    }

    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.h2.fontSize !=
      oldViewProps.htmlStyle.h2.fontSize) {
    [newConfig setH2FontSize:newViewProps.htmlStyle.h2.fontSize];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.h2.bold != oldViewProps.htmlStyle.h2.bold) {
    [newConfig setH2Bold:newViewProps.htmlStyle.h2.bold];

    // Update style blocks and conflicts for bold
    if (newViewProps.htmlStyle.h2.bold) {
      [StyleUtils addStyleBlock:H2 to:Bold forHost:self];
      [StyleUtils addStyleConflict:Bold to:H2 forHost:self];
    } else {
      [StyleUtils removeStyleBlock:H2 from:Bold forHost:self];
      [StyleUtils removeStyleConflict:Bold from:H2 forHost:self];
    }

    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.h3.fontSize !=
      oldViewProps.htmlStyle.h3.fontSize) {
    [newConfig setH3FontSize:newViewProps.htmlStyle.h3.fontSize];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.h3.bold != oldViewProps.htmlStyle.h3.bold) {
    [newConfig setH3Bold:newViewProps.htmlStyle.h3.bold];

    // Update style blocks and conflicts for bold
    if (newViewProps.htmlStyle.h3.bold) {
      [StyleUtils addStyleBlock:H3 to:Bold forHost:self];
      [StyleUtils addStyleConflict:Bold to:H3 forHost:self];
    } else {
      [StyleUtils removeStyleBlock:H3 from:Bold forHost:self];
      [StyleUtils removeStyleConflict:Bold from:H3 forHost:self];
    }

    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.h4.fontSize !=
      oldViewProps.htmlStyle.h4.fontSize) {
    [newConfig setH4FontSize:newViewProps.htmlStyle.h4.fontSize];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.h4.bold != oldViewProps.htmlStyle.h4.bold) {
    [newConfig setH4Bold:newViewProps.htmlStyle.h4.bold];

    // Update style blocks and conflicts for bold
    if (newViewProps.htmlStyle.h4.bold) {
      [StyleUtils addStyleBlock:H4 to:Bold forHost:self];
      [StyleUtils addStyleConflict:Bold to:H4 forHost:self];
    } else {
      [StyleUtils removeStyleBlock:H4 from:Bold forHost:self];
      [StyleUtils removeStyleConflict:Bold from:H4 forHost:self];
    }

    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.h5.fontSize !=
      oldViewProps.htmlStyle.h5.fontSize) {
    [newConfig setH5FontSize:newViewProps.htmlStyle.h5.fontSize];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.h5.bold != oldViewProps.htmlStyle.h5.bold) {
    [newConfig setH5Bold:newViewProps.htmlStyle.h5.bold];

    // Update style blocks and conflicts for bold
    if (newViewProps.htmlStyle.h5.bold) {
      [StyleUtils addStyleBlock:H5 to:Bold forHost:self];
      [StyleUtils addStyleConflict:Bold to:H5 forHost:self];
    } else {
      [StyleUtils removeStyleBlock:H5 from:Bold forHost:self];
      [StyleUtils removeStyleConflict:Bold from:H5 forHost:self];
    }

    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.h6.fontSize !=
      oldViewProps.htmlStyle.h6.fontSize) {
    [newConfig setH6FontSize:newViewProps.htmlStyle.h6.fontSize];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.h6.bold != oldViewProps.htmlStyle.h6.bold) {
    [newConfig setH6Bold:newViewProps.htmlStyle.h6.bold];

    // Update style blocks and conflicts for bold
    if (newViewProps.htmlStyle.h6.bold) {
      [StyleUtils addStyleBlock:H6 to:Bold forHost:self];
      [StyleUtils addStyleConflict:Bold to:H6 forHost:self];
    } else {
      [StyleUtils removeStyleBlock:H6 from:Bold forHost:self];
      [StyleUtils removeStyleConflict:Bold from:H6 forHost:self];
    }

    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.blockquote.borderColor !=
      oldViewProps.htmlStyle.blockquote.borderColor) {
    if (isColorMeaningful(newViewProps.htmlStyle.blockquote.borderColor)) {
      [newConfig setBlockquoteBorderColor:RCTUIColorFromSharedColor(
                                              newViewProps.htmlStyle.blockquote
                                                  .borderColor)];
      stylePropChanged = YES;
    }
  }

  if (newViewProps.htmlStyle.blockquote.borderWidth !=
      oldViewProps.htmlStyle.blockquote.borderWidth) {
    [newConfig
        setBlockquoteBorderWidth:newViewProps.htmlStyle.blockquote.borderWidth];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.blockquote.gapWidth !=
      oldViewProps.htmlStyle.blockquote.gapWidth) {
    [newConfig
        setBlockquoteGapWidth:newViewProps.htmlStyle.blockquote.gapWidth];
    stylePropChanged = YES;
  }

  // since this prop defaults to undefined on JS side, we need to force set the
  // value on first mount
  if (newViewProps.htmlStyle.blockquote.color !=
          oldViewProps.htmlStyle.blockquote.color ||
      isFirstMount) {
    if (isColorMeaningful(newViewProps.htmlStyle.blockquote.color)) {
      [newConfig
          setBlockquoteColor:RCTUIColorFromSharedColor(
                                 newViewProps.htmlStyle.blockquote.color)];
    } else {
      [newConfig setBlockquoteColor:[newConfig primaryColor]];
    }
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.code.color != oldViewProps.htmlStyle.code.color) {
    if (isColorMeaningful(newViewProps.htmlStyle.code.color)) {
      [newConfig setInlineCodeFgColor:RCTUIColorFromSharedColor(
                                          newViewProps.htmlStyle.code.color)];
      stylePropChanged = YES;
    }
  }

  if (newViewProps.htmlStyle.code.backgroundColor !=
      oldViewProps.htmlStyle.code.backgroundColor) {
    if (isColorMeaningful(newViewProps.htmlStyle.code.backgroundColor)) {
      [newConfig setInlineCodeBgColor:RCTUIColorFromSharedColor(
                                          newViewProps.htmlStyle.code
                                              .backgroundColor)];
      stylePropChanged = YES;
    }
  }

  if (newViewProps.htmlStyle.ol.gapWidth !=
      oldViewProps.htmlStyle.ol.gapWidth) {
    [newConfig setOrderedListGapWidth:newViewProps.htmlStyle.ol.gapWidth];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.ol.marginLeft !=
      oldViewProps.htmlStyle.ol.marginLeft) {
    [newConfig setOrderedListMarginLeft:newViewProps.htmlStyle.ol.marginLeft];
    stylePropChanged = YES;
  }

  // since this prop defaults to undefined on JS side, we need to force set the
  // value on first mount
  if (newViewProps.htmlStyle.ol.markerFontWeight !=
          oldViewProps.htmlStyle.ol.markerFontWeight ||
      isFirstMount) {
    if (!newViewProps.htmlStyle.ol.markerFontWeight.empty()) {
      [newConfig
          setOrderedListMarkerFontWeight:
              [NSString
                  fromCppString:newViewProps.htmlStyle.ol.markerFontWeight]];
    } else {
      [newConfig setOrderedListMarkerFontWeight:[newConfig primaryFontWeight]];
    }
    stylePropChanged = YES;
  }

  // since this prop defaults to undefined on JS side, we need to force set the
  // value on first mount
  if (newViewProps.htmlStyle.ol.markerColor !=
          oldViewProps.htmlStyle.ol.markerColor ||
      isFirstMount) {
    if (isColorMeaningful(newViewProps.htmlStyle.ol.markerColor)) {
      [newConfig
          setOrderedListMarkerColor:RCTUIColorFromSharedColor(
                                        newViewProps.htmlStyle.ol.markerColor)];
    } else {
      [newConfig setOrderedListMarkerColor:[newConfig primaryColor]];
    }
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.ul.bulletColor !=
      oldViewProps.htmlStyle.ul.bulletColor) {
    if (isColorMeaningful(newViewProps.htmlStyle.ul.bulletColor)) {
      [newConfig setUnorderedListBulletColor:RCTUIColorFromSharedColor(
                                                 newViewProps.htmlStyle.ul
                                                     .bulletColor)];
      stylePropChanged = YES;
    }
  }

  if (newViewProps.htmlStyle.ul.bulletSize !=
      oldViewProps.htmlStyle.ul.bulletSize) {
    [newConfig setUnorderedListBulletSize:newViewProps.htmlStyle.ul.bulletSize];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.ul.gapWidth !=
      oldViewProps.htmlStyle.ul.gapWidth) {
    [newConfig setUnorderedListGapWidth:newViewProps.htmlStyle.ul.gapWidth];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.ul.marginLeft !=
      oldViewProps.htmlStyle.ul.marginLeft) {
    [newConfig setUnorderedListMarginLeft:newViewProps.htmlStyle.ul.marginLeft];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.a.color != oldViewProps.htmlStyle.a.color) {
    if (isColorMeaningful(newViewProps.htmlStyle.a.color)) {
      [newConfig setLinkColor:RCTUIColorFromSharedColor(
                                  newViewProps.htmlStyle.a.color)];
      stylePropChanged = YES;
    }
  }

  if (newViewProps.htmlStyle.codeblock.color !=
      oldViewProps.htmlStyle.codeblock.color) {
    if (isColorMeaningful(newViewProps.htmlStyle.codeblock.color)) {
      [newConfig
          setCodeBlockFgColor:RCTUIColorFromSharedColor(
                                  newViewProps.htmlStyle.codeblock.color)];
      stylePropChanged = YES;
    }
  }

  if (newViewProps.htmlStyle.codeblock.backgroundColor !=
      oldViewProps.htmlStyle.codeblock.backgroundColor) {
    if (isColorMeaningful(newViewProps.htmlStyle.codeblock.backgroundColor)) {
      [newConfig setCodeBlockBgColor:RCTUIColorFromSharedColor(
                                         newViewProps.htmlStyle.codeblock
                                             .backgroundColor)];
      stylePropChanged = YES;
    }
  }

  if (newViewProps.htmlStyle.codeblock.borderRadius !=
      oldViewProps.htmlStyle.codeblock.borderRadius) {
    [newConfig
        setCodeBlockBorderRadius:newViewProps.htmlStyle.codeblock.borderRadius];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.ulCheckbox.boxSize !=
      oldViewProps.htmlStyle.ulCheckbox.boxSize) {
    [newConfig
        setCheckboxListBoxSize:newViewProps.htmlStyle.ulCheckbox.boxSize];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.ulCheckbox.gapWidth !=
      oldViewProps.htmlStyle.ulCheckbox.gapWidth) {
    [newConfig
        setCheckboxListGapWidth:newViewProps.htmlStyle.ulCheckbox.gapWidth];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.ulCheckbox.marginLeft !=
      oldViewProps.htmlStyle.ulCheckbox.marginLeft) {
    [newConfig
        setCheckboxListMarginLeft:newViewProps.htmlStyle.ulCheckbox.marginLeft];
    stylePropChanged = YES;
  }

  if (newViewProps.htmlStyle.ulCheckbox.boxColor !=
      oldViewProps.htmlStyle.ulCheckbox.boxColor) {
    if (isColorMeaningful(newViewProps.htmlStyle.ulCheckbox.boxColor)) {
      [newConfig setCheckboxListBoxColor:RCTUIColorFromSharedColor(
                                             newViewProps.htmlStyle.ulCheckbox
                                                 .boxColor)];
      stylePropChanged = YES;
    }
  }

  if (newViewProps.htmlStyle.a.textDecorationLine !=
      oldViewProps.htmlStyle.a.textDecorationLine) {
    NSString *objcString =
        [NSString fromCppString:newViewProps.htmlStyle.a.textDecorationLine];
    if ([objcString isEqualToString:DecorationUnderline]) {
      [newConfig setLinkDecorationLine:DecorationUnderline];
    } else {
      // both DecorationNone and a different, wrong value gets a DecorationNone
      // here
      [newConfig setLinkDecorationLine:DecorationNone];
    }
    stylePropChanged = YES;
  }

  if (newViewProps.scrollEnabled != oldViewProps.scrollEnabled ||
      textView.scrollEnabled != newViewProps.scrollEnabled) {
    [textView setScrollEnabled:newViewProps.scrollEnabled];
  }

  if (newViewProps.allowFontScaling != oldViewProps.allowFontScaling) {
    [newConfig setAllowFontScaling:newViewProps.allowFontScaling];
    stylePropChanged = YES;
  }

  folly::dynamic oldMentionStyle = oldViewProps.htmlStyle.mention;
  folly::dynamic newMentionStyle = newViewProps.htmlStyle.mention;
  if (oldMentionStyle != newMentionStyle) {
    bool newSingleProps = NO;

    for (const auto &obj : newMentionStyle.items()) {
      if (obj.second.isInt() || obj.second.isString()) {
        // we are in just a single MentionStyleProps object
        newSingleProps = YES;
        break;
      } else if (obj.second.isObject()) {
        // we are in map of indicators to MentionStyleProps
        newSingleProps = NO;
        break;
      }
    }

    if (newSingleProps) {
      [newConfig setMentionStyleProps:
                     [MentionStyleProps
                         getSinglePropsFromFollyDynamic:newMentionStyle]];
    } else {
      [newConfig setMentionStyleProps:
                     [MentionStyleProps
                         getComplexPropsFromFollyDynamic:newMentionStyle]];
    }

    stylePropChanged = YES;
  }

  if (stylePropChanged) {
    // all the text needs to be rebuilt
    // we get the current html using old config, then switch to new config and
    // replace text using the html this way, the newest config attributes are
    // being used!

    // the html needs to be generated using the old config
    NSString *currentHtml = [HtmlParser
        parseToHtmlFromRange:NSMakeRange(0, textView.textStorage.string.length)
                        host:self];
    // we want to preserve the selection between props changes
    NSRange prevSelectedRange = textView.selectedRange;

    // now set the new config
    config = newConfig;

    // fill the typing attributes with style props
    defaultTypingAttributes[NSForegroundColorAttributeName] =
        [config primaryColor];
    defaultTypingAttributes[NSFontAttributeName] = [config primaryFont];
    defaultTypingAttributes[NSUnderlineColorAttributeName] =
        [config primaryColor];
    defaultTypingAttributes[NSStrikethroughColorAttributeName] =
        [config primaryColor];
    NSMutableParagraphStyle *defaultPStyle =
        [[NSMutableParagraphStyle alloc] init];
    defaultPStyle.minimumLineHeight = [config scaledPrimaryLineHeight];
    defaultTypingAttributes[NSParagraphStyleAttributeName] = defaultPStyle;

    // no emitting during styles reload
    blockEmitting = YES;

    // make sure everything is sound in the html
    NSString *initiallyProcessedHtml =
        [parser initiallyProcessHtml:currentHtml];
    if (initiallyProcessedHtml != nullptr) {
      [parser replaceWholeFromHtml:initiallyProcessedHtml];
    }

    blockEmitting = NO;

    textView.typingAttributes = defaultTypingAttributes;
    textView.selectedRange = prevSelectedRange;

    // make sure the newest lineHeight is applied
    [self refreshLineHeight];
    // update the placeholder as well
    [self refreshPlaceholderLabelStyles];
  }

  // editable
  if (newViewProps.editable != textView.editable) {
    textView.editable = newViewProps.editable;
  }

  // useHtmlNormalizer
  if (newViewProps.useHtmlNormalizer != oldViewProps.useHtmlNormalizer) {
    useHtmlNormalizer = newViewProps.useHtmlNormalizer;
  }

  // textShortcuts
  bool textShortcutsChanged =
      newViewProps.textShortcuts.size() != oldViewProps.textShortcuts.size();
  if (!textShortcutsChanged) {
    for (size_t i = 0; i < newViewProps.textShortcuts.size(); i++) {
      const auto &newItem = newViewProps.textShortcuts[i];
      const auto &oldItem = oldViewProps.textShortcuts[i];
      if (newItem.trigger != oldItem.trigger ||
          newItem.style != oldItem.style) {
        textShortcutsChanged = true;
        break;
      }
    }
  }

  if (textShortcutsChanged) {
    NSMutableArray *shortcuts = [NSMutableArray new];
    for (const auto &item : newViewProps.textShortcuts) {
      [shortcuts addObject:@{
        @"trigger" : [NSString fromCppString:item.trigger],
        @"style" : [NSString fromCppString:item.style],
      }];
    }
    textShortcuts = shortcuts;
  }

  // default value - must be set before placeholder to make sure it correctly
  // shows on first mount
  if (newViewProps.defaultValue != oldViewProps.defaultValue) {
    NSString *newDefaultValue =
        [NSString fromCppString:newViewProps.defaultValue];

    NSString *initiallyProcessedHtml =
        [parser initiallyProcessHtml:newDefaultValue];
    if (initiallyProcessedHtml == nullptr) {
      // just plain text
      textView.text = newDefaultValue;
    } else {
      // we've got some seemingly proper html
      [parser replaceWholeFromHtml:initiallyProcessedHtml];
    }
    textView.selectedRange = NSRange(textView.textStorage.string.length, 0);
  }

  // placeholderTextColor
  if (newViewProps.placeholderTextColor != oldViewProps.placeholderTextColor) {
    // some real color
    if (isColorMeaningful(newViewProps.placeholderTextColor)) {
      _placeholderColor =
          RCTUIColorFromSharedColor(newViewProps.placeholderTextColor);
    } else {
      _placeholderColor = nullptr;
    }
    [self refreshPlaceholderLabelStyles];
  }

  // placeholder
  if (newViewProps.placeholder != oldViewProps.placeholder) {
    _placeholderLabel.text = [NSString fromCppString:newViewProps.placeholder];
    [self refreshPlaceholderLabelStyles];
    // additionally show placeholder on first mount if it should be there
    if (isFirstMount && textView.text.length == 0) {
      [self setPlaceholderLabelShown:YES];
    }
  }

  // mention indicators
  auto mismatchPair = std::mismatch(newViewProps.mentionIndicators.begin(),
                                    newViewProps.mentionIndicators.end(),
                                    oldViewProps.mentionIndicators.begin(),
                                    oldViewProps.mentionIndicators.end());
  if (mismatchPair.first != newViewProps.mentionIndicators.end() ||
      mismatchPair.second != oldViewProps.mentionIndicators.end()) {
    NSMutableSet<NSNumber *> *newIndicators = [[NSMutableSet alloc] init];
    for (const std::string &item : newViewProps.mentionIndicators) {
      if (item.length() == 1) {
        [newIndicators addObject:@(item[0])];
      }
    }
    [config setMentionIndicators:newIndicators];
  }

  // linkRegex
  LinkRegexConfig *oldRegexConfig =
      [[LinkRegexConfig alloc] initWithLinkRegexProp:oldViewProps.linkRegex];
  LinkRegexConfig *newRegexConfig =
      [[LinkRegexConfig alloc] initWithLinkRegexProp:newViewProps.linkRegex];
  if (![newRegexConfig isEqualToConfig:oldRegexConfig]) {
    [config setLinkRegexConfig:newRegexConfig];
  }

  // selection color sets both selection and cursor on iOS (just as in RN)
  if (newViewProps.selectionColor != oldViewProps.selectionColor) {
    if (isColorMeaningful(newViewProps.selectionColor)) {
      textView.tintColor =
          RCTUIColorFromSharedColor(newViewProps.selectionColor);
    } else {
      textView.tintColor = nullptr;
    }
    // Remember the configured tint so textViewDidChangeSelection: can restore
    // it after temporarily swapping to the over-highlight selection color.
    _baseSelectionTintColor = textView.tintColor;
  }

  if (newViewProps.returnKeyType != oldViewProps.returnKeyType) {
    NSString *str = [NSString fromCppString:newViewProps.returnKeyType];

    textView.returnKeyType =
        [KeyboardUtils getUIReturnKeyTypeFromReturnKeyType:str];
  }

  if (newViewProps.submitBehavior != oldViewProps.submitBehavior) {
    _submitBehavior = [NSString fromCppString:newViewProps.submitBehavior];
  }

  // autoCapitalize
  if (newViewProps.autoCapitalize != oldViewProps.autoCapitalize) {
    NSString *str = [NSString fromCppString:newViewProps.autoCapitalize];
    if ([str isEqualToString:@"none"]) {
      textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    } else if ([str isEqualToString:@"sentences"]) {
      textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    } else if ([str isEqualToString:@"words"]) {
      textView.autocapitalizationType = UITextAutocapitalizationTypeWords;
    } else if ([str isEqualToString:@"characters"]) {
      textView.autocapitalizationType =
          UITextAutocapitalizationTypeAllCharacters;
    }

    // textView needs to be refocused on autocapitalization type change and we
    // don't want to emit these events
    if ([textView isFirstResponder]) {
      _emitFocusBlur = NO;
      [textView reactBlur];
      [textView reactFocus];
      _emitFocusBlur = YES;
    }
  }

  // isOnChangeHtmlSet
  _emitHtml = newViewProps.isOnChangeHtmlSet;

  // isOnChangeTextSet
  _emitTextChange = newViewProps.isOnChangeTextSet;

  // contextMenuItems
  bool contextMenuChanged = newViewProps.contextMenuItems.size() !=
                            oldViewProps.contextMenuItems.size();
  if (!contextMenuChanged) {
    for (size_t i = 0; i < newViewProps.contextMenuItems.size(); i++) {
      if (newViewProps.contextMenuItems[i].text !=
          oldViewProps.contextMenuItems[i].text) {
        contextMenuChanged = true;
        break;
      }
    }
  }
  if (contextMenuChanged) {
    NSMutableArray<NSString *> *items = [NSMutableArray new];
    for (const auto &item : newViewProps.contextMenuItems) {
      [items addObject:[NSString fromCppString:item.text]];
    }
    _contextMenuItems = [items copy];
  }

  // disableNativeSelectionMenu
  if (newViewProps.disableNativeSelectionMenu !=
      oldViewProps.disableNativeSelectionMenu) {
    _disableNativeSelectionMenu = newViewProps.disableNativeSelectionMenu;
  }

  [super updateProps:props oldProps:oldProps];
  // run the changes callback
  [self anyTextMayHaveBeenModified];

  // autofocus - needs to be done at the very end
  if (isFirstMount && newViewProps.autoFocus) {
    [textView reactFocus];
  }
}

- (void)setPlaceholderLabelShown:(BOOL)shown {
  if (shown) {
    [self refreshPlaceholderLabelStyles];
    _placeholderLabel.hidden = NO;
  } else {
    _placeholderLabel.hidden = YES;
  }
}

- (void)refreshPlaceholderLabelStyles {
  NSMutableDictionary *newAttrs = [defaultTypingAttributes mutableCopy];
  if (_placeholderColor != nullptr) {
    newAttrs[NSForegroundColorAttributeName] = _placeholderColor;
  }

  // Get the current active alignment in input
  NSParagraphStyle *currentTypingPara =
      textView.typingAttributes[NSParagraphStyleAttributeName];
  NSTextAlignment activeAlignment =
      currentTypingPara ? currentTypingPara.alignment : NSTextAlignmentNatural;
  NSMutableParagraphStyle *placeholderPStyle =
      [newAttrs[NSParagraphStyleAttributeName] mutableCopy];
  if (!placeholderPStyle) {
    placeholderPStyle = [[NSMutableParagraphStyle alloc] init];
  }
  placeholderPStyle.alignment = activeAlignment;
  newAttrs[NSParagraphStyleAttributeName] = placeholderPStyle;

  NSAttributedString *newAttrStr =
      [[NSAttributedString alloc] initWithString:_placeholderLabel.text
                                      attributes:newAttrs];
  _placeholderLabel.attributedText = newAttrStr;
}

- (void)refreshLineHeight {
  [textView.textStorage
      enumerateAttribute:NSParagraphStyleAttributeName
                 inRange:NSMakeRange(0, textView.textStorage.string.length)
                 options:0
              usingBlock:^(id _Nullable value, NSRange range,
                           BOOL *_Nonnull stop) {
                NSMutableParagraphStyle *pStyle =
                    [(NSParagraphStyle *)value mutableCopy];
                if (pStyle == nil)
                  return;
                pStyle.minimumLineHeight = [config scaledPrimaryLineHeight];
                [textView.textStorage addAttribute:NSParagraphStyleAttributeName
                                             value:pStyle
                                             range:range];
              }];
}

// MARK: - Measuring and states

- (CGSize)measureSize:(CGFloat)maxWidth {
  // copy the the whole attributed string
  NSMutableAttributedString *currentStr = [[NSMutableAttributedString alloc]
      initWithAttributedString:textView.textStorage];

  // edge case: empty input should still be of a height of a single line, so we
  // add a mock "I" character
  if ([currentStr length] == 0) {
    [currentStr
        appendAttributedString:[[NSAttributedString alloc]
                                   initWithString:@"I"
                                       attributes:textView.typingAttributes]];
  }

  // edge case: input with only a zero width space should still be of a height
  // of a single line, so we add a mock "I" character
  if ([currentStr length] == 1 &&
      [[currentStr.string substringWithRange:NSMakeRange(0, 1)]
          isEqualToString:@"\u200B"]) {
    [currentStr
        appendAttributedString:[[NSAttributedString alloc]
                                   initWithString:@"I"
                                       attributes:textView.typingAttributes]];
  }

  // edge case: trailing newlines aren't counted towards height calculations, so
  // we add a mock "I" character
  if (currentStr.length > 0) {
    unichar lastChar =
        [currentStr.string characterAtIndex:currentStr.length - 1];
    if ([[NSCharacterSet newlineCharacterSet] characterIsMember:lastChar]) {
      [currentStr
          appendAttributedString:[[NSAttributedString alloc]
                                     initWithString:@"I"
                                         attributes:defaultTypingAttributes]];
    }
  }

  CGRect boundingBox =
      [currentStr boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                               options:NSStringDrawingUsesLineFragmentOrigin |
                                       NSStringDrawingUsesFontLeading
                               context:nullptr];

  return CGSizeMake(maxWidth, ceil(boundingBox.size.height));
}

// make sure the newest state is kept in _state property
- (void)updateState:(State::Shared const &)state
           oldState:(State::Shared const &)oldState {
  _state = std::static_pointer_cast<
      const EnrichedTextInputViewShadowNode::ConcreteState>(state);

  // first render with all the needed stuff already defined (state and
  // componentView) so we need to run a single height calculation for any
  // initial values
  if (oldState == nullptr) {
    [self tryUpdatingHeight];
  }
}

- (void)tryUpdatingHeight {
  if (_state == nullptr) {
    return;
  }
  _componentViewHeightUpdateCounter++;
  auto selfRef = wrapManagedObjectWeakly(self);
  _state->updateState(
      EnrichedTextInputViewState(_componentViewHeightUpdateCounter, selfRef));
}

// MARK: - Active styles

- (void)tryUpdatingActiveStyles {
  // style updates are emitted only if something differs from the previously
  // active styles
  BOOL updateNeeded = NO;

  // active styles are kept in a separate set until we're sure they can be
  // emitted
  NSMutableSet *newActiveStyles = [_activeStyles mutableCopy];

  // currently blocked styles are subject to change (e.g. bold being blocked by
  // headings might change in reaction to prop change) so they also are kept
  // separately
  NSMutableSet *newBlockedStyles = [_blockedStyles mutableCopy];

  // data for onLinkDetected event
  LinkData *detectedLinkData;
  NSRange detectedLinkRange = NSMakeRange(0, 0);
  BOOL shouldClearLink = NO;

  // data for onMentionDetected event
  MentionParams *detectedMentionParams = nullptr;
  NSRange detectedMentionRange = NSMakeRange(0, 0);
  BOOL shouldClearMention = NO;

  for (NSNumber *type in stylesDict) {
    StyleBase *style = stylesDict[type];

    BOOL wasActive = [newActiveStyles containsObject:type];
    BOOL isActive = [style detect:textView.selectedRange];

    BOOL wasBlocked = [newBlockedStyles containsObject:type];
    BOOL isBlocked = [self isStyle:(StyleType)[type integerValue]
                       activeInMap:blockingStyles];

    if (wasActive != isActive) {
      updateNeeded = YES;
      if (isActive) {
        [newActiveStyles addObject:type];
      } else {
        [newActiveStyles removeObject:type];
      }
    }

    // blocked state change for a style also needs an update
    if (wasBlocked != isBlocked) {
      updateNeeded = YES;
      if (isBlocked) {
        [newBlockedStyles addObject:type];
      } else {
        [newBlockedStyles removeObject:type];
      }
    }

    // onLinkDetected event
    if ([type intValue] == [LinkStyle getType]) {
      if (isActive) {
        // get the link data
        LinkData *candidateLinkData;
        NSRange candidateLinkRange = NSMakeRange(0, 0);
        LinkStyle *linkStyleClass =
            (LinkStyle *)stylesDict[@([LinkStyle getType])];
        if (linkStyleClass != nullptr) {
          candidateLinkData =
              [linkStyleClass getLinkDataAt:textView.selectedRange.location];
          candidateLinkRange = [linkStyleClass
              getFullLinkRangeAt:textView.selectedRange.location];
        }

        if (wasActive == NO) {
          // we changed selection from non-link to a link
          detectedLinkData = candidateLinkData;
          detectedLinkRange = candidateLinkRange;
        } else if (![_recentlyActiveLinkData
                       isEqualToLinkData:candidateLinkData] ||
                   !NSEqualRanges(_recentlyActiveLinkRange,
                                  candidateLinkRange)) {
          // we changed selection from one link to the other or modified
          // current link's text
          detectedLinkData = candidateLinkData;
          detectedLinkRange = candidateLinkRange;
        }
      } else if (wasActive) {
        shouldClearLink = YES;
      }
    }

    // onMentionDetected event
    if ([type intValue] == [MentionStyle getType]) {
      if (isActive) {
        // get mention data
        MentionParams *candidateMentionParams;
        NSRange candidateMentionRange = NSMakeRange(0, 0);
        MentionStyle *mentionStyleClass =
            (MentionStyle *)stylesDict[@([MentionStyle getType])];
        if (mentionStyleClass != nullptr) {
          candidateMentionParams = [mentionStyleClass
              getMentionParamsAt:textView.selectedRange.location];
          candidateMentionRange = [mentionStyleClass
              getFullMentionRangeAt:textView.selectedRange.location];
        }

        if (wasActive == NO) {
          // selection was changed from a non-mention to a mention
          detectedMentionParams = candidateMentionParams;
          detectedMentionRange = candidateMentionRange;
        } else if (![_recentlyActiveMentionParams.text
                       isEqualToString:candidateMentionParams.text] ||
                   ![_recentlyActiveMentionParams.attributes
                       isEqualToString:candidateMentionParams.attributes] ||
                   !NSEqualRanges(_recentlyActiveMentionRange,
                                  candidateMentionRange)) {
          // selection changed from one mention to another
          detectedMentionParams = candidateMentionParams;
          detectedMentionRange = candidateMentionRange;
        }
      } else if (wasActive) {
        shouldClearMention = YES;
      }
    }
  }

  // detect alignment change
  AlignmentStyle *alignmentStyle = stylesDict[@([AlignmentStyle getType])];
  NSString *currentAlignment = [alignmentStyle getStyleState];
  if (![currentAlignment isEqualToString:_recentlyEmittedAlignment]) {
    updateNeeded = YES;
  }

  if (updateNeeded) {
    auto emitter = [self getEventEmitter];
    if (emitter != nullptr) {
      // update activeStyles and blockedStyles only if emitter is available
      _activeStyles = newActiveStyles;
      _blockedStyles = newBlockedStyles;
      _recentlyEmittedAlignment = currentAlignment;

      ImageStyle *imageStyleForCaption =
          (ImageStyle *)stylesDict[@([ImageStyle getType])];
      ImageData *selectedImageData =
          [imageStyleForCaption getImageDataAt:textView.selectedRange.location];
      NSString *selectedImageCaption =
          (selectedImageData != nullptr && selectedImageData.caption != nil)
              ? selectedImageData.caption
              : @"";

      emitter->onChangeState(
          {.bold = GET_STYLE_STATE([BoldStyle getType]),
           .italic = GET_STYLE_STATE([ItalicStyle getType]),
           .underline = GET_STYLE_STATE([UnderlineStyle getType]),
           .strikeThrough = GET_STYLE_STATE([StrikethroughStyle getType]),
           .inlineCode = GET_STYLE_STATE([InlineCodeStyle getType]),
           .link = GET_STYLE_STATE([LinkStyle getType]),
           .mention = GET_STYLE_STATE([MentionStyle getType]),
           .h1 = GET_STYLE_STATE([H1Style getType]),
           .h2 = GET_STYLE_STATE([H2Style getType]),
           .h3 = GET_STYLE_STATE([H3Style getType]),
           .h4 = GET_STYLE_STATE([H4Style getType]),
           .h5 = GET_STYLE_STATE([H5Style getType]),
           .h6 = GET_STYLE_STATE([H6Style getType]),
           .unorderedList = GET_STYLE_STATE([UnorderedListStyle getType]),
           .orderedList = GET_STYLE_STATE([OrderedListStyle getType]),
           .blockQuote = GET_STYLE_STATE([BlockQuoteStyle getType]),
           .codeBlock = GET_STYLE_STATE([CodeBlockStyle getType]),
           .image = GET_STYLE_STATE([ImageStyle getType]),
           .checkboxList = GET_STYLE_STATE([CheckboxListStyle getType]),
           .highlight = GET_STYLE_STATE([HighlightStyle getType]),
           .alignment = [currentAlignment UTF8String],
           .selectedImageCaption = [selectedImageCaption UTF8String]});
    }
  }

  if (detectedLinkData != nullptr) {
    // emit onLinkeDetected event
    [self emitOnLinkDetectedEvent:detectedLinkData range:detectedLinkRange];
  } else if (shouldClearLink) {
    LinkData *emptyLinkData = [[LinkData alloc] init];
    emptyLinkData.text = @"";
    emptyLinkData.url = @"";
    [self emitOnLinkDetectedEvent:emptyLinkData range:NSMakeRange(0, 0)];
  }

  if (detectedMentionParams != nullptr) {
    // emit onMentionDetected event
    [self emitOnMentionDetectedEvent:detectedMentionParams.text
                           indicator:detectedMentionParams.indicator
                          attributes:detectedMentionParams.attributes];

    _recentlyActiveMentionParams = detectedMentionParams;
    _recentlyActiveMentionRange = detectedMentionRange;
  } else if (shouldClearMention) {
    [self emitOnMentionDetectedEvent:@"" indicator:@"" attributes:@"{}"];
    _recentlyActiveMentionParams = nullptr;
    _recentlyActiveMentionRange = NSMakeRange(0, 0);
  }
  // emit onChangeHtml event if needed
  [self tryEmittingOnChangeHtmlEvent];
}

- (bool)isStyleActive:(StyleType)type {
  return [_activeStyles containsObject:@(type)];
}

- (bool)isStyle:(StyleType)type activeInMap:(NSDictionary *)styleMap {
  NSArray *relatedStyles = styleMap[@(type)];

  if (!relatedStyles) {
    return false;
  }

  for (NSNumber *style in relatedStyles) {
    if ([_activeStyles containsObject:style]) {
      return true;
    }
  }

  return false;
}

- (bool)textInputShouldReturn {
  return [_submitBehavior isEqualToString:@"blurAndSubmit"];
}

- (bool)textInputShouldSubmitOnReturn {
  return [_submitBehavior isEqualToString:@"blurAndSubmit"] ||
         [_submitBehavior isEqualToString:@"submit"];
}

// MARK: - Native commands and events

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args {
  if ([commandName isEqualToString:@"focus"]) {
    [self focus];
  } else if ([commandName isEqualToString:@"blur"]) {
    [self blur];
  } else if ([commandName isEqualToString:@"undo"]) {
    // `textView` ivar is the concrete EnrichedInputTextView; the
    // `self.textView` getter is typed UITextView (EnrichedViewHost) and
    // wouldn't see katavUndo.
    [textView katavUndo];
    [self anyTextMayHaveBeenModified];
  } else if ([commandName isEqualToString:@"redo"]) {
    [textView katavRedo];
    [self anyTextMayHaveBeenModified];
  } else if ([commandName isEqualToString:@"setValue"]) {
    NSString *value = (NSString *)args[0];
    [self setValue:value];
  } else if ([commandName isEqualToString:@"insertText"]) {
    NSString *text = (NSString *)args[0];
    [self insertTextAtSelection:text];
  } else if ([commandName isEqualToString:@"toggleBold"]) {
    [self toggleRegularStyle:[BoldStyle getType]];
  } else if ([commandName isEqualToString:@"toggleItalic"]) {
    [self toggleRegularStyle:[ItalicStyle getType]];
  } else if ([commandName isEqualToString:@"toggleUnderline"]) {
    [self toggleRegularStyle:[UnderlineStyle getType]];
  } else if ([commandName isEqualToString:@"toggleStrikeThrough"]) {
    [self toggleRegularStyle:[StrikethroughStyle getType]];
  } else if ([commandName isEqualToString:@"toggleInlineCode"]) {
    [self toggleRegularStyle:[InlineCodeStyle getType]];
  } else if ([commandName isEqualToString:@"addLink"]) {
    NSInteger start = [((NSNumber *)args[0]) integerValue];
    NSInteger end = [((NSNumber *)args[1]) integerValue];
    NSString *text = (NSString *)args[2];
    NSString *url = (NSString *)args[3];
    [self addLinkAt:start end:end text:text url:url];
  } else if ([commandName isEqualToString:@"removeLink"]) {
    NSInteger start = [((NSNumber *)args[0]) integerValue];
    NSInteger end = [((NSNumber *)args[1]) integerValue];
    [self removeLinkAt:start end:end];
  } else if ([commandName isEqualToString:@"addHighlight"]) {
    NSInteger start = [((NSNumber *)args[0]) integerValue];
    NSInteger end = [((NSNumber *)args[1]) integerValue];
    NSString *color = (NSString *)args[2];
    [self addHighlightAt:start end:end color:color];
  } else if ([commandName isEqualToString:@"removeHighlight"]) {
    NSInteger start = [((NSNumber *)args[0]) integerValue];
    NSInteger end = [((NSNumber *)args[1]) integerValue];
    [self removeHighlightAt:start end:end];
  } else if ([commandName isEqualToString:@"clearFormatting"]) {
    NSInteger start = [((NSNumber *)args[0]) integerValue];
    NSInteger end = [((NSNumber *)args[1]) integerValue];
    [self clearFormattingAt:start end:end];
  } else if ([commandName isEqualToString:@"clearColors"]) {
    NSInteger start = [((NSNumber *)args[0]) integerValue];
    NSInteger end = [((NSNumber *)args[1]) integerValue];
    // The only color formatting is highlight (background); reuse its removal.
    [self removeHighlightAt:start end:end];
  } else if ([commandName isEqualToString:@"addMention"]) {
    NSString *indicator = (NSString *)args[0];
    NSString *text = (NSString *)args[1];
    NSString *attributes = (NSString *)args[2];
    [self addMention:indicator text:text attributes:attributes];
  } else if ([commandName isEqualToString:@"startMention"]) {
    NSString *indicator = (NSString *)args[0];
    [self startMentionWithIndicator:indicator];
  } else if ([commandName isEqualToString:@"toggleH1"]) {
    [self toggleRegularStyle:[H1Style getType]];
  } else if ([commandName isEqualToString:@"toggleH2"]) {
    [self toggleRegularStyle:[H2Style getType]];
  } else if ([commandName isEqualToString:@"toggleH3"]) {
    [self toggleRegularStyle:[H3Style getType]];
  } else if ([commandName isEqualToString:@"toggleH4"]) {
    [self toggleRegularStyle:[H4Style getType]];
  } else if ([commandName isEqualToString:@"toggleH5"]) {
    [self toggleRegularStyle:[H5Style getType]];
  } else if ([commandName isEqualToString:@"toggleH6"]) {
    [self toggleRegularStyle:[H6Style getType]];
  } else if ([commandName isEqualToString:@"toggleUnorderedList"]) {
    [self toggleRegularStyle:[UnorderedListStyle getType]];
  } else if ([commandName isEqualToString:@"toggleOrderedList"]) {
    [self toggleRegularStyle:[OrderedListStyle getType]];
  } else if ([commandName isEqualToString:@"toggleCheckboxList"]) {
    BOOL checked = [args[0] boolValue];
    [self toggleCheckboxList:checked];
  } else if ([commandName isEqualToString:@"indentList"]) {
    [self indentListAtSelection];
  } else if ([commandName isEqualToString:@"outdentList"]) {
    [self outdentListAtSelection];
  } else if ([commandName isEqualToString:@"toggleBlockQuote"]) {
    [self toggleRegularStyle:[BlockQuoteStyle getType]];
  } else if ([commandName isEqualToString:@"toggleCodeBlock"]) {
    [self toggleRegularStyle:[CodeBlockStyle getType]];
  } else if ([commandName isEqualToString:@"addImage"]) {
    NSString *uri = (NSString *)args[0];
    CGFloat imgWidth = [(NSNumber *)args[1] floatValue];
    CGFloat imgHeight = [(NSNumber *)args[2] floatValue];

    [self addImage:uri width:imgWidth height:imgHeight];
  } else if ([commandName isEqualToString:@"setSelectedImageCaption"]) {
    NSString *caption = (NSString *)args[0];
    [self setSelectedImageCaption:caption];
  } else if ([commandName isEqualToString:@"insertHorizontalRule"]) {
    [self insertHorizontalRule];
  } else if ([commandName isEqualToString:@"setSelection"]) {
    NSInteger start = [((NSNumber *)args[0]) integerValue];
    NSInteger end = [((NSNumber *)args[1]) integerValue];
    [self setCustomSelection:start end:end];
  } else if ([commandName isEqualToString:@"focusTableCell"]) {
    NSInteger tableIndex = [((NSNumber *)args[0]) integerValue];
    NSInteger row = [((NSNumber *)args[1]) integerValue];
    NSInteger col = [((NSNumber *)args[2]) integerValue];
    [self focusTableCellAtIndex:tableIndex row:row col:col];
  } else if ([commandName isEqualToString:@"requestHTML"]) {
    NSInteger requestId = [((NSNumber *)args[0]) integerValue];
    [self requestHTML:requestId];
  } else if ([commandName isEqualToString:@"requestSelectionHTML"]) {
    NSInteger requestId = [((NSNumber *)args[0]) integerValue];
    NSInteger start = [((NSNumber *)args[1]) integerValue];
    NSInteger end = [((NSNumber *)args[2]) integerValue];
    [self requestSelectionHTML:requestId start:start end:end];
  } else if ([commandName isEqualToString:@"replaceSelectionWithHtml"]) {
    NSInteger start = [((NSNumber *)args[0]) integerValue];
    NSInteger end = [((NSNumber *)args[1]) integerValue];
    NSString *html = (NSString *)args[2];
    [self replaceSelectionWithHtml:start end:end html:html];
  } else if ([commandName isEqualToString:@"setTextAlignment"]) {
    NSString *alignmentString = (NSString *)args[0];

    AlignmentStyle *alignmentStyle = stylesDict[@([AlignmentStyle getType])];
    [alignmentStyle
          addAlignment:[AlignmentUtils stringToAlignment:alignmentString]
                 range:textView.selectedRange
            withTyping:YES
        withDirtyRange:YES];

    [self anyTextMayHaveBeenModified];
    if (!_placeholderLabel.isHidden) {
      [self refreshPlaceholderLabelStyles];
    }
  }
}

- (std::shared_ptr<EnrichedTextInputViewEventEmitter>)getEventEmitter {
  if (_eventEmitter != nullptr && !blockEmitting) {
    auto emitter =
        static_cast<const EnrichedTextInputViewEventEmitter &>(*_eventEmitter);
    return std::make_shared<EnrichedTextInputViewEventEmitter>(emitter);
  } else {
    return nullptr;
  }
}

- (void)blur {
  [textView reactBlur];
}

- (void)focus {
  [textView reactFocus];
}

- (void)setValue:(NSString *)value {
  NSString *initiallyProcessedHtml = [parser initiallyProcessHtml:value];
  if (initiallyProcessedHtml == nullptr) {
    // reset the text first and reset typing attributes
    textView.text = @"";
    textView.typingAttributes = defaultTypingAttributes;
    // set new text
    textView.text = value;
  } else {
    // we've got some seemingly proper html
    [parser replaceWholeFromHtml:initiallyProcessedHtml];
  }

  // set selectedRange and check for changes
  textView.selectedRange = NSRange(textView.textStorage.string.length, 0);
  [self anyTextMayHaveBeenModified];
}

// Insert / replace plain text at the current selection (or caret). Used by the
// JS-side popover for Paste and for inserting an AI definition into the note.
- (void)insertTextAtSelection:(NSString *)text {
  // Empty string is allowed: replacing a non-empty selection with "" deletes
  // it (used by Cut). Only a nil guard is needed.
  if (text == nullptr) {
    return;
  }
  [TextInsertionUtils replaceText:text
                               at:textView.selectedRange
             additionalAttributes:nullptr
                             host:self
                    withSelection:YES];
  [self anyTextMayHaveBeenModified];
}

- (void)setCustomSelection:(NSInteger)visibleStart end:(NSInteger)visibleEnd {
  NSString *text = textView.textStorage.string;

  NSUInteger actualStart = [self getActualIndex:visibleStart text:text];
  NSUInteger actualEnd = [self getActualIndex:visibleEnd text:text];

  textView.selectedRange = NSMakeRange(actualStart, actualEnd - actualStart);
}

// Helper: Walks through the string skipping ZWSPs to find the Nth visible
// character
- (NSUInteger)getActualIndex:(NSInteger)visibleIndex text:(NSString *)text {
  NSUInteger currentVisibleCount = 0;
  NSUInteger actualIndex = 0;

  while (actualIndex < text.length) {
    if (currentVisibleCount == visibleIndex) {
      return actualIndex;
    }

    // If the current char is not a hidden space, it counts towards our visible
    // index.
    if ([text characterAtIndex:actualIndex] != 0x200B) {
      currentVisibleCount++;
    }

    actualIndex++;
  }

  return actualIndex;
}

- (void)emitOnSubmitEdittingEvent {
  auto emitter = [self getEventEmitter];
  if (emitter != nullptr) {
    NSString *stringToBeEmitted = [[textView.textStorage.string
        stringByReplacingOccurrencesOfString:@"\u200B"
                                  withString:@""] copy];

    emitter->onSubmitEditing({
        .text = [stringToBeEmitted toCppString],
    });
  }
}

- (void)emitOnLinkDetectedEvent:(LinkData *)linkData range:(NSRange)range {
  auto emitter = [self getEventEmitter];
  if (emitter != nullptr) {
    // update recently active link info
    _recentlyActiveLinkData = linkData;
    _recentlyActiveLinkRange = range;

    emitter->onLinkDetected({
        .text = [linkData.text toCppString],
        .url = [linkData.url toCppString],
        .start = static_cast<int>(range.location),
        .end = static_cast<int>(range.location + range.length),
    });
  }
}

- (void)emitOnPasteImagesEvent:(NSArray<NSDictionary *> *)images {
  auto emitter = [self getEventEmitter];
  if (emitter != nullptr) {
    std::vector<EnrichedTextInputViewEventEmitter::OnPasteImagesImages>
        imagesVector;
    imagesVector.reserve(images.count);

    for (NSDictionary *img in images) {
      NSString *uri = img[@"uri"];
      NSString *type = img[@"type"];
      double width = [img[@"width"] doubleValue];
      double height = [img[@"height"] doubleValue];

      EnrichedTextInputViewEventEmitter::OnPasteImagesImages imageStruct = {
          .uri = [uri toCppString],
          .type = [type toCppString],
          .width = width,
          .height = height};

      imagesVector.push_back(imageStruct);
    }

    emitter->onPasteImages({.images = imagesVector});
  }
}

- (void)emitOnMentionDetectedEvent:(NSString *)text
                         indicator:(NSString *)indicator
                        attributes:(NSString *)attributes {
  auto emitter = [self getEventEmitter];
  if (emitter != nullptr) {
    emitter->onMentionDetected({.text = [text toCppString],
                                .indicator = [indicator toCppString],
                                .payload = [attributes toCppString]});
  }
}

- (void)emitOnMentionEvent:(NSString *)indicator text:(NSString *)text {
  auto emitter = [self getEventEmitter];
  if (emitter != nullptr) {
    if (text != nullptr) {
      folly::dynamic fdStr = [text toCppString];
      emitter->onMention({.indicator = [indicator toCppString], .text = fdStr});
    } else {
      folly::dynamic nul = nullptr;
      emitter->onMention({.indicator = [indicator toCppString], .text = nul});
    }
  }
}

- (void)tryEmittingOnChangeHtmlEvent {
  if (!_emitHtml || textView.markedTextRange != nullptr) {
    return;
  }
  auto emitter = [self getEventEmitter];
  if (emitter != nullptr) {
    NSString *htmlOutput = [HtmlParser
        parseToHtmlFromRange:NSMakeRange(0, textView.textStorage.string.length)
                        host:self];
    // make sure html really changed
    if (![htmlOutput isEqualToString:_recentlyEmittedHtml]) {
      _recentlyEmittedHtml = htmlOutput;
      emitter->onChangeHtml({.value = [htmlOutput toCppString]});
    }
  }
}

- (void)requestHTML:(NSInteger)requestId {
  auto emitter = [self getEventEmitter];
  if (emitter != nullptr) {
    @try {
      NSString *htmlOutput = [HtmlParser
          parseToHtmlFromRange:NSMakeRange(0,
                                           textView.textStorage.string.length)
                          host:self];
      emitter->onRequestHtmlResult({.requestId = static_cast<int>(requestId),
                                    .html = [htmlOutput toCppString]});
    } @catch (NSException *exception) {
      emitter->onRequestHtmlResult({.requestId = static_cast<int>(requestId),
                                    .html = folly::dynamic(nullptr)});
    }
  }
}

// Serialize the [start, end) range to an HTML fragment and return it via the
// same onRequestHtmlResult event, keyed by requestId.
- (void)requestSelectionHTML:(NSInteger)requestId
                       start:(NSInteger)visibleStart
                         end:(NSInteger)visibleEnd {
  auto emitter = [self getEventEmitter];
  if (emitter == nullptr) {
    return;
  }
  @try {
    NSString *text = textView.textStorage.string;
    NSUInteger actualStart = [self getActualIndex:visibleStart text:text];
    NSUInteger actualEnd = [self getActualIndex:visibleEnd text:text];
    NSRange range = NSMakeRange(
        actualStart, actualEnd >= actualStart ? actualEnd - actualStart : 0);
    NSString *htmlOutput = [HtmlParser parseToHtmlFromRange:range host:self];
    emitter->onRequestHtmlResult({.requestId = static_cast<int>(requestId),
                                  .html = [htmlOutput toCppString]});
  } @catch (NSException *exception) {
    emitter->onRequestHtmlResult({.requestId = static_cast<int>(requestId),
                                  .html = folly::dynamic(nullptr)});
  }
}

// Replace the [start, end) range with a parsed HTML fragment, preserving the
// fragment's formatting. Reuses the existing InputHtmlParser range-replace.
- (void)replaceSelectionWithHtml:(NSInteger)visibleStart
                             end:(NSInteger)visibleEnd
                            html:(NSString *)html {
  NSString *text = textView.textStorage.string;
  NSUInteger actualStart = [self getActualIndex:visibleStart text:text];
  NSUInteger actualEnd = [self getActualIndex:visibleEnd text:text];
  NSRange range = NSMakeRange(
      actualStart, actualEnd >= actualStart ? actualEnd - actualStart : 0);
  [parser replaceFromHtml:html range:range];
}

- (void)emitOnKeyPressEvent:(NSString *)key {
  auto emitter = [self getEventEmitter];
  if (emitter != nullptr) {
    emitter->onInputKeyPress({.key = [key toCppString]});
  }
}

// MARK: - Styles manipulation

- (void)toggleRegularStyle:(StyleType)type {
  StyleBase *style = stylesDict[@(type)];
  NSRange range = textView.selectedRange;
  if ([style isParagraph]) {
    range = [textView.textStorage.string paragraphRangeForRange:range];
  }
  if ([StyleUtils handleStyleBlocksAndConflicts:type
                                          range:range
                                        forHost:self]) {
    [style toggle:range];
    [self anyTextMayHaveBeenModified];
  }
}

// Thin entry points for the Cmd-B/I/U key commands handled on the text view.
// They route through the exact same path as the toolbar buttons and the JS
// `toggleBold` / `toggleItalic` / `toggleUnderline` commands.
- (void)katavToggleBold {
  [self toggleRegularStyle:[BoldStyle getType]];
}

- (void)katavToggleItalic {
  [self toggleRegularStyle:[ItalicStyle getType]];
}

- (void)katavToggleUnderline {
  [self toggleRegularStyle:[UnderlineStyle getType]];
}

- (void)toggleCheckboxList:(BOOL)checked {
  CheckboxListStyle *style =
      (CheckboxListStyle *)stylesDict[@([CheckboxListStyle getType])];
  if (style == nullptr) {
    return;
  }
  NSRange range = [textView.textStorage.string
      paragraphRangeForRange:textView.selectedRange];
  if ([StyleUtils handleStyleBlocksAndConflicts:[CheckboxListStyle getType]
                                          range:range
                                        forHost:self]) {
    [style toggleWithChecked:checked range:range];
    [self anyTextMayHaveBeenModified];
  }
}

// Finds the list style (UL / OL / Checkbox) active at the current selection,
// or nil if the caret is outside any list. Mirrors EnrichedInputTextView's
// activeListStyleForSelection — duplicated here because the JS command path
// doesn't go through the text view.
- (StyleBase *)activeListStyleForCurrentSelection {
  NSArray<NSNumber *> *candidates = @[
    @([UnorderedListStyle getType]),
    @([OrderedListStyle getType]),
    @([CheckboxListStyle getType]),
  ];
  NSRange range = textView.selectedRange;
  for (NSNumber *type in candidates) {
    StyleBase *style = stylesDict[type];
    if (style == nil)
      continue;
    if ([style detect:range])
      return style;
  }
  return nil;
}

- (void)indentListAtSelection {
  StyleBase *style = [self activeListStyleForCurrentSelection];
  if (style == nil)
    return;

  NSRange range = textView.selectedRange;
  NSUInteger probe = range.location;
  if (probe >= textView.textStorage.length && probe > 0)
    probe--;
  NSInteger depth = [style depthAtLocation:probe];
  // Cap matches the keyboard handler so the JS command and Tab key behave
  // identically.
  if (depth >= 4)
    return;

  [style indent:range];
  // Sync typing attrs to the new paragraph state — see comment on the helper.
  [textView katavSyncTypingAttributesToCurrentParagraph];
  [self anyTextMayHaveBeenModified];
}

- (void)outdentListAtSelection {
  StyleBase *style = [self activeListStyleForCurrentSelection];
  if (style == nil)
    return;

  NSRange range = textView.selectedRange;
  NSUInteger probe = range.location;
  if (probe >= textView.textStorage.length && probe > 0)
    probe--;
  NSInteger depth = [style depthAtLocation:probe];

  if (depth <= 0) {
    // Same as Shift-Tab at depth 0: collapse out of the list entirely.
    [style remove:range withDirtyRange:YES];
  } else {
    [style outdent:range];
  }
  [textView katavSyncTypingAttributesToCurrentParagraph];
  [self anyTextMayHaveBeenModified];
}

- (void)addLinkAt:(NSInteger)start
              end:(NSInteger)end
             text:(NSString *)text
              url:(NSString *)url {
  LinkStyle *linkStyleClass = (LinkStyle *)stylesDict[@([LinkStyle getType])];
  if (linkStyleClass == nullptr) {
    return;
  }

  // translate the output start-end notation to range
  NSRange linkRange = NSMakeRange(start, end - start);
  if ([StyleUtils handleStyleBlocksAndConflicts:[LinkStyle getType]
                                          range:linkRange
                                        forHost:self]) {
    LinkData *linkData = [[LinkData alloc] init];
    linkData.text = text;
    linkData.url = url;
    linkData.isManual = YES;
    [linkStyleClass addLink:linkData range:linkRange withSelection:YES];
    [self anyTextMayHaveBeenModified];
  }
}

// Parses a #RRGGBB hex string into a UIColor. Tolerant of an optional
// leading '#' and case-insensitive on the hex digits; everything else
// falls back to a transparent color so the caller's set/get round-trip
// stays predictable.
static UIColor *katavParseHexColor(NSString *hex) {
  if (hex.length == 0) {
    return [UIColor clearColor];
  }
  NSString *cleaned = [hex hasPrefix:@"#"] ? [hex substringFromIndex:1] : hex;
  if (cleaned.length != 6) {
    return [UIColor clearColor];
  }
  unsigned int rgb = 0;
  NSScanner *scanner = [NSScanner scannerWithString:cleaned];
  if (![scanner scanHexInt:&rgb]) {
    return [UIColor clearColor];
  }
  CGFloat r = ((rgb >> 16) & 0xFF) / 255.0;
  CGFloat g = ((rgb >> 8) & 0xFF) / 255.0;
  CGFloat b = (rgb & 0xFF) / 255.0;
  return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

- (void)addHighlightAt:(NSInteger)start
                   end:(NSInteger)end
                 color:(NSString *)hexColor {
  HighlightStyle *highlightStyle =
      (HighlightStyle *)stylesDict[@([HighlightStyle getType])];
  if (highlightStyle == nullptr) {
    return;
  }
  NSInteger textLength = (NSInteger)textView.textStorage.length;
  NSInteger rangeStart = MAX(0, MIN(start, end));
  NSInteger rangeEnd = MIN(textLength, MAX(start, end));
  if (rangeEnd <= rangeStart) {
    return;
  }
  NSRange range = NSMakeRange(rangeStart, rangeEnd - rangeStart);
  UIColor *color = katavParseHexColor(hexColor);
  [highlightStyle addHighlightAtRange:range color:color];
  [self anyTextMayHaveBeenModified];
}

- (void)removeHighlightAt:(NSInteger)start end:(NSInteger)end {
  HighlightStyle *highlightStyle =
      (HighlightStyle *)stylesDict[@([HighlightStyle getType])];
  if (highlightStyle == nullptr) {
    return;
  }
  NSInteger textLength = (NSInteger)textView.textStorage.length;
  NSInteger rangeStart = MAX(0, MIN(start, end));
  NSInteger rangeEnd = MIN(textLength, MAX(start, end));
  if (rangeEnd <= rangeStart) {
    // Empty/stale range from the toolbar (the editor can briefly lose the JS
    // selection on tap) — fall back to the live native selection.
    NSRange sel = textView.selectedRange;
    rangeStart = (NSInteger)sel.location;
    rangeEnd = MIN(textLength, (NSInteger)(sel.location + sel.length));
  }
  if (rangeEnd <= rangeStart) {
    return;
  }
  NSRange range = NSMakeRange(rangeStart, rangeEnd - rangeStart);
  [highlightStyle removeHighlightInRange:range];
  [self anyTextMayHaveBeenModified];
}

// Strip ALL inline formatting the user perceives — bold / italic / underline /
// strikethrough / inline code / link AND highlight ("marcação") — from the
// range, leaving paragraph structure (heading / list / quote) intact.
//
// Inline styles are tracked as custom attributes (EnrichedBold, …); the visual
// font traits are DERIVED from them by InputAttributesManager when it
// reprocesses a dirty range. So clearing the visual attributes directly (or
// re-inserting plain text) doesn't stick — the styling is rebuilt from the
// custom attributes, which is why earlier attempts left bold in place. We
// instead remove each style through the SAME path the toolbar uses to toggle it
// off: drop the custom attribute and mark the range dirty so the manager
// rebuilds the run without it. Highlight is the background-color attribute, so
// it's dropped through its own removal path.
- (void)clearFormattingAt:(NSInteger)start end:(NSInteger)end {
  NSInteger textLength = (NSInteger)textView.textStorage.length;
  NSInteger rangeStart = MAX(0, MIN(start, end));
  NSInteger rangeEnd = MIN(textLength, MAX(start, end));
  if (rangeEnd <= rangeStart) {
    // Empty/stale range from the toolbar (the editor can briefly lose the JS
    // selection on tap) — fall back to the live native selection.
    NSRange sel = textView.selectedRange;
    rangeStart = (NSInteger)sel.location;
    rangeEnd = MIN(textLength, (NSInteger)(sel.location + sel.length));
  }
  if (rangeEnd <= rangeStart) {
    return;
  }
  NSRange range = NSMakeRange(rangeStart, rangeEnd - rangeStart);

  // Inline styles (incl. link) via the toolbar's toggle-off path.
  StyleType inlineTypes[] = {
      [BoldStyle getType],       [ItalicStyle getType],
      [UnderlineStyle getType],  [StrikethroughStyle getType],
      [InlineCodeStyle getType], [LinkStyle getType],
  };
  for (NSUInteger i = 0; i < sizeof(inlineTypes) / sizeof(inlineTypes[0]);
       i++) {
    StyleBase *style = stylesDict[@(inlineTypes[i])];
    if (style != nullptr) {
      // remove: is a no-op where the style is absent and removes it wherever it
      // occurs in the range — no need to pre-check coverage.
      [style remove:range withDirtyRange:YES];
    }
  }

  // Highlight ("marcação") is the background-color attribute — drop it too so a
  // single "clear formatting" tap removes everything the user sees.
  HighlightStyle *highlightStyle =
      (HighlightStyle *)stylesDict[@([HighlightStyle getType])];
  if (highlightStyle != nullptr) {
    [highlightStyle removeHighlightInRange:range];
  }

  [self anyTextMayHaveBeenModified];
}

- (void)removeLinkAt:(NSInteger)start end:(NSInteger)end {
  LinkStyle *linkStyleClass = (LinkStyle *)stylesDict[@([LinkStyle getType])];
  if (linkStyleClass == nullptr) {
    return;
  }

  NSInteger textLength = (NSInteger)textView.textStorage.length;
  if (start < 0) {
    start = 0;
  }
  if (end > textLength) {
    end = textLength;
  }

  NSInteger rangeStart = MIN(start, end);
  NSInteger rangeLength = MAX(start, end) - rangeStart;
  NSRange linkRange = NSMakeRange(rangeStart, rangeLength);

  [linkStyleClass remove:linkRange withDirtyRange:YES];
  [self anyTextMayHaveBeenModified];
}

- (void)addMention:(NSString *)indicator
              text:(NSString *)text
        attributes:(NSString *)attributes {
  MentionStyle *mentionStyleClass =
      (MentionStyle *)stylesDict[@([MentionStyle getType])];
  if (mentionStyleClass == nullptr) {
    return;
  }

  NSValue *activeMentionRange = [mentionStyleClass getActiveMentionRange];
  NSRange rangeToUse = activeMentionRange != nullptr
                           ? [activeMentionRange rangeValue]
                           : self.textView.selectedRange;

  if ([StyleUtils handleStyleBlocksAndConflicts:[MentionStyle getType]
                                          range:rangeToUse
                                        forHost:self]) {
    [mentionStyleClass addMention:indicator text:text attributes:attributes];
    [self anyTextMayHaveBeenModified];
  }
}

- (void)addImage:(NSString *)uri width:(float)width height:(float)height {
  ImageStyle *imageStyleClass =
      (ImageStyle *)stylesDict[@([ImageStyle getType])];
  if (imageStyleClass == nullptr) {
    return;
  }

  if ([StyleUtils handleStyleBlocksAndConflicts:[ImageStyle getType]
                                          range:textView.selectedRange
                                        forHost:self]) {
    [imageStyleClass addImage:uri width:width height:height];
    [self anyTextMayHaveBeenModified];
  }
}

- (void)setSelectedImageCaption:(NSString *)caption {
  ImageStyle *imageStyleClass =
      (ImageStyle *)stylesDict[@([ImageStyle getType])];
  if (imageStyleClass == nullptr) {
    return;
  }
  [imageStyleClass setSelectedImageCaption:caption];
  [self anyTextMayHaveBeenModified];
}

- (void)insertHorizontalRule {
  HorizontalRuleStyle *hrStyle =
      (HorizontalRuleStyle *)stylesDict[@([HorizontalRuleStyle getType])];
  if (hrStyle == nullptr) {
    return;
  }

  if ([StyleUtils handleStyleBlocksAndConflicts:[HorizontalRuleStyle getType]
                                          range:textView.selectedRange
                                        forHost:self]) {
    [hrStyle insertHorizontalRule];
    [self anyTextMayHaveBeenModified];
  }
}

- (void)startMentionWithIndicator:(NSString *)indicator {
  MentionStyle *mentionStyleClass =
      (MentionStyle *)stylesDict[@([MentionStyle getType])];
  if (mentionStyleClass == nullptr) {
    return;
  }

  if ([StyleUtils handleStyleBlocksAndConflicts:[MentionStyle getType]
                                          range:textView.selectedRange
                                        forHost:self]) {
    [mentionStyleClass startMentionWithIndicator:indicator];
    [self anyTextMayHaveBeenModified];
  }
}

- (void)manageSelectionBasedChanges {
  NSString *currentString = [textView.textStorage.string copy];

  MentionStyle *mentionStyleClass =
      (MentionStyle *)stylesDict[@([MentionStyle getType])];
  if (mentionStyleClass != nullptr) {
    // mention editing runs if only a selection was done (no text change)
    // otherwise we would double-emit with a second call in the
    // anyTextMayHaveBeenModified method
    if ([_recentInputString isEqualToString:currentString]) {
      [mentionStyleClass manageMentionEditing];
    }
  }

  // attributes manager handles proper typingAttributes at all times to properly
  // extend meta-attributes
  BOOL onlySelectionChanged =
      textView.selectedRange.length == 0 &&
      [_recentInputString isEqualToString:currentString];
  // removedTypingAttributes aren't normally removed during the regular flow
  // and we do remove them only here - so when we are sure that selection
  // changed. We want to remember which attributes were removed as long as we
  // stay at the same position. This prevents a removed attribute from being
  // re-applied from the preceding character right after we toggled it off.
  [attributesManager clearRemovedTypingAttributes];
  [attributesManager
      manageTypingAttributesWithOnlySelection:onlySelectionChanged];

  // always update active styles
  [self tryUpdatingActiveStyles];
}

- (void)handleWordModificationBasedChanges:(NSString *)word
                                   inRange:(NSRange)range {
  // manual links refreshing and automatic links detection handling
  LinkStyle *linkStyle = [stylesDict objectForKey:@([LinkStyle getType])];

  if (linkStyle != nullptr) {
    // manual links need to be handled first because they can block automatic
    // links after being refreshed
    [linkStyle handleManualLinks:word inRange:range];
    [linkStyle handleAutomaticLinks:word inRange:range];
  }
}

- (void)anyTextMayHaveBeenModified {
  // we don't do no text changes when working with iOS marked text
  if (textView.markedTextRange != nullptr) {
    return;
  }

  // zero width space adding or removal
  [ZeroWidthSpaceUtils handleZeroWidthSpacesInHost:self];

  // emptying input typing attributes management
  if (textView.textStorage.string.length == 0 &&
      _recentInputString.length > 0) {
    // reset typing attribtues
    textView.typingAttributes = defaultTypingAttributes;
  }

  // mentions management: removal and editing
  MentionStyle *mentionStyleClass =
      (MentionStyle *)stylesDict[@([MentionStyle getType])];
  if (mentionStyleClass != nullptr) {
    [mentionStyleClass handleExistingMentions];
    [mentionStyleClass manageMentionEditing];
  }

  // placholder management
  if (!_placeholderLabel.hidden && textView.textStorage.string.length > 0) {
    [self setPlaceholderLabelShown:NO];
  } else if (textView.textStorage.string.length == 0 &&
             _placeholderLabel.hidden) {
    [self setPlaceholderLabelShown:YES];
  }

  // modified words handling
  NSArray *currentDirtyRanges = [attributesManager getDirtyRanges];
  if (currentDirtyRanges.count > 0) {
    NSMutableArray *modifiedWords = [[NSMutableArray alloc] init];

    for (NSValue *dirtyRangeValue in currentDirtyRanges) {
      NSRange dirtyRange = [dirtyRangeValue rangeValue];
      NSArray *words =
          [WordsUtils getAffectedWordsFromText:textView.textStorage.string
                             modificationRange:dirtyRange];
      if (words != nullptr) {
        [modifiedWords addObjectsFromArray:words];
      }
    }

    for (NSDictionary *wordDict in modifiedWords) {
      NSString *wordText = (NSString *)[wordDict objectForKey:@"word"];
      NSValue *wordRange = (NSValue *)[wordDict objectForKey:@"range"];

      if (wordText == nullptr || wordRange == nullptr) {
        continue;
      }

      [self handleWordModificationBasedChanges:wordText
                                       inRange:[wordRange rangeValue]];
    }
  }

  if (![textView.textStorage.string isEqualToString:_recentInputString]) {
    // emit onChangeText event
    auto emitter = [self getEventEmitter];
    if (emitter != nullptr && _emitTextChange) {
      // set the recent input string only if the emitter is defined
      _recentInputString = [textView.textStorage.string copy];

      // emit string without zero width spaces
      NSString *stringToBeEmitted = [[textView.textStorage.string
          stringByReplacingOccurrencesOfString:@"\u200B"
                                    withString:@""] copy];

      emitter->onChangeText({.value = [stringToBeEmitted toCppString]});
    }
  }
  // all the visible (not meta) attributes handling in the ranges that could
  // have changed
  [attributesManager handleDirtyRangesStyling];
  // update height on each character change
  [self tryUpdatingHeight];
  // update active styles as well
  [self tryUpdatingActiveStyles];
  [self layoutAttachments];
  // update drawing - schedule debounced relayout
  [self scheduleRelayoutIfNeeded];
}

// Debounced relayout helper - coalesces multiple requests into one per runloop
// tick
- (void)scheduleRelayoutIfNeeded {
  // Cancel any previously scheduled invocation to debounce
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(_performRelayout)
                                             object:nil];
  // Schedule on next runloop cycle
  [self performSelector:@selector(_performRelayout)
             withObject:nil
             afterDelay:0];
}

- (void)_performRelayout {
  if (!textView) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    NSRange wholeRange =
        NSMakeRange(0, self->textView.textStorage.string.length);
    NSRange actualRange = NSMakeRange(0, 0);
    [self->textView.layoutManager
        invalidateLayoutForCharacterRange:wholeRange
                     actualCharacterRange:&actualRange];
    [self->textView.layoutManager ensureLayoutForCharacterRange:actualRange];
    [self->textView.layoutManager
        invalidateDisplayForCharacterRange:wholeRange];

    // We have to explicitly set contentSize
    // That way textView knows if content overflows and if should be scrollable
    // We recall measureSize here because value returned from previous
    // measureSize may not be up-to date at that point
    CGSize measuredSize = [self measureSize:self->textView.frame.size.width];
    self->textView.contentSize = measuredSize;
  });
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  // used to run all lifecycle callbacks
  [self anyTextMayHaveBeenModified];
}

// MARK: - Delegate methods

- (void)textViewDidBeginEditing:(UITextView *)textView {
  auto emitter = [self getEventEmitter];
  if (emitter != nullptr) {
    // send onFocus event if allowed
    if (_emitFocusBlur) {
      emitter->onInputFocus({});
    }
  }
  // manage selection changes since textViewDidChangeSelection sometimes doesn't
  // run on focus
  [self manageSelectionBasedChanges];
}

- (void)textViewDidEndEditing:(UITextView *)textView {
  auto emitter = [self getEventEmitter];
  if (emitter != nullptr && _emitFocusBlur) {
    // send onBlur event
    emitter->onInputBlur({});
  }
}

- (UIMenu *)textView:(UITextView *)tv
    editMenuForTextInRange:(NSRange)range
          suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions
    API_AVAILABLE(ios(16.0)) {
  // Consumers with their own selection toolbar suppress the native edit menu
  // entirely so the two don't overlap. Returning an empty menu hides it.
  if (_disableNativeSelectionMenu) {
    return [UIMenu menuWithChildren:@[]];
  }

  if (_contextMenuItems == nil || _contextMenuItems.count == 0) {
    return [UIMenu menuWithChildren:suggestedActions];
  }

  NSMutableArray<UIMenuElement *> *customActions = [NSMutableArray new];

  for (NSString *title in _contextMenuItems) {
    __weak EnrichedTextInputView *weakSelf = self;

    UIAction *action =
        [UIAction actionWithTitle:title
                            image:nil
                       identifier:nil
                          handler:^(__kindof UIAction *_Nonnull action) {
                            [weakSelf emitOnContextMenuItemPressEvent:title];
                          }];
    [customActions addObject:action];
  }

  [customActions addObjectsFromArray:suggestedActions];
  return [UIMenu menuWithChildren:customActions];
}

// iOS 17+ presents a SEPARATE context menu for "text items" — links and (the
// case that bites us) image attachments — via this delegate, independent of
// editMenuForTextInRange above. A consumer that renders its own image/selection
// menu sets disableNativeSelectionMenu, so suppress this one too: otherwise
// tapping a selected image shows the system menu (Copy / Share / Save to
// Photos…) on top of the JS menu. Returning nil hides the system menu for the
// item; selection (and the JS menu it drives) is unaffected.
- (UITextItemMenuConfiguration *)textView:(UITextView *)tv
             menuConfigurationForTextItem:(UITextItem *)textItem
                              defaultMenu:(UIMenu *)defaultMenu
    API_AVAILABLE(ios(17.0)) {
  if (_disableNativeSelectionMenu) {
    return nil;
  }
  return [UITextItemMenuConfiguration configurationWithMenu:defaultMenu];
}

- (void)emitOnContextMenuItemPressEvent:(NSString *)itemText {
  auto emitter = [self getEventEmitter];
  if (emitter != nullptr) {
    NSRange selectedRange = textView.selectedRange;
    NSString *selectedText = @"";
    if (selectedRange.length > 0) {
      selectedText =
          [textView.textStorage.string substringWithRange:selectedRange];
    }

    AlignmentStyle *alignmentStyle = stylesDict[@([AlignmentStyle getType])];
    NSString *currentAlignment = [alignmentStyle getStyleState];

    emitter->onContextMenuItemPress(
        {.itemText = [itemText toCppString],
         .selectedText = [selectedText toCppString],
         .selectionStart = static_cast<int>(selectedRange.location),
         .selectionEnd =
             static_cast<int>(selectedRange.location + selectedRange.length),
         .styleState = {
             .bold = GET_STYLE_STATE([BoldStyle getType]),
             .italic = GET_STYLE_STATE([ItalicStyle getType]),
             .underline = GET_STYLE_STATE([UnderlineStyle getType]),
             .strikeThrough = GET_STYLE_STATE([StrikethroughStyle getType]),
             .inlineCode = GET_STYLE_STATE([InlineCodeStyle getType]),
             .h1 = GET_STYLE_STATE([H1Style getType]),
             .h2 = GET_STYLE_STATE([H2Style getType]),
             .h3 = GET_STYLE_STATE([H3Style getType]),
             .h4 = GET_STYLE_STATE([H4Style getType]),
             .h5 = GET_STYLE_STATE([H5Style getType]),
             .h6 = GET_STYLE_STATE([H6Style getType]),
             .codeBlock = GET_STYLE_STATE([CodeBlockStyle getType]),
             .blockQuote = GET_STYLE_STATE([BlockQuoteStyle getType]),
             .orderedList = GET_STYLE_STATE([OrderedListStyle getType]),
             .unorderedList = GET_STYLE_STATE([UnorderedListStyle getType]),
             .link = GET_STYLE_STATE([LinkStyle getType]),
             .image = GET_STYLE_STATE([ImageStyle getType]),
             .mention = GET_STYLE_STATE([MentionStyle getType]),
             .checkboxList = GET_STYLE_STATE([CheckboxListStyle getType]),
             .highlight = GET_STYLE_STATE([HighlightStyle getType]),
             .alignment = [currentAlignment UTF8String]}});
  }
}

- (void)handleKeyPressInRange:(NSString *)text range:(NSRange)range {
  NSString *key = nil;

  if (text.length == 0) {
    key = @"Backspace";
  } else if ([text isEqualToString:@"\n"]) {
    key = @"Enter";
  } else if ([text isEqualToString:@"\t"]) {
    key = @"Tab";
  } else if (text.length == 1) {
    key = text;
  }

  if (key != nil) {
    [self emitOnKeyPressEvent:key];
  }
}

- (bool)textView:(UITextView *)textView
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString *)text {
  // Capture the attributes at range.location that are being replaced
  // (autocorrect / predictive) so didProcessEditing: can re-stamp them onto the
  // replacement.
  if (range.length > 0) {
    _capturedAttributesBeforeChange =
        [textView.textStorage attributesAtIndex:range.location
                                 effectiveRange:NULL];
  }

  // Check if the user pressed "Enter"
  if ([text isEqualToString:@"\n"]) {
    const bool shouldSubmit = [self textInputShouldSubmitOnReturn];
    const bool shouldReturn = [self textInputShouldReturn];

    if (shouldSubmit) {
      [self emitOnSubmitEdittingEvent];
    }

    if (shouldReturn) {
      [textView endEditing:NO];
    }

    if (shouldSubmit || shouldReturn) {
      return NO;
    }
  }

  [self handleKeyPressInRange:text range:range];

  CheckboxListStyle *cbLStyle =
      (CheckboxListStyle *)stylesDict[@([CheckboxListStyle getType])];
  H1Style *h1Style = stylesDict[@([H1Style getType])];
  H2Style *h2Style = stylesDict[@([H2Style getType])];
  H3Style *h3Style = stylesDict[@([H3Style getType])];
  H4Style *h4Style = stylesDict[@([H4Style getType])];
  H5Style *h5Style = stylesDict[@([H5Style getType])];
  H6Style *h6Style = stylesDict[@([H6Style getType])];

  // some of the changes these checks do could interfere with later checks and
  // cause a crash so here we rely on short circuiting evaluation of the logical
  // expression. Either way it's not possible to have two of them come off at
  // the same time
  if (
      // ZWS backspace handling for paragraph styles
      [ZeroWidthSpaceUtils handleBackspaceInRange:range
                                  replacementText:text
                                             host:self] ||
      [cbLStyle handleNewlinesInRange:range replacementText:text] ||
      [h1Style handleNewlinesInRange:range replacementText:text] ||
      [h2Style handleNewlinesInRange:range replacementText:text] ||
      [h3Style handleNewlinesInRange:range replacementText:text] ||
      [h4Style handleNewlinesInRange:range replacementText:text] ||
      [h5Style handleNewlinesInRange:range replacementText:text] ||
      [h6Style handleNewlinesInRange:range replacementText:text] ||
      [ParagraphAttributesUtils handleBackspaceInRange:range
                                       replacementText:text
                                                 input:self] ||
      [ParagraphAttributesUtils handleResetTypingAttributesOnBackspace:range
                                                       replacementText:text
                                                                 input:self]
      // Check configurable text shortcuts (block: "# " → h1, inline: `code` →
      // inline_code)
      || [ShortcutsUtils tryHandlingParagraphShortcutsInRange:range
                                              replacementText:text
                                                        input:self] ||
      [ShortcutsUtils tryHandlingInlineShortcutsInRange:range
                                        replacementText:text
                                                  input:self]
      //       CRITICAL: This callback HAS TO be always evaluated last.
      //
      //       This function is the "Generic Fallback": if no specific style
      //       claims the backspace action to change its state, only then do we
      //       proceed to physically delete the newline and merge paragraphs.
      ||
      [ParagraphAttributesUtils handleParagraphStylesMergeOnBackspace:range
                                                      replacementText:text
                                                                input:self]) {
    [self anyTextMayHaveBeenModified];
    return NO;
  }

  return YES;
}

// A deeper, more saturated variant of the given color (~half brightness). Used
// for the selection tint over a highlight so the highlighted text reads as a
// distinct, darker band within the selection.
- (UIColor *)katavDeeperColor:(UIColor *)color {
  if (color == nil) {
    return nil;
  }
  CGFloat h, s, b, a;
  if ([color getHue:&h saturation:&s brightness:&b alpha:&a]) {
    return [UIColor colorWithHue:h
                      saturation:MIN(1.0, s * 1.15)
                      brightness:b * 0.5
                           alpha:a];
  }
  return color;
}

// While the selection overlaps any highlighted (background-color) text, swap
// the selection tint to a deeper translucent green so the highlighted text
// stays distinct against the highlight; restore the configured tint otherwise.
// Fires on every selection change, so the color updates live as the user drags
// the selection.
- (void)updateSelectionTintForHighlightOverlap {
  if (_baseSelectionTintColor == nil) {
    _baseSelectionTintColor = textView.tintColor;
  }
  NSRange sel = textView.selectedRange;

  // A selected inline image shows the JS resize overlay instead of the native
  // selection. The native selection band is sized to the attachment's RESERVED
  // glyph box (image height + descender + caption space), so it renders a
  // second, taller box around the image — worse with a multi-line caption.
  // Clear the tint while a lone image is selected to hide that band (and its
  // grab handles); the resize overlay is the only selection affordance.
  if (sel.length == 1 && sel.location < textView.textStorage.length) {
    ImageStyle *imageStyle = (ImageStyle *)stylesDict[@([ImageStyle getType])];
    TableStyle *tableStyle = (TableStyle *)stylesDict[@([TableStyle getType])];
    BOOL loneImage = imageStyle != nil &&
                     [imageStyle getImageDataAt:sel.location] != nullptr;
    // A tapped table selects its ORC (1 char) so the toolbar's table controls
    // light up; like an image, the native selection band around that glyph is
    // unwanted chrome — clear the tint so only the table grid shows.
    BOOL loneTable = tableStyle != nil &&
                     [tableStyle getTableDataAt:sel.location] != nullptr;
    if (loneImage || loneTable) {
      UIColor *clear = [UIColor clearColor];
      if (![textView.tintColor isEqual:clear]) {
        textView.tintColor = clear;
      }
      return;
    }
  }

  UIColor *desired = _baseSelectionTintColor;
  if (sel.length > 0 &&
      sel.location + sel.length <= textView.textStorage.length) {
    __block BOOL overlapsHighlight = NO;
    [textView.textStorage enumerateAttribute:NSBackgroundColorAttributeName
                                     inRange:sel
                                     options:0
                                  usingBlock:^(id _Nullable value, NSRange r,
                                               BOOL *_Nonnull stop) {
                                    if ([value isKindOfClass:[UIColor class]]) {
                                      overlapsHighlight = YES;
                                      *stop = YES;
                                    }
                                  }];
    if (overlapsHighlight) {
      // Deeper green derived from the configured (green) selection tint —
      // theme-aware, and reads as a darker band over the highlight. UITextView
      // renders the selection fill at the system alpha, so this stays
      // translucent. Fall back to a fixed deep green if the base isn't set.
      desired = [self katavDeeperColor:_baseSelectionTintColor]
                    ?: [UIColor colorWithRed:0.04
                                       green:0.36
                                        blue:0.21
                                       alpha:1.0];
    }
  }
  if (textView.tintColor != desired && ![textView.tintColor isEqual:desired]) {
    textView.tintColor = desired;
  }
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
  [self updateSelectionTintForHighlightOverlap];

  [self emitChangeSelectionEvent];

  // manage selection changes
  [self manageSelectionBasedChanges];
}

// Computes the current selection's substring + on-screen rect and emits
// onChangeSelection. Extracted from textViewDidChangeSelection: so it can also
// fire on scroll (see scrollViewDidScroll:) — JS-side overlays (image resize
// handles, table controls, the selection popover) anchor to this rect in the
// React wrapper's coordinate space, so they have to be refreshed as the text
// view scrolls internally, or they stay pinned at the original spot and end up
// floating over unrelated text.
- (void)emitChangeSelectionEvent {
  // emit the event
  NSString *textAtSelection =
      [[[NSMutableString alloc] initWithString:textView.textStorage.string]
          substringWithRange:textView.selectedRange];

  // Compute the on-screen rect of the selection so JS can anchor a popover
  // (highlight / Define / Search) above it. firstRectForRange returns the
  // bounding rect of the FIRST line of the selection in the text view's
  // own coordinate space; we hand that straight to JS, which already lays
  // the popover out relative to the editor view. Empty / collapsed
  // selections report a zero-size rect and the JS side hides the popover.
  CGRect selectionRect = CGRectZero;
  // Special case: a selected inline image is a single Object-Replacement-Char
  // glyph whose laid-out glyph rect reserves image + caption height. Handing
  // that full rect to JS makes the green resize/selection box taller than the
  // image (starting above it) and corrupts the resize aspect (width/height).
  // For an ImageAttachment, emit the image's own on-screen frame instead —
  // computed by the SAME helper that positions the image, so the box hugs the
  // image exactly and stays correct after internal scroll. Tables / horizontal
  // rules are also single-ORC attachments but are NOT ImageAttachments and
  // their caption-reserved height is 0, so we deliberately exclude them: JS
  // (activeTableRect) needs the table's full glyph rect for its column handles.
  BOOL handledImageRect = NO;
  if (textView.selectedRange.length == 1) {
    id attachment =
        [textView.textStorage attribute:NSAttachmentAttributeName
                                atIndex:textView.selectedRange.location
                         effectiveRange:NULL];
    if ([attachment isKindOfClass:[ImageAttachment class]]) {
      CGRect imageRect = [AttachmentLayoutUtils
          frameForAttachment:(ImageAttachment *)attachment
                     atRange:textView.selectedRange
                    textView:textView
                      config:config];
      if (!CGRectIsNull(imageRect) && !CGRectIsInfinite(imageRect) &&
          imageRect.size.width > 0 && imageRect.size.height > 0) {
        selectionRect = [textView convertRect:imageRect toView:self];
        handledImageRect = YES;
      }
    }
  }
  if (!handledImageRect && textView.selectedRange.length > 0) {
    UITextRange *textRange =
        [self katavTextRangeFromNSRange:textView.selectedRange
                             inTextView:textView];
    if (textRange != nil) {
      CGRect rawRect = [textView firstRectForRange:textRange];
      // firstRectForRange can return CGRectNull / infinite for ranges that
      // aren't laid out yet — clamp to zero so JS treats it as "no rect".
      if (CGRectIsNull(rawRect) || CGRectIsInfinite(rawRect)) {
        selectionRect = CGRectZero;
      } else {
        // firstRectForRange returns coords in textView's own coordinate space,
        // which includes the scroll content offset. Convert to the outer view
        // (self) so the JS popover — anchored relative to the React wrapper,
        // not the scrollable content — is positioned correctly after scrolling.
        selectionRect = [textView convertRect:rawRect toView:self];
      }
    }
  }

  auto emitter = [self getEventEmitter];
  if (emitter != nullptr) {
    // iOS range works differently because it specifies location and length
    // here, start is the location, but end is the first index BEHIND the end.
    // So a 0 length range will have equal start and end
    emitter->onChangeSelection(
        {.start = static_cast<int>(textView.selectedRange.location),
         .end = static_cast<int>(textView.selectedRange.location +
                                 textView.selectedRange.length),
         .text = [textAtSelection toCppString],
         .rectX = static_cast<Float>(selectionRect.origin.x),
         .rectY = static_cast<Float>(selectionRect.origin.y),
         .rectWidth = static_cast<Float>(selectionRect.size.width),
         .rectHeight = static_cast<Float>(selectionRect.size.height)});
  }
}

// UITextView is a UIScrollView and scrolls its content internally, but the
// selection rect we report is anchored to the React wrapper — so a selected
// image's resize handles (and the table/selection overlays) would stay frozen
// in place while the image scrolls away, leaving the green chrome floating over
// the text area. Re-emit the selection rect as the content scrolls so the
// overlay tracks the selection. Only when something is actually selected, so
// ordinary reading-scroll stays free of bridge traffic and re-renders.
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
  if (textView.selectedRange.length > 0) {
    [self emitChangeSelectionEvent];
  }
}

// Builds a UITextRange from an NSRange so we can ask the text view for the
// selection's on-screen rect. Returns nil if the range can't be mapped to
// valid text positions (e.g. out of bounds mid-edit).
- (UITextRange *)katavTextRangeFromNSRange:(NSRange)range
                                inTextView:(UITextView *)textView {
  UITextPosition *beginning = textView.beginningOfDocument;
  UITextPosition *start = [textView positionFromPosition:beginning
                                                  offset:range.location];
  if (start == nil) {
    return nil;
  }
  UITextPosition *end = [textView positionFromPosition:start
                                                offset:range.length];
  if (end == nil) {
    return nil;
  }
  return [textView textRangeFromPosition:start toPosition:end];
}

// this function isn't called always when some text changes (for example setting
// link or starting mention with indicator doesn't fire it) so all the logic is
// in anyTextMayHaveBeenModified
- (void)textViewDidChange:(UITextView *)textView {
  [self anyTextMayHaveBeenModified];
}

/**
 * Handles iOS Dynamic Type changes (User changing font size in System
 * Settings).
 *
 * Unlike Android, iOS Views do not automatically rescale existing
 * NSAttributedStrings when the system font size changes. The text attributes
 * are static once drawn.
 *
 * This method detects the change and performs a "Hard Refresh" of the content.
 */
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];

  if (!config.allowFontScaling) {
    return;
  }

  if (previousTraitCollection.preferredContentSizeCategory ==
      self.traitCollection.preferredContentSizeCategory) {
    return;
  }

  [config invalidateFonts];

  NSMutableDictionary *newTypingAttrs = [defaultTypingAttributes mutableCopy];
  newTypingAttrs[NSFontAttributeName] = [config primaryFont];

  defaultTypingAttributes = newTypingAttrs;
  textView.typingAttributes = defaultTypingAttributes;

  [self refreshPlaceholderLabelStyles];

  NSRange prevSelectedRange = textView.selectedRange;

  NSString *currentHtml = [HtmlParser
      parseToHtmlFromRange:NSMakeRange(0, textView.textStorage.string.length)
                      host:self];
  NSString *initiallyProcessedHtml = [parser initiallyProcessHtml:currentHtml];
  [parser replaceWholeFromHtml:initiallyProcessedHtml];

  textView.selectedRange = prevSelectedRange;
  [self anyTextMayHaveBeenModified];
}

- (void)onTextBlockTap:(TextBlockTapGestureRecognizer *)gr {
  if (gr.state != UIGestureRecognizerStateEnded)
    return;
  if (![self->textView isFirstResponder]) {
    [self->textView becomeFirstResponder];
  }

  switch (gr.tapKind) {

  case TextBlockTapKindCheckbox: {
    CheckboxListStyle *checkboxStyle =
        (CheckboxListStyle *)stylesDict[@([CheckboxListStyle getType])];

    if (checkboxStyle) {
      NSUInteger charIndex = (NSUInteger)gr.characterIndex;
      [checkboxStyle toggleCheckedAt:charIndex withDirtyRange:YES];
      [self anyTextMayHaveBeenModified];

      NSString *fullText = textView.textStorage.string;
      NSRange paragraphRange =
          [fullText paragraphRangeForRange:NSMakeRange(charIndex, 0)];
      NSUInteger endOfLineIndex = NSMaxRange(paragraphRange);

      // If the paragraph ends with a newline, step back by 1 so the cursor
      // stays on the current line instead of jumping to the next one.
      if (endOfLineIndex > 0 && endOfLineIndex <= fullText.length) {
        unichar lastChar = [fullText characterAtIndex:endOfLineIndex - 1];
        if ([[NSCharacterSet newlineCharacterSet] characterIsMember:lastChar]) {
          endOfLineIndex--;
        }
      }

      // Move the cursor to the end of the currently tapped checkbox line.
      // Without this, the cursor may remain at its previous position,
      // potentially inside a different checkbox line.
      textView.selectedRange = NSMakeRange(endOfLineIndex, 0);
    }
    break;
  }

  case TextBlockTapKindTable: {
    TableCellHitResult *hit = gr.tableHit;
    if (hit == nil) {
      break;
    }
    // Select the table's Object Replacement Character so the table reads as
    // "active": JS keys the toolbar's table controls off this 1-char selection
    // and clears them when the next selection change doesn't match.
    NSUInteger loc = (NSUInteger)hit.charIndex;
    if (loc < textView.textStorage.length) {
      textView.selectedRange = NSMakeRange(loc, 1);
    }
    // Cell frame: text-view space → outer view (self) space, matching how
    // onChangeSelection reports its rect, so the JS inline cell editor lands
    // over the tapped cell after any scroll.
    CGRect rectInSelf = [textView convertRect:hit.cellRect toView:self];
    auto emitter = [self getEventEmitter];
    if (emitter != nullptr) {
      emitter->onTableCellTap(
          {.charIndex = static_cast<int>(hit.charIndex),
           .tableIndex = static_cast<int>(hit.tableIndex),
           .row = static_cast<int>(hit.row),
           .col = static_cast<int>(hit.col),
           .x = static_cast<Float>(rectInSelf.origin.x),
           .y = static_cast<Float>(rectInSelf.origin.y),
           .width = static_cast<Float>(rectInSelf.size.width),
           .height = static_cast<Float>(rectInSelf.size.height),
           .colFractions = katavFractionsString(hit.columnFractions)});
    }
    break;
  }

  default:
    break;
  }
}

// Programmatically focus a table cell (no tap) and report it the same way
// onTextBlockTap does — used by the JS Tab-to-next-cell navigation. Reads the
// live cell geometry so it's correct after re-renders.
- (void)focusTableCellAtIndex:(NSInteger)tableIndex
                          row:(NSInteger)row
                          col:(NSInteger)col {
  TableCellHitResult *hit = [TableCellHitTestUtils cellAtTableIndex:tableIndex
                                                                row:row
                                                                col:col
                                                            inInput:self];
  if (hit == nil) {
    return;
  }
  // NOTE: deliberately does NOT call becomeFirstResponder. This is driven by
  // Tab from the JS inline cell editor (a separate RN TextInput overlay that
  // holds the keyboard); grabbing first responder for the native editor here
  // steals focus mid-handoff and drops the keyboard on the next cell. Setting
  // selectedRange doesn't require first responder.
  NSUInteger loc = (NSUInteger)hit.charIndex;
  if (loc < textView.textStorage.length) {
    textView.selectedRange = NSMakeRange(loc, 1);
  }
  CGRect rectInSelf = [textView convertRect:hit.cellRect toView:self];
  auto emitter = [self getEventEmitter];
  if (emitter != nullptr) {
    emitter->onTableCellTap(
        {.charIndex = static_cast<int>(hit.charIndex),
         .tableIndex = static_cast<int>(tableIndex),
         .row = static_cast<int>(row),
         .col = static_cast<int>(col),
         .x = static_cast<Float>(rectInSelf.origin.x),
         .y = static_cast<Float>(rectInSelf.origin.y),
         .width = static_cast<Float>(rectInSelf.size.width),
         .height = static_cast<Float>(rectInSelf.size.height),
         .colFractions = katavFractionsString(hit.columnFractions)});
  }
}

- (void)textStorage:(NSTextStorage *)textStorage
    didProcessEditing:(NSTextStorageEditActions)editedMask
                range:(NSRange)editedRange
       changeInLength:(NSInteger)delta {
  // iOS replacing quick double space with ". " attributes fix.
  [DotReplacementUtils handleDotReplacement:self
                                textStorage:textStorage
                                 editedMask:editedMask
                                editedRange:editedRange
                                      delta:delta];

  // Needed dirty ranges adjustments happen on every character edition.
  if ((editedMask & NSTextStorageEditedCharacters) != 0) {
    // Re-stamp custom meta-attributes captured in shouldChangeTextInRange: onto
    // the new range so autocorrect/predictive replacements keep their styling.
    if (_capturedAttributesBeforeChange != nil) {
      // Skip while an IME composition is in progress; restamp on commit.
      if (textView.markedTextRange == nil) {
        NSSet *customKeys = [attributesManager customAttributesKeys];
        for (NSString *key in _capturedAttributesBeforeChange) {
          if ([customKeys containsObject:key]) {
            [textStorage addAttribute:key
                                value:_capturedAttributesBeforeChange[key]
                                range:editedRange];
          }
        }
      }

      // Clear after consuming
      _capturedAttributesBeforeChange = nil;
    }
    // Always try shifting dirty ranges (happens only with delta != 0).
    [attributesManager shiftDirtyRangesWithEditedRange:editedRange
                                        changeInLength:delta];

    // Add dirty ranges. We also add zero-length ranges because they are useful
    // for word modification-based changes.
    [attributesManager addDirtyRange:editedRange];
  }
}

// MARK: - Media attachments delegate

- (void)mediaAttachmentDidUpdate:(MediaAttachment *)attachment {
  [AttachmentLayoutUtils handleAttachmentUpdate:attachment
                                       textView:textView
                                  onLayoutBlock:^{
                                    [self layoutAttachments];
                                  }];
}

// MARK: - Image/GIF Overlay Management

- (void)layoutAttachments {
  _attachmentViews =
      [AttachmentLayoutUtils layoutAttachmentsInTextView:textView
                                                  config:config
                                           existingViews:_attachmentViews];
}
@end
