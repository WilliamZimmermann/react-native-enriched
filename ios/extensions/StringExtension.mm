#import "StringExtension.h"

@implementation NSString (StringExtension)

- (std::string)toCppString {
  return std::string([self UTF8String]);
}

+ (NSString *)fromCppString:(std::string)string {
  return [NSString stringWithUTF8String:string.c_str()];
}

+ (NSString *)stringByEscapingHtml:(NSString *)html {
  NSMutableString *escaped = [html mutableCopy];
  NSDictionary *escapeMap = @{
    @"&" : @"&amp;",
    @"<" : @"&lt;",
    @">" : @"&gt;",
  };

  for (NSString *key in escapeMap) {
    [escaped replaceOccurrencesOfString:key
                             withString:escapeMap[key]
                                options:NSLiteralSearch
                                  range:NSMakeRange(0, escaped.length)];
  }
  return escaped;
}

/// A Unicode scalar as a string, or nil when the value is not a legal scalar.
static NSString *KatavStringFromCodepoint(UTF32Char codepoint) {
  // Surrogates are only meaningful as a pair inside UTF-16; a lone one here
  // would be a malformed document, and NSString would reject the bytes.
  if (codepoint == 0 || codepoint > 0x10FFFF ||
      (codepoint >= 0xD800 && codepoint <= 0xDFFF)) {
    return nil;
  }

  UTF32Char value = NSSwapHostIntToLittle(codepoint);
  return [[NSString alloc] initWithBytes:&value
                                  length:sizeof(value)
                                encoding:NSUTF32LittleEndianStringEncoding];
}

+ (NSDictionary *)getEscapedCharactersInfoFrom:(NSString *)text {
  NSDictionary *unescapeMap = @{
    @"&amp;" : @"&",
    @"&lt;" : @"<",
    @"&gt;" : @">",
  };

  NSMutableDictionary *results = [[NSMutableDictionary alloc] init];

  for (NSString *key in unescapeMap) {
    NSRange searchRange = NSMakeRange(0, text.length);
    NSRange foundRange;

    while (searchRange.location < text.length) {
      foundRange = [text rangeOfString:key options:0 range:searchRange];
      if (foundRange.location == NSNotFound) {
        break;
      }
      results[@(foundRange.location)] = @[ key, unescapeMap[key] ];
      searchRange.location = foundRange.location + foundRange.length;
      searchRange.length = text.length - searchRange.location;
    }
  }

  // Numeric character references, decimal (&#231;) and hex (&#xE7;).
  //
  // Only the three named entities above were decoded, so everything else came
  // through as literal text. That is invisible until a document written
  // somewhere else arrives: Android's serializer escapes EVERY non-ASCII
  // character this way, so a note edited on Android and then opened in this
  // editor showed "Nota&#231;&#227;o" instead of "Notação". The read-only
  // viewer never showed it because that one is JavaScript and decodes numeric
  // references already.
  static NSRegularExpression *numericEntity = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    numericEntity = [NSRegularExpression
        regularExpressionWithPattern:@"&#([0-9]+);|&#[xX]([0-9a-fA-F]+);"
                             options:0
                               error:nil];
  });

  [numericEntity
      enumerateMatchesInString:text
                       options:0
                         range:NSMakeRange(0, text.length)
                    usingBlock:^(NSTextCheckingResult *match,
                                 NSMatchingFlags flags, BOOL *stop) {
                      NSRange decimal = [match rangeAtIndex:1];
                      NSRange hex = [match rangeAtIndex:2];

                      unsigned long long codepoint = 0;
                      if (decimal.location != NSNotFound) {
                        codepoint = strtoull(
                            [[text substringWithRange:decimal] UTF8String],
                            NULL, 10);
                      } else if (hex.location != NSNotFound) {
                        codepoint =
                            strtoull([[text substringWithRange:hex] UTF8String],
                                     NULL, 16);
                      }

                      NSString *decoded =
                          KatavStringFromCodepoint((UTF32Char)codepoint);
                      if (decoded == nil) {
                        // Leave an undecodable reference as written rather than
                        // dropping the characters it stands for.
                        return;
                      }

                      // A named entity already claimed this index only if the
                      // document is double-escaped ("&amp;#231;"), and there
                      // the "&amp;" reading is the correct one — so it wins.
                      NSNumber *key = @(match.range.location);
                      if (results[key] != nil)
                        return;

                      results[key] =
                          @[ [text substringWithRange:match.range], decoded ];
                    }];

  return results;
}

@end

@implementation NSMutableString (StringExtension)

- (std::string)toCppString {
  return std::string([self UTF8String]);
}

+ (NSMutableString *)fromCppString:(std::string)string {
  return [NSMutableString stringWithUTF8String:string.c_str()];
}

@end
