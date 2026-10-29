/// Parses a single household-purchase phrase into editable entry fields.
///
/// This is a conservative, on-device MVP parser, not an LLM. It never saves
/// anything; the user must review the fields and explicitly confirm the entry.
class ParsedHouseholdExpense {
  const ParsedHouseholdExpense({
    required this.title,
    required this.amount,
    required this.category,
  });

  final String title;
  final double? amount;
  final String category;
}

String _normalizeHindiDigits(String input) {
  final output = StringBuffer();
  for (final rune in input.runes) {
    final digit = rune - 0x0966;
    if (digit >= 0 && digit <= 9) {
      output.write(digit);
    } else {
      output.writeCharCode(rune);
    }
  }
  return output.toString();
}

const Set<String> _fillerWords = <String>{
  'aaj',
  'today',
  'maine',
  'mene',
  'mai',
  'mein',
  'i',
  'bought',
  'buy',
  'purchase',
  'purchased',
  'spend',
  'spent',
  'spending',
  'on',
  'at',
  'of',
  'diye',
  'diya',
  'pay',
  'paid',
  'kiya',
  'kharida',
  'khareeda',
  'kharidi',
  'khareedi',
  'li',
  'lia',
  'liya',
  'lee',
  'lii',
  'ke',
  'ka',
  'ki',
  'rupee',
  'rupees',
  'rs',
  'rupaye',
  'rupya',
  'rupay',
  'रुपये',
  'रुपए',
  'रुपया',
  'रुपयों',
  'आज',
  'मैंने',
  'मैने',
  'मैं',
  'मुझे',
  'खरीदा',
  'खरीदी',
  'खरीदे',
  'लिया',
  'ली',
  'लिए',
  'किया',
  'की',
  'का',
  'के',
  'में',
  'आजका',
  'खरीदकर',
  'है',
  'था',
  'थी',
};

const Map<String, List<String>> _categoryKeywords = <String, List<String>>{
  'Vegetables': <String>[
    'sabzi',
    'vegetable',
    'vegetables',
    'potato',
    'aloo',
    'onion',
    'pyaz',
    'tomato',
    'tamatar',
    'भाजी',
    'सब्जी',
    'सब्ज़ी',
    'आलू',
    'प्याज',
    'प्याज़',
    'टमाटर',
  ],
  'Dairy': <String>[
    'milk',
    'doodh',
    'curd',
    'dahi',
    'paneer',
    'butter',
    'दूध',
    'दही',
    'पनीर',
    'मक्खन',
  ],
  'Groceries': <String>[
    'grocery',
    'groceries',
    'atta',
    'flour',
    'rice',
    'chawal',
    'dal',
    'daal',
    'chana',
    'chane',
    'chickpea',
    'chickpeas',
    'sugar',
    'shakkar',
    'chini',
    'oil',
    'salt',
    'किराना',
    'आटा',
    'चावल',
    'दाल',
    'चना',
    'चने',
    'शक्कर',
    'चीनी',
    'तेल',
    'नमक',
  ],
  'Transport': <String>[
    'bus',
    'auto',
    'taxi',
    'cab',
    'petrol',
    'diesel',
    'fuel',
    'rickshaw',
    'यात्रा',
    'बस',
    'ऑटो',
    'पेट्रोल',
    'डीजल',
  ],
  'Utilities': <String>[
    'electricity',
    'light bill',
    'water bill',
    'internet',
    'recharge',
    'mobile bill',
    'बिजली',
    'पानी का बिल',
    'रिचार्ज',
  ],
  'Health': <String>[
    'medicine',
    'doctor',
    'hospital',
    'medical',
    'dawai',
    'दवाई',
    'दवा',
    'डॉक्टर',
    'अस्पताल',
  ],
  'Food & Dining': <String>[
    'restaurant',
    'food',
    'chai',
    'tea',
    'coffee',
    'samosa',
    'snack',
    'snacks',
    'pizza',
    'burger',
    'खाना',
    'चाय',
    'समोसा',
  ],
  'Education': <String>[
    'book',
    'books',
    'school',
    'college',
    'fee',
    'notebook',
    'किताब',
    'स्कूल',
    'कॉलेज',
    'फीस',
  ],
  'Household': <String>[
    'soap',
    'detergent',
    'cleaner',
    'bucket',
    'broom',
    'घर',
    'साबुन',
    'डिटर्जेंट',
  ],
};

String _guessCategory(String text) {
  for (final entry in _categoryKeywords.entries) {
    if (entry.value.any(text.contains)) return entry.key;
  }
  return 'Other';
}

ParsedHouseholdExpense parseHouseholdExpense(String transcript) {
  final normalized = _normalizeHindiDigits(transcript).trim();
  final amountPattern = RegExp(
    r'(?:₹|rs\.?)\s*((?:\d{1,3}(?:,\d{2,3})+|\d+)(?:\.\d{1,2})?)|((?:\d{1,3}(?:,\d{2,3})+|\d+)(?:\.\d{1,2})?)\s*(?:rupees?|rupaye|rupya|rupay|रुपये|रुपए|रुपया)',
    caseSensitive: false,
  );
  Match? amountMatch = amountPattern.firstMatch(normalized);
  String? amountText;
  if (amountMatch != null) {
    amountText = amountMatch.group(1) ?? amountMatch.group(2);
  } else {
    // If speech gives quantities such as "1 kilo milk", do not mistake the
    // quantity for a price. When multiple unlabelled numbers are spoken,
    // leave the amount blank and let the user confirm it manually.
    final numberPattern = RegExp(
      r'((?:\d{1,3}(?:,\d{2,3})+|\d+)(?:\.\d{1,2})?)',
    );
    final unitAfterNumber = RegExp(
      r'^(?:kg|kgs|kilo(?:gram)?s?|g|gm|grams?|ml|l|litres?|liters?|pcs?|pieces?)\b',
      caseSensitive: false,
    );
    final candidates = numberPattern.allMatches(normalized).where((match) {
      final remaining = normalized.substring(match.end).trimLeft();
      return !unitAfterNumber.hasMatch(remaining);
    }).toList();
    if (candidates.length == 1) {
      amountMatch = candidates.single;
      amountText = candidates.single.group(1);
    }
  }
  final amount = amountText == null
      ? null
      : double.tryParse(amountText.replaceAll(',', ''));

  var titleText = normalized;
  if (amountMatch != null) {
    titleText = titleText.replaceRange(amountMatch.start, amountMatch.end, ' ');
  }

  final tokens = titleText
      .split(RegExp(r'\s+'))
      .map((token) => token.replaceAll(
          RegExp(r'^[^A-Za-z0-9\u0900-\u097F]+|[^A-Za-z0-9\u0900-\u097F]+$'),
          ''))
      .where((token) => token.isNotEmpty)
      .where((token) => !_fillerWords.contains(token.toLowerCase()))
      .toList();
  final title = tokens.join(' ').trim();

  return ParsedHouseholdExpense(
    title: title.isEmpty ? 'Purchase' : title,
    amount: amount,
    category: _guessCategory(normalized.toLowerCase()),
  );
}
