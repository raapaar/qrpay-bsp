import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BspChannel {
  static const channel = MethodChannel('pg.qrpay/bsp');

  Future<void> openMerchantMenu() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('The BSP dialler handoff is Android only.');
    }
    // No QR payload or PIN crosses this channel. Only the fixed menu is opened.
    await channel.invokeMethod<void>('openMerchantMenu');
  }
}
