package com.swmansion.enriched.textinput.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

/**
 * Fired when the user taps a cell of an inline table, so JS can float a real
 * editor over that cell (the caret cannot enter a table — the whole grid is one
 * character). Mirrors the iOS onTableCellTap field for field.
 *
 * The rect is in the editor view's coordinate space, in dp.
 */
class OnTableCellTapEvent(
  surfaceId: Int,
  viewId: Int,
  private val charIndex: Int,
  private val tableIndex: Int,
  private val row: Int,
  private val col: Int,
  private val x: Float,
  private val y: Float,
  private val width: Float,
  private val height: Float,
  private val colFractions: String,
) : Event<OnTableCellTapEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap {
    val data: WritableMap = Arguments.createMap()
    data.putInt("charIndex", charIndex)
    data.putInt("tableIndex", tableIndex)
    data.putInt("row", row)
    data.putInt("col", col)
    data.putDouble("x", x.toDouble())
    data.putDouble("y", y.toDouble())
    data.putDouble("width", width.toDouble())
    data.putDouble("height", height.toDouble())
    data.putString("colFractions", colFractions)
    return data
  }

  companion object {
    const val EVENT_NAME: String = "onTableCellTap"
  }
}
