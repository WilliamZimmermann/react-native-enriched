"use strict";

import { useEffect, useRef } from 'react';
import { adaptWebToNativeEvent } from "./adaptWebToNativeEvent.js";
export const useOnEditorChange = (editor, handler, getValue) => {
  const lastValueRef = useRef('');
  useEffect(() => {
    if (!handler) return;
    const handleUpdate = () => {
      const value = getValue(editor);
      if (value !== lastValueRef.current) {
        lastValueRef.current = value;
        handler(adaptWebToNativeEvent(null, {
          value
        }));
      }
    };
    handleUpdate();
    editor.on('transaction', handleUpdate);
    return () => {
      editor.off('transaction', handleUpdate);
    };
  }, [editor, handler, getValue]);
};
//# sourceMappingURL=useOnEditorChange.js.map