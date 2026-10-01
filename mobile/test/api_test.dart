import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_shop_scheme/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('validation errors identify fields without echoing submitted values', () {
    final message = apiErrorMessage([
      {'loc': ['body', 'password'], 'msg': 'String should have at least 8 characters', 'input': 'private-password'},
      {'loc': ['body', 'phone'], 'msg': 'String should match pattern', 'input': 'private-phone'},
    ]);
    expect(message, contains('password: String should have at least 8 characters'));
    expect(message, contains('Phone: enter a valid Indian mobile number, for example +919876543210'));
    expect(message, isNot(contains('private-password')));
    expect(message, isNot(contains('private-phone')));
  });
  test('temporary service failure preserves the stored session', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'access_token': 'access', 'refresh_token': 'refresh'});
    final auth = AuthService(
        client: MockClient(
            (request) async => http.Response('<html>Unavailable</html>', 503)));
    await expectLater(auth.restoreEmail(), throwsA(isA<ApiException>()));
    expect(await const FlutterSecureStorage().read(key: 'refresh_token'),
        'refresh');
  });

  test('revoked refresh clears the session', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'access_token': 'access', 'refresh_token': 'refresh'});
    final auth = AuthService(
        client: MockClient((request) async =>
            http.Response('{"detail":"Session expired"}', 401)));
    expect(await auth.restoreEmail(), isNull);
    expect(
        await const FlutterSecureStorage().read(key: 'refresh_token'), isNull);
  });
}
