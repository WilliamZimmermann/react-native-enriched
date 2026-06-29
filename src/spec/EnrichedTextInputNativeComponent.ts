import { codegenNativeComponent, codegenNativeCommands } from 'react-native';
import type {
  BubblingEventHandler,
  DirectEventHandler,
  Float,
  Int32,
  UnsafeMixed,
} from 'react-native/Libraries/Types/CodegenTypes';
import type { ColorValue, HostComponent, ViewProps } from 'react-native';
import React from 'react';

export interface LinkNativeRegex {
  pattern: string;
  caseInsensitive: boolean;
  dotAll: boolean;
  // Link detection will be disabled
  isDisabled: boolean;
  // Use default native link regex
  isDefault: boolean;
}

export interface OnChangeTextEvent {
  value: string;
}

export interface OnChangeHtmlEvent {
  value: string;
}

export interface OnChangeStateEvent {
  bold: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  italic: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  underline: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  strikeThrough: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  inlineCode: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  h1: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  h2: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  h3: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  h4: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  h5: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  h6: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  codeBlock: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  blockQuote: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  orderedList: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  unorderedList: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  link: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  image: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  mention: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  checkboxList: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  highlight: {
    isActive: boolean;
    isConflicting: boolean;
    isBlocking: boolean;
  };
  alignment: string;
  // Caption of the currently-selected image (empty string when none / no
  // image selected). Lets the toolbar pre-fill its caption dialog.
  selectedImageCaption: string;
}

export interface OnLinkDetected {
  text: string;
  url: string;
  start: Int32;
  end: Int32;
}

export interface OnMentionDetectedInternal {
  text: string;
  indicator: string;
  payload: string;
}

export interface OnMentionDetected {
  text: string;
  indicator: string;
  attributes: Record<string, string>;
}

export interface OnMentionEvent {
  indicator: string;
  text: UnsafeMixed;
}

export interface OnChangeSelectionEvent {
  start: Int32;
  end: Int32;
  text: string;
  // On-screen bounding rect of the selection's first line, in the editor
  // view's coordinate space. Zero-size when the selection is collapsed —
  // JS uses it to anchor the selection popover above the highlight.
  rectX: Float;
  rectY: Float;
  rectWidth: Float;
  rectHeight: Float;
}

export interface OnTableCellTapEvent {
  // Text-storage location of the tapped table's Object Replacement Character.
  // The tap selects this 1-char range, so JS correlates the current selection
  // to the tapped table (a table ORC looks identical to an image ORC).
  charIndex: Int32;
  // Ordinal of the tapped table among all tables in the document (0-based).
  tableIndex: Int32;
  row: Int32;
  col: Int32;
  // Tapped cell's frame in the editor view's coordinate space (points), so JS
  // can position an inline cell editor over it.
  x: Float;
  y: Float;
  width: Float;
  height: Float;
  // The table's rendered column widths as comma-separated fractions (sum ≈ 1),
  // e.g. "0.3,0.4,0.3" — JS uses them to place per-column resize handles.
  colFractions: string;
}

export interface OnRequestHtmlResultEvent {
  requestId: Int32;
  html: UnsafeMixed;
}

export interface OnSubmitEditing {
  text: string;
}

export interface OnKeyPressEvent {
  key: string;
}

export interface ContextMenuItemConfig {
  text: string;
}

export interface TextShortcut {
  trigger: string;
  style: string;
}

export interface OnContextMenuItemPressEvent {
  itemText: string;
  selectedText: string;
  selectionStart: Int32;
  selectionEnd: Int32;
  styleState: {
    bold: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    italic: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    underline: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    strikeThrough: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    inlineCode: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    h1: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    h2: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    h3: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    h4: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    h5: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    h6: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    codeBlock: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    blockQuote: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    orderedList: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    unorderedList: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    link: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    image: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    mention: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    checkboxList: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    highlight: {
      isActive: boolean;
      isConflicting: boolean;
      isBlocking: boolean;
    };
    alignment: string;
    selectedImageCaption: string;
  };
}

interface TargetedEvent {
  target: Int32;
}

export interface PastedImage {
  uri: string;
  type: string;
  width: Float;
  height: Float;
}

export interface OnPasteImagesEvent {
  images: {
    uri: string;
    type: string;
    width: Float;
    height: Float;
  }[];
}

type Heading = {
  fontSize?: Float;
  bold?: boolean;
};

