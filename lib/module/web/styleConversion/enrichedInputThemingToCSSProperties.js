"use strict";

import { toColor } from "./toColor.js";
export function enrichedInputThemingToCSSProperties({
  cursorColor,
  placeholderTextColor,
  selectionColor
}) {
  const extra = {};
  const caret = toColor(cursorColor);
  if (caret) extra.caretColor = caret;
  const placeholderCss = toColor(placeholderTextColor);
  if (placeholderCss) extra['--eti-placeholder-text-color'] = placeholderCss;
  const selectionCss = toColor(selectionColor);
  if (selectionCss) extra['--eti-selection-color'] = selectionCss;
  return extra;
}
//# sourceMappingURL=enrichedInputThemingToCSSProperties.js.map