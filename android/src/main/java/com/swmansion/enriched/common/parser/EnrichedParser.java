package com.swmansion.enriched.common.parser;

import android.graphics.Color;
import android.text.Editable;
import android.text.Spannable;
import android.text.SpannableStringBuilder;
import android.text.Spanned;
import android.text.TextUtils;
import android.text.style.ParagraphStyle;
import com.swmansion.enriched.common.EnrichedConstants;
import com.swmansion.enriched.common.spans.EnrichedAlignmentSpan;
import com.swmansion.enriched.common.spans.EnrichedBoldSpan;
import com.swmansion.enriched.common.spans.EnrichedCheckboxListSpan;
import com.swmansion.enriched.common.spans.EnrichedCodeBlockSpan;
import com.swmansion.enriched.common.spans.EnrichedDirectionSpan;
import com.swmansion.enriched.common.spans.EnrichedH1Span;
import com.swmansion.enriched.common.spans.EnrichedH2Span;
import com.swmansion.enriched.common.spans.EnrichedH3Span;
import com.swmansion.enriched.common.spans.EnrichedH4Span;
import com.swmansion.enriched.common.spans.EnrichedH5Span;
import com.swmansion.enriched.common.spans.EnrichedH6Span;
import com.swmansion.enriched.common.spans.EnrichedImageSpan;
import com.swmansion.enriched.common.spans.EnrichedInlineCodeSpan;
import com.swmansion.enriched.common.spans.EnrichedItalicSpan;
import com.swmansion.enriched.common.spans.EnrichedLinkSpan;
import com.swmansion.enriched.common.spans.EnrichedMentionSpan;
import com.swmansion.enriched.common.spans.EnrichedOrderedListSpan;
import com.swmansion.enriched.common.spans.EnrichedStrikeThroughSpan;
import com.swmansion.enriched.common.spans.EnrichedFontSizeSpan;
import com.swmansion.enriched.common.spans.EnrichedHighlightSpan;
import com.swmansion.enriched.common.spans.EnrichedSubscriptSpan;
import com.swmansion.enriched.common.spans.EnrichedSuperscriptSpan;
import com.swmansion.enriched.common.spans.EnrichedTableData;
import com.swmansion.enriched.common.spans.EnrichedTableSpan;
import com.swmansion.enriched.common.spans.EnrichedTextColorSpan;
import com.swmansion.enriched.common.spans.EnrichedUnderlineSpan;
import com.swmansion.enriched.common.spans.EnrichedUnorderedListSpan;
import com.swmansion.enriched.common.spans.interfaces.EnrichedBlockSpan;
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan;
import com.swmansion.enriched.common.spans.interfaces.EnrichedParagraphSpan;
import com.swmansion.enriched.common.spans.interfaces.EnrichedSpan;
import com.swmansion.enriched.common.spans.interfaces.EnrichedZeroWidthSpaceSpan;
import java.io.IOException;
import java.io.StringReader;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.ccil.cowan.tagsoup.HTMLSchema;
import org.ccil.cowan.tagsoup.Parser;
import org.xml.sax.Attributes;
import org.xml.sax.ContentHandler;
import org.xml.sax.InputSource;
import org.xml.sax.Locator;
import org.xml.sax.SAXException;
import org.xml.sax.SAXNotRecognizedException;
import org.xml.sax.SAXNotSupportedException;
import org.xml.sax.XMLReader;

/**
 * Most of the code in this file is copied from the Android source code and adjusted to our needs.
 * For the reference see <a
 * href="https://android.googlesource.com/platform/frameworks/base/+/refs/heads/master/core/java/android/text/Html.java">docs</a>
 */
public class EnrichedParser {
  /** Retrieves images for HTML &lt;img&gt; tags. */
  private EnrichedParser() {}

  /**
   * Lazy initialization holder for HTML parser. This class will a) be preloaded by the zygote, or
   * b) not loaded until absolutely necessary.
   */
  private static class HtmlParser {
    private static final HTMLSchema schema = new HTMLSchema();
  }

  public static <T> Spanned fromHtml(String source, T style, EnrichedSpanFactory<T> spanFactory) {
    Parser parser = new Parser();
    try {
      parser.setProperty(Parser.schemaProperty, HtmlParser.schema);
    } catch (SAXNotRecognizedException | SAXNotSupportedException e) {
      // Should not happen.
      throw new RuntimeException(e);
    }
    HtmlToSpannedConverter converter =
        new HtmlToSpannedConverter(source, style, parser, spanFactory);
    return converter.convert();
  }

  public static String toHtml(Spanned text) {
    StringBuilder out = new StringBuilder();
    withinHtml(out, text);
    String outString = out.toString();

    // Codeblocks and blockquotes appends a newline character by default, so we have to remove it
    String normalizedCodeBlock = outString.replaceAll("</codeblock>\\n<br>", "</codeblock>");
    String normalizedBlockQuote =
        normalizedCodeBlock.replaceAll("</blockquote>\\n<br>", "</blockquote>");

    // Replace empty <p> tags (with or without style attributes) with <br>
    String normalizedHtml = normalizedBlockQuote.replaceAll("<p[^>]*></p>", "<br>");

    // A table stands on its own. It rides in the text as a single object
    // character, so it comes out wrapped in the paragraph that held it.
    String normalizedTables =
        normalizedHtml.replaceAll("<p[^>]*>\\s*(<table[\\s\\S]*?</table>)\\s*</p>", "$1");

    return "<html>\n" + normalizedTables + "</html>";
  }

  public static String toHtmlWithDefault(CharSequence text) {
    if (text instanceof Spanned) {
      return toHtml((Spanned) text);
    }
    return "<html>\n<p></p>\n</html>";
  }

  /** Returns an HTML escaped representation of the given plain text. */
  public static String escapeHtml(CharSequence text) {
    StringBuilder out = new StringBuilder();
    withinStyle(out, text, 0, text.length());
    return out.toString();
  }

  private static void withinHtml(StringBuilder out, Spanned text) {
    withinDiv(out, text, 0, text.length());
  }

