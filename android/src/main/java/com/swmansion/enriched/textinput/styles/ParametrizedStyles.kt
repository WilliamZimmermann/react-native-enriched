package com.swmansion.enriched.textinput.styles

import android.graphics.Color
import android.text.Editable
import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.Spanned
import com.swmansion.enriched.common.EnrichedConstants
import com.swmansion.enriched.common.spans.EnrichedFontSizeSpan
import com.swmansion.enriched.common.spans.EnrichedHighlightSpan
import com.swmansion.enriched.common.spans.EnrichedSubscriptSpan
import com.swmansion.enriched.common.spans.EnrichedSuperscriptSpan
import com.swmansion.enriched.common.spans.EnrichedTextColorSpan
import com.swmansion.enriched.textinput.EnrichedTextInputView
import com.swmansion.enriched.textinput.spans.EnrichedInputAiFlagSpan
import com.swmansion.enriched.textinput.spans.EnrichedInputAiSuggestionSpan
import com.swmansion.enriched.textinput.spans.EnrichedInputHorizontalRuleSpan
import com.swmansion.enriched.textinput.spans.EnrichedInputImageSpan
import com.swmansion.enriched.textinput.spans.EnrichedInputLinkSpan
import com.swmansion.enriched.textinput.spans.EnrichedInputMentionSpan
import com.swmansion.enriched.textinput.spans.EnrichedSpans
import com.swmansion.enriched.textinput.utils.getSafeSpanBoundaries
import com.swmansion.enriched.textinput.utils.safelyRemoveZWS

