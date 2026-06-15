"use strict";

export function startMention(editor, indicator, indicators) {
  if (!indicators.includes(indicator)) {
    console.warn(`[EnrichedMention] startMention: "${indicator}" is not in mentionIndicators`);
  }
  editor.chain().focus().insertContent(indicator).run();
}
//# sourceMappingURL=startMention.js.map