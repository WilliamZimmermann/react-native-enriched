import { type Editor } from '@tiptap/react';
import type { NativeSyntheticEvent } from 'react-native';
export declare const useOnEditorChange: <T extends {
    value: string;
}>(editor: Editor, handler: ((e: NativeSyntheticEvent<T>) => void) | undefined, getValue: (editor: Editor) => string) => void;
//# sourceMappingURL=useOnEditorChange.d.ts.map