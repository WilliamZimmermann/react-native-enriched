import { type Editor } from '@tiptap/core';
import type { ResolvedPos } from '@tiptap/pm/model';
export declare function findCutBefore($pos: ResolvedPos): ResolvedPos | null;
/** Line start → lift current block or join with the block above (wrapped blocks + lists). */
export declare function lineStartBackspace(editor: Editor, options: {
    isActive: () => boolean;
    lift: () => boolean;
    shouldJoinBefore: (nodeNameBefore: string | undefined) => boolean;
}): boolean;
export declare function wrappedBlockEnter(editor: Editor, wrapperNodeName: string): boolean;
export declare function wrappedBlockBackspace(editor: Editor, wrapperNodeName: string): boolean;
//# sourceMappingURL=wrappedBlockKeyboard.d.ts.map