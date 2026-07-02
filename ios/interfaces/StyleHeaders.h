#pragma once
#import "AiMarkParams.h"
#import "ImageData.h"
#import "LinkData.h"
#import "MentionParams.h"
#import "StyleBase.h"
#import "TableData.h"

@interface BoldStyle : StyleBase
@end

@interface ItalicStyle : StyleBase
@end

@interface UnderlineStyle : StyleBase
@end

@interface StrikethroughStyle : StyleBase
@end

@interface InlineCodeStyle : StyleBase
@end

@interface LinkStyle : StyleBase
- (void)addLink:(LinkData *)linkData
            range:(NSRange)range
    withSelection:(BOOL)withSelection;
- (LinkData *)getLinkDataAt:(NSUInteger)location;
- (NSRange)getFullLinkRangeAt:(NSUInteger)location;
- (void)handleAutomaticLinks:(NSString *)word inRange:(NSRange)wordRange;
- (void)handleManualLinks:(NSString *)word inRange:(NSRange)wordRange;
- (void)applyLinkMetaWithData:(LinkData *)linkData range:(NSRange)range;
@end

@interface MentionStyle : StyleBase
- (void)addMention:(NSString *)indicator
              text:(NSString *)text
        attributes:(NSString *)attributes;
- (void)addMentionAtRange:(NSRange)range params:(MentionParams *)params;
- (void)startMentionWithIndicator:(NSString *)indicator;
- (void)handleExistingMentions;
- (void)manageMentionEditing;
- (MentionParams *)getMentionParamsAt:(NSUInteger)location;
- (NSRange)getFullMentionRangeAt:(NSUInteger)location;
- (NSValue *)getActiveMentionRange;
- (void)applyMentionMeta:(MentionParams *)params range:(NSRange)range;
@end

@interface HeadingStyleBase : StyleBase
- (CGFloat)getHeadingFontSize;
- (BOOL)isHeadingBold;
- (BOOL)handleNewlinesInRange:(NSRange)range replacementText:(NSString *)text;
@end

@interface H1Style : HeadingStyleBase
@end

@interface H2Style : HeadingStyleBase
@end

@interface H3Style : HeadingStyleBase
@end

@interface H4Style : HeadingStyleBase
@end

@interface H5Style : HeadingStyleBase
@end

@interface H6Style : HeadingStyleBase
@end

@interface UnorderedListStyle : StyleBase
@end

@interface OrderedListStyle : StyleBase
@end

@interface CheckboxListStyle : StyleBase
- (void)toggleWithChecked:(BOOL)checked range:(NSRange)range;
- (void)addWithChecked:(BOOL)checked
                 range:(NSRange)range
            withTyping:(BOOL)withTyping
        withDirtyRange:(BOOL)withDirtyRange;
- (void)toggleCheckedAt:(NSUInteger)location
         withDirtyRange:(BOOL)withDirtyRange;
- (BOOL)getCheckboxStateAt:(NSUInteger)location;
- (BOOL)handleNewlinesInRange:(NSRange)range replacementText:(NSString *)text;
@end

@interface AlignmentStyle : StyleBase
- (void)addAlignment:(NSTextAlignment)alignment
               range:(NSRange)range
          withTyping:(BOOL)withTyping
      withDirtyRange:(BOOL)withDirtyRange;
- (NSString *)getStyleState;
@end

@interface BlockQuoteStyle : StyleBase
@end

@interface CodeBlockStyle : StyleBase
@end

@interface ImageStyle : StyleBase
- (void)addImage:(NSString *)uri width:(CGFloat)width height:(CGFloat)height;
- (void)addImageAtRange:(NSRange)range
              imageData:(ImageData *)imageData
          withSelection:(BOOL)withSelection
         withDirtyRange:(BOOL)withDirtyRange;
- (ImageData *)getImageDataAt:(NSUInteger)location;
- (void)setSelectedImageCaption:(NSString *)caption;
@end

@interface TableStyle : StyleBase
- (void)addTableAtRange:(NSRange)range
              tableData:(TableData *)tableData
          withSelection:(BOOL)withSelection
         withDirtyRange:(BOOL)withDirtyRange;
- (TableData *)getTableDataAt:(NSUInteger)location;
@end

@interface HighlightStyle : StyleBase
- (void)addHighlightAtRange:(NSRange)range color:(UIColor *)color;
- (void)removeHighlightInRange:(NSRange)range;
- (UIColor *)getHighlightColorAt:(NSUInteger)location;
@end

@interface HorizontalRuleStyle : StyleBase
// Inserts a horizontal rule (`<hr>`) as a single object-replacement character
// carrying a HorizontalRuleAttachment that draws a full-width divider line.
// The rule is forced onto its own line (newlines added around it as needed).
- (void)insertHorizontalRule;
- (void)addHorizontalRuleAtRange:(NSRange)range
                   withSelection:(BOOL)withSelection
                  withDirtyRange:(BOOL)withDirtyRange;
// YES when the location carries the horizontal-rule attribute.
- (BOOL)isHorizontalRuleAt:(NSUInteger)location;
@end

// Shared base for the two AI track-changes marks. `getKey`/`aiKind` and the
// pending/accepted visual are provided by the concrete subclasses below.
@interface AiMarkStyle : StyleBase
// 'suggestion' | 'flag' — used by the tap handler to label the emitted event.
- (NSString *)aiKind;
// Payload at a location (nil when the location carries no mark of this kind).
- (AiMarkParams *)paramsAt:(NSUInteger)location;
// Apply the mark (with payload) over an explicit range (the enrich apply
// phase).
- (void)applyAiMarkAtRange:(NSRange)range params:(AiMarkParams *)params;
// Review actions keyed by aiId.
- (void)acceptId:(NSString *)aiId; // status -> accepted, keep text + mark
- (void)stripId:
    (NSString *)aiId; // remove mark, keep text (claim / flag reject)
- (void)deleteId:(NSString *)aiId; // delete the marked text (suggestion reject)
// Bulk actions over every pending mark of this kind.
- (void)acceptAllPending;
- (void)deleteAllPending;
- (void)stripAllPending;
@end

@interface AiSuggestionStyle : AiMarkStyle
@end

@interface AiFlagStyle : AiMarkStyle
@end
