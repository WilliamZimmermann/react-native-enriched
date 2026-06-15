import type { ChainedCommands, Editor } from '@tiptap/core';
/**
 * Clears block styling with `clearNodes`, then wraps the selection’s blocks in a flat
 * `listTypeName` (one `itemTypeName` per block).
 *
 * We don't use toggleList because we've changed ListItem's content to
 * 'paragraph', in order not to allow nested lists. This however caused the
 * default toggle implementation to fail.
 *
 * SELECTION PRESERVATION: Modifying node boundaries here (destroying and
 * recreating blocks) causes ProseMirror's built-in selection to be invalid. To
 * fix this, we use our Android/iOS native coordinate system. Because the native
 * selection only cares about raw content and ignores Tiptap's node boundary
 * tokens, we store the cursor positions in the native format before the
 * transaction, and map them back to the new Tiptap document afterward.
 */
export declare function applyWrappingListToSelection(editor: Editor, chain: () => ChainedCommands, listTypeName: string, itemTypeName: string, itemAttrs?: Record<string, unknown> | null): boolean;
//# sourceMappingURL=applyWrappingListToSelection.d.ts.map