import { Extension } from '@tiptap/core';
declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        stripBoldInStyledHeadings: {
            normalizeBoldInStyledHeadings: () => ReturnType;
        };
    }
}
export declare const StripBoldInStyledHeadingsPlugin: Extension<any, any>;
//# sourceMappingURL=StripBoldInStyledHeadingsPlugin.d.ts.map