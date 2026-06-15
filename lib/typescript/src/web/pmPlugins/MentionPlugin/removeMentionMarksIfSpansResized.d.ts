import type { Mark } from '@tiptap/pm/model';
import type { EditorState, Transaction } from '@tiptap/pm/state';
export type MentionMarkRange = {
    from: number;
    to: number;
    mark: Mark;
};
export declare function removeMentionMarksIfSpansResized(transactions: readonly Transaction[], oldState: EditorState, newState: EditorState): Transaction | null;
//# sourceMappingURL=removeMentionMarksIfSpansResized.d.ts.map