class ParametrizedStyles(
  private val view: EnrichedTextInputView,
) {
  private var mentionStart: Int? = null
  private var isSettingLinkSpan = false

  var mentionIndicators: Array<String> = emptyArray<String>()

  /**
   * Report the new HTML after an inline style changed.
   *
   * The span watcher only emits for its own `EnrichedInputSpan`s, so applying a
   * colour, a size or sub/superscript changed the text on screen and never
   * reached JS: the note looked formatted and saved without the change, because
   * the draft still held the last HTML a KEYSTROKE had emitted. Passing null
   * asks for an unconditional emit.
   */
  private fun emitHtmlChange() {
    val spannable = view.text as? Spannable ?: return

    view.spanWatcher?.emitEvent(spannable, null)
  }

  fun <T> dropSpansIn(
    spannable: Spannable,
    start: Int,
    end: Int,
    clazz: Class<T>,
  ) {
    val ssb = spannable as SpannableStringBuilder

    for (span in ssb.getSpans(start, end, clazz)) {
      ssb.removeSpan(span)
    }
  }

  fun <T> removeSpansForRange(
    spannable: Spannable,
    start: Int,
    end: Int,
    clazz: Class<T>,
  ): Boolean {
    val ssb = spannable as SpannableStringBuilder
    val spans = ssb.getSpans(start, end, clazz)
    if (spans.isEmpty()) return false

    ssb.safelyRemoveZWS(start, end)

    for (span in spans) {
      ssb.removeSpan(span)
    }

    return true
  }

  /**
   * Apply a highlight (text background colour) over [start, end).
   *
   * Replaces any highlight already covering the range so re-tapping a swatch
   * recolours instead of stacking translucent spans.
   */
  fun setHighlightSpan(
    start: Int,
    end: Int,
    color: String?,
  ) {
    if (start >= end) return

    val parsed =
      try {
        Color.parseColor(color ?: "#FFF59D")
      } catch (e: IllegalArgumentException) {
        // Unparseable colour from JS — fall back to the same yellow iOS uses
        // for a bare <mark> rather than dropping the user's action.
        Color.parseColor("#FFF59D")
      }

    val spannable = view.text as SpannableStringBuilder
    removeSpansForRange(spannable, start, end, EnrichedHighlightSpan::class.java)

    val (safeStart, safeEnd) = spannable.getSafeSpanBoundaries(start, end)
    spannable.setSpan(
      EnrichedHighlightSpan(parsed),
      safeStart,
      safeEnd,
      Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )

    view.selection?.validateStyles()
    emitHtmlChange()
  }

  /** Apply a foreground colour over [start, end), replacing any already there. */
  fun setTextColorSpan(
    start: Int,
    end: Int,
    color: String?,
  ) {
    if (start >= end || color == null) return

    val parsed =
      try {
        Color.parseColor(color)
      } catch (e: IllegalArgumentException) {
        return
      }

    val spannable = view.text as SpannableStringBuilder
    removeSpansForRange(spannable, start, end, EnrichedTextColorSpan::class.java)

    val (safeStart, safeEnd) = spannable.getSafeSpanBoundaries(start, end)
    spannable.setSpan(
      EnrichedTextColorSpan(parsed),
      safeStart,
      safeEnd,
      Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )

    view.selection?.validateStyles()
    emitHtmlChange()
  }

  /**
   * Per-selection font size, in dp. Replaces any size already covering the
   * range so sizes don't stack.
   */
  fun setFontSizeSpan(
    start: Int,
    end: Int,
    size: Float,
  ) {
    if (start >= end || size <= 0f) return

    val spannable = view.text as SpannableStringBuilder
    dropSpansIn(spannable, start, end, EnrichedFontSizeSpan::class.java)

    val (safeStart, safeEnd) = spannable.getSafeSpanBoundaries(start, end)
    spannable.setSpan(
      EnrichedFontSizeSpan(size, view.allowFontScaling),
      safeStart,
      safeEnd,
      Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )

    view.selection?.validateStyles()
    emitHtmlChange()
  }

  fun removeFontSizeSpans(
    start: Int,
    end: Int,
  ) {
    if (start >= end) return

    val spannable = view.text as SpannableStringBuilder
    dropSpansIn(spannable, start, end, EnrichedFontSizeSpan::class.java)

    view.selection?.validateStyles()
    emitHtmlChange()
  }

  /**
   * Subscript / superscript over a range.
   *
   * They are mutually exclusive — applying one clears the other, which is what
   * every editor does and keeps `H<sub>2</sub>O` from also being raised.
   */
  fun toggleScriptSpan(
    start: Int,
    end: Int,
    superscript: Boolean,
  ) {
    if (start >= end) return

    val spannable = view.text as SpannableStringBuilder
    val wanted =
      if (superscript) EnrichedSuperscriptSpan::class.java else EnrichedSubscriptSpan::class.java
    val other =
      if (superscript) EnrichedSubscriptSpan::class.java else EnrichedSuperscriptSpan::class.java
    val alreadyOn = spannable.getSpans(start, end, wanted).isNotEmpty()

    dropSpansIn(spannable, start, end, wanted)
    dropSpansIn(spannable, start, end, other)

    if (!alreadyOn) {
      val (safeStart, safeEnd) = spannable.getSafeSpanBoundaries(start, end)
      spannable.setSpan(
        if (superscript) EnrichedSuperscriptSpan() else EnrichedSubscriptSpan(),
        safeStart,
        safeEnd,
        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
      )
    }

    view.selection?.validateStyles()
    emitHtmlChange()
  }

  fun removeTextColorSpans(
    start: Int,
    end: Int,
  ) {
    if (start >= end) return

    val spannable = view.text as SpannableStringBuilder
    removeSpansForRange(spannable, start, end, EnrichedTextColorSpan::class.java)

    view.selection?.validateStyles()
    emitHtmlChange()
  }

  fun removeHighlightSpans(
    start: Int,
    end: Int,
  ) {
    if (start >= end) return

    val spannable = view.text as SpannableStringBuilder
    removeSpansForRange(spannable, start, end, EnrichedHighlightSpan::class.java)

    view.selection?.validateStyles()
    emitHtmlChange()
  }

  fun setLinkSpan(
    start: Int,
    end: Int,
    text: String,
    url: String,
  ) {
    isSettingLinkSpan = true

    val spannable = view.text as SpannableStringBuilder
    val spans = spannable.getSpans(start, end, EnrichedInputLinkSpan::class.java)
    for (span in spans) {
      spannable.removeSpan(span)
    }

    if (start == end) {
      spannable.insert(start, text)
    } else {
      spannable.replace(start, end, text)
    }

    val spanEnd = start + text.length
    val span = EnrichedInputLinkSpan(url, view.htmlStyle, true)
    val (safeStart, safeEnd) = spannable.getSafeSpanBoundaries(start, spanEnd)
    spannable.setSpan(span, safeStart, safeEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)

    view.selection?.validateStyles()
    emitHtmlChange()
    isSettingLinkSpan = false
  }

  fun removeLinkSpans(
    start: Int,
    end: Int,
  ) {
    val spannable = view.text as SpannableStringBuilder
    val textLength = spannable.length
    val clampedStart = minOf(start, end).coerceIn(0, textLength)
    val clampedEnd = maxOf(start, end).coerceIn(0, textLength)

    val spans = spannable.getSpans(clampedStart, clampedEnd, EnrichedInputLinkSpan::class.java)
    for (span in spans) {
      spannable.removeSpan(span)
    }
    view.selection?.validateStyles()
    emitHtmlChange()
  }

  // MARK: - AI track-changes marks

  fun setAiSuggestionSpan(
    start: Int,
    end: Int,
    aiId: String,
    status: String,
    model: String,
  ) {
    val spannable = view.text as SpannableStringBuilder
    val (safeStart, safeEnd) = spannable.getSafeSpanBoundaries(start, end)
    if (safeStart >= safeEnd) return
    for (span in spannable.getSpans(safeStart, safeEnd, EnrichedInputAiSuggestionSpan::class.java)) {
      spannable.removeSpan(span)
    }
    spannable.setSpan(
      EnrichedInputAiSuggestionSpan(aiId, status, model, view.htmlStyle),
      safeStart,
      safeEnd,
      Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )
    view.selection?.validateStyles()
  }

  fun setAiFlagSpan(
    start: Int,
    end: Int,
    aiId: String,
    status: String,
    explanation: String,
  ) {
    val spannable = view.text as SpannableStringBuilder
    val (safeStart, safeEnd) = spannable.getSafeSpanBoundaries(start, end)
    if (safeStart >= safeEnd) return
    for (span in spannable.getSpans(safeStart, safeEnd, EnrichedInputAiFlagSpan::class.java)) {
      spannable.removeSpan(span)
    }
    spannable.setSpan(
      EnrichedInputAiFlagSpan(aiId, status, explanation, view.htmlStyle),
      safeStart,
      safeEnd,
      Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
    )
    view.selection?.validateStyles()
  }

  // Accept: flip a mark's status to "accepted" (keep text + mark). aiIds are
  // unique across kinds, so applying to both is safe.
  fun acceptAiMark(aiId: String) {
    val spannable = view.text as SpannableStringBuilder
    for (span in spannable.getSpans(0, spannable.length, EnrichedInputAiSuggestionSpan::class.java)) {
      if (span.getAiId() != aiId) continue
      val s = spannable.getSpanStart(span)
      val e = spannable.getSpanEnd(span)
      spannable.removeSpan(span)
      spannable.setSpan(
        EnrichedInputAiSuggestionSpan(aiId, "accepted", span.getModel(), view.htmlStyle),
        s,
        e,
        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
      )
    }
    for (span in spannable.getSpans(0, spannable.length, EnrichedInputAiFlagSpan::class.java)) {
      if (span.getAiId() != aiId) continue
      val s = spannable.getSpanStart(span)
      val e = spannable.getSpanEnd(span)
      spannable.removeSpan(span)
      spannable.setSpan(
        EnrichedInputAiFlagSpan(aiId, "accepted", span.getExplanation(), view.htmlStyle),
        s,
        e,
        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
      )
    }
    view.selection?.validateStyles()
  }

  // Reject: deleteText=true (gap-fill suggestion) removes the inserted text;
  // false (flag) strips the mark and keeps the student's text.
  fun rejectAiMark(
    aiId: String,
    deleteText: Boolean,
  ) {
    val spannable = view.text as SpannableStringBuilder
    val matches = ArrayList<Any>()
    for (span in spannable.getSpans(0, spannable.length, EnrichedInputAiSuggestionSpan::class.java)) {
      if (span.getAiId() == aiId) matches.add(span)
    }
    for (span in spannable.getSpans(0, spannable.length, EnrichedInputAiFlagSpan::class.java)) {
      if (span.getAiId() == aiId) matches.add(span)
    }
    // Delete from the end backwards so earlier ranges stay valid.
    matches.sortByDescending { spannable.getSpanStart(it) }
    for (span in matches) {
      val s = spannable.getSpanStart(span)
      val e = spannable.getSpanEnd(span)
      spannable.removeSpan(span)
      if (deleteText && e > s) spannable.delete(s, e)
    }
    view.selection?.validateStyles()
  }

  // Claim: strip a suggestion's mark, keeping the text as the student's own.
  fun claimAiMark(aiId: String) = rejectAiMark(aiId, false)

  fun acceptAllAiSuggestions() {
    val spannable = view.text as SpannableStringBuilder
    for (span in spannable.getSpans(0, spannable.length, EnrichedInputAiSuggestionSpan::class.java)) {
      if (span.getStatus() == "accepted") continue
      val s = spannable.getSpanStart(span)
      val e = spannable.getSpanEnd(span)
      spannable.removeSpan(span)
      spannable.setSpan(
        EnrichedInputAiSuggestionSpan(span.getAiId(), "accepted", span.getModel(), view.htmlStyle),
        s,
        e,
        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
      )
    }
    view.selection?.validateStyles()
  }

  fun rejectAllAiSuggestions() {
    val spannable = view.text as SpannableStringBuilder
    val pending = ArrayList<EnrichedInputAiSuggestionSpan>()
    for (span in spannable.getSpans(0, spannable.length, EnrichedInputAiSuggestionSpan::class.java)) {
      if (span.getStatus() != "accepted") pending.add(span)
    }
    pending.sortByDescending { spannable.getSpanStart(it) }
    for (span in pending) {
      val s = spannable.getSpanStart(span)
      val e = spannable.getSpanEnd(span)
      spannable.removeSpan(span)
      if (e > s) spannable.delete(s, e)
    }
    view.selection?.validateStyles()
  }

  fun rejectAllAiFlags() {
    val spannable = view.text as SpannableStringBuilder
    for (span in spannable.getSpans(0, spannable.length, EnrichedInputAiFlagSpan::class.java)) {
      if (span.getStatus() != "accepted") spannable.removeSpan(span)
    }
    view.selection?.validateStyles()
  }

  fun afterTextChanged(
    s: Editable,
    startCursorPosition: Int,
    endCursorPosition: Int,
  ) {
    afterTextChangedLinks(startCursorPosition, endCursorPosition)
    afterTextChangedMentions(s, startCursorPosition)
  }

  fun onStyleToggled(
    name: String,
    start: Int,
    end: Int,
  ) {
    // Run afterTextChangedLinks on the range affected by the style toggle to re-detect links.
    // For example, toggling a code block on and off will restore automatically detected links.
    val linkConfig = EnrichedSpans.getMergingConfigForStyle(EnrichedSpans.LINK, view.htmlStyle) ?: return
    if (name in linkConfig.blockingStyles || name in linkConfig.conflictingStyles) {
      afterTextChangedLinks(start, end)
    }
  }

  fun detectLinksInRange(
    spannable: Spannable,
    start: Int,
    end: Int,
  ) {
    val regex = view.linkRegex ?: return
    val textLength = spannable.length
    val safeStart = minOf(start, end).coerceIn(0, textLength)
    val safeEnd = maxOf(start, end).coerceIn(0, textLength)
    if (safeStart >= safeEnd) return

    val contextText = spannable.subSequence(safeStart, safeEnd).toString()

    val spans = spannable.getSpans(safeStart, safeEnd, EnrichedInputLinkSpan::class.java)
    for (span in spans) {
      if (span.getIsManual()) continue
      spannable.removeSpan(span)
    }

    val wordsRegex = Regex("\\S+")
    for (wordMatch in wordsRegex.findAll(contextText)) {
      var word = wordMatch.value
      var wordStart = wordMatch.range.first

      // Do not include zero-width space in link detection
      if (word.startsWith(EnrichedConstants.ZWS_STRING)) {
        word = word.substring(1)
        wordStart += 1
      }

      // Loop over words and detect links
      val matcher = regex.matcher(word)
      while (matcher.find()) {
        val linkStart = matcher.start()
        val linkEnd = matcher.end()

        val spanStart = start + wordStart + linkStart
        val spanEnd = start + wordStart + linkEnd

        val (safeStart, safeEnd) = spannable.getSafeSpanBoundaries(spanStart, spanEnd)

        // Do not overwrite a manual link span with an auto-detected one
        val overlappingManual =
          spannable
            .getSpans(safeStart, safeEnd, EnrichedInputLinkSpan::class.java)
            .any { it.getIsManual() }
        if (overlappingManual) continue

        val span = EnrichedInputLinkSpan(matcher.group(), view.htmlStyle)
        spannable.setSpan(
          span,
          safeStart,
          safeEnd,
          Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
      }
    }
  }

  private fun getWordAtIndex(
    s: CharSequence,
    index: Int,
  ): TextRange? {
    if (index < 0) return null

    var start = index
    var end = index

    while (start > 0 && !Character.isWhitespace(s[start - 1])) {
      start--
    }

    while (end < s.length && !Character.isWhitespace(s[end])) {
      end++
    }

    val result = s.subSequence(start, end).toString()

    return TextRange(result, start, end)
  }

  // After editing text we want to automatically detect links in the affected range
  // Affected range is range + previous word + next word
  private fun getLinksAffectedRange(
    s: CharSequence,
    start: Int,
    end: Int,
  ): IntRange {
    var actualStart = start
    var actualEnd = end

    // Expand backward to find the start of the first affected word
    while (actualStart > 0 && !Character.isWhitespace(s[actualStart - 1])) {
      actualStart--
    }

    // Expand forward to find the end of the last affected word
    while (actualEnd < s.length && !Character.isWhitespace(s[actualEnd])) {
      actualEnd++
    }

    return actualStart..actualEnd
  }

  private fun canLinkBeApplied(): Boolean {
    val mergingConfig = EnrichedSpans.getMergingConfigForStyle(EnrichedSpans.LINK, view.htmlStyle) ?: return true
    val conflictingStyles = mergingConfig.conflictingStyles
    val blockingStyles = mergingConfig.blockingStyles

    for (style in blockingStyles) {
      if (view.spanState?.getStart(style) != null) return false
    }

    for (style in conflictingStyles) {
      if (view.spanState?.getStart(style) != null) return false
    }

    return true
  }

  private fun afterTextChangedLinks(
    editStart: Int,
    editEnd: Int,
  ) {
    // Do not detect link if it's applied manually
    if (isSettingLinkSpan || !canLinkBeApplied()) return
    val spannable = view.text as? Spannable ?: return

    val affectedRange = getLinksAffectedRange(spannable, editStart, editEnd)
    detectLinksInRange(spannable, affectedRange.first, affectedRange.last)
  }

  private fun afterTextChangedMentions(
    s: CharSequence,
    endCursorPosition: Int,
  ) {
    val mentionHandler = view.mentionHandler ?: return
    val currentWord = getWordAtIndex(s, endCursorPosition) ?: return
    val spannable = view.text as Spannable

    val indicatorsPattern = mentionIndicators.joinToString("|") { Regex.escape(it) }
    val mentionIndicatorRegex = Regex("^($indicatorsPattern)")
    val mentionRegex = Regex("^($indicatorsPattern)\\S*")

    var indicator: String
    var finalStart: Int
    val finalEnd = currentWord.end

    // No mention in the current word, check previous one
    if (!mentionRegex.matches(currentWord.text)) {
      val previousWord = getWordAtIndex(spannable, currentWord.start - 1)

      // No previous word -> no mention to be detected
      if (previousWord == null) {
        mentionHandler.endMention()
        return
      }

      // Previous word is not a mention -> end mention
      if (!mentionRegex.matches(previousWord.text)) {
        mentionHandler.endMention()
        return
      }

      // Previous word is a mention -> use it
      finalStart = previousWord.start
      indicator = mentionIndicatorRegex.find(previousWord.text)?.value ?: ""
    } else {
      // Current word is a mention -> use it
      finalStart = currentWord.start
      indicator = mentionIndicatorRegex.find(currentWord.text)?.value ?: ""
    }

    // Mirror iOS conflicting-styles behaviour: check the full candidate range for
    // a finalized mention span. If the span's stored text still matches what is in
    // the buffer the mention is intact — block the event (covers HTML-loaded
    // mentions and typing adjacent to a freshly-selected mention).
    // If the span is stale (user edited inside it), remove it and record mentionStart
    // so setMentionSpan can replace text correctly when the user picks a new mention.
    val rangeSpans = spannable.getSpans(finalStart, finalEnd, EnrichedInputMentionSpan::class.java)
    for (span in rangeSpans) {
      val spanStart = spannable.getSpanStart(span)
      val spanEnd = spannable.getSpanEnd(span)
      val currentSpanText = spannable.subSequence(spanStart, spanEnd).toString()
      if (currentSpanText == span.getText()) {
        mentionHandler.endMention()
        return
      }
      spannable.removeSpan(span)
      mentionStart = spanStart
    }

    // Extract text without indicator
    val text = spannable.subSequence(finalStart, finalEnd).toString().replaceFirst(indicator, "")

    // Means we are starting mention
    if (text.isEmpty()) {
      mentionStart = finalStart
    }

    mentionHandler.onMention(indicator, text)
  }

  fun setImageSpan(
    src: String,
    width: Float,
    height: Float,
  ) {
    if (view.selection == null) return
    val spannable = view.text as SpannableStringBuilder
    val (start, originalEnd) = view.selection.getInlineSelection()

    if (start == originalEnd) {
      spannable.insert(start, EnrichedConstants.ORC_STRING)
    } else {
      val spans = spannable.getSpans(start, originalEnd, EnrichedInputImageSpan::class.java)
      for (s in spans) {
        spannable.removeSpan(s)
      }

      spannable.replace(start, originalEnd, EnrichedConstants.ORC_STRING)
    }

    val (imageStart, imageEnd) = spannable.getSafeSpanBoundaries(start, start + 1)
    val span = EnrichedInputImageSpan.createEnrichedImageSpan(src, width.toInt(), height.toInt())
    span.observeAsyncDrawableLoaded(view.text)

    spannable.setSpan(span, imageStart, imageEnd, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
  }

  fun insertHorizontalRule() {
    val selection = view.selection ?: return
    val spannable = view.text as SpannableStringBuilder
    val (start, end) = selection.getInlineSelection()

    // Build the rule isolated on its own line: a leading newline unless the
    // caret already starts a line, the object-replacement char, then a trailing
    // newline so the user lands on a fresh line below.
    val builder = StringBuilder()
    val needLeading = start > 0 && spannable[start - 1] != '\n'
    if (needLeading) builder.append('\n')
    val orcOffset = builder.length
    builder.append(EnrichedConstants.ORC_STRING)
    val afterOrc = builder.length
    val needTrailing = end >= spannable.length || spannable[end] != '\n'
    if (needTrailing) builder.append('\n')

    spannable.replace(start, end, builder.toString())

    val (ruleStart, ruleEnd) =
      spannable.getSafeSpanBoundaries(start + orcOffset, start + afterOrc)
    spannable.setSpan(
      EnrichedInputHorizontalRuleSpan(),
      ruleStart,
      ruleEnd,
      Spannable.SPAN_EXCLUSIVE_EXCLUSIVE,
    )

    view.setSelection((start + builder.length).coerceAtMost(spannable.length))
  }

  fun startMention(indicator: String) {
    val selection = view.selection ?: return

    val spannable = view.text as SpannableStringBuilder
    val (start, end) = selection.getInlineSelection()

    if (start == end) {
      spannable.insert(start, indicator)
    } else {
      spannable.replace(start, end, indicator)
    }
  }

  fun setMentionSpan(
    indicator: String,
    text: String,
    attributes: Map<String, String>,
  ) {
    val selection = view.selection ?: return

    val spannable = view.text as SpannableStringBuilder
    val (selectionStart, selectionEnd) = selection.getInlineSelection()
    val spans = spannable.getSpans(selectionStart, selectionEnd, EnrichedInputMentionSpan::class.java)

    for (span in spans) {
      spannable.removeSpan(span)
    }

    val start = mentionStart ?: selectionStart

    view.runAsATransaction {
      spannable.replace(start, selectionEnd, text)

      val span = EnrichedInputMentionSpan(text, indicator, attributes, view.htmlStyle)
      val spanEnd = start + text.length
      val (safeStart, safeEnd) = spannable.getSafeSpanBoundaries(start, spanEnd)
      spannable.setSpan(span, safeStart, safeEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)

      val hasSpaceAtTheEnd = spannable.length > safeEnd && spannable[safeEnd] == ' '
      if (!hasSpaceAtTheEnd) {
        spannable.insert(safeEnd, " ")
      }
    }

    view.mentionHandler?.reset()
    view.selection.validateStyles()
    mentionStart = null
  }

  fun getStyleRange(): Pair<Int, Int> = view.selection?.getInlineSelection() ?: Pair(0, 0)

  fun removeStyle(
    name: String,
    start: Int,
    end: Int,
  ): Boolean {
    val config = EnrichedSpans.parametrizedStyles[name] ?: return false
    val spannable = view.text as Spannable
    return removeSpansForRange(spannable, start, end, config.clazz)
  }

  companion object {
    data class TextRange(
      val text: String,
      val start: Int,
      val end: Int,
    )
  }
}
