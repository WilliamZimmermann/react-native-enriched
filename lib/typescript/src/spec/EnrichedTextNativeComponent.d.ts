import { type ColorValue } from 'react-native';
import type { HostComponent, ViewProps } from 'react-native';
import type { DirectEventHandler, Float, Int32, UnsafeMixed } from 'react-native/Libraries/Types/CodegenTypes';
type Heading = {
    fontSize?: Float;
    bold?: boolean;
};
export interface EnrichedTextHtmlStyleInternal {
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
        pressColor?: ColorValue;
        pressTextDecorationLine?: string;
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
export interface OnLinkPressEvent {
    url: string;
}
export interface OnMentionPressEventInternal {
    text: string;
    indicator: string;
    attributes: UnsafeMixed;
}
export interface OnMentionPressEvent {
    text: string;
    indicator: string;
    attributes: Record<string, string>;
}
export interface NativeProps extends ViewProps {
    text: string;
    htmlStyle?: EnrichedTextHtmlStyleInternal;
    useHtmlNormalizer: boolean;
    allowFontScaling?: boolean;
    ellipsizeMode: string;
    numberOfLines: Int32;
    selectable: boolean;
    selectionColor?: ColorValue;
    onLinkPress?: DirectEventHandler<OnLinkPressEvent>;
    onMentionPress?: DirectEventHandler<OnMentionPressEventInternal>;
    color?: ColorValue;
    fontSize?: Float;
    fontFamily?: string;
    fontWeight?: string;
    fontStyle?: string;
}
declare const _default: HostComponent<NativeProps>;
export default _default;
//# sourceMappingURL=EnrichedTextNativeComponent.d.ts.map