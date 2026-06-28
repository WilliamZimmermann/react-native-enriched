import {
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
  type CSSProperties,
} from 'react';
import './EnrichedTextInput.css';
import { DOMSerializer } from '@tiptap/pm/model';
import type { Node } from '@tiptap/pm/model';
import type {
  EnrichedTextInputInstance,
  EnrichedTextInputProps,
} from '../types';
import { adaptWebToNativeEvent } from './adaptWebToNativeEvent';
import {
  tiptapPosToNativePos,
  nativePosToTiptapPos,
  nativeLeafText,
} from './positionMapping';
import {
  useEditor,
  EditorContent,
  type ChainedCommands,
  Editor,
} from '@tiptap/react';
import Document from '@tiptap/extension-document';
import Paragraph from '@tiptap/extension-paragraph';
import Text from '@tiptap/extension-text';
import History from '@tiptap/extension-history';
import { Placeholder } from '@tiptap/extensions/placeholder';
import { useOnChangeHtml } from './useOnChangeHtml';
import { useOnChangeText } from './useOnChangeText';
import { useOnChangeState } from './useOnChangeState';
import { useOnLinkDetected } from './useOnLinkDetected';
import {
  prepareHtmlForTiptap,
  normalizeHtmlFromTiptap,
} from './tiptapHtmlNormalizer';
import { ENRICHED_TEXT_INPUT_DEFAULT_PROPS } from '../utils/EnrichedTextInputDefaultProps';
import { enrichedInputStyleToCSSProperties } from './styleConversion/enrichedInputStyleToCSSProperties';
import { enrichedInputThemingToCSSProperties } from './styleConversion/enrichedInputThemingToCSSProperties';
import { buildMentionRulesCSS } from './styleConversion/buildMentionRulesCSS';
import {
  htmlStyleToCSSVariables,
  mergeWithDefaultHtmlStyle,
} from './styleConversion/htmlStyleToCSSVariables';
import { EnrichedBold } from './formats/EnrichedBold';
import { EnrichedItalic } from './formats/EnrichedItalic';
import { EnrichedStrike } from './formats/EnrichedStrike';
import { EnrichedUnderline } from './formats/EnrichedUnderline';
import { EnrichedCode } from './formats/EnrichedCode';
import { EnrichedHeading } from './formats/EnrichedHeading';
import { EnrichedBlockquote } from './formats/EnrichedBlockquote';
import { EnrichedCodeBlock } from './formats/EnrichedCodeBlock';
import { EnrichedImage } from './formats/EnrichedImage';
import { EnrichedLink, setLink, removeLink } from './formats/EnrichedLink';
import { EnrichedMention } from './formats/EnrichedMention';
import { EnrichedListItem } from './formats/EnrichedListItem';
import { EnrichedUnorderedList } from './formats/EnrichedUnorderedList';
import { EnrichedOrderedList } from './formats/EnrichedOrderedList';
import { EnrichedCheckboxItem } from './formats/EnrichedCheckboxItem';
import { EnrichedCheckboxList } from './formats/EnrichedCheckboxList';
import { StripBoldInStyledHeadingsPlugin } from './pmPlugins/StripBoldInStyledHeadingsPlugin';
import { StrictMarksPlugin } from './pmPlugins/StrictMarksPlugin';
import { MergeAdjacentSameKindBlocksPlugin } from './pmPlugins/MergeAdjacentSameKindBlocksPlugin';
import { StripMarksInCodeBlockPlugin } from './pmPlugins/StripMarksInCodeBlockPlugin';
import { handleClipboardPasteImages } from './pasteImages';
import {
  MentionPlugin,
  setMention,
  startMention,
  subscribeMentionEvents,
} from './pmPlugins/MentionPlugin';
import { StripMarksOnImagePlugin } from './pmPlugins/StripMarksOnImagePlugin';
import { ShortcutPlugin } from './pmPlugins/ShortcutPlugin';
import { returnKeyTypeToEnterKeyHint } from './returnKeyTypeToEnterKeyHint';
function runFocused(
  editor: Editor,
  apply: (chain: ChainedCommands) => ChainedCommands
) {
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
  htmlStyle,
}: EnrichedTextInputProps) => {
  const tiptapContent =
    defaultValue != null ? prepareHtmlForTiptap(defaultValue) : defaultValue;

  const resolvedHtmlStyle = useMemo(
    () => mergeWithDefaultHtmlStyle(htmlStyle),
    [htmlStyle]
  );

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
    onMentionDetected,
  });
  useEffect(() => {
    mentionCallbacksRef.current = {
      onStartMention,
      onChangeMention,
      onEndMention,
      onMentionDetected,
    };
  }, [onStartMention, onChangeMention, onEndMention, onMentionDetected]);

  const submitBehaviorRef = useRef(submitBehavior);
  const onSubmitEditingRef = useRef(onSubmitEditing);
  const onKeyPressRef = useRef(onKeyPress);
  const editorInstanceRef = useRef<Editor | null>(null);

  useEffect(() => {
    submitBehaviorRef.current = submitBehavior;
  }, [submitBehavior]);
  useEffect(() => {
    onSubmitEditingRef.current = onSubmitEditing;
  }, [onSubmitEditing]);
  useEffect(() => {
    onKeyPressRef.current = onKeyPress;
  }, [onKeyPress]);

  const handleKeyDown = (doc: Node, event: KeyboardEvent): boolean => {
    onKeyPressRef.current?.(adaptWebToNativeEvent(event, { key: event.key }));
    if (event.key !== 'Enter') {
      return false;
    }

    const sb = submitBehaviorRef.current;
    if (sb === 'submit' || sb === 'blurAndSubmit') {
      event.preventDefault();
      const text = nativeLeafText(doc, 0, doc.content.size);
      onSubmitEditingRef.current?.(adaptWebToNativeEvent(event, { text }));
      if (sb === 'blurAndSubmit') {
        editorInstanceRef.current?.commands.blur();
      }
      return true;
    }

    return false;
  };

  const extensions = useMemo(
    () => [
      Document,
      Paragraph,
      Text,
      History,
      EnrichedBold,
      EnrichedItalic,
      EnrichedUnderline,
      EnrichedStrike,
      EnrichedCode,
      EnrichedLink,
      EnrichedImage,
      EnrichedMention,
      EnrichedHeading,
      EnrichedBlockquote,
      EnrichedCodeBlock,
      EnrichedListItem,
      EnrichedCheckboxItem,
      EnrichedUnorderedList,
      EnrichedOrderedList,
      EnrichedCheckboxList,
      StripMarksInCodeBlockPlugin,
      StripMarksOnImagePlugin,
      StripBoldInStyledHeadingsPlugin.configure({
        getHtmlStyle: () => htmlStyleRef.current,
      }),
      MergeAdjacentSameKindBlocksPlugin,
      StrictMarksPlugin,
      MentionPlugin.configure({
        getIndicators: () => mentionIndicatorsRef.current,
      }),
      ShortcutPlugin.configure({
        getHtmlStyle: () => htmlStyleRef.current,
      }),
      Placeholder.configure({
        placeholder,
        showOnlyWhenEditable: true,
      }),
    ],
    [placeholder]
  );

  const editor = useEditor(
    {
      extensions,
      editable,
      autofocus: autoFocus,
      onCreate: ({ editor: _editor }) => {
        // Setting initial content in this way ensures all custom plugins are run and applied
        _editor.commands.setContent(tiptapContent ?? '');
      },
      onFocus: ({ event }) => {
        onFocus?.(adaptWebToNativeEvent(event, { target: -1 }));
      },
      onBlur: ({ event }) => {
        onBlur?.(adaptWebToNativeEvent(event, { target: -1 }));
      },
      onSelectionUpdate: ({ editor: _editor }) => {
        const { state } = _editor;
        const { from, to } = state.selection;

        const start = tiptapPosToNativePos(state.doc, from);
        const end = tiptapPosToNativePos(state.doc, to);
        const text = nativeLeafText(state.doc, from, to);
        // Web has no native selection rect to report (the host app owns
        // its own selection UI), so the rect fields are always zero — the
        // native path is the only one that anchors the popover.
        onChangeSelection?.(
          adaptWebToNativeEvent(null, {
            start,
            end,
            text,
            rectX: 0,
            rectY: 0,
            rectWidth: 0,
            rectHeight: 0,
          })
        );
      },
      editorProps: {
        handleKeyDown: (view, event) => handleKeyDown(view.state.doc, event),
        handlePaste: (_view, event) =>
          handleClipboardPasteImages(
            event,
            () => editorInstanceRef.current,
            () => onPasteImagesRef.current
          ),
        attributes: {
          autoCapitalize,
          enterkeyhint: returnKeyTypeToEnterKeyHint(returnKeyType),
        },
      },
    },
    [tiptapContent, extensions]
  );

  useEffect(() => {
    editorInstanceRef.current = editor ?? null;
  }, [editor]);

  useEffect(() => {
    if (!editor) return;
    let dom: HTMLElement;
    try {
      dom = editor.view.dom;
    } catch {
      return;
    }
    dom.setAttribute(
      'enterkeyhint',
      returnKeyTypeToEnterKeyHint(returnKeyType)
    );
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

  useImperativeHandle(
    ref,
    (): EnrichedTextInputInstance => ({
      focus: () => editor.commands.focus(),
      blur: () => editor.commands.blur(),
      undo: () => runFocused(editor, (c) => c.undo()),
      redo: () => runFocused(editor, (c) => c.redo()),
      setValue: (value: string) =>
        editor.commands.setContent(prepareHtmlForTiptap(value)),
      insertText: (text: string) =>
        runFocused(editor, (c) => c.insertContent(text)),
      setSelection: (start, end) => {
        const doc = editor.state.doc;
        runFocused(editor, (c) =>
          c.setTextSelection({
            from: nativePosToTiptapPos(doc, start),
            to: nativePosToTiptapPos(doc, end),
          })
        );
      },
      getHTML: () => Promise.resolve(normalizeHtmlFromTiptap(editor.getHTML())),
      getSelectionHtml: (start: number, end: number) => {
        const doc = editor.state.doc;
        const slice = doc.slice(
          nativePosToTiptapPos(doc, start),
          nativePosToTiptapPos(doc, end)
        );
        const fragment = DOMSerializer.fromSchema(
          editor.schema
        ).serializeFragment(slice.content);
        const div = document.createElement('div');
        div.appendChild(fragment);
        return Promise.resolve(normalizeHtmlFromTiptap(div.innerHTML));
      },
      replaceSelectionWithHtml: (start: number, end: number, html: string) => {
        const doc = editor.state.doc;
        runFocused(editor, (c) =>
          c.insertContentAt(
            {
              from: nativePosToTiptapPos(doc, start),
              to: nativePosToTiptapPos(doc, end),
            },
            prepareHtmlForTiptap(html)
          )
        );
      },
      toggleBold: () => runFocused(editor, (c) => c.toggleBold()),
      toggleItalic: () => runFocused(editor, (c) => c.toggleItalic()),
      toggleUnderline: () => runFocused(editor, (c) => c.toggleUnderline()),
      toggleStrikeThrough: () => runFocused(editor, (c) => c.toggleStrike()),
      toggleInlineCode: () => runFocused(editor, (c) => c.toggleCode()),
      toggleH1: () => runFocused(editor, (c) => c.toggleHeading({ level: 1 })),
      toggleH2: () => runFocused(editor, (c) => c.toggleHeading({ level: 2 })),
      toggleH3: () => runFocused(editor, (c) => c.toggleHeading({ level: 3 })),
      toggleH4: () => runFocused(editor, (c) => c.toggleHeading({ level: 4 })),
      toggleH5: () => runFocused(editor, (c) => c.toggleHeading({ level: 5 })),
      toggleH6: () => runFocused(editor, (c) => c.toggleHeading({ level: 6 })),
      toggleCodeBlock: () => runFocused(editor, (c) => c.toggleCodeBlock()),
      toggleBlockQuote: () => runFocused(editor, (c) => c.toggleBlockquote()),
      toggleOrderedList: () => runFocused(editor, (c) => c.toggleOrderedList()),
      toggleUnorderedList: () =>
        runFocused(editor, (c) => c.toggleUnorderedList()),
      toggleCheckboxList: (checked: boolean) =>
        runFocused(editor, (c) => c.toggleCheckboxList(checked)),
      // Indent/outdent are native-only features in v0.8 of this fork — the
      // TipTap web fallback would need its own list-nesting commands which
      // it doesn't ship. No-op on web so the type contract is preserved
      // without misleading users into thinking it'll work in the browser.
      indentList: () => {},
      outdentList: () => {},
      setLink: (start: number, end: number, text: string, url: string) =>
        setLink(editor, start, end, text, url),
      removeLink: (start: number, end: number) =>
        removeLink(editor, start, end),
      // Web parity stubs — the native side carries the real
      // implementation. TipTap's Highlight extension lives in the web
      // host app, not in this vendor wrapper.
      setHighlight: (_start: number, _end: number, _color: string) => {},
      removeHighlight: (_start: number, _end: number) => {},
      // Strip inline marks on the current selection. clearColors is a parity
      // stub: highlight/color marks live in the host app's TipTap config, not
      // this wrapper (same as setHighlight/removeHighlight above).
      clearFormatting: (_start: number, _end: number) =>
        runFocused(editor, (c) => c.unsetAllMarks()),
      clearColors: (_start: number, _end: number) => {},
      startMention: (indicator: string) => {
        startMention(editor, indicator, mentionIndicatorsRef.current);
      },
      setMention: (
        indicator: string,
        text: string,
        attributes?: Record<string, string>
      ) => setMention(editor, indicator, text, attributes),
      setImage: (src: string, width: number, height: number) =>
        runFocused(editor, (c) => c.setImage({ src, width, height })),
      setSelectedImageCaption: (caption: string) =>
        runFocused(editor, (c) =>
          c.updateAttributes('image', { caption: caption || null })
        ),
      measure: () => {},
      measureInWindow: () => {},
      measureLayout: () => {},
      setNativeProps: () => {},
      setTextAlignment: () => {},
    }),
    [editor]
  );

  const editorStyle: CSSProperties = useMemo(
    () => enrichedInputStyleToCSSProperties(style ?? {}, { scrollEnabled }),
    [scrollEnabled, style]
  );

  const cssVars = useMemo(
    () => htmlStyleToCSSVariables(resolvedHtmlStyle),
    [resolvedHtmlStyle]
  );

  const themingStyle = useMemo(
    (): CSSProperties =>
      enrichedInputThemingToCSSProperties({
        cursorColor,
        placeholderTextColor,
        selectionColor,
      }),
    [cursorColor, placeholderTextColor, selectionColor]
  );

  const mentionRulesCSS = useMemo(
    () => buildMentionRulesCSS(resolvedHtmlStyle),
    [resolvedHtmlStyle]
  );

  const finalStyle = useMemo(
    () => ({ ...editorStyle, ...cssVars, ...themingStyle }),
    [editorStyle, cssVars, themingStyle]
  );

  return (
    <>
      {mentionRulesCSS ? <style>{mentionRulesCSS}</style> : null}
      <EditorContent
        editor={editor}
        className="eti-editor"
        // Cast to bypass a csstype version mismatch between this fork's
        // hoisted node_modules and the consuming monorepo's. The runtime
        // shape is identical (both csstype 3.x); only the structural type
        // identity differs and React.CSSProperties has the same problem.
        // Safe to widen — only the web fallback uses this path, the React
        // Native mobile build doesn't touch it.
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        style={finalStyle as any}
        data-placeholder={placeholder}
      />
    </>
  );
};
