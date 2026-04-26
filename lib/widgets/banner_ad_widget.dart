import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/ad_service.dart';

class BannerAdWidget extends StatefulWidget {
  final bool isPro;
  const BannerAdWidget({super.key, required this.isPro});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _banniere;
  bool _chargee = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isPro) _chargerBanniere();
  }

  @override
  void didUpdateWidget(BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'utilisateur vient d'acheter Pro -> liberer la banniere chargee
    // pour ne plus consommer d'impressions ni de memoire.
    if (widget.isPro && !oldWidget.isPro) {
      _banniere?.dispose();
      _banniere = null;
      _chargee = false;
    }
    // Cas symetrique : abonnement expire -> recharger une banniere.
    if (!widget.isPro && oldWidget.isPro && _banniere == null) {
      _chargerBanniere();
    }
  }

  void _chargerBanniere() {
    _banniere = AdService.creerBanniere(
      onLoaded: (ad) {
        if (mounted) setState(() => _chargee = true);
      },
    );
    _banniere!.load();
  }

  @override
  void dispose() {
    _banniere?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPro) return const SizedBox.shrink();
    if (!_chargee || _banniere == null) return const SizedBox.shrink();
    return SizedBox(
      width: _banniere!.size.width.toDouble(),
      height: _banniere!.size.height.toDouble(),
      child: AdWidget(ad: _banniere!),
    );
  }
}
