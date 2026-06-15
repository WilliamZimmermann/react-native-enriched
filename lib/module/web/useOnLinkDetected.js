"use strict";

import { useEffect, useRef } from 'react';
import { getMarkRange, getMarksBetween } from '@tiptap/core';
import { tiptapPosToNativePos } from "./positionMapping.js";
export const useOnLinkDetected = (editor, onLinkDetected) => {
  const lastEmittedRef = useRef(null);
  const wasInLinkRef = useRef(false);
  useEffect(() => {
    if (!editor || !onLinkDetected) return;
    const handleUpdate = () => {
      const {
        state
      } = editor;
      const linkType = state.schema.marks.link;
      if (!linkType) return;
      const $pos = state.selection.$from;
      const range = getMarkRange($pos, linkType);
      if (!range) {
        if (wasInLinkRef.current) {
          wasInLinkRef.current = false;
          onLinkDetected({
            text: '',
            url: '',
            start: 0,
            end: 0
          });
        }
        lastEmittedRef.current = null;
        return;
      }
      const linkMark = getMarksBetween(range.from, range.to, state.doc).find(entry => entry.mark.type === linkType)?.mark;
      if (!linkMark) {
        wasInLinkRef.current = false;
        lastEmittedRef.current = null;
        return;
      }
      wasInLinkRef.current = true;
      const {
        from,
        to
      } = range;
      const url = linkMark.attrs.href ?? '';
      const text = state.doc.textBetween(from, to, '\n');
      const start = tiptapPosToNativePos(state.doc, from);
      const end = tiptapPosToNativePos(state.doc, to);
      const next = {
        text,
        url,
        start,
        end
      };
      const prev = lastEmittedRef.current;
      if (prev !== null && prev.text === next.text && prev.url === next.url && prev.start === next.start && prev.end === next.end) {
        return;
      }
      lastEmittedRef.current = next;
      onLinkDetected(next);
    };
    handleUpdate();
    editor.on('transaction', handleUpdate);
    return () => {
      wasInLinkRef.current = false;
      editor.off('transaction', handleUpdate);
    };
  }, [editor, onLinkDetected]);
};
//# sourceMappingURL=useOnLinkDetected.js.map