"use strict";

import { ListItem } from '@tiptap/extension-list';
import { listBackspace, listEnter } from "./listKeyboard.js";
const LIST_WRAPPERS = ['unorderedList', 'orderedList'];
export const EnrichedListItem = ListItem.extend({
  content: 'paragraph',
  addKeyboardShortcuts() {
    return {
      Enter: ({
        editor
      }) => listEnter(editor, 'listItem'),
      Backspace: ({
        editor
      }) => listBackspace(editor, 'listItem', LIST_WRAPPERS)
    };
  }
});
//# sourceMappingURL=EnrichedListItem.js.map