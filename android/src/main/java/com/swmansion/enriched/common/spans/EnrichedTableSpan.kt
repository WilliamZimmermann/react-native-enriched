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
  android.content.res.Resources
    .getSystem()
    .displayMetrics.widthPixels - TABLE_HORIZONTAL_INSET

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

/** A cell located by [EnrichedTableSpan.cellAt], with its span-local frame. */
data class EnrichedTableCellHit(
  val row: Int,
  val col: Int,
  val rect: Rect,
)

/**
 * Draws a table inline in the editor.
 *
 * Android's counterpart to the iOS TableAttachment. iOS rasterises to an image
 * because TextKit wants an attachment; a `ReplacementSpan` can paint straight
 * onto the canvas, so there is no bitmap and no scaling to get wrong.
 *
 * The grid is painted, not laid out as text, so the caret can never sit inside
 * a cell — the span occupies a single character. Editing a cell therefore works
 * the way it does on iOS: [cellAt] resolves a touch to a cell + frame, the view
 * reports it through `onTableCellTap`, and JS floats a real editor over it.
 */
class EnrichedTableSpan(
  val data: EnrichedTableData,
  private val availableWidth: Int,
  /** Fill behind the first row, matching the read-only renderer. Null = none. */
  private val headerBackgroundColor: Int? = null,
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

  private val headerPaint =
    Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.FILL
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
        // The header row is filled first so the border draws over its edge.
        if (r == 0 && headerBackgroundColor != null) {
          headerPaint.color = headerBackgroundColor
          canvas.drawRect(
            x + rect.left,
            originY + rect.top,
            x + rect.right,
            originY + rect.bottom,
            headerPaint,
          )
        }

        canvas.drawRect(
          x + rect.left,
          originY + rect.top,
          x + rect.right,
          originY + rect.bottom,
          borderPaint,
        )

        val cell =
          data.rows
            .getOrNull(r)
            ?.getOrNull(c)
            .orEmpty()
        if (cell.isBlank()) continue

        canvas.save()
        canvas.translate(x + rect.left + CELL_PADDING, originY + rect.top + CELL_PADDING)
        cellLayout(cell, rect.width() - CELL_PADDING * 2, paint).draw(canvas)
        canvas.restore()
      }
    }
  }

  /**
   * Height the span reserved on its line. Zero until the first measure, which
   * always precedes a touch (the grid has to be on screen to be tapped).
   */
  val heightPx: Int
    get() = measuredHeight

  /** Rendered width, for the caller mapping a touch into span-local space. */
  val widthPx: Int
    get() = availableWidth

  /**
   * The cell containing ([localX], [localY]), given in the span's own space
   * (origin = the grid's top-left), or null when the touch missed the grid.
   */
  fun cellAt(
    localX: Float,
    localY: Float,
  ): EnrichedTableCellHit? {
    for ((r, row) in cellRects.withIndex()) {
      for ((c, rect) in row.withIndex()) {
        if (rect.contains(localX.toInt(), localY.toInt())) {
          return EnrichedTableCellHit(r, c, rect)
        }
      }
    }

    return null
  }

  /**
   * Column widths as fractions of the table width. Even split today; kept as a
   * list so a future per-column width lands here without changing the event.
   */
  fun columnFractions(): List<Float> {
    val cols = maxOf(data.colCount, 1)

    return List(cols) { 1f / cols }
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
  private fun stripTags(html: String): String = decodeEntities(html.replace(Regex("<[^>]*>"), "")).trim()

  /**
   * Decode the entities a cell's HTML can carry.
   *
   * The editor escapes every non-ASCII character NUMERICALLY, so a cell typed
   * as "Cabeçalho" round-trips as `Cabe&#231;alho` — which is what the grid
   * painted, character for character, before this decoded them.
   */
  private fun decodeEntities(text: String): String =
    NUMERIC_ENTITY
      .replace(text) { match ->
        val (hex, digits) = match.destructured
        val code = if (hex.isNotEmpty()) hex.toIntOrNull(16) else digits.toIntOrNull()
        code?.let { String(Character.toChars(it)) } ?: match.value
      }.replace("&nbsp;", " ")
      .replace("&lt;", "<")
      .replace("&gt;", ">")
      .replace("&quot;", "\"")
      .replace("&apos;", "'")
      // Last, so an escaped "&amp;lt;" does not become a tag-looking "<".
      .replace("&amp;", "&")

  companion object {
    /** `&#233;` or `&#xe9;` — hex in group 1, decimal in group 2. */
    private val NUMERIC_ENTITY = Regex("&#(?:x([0-9a-fA-F]+)|(\\d+));")

    private const val BORDER_WIDTH = 1.5f
    private const val CELL_PADDING = 10
    private const val MIN_ROW_HEIGHT = 44
    private const val CELL_TEXT_SCALE = 0.92f
    private const val BORDER_ALPHA = 90
  }
}
