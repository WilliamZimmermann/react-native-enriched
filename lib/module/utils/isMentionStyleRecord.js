"use strict";

export function isMentionStyleRecord(mentionStyle) {
  if (mentionStyle && typeof mentionStyle === 'object' && !Array.isArray(mentionStyle)) {
    const keys = Object.keys(mentionStyle);
    return keys.length > 0 && keys.every(key => typeof mentionStyle[key] === 'object' && mentionStyle[key] !== null);
  }
  return false;
}
//# sourceMappingURL=isMentionStyleRecord.js.map