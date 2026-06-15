/**
 * Collect image `File`s from the clipboard and build `OnPasteImagesEvent` payloads with `blob:` URIs.
 */
import type { Editor } from '@tiptap/react';
import type { NativeSyntheticEvent } from 'react-native';
import type { OnPasteImagesEvent } from '../types';
export declare function clipboardImageFiles(data: DataTransfer): File[];
export declare function buildPasteImagesPayload(files: File[]): Promise<OnPasteImagesEvent['images']>;
export declare function handleClipboardPasteImages(event: ClipboardEvent, getEditor: () => Editor | null, getOnPasteImages: () => ((e: NativeSyntheticEvent<OnPasteImagesEvent>) => void) | undefined): boolean;
//# sourceMappingURL=pasteImages.d.ts.map