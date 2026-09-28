import 'dart:js_interop';
import 'api.dart';

@JS('registerSchemePush')
external JSPromise<JSString> registerSchemePush(
    JSObject options, JSString vapid);
Future<void> enablePush(AuthService auth) async {
  final config = await auth.request('/app-config');
  final options = config['firebase']['web'];
  if (options == null || config['vapidKey'] == '') {
    throw Exception(
        'Push notifications have not been configured by the store.');
  }
  final token = await registerSchemePush((options as Map).jsify() as JSObject,
          (config['vapidKey'] as String).toJS)
      .toDart;
  await auth.registerPush(token.toDart, 'web');
}
