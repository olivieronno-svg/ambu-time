import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const String _banniereId = 'ca-app-pub-4157370209136747/2635157411';
  static const String _interstitielleId = 'ca-app-pub-4157370209136747/6427062765';

  // IDs de test (à utiliser pendant le développement)
  static const String _banniereTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _interstitielleTest = 'ca-app-pub-3940256099942544/1033173712';

  static final bool _enProduction = const bool.fromEnvironment('dart.vm.product');

  static String get banniereAdUnitId =>
      _enProduction ? _banniereId : _banniereTest;
  static String get interstitielleAdUnitId =>
      _enProduction ? _interstitielleId : _interstitielleTest;

  static Future<void> initialiser() async {
    await MobileAds.instance.initialize();
  }

  static BannerAd creerBanniere({required void Function(Ad) onLoaded}) {
    return BannerAd(
      adUnitId: banniereAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
  }

  static InterstitialAd? _interstitielle;
  static bool _interstitielleChargee = false;
  static bool _chargementEnCours = false;

  static void chargerInterstitielle() {
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

  static void afficherInterstitielle() {
    if (_interstitielleChargee && _interstitielle != null) {
      _interstitielle!.show();
      _interstitielle = null;
      _interstitielleChargee = false;
      // Recharge pour la prochaine fois
      chargerInterstitielle();
    }
  }
}
