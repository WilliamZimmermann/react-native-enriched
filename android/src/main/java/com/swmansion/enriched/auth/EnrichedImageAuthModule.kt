package com.swmansion.enriched.auth

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class EnrichedImageAuthModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName() = "EnrichedImageAuth"

  @ReactMethod
  fun setAuthHeader(token: String?, origin: String?) {
    ImageAuthStore.set(token, origin)
  }
}