  private static void withinDiv(StringBuilder out, Spanned text, int start, int end) {
    int next;
    for (int i = start; i < end; i = next) {
      next = text.nextSpanTransition(i, end, EnrichedBlockSpan.class);
      EnrichedBlockSpan[] blocks = text.getSpans(i, next, EnrichedBlockSpan.class);
      String tag = "unknown";
      if (blocks.length > 0) {
        tag = blocks[0] instanceof EnrichedCodeBlockSpan ? "codeblock" : "blockquote";
      }

      // Each block appends a newline by default.
      // If we set up a new block, we have to remove the last  character.
      if (out.length() >= 5 && out.substring(out.length() - 5).equals("<br>\n")) {
        out.replace(out.length() - 5, out.length(), "");
      }

      for (EnrichedBlockSpan ignored : blocks) {
        out.append("<").append(tag).append(">\n");
      }
      withinBlock(out, text, i, next);
      for (EnrichedBlockSpan ignored : blocks) {
        out.append("</").append(tag).append(">\n");
      }
    }
  }

  private static String getAlignmentStyleAttr(Spanned text, int start, int end) {
    EnrichedAlignmentSpan[] spans = text.getSpans(start, end, EnrichedAlignmentSpan.class);
    if (spans.length == 0) return "";
    String cssValue = spans[0].getCssValue();
    if (cssValue.equals("auto")) return "";
    return " style=\"text-align: " + cssValue + "\"";
  }

  private static String getDirectionAttr(Spanned text, int start, int end) {
    EnrichedDirectionSpan[] spans = text.getSpans(start, end, EnrichedDirectionSpan.class);
    if (spans.length == 0) return "";
    String cssValue = spans[0].getCssValue();
    // "auto" is the platform default and is emitted as the absence of a dir attribute.
    if (cssValue.equals("auto")) return "";
    return " dir=\"" + cssValue + "\"";
  }

  private static String getBlockTag(EnrichedParagraphSpan[] spans) {
    for (EnrichedParagraphSpan span : spans) {
      if (span instanceof EnrichedUnorderedListSpan) {
        return "ul";
      } else if (span instanceof EnrichedOrderedListSpan) {
        return "ol";
      } else if (span instanceof EnrichedCheckboxListSpan) {
        return "ul data-type=\"checkbox\"";
      } else if (span instanceof EnrichedH1Span) {
        return "h1";
      } else if (span instanceof EnrichedH2Span) {
        return "h2";
      } else if (span instanceof EnrichedH3Span) {
        return "h3";
      } else if (span instanceof EnrichedH4Span) {
        return "h4";
      } else if (span instanceof EnrichedH5Span) {
        return "h5";
      } else if (span instanceof EnrichedH6Span) {
        return "h6";
      }
    }

    return "p";
  }

  private static void withinBlock(StringBuilder out, Spanned text, int start, int end) {
    boolean isInUlList = false;
    boolean isInOlList = false;
    boolean isInCheckboxList = false;

    int next;
    for (int i = start; i <= end; i = next) {
      next = TextUtils.indexOf(text, '\n', i, end);
      if (next < 0) {
        next = end;
      }
      if (next == i) {
        if (isInUlList) {
          // Current paragraph is no longer a list item; close the previously opened list
          isInUlList = false;
          out.append("</ul>\n");
        } else if (isInOlList) {
          // Current paragraph is no longer a list item; close the previously opened list
          isInOlList = false;
          out.append("</ol>\n");
        } else if (isInCheckboxList) {
          // Current paragraph is no longer a list item; close the previously opened list
          isInCheckboxList = false;
          out.append("</ul>\n");
        }
        out.append("<br>\n");
      } else {
        EnrichedParagraphSpan[] paragraphStyles =
            text.getSpans(i, next, EnrichedParagraphSpan.class);
        String tag = getBlockTag(paragraphStyles);
        boolean isUlListItem = tag.equals("ul");
        boolean isOlListItem = tag.equals("ol");
        boolean isCheckboxListItem = tag.equals("ul data-type=\"checkbox\"");

        if (isInUlList && !isUlListItem) {
          // Current paragraph is no longer a list item; close the previously opened list
          isInUlList = false;
          out.append("</ul>\n");
        } else if (isInOlList && !isOlListItem) {
          // Current paragraph is no longer a list item; close the previously opened list
          isInOlList = false;
          out.append("</ol>\n");
        } else if (isInCheckboxList && !isCheckboxListItem) {
          // Current paragraph is no longer a list item; close the previously opened list
          isInCheckboxList = false;
          out.append("</ul>\n");
        }

        if (isUlListItem && !isInUlList) {
          // Current paragraph is the first item in a list
          isInUlList = true;
          out.append("<ul")
              .append(getAlignmentStyleAttr(text, i, next))
              .append(getDirectionAttr(text, i, next))
              .append(">\n");
        } else if (isOlListItem && !isInOlList) {
          // Current paragraph is the first item in a list
          isInOlList = true;
          out.append("<ol")
              .append(getAlignmentStyleAttr(text, i, next))
              .append(getDirectionAttr(text, i, next))
              .append(">\n");
        } else if (isCheckboxListItem && !isInCheckboxList) {
          // Current paragraph is the first item in a list
          isInCheckboxList = true;
          out.append("<ul data-type=\"checkbox\"")
              .append(getAlignmentStyleAttr(text, i, next))
              .append(getDirectionAttr(text, i, next))
              .append(">\n");
        }

        boolean isList = isUlListItem || isOlListItem || isCheckboxListItem;
        String tagType = isList ? "li" : tag;

        out.append("<");
        out.append(tagType);

        // Add alignment style and writing direction to non-list paragraph/heading tags
        if (!isList) {
          out.append(getAlignmentStyleAttr(text, i, next));
          out.append(getDirectionAttr(text, i, next));
        }

        if (isCheckboxListItem) {
          EnrichedCheckboxListSpan[] checkboxSpans =
              text.getSpans(i, next, EnrichedCheckboxListSpan.class);
          if (checkboxSpans.length > 0) {
            boolean isChecked = checkboxSpans[0].isChecked();
            if (isChecked) out.append(" checked");
          }
        }

        out.append(">");
        withinParagraph(out, text, i, next);
        out.append("</");
        out.append(tagType);
        out.append(">\n");
        if (next == end && isInUlList) {
          isInUlList = false;
          out.append("</ul>\n");
        } else if (next == end && isInOlList) {
          isInOlList = false;
          out.append("</ol>\n");
        } else if (next == end && isInCheckboxList) {
          isInCheckboxList = false;
          out.append("</ul>\n");
        }
      }
      next++;
    }
  }

