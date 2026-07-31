import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../utils/premium_service.dart';

/// Écran d'abonnement « Ambu Time Premium » (4,99 €/mois).
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _achatEnCours = false;

  static const List<(IconData, String, String)> _avantages = [
    (Icons.picture_as_pdf, 'Attestations PDF',
        'Exportez vos attestations fiscales annuelles en PDF, prêtes pour les impôts.'),
    (Icons.block, 'Zéro publicité',
        'Une application entièrement débarrassée des publicités.'),
    (Icons.insights, 'Toutes les fonctions Pro',
        'Accès complet aux outils avancés, aujourd\'hui et à venir.'),
    (Icons.favorite, 'Vous soutenez l\'app',
        'Un développeur indépendant qui améliore l\'app en continu.'),
  ];

  @override
  void initState() {
    super.initState();
    // Ferme l'écran dès que l'abonnement devient actif.
    PremiumService.instance.isPro.addListener(_surChangementPro);
  }

  @override
  void dispose() {
    PremiumService.instance.isPro.removeListener(_surChangementPro);
    super.dispose();
  }

  void _surChangementPro() {
    if (PremiumService.instance.isPro.value && mounted) {
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🎉 Abonnement Premium activé. Merci !'),
      ));
    }
  }

  Future<void> _sabonner() async {
    setState(() => _achatEnCours = true);
    final ok = await PremiumService.instance.acheterMensuel();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Abonnement momentanément indisponible. Réessayez plus tard.'),
      ));
    }
    if (mounted) setState(() => _achatEnCours = false);
  }

  Future<void> _restaurer() async {
    await PremiumService.instance.restaurer();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Recherche de votre abonnement…'),
      ));
    }
  }

  Future<void> _ouvrirLien(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossible d\'ouvrir le lien.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prix = PremiumService.instance.prixAffiche;
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Ambu Time Premium'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── En-tête ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.violet, AppTheme.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(children: [
                  const Icon(Icons.workspace_premium, color: Colors.white, size: 44),
                  const SizedBox(height: 10),
                  const Text('Passez en Premium',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('$prix / mois — sans engagement, résiliable à tout moment',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ]),
              ),
              const SizedBox(height: 22),

              // ── Avantages ──────────────────────────────────────────
              ..._avantages.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.blueAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(a.$1, color: AppTheme.blueAccent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.$2, style: TextStyle(
                              color: AppTheme.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(a.$3, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.35)),
                        ]),
                      ),
                    ]),
                  )),
              const SizedBox(height: 8),

              // ── Bouton d'abonnement ────────────────────────────────
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _achatEnCours ? null : _sabonner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.violet,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _achatEnCours
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('S\'abonner — $prix / mois',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _restaurer,
                  child: Text('Restaurer un abonnement',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),

              const SizedBox(height: 6),
              Text(
                'Abonnement AmbuTime Premium : $prix par mois. Renouvellement '
                'automatique chaque mois, sauf résiliation au moins 24 h avant '
                'l\'échéance. Gérez ou résiliez à tout moment depuis '
                '${Platform.isIOS ? 'votre compte App Store' : 'votre abonnement Google Play'}.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 11.5, height: 1.4),
              ),
              const SizedBox(height: 8),
              // Liens obligatoires (Apple 3.1.2) : CGU (EULA) + confidentialité,
              // affichés directement dans l'écran d'abonnement.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _ouvrirLien(
                        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Conditions d\'utilisation (CGU)',
                        style: TextStyle(color: AppTheme.blueAccent, fontSize: 11.5)),
                  ),
                  Text('·', style: TextStyle(color: AppTheme.textTertiary)),
                  TextButton(
                    onPressed: () => _ouvrirLien(
                        'https://olivieronno-svg.github.io/ambu-time/privacy.html'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Confidentialité',
                        style: TextStyle(color: AppTheme.blueAccent, fontSize: 11.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
