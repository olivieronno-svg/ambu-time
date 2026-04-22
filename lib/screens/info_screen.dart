
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../utils/purchase_service.dart';
import '../utils/storage.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});
  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  bool _isPro = false;
  int _tapCount = 0;

  @override
  void initState() { super.initState(); _verifierPro(); }

  Future<void> _verifierPro() async {
    final pro = await PurchaseService.isPro();
    final tester = await Storage.isTesterPro();
    setState(() => _isPro = pro || tester);
  }

  void _onVersionTap() {
    if (!kDebugMode) return;
    _tapCount++;
    if (_tapCount >= 5) { _tapCount = 0; _afficherDialogCode(); }
  }

  void _afficherDialogCode() {
    final codeCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.bgSecondaryDark,
      title: Text('Code testeur', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
      content: TextField(controller: codeCtrl, autofocus: true, obscureText: true,
        style: TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(hintText: 'Entrez le code',
            hintStyle: TextStyle(color: AppTheme.textTertiary))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: AppTheme.textSecondary))),
        TextButton(
          onPressed: () async {
            if (kDebugMode && codeCtrl.text.trim() == 'AMBUTEST2026') {
              await Storage.activerModeTester();
              setState(() => _isPro = true);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text('Mode testeur Pro activé !'),
                ]),
                backgroundColor: AppTheme.colorGreen,
              ));
            } else {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code incorrect')));
            }
          },
          child: Text('Valider', style: TextStyle(color: AppTheme.blueAccent,
              fontWeight: FontWeight.w600)),
        ),
      ],
    ));
  }

  Future<void> _ouvrirLien(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Informations', style: AppTheme.titleStyle()),
            const SizedBox(height: 16),

            // ── À propos ───────────────────────────────────────────
            _sectionTitle('À propos'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(),
              child: Column(children: [
                _infoRow('Application', 'Ambu Time'),
                _infoRow('Plateforme', 'Android'),
                _infoRow('Convention', 'CCN Transports Sanitaires'),
                Divider(color: AppTheme.bgCardBorder),
                GestureDetector(
                  onTap: _onVersionTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Version', style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                      Row(children: [
                        if (_isPro) Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.colorGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.colorGreen.withOpacity(0.4)),
                          ),
                          child: Text('PRO', style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w700, color: AppTheme.colorGreen)),
                        ),
                        Text('1.0.6', style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w500, color: AppTheme.colorBlue)),
                      ]),
                    ]),
                  ),
                ),
              ]),
            ),

            // ── Mes Droits (Pro) ───────────────────────────────────
            _sectionTitle('Mes Droits'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(
                borderColor: _isPro
                    ? AppTheme.blueAccent.withOpacity(0.3)
                    : AppTheme.bgCardBorder),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(_isPro ? Icons.gavel : Icons.lock_outline,
                      size: 16,
                      color: _isPro ? AppTheme.blueAccent : AppTheme.textTertiary),
                  const SizedBox(width: 8),
                  Text('Textes de référence',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: _isPro ? AppTheme.textPrimary : AppTheme.textTertiary)),
                  if (_isPro) ...[
                    const Spacer(),
                    AppTheme.badge('Pro', AppTheme.blueAccent.withOpacity(0.15), AppTheme.blueAccent),
                  ],
                ]),
                const SizedBox(height: 8),
                if (_isPro) ...[
                  // ✅ Lien CCN Transports Sanitaires (correct)
                  _lienDroit(
                    'CCN Transports Sanitaires',
                    'Convention collective nationale',
                    Icons.article_outlined,
                    'https://www.legifrance.gouv.fr/conv_coll/id/KALICONT000005635624',
                  ),
                  const SizedBox(height: 8),
                  // ✅ Code du travail (bon lien, ne pas toucher)
                  _lienDroit(
                    'Code du travail',
                    'Durée du travail, repos, congés',
                    Icons.balance_outlined,
                    'https://www.legifrance.gouv.fr/codes/id/LEGITEXT000006072050',
                  ),
                  const SizedBox(height: 8),
                  // ✅ IDAJ — article Légifrance
                  _lienDroit(
                    'IDAJ & Amplitudes — Légifrance',
                    'Art. CCN — Indemnités travail anormal',
                    Icons.timer_outlined,
                    'https://www.legifrance.gouv.fr/conv_coll/id/KALIARTI000033415263?idConteneur=KALICONT000005635624',
                  ),
                  const SizedBox(height: 8),
                  // ✅ IDAJ — DREETS Bourgogne
                  _lienDroit(
                    'IDAJ & Amplitudes — DREETS',
                    'Guide ambulances — BFC',
                    Icons.picture_as_pdf_outlined,
                    'https://bourgogne-franche-comte.dreets.gouv.fr/sites/bourgogne-franche-comte.dreets.gouv.fr/IMG/pdf/aambulances.pdf',
                  ),
                ] else ...[
                  Text('Accédez directement aux textes légaux (CCN, Code du travail).',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Disponible dans la version Pro.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textTertiary,
                          fontStyle: FontStyle.italic)),
                ],
              ]),
            ),

            // ── Calculs CCN ────────────────────────────────────────
            _sectionTitle('Calculs appliqués (CCN)'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _infoDetail('Heures de nuit', 'Entre 21h et 6h — majoration de 25% du taux horaire'),
                _infoDetail('Heures supplémentaires',
                    'Au-delà de 78h/quatorzaine — +25% jusqu\'à 86h, +50% au-delà'),
                _infoDetail('Dimanche / Jour férié', 'Majoration de 25% + indemnité forfaitaire'),
                _infoDetail('IDAJ', 'Amplitude > 12h — indemnité par tranche de 2h'),
                _infoDetail('Panier repas', 'Montant configurable par garde'),
                _infoDetail('Prime annuelle', 'Calculée sur la moyenne mensuelle — versée en mai'),
              ]),
            ),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.amber.withOpacity(0.25)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.colorAmber),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Les calculs sont fournis à titre indicatif. Consultez votre employeur ou un conseiller RH pour toute question spécifique.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                )),
              ]),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title.toUpperCase(), style: TextStyle(fontSize: 10,
        fontWeight: FontWeight.w500, color: AppTheme.textTertiary, letterSpacing: 0.8)),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
          color: AppTheme.colorBlue)),
    ]),
  );

  Widget _infoDetail(String label, String detail) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary)),
      const SizedBox(height: 2),
      Text(detail, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
    ]),
  );

  Widget _lienDroit(String titre, String sous, IconData icon, String url) {
    return GestureDetector(
      onTap: () => _ouvrirLien(url),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.bgCardBorder)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: AppTheme.blueAccent)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titre, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary)),
            Text(sous, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ])),
          Icon(Icons.open_in_new, size: 14, color: AppTheme.textTertiary),
        ]),
      ),
    );
  }
}
