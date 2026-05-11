import 'dart:async';
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const String _interstitielleAndroid = 'ca-app-pub-4157370209136747/6427062765';
  static const String _interstitielleIos = 'ca-app-pub-4157370209136747/1601639700';

  static const String _interstitielleTestAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _interstitielleTestIos = 'ca-app-pub-3940256099942544/4411468910';

  static final bool _enProduction = const bool.fromEnvironment('dart.vm.product');

  static String get interstitielleAdUnitId {
    if (_enProduction) {
      return Platform.isIOS ? _interstitielleIos : _interstitielleAndroid;
    }
    return Platform.isIOS ? _interstitielleTestIos : _interstitielleTestAndroid;
  }

  static bool _mobileAdsInitialise = false;

  // RGPD (UMP) + ATT iOS. Sans message publie cote console AdMob (Privacy &
  // messaging → European regulations + IDFA message), l'appel ne fait rien.
  // canRequestAds devient true si l'utilisateur a consenti OU s'il est hors UE.
  static Future<void> initialiser() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((_) {
          if (!completer.isCompleted) completer.complete();
        });
      },
      (error) {
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
    if (await ConsentInformation.instance.canRequestAds()) {
      await MobileAds.instance.initialize();
      _mobileAdsInitialise = true;
    }
  }

  static InterstitialAd? _interstitielle;
  static bool _interstitielleChargee = false;
  static bool _chargementEnCours = false;

  static void chargerInterstitielle() {
    if (!_mobileAdsInitialise) return;
    if (_chargementEnCours || _interstitielleChargee) return;
    _chargementEnCours = true;
    InterstitialAd.load(
      adUnitId: interstitielleAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitielle = ad;
          _interstitielleChargee = true;
          _chargementEnCours = false;
        },
        onAdFailedToLoad: (error) {
          _interstitielleChargee = false;
          _chargementEnCours = false;
        },
      ),
    );
  }

  static void afficherInterstitielle({required bool isPro}) {
    // Re-check au moment du show : une interstitielle peut avoir ete prechargee
    // avant que _isPro passe a true (achat en cours, restauration). On refuse
    // l'affichage et on libere la pub en cache.
    if (isPro) {
      disposerInterstitielle();
      return;
    }
    if (_interstitielleChargee && _interstitielle != null) {
      _interstitielle!.show();
      _interstitielle = null;
      _interstitielleChargee = false;
      // Recharge pour la prochaine fois
      chargerInterstitielle();
    }
  }

  static void disposerInterstitielle() {
    _interstitielle?.dispose();
    _interstitielle = null;
    _interstitielleChargee = false;
    _chargementEnCours = false;
  }
}
