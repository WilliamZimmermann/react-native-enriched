/**
 * Best-effort intrinsic pixel size for pasted images (from Blob, with URL fallback).
 * Returns 0×0 when decode fails (caller still emits onPasteImages).
 */
export declare function readImageDimensionsFromBlob(blob: Blob, fallbackUrl: string): Promise<{
    width: number;
    height: number;
}>;
//# sourceMappingURL=pastedImageDimensions.d.ts.map