  private static void withinParagraph(StringBuilder out, Spanned text, int start, int end) {
    int next;
    for (int i = start; i < end; i = next) {
      next = text.nextSpanTransition(i, end, EnrichedInlineSpan.class);
      EnrichedInlineSpan[] style = text.getSpans(i, next, EnrichedInlineSpan.class);
      for (int j = 0; j < style.length; j++) {
        if (style[j] instanceof EnrichedBoldSpan) {
          out.append("<b>");
        }
        if (style[j] instanceof EnrichedItalicSpan) {
          out.append("<i>");
        }
        if (style[j] instanceof EnrichedUnderlineSpan) {
          out.append("<u>");
        }
        if (style[j] instanceof EnrichedTextColorSpan) {
          out.append("<span style=\"color:");
          out.append(((EnrichedTextColorSpan) style[j]).getColorHex());
          out.append(";\">");
        }
        if (style[j] instanceof EnrichedFontSizeSpan) {
          // TipTap's FontSize mark shape, also what iOS emits.
          out.append("<span style=\"font-size:");
          out.append(((EnrichedFontSizeSpan) style[j]).getSizeCss());
          out.append("px;\">");
        }
        if (style[j] instanceof EnrichedSubscriptSpan) {
          out.append("<sub>");
        }
        if (style[j] instanceof EnrichedSuperscriptSpan) {
          out.append("<sup>");
        }
        if (style[j] instanceof EnrichedHighlightSpan) {
          // Same shape iOS emits and TipTap writes, so a highlighted note
          // round-trips between phone, tablet and web unchanged.
          out.append("<mark style=\"background-color:");
          out.append(((EnrichedHighlightSpan) style[j]).getColorHex());
          out.append(";\">");
        }
        if (style[j] instanceof EnrichedInlineCodeSpan) {
          out.append("<code>");
        }
        if (style[j] instanceof EnrichedStrikeThroughSpan) {
          out.append("<s>");
        }
        if (style[j] instanceof EnrichedLinkSpan) {
          out.append("<a href=\"");
          out.append(((EnrichedLinkSpan) style[j]).getUrl());
          out.append("\">");
        }
        if (style[j] instanceof EnrichedMentionSpan) {
          out.append("<mention text=\"");
          out.append(((EnrichedMentionSpan) style[j]).getText());
          out.append("\"");

          out.append(" indicator=\"");
          out.append(((EnrichedMentionSpan) style[j]).getIndicator());
          out.append("\"");

          Map<String, String> attributes = ((EnrichedMentionSpan) style[j]).getAttributes();
          for (Map.Entry<String, String> entry : attributes.entrySet()) {
            out.append(" ");
            out.append(entry.getKey());
            out.append("=\"");
            out.append(entry.getValue());
            out.append("\"");
          }

          out.append(">");
        }
        if (style[j] instanceof EnrichedTableSpan) {
          // Verbatim: the table was never decomposed, so nothing to rebuild.
          out.append(((EnrichedTableSpan) style[j]).getData().getRawHtml());
          i = next;
        }
        if (style[j] instanceof EnrichedImageSpan) {
          out.append("<img src=\"");
          out.append(((EnrichedImageSpan) style[j]).getSource());
          out.append("\"");

          out.append(" width=\"");
          out.append(((EnrichedImageSpan) style[j]).getWidth());
          out.append("\"");

          out.append(" height=\"");
          out.append(((EnrichedImageSpan) style[j]).getHeight());

          out.append("\"/>");
          // Don't output the placeholder character underlying the image.
          i = next;
        }
      }
      withinStyle(out, text, i, next);
      for (int j = style.length - 1; j >= 0; j--) {
        if (style[j] instanceof EnrichedLinkSpan) {
          out.append("</a>");
        }
        if (style[j] instanceof EnrichedMentionSpan) {
          out.append("</mention>");
        }
        if (style[j] instanceof EnrichedStrikeThroughSpan) {
          out.append("</s>");
        }
        if (style[j] instanceof EnrichedHighlightSpan) {
          out.append("</mark>");
        }
        if (style[j] instanceof EnrichedTextColorSpan) {
          out.append("</span>");
        }
        if (style[j] instanceof EnrichedFontSizeSpan) {
          out.append("</span>");
        }
        if (style[j] instanceof EnrichedSubscriptSpan) {
          out.append("</sub>");
        }
        if (style[j] instanceof EnrichedSuperscriptSpan) {
          out.append("</sup>");
        }
        if (style[j] instanceof EnrichedUnderlineSpan) {
          out.append("</u>");
        }
        if (style[j] instanceof EnrichedInlineCodeSpan) {
          out.append("</code>");
        }
        if (style[j] instanceof EnrichedBoldSpan) {
          out.append("</b>");
        }
        if (style[j] instanceof EnrichedItalicSpan) {
          out.append("</i>");
        }
      }
    }
  }

  private static void withinStyle(StringBuilder out, CharSequence text, int start, int end) {
    for (int i = start; i < end; i++) {
      char c = text.charAt(i);
      if (c == EnrichedConstants.ZWS) {
        // Do not output zero-width space characters.
        continue;
      } else if (c == '<') {
        out.append("&lt;");
      } else if (c == '>') {
        out.append("&gt;");
      } else if (c == '&') {
        out.append("&amp;");
      } else if (c >= 0xD800 && c <= 0xDFFF) {
        if (c < 0xDC00 && i + 1 < end) {
          char d = text.charAt(i + 1);
          if (d >= 0xDC00 && d <= 0xDFFF) {
            i++;
            int codepoint = 0x010000 | (int) c - 0xD800 << 10 | (int) d - 0xDC00;
            out.append("&#").append(codepoint).append(";");
          }
        }
      } else if (c > 0x7E || c < ' ') {
        out.append("&#").append((int) c).append(";");
      } else if (c == ' ') {
        while (i + 1 < end && text.charAt(i + 1) == ' ') {
          out.append("&nbsp;");
          i++;
        }
        out.append(' ');
      } else {
        out.append(c);
      }
    }
  }
}

class HtmlToSpannedConverter<T> implements ContentHandler {
  private final EnrichedSpanFactory<T> mSpanFactory;
  private final T mStyle;
  private final String mSource;
  private final XMLReader mReader;
  private final SpannableStringBuilder mSpannableStringBuilder;
  private static Integer currentOrderedListItemIndex = 0;
  private static Boolean isInOrderedList = false;
  private static Boolean isInCheckboxList = false;
  private static Boolean isEmptyTag = false;
  private static String currentListAlignmentCssValue = null;
  private static String currentListDirectionValue = null;

  /**
   * Raw `<table>…</table>` blocks, in source order, and how many have been
   * consumed.
   *
   * TagSoup hands over tags one at a time, so the original markup is gone by
   * the time `<table>` arrives. Tables are round-tripped VERBATIM (see
   * EnrichedTableData), so the source is scanned up front and the converter
   * takes the blocks in order, ignoring every event until the matching
   * `</table>`.
   */
  private final java.util.List<String> mTableHtml = new java.util.ArrayList<>();

