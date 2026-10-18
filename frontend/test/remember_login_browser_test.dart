@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

@JS('window.localStorage.length')
external int get _storageLength;

@JS('window.localStorage.key')
external JSString? _storageKey(int index);

@JS('window.localStorage.getItem')
external JSString? _storageGetItem(JSString key);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WebCrypto nhớ qua instance mới, không ghi mật khẩu dạng rõ', () async {
    final repository = AuthRepository();
    addTearDown(repository.clearRememberedLogin);
    await repository.saveRememberedLogin(
      username: 'browser.demo',
      password: 'browser-demo-password',
    );
    final saved = await AuthRepository().readRememberedLogin();
    expect(saved?.username, 'browser.demo');
    expect(saved?.password, 'browser-demo-password');

    // Chỉ dữ liệu giả trong profile test riêng, không đọc phiên trình duyệt cá nhân.
    for (var index = 0; index < _storageLength; index++) {
      final key = _storageKey(index)!;
      final raw = _storageGetItem(key)?.toDart ?? '';
      expect(raw.contains('browser-demo-password'), isFalse);
    }
    await repository.clearRememberedLogin();
    expect(await AuthRepository().readRememberedLogin(), isNull);
  });
}
