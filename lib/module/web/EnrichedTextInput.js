"use strict";

import { useEffect, useImperativeHandle, useMemo, useRef } from 'react';
import './EnrichedTextInput.css';
import { DOMSerializer } from '@tiptap/pm/model';
import { adaptWebToNativeEvent } from "./adaptWebToNativeEvent.js";
import { tiptapPosToNativePos, nativePosToTiptapPos, nativeLeafText } from "./positionMapping.js";
import { useEditor, EditorContent } from '@tiptap/react';
import Document from '@tiptap/extension-document';
import Paragraph from '@tiptap/extension-paragraph';
import Text from '@tiptap/extension-text';
import History from '@tiptap/extension-history';
import { Placeholder } from '@tiptap/extensions/placeholder';
import { useOnChangeHtml } from "./useOnChangeHtml.js";
import { useOnChangeText } from "./useOnChangeText.js";
import { useOnChangeState } from "./useOnChangeState.js";
import { useOnLinkDetected } from "./useOnLinkDetected.js";
import { prepareHtmlForTiptap, normalizeHtmlFromTiptap } from "./tiptapHtmlNormalizer.js";
import { ENRICHED_TEXT_INPUT_DEFAULT_PROPS } from "../utils/EnrichedTextInputDefaultProps.js";
import { enrichedInputStyleToCSSProperties } from "./styleConversion/enrichedInputStyleToCSSProperties.js";
import { enrichedInputThemingToCSSProperties } from "./styleConversion/enrichedInputThemingToCSSProperties.js";
import { buildMentionRulesCSS } from "./styleConversion/buildMentionRulesCSS.js";
import { htmlStyleToCSSVariables, mergeWithDefaultHtmlStyle } from "./styleConversion/htmlStyleToCSSVariables.js";
import { EnrichedBold } from "./formats/EnrichedBold.js";
import { EnrichedItalic } from "./formats/EnrichedItalic.js";
import { EnrichedStrike } from "./formats/EnrichedStrike.js";
import { EnrichedUnderline } from "./formats/EnrichedUnderline.js";
import { EnrichedCode } from "./formats/EnrichedCode.js";
import { EnrichedHeading } from "./formats/EnrichedHeading.js";
import { EnrichedBlockquote } from "./formats/EnrichedBlockquote.js";
import { EnrichedCodeBlock } from "./formats/EnrichedCodeBlock.js";
import { EnrichedImage } from "./formats/EnrichedImage.js";
import { EnrichedLink, setLink, removeLink } from "./formats/EnrichedLink.js";
import { EnrichedMention } from "./formats/EnrichedMention.js";
import { EnrichedListItem } from "./formats/EnrichedListItem.js";
import { EnrichedUnorderedList } from "./formats/EnrichedUnorderedList.js";
import { EnrichedOrderedList } from "./formats/EnrichedOrderedList.js";
import { EnrichedCheckboxItem } from "./formats/EnrichedCheckboxItem.js";
import { EnrichedCheckboxList } from "./formats/EnrichedCheckboxList.js";
import { StripBoldInStyledHeadingsPlugin } from "./pmPlugins/StripBoldInStyledHeadingsPlugin.js";
import { StrictMarksPlugin } from "./pmPlugins/StrictMarksPlugin.js";
import { MergeAdjacentSameKindBlocksPlugin } from "./pmPlugins/MergeAdjacentSameKindBlocksPlugin.js";
import { StripMarksInCodeBlockPlugin } from "./pmPlugins/StripMarksInCodeBlockPlugin.js";
import { handleClipboardPasteImages } from "./pasteImages.js";
import { MentionPlugin, setMention, startMention, subscribeMentionEvents } from "./pmPlugins/MentionPlugin/index.js";
import { StripMarksOnImagePlugin } from "./pmPlugins/StripMarksOnImagePlugin.js";
import { ShortcutPlugin } from "./pmPlugins/ShortcutPlugin.js";
import { returnKeyTypeToEnterKeyHint } from "./returnKeyTypeToEnterKeyHint.js";
import { jsx as _jsx, Fragment as _Fragment, jsxs as _jsxs } from "react/jsx-runtime";
function runFocused(editor, apply) {
  apply(editor.chain().focus()).run();
}
export const EnrichedTextInput = ({
  ref,
  defaultValue,
  autoFocus,
  editable = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.editable,
  placeholder = '',
  placeholderTextColor,
  cursorColor,
  selectionColor,
  autoCapitalize = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.autoCapitalize,
  scrollEnabled = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.scrollEnabled,
  mentionIndicators = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.mentionIndicators.slice(),
  onFocus,
  style,
  onBlur,
  onChangeSelection,
  onKeyPress,
  onChangeText,
  onChangeHtml,
  onChangeState,
  onLinkDetected,
  onSubmitEditing,
  returnKeyType,
  submitBehavior,
  onPasteImages,
  onMentionDetected,
  onStartMention,
  onChangeMention,
  onEndMention,
  htmlStyle
}) => {
  const tiptapContent = defaultValue != null ? prepareHtmlForTiptap(defaultValue) : defaultValue;
  const resolvedHtmlStyle = useMemo(() => mergeWithDefaultHtmlStyle(htmlStyle), [htmlStyle]);
  const htmlStyleRef = useRef(resolvedHtmlStyle);
  useEffect(() => {
    htmlStyleRef.current = resolvedHtmlStyle;
  }, [resolvedHtmlStyle]);
  const onPasteImagesRef = useRef(onPasteImages);
  useEffect(() => {
    onPasteImagesRef.current = onPasteImages;
  }, [onPasteImages]);
  const mentionIndicatorsRef = useRef(mentionIndicators);
  useEffect(() => {
    mentionIndicatorsRef.current = mentionIndicators;
  }, [mentionIndicators]);
  const mentionCallbacksRef = useRef({
    onStartMention,
    onChangeMention,
    onEndMention,
    onMentionDetected
  });
  useEffect(() => {
    mentionCallbacksRef.current = {
      onStartMention,
      onChangeMention,
      onEndMention,
      onMentionDetected
    };
  }, [onStartMention, onChangeMention, onEndMention, onMentionDetected]);
  const submitBehaviorRef = useRef(submitBehavior);
  const onSubmitEditingRef = useRef(onSubmitEditing);
  const onKeyPressRef = useRef(onKeyPress);
  const editorInstanceRef = useRef(null);
  useEffect(() => {
    submitBehaviorRef.current = submitBehavior;
  }, [submitBehavior]);
  useEffect(() => {
    onSubmitEditingRef.current = onSubmitEditing;
  }, [onSubmitEditing]);
  useEffect(() => {
    onKeyPressRef.current = onKeyPress;
  }, [onKeyPress]);
  const handleKeyDown = (doc, event) => {
    onKeyPressRef.current?.(adaptWebToNativeEvent(event, {
      key: event.key
    }));
    if (event.key !== 'Enter') {
      return false;
    }
    const sb = submitBehaviorRef.current;
    if (sb === 'submit' || sb === 'blurAndSubmit') {
      event.preventDefault();
      const text = nativeLeafText(doc, 0, doc.content.size);
      onSubmitEditingRef.current?.(adaptWebToNativeEvent(event, {
        text
      }));
      if (sb === 'blurAndSubmit') {
        editorInstanceRef.current?.commands.blur();
      }
      return true;
    }
    return false;
  };
  const extensions = useMemo(() => [Document, Paragraph, Text, History, EnrichedBold, EnrichedItalic, EnrichedUnderline, EnrichedStrike, EnrichedCode, EnrichedLink, EnrichedImage, EnrichedMention, EnrichedHeading, EnrichedBlockquote, EnrichedCodeBlock, EnrichedListItem, EnrichedCheckboxItem, EnrichedUnorderedList, EnrichedOrderedList, EnrichedCheckboxList, StripMarksInCodeBlockPlugin, StripMarksOnImagePlugin, StripBoldInStyledHeadingsPlugin.configure({
    getHtmlStyle: () => htmlStyleRef.current
  }), MergeAdjacentSameKindBlocksPlugin, StrictMarksPlugin, MentionPlugin.configure({
    getIndicators: () => mentionIndicatorsRef.current
  }), ShortcutPlugin.configure({
    getHtmlStyle: () => htmlStyleRef.current
  }), Placeholder.configure({
    placeholder,
    showOnlyWhenEditable: true
  })], [placeholder]);
  const editor = useEditor({
    extensions,
    editable,
    autofocus: autoFocus,
    onCreate: ({
      editor: _editor
    }) => {
      // Setting initial content in this way ensures all custom plugins are run and applied
      _editor.commands.setContent(tiptapContent ?? '');
    },
    onFocus: ({
      event
    }) => {
      onFocus?.(adaptWebToNativeEvent(event, {
        target: -1
      }));
    },
    onBlur: ({
      event
    }) => {
      onBlur?.(adaptWebToNativeEvent(event, {
        target: -1
      }));
    },
    onSelectionUpdate: ({
      editor: _editor
    }) => {
      const {
        state
      } = _editor;
      const {
        from,
        to
      } = state.selection;
      const start = tiptapPosToNativePos(state.doc, from);
      const end = tiptapPosToNativePos(state.doc, to);
      const text = nativeLeafText(state.doc, from, to);
      // Web has no native selection rect to report (the host app owns
      // its own selection UI), so the rect fields are always zero — the
      // native path is the only one that anchors the popover.
      onChangeSelection?.(adaptWebToNativeEvent(null, {
        start,
        end,
        text,
        rectX: 0,
        rectY: 0,
        rectWidth: 0,
        rectHeight: 0
      }));
    },
    editorProps: {
      handleKeyDown: (view, event) => handleKeyDown(view.state.doc, event),
      handlePaste: (_view, event) => handleClipboardPasteImages(event, () => editorInstanceRef.current, () => onPasteImagesRef.current),
      attributes: {
        autoCapitalize,
        enterkeyhint: returnKeyTypeToEnterKeyHint(returnKeyType)
      }
    }
  }, [tiptapContent, extensions]);
  useEffect(() => {
    editorInstanceRef.current = editor ?? null;
  }, [editor]);
  useEffect(() => {
    if (!editor) return;
    let dom;
    try {
      dom = editor.view.dom;
    } catch {
      return;
    }
    dom.setAttribute('enterkeyhint', returnKeyTypeToEnterKeyHint(returnKeyType));
  }, [editor, returnKeyType]);
  useEffect(() => {
    editor?.commands.normalizeBoldInStyledHeadings();
  }, [editor, resolvedHtmlStyle]);
  useEffect(() => {
    if (!editor) return;
    return subscribeMentionEvents(editor, () => mentionCallbacksRef.current);
  }, [editor]);
  useOnChangeHtml(editor, onChangeHtml);
  useOnChangeText(editor, onChangeText);
  useOnChangeState(editor, resolvedHtmlStyle, onChangeState);
  useOnLinkDetected(editor, onLinkDetected);
  useImperativeHandle(ref, () => ({
    focus: () => editor.commands.focus(),
    blur: () => editor.commands.blur(),
    undo: () => runFocused(editor, c => c.undo()),
    redo: () => runFocused(editor, c => c.redo()),
    setValue: value => editor.commands.setContent(prepareHtmlForTiptap(value)),
    insertText: text => runFocused(editor, c => c.insertContent(text)),
    setSelection: (start, end) => {
      const doc = editor.state.doc;
      runFocused(editor, c => c.setTextSelection({
        from: nativePosToTiptapPos(doc, start),
        to: nativePosToTiptapPos(doc, end)
      }));
    },
    getHTML: () => Promise.resolve(normalizeHtmlFromTiptap(editor.getHTML())),
    getSelectionHtml: (start, end) => {
      const doc = editor.state.doc;
      const slice = doc.slice(nativePosToTiptapPos(doc, start), nativePosToTiptapPos(doc, end));
      const fragment = DOMSerializer.fromSchema(editor.schema).serializeFragment(slice.content);
      const div = document.createElement('div');
      div.appendChild(fragment);
      return Promise.resolve(normalizeHtmlFromTiptap(div.innerHTML));
    },
    replaceSelectionWithHtml: (start, end, html) => {
      const doc = editor.state.doc;
      runFocused(editor, c => c.insertContentAt({
        from: nativePosToTiptapPos(doc, start),
        to: nativePosToTiptapPos(doc, end)
      }, prepareHtmlForTiptap(html)));
    },
    toggleBold: () => runFocused(editor, c => c.toggleBold()),
    toggleItalic: () => runFocused(editor, c => c.toggleItalic()),
    toggleUnderline: () => runFocused(editor, c => c.toggleUnderline()),
    toggleStrikeThrough: () => runFocused(editor, c => c.toggleStrike()),
    toggleInlineCode: () => runFocused(editor, c => c.toggleCode()),
    toggleH1: () => runFocused(editor, c => c.toggleHeading({
      level: 1
    })),
    toggleH2: () => runFocused(editor, c => c.toggleHeading({
      level: 2
    })),
    toggleH3: () => runFocused(editor, c => c.toggleHeading({
      level: 3
    })),
    toggleH4: () => runFocused(editor, c => c.toggleHeading({
      level: 4
    })),
    toggleH5: () => runFocused(editor, c => c.toggleHeading({
      level: 5
    })),
    toggleH6: () => runFocused(editor, c => c.toggleHeading({
      level: 6
    })),
    toggleCodeBlock: () => runFocused(editor, c => c.toggleCodeBlock()),
    toggleBlockQuote: () => runFocused(editor, c => c.toggleBlockquote()),
    toggleOrderedList: () => runFocused(editor, c => c.toggleOrderedList()),
    toggleUnorderedList: () => runFocused(editor, c => c.toggleUnorderedList()),
    toggleCheckboxList: checked => runFocused(editor, c => c.toggleCheckboxList(checked)),
    // Indent/outdent are native-only features in v0.8 of this fork — the
    // TipTap web fallback would need its own list-nesting commands which
    // it doesn't ship. No-op on web so the type contract is preserved
    // without misleading users into thinking it'll work in the browser.
    indentList: () => {},
    outdentList: () => {},
    setLink: (start, end, text, url) => setLink(editor, start, end, text, url),
    removeLink: (start, end) => removeLink(editor, start, end),
    // Web parity stubs — the native side carries the real
    // implementation. TipTap's Highlight extension lives in the web
    // host app, not in this vendor wrapper.
    setHighlight: (_start, _end, _color) => {},
    removeHighlight: (_start, _end) => {},
    // Strip inline marks on the current selection. clearColors is a parity
    // stub: highlight/color marks live in the host app's TipTap config, not
    // this wrapper (same as setHighlight/removeHighlight above).
    clearFormatting: (_start, _end) => runFocused(editor, c => c.unsetAllMarks()),
    clearColors: (_start, _end) => {},
    startMention: indicator => {
      startMention(editor, indicator, mentionIndicatorsRef.current);
    },
    setMention: (indicator, text, attributes) => setMention(editor, indicator, text, attributes),
    setImage: (src, width, height) => runFocused(editor, c => c.setImage({
      src,
      width,
      height
    })),
    measure: () => {},
    measureInWindow: () => {},
    measureLayout: () => {},
    setNativeProps: () => {},
    setTextAlignment: () => {}
  }), [editor]);
  const editorStyle = useMemo(() => enrichedInputStyleToCSSProperties(style ?? {}, {
    scrollEnabled
  }), [scrollEnabled, style]);
  const cssVars = useMemo(() => htmlStyleToCSSVariables(resolvedHtmlStyle), [resolvedHtmlStyle]);
  const themingStyle = useMemo(() => enrichedInputThemingToCSSProperties({
    cursorColor,
    placeholderTextColor,
    selectionColor
  }), [cursorColor, placeholderTextColor, selectionColor]);
  const mentionRulesCSS = useMemo(() => buildMentionRulesCSS(resolvedHtmlStyle), [resolvedHtmlStyle]);
  const finalStyle = useMemo(() => ({
    ...editorStyle,
    ...cssVars,
    ...themingStyle
  }), [editorStyle, cssVars, themingStyle]);
  return /*#__PURE__*/_jsxs(_Fragment, {
    children: [mentionRulesCSS ? /*#__PURE__*/_jsx("style", {
      children: mentionRulesCSS
    }) : null, /*#__PURE__*/_jsx(EditorContent, {
      editor: editor,
      className: "eti-editor"
      // Cast to bypass a csstype version mismatch between this fork's
      // hoisted node_modules and the consuming monorepo's. The runtime
      // shape is identical (both csstype 3.x); only the structural type
      // identity differs and React.CSSProperties has the same problem.
      // Safe to widen — only the web fallback uses this path, the React
      // Native mobile build doesn't touch it.
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ,
      style: finalStyle,
      "data-placeholder": placeholder
    })]
  });
};
//# sourceMappingURL=EnrichedTextInput.js.map