package com.swmansion.enriched.auth

import java.net.URL

object ImageAuthStore {
  @Volatile private var token: String? = null

  @Volatile private var origin: URL? = null

  fun set(
    token: String?,
    origin: String?,
  ) {
    this.token = token?.takeIf { it.isNotEmpty() }
    this.origin =
      origin?.takeIf { it.isNotEmpty() }?.let {
        runCatching { URL(it) }.getOrNull()
      }
  }

  /** Bearer token iff [urlString] matches the configured origin + /api/mobile/ path. */
  fun tokenForUrl(urlString: String): String? {
    val t = token ?: return null
    val o = origin ?: return null
    val u = runCatching { URL(urlString) }.getOrNull() ?: return null
    val portOf = { x: URL -> if (x.port == -1) x.defaultPort else x.port }
    val sameOrigin =
      u.protocol.equals(o.protocol, true) &&
        u.host.equals(o.host, true) &&
        u.host.isNotEmpty() &&
        portOf(u) == portOf(o)
    return if (sameOrigin && u.path.startsWith("/api/mobile/")) t else null
  }
}
