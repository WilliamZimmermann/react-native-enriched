declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        codeBlock: {
            toggleCodeBlock: () => ReturnType;
        };
    }
}
export declare const EnrichedCodeBlock: import("@tiptap/core").Node<import("@tiptap/extension-blockquote").BlockquoteOptions, any>;
//# sourceMappingURL=EnrichedCodeBlock.d.ts.map