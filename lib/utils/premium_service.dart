import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'premium_codes.dart';
import 'storage.dart';

/// Gère l'abonnement « Ambu Time Premium » (3,99 €/mois) via Google Play /
/// App Store, avec le package officiel `in_app_purchase`.
///
/// Un seul point de vérité : [isPro]. Le reste de l'app l'écoute pour
/// déverrouiller l'export PDF, masquer les publicités, etc.
///
/// Persistance locale du dernier statut connu (SharedPreferences) pour que
/// l'utilisateur reste Premium hors-ligne. Au démarrage, on interroge le store
/// (restorePurchases) pour recaler le statut réel.
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  /// Identifiant du produit d'abonnement — à créer À L'IDENTIQUE dans la
  /// Play Console (et App Store Connect côté iOS).
  static const String monthlyId = 'ambutime_premium_monthly';
  static const String _prefKey = 'ambutime_is_pro';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Statut Premium observable par toute l'app.
  final ValueNotifier<bool> isPro = ValueNotifier<bool>(false);

  ProductDetails? _monthly;
  ProductDetails? get monthly => _monthly;

  bool _storeDisponible = false;
  bool get storeDisponible => _storeDisponible;

  bool _initFait = false;

  /// Prix formaté renvoyé par le store (ex. « 3,99 € »), ou une valeur de repli.
  String get prixAffiche => _monthly?.price ?? '3,99 €';

  Future<void> init() async {
    if (_initFait) return;
    _initFait = true;

    // 1) Statut connu hors-ligne (repli immédiat au lancement) :
    //    abonnement persisté OU code de gratuité validé (déblocage à vie).
    final prefs = await SharedPreferences.getInstance();
    isPro.value = (prefs.getBool(_prefKey) ?? false) || await Storage.isTesterPro();

    // 2) Store disponible ? (émulateur sans Play Store, etc.)
    _storeDisponible = await _iap.isAvailable();
    if (!_storeDisponible) return;

    // 3) Écoute des achats (achat en cours, restauration, erreurs).
    _sub = _iap.purchaseStream.listen(
      _traiterAchats,
      onDone: () => _sub?.cancel(),
      onError: (_) {},
    );

    // 4) Charger le détail du produit (prix localisé, etc.).
    final resp = await _iap.queryProductDetails({monthlyId});
    if (resp.productDetails.isNotEmpty) {
      _monthly = resp.productDetails.first;
    }

    // 5) Restaurer un éventuel abonnement déjà actif sur ce compte.
    await _iap.restorePurchases();
  }

  Future<void> _traiterAchats(List<PurchaseDetails> achats) async {
    for (final p in achats) {
      if (p.productID != monthlyId) continue;

      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _definirPro(true);
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          // On ne change pas le statut connu (évite de verrouiller à tort).
          break;
      }

      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  Future<void> _definirPro(bool valeur) async {
    isPro.value = valeur;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, valeur);
  }

  /// Valide un **code de gratuité** (Premium à vie). Renvoie true si le code
  /// est reconnu. Insensible à la casse et aux espaces. Débloque le Premium
  /// définitivement sur cet appareil (mêmes codes qu'Android — code partagé).
  Future<bool> activerAvecCode(String code) async {
    final normalise = code.trim().replaceAll(' ', '').toUpperCase();
    if (!PremiumCodes.valides.contains(normalise)) return false;
    await Storage.setTesterPro(true);
    await _definirPro(true);
    return true;
  }

  /// Lance le tunnel d'achat de l'abonnement mensuel.
  /// Retourne false si le produit n'est pas chargé (store indisponible).
  Future<bool> acheterMensuel() async {
    if (_monthly == null) return false;
    final param = PurchaseParam(productDetails: _monthly!);
    // Un abonnement se traite comme un « non consommable » côté plugin.
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Restaure un abonnement acheté précédemment (changement d'appareil…).
  Future<void> restaurer() => _iap.restorePurchases();

  void dispose() {
    _sub?.cancel();
  }
}
