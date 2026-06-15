import type { CSSProperties } from 'react';
import type { HtmlStyle } from '../../types';
export declare function mergeWithDefaultHtmlStyle(htmlStyle?: HtmlStyle): Required<HtmlStyle>;
export declare const ETI_MENTION_CSS_VARS: {
    readonly color: (indicator: string) => string;
    readonly backgroundColor: (indicator: string) => string;
    readonly textDecorationLine: (indicator: string) => string;
};
export declare function htmlStyleToCSSVariables(htmlStyle?: HtmlStyle): CSSProperties;
//# sourceMappingURL=htmlStyleToCSSVariables.d.ts.map