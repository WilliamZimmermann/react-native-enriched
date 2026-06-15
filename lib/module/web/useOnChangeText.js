"use strict";

import { nativeLeafText } from "./positionMapping.js";
import { useOnEditorChange } from "./useOnEditorChange.js";
export const useOnChangeText = (editor, onChangeText) => {
  useOnEditorChange(editor, onChangeText, e => {
    const doc = e.state.doc;
    return nativeLeafText(doc, 0, doc.content.size);
  });
};
//# sourceMappingURL=useOnChangeText.js.map