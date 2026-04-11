
import 'package:flutter/material.dart';
import '../models/garde.dart';
import '../models/prime.dart';
import '../utils/calculs.dart';
import '../utils/pdf_service.dart';
import '../utils/purchase_service.dart';
import '../utils/storage.dart';
import '../app_theme.dart';

class ImpotsScreen extends StatefulWidget {
  final List<Garde> gardes;
  final double tauxHoraire;
  final double panierRepas;
  final double indemnitesDimanche;
  final double montantIdaj;
  final double impotSource;
  final List<PrimeMensuelle> primes;
  final double primeAnnuelle;
  final double kmDomicileTravail;

  const ImpotsScreen({
    super.key,
    required this.gardes,
    required this.tauxHoraire,
    required this.panierRepas,
    required this.indemnitesDimanche,
    required this.montantIdaj,
    required this.impotSource,
    required this.primes,
    required this.primeAnnuelle,
    this.kmDomicileTravail = 0,
  });

  @override
  State<ImpotsScreen> createState() => _ImpotsScreenState();
}

class _ImpotsScreenState extends State<ImpotsScreen> {
  bool _isPro = false;
  bool _exportEnCours = false;

  @override
  void initState() { super.initState(); _verifierPro(); }

  Future<void> _verifierPro() async {
    final pro = await PurchaseService.isPro();
    final tester = await Storage.isTesterPro();
    setState(() => _isPro = pro || tester);
  }

