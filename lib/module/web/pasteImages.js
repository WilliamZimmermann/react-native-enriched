"use strict";

/**
 * Collect image `File`s from the clipboard and build `OnPasteImagesEvent` payloads with `blob:` URIs.
 */

import { adaptWebToNativeEvent } from "./adaptWebToNativeEvent.js";
import { isImageBlocked } from "./formats/formatRules.js";
import { readImageDimensionsFromBlob } from "./pastedImageDimensions.js";
const isImageLikeClipboardFile = (file, reportedMime) => reportedMime.startsWith('image/') || file.type.startsWith('image/');

/** Browsers often expose the same paste as two `File`s (items vs files) with different `name`. */
function dedupeImageFiles(files) {
  const seen = new Set();
  const out = [];
  for (const file of files) {
    const key = `${file.size}\0${file.lastModified}\0${file.type}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(file);
  }
  return out;
}
export function clipboardImageFiles(data) {
  const fromItems = [];
  for (const item of [...data.items]) {
    if (item == null || item.kind !== 'file') continue;
    const file = item.getAsFile();
    if (!file) continue;
    if (isImageLikeClipboardFile(file, item.type)) fromItems.push(file);
  }
  if (fromItems.length > 0) return dedupeImageFiles(fromItems);
  const fromFiles = [];
  for (const file of [...data.files]) {
    if (isImageLikeClipboardFile(file, file.type)) fromFiles.push(file);
  }
  return dedupeImageFiles(fromFiles);
}
export async function buildPasteImagesPayload(files) {
  return Promise.all(files.map(async file => {
    const uri = URL.createObjectURL(file);
    const {
      width,
      height
    } = await readImageDimensionsFromBlob(file, uri);
    return {
      uri,
      type: file.type || 'image/png',
      width,
      height
    };
  }));
}
export function handleClipboardPasteImages(event, getEditor, getOnPasteImages) {
  const clipboardData = event.clipboardData;
  if (!clipboardData) return false;
  const files = clipboardImageFiles(clipboardData);
  if (files.length === 0) return false;
  const ed = getEditor();
  if (!ed || isImageBlocked(ed)) return false;
  const onPasteImages = getOnPasteImages();
  if (!onPasteImages) return false;
  event.preventDefault();
  (async () => {
    try {
      const images = await buildPasteImagesPayload(files);
      const editor = getEditor();
      if (!editor || isImageBlocked(editor)) return;
      onPasteImages(adaptWebToNativeEvent(event, {
        images
      }));
    } catch (err) {
      console.error(err);
    }
  })();
  return true;
}
//# sourceMappingURL=pasteImages.js.map