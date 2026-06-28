import type { BubblingEventHandler, DirectEventHandler, Float, Int32, UnsafeMixed } from 'react-native/Libraries/Types/CodegenTypes';
import type { ColorValue, HostComponent, ViewProps } from 'react-native';
import React from 'react';
export interface LinkNativeRegex {
    pattern: string;
    caseInsensitive: boolean;
    dotAll: boolean;
    isDisabled: boolean;
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
    rectX: Float;
    rectY: Float;
    rectWidth: Float;
    rectHeight: Float;
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
    disableNativeSelectionMenu?: boolean;
    textShortcuts: ReadonlyArray<Readonly<TextShortcut>>;
    returnKeyType?: string;
    returnKeyLabel?: string;
    submitBehavior?: string;
    allowFontScaling?: boolean;
    onInputFocus?: DirectEventHandler<TargetedEvent>;
    onInputBlur?: DirectEventHandler<TargetedEvent>;
    onChangeText?: DirectEventHandler<OnChangeTextEvent>;
    onChangeHtml?: DirectEventHandler<OnChangeHtmlEvent>;
    onChangeState?: DirectEventHandler<OnChangeStateEvent>;
    onLinkDetected?: DirectEventHandler<OnLinkDetected>;
    onMentionDetected?: DirectEventHandler<OnMentionDetectedInternal>;
    onMention?: DirectEventHandler<OnMentionEvent>;
    onChangeSelection?: DirectEventHandler<OnChangeSelectionEvent>;
    onRequestHtmlResult?: DirectEventHandler<OnRequestHtmlResultEvent>;
    onInputKeyPress?: DirectEventHandler<OnKeyPressEvent>;
    onPasteImages?: DirectEventHandler<OnPasteImagesEvent>;
    onContextMenuItemPress?: DirectEventHandler<OnContextMenuItemPressEvent>;
    onSubmitEditing?: BubblingEventHandler<OnSubmitEditing>;
    color?: ColorValue;
    fontSize?: Float;
    lineHeight?: Float;
    fontFamily?: string;
    fontWeight?: string;
    fontStyle?: string;
    isOnChangeHtmlSet: boolean;
    isOnChangeTextSet: boolean;
    androidExperimentalSynchronousEvents: boolean;
    useHtmlNormalizer: boolean;
}
type ComponentType = HostComponent<NativeProps>;
interface NativeCommands {
    focus: (viewRef: React.ElementRef<ComponentType>) => void;
    blur: (viewRef: React.ElementRef<ComponentType>) => void;
    undo: (viewRef: React.ElementRef<ComponentType>) => void;
    redo: (viewRef: React.ElementRef<ComponentType>) => void;
    setValue: (viewRef: React.ElementRef<ComponentType>, text: string) => void;
    insertText: (viewRef: React.ElementRef<ComponentType>, text: string) => void;
    setSelection: (viewRef: React.ElementRef<ComponentType>, start: Int32, end: Int32) => void;
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
    toggleCheckboxList: (viewRef: React.ElementRef<ComponentType>, checked: boolean) => void;
    indentList: (viewRef: React.ElementRef<ComponentType>) => void;
    outdentList: (viewRef: React.ElementRef<ComponentType>) => void;
    addLink: (viewRef: React.ElementRef<ComponentType>, start: Int32, end: Int32, text: string, url: string) => void;
    removeLink: (viewRef: React.ElementRef<ComponentType>, start: Int32, end: Int32) => void;
    addImage: (viewRef: React.ElementRef<ComponentType>, uri: string, width: Float, height: Float) => void;
    setSelectedImageCaption: (viewRef: React.ElementRef<ComponentType>, caption: string) => void;
    startMention: (viewRef: React.ElementRef<ComponentType>, indicator: string) => void;
    addMention: (viewRef: React.ElementRef<ComponentType>, indicator: string, text: string, payload: string) => void;
    requestHTML: (viewRef: React.ElementRef<ComponentType>, requestId: Int32) => void;
    requestSelectionHTML: (viewRef: React.ElementRef<ComponentType>, requestId: Int32, start: Int32, end: Int32) => void;
    replaceSelectionWithHtml: (viewRef: React.ElementRef<ComponentType>, start: Int32, end: Int32, html: string) => void;
    setTextAlignment: (viewRef: React.ElementRef<ComponentType>, alignment: string) => void;
    addHighlight: (viewRef: React.ElementRef<ComponentType>, start: Int32, end: Int32, color: string) => void;
    removeHighlight: (viewRef: React.ElementRef<ComponentType>, start: Int32, end: Int32) => void;
    clearFormatting: (viewRef: React.ElementRef<ComponentType>, start: Int32, end: Int32) => void;
    clearColors: (viewRef: React.ElementRef<ComponentType>, start: Int32, end: Int32) => void;
}
export declare const Commands: NativeCommands;
declare const _default: HostComponent<NativeProps>;
export default _default;
//# sourceMappingURL=EnrichedTextInputNativeComponent.d.ts.map