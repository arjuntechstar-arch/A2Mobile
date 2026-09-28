import 'dart:async';
import 'dart:js_interop';

@JS('Razorpay')
extension type Razorpay._(JSObject _) implements JSObject {
  external factory Razorpay(JSObject options);
  external void open();
  external void on(JSString event, JSFunction callback);
}

Future<Map<String, dynamic>> checkout(Map<String, dynamic> order) async {
  final result = Completer<Map<String, dynamic>>();
  final handler = ((JSObject response) {
    final data = Map<String, dynamic>.from(response.dartify() as Map);
    if (!result.isCompleted) {
      result.complete({
        'razorpay_payment_id': data['razorpay_payment_id'],
        'razorpay_signature': data['razorpay_signature']
      });
    }
  }).toJS;
  final dismissed = (() {
    if (!result.isCompleted) {
      result.completeError(Exception(
          'Checkout was closed. Check payment history before retrying.'));
    }
  }).toJS;
  final options = {
    'key': order['key_id'],
    'order_id': order['order_id'],
    'amount': order['amount_paise'],
    'currency': 'INR',
    'name': 'Mobile Shop Scheme',
    'handler': handler,
    'modal': {'ondismiss': dismissed}
  }.jsify() as JSObject;
  final gateway = Razorpay(options);
  gateway.on(
      'payment.failed'.toJS,
      ((JSObject response) {
        if (!result.isCompleted) {
          result.completeError(Exception(
              'Payment was not completed. Please check your payment history.'));
        }
      }).toJS);
  gateway.open();
  return result.future;
}
