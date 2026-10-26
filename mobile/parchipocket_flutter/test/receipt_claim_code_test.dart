import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/services/firestore_service.dart';

void main() {
  test(
      'receipt claim codes use 128 bits and are unique across service instances',
      () {
    final first = FirestoreService();
    final second = FirestoreService();
    final codes = <String>{
      for (var index = 0; index < 128; index++)
        (index.isEven ? first : second).newReceiptClaimCode(),
    };

    expect(codes, hasLength(128));
    expect(codes.every((code) => RegExp(r'^[0-9a-f]{32}$').hasMatch(code)),
        isTrue);
  });
}
