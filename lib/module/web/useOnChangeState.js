"use strict";

import { useEffect, useRef } from 'react';
import { adaptWebToNativeEvent } from "./adaptWebToNativeEvent.js";
import { isAnyParagraphFormatActive, isFormatBlocked } from "./formats/formatRules.js";
export const useOnChangeState = (editor, htmlStyle, onChangeState) => {
  const lastStateHashRef = useRef(null);
  useEffect(() => {
    if (!editor || !onChangeState) return;
    const handleUpdate = () => {
      const state = buildState(editor, htmlStyle);
      const stateHash = hashState(state);
      if (lastStateHashRef.current === stateHash) {
        return;
      }
      lastStateHashRef.current = stateHash;
      onChangeState(adaptWebToNativeEvent(null, state));
    };
    handleUpdate();
    editor.on('transaction', handleUpdate);
    return () => {
      editor.off('transaction', handleUpdate);
    };
  }, [editor, onChangeState, htmlStyle]);
};
function buildState(editor, htmlStyle) {
  const isAnyBlockActive = isAnyParagraphFormatActive(editor);
  function inlineFormat(tiptapName, isConflicting) {
    return {
      isActive: editor.isActive(tiptapName),
      isConflicting,
      isBlocking: isFormatBlocked(tiptapName, editor, htmlStyle)
    };
  }
  function paragraphFormat(isActive, additionalIsConflicting = false) {
    return {
      isActive,
      isConflicting: !isActive && isAnyBlockActive || additionalIsConflicting,
      isBlocking: false
    };
  }
  return {
    bold: inlineFormat('bold', false),
    italic: inlineFormat('italic', false),
    underline: inlineFormat('underline', false),
    strikeThrough: inlineFormat('strike', false),
    inlineCode: inlineFormat('code', editor.isActive('link')),
    h1: paragraphFormat(editor.isActive('heading', {
      level: 1
    })),
    h2: paragraphFormat(editor.isActive('heading', {
      level: 2
    })),
    h3: paragraphFormat(editor.isActive('heading', {
      level: 3
    })),
    h4: paragraphFormat(editor.isActive('heading', {
      level: 4
    })),
    h5: paragraphFormat(editor.isActive('heading', {
      level: 5
    })),
    h6: paragraphFormat(editor.isActive('heading', {
      level: 6
    })),
    blockQuote: paragraphFormat(editor.isActive('blockquote')),
    codeBlock: paragraphFormat(editor.isActive('codeBlock'), editor.isActive('link')),
    orderedList: paragraphFormat(editor.isActive('orderedList')),
    unorderedList: paragraphFormat(editor.isActive('unorderedList')),
    checkboxList: paragraphFormat(editor.isActive('checkboxList')),
    highlight: inlineFormat('highlight', false),
    link: inlineFormat('link', editor.isActive('code') || editor.isActive('link') || editor.isActive('codeBlock')),
    mention: inlineFormat('mention', editor.isActive('code') || editor.isActive('codeBlock')),
    image: {
      isActive: editor.isActive('image'),
      isConflicting: editor.isActive('link'),
      isBlocking: isFormatBlocked('image', editor, htmlStyle)
    },
    alignment: 'left',
    selectedImageCaption: editor.getAttributes('image').caption ?? ''
  };
}
function hashState(state) {
  return Object.values(state).map(formatState => String(getFormatHash(formatState.isActive, formatState.isConflicting, formatState.isBlocking))).join('');
}
function getFormatHash(isActive, isConflicting, isBlocking) {
  // eslint-disable-next-line no-bitwise
  return +isActive << 2 | +isConflicting << 1 | +isBlocking << 0;
}
//# sourceMappingURL=useOnChangeState.js.map