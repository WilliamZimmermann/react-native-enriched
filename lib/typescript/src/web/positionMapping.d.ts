import type { Node } from '@tiptap/pm/model';
/**
 * Position model mismatch: ProseMirror vs native (iOS/Android)
 *
 * Native selection/cursor offsets are plain string indices in rendered text
 * Block boundaries are represented by a single '\n'.
 *
 * ProseMirror positions are tree positions. Entering/leaving block nodes
 * consumes extra positions that do not map to extra native characters.
 * Crossing one paragraph boundary is 1 native char ('\n') but usually 2 PM
 * positions (close paragraph + open next paragraph).
 *
 * Example for three paragraphs "AAAA", "BBBB", "CCCC":
 *
 *   PM:      1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17
 *   Native:  0  1  2  3  4  4  5  6  7   8  9  9 10 11 12 13 14
 *
 * PM 5 and PM 6 both map to native 4, PM 11 and PM 12 both map to native 9.
 *
 * Inline images occupy one index in the native plain string as a '\ufffc' character,
 * we do the same for the web implementation.
 */
/**
 * Plain text in the native coordinate model for [from, to), including '\ufffc' per inline image.
 */
export declare function nativeLeafText(doc: Node, from: number, to: number): string;
/**
 * Returns the native position for a given TipTap document position.
 */
export declare function tiptapPosToNativePos(doc: Node, tiptapPos: number): number;
/**
 * Returns the TipTap document position for a given native position.
 *
 * Traverses only text-bearing block nodes (paragraphs, headings, etc.),
 * skipping wrapper nodes like block quotes and lists. This ensures the result
 * is always a valid cursor position drilled down to the innermost content node.
 */
export declare function nativePosToTiptapPos(doc: Node, nativePos: number): number;
//# sourceMappingURL=positionMapping.d.ts.map