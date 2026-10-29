import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/household_expense_parser.dart';

void main() {
  group('parseHouseholdExpense', () {
    test('extracts amount, item and category from Hinglish', () {
      final result = parseHouseholdExpense('Maine aaj 250 rupaye ki sabzi li');

      expect(result.amount, 250);
      expect(result.title.toLowerCase(), 'sabzi');
      expect(result.category, 'Vegetables');
    });

    test('supports Hindi words and Devanagari digits', () {
      final result =
          parseHouseholdExpense('मैंने आज २५० रुपये की सब्जी खरीदी');

      expect(result.amount, 250);
      expect(result.title, 'सब्जी');
      expect(result.category, 'Vegetables');
    });

    test('detects dairy from a short price-first phrase', () {
      final result = parseHouseholdExpense('₹60 का दूध लिया');

      expect(result.amount, 60);
      expect(result.title, 'दूध');
      expect(result.category, 'Dairy');
    });

    test('preserves Indian comma-grouped amounts', () {
      final result = parseHouseholdExpense('Maine 2,500 rupaye ka saman liya');

      expect(result.amount, 2500);
    });

    test('keeps the amount missing when speech does not include a price', () {
      final result = parseHouseholdExpense('Maine doodh kharida');

      expect(result.amount, isNull);
      expect(result.title, 'doodh');
      expect(result.category, 'Dairy');
    });

    test('leaves unknown purchases in Other instead of guessing a category', () {
      final result = parseHouseholdExpense('₹125 decorative vase');

      expect(result.amount, 125);
      expect(result.title.toLowerCase(), 'decorative vase');
      expect(result.category, 'Other');
    });

    test('does not silently save or persist anything', () {
      final result = parseHouseholdExpense('₹40 bread');

      expect(result.amount, 40);
      expect(result.title.toLowerCase(), 'bread');
    });
  });
}
