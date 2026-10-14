import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/shared/plural.dart';

void main() {
  test('one is singular, everything else is plural', () {
    expect(countOf(1, 'card'), '1 card');
    expect(countOf(0, 'card'), '0 cards');
    expect(countOf(2, 'second'), '2 seconds');
  });
}
