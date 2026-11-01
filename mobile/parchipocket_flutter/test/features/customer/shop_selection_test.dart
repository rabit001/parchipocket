import 'package:flutter_test/flutter_test.dart';
import 'package:parchipocket/app_state.dart';

void main() {
  test('shop selection is independent from general status notices', () {
    final state = AppState();

    state.openShop('Mansuri General Store');
    expect(state.page, 'shopDetails');
    expect(state.selectedShopName, 'Mansuri General Store');

    state.lastNotice = 'Shop saved.';
    expect(state.selectedShopName, 'Mansuri General Store');

    state.dispose();
  });
}