  private int mTableIndex = 0;
  private int mTableDepth = 0;

  private static final Pattern TABLE_PATTERN =
      Pattern.compile("<table\\b[^>]*>[\\s\\S]*?</table>", Pattern.CASE_INSENSITIVE);

  private static final Pattern TABLE_ROW_PATTERN =
      Pattern.compile("<tr\\b[^>]*>([\\s\\S]*?)</tr>", Pattern.CASE_INSENSITIVE);

  private static final Pattern TABLE_CELL_PATTERN =
      Pattern.compile("<(?:td|th)\\b[^>]*>([\\s\\S]*?)</(?:td|th)>", Pattern.CASE_INSENSITIVE);

  /** Split a raw table into its cells, keeping each cell's inner HTML. */
  static EnrichedTableData buildTableData(String rawHtml) {
    java.util.List<java.util.List<String>> rows = new java.util.ArrayList<>();
    int colCount = 0;

    Matcher rowMatcher = TABLE_ROW_PATTERN.matcher(rawHtml);
    while (rowMatcher.find()) {
      java.util.List<String> cells = new java.util.ArrayList<>();
      Matcher cellMatcher = TABLE_CELL_PATTERN.matcher(rowMatcher.group(1));
      while (cellMatcher.find()) {
        cells.add(cellMatcher.group(1));
      }
      if (cells.size() > colCount) colCount = cells.size();
      rows.add(cells);
    }

    return new EnrichedTableData(rawHtml, rows, colCount);
  }

  private static final Pattern CSS_ALIGNMENT_PATTERN =
      Pattern.compile("text-align\\s*:\\s*(left|center|right)", Pattern.CASE_INSENSITIVE);

  private static String parseCssAlignmentValue(Attributes attributes) {
    String style = attributes.getValue("", "style");
    if (style == null) return null;
    Matcher m = CSS_ALIGNMENT_PATTERN.matcher(style);
    return m.find() ? m.group(1).toLowerCase() : null;
  }

  private static String parseDirectionValue(Attributes attributes) {
    String dir = attributes.getValue("", "dir");
    if (dir == null) return null;
    dir = dir.trim().toLowerCase();
    if (dir.equals("ltr") || dir.equals("rtl")) return dir;
    return null;
  }

  private static void pushAlignmentMark(Editable text, Attributes attributes) {
    String cssValue = parseCssAlignmentValue(attributes);
    if (cssValue != null) {
      start(text, new Alignment(cssValue));
    }
  }

  private static void pushDirectionMark(Editable text, Attributes attributes) {
    String value = parseDirectionValue(attributes);
    if (value != null) {
      start(text, new Direction(value));
    }
  }

  public HtmlToSpannedConverter(
      String source, T style, Parser parser, EnrichedSpanFactory<T> spanFactory) {
    mStyle = style;
    mSource = source;
    mSpannableStringBuilder = new SpannableStringBuilder();
    mReader = parser;
    mSpanFactory = spanFactory;

    if (source != null) {
      Matcher tableMatcher = TABLE_PATTERN.matcher(source);
      while (tableMatcher.find()) {
        mTableHtml.add(tableMatcher.group());
      }
    }
  }

