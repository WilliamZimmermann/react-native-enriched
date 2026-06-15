"use strict";

import { useCallback, useImperativeHandle, useMemo, useRef } from 'react';
import EnrichedTextNativeComponent from '../spec/EnrichedTextNativeComponent';
import { nullthrows } from "../utils/nullthrows.js";
import { normalizeEnrichedTextHtmlStyle } from "../utils/normalizeHtmlStyle.js";
import { jsx as _jsx } from "react/jsx-runtime";
export const EnrichedText = ({
  ref,
  children,
  style,
  htmlStyle: _htmlStyle = {},
  useHtmlNormalizer = false,
  ellipsizeMode = 'tail',
  numberOfLines = 0,
  selectable = false,
  selectionColor,
  allowFontScaling = true,
  onLinkPress: _onLinkPress,
  onMentionPress: _onMentionPress,
  ...rest
}) => {
  const nativeRef = useRef(null);
  const htmlStyle = useMemo(() => normalizeEnrichedTextHtmlStyle(_htmlStyle), [_htmlStyle]);
  const onLinkPress = useCallback(e => {
    _onLinkPress?.(e.nativeEvent);
  }, [_onLinkPress]);
  const onMentionPress = useCallback(e => {
    const {
      text,
      indicator,
      attributes
    } = e.nativeEvent;
    _onMentionPress?.({
      text,
      indicator,
      attributes: attributes
    });
  }, [_onMentionPress]);
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
      nullthrows(nativeRef.current).focus();
    },
    blur: () => {
      nullthrows(nativeRef.current).blur();
    }
  }));
  return /*#__PURE__*/_jsx(EnrichedTextNativeComponent, {
    ref: nativeRef,
    text: children,
    style: style,
    htmlStyle: htmlStyle,
    useHtmlNormalizer: useHtmlNormalizer,
    ellipsizeMode: ellipsizeMode,
    numberOfLines: numberOfLines,
    selectable: selectable,
    selectionColor: selectionColor,
    allowFontScaling: allowFontScaling,
    onLinkPress: onLinkPress,
    onMentionPress: onMentionPress,
    ...rest
  });
};
//# sourceMappingURL=EnrichedText.js.map