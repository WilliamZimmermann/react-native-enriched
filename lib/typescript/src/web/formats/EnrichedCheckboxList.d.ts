declare module '@tiptap/core' {
    interface Commands<ReturnType> {
        checkboxList: {
            toggleCheckboxList: (checked: boolean) => ReturnType;
        };
    }
}
export declare const EnrichedCheckboxList: import("@tiptap/core").Node<import("@tiptap/extension-list").TaskListOptions, any>;
//# sourceMappingURL=EnrichedCheckboxList.d.ts.map