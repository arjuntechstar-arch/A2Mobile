import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';

Future<Map<String, dynamic>> checkout(Map<String, dynamic> order) async {
  final gateway = Razorpay();
  final result = Completer<Map<String, dynamic>>();
  gateway.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
    if (!result.isCompleted) {
      result.complete({
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature
      });
    }
  });
  gateway.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
    if (!result.isCompleted) {
      result.completeError(
          Exception(response.message ?? 'Payment was not completed'));
    }
  });
  gateway.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
    if (!result.isCompleted) {
      result.completeError(Exception(
          'Continue payment in your wallet, then check payment history.'));
    }
  });
  try {
    gateway.open({
      'key': order['key_id'],
      'order_id': order['order_id'],
      'amount': order['amount_paise'],
      'currency': 'INR',
      'name': 'A2Mobile'
    });
    return await result.future;
  } finally {
    gateway.clear();
  }
}
