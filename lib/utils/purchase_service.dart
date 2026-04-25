
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  static const String _androidKey = String.fromEnvironment(
    'REVENUECAT_KEY',
    defaultValue: 'goog_SJzfxsgcrYbioGEVeeZzgDqsxAd',
  );
  static const String _iosKey = String.fromEnvironment(
    'REVENUECAT_KEY_IOS',
    defaultValue: 'appl_BwaBwYHXStdiYaVTkccvRjjFfCx',
  );
  static String get apiKey => Platform.isIOS ? _iosKey : _androidKey;
  static const String entitlementId = 'Onn-Off Pro';

  static Future<void> initialiser() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      final config = PurchasesConfiguration(apiKey);
      await Purchases.configure(config);
    } catch (e) {
      debugPrint('RevenueCat non disponible : $e');
    }
  }

  static Future<bool> isPro() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlementId);
    } catch (e) {
      return false;
    }
  }

  static Future<bool> acheterPro() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) return false;
      final package = offerings.current!.availablePackages.first;
      await Purchases.purchase(PurchaseParams.package(package));
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> restaurerAchats() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(entitlementId);
    } catch (e) {
      return false;
    }
  }
}