package com.swmansion.enriched.textinput.utils

import android.text.Editable
import android.text.Spannable
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.swmansion.enriched.common.EnrichedConstants
import com.swmansion.enriched.textinput.EnrichedTextInputView
import com.swmansion.enriched.textinput.events.OnAiMarkTapEvent
import com.swmansion.enriched.textinput.events.OnChangeSelectionEvent
import com.swmansion.enriched.textinput.events.OnLinkDetectedEvent
import com.swmansion.enriched.textinput.events.OnMentionDetectedEvent
import com.swmansion.enriched.textinput.spans.EnrichedInputAiFlagSpan
import com.swmansion.enriched.textinput.spans.EnrichedInputAiSuggestionSpan
import com.swmansion.enriched.textinput.spans.EnrichedInputLinkSpan
import com.swmansion.enriched.textinput.spans.EnrichedInputMentionSpan
import com.swmansion.enriched.textinput.spans.EnrichedSpans
import org.json.JSONObject

class EnrichedSelection(
  private val view: EnrichedTextInputView,
) {
  var start: Int = 0
  var end: Int = 0

  private var previousLinkDetectedEvent: MutableMap<String, String> = mutableMapOf("text" to "", "url" to "")
  private var previousMentionDetectedEvent: MutableMap<String, String> = mutableMapOf("text" to "", "payload" to "")

  fun onSelection(
    selStart: Int,
    selEnd: Int,
  ) {
    var shouldValidateStyles = false
    var newStart = start
    var newEnd = end

    if (selStart != -1 && selStart != newStart) {
      newStart = selStart
      shouldValidateStyles = true
    }

    if (selEnd != -1 && selEnd != newEnd) {
      newEnd = selEnd
      shouldValidateStyles = true
    }

    val textLength = view.text?.length ?: 0
    val finalStart = newStart.coerceAtMost(newEnd).coerceAtLeast(0).coerceAtMost(textLength)
    val finalEnd = newEnd.coerceAtLeast(newStart).coerceAtLeast(0).coerceAtMost(textLength)

    if (isZeroWidthSelection(finalStart, finalEnd) && !view.isDuringTransaction) {
      view.setSelection(finalStart + 1)
      shouldValidateStyles = false
    }

    if (!shouldValidateStyles) return

    start = finalStart
    end = finalEnd
    validateStyles()
    emitSelectionChangeEvent(view.text, finalStart, finalEnd)
    maybeEmitAiMarkTap(finalStart)
  }

  // aiId of the mark the caret currently sits inside, so onAiMarkTap fires once
  // on entry rather than on every selection change (mirrors iOS lastAiMarkId).
  private var lastAiMarkId: String? = null

  private fun maybeEmitAiMarkTap(caret: Int) {
    val spannable = view.text as? Spannable
    val len = spannable?.length ?: 0
    var kind: String? = null
    var aiId = ""
    var status = "pending"
    var explanation = ""
    var spanStart = -1
    var spanEnd = -1

    if (spannable != null && len > 0 && caret < len) {
      val sug = spannable.getSpans(caret, caret + 1, EnrichedInputAiSuggestionSpan::class.java)
      if (sug.isNotEmpty()) {
        kind = "suggestion"
        aiId = sug[0].getAiId()
        status = sug[0].getStatus()
        spanStart = spannable.getSpanStart(sug[0])
        spanEnd = spannable.getSpanEnd(sug[0])
      } else {
        val flg = spannable.getSpans(caret, caret + 1, EnrichedInputAiFlagSpan::class.java)
        if (flg.isNotEmpty()) {
          kind = "flag"
          aiId = flg[0].getAiId()
          status = flg[0].getStatus()
          explanation = flg[0].getExplanation()
          spanStart = spannable.getSpanStart(flg[0])
          spanEnd = spannable.getSpanEnd(flg[0])
        }
      }
    }

    val currentId = if (kind != null) aiId else null
    if (currentId != null && currentId != lastAiMarkId) {
      val rect = computeSpanRect(spanStart, spanEnd)
      val context = view.context as ReactContext
      val surfaceId = UIManagerHelper.getSurfaceId(context)
      val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
      dispatcher?.dispatchEvent(
        OnAiMarkTapEvent(
          surfaceId,
          view.id,
          kind!!,
          aiId,
          status,
          explanation,
          rect[0],
          rect[1],
          rect[2],
          rect[3],
        ),
      )
    }
    lastAiMarkId = currentId
  }

  // Best-effort on-screen rect (dp) of the mark for popover anchoring.
  private fun computeSpanRect(
    spanStart: Int,
    spanEnd: Int,
  ): FloatArray {
    val layout = view.layout ?: return floatArrayOf(0f, 0f, 0f, 0f)
    if (spanStart < 0) return floatArrayOf(0f, 0f, 0f, 0f)
    val density = view.resources.displayMetrics.density
    val line = layout.getLineForOffset(spanStart)
    val startX = layout.getPrimaryHorizontal(spanStart)
    val endX =
      if (layout.getLineForOffset(spanEnd) == line) {
        layout.getPrimaryHorizontal(spanEnd)
      } else {
        layout.getLineRight(line)
      }
    val top = layout.getLineTop(line).toFloat()
    val bottom = layout.getLineBottom(line).toFloat()
    val x = startX + view.totalPaddingLeft - view.scrollX
    val y = top + view.totalPaddingTop - view.scrollY
    return floatArrayOf(x / density, y / density, (endX - startX) / density, (bottom - top) / density)
  }

  private fun isZeroWidthSelection(
    start: Int,
    end: Int,
  ): Boolean {
    val text = view.text ?: return false

    if (start != end) {
      return text.substring(start, end) == EnrichedConstants.ZWS_STRING
    }

    val isNewLine = if (start > 0) text.substring(start - 1, start) == "\n" else true
    val isNextCharacterZeroWidth =
      if (start < text.length) {
        text.substring(start, start + 1) == EnrichedConstants.ZWS_STRING
      } else {
        false
      }

    return isNewLine && isNextCharacterZeroWidth
  }

  fun validateStyles() {
    val state = view.spanState ?: return

    // We don't validate inline styles when removing many characters at once
    // We don't want to remove styles on auto-correction
    // If user removes many characters at once, we want to keep the styles config
    if (!view.isRemovingMany) {
      for ((style, config) in EnrichedSpans.inlineSpans) {
        state.setStart(style, getInlineStyleStart(config.clazz))
      }
    } else {
      view.isRemovingMany = false
    }

    for ((style, config) in EnrichedSpans.paragraphSpans) {
      state.setStart(style, getParagraphStyleStart(config.clazz))
    }

    for ((style, config) in EnrichedSpans.listSpans) {
      state.setStart(style, getListStyleStart(config.clazz))
    }

    for ((style, config) in EnrichedSpans.parametrizedStyles) {
      state.setStart(style, getParametrizedStyleStart(config.clazz))
    }

    val currentAlignment = view.alignmentStyles?.getCurrentAlignment() ?: "auto"
    state.setAlignment(currentAlignment)
  }

  fun getInlineSelection(): Pair<Int, Int> {
    val textLength = view.text?.length ?: 0
    val finalStart = start.coerceAtMost(end).coerceAtLeast(0).coerceAtMost(textLength)
    val finalEnd = end.coerceAtLeast(start).coerceAtLeast(0).coerceAtMost(textLength)

    return Pair(finalStart, finalEnd)
  }

  private fun <T> getInlineStyleStart(type: Class<T>): Int? {
    val (start, end) = getInlineSelection()
    val spannable = view.text as Spannable
    val spans = spannable.getSpans(start, end, type)
    var styleStart: Int? = null

    for (span in spans) {
      val spanStart = spannable.getSpanStart(span)
      val spanEnd = spannable.getSpanEnd(span)

      if (start == end && start == spanStart) {
        styleStart = null
      } else if (start >= spanStart && end <= spanEnd) {
        styleStart = spanStart
      }
    }

    return styleStart
  }

  fun getParagraphSelection(): Pair<Int, Int> {
    val (currentStart, currentEnd) = getInlineSelection()
    val spannable = view.text as Spannable
    return spannable.getParagraphBounds(currentStart, currentEnd)
  }

  private fun <T> getParagraphStyleStart(type: Class<T>): Int? {
    val (start, end) = getParagraphSelection()
    val spannable = view.text as Spannable
    val spans = spannable.getSpans(start, end, type)
    var styleStart: Int? = null

    for (span in spans) {
      val spanStart = spannable.getSpanStart(span)
      val spanEnd = spannable.getSpanEnd(span)

      if (start >= spanStart && end <= spanEnd) {
        styleStart = spanStart
        break
      }
    }

    return styleStart
  }

  private fun <T> getListStyleStart(type: Class<T>): Int? {
    val (start, end) = getParagraphSelection()
    val spannable = view.text as Spannable
    var styleStart: Int? = null

    var paragraphStart = start
    val paragraphs = spannable.substring(start, end).split("\n")
    pi@ for (paragraph in paragraphs) {
      val paragraphEnd = paragraphStart + paragraph.length
      val spans = spannable.getSpans(paragraphStart, paragraphEnd, type)

      for (span in spans) {
        val spanStart = spannable.getSpanStart(span)
        val spanEnd = spannable.getSpanEnd(span)

        if (spanStart == paragraphStart && spanEnd == paragraphEnd) {
          styleStart = spanStart
          paragraphStart = paragraphEnd + 1
          continue@pi
        }
      }

      styleStart = null
      break
    }

    return styleStart
  }

  private fun <T> getParametrizedStyleStart(type: Class<T>): Int? {
    val (start, end) = getInlineSelection()
    val spannable = view.text as Spannable
    val spans = spannable.getSpans(start, end, type)
    val isLinkType = type == EnrichedInputLinkSpan::class.java
    val isMentionType = type == EnrichedInputMentionSpan::class.java

    if (isLinkType && spans.isEmpty()) {
      if (wasLinkPreviouslyDetected()) {
        emitLinkDetectedEvent(spannable, null, 0, 0)
      }
      return null
    }

    if (isMentionType && spans.isEmpty()) {
      if (wasMentionPreviouslyDetected()) {
        emitMentionDetectedEvent(spannable, null, start, end)
      }
      return null
    }

    for (span in spans) {
      val spanStart = spannable.getSpanStart(span)
      val spanEnd = spannable.getSpanEnd(span)

      if (start >= spanStart && end <= spanEnd) {
        if (isLinkType && span is EnrichedInputLinkSpan) {
          emitLinkDetectedEvent(spannable, span, spanStart, spanEnd)
        } else if (isMentionType && span is EnrichedInputMentionSpan) {
          emitMentionDetectedEvent(spannable, span, spanStart, spanEnd)
        }

        return spanStart
      }
    }

    return null
  }

  private fun emitSelectionChangeEvent(
    editable: Editable?,
    start: Int,
    end: Int,
  ) {
    if (editable == null) return

    val context = view.context as ReactContext
    val surfaceId = UIManagerHelper.getSurfaceId(context)
    val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(context, view.id)

    val visibleStart = start - editable.zwsCountBefore(start)
    val visibleEnd = end - editable.zwsCountBefore(end)
    val text = editable.substring(start, end).replace(EnrichedConstants.ZWS_STRING, "")
    dispatcher?.dispatchEvent(
      OnChangeSelectionEvent(
        surfaceId,
        view.id,
        text,
        visibleStart,
        visibleEnd,
        view.experimentalSynchronousEvents,
      ),
    )
  }

  private fun wasMentionPreviouslyDetected(): Boolean {
    val previousText = previousMentionDetectedEvent["text"] ?: ""
    val previousIndicator = previousMentionDetectedEvent["indicator"] ?: ""
    return previousText.isNotEmpty() || previousIndicator.isNotEmpty()
  }

  private fun wasLinkPreviouslyDetected(): Boolean {
    val previousText = previousLinkDetectedEvent["text"] ?: ""
    val previousUrl = previousLinkDetectedEvent["url"] ?: ""
    return previousText.isNotEmpty() || previousUrl.isNotEmpty()
  }

  private fun emitLinkDetectedEvent(
    spannable: Spannable,
    span: EnrichedInputLinkSpan?,
    start: Int,
    end: Int,
  ) {
    val text = spannable.substring(start, end).replace(EnrichedConstants.ZWS_STRING, "")
    val url = span?.getUrl() ?: ""

    // Prevents emitting unnecessary events
    if (text == previousLinkDetectedEvent["text"] && url == previousLinkDetectedEvent["url"]) return

    previousLinkDetectedEvent.put("text", text)
    previousLinkDetectedEvent.put("url", url)

    val visibleStart = start - spannable.zwsCountBefore(start)
    val visibleEnd = end - spannable.zwsCountBefore(end)

    val context = view.context as ReactContext
    val surfaceId = UIManagerHelper.getSurfaceId(context)
    val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
    dispatcher?.dispatchEvent(
      OnLinkDetectedEvent(
        surfaceId,
        view.id,
        text,
        url,
        visibleStart,
        visibleEnd,
        view.experimentalSynchronousEvents,
      ),
    )
  }

  private fun emitMentionDetectedEvent(
    spannable: Spannable,
    span: EnrichedInputMentionSpan?,
    start: Int,
    end: Int,
  ) {
    val text = spannable.substring(start, end)
    val attributes = span?.getAttributes() ?: emptyMap()
    val indicator = span?.getIndicator() ?: ""
    val payload = JSONObject(attributes).toString()

    val previousText = previousMentionDetectedEvent["text"] ?: ""
    val previousPayload = previousMentionDetectedEvent["payload"] ?: ""
    val previousIndicator = previousMentionDetectedEvent["indicator"] ?: ""

    if (text == previousText && payload == previousPayload && indicator == previousIndicator) return

    previousMentionDetectedEvent.put("text", text)
    previousMentionDetectedEvent.put("payload", payload)
    previousMentionDetectedEvent.put("indicator", indicator)

    val context = view.context as ReactContext
    val surfaceId = UIManagerHelper.getSurfaceId(context)
    val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(context, view.id)
    dispatcher?.dispatchEvent(
      OnMentionDetectedEvent(
        surfaceId,
        view.id,
        text,
        indicator,
        payload,
        view.experimentalSynchronousEvents,
      ),
    )
  }
}
