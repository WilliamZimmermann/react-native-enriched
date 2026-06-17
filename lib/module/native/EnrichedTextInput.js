"use strict";

import { useEffect, useImperativeHandle, useMemo, useRef } from 'react';
import { useCallback } from 'react';
import EnrichedTextInputNativeComponent, { Commands } from '../spec/EnrichedTextInputNativeComponent';
import { normalizeHtmlStyle } from "../utils/normalizeHtmlStyle.js";
import { toNativeRegexConfig } from "../utils/regexParser.js";
import { nullthrows } from "../utils/nullthrows.js";
import { ENRICHED_TEXT_INPUT_DEFAULT_PROPS } from "../utils/EnrichedTextInputDefaultProps.js";
import { jsx as _jsx } from "react/jsx-runtime";
const warnMentionIndicators = indicator => {
  console.warn(`Looks like you are trying to set a "${indicator}" but it's not in the mentionIndicators prop`);
};
export const EnrichedTextInput = ({
  ref,
  autoFocus,
  editable = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.editable,
  mentionIndicators = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.mentionIndicators.slice(),
  defaultValue,
  placeholder,
  placeholderTextColor,
  cursorColor,
  selectionColor,
  style,
  autoCapitalize = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.autoCapitalize,
  htmlStyle = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.htmlStyle,
  linkRegex: _linkRegex,
  onFocus,
  onBlur,
  onChangeText,
  onChangeHtml,
  onChangeState,
  onLinkDetected,
  onMentionDetected,
  onStartMention,
  onChangeMention,
  onEndMention,
  onChangeSelection,
  onKeyPress,
  onSubmitEditing,
  returnKeyType,
  returnKeyLabel,
  submitBehavior,
  contextMenuItems,
  disableNativeSelectionMenu,
  textShortcuts = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.textShortcuts,
  androidExperimentalSynchronousEvents = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.androidExperimentalSynchronousEvents,
  useHtmlNormalizer = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.useHtmlNormalizer,
  scrollEnabled = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.scrollEnabled,
  allowFontScaling = ENRICHED_TEXT_INPUT_DEFAULT_PROPS.allowFontScaling,
  ...rest
}) => {
  const nativeRef = useRef(null);
  const nextHtmlRequestId = useRef(1);
  const pendingHtmlRequests = useRef(new Map());

  // Store onPress callbacks in a ref so native only receives serializable data
  const contextMenuCallbacksRef = useRef(new Map());
  useEffect(() => {
    const callbacksMap = new Map();
    if (contextMenuItems) {
      for (const item of contextMenuItems) {
        callbacksMap.set(item.text, item.onPress);
      }
    }
    contextMenuCallbacksRef.current = callbacksMap;
  }, [contextMenuItems]);
  const nativeContextMenuItems = useMemo(() => contextMenuItems?.filter(item => item.visible !== false).map(item => ({
    text: item.text
  })), [contextMenuItems]);
  const handleContextMenuItemPress = useCallback(e => {
    const {
      itemText,
      selectedText,
      selectionStart,
      selectionEnd,
      styleState
    } = e.nativeEvent;
    const callback = contextMenuCallbacksRef.current.get(itemText);
    callback?.({
      text: selectedText,
      selection: {
        start: selectionStart,
        end: selectionEnd
      },
      styleState
    });
  }, []);
  useEffect(() => {
    const pendingRequests = pendingHtmlRequests.current;
    return () => {
      pendingRequests.forEach(({
        reject
      }) => {
        reject(new Error('Component unmounted'));
      });
      pendingRequests.clear();
    };
  }, []);
  const normalizedHtmlStyle = useMemo(() => normalizeHtmlStyle(htmlStyle, mentionIndicators), [htmlStyle, mentionIndicators]);
  const linkRegex = useMemo(() => toNativeRegexConfig(_linkRegex), [_linkRegex]);
  useImperativeHandle(ref, () => ({
    measureInWindow: callback => {
      nullthrows(nativeRef.current).measureInWindow(callback);
    },
    measure: callback => {
      nullthrows(nativeRef.current).measure(callback);
    },
    measureLayout: (relativeToNativeComponentRef, onSuccess, onFail) => {
      nullthrows(nativeRef.current).measureLayout(relativeToNativeComponentRef, onSuccess, onFail);
    },
    setNativeProps: nativeProps => {
      nullthrows(nativeRef.current).setNativeProps(nativeProps);
    },
    focus: () => {
      Commands.focus(nullthrows(nativeRef.current));
    },
    blur: () => {
      Commands.blur(nullthrows(nativeRef.current));
    },
    undo: () => {
      Commands.undo(nullthrows(nativeRef.current));
    },
    redo: () => {
      Commands.redo(nullthrows(nativeRef.current));
    },
    setValue: value => {
      Commands.setValue(nullthrows(nativeRef.current), value);
    },
    insertText: text => {
      Commands.insertText(nullthrows(nativeRef.current), text);
    },
    getHTML: () => {
      return new Promise((resolve, reject) => {
        const requestId = nextHtmlRequestId.current++;
        pendingHtmlRequests.current.set(requestId, {
          resolve,
          reject
        });
        Commands.requestHTML(nullthrows(nativeRef.current), requestId);
      });
    },
    getSelectionHtml: (start, end) => {
      return new Promise((resolve, reject) => {
        const requestId = nextHtmlRequestId.current++;
        pendingHtmlRequests.current.set(requestId, {
          resolve,
          reject
        });
        Commands.requestSelectionHTML(nullthrows(nativeRef.current), requestId, start, end);
      });
    },
    replaceSelectionWithHtml: (start, end, html) => {
      Commands.replaceSelectionWithHtml(nullthrows(nativeRef.current), start, end, html);
    },
    toggleBold: () => {
      Commands.toggleBold(nullthrows(nativeRef.current));
    },
    toggleItalic: () => {
      Commands.toggleItalic(nullthrows(nativeRef.current));
    },
    toggleUnderline: () => {
      Commands.toggleUnderline(nullthrows(nativeRef.current));
    },
    toggleStrikeThrough: () => {
      Commands.toggleStrikeThrough(nullthrows(nativeRef.current));
    },
    toggleInlineCode: () => {
      Commands.toggleInlineCode(nullthrows(nativeRef.current));
    },
    toggleH1: () => {
      Commands.toggleH1(nullthrows(nativeRef.current));
    },
    toggleH2: () => {
      Commands.toggleH2(nullthrows(nativeRef.current));
    },
    toggleH3: () => {
      Commands.toggleH3(nullthrows(nativeRef.current));
    },
    toggleH4: () => {
      Commands.toggleH4(nullthrows(nativeRef.current));
    },
    toggleH5: () => {
      Commands.toggleH5(nullthrows(nativeRef.current));
    },
    toggleH6: () => {
      Commands.toggleH6(nullthrows(nativeRef.current));
    },
    toggleCodeBlock: () => {
      Commands.toggleCodeBlock(nullthrows(nativeRef.current));
    },
    toggleBlockQuote: () => {
      Commands.toggleBlockQuote(nullthrows(nativeRef.current));
    },
    toggleOrderedList: () => {
      Commands.toggleOrderedList(nullthrows(nativeRef.current));
    },
    toggleUnorderedList: () => {
      Commands.toggleUnorderedList(nullthrows(nativeRef.current));
    },
    toggleCheckboxList: checked => {
      Commands.toggleCheckboxList(nullthrows(nativeRef.current), checked);
    },
    indentList: () => {
      Commands.indentList(nullthrows(nativeRef.current));
    },
    outdentList: () => {
      Commands.outdentList(nullthrows(nativeRef.current));
    },
    setLink: (start, end, text, url) => {
      Commands.addLink(nullthrows(nativeRef.current), start, end, text, url);
    },
    removeLink: (start, end) => {
      Commands.removeLink(nullthrows(nativeRef.current), start, end);
    },
    setHighlight: (start, end, color) => {
      Commands.addHighlight(nullthrows(nativeRef.current), start, end, color);
    },
    removeHighlight: (start, end) => {
      Commands.removeHighlight(nullthrows(nativeRef.current), start, end);
    },
    setImage: (uri, width, height) => {
      Commands.addImage(nullthrows(nativeRef.current), uri, width, height);
    },
    setMention: (indicator, text, attributes) => {
      // Codegen does not support objects as Commands parameters, so we stringify attributes
      const parsedAttributes = JSON.stringify(attributes ?? {});
      Commands.addMention(nullthrows(nativeRef.current), indicator, text, parsedAttributes);
    },
    startMention: indicator => {
      if (!mentionIndicators?.includes(indicator)) {
        warnMentionIndicators(indicator);
      }
      Commands.startMention(nullthrows(nativeRef.current), indicator);
    },
    setSelection: (start, end) => {
      Commands.setSelection(nullthrows(nativeRef.current), start, end);
    },
    setTextAlignment: alignment => {
      Commands.setTextAlignment(nullthrows(nativeRef.current), alignment);
    }
  }));
  const handleMentionEvent = e => {
    const mentionText = e.nativeEvent.text;
    const mentionIndicator = e.nativeEvent.indicator;
    if (typeof mentionText === 'string') {
      if (mentionText === '') {
        onStartMention?.(mentionIndicator);
      } else {
        onChangeMention?.({
          indicator: mentionIndicator,
          text: mentionText
        });
      }
    } else if (mentionText === null) {
      onEndMention?.(mentionIndicator);
    }
  };
  const handleLinkDetected = e => {
    const {
      text,
      url,
      start,
      end
    } = e.nativeEvent;
    onLinkDetected?.({
      text,
      url,
      start,
      end
    });
  };
  const handleMentionDetected = e => {
    const {
      text,
      indicator,
      payload
    } = e.nativeEvent;
    const attributes = JSON.parse(payload);
    onMentionDetected?.({
      text,
      indicator,
      attributes
    });
  };
  const handleRequestHtmlResult = e => {
    const {
      requestId,
      html
    } = e.nativeEvent;
    const pending = pendingHtmlRequests.current.get(requestId);
    if (!pending) return;
    if (html === null || typeof html !== 'string') {
      pending.reject(new Error('Failed to parse HTML'));
    } else {
      pending.resolve(html);
    }
    pendingHtmlRequests.current.delete(requestId);
  };
  return /*#__PURE__*/_jsx(EnrichedTextInputNativeComponent, {
    ref: nativeRef,
    mentionIndicators: mentionIndicators,
    editable: editable,
    autoFocus: autoFocus,
    defaultValue: defaultValue,
    placeholder: placeholder,
    placeholderTextColor: placeholderTextColor,
    cursorColor: cursorColor,
    selectionColor: selectionColor,
    style: style,
    autoCapitalize: autoCapitalize,
    htmlStyle: normalizedHtmlStyle,
    linkRegex: linkRegex,
    onInputFocus: onFocus,
    onInputBlur: onBlur,
    onChangeText: onChangeText,
    onChangeHtml: onChangeHtml,
    isOnChangeHtmlSet: onChangeHtml !== undefined,
    isOnChangeTextSet: onChangeText !== undefined,
    onChangeState: onChangeState,
    onLinkDetected: handleLinkDetected,
    onMentionDetected: handleMentionDetected,
    onMention: handleMentionEvent,
    onChangeSelection: onChangeSelection,
    onRequestHtmlResult: handleRequestHtmlResult,
    onInputKeyPress: onKeyPress,
    contextMenuItems: nativeContextMenuItems,
    disableNativeSelectionMenu: disableNativeSelectionMenu,
    textShortcuts: textShortcuts,
    onContextMenuItemPress: handleContextMenuItemPress,
    onSubmitEditing: onSubmitEditing,
    returnKeyType: returnKeyType,
    returnKeyLabel: returnKeyLabel,
    submitBehavior: submitBehavior,
    androidExperimentalSynchronousEvents: androidExperimentalSynchronousEvents,
    useHtmlNormalizer: useHtmlNormalizer,
    scrollEnabled: scrollEnabled,
    allowFontScaling: allowFontScaling,
    ...rest
  });
};
//# sourceMappingURL=EnrichedTextInput.js.map