  public Spanned convert() {
    mReader.setContentHandler(this);
    try {
      mReader.parse(new InputSource(new StringReader(mSource)));
    } catch (IOException e) {
      // We are reading from a string. There should not be IO problems.
      throw new RuntimeException(e);
    } catch (SAXException e) {
      // TagSoup doesn't throw parse exceptions.
      throw new RuntimeException(e);
    }
    // Fix flags and range for paragraph-type markup.
    Object[] obj =
        mSpannableStringBuilder.getSpans(0, mSpannableStringBuilder.length(), ParagraphStyle.class);
    for (int i = 0; i < obj.length; i++) {
      int start = mSpannableStringBuilder.getSpanStart(obj[i]);
      int end = mSpannableStringBuilder.getSpanEnd(obj[i]);
      // If the last line of the range is blank, back off by one.
      if (end - 2 >= 0) {
        if (mSpannableStringBuilder.charAt(end - 1) == '\n'
            && mSpannableStringBuilder.charAt(end - 2) == '\n') {
          end--;
        }
      }
      if (end == start) {
        mSpannableStringBuilder.removeSpan(obj[i]);
      } else {
        // TODO: verify if Spannable.SPAN_EXCLUSIVE_EXCLUSIVE does not break anything.
        // Previously it was SPAN_PARAGRAPH. I've changed that in order to fix ranges for list
        // items.
        mSpannableStringBuilder.setSpan(obj[i], start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
      }
    }

    // Assign zero-width space character to the proper spans.
    EnrichedZeroWidthSpaceSpan[] zeroWidthSpaceSpans =
        mSpannableStringBuilder.getSpans(
            0, mSpannableStringBuilder.length(), EnrichedZeroWidthSpaceSpan.class);
    for (EnrichedZeroWidthSpaceSpan zeroWidthSpaceSpan : zeroWidthSpaceSpans) {
      int start = mSpannableStringBuilder.getSpanStart(zeroWidthSpaceSpan);
      int end = mSpannableStringBuilder.getSpanEnd(zeroWidthSpaceSpan);

      if (mSpannableStringBuilder.charAt(start) != EnrichedConstants.ZWS) {
        // Collect spans before inserting ZWS. SPAN_EXCLUSIVE_EXCLUSIVE spans will
        // shift to start+1. We must re-anchor them back to `start` to prevent
        // the loop from processing them again and inserting duplicate ZWS.
        EnrichedSpan[] colocated =
            mSpannableStringBuilder.getSpans(start, start + 1, EnrichedSpan.class);

        mSpannableStringBuilder.insert(start, EnrichedConstants.ZWS_STRING);
        end++;

        for (EnrichedSpan span : colocated) {
          if (span == zeroWidthSpaceSpan) continue;
          // Only re-anchor spans that actually shifted.
          // Skip overlapping or INCLUSIVE spans that kept their original start.
          if (mSpannableStringBuilder.getSpanStart(span) != start + 1) continue;
          int spanEnd = mSpannableStringBuilder.getSpanEnd(span);
          mSpannableStringBuilder.removeSpan(span);
          mSpannableStringBuilder.setSpan(span, start, spanEnd, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
        }
      }

      mSpannableStringBuilder.removeSpan(zeroWidthSpaceSpan);
      mSpannableStringBuilder.setSpan(
          zeroWidthSpaceSpan, start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
    }

    return mSpannableStringBuilder;
  }

  private void handleStartTag(String tag, Attributes attributes) {
    if (tag.equalsIgnoreCase("br")) {
      // We don't need to handle this. TagSoup will ensure that there's a </br> for each <br>
      // so we can safely emit the linebreaks when we handle the close tag.
    } else if (tag.equalsIgnoreCase("p")) {
      isEmptyTag = true;
      startBlockElement(mSpannableStringBuilder);
      pushAlignmentMark(mSpannableStringBuilder, attributes);
      pushDirectionMark(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("ul")) {
      isInOrderedList = false;
      String dataType = attributes.getValue("", "data-type");
      isInCheckboxList = "checkbox".equals(dataType);
      currentListAlignmentCssValue = parseCssAlignmentValue(attributes);
      currentListDirectionValue = parseDirectionValue(attributes);
      startBlockElement(mSpannableStringBuilder);
    } else if (tag.equalsIgnoreCase("ol")) {
      isInOrderedList = true;
      currentOrderedListItemIndex = 0;
      currentListAlignmentCssValue = parseCssAlignmentValue(attributes);
      currentListDirectionValue = parseDirectionValue(attributes);
      startBlockElement(mSpannableStringBuilder);
    } else if (tag.equalsIgnoreCase("li")) {
      isEmptyTag = true;
      startLi(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("b")) {
      start(mSpannableStringBuilder, new Bold());
    } else if (tag.equalsIgnoreCase("i")) {
      start(mSpannableStringBuilder, new Italic());
    } else if (tag.equalsIgnoreCase("blockquote")) {
      isEmptyTag = true;
      startBlockquote(mSpannableStringBuilder);
    } else if (tag.equalsIgnoreCase("codeblock")) {
      isEmptyTag = true;
      startCodeBlock(mSpannableStringBuilder);
    } else if (tag.equalsIgnoreCase("a")) {
      startA(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("mark")) {
      start(mSpannableStringBuilder, new Highlight(parseHighlightColor(attributes)));
    } else if (tag.equalsIgnoreCase("span")) {
      // A styled <span> carries colour and/or size. Anything else is a plain
      // wrapper and contributes no span, but still has to push a mark so the
      // closing tag stays balanced.
      startStyledSpan(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("sub")) {
      start(mSpannableStringBuilder, new Subscript());
    } else if (tag.equalsIgnoreCase("sup")) {
      start(mSpannableStringBuilder, new Superscript());
    } else if (tag.equalsIgnoreCase("u")) {
      start(mSpannableStringBuilder, new Underline());
    } else if (tag.equalsIgnoreCase("s")) {
      start(mSpannableStringBuilder, new Strikethrough());
    } else if (tag.equalsIgnoreCase("strike")) {
      start(mSpannableStringBuilder, new Strikethrough());
    } else if (tag.equalsIgnoreCase("h1")) {
      startHeading(mSpannableStringBuilder, 1);
      pushAlignmentMark(mSpannableStringBuilder, attributes);
      pushDirectionMark(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("h2")) {
      startHeading(mSpannableStringBuilder, 2);
      pushAlignmentMark(mSpannableStringBuilder, attributes);
      pushDirectionMark(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("h3")) {
      startHeading(mSpannableStringBuilder, 3);
      pushAlignmentMark(mSpannableStringBuilder, attributes);
      pushDirectionMark(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("h4")) {
      startHeading(mSpannableStringBuilder, 4);
      pushAlignmentMark(mSpannableStringBuilder, attributes);
      pushDirectionMark(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("h5")) {
      startHeading(mSpannableStringBuilder, 5);
      pushAlignmentMark(mSpannableStringBuilder, attributes);
      pushDirectionMark(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("h6")) {
      startHeading(mSpannableStringBuilder, 6);
      pushAlignmentMark(mSpannableStringBuilder, attributes);
      pushDirectionMark(mSpannableStringBuilder, attributes);
    } else if (tag.equalsIgnoreCase("img")) {
      // Image content means the current tag is not empty (e.g. <li><img .../></li>).
      isEmptyTag = false;
      startImg(mSpannableStringBuilder, attributes, mSpanFactory);
    } else if (tag.equalsIgnoreCase("code")) {
      start(mSpannableStringBuilder, new Code());
    } else if (tag.equalsIgnoreCase("mention")) {
      startMention(mSpannableStringBuilder, attributes);
    }
  }

  private void handleEndTag(String tag) {
    if (tag.equalsIgnoreCase("br")) {
      handleBr(mSpannableStringBuilder);
    } else if (tag.equalsIgnoreCase("p")) {
      endBlockElement(mSpannableStringBuilder, mSpanFactory);
    } else if (tag.equalsIgnoreCase("ul")) {
      currentListAlignmentCssValue = null;
      currentListDirectionValue = null;
      endBlockElement(mSpannableStringBuilder, mSpanFactory);
    } else if (tag.equalsIgnoreCase("ol")) {
      currentListAlignmentCssValue = null;
      currentListDirectionValue = null;
      endBlockElement(mSpannableStringBuilder, mSpanFactory);
    } else if (tag.equalsIgnoreCase("li")) {
      endLi(mSpannableStringBuilder, mStyle, mSpanFactory);
    } else if (tag.equalsIgnoreCase("b")) {
      end(mSpannableStringBuilder, Bold.class, mSpanFactory.createBoldSpan(mStyle));
    } else if (tag.equalsIgnoreCase("i")) {
      end(mSpannableStringBuilder, Italic.class, mSpanFactory.createItalicSpan(mStyle));
    } else if (tag.equalsIgnoreCase("blockquote")) {
      endBlockquote(mSpannableStringBuilder, mStyle, mSpanFactory);
    } else if (tag.equalsIgnoreCase("codeblock")) {
      endCodeBlock(mSpannableStringBuilder, mStyle, mSpanFactory);
    } else if (tag.equalsIgnoreCase("a")) {
      endA(mSpannableStringBuilder, mStyle, mSpanFactory);
    } else if (tag.equalsIgnoreCase("mark")) {
      Object open = getLast(mSpannableStringBuilder, Highlight.class);
      int color = open instanceof Highlight ? ((Highlight) open).color : DEFAULT_HIGHLIGHT_COLOR;
      end(mSpannableStringBuilder, Highlight.class, new EnrichedHighlightSpan(color));
    } else if (tag.equalsIgnoreCase("span")) {
      endStyledSpan(mSpannableStringBuilder);
    } else if (tag.equalsIgnoreCase("sub")) {
      end(mSpannableStringBuilder, Subscript.class, new EnrichedSubscriptSpan());
    } else if (tag.equalsIgnoreCase("sup")) {
      end(mSpannableStringBuilder, Superscript.class, new EnrichedSuperscriptSpan());
    } else if (tag.equalsIgnoreCase("u")) {
      end(mSpannableStringBuilder, Underline.class, mSpanFactory.createUnderlineSpan(mStyle));
    } else if (tag.equalsIgnoreCase("s")) {
      end(
          mSpannableStringBuilder,
          Strikethrough.class,
          mSpanFactory.createStrikeThroughSpan(mStyle));
    } else if (tag.equalsIgnoreCase("h1")) {
      endHeading(mSpannableStringBuilder, mStyle, mSpanFactory, 1);
    } else if (tag.equalsIgnoreCase("h2")) {
      endHeading(mSpannableStringBuilder, mStyle, mSpanFactory, 2);
    } else if (tag.equalsIgnoreCase("h3")) {
      endHeading(mSpannableStringBuilder, mStyle, mSpanFactory, 3);
    } else if (tag.equalsIgnoreCase("h4")) {
      endHeading(mSpannableStringBuilder, mStyle, mSpanFactory, 4);
    } else if (tag.equalsIgnoreCase("h5")) {
      endHeading(mSpannableStringBuilder, mStyle, mSpanFactory, 5);
    } else if (tag.equalsIgnoreCase("h6")) {
      endHeading(mSpannableStringBuilder, mStyle, mSpanFactory, 6);
    } else if (tag.equalsIgnoreCase("code")) {
      end(mSpannableStringBuilder, Code.class, mSpanFactory.createInlineCodeSpan(mStyle));
    } else if (tag.equalsIgnoreCase("mention")) {
      endMention(mSpannableStringBuilder, mStyle, mSpanFactory);
    }
  }

  private static void appendNewlines(Editable text, int minNewline) {
    final int len = text.length();
    if (len == 0) {
      return;
    }
    int existingNewlines = 0;
    for (int i = len - 1; i >= 0 && text.charAt(i) == '\n'; i--) {
      existingNewlines++;
    }
    for (int j = existingNewlines; j < minNewline; j++) {
      text.append("\n");
    }
  }

  private static void startBlockElement(Editable text) {
    appendNewlines(text, 1);
    start(text, new Newline(1));
  }

  private static <T> void endBlockElement(Editable text, EnrichedSpanFactory<T> spanFactory) {
    Newline n = getLast(text, Newline.class);
    if (n != null) {
      appendNewlines(text, n.mNumNewlines);
      text.removeSpan(n);
    }
    Alignment a = getLast(text, Alignment.class);
    if (a != null) {
      setParagraphSpanFromMark(text, a, spanFactory.createAlignmentSpan(a.mCssValue));
    }
    Direction d = getLast(text, Direction.class);
    if (d != null) {
      setParagraphSpanFromMark(text, d, spanFactory.createDirectionSpan(d.mValue));
    }
  }

  private static void handleBr(Editable text) {
    text.append('\n');
  }

  private void startLi(Editable text, Attributes attributes) {
    startBlockElement(text);

    if (currentListAlignmentCssValue != null) {
      start(text, new Alignment(currentListAlignmentCssValue));
    }

    if (currentListDirectionValue != null) {
      start(text, new Direction(currentListDirectionValue));
    }

    if (isInOrderedList) {
      currentOrderedListItemIndex++;
      start(text, new List("ordered", currentOrderedListItemIndex, false));
    } else if (isInCheckboxList) {
      String isChecked = attributes.getValue("", "checked");
      start(text, new List("checked", 0, "checked".equals(isChecked)));
    } else {
      start(text, new List("unordered", 0, false));
    }
  }

  private static <T> void endLi(Editable text, T style, EnrichedSpanFactory<T> spanFactory) {
    endBlockElement(text, spanFactory);

    List l = getLast(text, List.class);
    if (l != null) {
      if (l.mType.equals("ordered")) {
        setParagraphSpanFromMark(text, l, spanFactory.createOrderedListSpan(l.mIndex, style));
      } else if (l.mType.equals("checked")) {
        setParagraphSpanFromMark(text, l, spanFactory.createCheckboxListSpan(l.mChecked, style));
      } else {
        setParagraphSpanFromMark(text, l, spanFactory.createUnorderedListSpan(style));
      }
    }

    endBlockElement(text, spanFactory);
  }

  private void startBlockquote(Editable text) {
    startBlockElement(text);
    start(text, new Blockquote());
  }

  private static <T> void endBlockquote(
      Editable text, T style, EnrichedSpanFactory<T> spanFactory) {
    endBlockElement(text, spanFactory);
    Blockquote last = getLast(text, Blockquote.class);
    setParagraphSpanFromMark(text, last, spanFactory.createBlockQuoteSpan(style));
  }

  private void startCodeBlock(Editable text) {
    startBlockElement(text);
    start(text, new CodeBlock());
  }

  private static <T> void endCodeBlock(Editable text, T style, EnrichedSpanFactory<T> spanFactory) {
    endBlockElement(text, spanFactory);
    CodeBlock last = getLast(text, CodeBlock.class);
    setParagraphSpanFromMark(text, last, spanFactory.createCodeBlockSpan(style));
  }

  private void startHeading(Editable text, int level) {
    startBlockElement(text);

    switch (level) {
      case 1:
        start(text, new H1());
        break;
      case 2:
        start(text, new H2());
        break;
      case 3:
        start(text, new H3());
        break;
      case 4:
        start(text, new H4());
        break;
      case 5:
        start(text, new H5());
        break;
      case 6:
        start(text, new H6());
        break;
      default:
        throw new IllegalArgumentException("Unsupported heading level: " + level);
    }
  }

  private static <T> void endHeading(
      Editable text, T style, EnrichedSpanFactory<T> spanFactory, int level) {
    endBlockElement(text, spanFactory);

    switch (level) {
      case 1:
        H1 lastH1 = getLast(text, H1.class);
        setParagraphSpanFromMark(text, lastH1, spanFactory.createH1Span(style));
        break;
      case 2:
        H2 lastH2 = getLast(text, H2.class);
        setParagraphSpanFromMark(text, lastH2, spanFactory.createH2Span(style));
        break;
      case 3:
        H3 lastH3 = getLast(text, H3.class);
        setParagraphSpanFromMark(text, lastH3, spanFactory.createH3Span(style));
        break;
      case 4:
        H4 lastH4 = getLast(text, H4.class);
        setParagraphSpanFromMark(text, lastH4, spanFactory.createH4Span(style));
        break;
      case 5:
        H5 lastH5 = getLast(text, H5.class);
        setParagraphSpanFromMark(text, lastH5, spanFactory.createH5Span(style));
        break;
      case 6:
        H6 lastH6 = getLast(text, H6.class);
        setParagraphSpanFromMark(text, lastH6, spanFactory.createH6Span(style));
        break;
      default:
        throw new IllegalArgumentException("Unsupported heading level: " + level);
    }
  }

  private static <T> T getLast(Spanned text, Class<T> kind) {
    /*
     * This knows that the last returned object from getSpans()
     * will be the most recently added.
     */
    T[] objs = text.getSpans(0, text.length(), kind);
    if (objs.length == 0) {
      return null;
    } else {
      return objs[objs.length - 1];
    }
  }

  private static void setSpanFromMark(Spannable text, Object mark, Object... spans) {
    int where = text.getSpanStart(mark);
    text.removeSpan(mark);
    int len = text.length();
    if (where != len) {
      for (Object span : spans) {
        text.setSpan(span, where, len, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
      }
    }
  }

  private static void setParagraphSpanFromMark(Editable text, Object mark, Object... spans) {
    int where = text.getSpanStart(mark);
    text.removeSpan(mark);
    int len = text.length();

    // Block spans require at least one character to be applied.
    if (isEmptyTag) {
      text.append(EnrichedConstants.ZWS);
      len++;
    }

    // Adjust the end position to exclude the newline character, if present
    if (len > 0 && text.charAt(len - 1) == '\n') {
      len--;
    }

    if (where != len) {
      for (Object span : spans) {
        text.setSpan(span, where, len, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
      }
    }
  }

  /** Yellow, matching what iOS uses for a `<mark>` with no colour. */
  private static final int DEFAULT_HIGHLIGHT_COLOR = 0xFFFFF59D;

  /** Box for an image whose markup carries no usable size. */
  private static final int DEFAULT_IMAGE_WIDTH = 280;

  /**
   * Pull `background-color:#RRGGBB` out of a `<mark>`'s style attribute. Both
   * iOS and TipTap write that shape; anything else falls back to yellow so the
   * text still reads as highlighted.
   */
  private static int parseHighlightColor(Attributes attributes) {
    String style = attributes.getValue("", "style");
    if (style == null) return DEFAULT_HIGHLIGHT_COLOR;

    Matcher matcher = HIGHLIGHT_COLOR_PATTERN.matcher(style);
    if (!matcher.find()) return DEFAULT_HIGHLIGHT_COLOR;

    try {
      return Color.parseColor(matcher.group(1));
    } catch (IllegalArgumentException e) {
      return DEFAULT_HIGHLIGHT_COLOR;
    }
  }

  private static final Pattern HIGHLIGHT_COLOR_PATTERN =
      Pattern.compile("background-color\\s*:\\s*(#[0-9a-fA-F]{6})");

  private static final Pattern TEXT_COLOR_PATTERN =
      Pattern.compile("(?:^|;)\\s*color\\s*:\\s*(#[0-9a-fA-F]{3,8})");

  private static final Pattern FONT_SIZE_PATTERN =
      Pattern.compile("font-size\\s*:\\s*([0-9]+(?:\\.[0-9]+)?)\\s*px");

  /**
   * Open a `<span>`.
   *
   * Colour and size are the two things a span can carry here — the shapes
   * TipTap writes and iOS emits. A span with neither still pushes a mark, so
   * that the matching `</span>` closes something and cannot unbalance the
   * document.
   */
  private static void startStyledSpan(Editable text, Attributes attributes) {
    String style = attributes.getValue("", "style");
    Integer color = null;
    Float size = null;

    if (style != null) {
      Matcher colorMatcher = TEXT_COLOR_PATTERN.matcher(style);
      if (colorMatcher.find()) {
        try {
          color = Color.parseColor(colorMatcher.group(1));
        } catch (IllegalArgumentException e) {
          color = null;
        }
      }

      Matcher sizeMatcher = FONT_SIZE_PATTERN.matcher(style);
      if (sizeMatcher.find()) {
        try {
          size = Float.parseFloat(sizeMatcher.group(1));
        } catch (NumberFormatException e) {
          size = null;
        }
      }
    }

    start(text, new StyledSpan(color, size));
  }

  private static void endStyledSpan(Editable text) {
    Object open = getLast(text, StyledSpan.class);
    if (!(open instanceof StyledSpan)) return;

    StyledSpan mark = (StyledSpan) open;
    int where = text.getSpanStart(mark);
    text.removeSpan(mark);

    int len = text.length();
    if (where < 0 || where == len) return;

    if (mark.color != null) {
      text.setSpan(
          new EnrichedTextColorSpan(mark.color), where, len, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
    }
    if (mark.size != null) {
      text.setSpan(
          new EnrichedFontSizeSpan(mark.size, EnrichedConstants.ALLOW_FONT_SCALING_DEFAULT),
          where,
          len,
          Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
    }
  }

  private static void start(Editable text, Object mark) {
    int len = text.length();
    text.setSpan(mark, len, len, Spannable.SPAN_INCLUSIVE_EXCLUSIVE);
  }

  private static void end(Editable text, Class kind, Object repl) {
    Object obj = getLast(text, kind);
    if (obj != null) {
      setSpanFromMark(text, obj, repl);
    }
  }

  private static <T> void startImg(
      Editable text, Attributes attributes, EnrichedSpanFactory<T> spanFactory) {
    String src = attributes.getValue("", "src");

    // An image with no source renders nothing; skipping it keeps the rest of
    // the document.
    if (src == null) {
      return;
    }

    int width = parseSize(attributes.getValue("", "width"), DEFAULT_IMAGE_WIDTH);
    int height = parseSize(attributes.getValue("", "height"), Math.round(width * 3f / 4f));

    int len = text.length();
    text.append("￼");
    text.setSpan(
        spanFactory.createImageSpan(src, width, height),
        len,
        text.length(),
        Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
  }

  /**
   * Image dimension from an HTML attribute.
   *
   * This used to be a bare {@code Integer.parseInt}, so a missing attribute
   * ("s == null") or a decimal — both of which real documents contain — threw
   * out of the SAX handler and aborted the parse of the WHOLE document. The
   * caller then fell back to inserting the note as plain text, which turned an
   * imported page into a wall of raw markup.
   */
  private static int parseSize(String value, int fallback) {
    if (value == null) {
      return fallback;
    }

    try {
      int parsed = Math.round(Float.parseFloat(value.trim()));

      return parsed > 0 ? parsed : fallback;
    } catch (NumberFormatException e) {
      return fallback;
    }
  }

  private static void startA(Editable text, Attributes attributes) {
    String href = attributes.getValue("", "href");
    start(text, new Href(href));
  }

  private static <T> void endA(Editable text, T style, EnrichedSpanFactory<T> spanFactory) {
    Href h = getLast(text, Href.class);
    if (h != null) {
      if (h.mHref != null) {
        setSpanFromMark(text, h, spanFactory.createLinkSpan(h.mHref, style));
      }
    }
  }

  private static void startMention(Editable mention, Attributes attributes) {
    String text = attributes.getValue("", "text");
    String indicator = attributes.getValue("", "indicator");

    Map<String, String> attributesMap = new HashMap<>();
    for (int i = 0; i < attributes.getLength(); i++) {
      String localName = attributes.getLocalName(i);

      if (!"text".equals(localName) && !"indicator".equals(localName)) {
        attributesMap.put(localName, attributes.getValue(i));
      }
    }

    start(mention, new Mention(indicator, text, attributesMap));
  }

  private static <T> void endMention(Editable text, T style, EnrichedSpanFactory<T> spanFactory) {
    Mention m = getLast(text, Mention.class);

    if (m == null) return;
    if (m.mText == null) return;

    setSpanFromMark(
        text, m, spanFactory.createMentionSpan(m.mText, m.mIndicator, m.mAttributes, style));
  }

  public void setDocumentLocator(Locator locator) {}

  public void startDocument() {}

  public void endDocument() {}

  public void startPrefixMapping(String prefix, String uri) {}

  public void endPrefixMapping(String prefix) {}

  public void startElement(String uri, String localName, String qName, Attributes attributes) {
    if (localName.equalsIgnoreCase("table")) {
      mTableDepth++;
      if (mTableDepth == 1) {
        startTable();
        return;
      }
    }

    // Everything inside a table is already captured in its raw HTML.
    if (mTableDepth > 0) return;

    handleStartTag(localName, attributes);
  }

  public void endElement(String uri, String localName, String qName) {
    if (localName.equalsIgnoreCase("table")) {
      if (mTableDepth > 0) mTableDepth--;
      return;
    }

    if (mTableDepth > 0) return;

    handleEndTag(localName);
  }

  /**
   * Place a table at the caret.
   *
   * The span replaces a single object character, the way an image does, so the
   * table occupies one position in the text and the serializer can swap it back
   * for its raw HTML.
   */
  private void startTable() {
    if (mTableIndex >= mTableHtml.size()) return;

    String rawHtml = mTableHtml.get(mTableIndex++);
    EnrichedTableData data = buildTableData(rawHtml);

    if (data.getRows().isEmpty()) return;

    isEmptyTag = false;
    int len = mSpannableStringBuilder.length();
    mSpannableStringBuilder.append("\uFFFC");
    mSpannableStringBuilder.setSpan(
        mSpanFactory.createTableSpan(rawHtml, data, mStyle),
        len,
        mSpannableStringBuilder.length(),
        Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
  }

  public void characters(char[] ch, int start, int length) {
    if (mTableDepth > 0) return;

    StringBuilder sb = new StringBuilder();

    /*
     * Ignore whitespace that immediately follows other whitespace;
     * newlines count as spaces.
     */
    for (int i = 0; i < length; i++) {
      char c = ch[i + start];
      if (c == ' ' || c == '\n') {
        char pred;
        int len = sb.length();
        if (len == 0) {
          len = mSpannableStringBuilder.length();
          if (len == 0) {
            pred = '\n';
          } else {
            pred = mSpannableStringBuilder.charAt(len - 1);
          }
        } else {
          pred = sb.charAt(len - 1);
        }
        if (pred != ' ' && pred != '\n') {
          sb.append(' ');
        }
      } else {
        sb.append(c);
      }
    }
    // Only mark the tag as non-empty if content was actually appended after
    // whitespace collapsing. A space-only list item (e.g. <li> </li>) would
    // have its space dropped when the preceding char is a newline, leaving
    // nothing to anchor a span — the ZWS placeholder must still be inserted.
    if (sb.length() > 0) isEmptyTag = false;
    mSpannableStringBuilder.append(sb);
  }

  public void ignorableWhitespace(char[] ch, int start, int length) {}

  public void processingInstruction(String target, String data) {}

  public void skippedEntity(String name) {}

  private static class H1 {}

  private static class H2 {}

  private static class H3 {}

  private static class H4 {}

  private static class H5 {}

  private static class H6 {}

  private static class Bold {}

  private static class Italic {}

  private static class Underline {}

  /** Marker for an open `<mark>`, carrying the colour parsed from its style. */
  private static class Highlight {
    final int color;

    Highlight(int color) {
      this.color = color;
    }
  }

  private static class Code {}

  /** An open `<span>`, carrying whatever of colour / size it declared. */
  private static class StyledSpan {
    final Integer color;
    final Float size;

    StyledSpan(Integer color, Float size) {
      this.color = color;
      this.size = size;
    }
  }

  private static class Subscript {}

  private static class Superscript {}

  private static class CodeBlock {}

  private static class Strikethrough {}

  private static class Blockquote {}

  private static class List {
    public int mIndex;
    public String mType;
    public boolean mChecked;

    public List(String type, int index, boolean checked) {
      mType = type;
      mIndex = index;
      mChecked = checked;
    }
  }

  private static class Mention {
    public Map<String, String> mAttributes;
    public String mIndicator;
    public String mText;

    public Mention(String indicator, String text, Map<String, String> attributes) {
      mIndicator = indicator;
      mAttributes = attributes;
      mText = text;
    }
  }

  private static class Href {
    public String mHref;

    public Href(String href) {
      mHref = href;
    }
  }

  private static class Newline {
    private final int mNumNewlines;

    public Newline(int numNewlines) {
      mNumNewlines = numNewlines;
    }
  }

  private static class Alignment {
    final String mCssValue;

    public Alignment(String cssValue) {
      this.mCssValue = cssValue;
    }
  }

  private static class Direction {
    final String mValue;

    public Direction(String value) {
      this.mValue = value;
    }
  }
}
