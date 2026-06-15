"use strict";

import { useOnEditorChange } from "./useOnEditorChange.js";
import { normalizeHtmlFromTiptap } from "./tiptapHtmlNormalizer.js";
export const useOnChangeHtml = (editor, onChangeHtml) => {
  useOnEditorChange(editor, onChangeHtml, e => normalizeHtmlFromTiptap(e.getHTML()));
};
//# sourceMappingURL=useOnChangeHtml.js.map