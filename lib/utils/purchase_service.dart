
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  static const String apiKey = 'goog_SJzfxsgcrYbioGEVeeZzgDqsxAd';
  static const String entitlementId = 'Onn-Off Pro';

  static Future<void> initialiser() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      final config = PurchasesConfiguration(apiKey);
      await Purchases.configure(config);
    } catch (e) {
      print('RevenueCat non disponible : $e');
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
      await Purchases.purchasePackage(package);
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