export interface HtmlStyleInternal {
  h1?: Heading;
  h2?: Heading;
  h3?: Heading;
  h4?: Heading;
  h5?: Heading;
  h6?: Heading;
  blockquote?: {
    borderColor?: ColorValue;
    borderWidth?: Float;
    gapWidth?: Float;
    color?: ColorValue;
  };
  codeblock?: {
    color?: ColorValue;
    borderRadius?: Float;
    backgroundColor?: ColorValue;
  };
  code?: {
    color?: ColorValue;
    backgroundColor?: ColorValue;
  };
  a?: {
    color?: ColorValue;
    textDecorationLine?: string;
  };
  // This is a workaround for the fact that codegen does not support Records.
  // On native Android side this will become a ReadableMap, on native iOS we can work with a folly::dynamic object.
  mention?: UnsafeMixed;
  ol?: {
    gapWidth?: Float;
    marginLeft?: Float;
    markerFontWeight?: string;
    markerColor?: ColorValue;
  };
  ul?: {
    bulletColor?: ColorValue;
    bulletSize?: Float;
    marginLeft?: Float;
    gapWidth?: Float;
  };
  ulCheckbox?: {
    gapWidth?: Float;
    boxSize?: Float;
    marginLeft?: Float;
    boxColor?: ColorValue;
  };
}

export interface NativeProps extends ViewProps {
  // base props
  autoFocus?: boolean;
  editable?: boolean;
  defaultValue?: string;
  placeholder?: string;
  placeholderTextColor?: ColorValue;
  mentionIndicators: string[];
  cursorColor?: ColorValue;
  selectionColor?: ColorValue;
  autoCapitalize?: string;
  htmlStyle?: HtmlStyleInternal;
  scrollEnabled?: boolean;
  linkRegex?: LinkNativeRegex;
  contextMenuItems?: ReadonlyArray<Readonly<ContextMenuItemConfig>>;
  // When true, suppress the native iOS edit menu (Cut/Copy/Paste/Look Up) on
  // text selection. Consumers that render their own selection toolbar set this
  // so the user doesn't see two overlapping menus.
  disableNativeSelectionMenu?: boolean;
  textShortcuts: ReadonlyArray<Readonly<TextShortcut>>;
  returnKeyType?: string;
  returnKeyLabel?: string;
  submitBehavior?: string;
  allowFontScaling?: boolean;

  // event callbacks
  onInputFocus?: DirectEventHandler<TargetedEvent>;
  onInputBlur?: DirectEventHandler<TargetedEvent>;
  onChangeText?: DirectEventHandler<OnChangeTextEvent>;
  onChangeHtml?: DirectEventHandler<OnChangeHtmlEvent>;
  onChangeState?: DirectEventHandler<OnChangeStateEvent>;
  onLinkDetected?: DirectEventHandler<OnLinkDetected>;
  onMentionDetected?: DirectEventHandler<OnMentionDetectedInternal>;
  onMention?: DirectEventHandler<OnMentionEvent>;
  onChangeSelection?: DirectEventHandler<OnChangeSelectionEvent>;
  onTableCellTap?: DirectEventHandler<OnTableCellTapEvent>;
  onRequestHtmlResult?: DirectEventHandler<OnRequestHtmlResultEvent>;
  onInputKeyPress?: DirectEventHandler<OnKeyPressEvent>;
  onPasteImages?: DirectEventHandler<OnPasteImagesEvent>;
  onContextMenuItemPress?: DirectEventHandler<OnContextMenuItemPressEvent>;
  onSubmitEditing?: BubblingEventHandler<OnSubmitEditing>;

  // Style related props - used for generating proper setters in component's manager
  // These should not be passed as regular props
  color?: ColorValue;
  fontSize?: Float;
  lineHeight?: Float;
  fontFamily?: string;
  fontWeight?: string;
  fontStyle?: string;

  // Used for onChangeHtml event performance optimization
  isOnChangeHtmlSet: boolean;
  // Used for onChangeText event performance optimization
  isOnChangeTextSet: boolean;

  // Experimental
  androidExperimentalSynchronousEvents: boolean;
  useHtmlNormalizer: boolean;
}

type ComponentType = HostComponent<NativeProps>;

interface NativeCommands {
  // General commands
  focus: (viewRef: React.ElementRef<ComponentType>) => void;
  blur: (viewRef: React.ElementRef<ComponentType>) => void;
  // Undo / redo the most recent text edit (backed by the native undo manager).
  undo: (viewRef: React.ElementRef<ComponentType>) => void;
  redo: (viewRef: React.ElementRef<ComponentType>) => void;
  setValue: (viewRef: React.ElementRef<ComponentType>, text: string) => void;
  // Insert / replace plain text at the current selection (or caret).
  insertText: (viewRef: React.ElementRef<ComponentType>, text: string) => void;
  setSelection: (
    viewRef: React.ElementRef<ComponentType>,
    start: Int32,
    end: Int32
  ) => void;
  // Programmatically focus a table cell (by table ordinal + row/col); the
  // native side emits onTableCellTap for it. Used for Tab navigation.
  focusTableCell: (
    viewRef: React.ElementRef<ComponentType>,
    tableIndex: Int32,
    row: Int32,
    col: Int32
  ) => void;

