import { Extension } from '@tiptap/core';
import type { HtmlStyle } from '../../types';
export interface ShortcutPluginOptions {
    getHtmlStyle: () => Required<HtmlStyle>;
}
export declare const ShortcutPlugin: Extension<ShortcutPluginOptions, any>;
//# sourceMappingURL=ShortcutPlugin.d.ts.map