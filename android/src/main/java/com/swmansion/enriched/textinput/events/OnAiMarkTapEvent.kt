package com.swmansion.enriched.textinput.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

/**
 * Fired when the caret enters an AI suggestion/flag mark, so JS can open the
 * accept/reject popover anchored at the mark's on-screen rect (dp). Mirrors the
 * iOS onAiMarkTap.
 */
class OnAiMarkTapEvent(
  surfaceId: Int,
  viewId: Int,
  private val kind: String,
  private val aiId: String,
  private val status: String,
  private val explanation: String,
  private val rectX: Float,
  private val rectY: Float,
  private val rectWidth: Float,
  private val rectHeight: Float,
) : Event<OnAiMarkTapEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap {
    val data: WritableMap = Arguments.createMap()
    data.putString("kind", kind)
    data.putString("aiId", aiId)
    data.putString("status", status)
    data.putString("explanation", explanation)
    data.putDouble("rectX", rectX.toDouble())
    data.putDouble("rectY", rectY.toDouble())
    data.putDouble("rectWidth", rectWidth.toDouble())
    data.putDouble("rectHeight", rectHeight.toDouble())
    return data
  }

  companion object {
    const val EVENT_NAME: String = "onAiMarkTap"
  }
}