  // Text formatting commands
  toggleBold: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleItalic: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleUnderline: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleStrikeThrough: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleInlineCode: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleH1: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleH2: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleH3: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleH4: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleH5: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleH6: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleCodeBlock: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleBlockQuote: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleOrderedList: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleUnorderedList: (viewRef: React.ElementRef<ComponentType>) => void;
  toggleCheckboxList: (
    viewRef: React.ElementRef<ComponentType>,
    checked: boolean
  ) => void;
  indentList: (viewRef: React.ElementRef<ComponentType>) => void;
  outdentList: (viewRef: React.ElementRef<ComponentType>) => void;
  addLink: (
    viewRef: React.ElementRef<ComponentType>,
    start: Int32,
    end: Int32,
    text: string,
    url: string
  ) => void;
  removeLink: (
    viewRef: React.ElementRef<ComponentType>,
    start: Int32,
    end: Int32
  ) => void;
  addImage: (
    viewRef: React.ElementRef<ComponentType>,
    uri: string,
    width: Float,
    height: Float
  ) => void;
  // Set (or clear, when empty) the caption of the currently-selected image.
  setSelectedImageCaption: (
    viewRef: React.ElementRef<ComponentType>,
    caption: string
  ) => void;
  // Insert a horizontal rule (`<hr>`) at the caret, on its own line.
  insertHorizontalRule: (viewRef: React.ElementRef<ComponentType>) => void;
  startMention: (
    viewRef: React.ElementRef<ComponentType>,
    indicator: string
  ) => void;
  addMention: (
    viewRef: React.ElementRef<ComponentType>,
    indicator: string,
    text: string,
    payload: string
  ) => void;
  requestHTML: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: Int32
  ) => void;
  // Serialize the [start, end) range to an HTML fragment, returned via the
  // same onGetHtml event keyed by requestId.
  requestSelectionHTML: (
    viewRef: React.ElementRef<ComponentType>,
    requestId: Int32,
    start: Int32,
    end: Int32
  ) => void;
  // Replace the [start, end) range with a parsed HTML fragment (preserves
  // the fragment's formatting — headings, lists, bold/italic, etc.).
  replaceSelectionWithHtml: (
    viewRef: React.ElementRef<ComponentType>,
    start: Int32,
    end: Int32,
    html: string
  ) => void;
  setTextAlignment: (
    viewRef: React.ElementRef<ComponentType>,
    alignment: string
  ) => void;
  addHighlight: (
    viewRef: React.ElementRef<ComponentType>,
    start: Int32,
    end: Int32,
    color: string
  ) => void;
  removeHighlight: (
    viewRef: React.ElementRef<ComponentType>,
    start: Int32,
    end: Int32
  ) => void;
  // Strip inline formatting from the range (leaves plain text).
  clearFormatting: (
    viewRef: React.ElementRef<ComponentType>,
    start: Int32,
    end: Int32
  ) => void;
  // Remove color/highlight from the range.
  clearColors: (
    viewRef: React.ElementRef<ComponentType>,
    start: Int32,
    end: Int32
  ) => void;
}

export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({
  supportedCommands: [
    // General commands
    'focus',
    'blur',
    'undo',
    'redo',
    'setValue',
    'insertText',
    'setSelection',
    'focusTableCell',

    // Text formatting commands
    'toggleBold',
    'toggleItalic',
    'toggleUnderline',
    'toggleStrikeThrough',
    'toggleInlineCode',
    'toggleH1',
    'toggleH2',
    'toggleH3',
    'toggleH4',
    'toggleH5',
    'toggleH6',
    'toggleCodeBlock',
    'toggleBlockQuote',
    'toggleOrderedList',
    'toggleUnorderedList',
    'toggleCheckboxList',
    'indentList',
    'outdentList',
    'addLink',
    'removeLink',
    'addImage',
    'setSelectedImageCaption',
    'insertHorizontalRule',
    'startMention',
    'addMention',
    'requestHTML',
    'requestSelectionHTML',
    'replaceSelectionWithHtml',
    'setTextAlignment',
    'addHighlight',
    'removeHighlight',
    'clearFormatting',
    'clearColors',
  ],
});

export default codegenNativeComponent<NativeProps>('EnrichedTextInputView', {
  interfaceOnly: true,
}) as HostComponent<NativeProps>;
