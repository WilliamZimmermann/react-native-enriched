"use strict";

import { Extension } from '@tiptap/core';
import { Slice } from '@tiptap/pm/model';
import { Plugin } from '@tiptap/pm/state';
import { makeMentionPluginState } from "./makeMentionPluginState.js";
import { mentionPluginKey } from "./mentionPluginKey.js";
import { removeMentionMarksIfSpansResized } from "./removeMentionMarksIfSpansResized.js";
import { stripPartialMentionMarks } from "./stripPartialMentionMarks.js";
export { mentionPluginKey } from "./mentionPluginKey.js";
export { setMention } from "./setMention.js";
export { startMention } from "./startMention.js";
export { subscribeMentionEvents } from "./subscribeMentionEvents.js";
export const MentionPlugin = Extension.create({
  name: 'mentionTrigger',
  addOptions() {
    return {
      getIndicators: () => {
        throw new Error('MentionPlugin.configure({ getIndicators }) is required');
      }
    };
  },
  addProseMirrorPlugins() {
    return [new Plugin({
      key: mentionPluginKey,
      props: {
        transformPasted(slice) {
          return new Slice(stripPartialMentionMarks(slice.content), slice.openStart, slice.openEnd);
        }
      },
      state: makeMentionPluginState(this.options.getIndicators),
      appendTransaction: removeMentionMarksIfSpansResized
    })];
  }
});
//# sourceMappingURL=index.js.map