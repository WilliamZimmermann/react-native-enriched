"use strict";

export function toColor(value) {
  if (typeof value === 'string') return value;
  if (typeof value === 'number') {
    // eslint-disable-next-line no-bitwise
    const r = value >>> 24 & 0xff;
    // eslint-disable-next-line no-bitwise
    const g = value >>> 16 & 0xff;
    // eslint-disable-next-line no-bitwise
    const b = value >>> 8 & 0xff;
    // eslint-disable-next-line no-bitwise
    const a = (value & 0xff) / 255;
    return `rgba(${r}, ${g}, ${b}, ${a})`;
  }
  return undefined;
}
//# sourceMappingURL=toColor.js.map