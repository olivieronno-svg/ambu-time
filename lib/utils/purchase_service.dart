
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

enum AchatResult { succes, annule, offerIndisponible, echec }

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

  static Future<AchatResult> acheterPro() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null ||
          offerings.current!.availablePackages.isEmpty) {
        debugPrint('[PurchaseService] Aucun offering current dans RevenueCat');
        return AchatResult.offerIndisponible;
      }
      final package = offerings.current!.availablePackages.first;
      final result = await Purchases.purchase(PurchaseParams.package(package));
      if (result.customerInfo.entitlements.active.containsKey(entitlementId)) {
        return AchatResult.succes;
      }
      debugPrint('[PurchaseService] Achat retourné sans entitlement actif');
      return AchatResult.echec;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('[PurchaseService] PlatformException: $code — ${e.message}');
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return AchatResult.annule;
      }
      // Cas testeur ou réinstall : Google Play renvoie ITEM_ALREADY_OWNED
      // → on tente une restauration pour synchroniser l'entitlement RevenueCat.
      if (code == PurchasesErrorCode.productAlreadyPurchasedError) {
        try {
          final info = await Purchases.restorePurchases();
          if (info.entitlements.active.containsKey(entitlementId)) {
            return AchatResult.succes;
          }
        } catch (restoreError) {
          debugPrint('[PurchaseService] Restore après already-purchased a échoué: $restoreError');
        }
      }
      return AchatResult.echec;
    } catch (e) {
      debugPrint('[PurchaseService] Erreur inattendue: $e');
      return AchatResult.echec;
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