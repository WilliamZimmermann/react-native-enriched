declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        unorderedList: {
            toggleUnorderedList: () => ReturnType;
        };
    }
}
export declare const EnrichedUnorderedList: import("@tiptap/core").Node<import("@tiptap/extension-list").BulletListOptions, any>;
//# sourceMappingURL=EnrichedUnorderedList.d.ts.map