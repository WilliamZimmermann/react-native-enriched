#import "TableData.h"

@implementation TableData

- (instancetype)copyWithZone:(NSZone *)zone {
  TableData *copy = [[TableData allocWithZone:zone] init];
  copy.rawHtml = self.rawHtml;
  // Deep enough: outer array + inner string copies. Cells are NSStrings
  // (immutable), so a shallow inner-array reuse would also work — but
  // copying makes the contract loud and matches how ImageData would copy
  // a non-trivial payload if it had one.
  NSMutableArray<NSArray<NSString *> *> *rowsCopy =
      [NSMutableArray arrayWithCapacity:self.rows.count];
  for (NSArray<NSString *> *row in self.rows) {
    [rowsCopy addObject:[row copy]];
  }
  copy.rows = [rowsCopy copy];
  copy.colCount = self.colCount;
  return copy;
}

@end
