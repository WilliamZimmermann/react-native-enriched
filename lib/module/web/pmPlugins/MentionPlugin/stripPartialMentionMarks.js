"use strict";

import { Fragment } from '@tiptap/pm/model';
export function stripPartialMentionMarks(fragment) {
  const nodes = [];
  fragment.forEach(node => nodes.push(node.isText ? node.mark(node.marks.filter(m => m.type.name !== 'mention' || node.text === m.attrs.text)) : node.copy(stripPartialMentionMarks(node.content))));
  return Fragment.from(nodes);
}
//# sourceMappingURL=stripPartialMentionMarks.js.map