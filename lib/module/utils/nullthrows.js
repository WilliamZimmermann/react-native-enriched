"use strict";

export const nullthrows = value => {
  if (value == null) {
    throw new Error('Unexpected null or undefined value');
  }
  return value;
};
//# sourceMappingURL=nullthrows.js.map