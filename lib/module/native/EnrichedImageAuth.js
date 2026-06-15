"use strict";

import { NativeModules } from 'react-native';
const native = NativeModules.EnrichedImageAuth;

/**
 * Registers a process-global bearer token used by the native enriched image
 * loaders (iOS ImageAttachment / Android AsyncDrawable) when fetching images
 * whose URL origin matches `origin`. Pass `token = null` to clear it (e.g. on
 * sign-out). Safe no-op on binaries that predate the native module.
 */
export function setImageAuthHeader(token, origin) {
  native?.setAuthHeader(token ?? null, origin ?? null);
}
//# sourceMappingURL=EnrichedImageAuth.js.map