  Future<void> _exporterAttestation(int annee) async {
    setState(() => _exportEnCours = true);
    try {
      final gardesAnnee = widget.gardes.where((g) => g.date.year == annee).toList();
      await PdfService.exporterAttestation(
        gardes: gardesAnnee,
        annee: annee,
        tauxHoraire: widget.tauxHoraire,
        panierRepas: widget.panierRepas,
        indemnitesDimanche: widget.indemnitesDimanche,
        montantIdaj: widget.montantIdaj,
        primes: widget.primes,
        impotSource: widget.impotSource,
        kmDomicileTravail: widget.kmDomicileTravail,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export : $e')));
    }
    setState(() => _exportEnCours = false);
  }

  @override
  Widget build(BuildContext context) {
    final annee = DateTime.now().year;

    // ── Gardes de l'année courante ─────────────────────────────────────────
    final gardesAnnee = widget.gardes.where((g) => g.date.year == annee).toList();
    // ── Gardes pour attestation = même année courante ─────────────────────
    final gardesAnneePrec = gardesAnnee; // compteur repart à 0 chaque 1er janvier

    // ── Calcul brut mensuel moyen pour estimer l'impôt annuel ─────────────
    final Map<String, double> brutParMois = {};
    for (final g in gardesAnnee) {
      if (g.jourNonTravaille) continue;
      final key = '${g.date.year}-${g.date.month.toString().padLeft(2, '0')}';
      brutParMois[key] = (brutParMois[key] ?? 0) +
          Calculs.salaireBrutGarde(g, taux: widget.tauxHoraire, panier: widget.panierRepas,
              indDimanche: widget.indemnitesDimanche, montantIdaj: widget.montantIdaj);
    }
    final totalPrimesMensuelles = widget.primes.fold(0.0, (s, p) => s + p.montant);
    final nbMois = brutParMois.length;

    // Calcul net mensuel moyen (avec primes)
    double netMensuelMoyen = 0;
    if (nbMois > 0) {
      final brutMoyenMensuel = brutParMois.values.fold(0.0, (s, v) => s + v) / nbMois;
      final brutAvecPrimes = brutMoyenMensuel + totalPrimesMensuelles;
      netMensuelMoyen = Calculs.netEstime(brutAvecPrimes);
    }

    // Impôt mensuel estimé
    final impotMensuel = widget.impotSource > 0 ? netMensuelMoyen * (widget.impotSource / 100) : 0.0;
    // Impôt cumulé sur les mois déjà passés
    final impotCumule = impotMensuel * nbMois;
    // Impôt annuel estimé (projection 12 mois)
    final impotAnnuelEstime = impotMensuel * 12;

    // ── Total achats de l'année ────────────────────────────────────────────
    final totalAchatsAnnee = gardesAnnee.fold(0.0, (s, g) => s + g.totalAchats);

    // ── Total km de l'année ───────────────────────────────────────────────
    final nbJoursTravailles = gardesAnnee.where((g) => !g.jourNonTravaille).length;
    // Si gardes ont km enregistré → on cumule, sinon on utilise le param × nb jours
    final kmDepuisGardes = gardesAnnee
        .where((g) => !g.jourNonTravaille)
        .fold(0.0, (s, g) => s + g.kmDomicileTravail);
    final totalKmAnnee = kmDepuisGardes > 0
        ? kmDepuisGardes
        : (widget.kmDomicileTravail * nbJoursTravailles);

    // ── Détail achats par catégorie/mois ──────────────────────────────────
    final Map<String, double> achatsMois = {};
    for (final g in gardesAnnee) {
      if (g.achats.isEmpty) continue;
      final key = '${g.date.month.toString().padLeft(2, '0')}';
      achatsMois[key] = (achatsMois[key] ?? 0) + g.totalAchats;
    }

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Impôts', style: AppTheme.titleStyle()),
              const SizedBox(height: 4),
              Text('Année $annee — données pour votre déclaration',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),

              // ── Prélèvement à la source ────────────────────────────
              _sectionTitle('Impôt prélèvement à la source'),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: AppTheme.cardDecoration(),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Taux appliqué',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text(widget.impotSource > 0
                            ? '${widget.impotSource.toStringAsFixed(1)}% du net mensuel'
                            : 'Non configuré',
                            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.impotSource > 0
                              ? AppTheme.red.withOpacity(0.1)
                              : AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: widget.impotSource > 0
                              ? AppTheme.red.withOpacity(0.3)
                              : AppTheme.bgCardBorder),
                        ),
                        child: Text(
                          widget.impotSource > 0 ? '${widget.impotSource.toStringAsFixed(1)} %' : '— %',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                              color: widget.impotSource > 0 ? AppTheme.red : AppTheme.textTertiary),
                        ),
                      ),
                    ]),
                  ),
                  if (widget.impotSource > 0) ...[
                    Divider(height: 1, color: AppTheme.bgCardBorder),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        _ligneCalc('Net mensuel moyen estimé',
                            '${netMensuelMoyen.toStringAsFixed(2)} €', null),
                        _ligneCalc('Impôt mensuel estimé',
                            '${impotMensuel.toStringAsFixed(2)} €', null),
                        Divider(color: AppTheme.bgCardBorder),
                        _ligneCalc('Cumulé déjà prélevé ($nbMois mois)',
                            '${impotCumule.toStringAsFixed(2)} €', null, isBold: true),
                        _ligneCalc('Estimation annuelle (12 mois)',
                            '${impotAnnuelEstime.toStringAsFixed(2)} €',
                            'à déclarer aux impôts', isBold: true),
                      ]),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Text(
                        'Configurez votre taux de prélèvement dans Paramètres → Profil.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                      ),
                    ),
                  ],
                ]),
              ),

              // ── Total achats frais réels ───────────────────────────
              _sectionTitle('Total achats — frais réels'),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: AppTheme.cardDecoration(
                    borderColor: AppTheme.colorGreen.withOpacity(0.3)),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Achats cumulés $annee',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('Saisis quotidiennes',
                            style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
                      ])),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.colorGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.colorGreen.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${totalAchatsAnnee.toStringAsFixed(2)} €',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                              color: AppTheme.colorGreen),
                        ),
                      ),
                    ]),
                  ),
                  if (achatsMois.isNotEmpty) ...[
                    Divider(height: 1, color: AppTheme.bgCardBorder),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(children: [
                        Text('Détail par mois',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        for (final entry in (achatsMois.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key))))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_nomMoisCourt(int.parse(entry.key)),
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                Text('${entry.value.toStringAsFixed(2)} €',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                                        color: AppTheme.colorGreen)),
                              ],
                            ),
                          ),
                      ]),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Text('Aucun achat saisi pour $annee.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                    ),
                  ],
                ]),
              ),

              // ── Total km domicile-travail ──────────────────────────
              _sectionTitle('Total km réalisés'),
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: AppTheme.cardDecoration(
                    borderColor: AppTheme.blueAccent.withOpacity(0.3)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Km domicile-travail $annee',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('Pour déclaration frais réels',
                            style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
                      ])),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.blueAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.blueAccent.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${totalKmAnnee.toStringAsFixed(0)} km',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                              color: AppTheme.blueAccent),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Divider(color: AppTheme.bgCardBorder),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Gardes travaillées $annee',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      Text('${gardesAnnee.where((g) => !g.jourNonTravaille).length} jours',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary)),
                    ]),
                  ]),
                ),
              ),

              // ── Attestation fiscale ────────────────────────────────
              const SizedBox(height: 8),
              _sectionTitle('Attestation fiscale $annee'),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: AppTheme.cardDecoration(
                    borderColor: const Color(0xFF7F77DD).withOpacity(0.3)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── En-tête ──────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCECBF6).withOpacity(0.3),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Attestation fiscale', style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                      Text('1er janvier $annee → 31 décembre $annee',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ]),
                  ),

                  // ── Salaires ─────────────────────────────────────
                  if (gardesAnneePrec.isNotEmpty) ...[
                    _attestSection('SALAIRES', Icons.euro_outlined),
                    Builder(builder: (ctx) {
                      final brutPrec = Calculs.totalBrut(
                          gardesAnneePrec.where((g) => !g.jourNonTravaille).toList(),
                          taux: widget.tauxHoraire, panier: widget.panierRepas,
                          indDimanche: widget.indemnitesDimanche,
                          montantIdaj: widget.montantIdaj);
                      final primesAnnuelles = widget.primes.fold(0.0, (s, p) => s + p.montant) * 12;
                      final brutTotal = brutPrec + primesAnnuelles;
                      final netTotal = Calculs.netEstime(brutTotal);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Column(children: [
                          _ligneAttest('Salaire brut annuel', '${brutTotal.toStringAsFixed(2)} €'),
                          _ligneAttest('Primes annuelles', '${primesAnnuelles.toStringAsFixed(2)} €'),
                          Divider(color: AppTheme.bgCardBorder),
                          _ligneAttest('Salaire net estimé', '${netTotal.toStringAsFixed(2)} €', bold: true),
                        ]),
                      );
                    }),
                    Divider(height: 1, color: AppTheme.bgCardBorder),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text('Aucune garde pour $annee.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                    ),
                    Divider(height: 1, color: AppTheme.bgCardBorder),
                  ],

                  // ── Frais réels ───────────────────────────────────
                  _attestSection('FRAIS RÉELS', Icons.receipt_long_outlined),
                  Builder(builder: (ctx) {
                    final gsTrav = gardesAnneePrec.where((g) => !g.jourNonTravaille).toList();
                    final kmPrec = gsTrav.fold(0.0, (s, g) => s + g.kmDomicileTravail);
                    final totalKmPrec = kmPrec > 0
                        ? kmPrec
                        : widget.kmDomicileTravail * gsTrav.length;
                    final paniersPrec = gsTrav.fold(0.0, (s, g) => s + g.panierRepasGarde);
                    final achatsPrec = gardesAnneePrec.fold(0.0, (s, g) => s + g.totalAchats);
                    final totalFrais = totalKmPrec * 0.099 + paniersPrec + achatsPrec; // 0.099€/km barème fiscal 2024
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Column(children: [
                        _ligneAttest('Km domicile-travail',
                            '${totalKmPrec.toStringAsFixed(0)} km',
                            sub: '${(totalKmPrec * 0.099).toStringAsFixed(2)} € (0,099 €/km)'),
                        _ligneAttest('Paniers repas', '${paniersPrec.toStringAsFixed(2)} €'),
                        _ligneAttest('Autres dépenses', '${achatsPrec.toStringAsFixed(2)} €'),
                        Divider(color: AppTheme.bgCardBorder),
                        _ligneAttest('Total frais réels déductibles',
                            '${totalFrais.toStringAsFixed(2)} €', bold: true),
                      ]),
                    );
                  }),

                  // ── Bouton export ─────────────────────────────────
                  Divider(height: 1, color: AppTheme.bgCardBorder),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _exportEnCours ? null : () {
                          if (_isPro) {
                            _exporterAttestation(annee);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Activez le mode Pro dans Info !')));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isPro
                              ? const Color(0xFF534AB7)
                              : AppTheme.blueAccent.withOpacity(0.5),
                        ),
                        icon: _exportEnCours
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(_isPro ? Icons.picture_as_pdf : Icons.lock_outline, size: 18),
                        label: Text(_exportEnCours ? 'Génération...'
                            : _isPro
                                ? 'Exporter l\'attestation PDF'
                                : 'Exporter l\'attestation (Pro)'),
                      ),
                    ),
                  ),
                ]),
              ),

              // ── Note fiscale ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.amber.withOpacity(0.2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, size: 14, color: AppTheme.colorAmber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Ces données sont indicatives. Consultez un conseiller fiscal pour votre déclaration de revenus.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  )),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _nomMoisCourt(int mois) {
    const noms = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
        'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return noms[mois];
  }

  Widget _attestSection(String title, IconData icon) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    child: Row(children: [
      Icon(icon, size: 14, color: const Color(0xFF534AB7)),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: Color(0xFF534AB7), letterSpacing: 0.5)),
    ]),
  );

  Widget _ligneAttest(String label, String value, {bool bold = false, String? sub}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: bold ? AppTheme.textPrimary : AppTheme.textSecondary)),
          if (sub != null)
            Text(sub, style: TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
        ]),
        Text(value, style: TextStyle(fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            color: bold ? const Color(0xFF534AB7) : AppTheme.textPrimary)),
      ]),
    );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title.toUpperCase(), style: TextStyle(fontSize: 10,
        fontWeight: FontWeight.w500, color: AppTheme.textTertiary, letterSpacing: 0.8)),
  );

  Widget _ligneCalc(String label, String value, String? sub, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12,
              fontWeight: isBold ? FontWeight.w500 : FontWeight.normal,
              color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary)),
          if (sub != null)
            Text(sub, style: TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
        ]),
        Text(value, style: TextStyle(fontSize: 13,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: isBold ? AppTheme.red : AppTheme.textPrimary)),
      ]),
    );
  }
}
