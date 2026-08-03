package com.swmansion.enriched.common.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.style.ReplacementSpan
import com.swmansion.enriched.common.spans.interfaces.EnrichedInlineSpan

/**
 * Width a table is drawn at: the screen minus the editor's own padding. A table
 * is a block, so it always takes the full column rather than sizing to content.
 */
fun tableWidth(): Int =
  android.content.res.Resources.getSystem().displayMetrics.widthPixels - TABLE_HORIZONTAL_INSET

private const val TABLE_HORIZONTAL_INSET = 40

/**
 * Payload of a table in the editor.
 *
 * [rawHtml] is the original `<table>…</table>` the parser swallowed. It is
 * written back out unchanged on save, so the web stack reads exactly what it
 * wrote instead of a lossy reconstruction — the same contract the iOS
 * TableAttachment uses. [rows] is the denormalised view used to draw, and
 * [colCount] is the widest row so short rows still draw their trailing cells.
 */
data class EnrichedTableData(
  val rawHtml: String,
  val rows: List<List<String>>,
  val colCount: Int,
)

/**
 * Draws a table inline in the editor.
 *
 * Android's counterpart to the iOS TableAttachment. iOS rasterises to an image
 * because TextKit wants an attachment; a `ReplacementSpan` can paint straight
 * onto the canvas, so there is no bitmap and no scaling to get wrong.
 *
 * Read-only for now, like iOS v1: the grid renders and round-trips, and editing
 * a cell still happens on the surface that has an inline cell editor.
 */
class EnrichedTableSpan(
  val data: EnrichedTableData,
  private val availableWidth: Int,
) : ReplacementSpan(),
  EnrichedInlineSpan {
  /** Cell rectangles in the span's own coordinate space, row-major. */
  private var cellRects: List<List<Rect>> = emptyList()
  private var measuredHeight: Int = 0

  // Colours come from the text paint at draw time, so the grid follows the
  // editor's theme without the span having to know about it.
  private val borderPaint =
    Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE
      strokeWidth = BORDER_WIDTH
    }

  override fun getSize(
    paint: Paint,
    text: CharSequence?,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    layoutCells(paint)

    if (fm != null) {
      fm.ascent = -measuredHeight
      fm.top = fm.ascent
      fm.descent = 0
      fm.bottom = 0
    }

    return availableWidth
  }

  override fun draw(
    canvas: Canvas,
    text: CharSequence?,
    start: Int,
    end: Int,
    x: Float,
    top: Int,
    y: Int,
    bottom: Int,
    paint: Paint,
  ) {
    layoutCells(paint)

    borderPaint.color = paint.color
    borderPaint.alpha = BORDER_ALPHA

    val originY = (y - measuredHeight).toFloat()

    for ((r, row) in cellRects.withIndex()) {
      for ((c, rect) in row.withIndex()) {
        canvas.drawRect(
          x + rect.left,
          originY + rect.top,
          x + rect.right,
          originY + rect.bottom,
          borderPaint,
        )

        val cell = data.rows.getOrNull(r)?.getOrNull(c).orEmpty()
        if (cell.isBlank()) continue

        canvas.save()
        canvas.translate(x + rect.left + CELL_PADDING, originY + rect.top + CELL_PADDING)
        cellLayout(cell, rect.width() - CELL_PADDING * 2, paint).draw(canvas)
        canvas.restore()
      }
    }
  }

  /**
   * Measure every cell and place it. Columns share the width equally — the
   * per-column fractions the tablet can drag are not editable here yet, and an
   * even split is what an unstyled `<table>` renders as on the web anyway.
   */
  private fun layoutCells(paint: Paint) {
    if (cellRects.isNotEmpty()) return

    val cols = maxOf(data.colCount, 1)
    val colWidth = availableWidth / cols
    val rects = mutableListOf<List<Rect>>()
    var yOffset = 0

    for (row in data.rows) {
      var rowHeight = MIN_ROW_HEIGHT

      for (c in 0 until cols) {
        val cell = row.getOrNull(c).orEmpty()
        if (cell.isBlank()) continue

        val cellHeight =
          cellLayout(cell, colWidth - CELL_PADDING * 2, paint).height + CELL_PADDING * 2
        if (cellHeight > rowHeight) rowHeight = cellHeight
      }

      val rowRects =
        (0 until cols).map { c ->
          Rect(c * colWidth, yOffset, (c + 1) * colWidth, yOffset + rowHeight)
        }

      rects.add(rowRects)
      yOffset += rowHeight
    }

    cellRects = rects
    measuredHeight = maxOf(yOffset, MIN_ROW_HEIGHT)
  }

  private fun cellLayout(
    cellHtml: String,
    width: Int,
    paint: Paint,
  ): StaticLayout {
    val cellPaint =
      TextPaint(paint).apply {
        textSize = paint.textSize * CELL_TEXT_SCALE
      }

    return StaticLayout.Builder
      .obtain(stripTags(cellHtml), 0, stripTags(cellHtml).length, cellPaint, maxOf(width, 1))
      .setAlignment(Layout.Alignment.ALIGN_NORMAL)
      .setIncludePad(false)
      .build()
  }

  /**
   * Cell text for drawing.
   *
   * Cells keep their inner HTML so the round-trip stays lossless, but the grid
   * paints plain text — rendering marks inside a cell is what the inline cell
   * editor is for.
   */
  private fun stripTags(html: String): String =
    html
      .replace(Regex("<[^>]*>"), "")
      .replace("&nbsp;", " ")
      .replace("&amp;", "&")
      .replace("&lt;", "<")
      .replace("&gt;", ">")
      .replace("&#39;", "'")
      .replace("&quot;", "\"")
      .trim()

  companion object {
    private const val BORDER_WIDTH = 1.5f
    private const val CELL_PADDING = 10
    private const val MIN_ROW_HEIGHT = 44
    private const val CELL_TEXT_SCALE = 0.92f
    private const val BORDER_ALPHA = 90
  }
}
