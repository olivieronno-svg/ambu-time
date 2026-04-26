import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/garde.dart';
import '../models/prime.dart';
import '../utils/calculs.dart';
import '../app_theme.dart';

class SalaireScreen extends StatelessWidget {
  final List<Garde> gardes;
  final double tauxHoraire;
  final double panierRepas;
  final double indemnitesDimanche;
  final double montantIdaj;
  final List<PrimeMensuelle> primes;
  final double primeAnnuelle;
  final double impotSource;
  final double congesAcquisAvant;
  final int modeCp;
  final double brutPeriodeRef;
  final DateTime? debutQuatorzaine;
  /// Vrai si l'utilisateur veut inclure la prime annuelle (case cochée).
  final bool primeAnnuelleActivee;
  /// Montant auto-calculé (moyenne mensuelle), affiché à titre indicatif
  /// même quand la case est décochée.
  final double primeAnnuelleAuto;
  /// Callback pour basculer l'inclusion de la prime annuelle.
  final ValueChanged<bool>? onPrimeAnnuelleToggle;

  const SalaireScreen({
    super.key,
    required this.gardes,
    required this.tauxHoraire,
    required this.panierRepas,
    required this.indemnitesDimanche,
    required this.montantIdaj,
    this.primes = const [],
    this.primeAnnuelle = 0,
    this.impotSource = 0,
    this.congesAcquisAvant = 0,
    this.modeCp = 0,
    this.brutPeriodeRef = 0,
    this.debutQuatorzaine,
    this.primeAnnuelleActivee = true,
    this.primeAnnuelleAuto = 0,
    this.onPrimeAnnuelleToggle,
  });

  List<Map<String, dynamic>> _evolutionMensuelle() {
    if (gardes.isEmpty) return [];
    final Map<String, double> brutParMois = {};
    for (final g in gardes.where((g) => !g.isCongesPaies)) {
      final key = '${g.date.year}-${g.date.month.toString().padLeft(2, '0')}';
      brutParMois[key] = (brutParMois[key] ?? 0) +
          Calculs.salaireBrutGarde(g, taux: tauxHoraire, panier: panierRepas,
              indDimanche: indemnitesDimanche, montantIdaj: montantIdaj);
    }
    final keys = brutParMois.keys.toList()..sort();
    double cumul = 0;
    List<Map<String, dynamic>> result = [];
    for (int i = 0; i < keys.length; i++) {
      cumul += brutParMois[keys[i]]!;
      final parts = keys[i].split('-');
      result.add({
        'key': keys[i], 'annee': int.parse(parts[0]), 'mois': int.parse(parts[1]),
        'brut': brutParMois[keys[i]]!, 'moyenne': cumul / (i + 1),
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final estMai = now.month == 5;
    final evolution = _evolutionMensuelle();

    // ── Gardes du mois en cours uniquement pour la carte principale ──
    final gardesMoisCours = gardes.where((g) =>
        g.date.year == now.year && g.date.month == now.month).toList();

    double totalHeuresMois = Calculs.totalHeures(gardesMoisCours);
    // Filtre les primes qui s'appliquent au mois en cours (selon leur champ mois).
    final moisCourant = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    double totalPrimesMensuelles = primes
        .where((p) => p.appliqueAu(moisCourant))
        .fold(0.0, (s, p) => s + p.montant);
    // ── Source de vérité unique : brut mensuel complet ────────────────
    // Même chiffre que Historique et Graphiques.
    final int jourscpMois = Calculs.joursCPDansMois(gardes, now.year, now.month);
    final double tauxJournalierCP = Calculs.tauxJournalierCP(tauxHoraire, brutPeriodeRef);
    final double indemniteCp = jourscpMois * tauxJournalierCP;
    final double brutAvecPrimesMois = Calculs.brutMoisComplet(
      toutesGardes: gardes,
      annee: now.year,
      mois: now.month,
      taux: tauxHoraire,
      panier: panierRepas,
      indDimanche: indemnitesDimanche,
      montantIdaj: montantIdaj,
      brutPeriodeRef: brutPeriodeRef,
      primesMensuellesMois: totalPrimesMensuelles,
      primeAnnuelle: primeAnnuelle,
    );
    double netBrutMois = Calculs.netEstime(brutAvecPrimesMois);
    double montantImpotMois = impotSource > 0 ? netBrutMois * (impotSource / 100) : 0;
    double netFinalMois = netBrutMois - montantImpotMois;

    // ── Détail du calcul (pour la section sous la carte principale) ───
    final gardesMois = gardesMoisCours;
    double totalHeures = totalHeuresMois;
    // HS par quatorzaine CCN — info uniquement, non ajoutée au brut total
    final hsSuppParMois = Calculs.heuresSuppParMois(gardes, debutQuatorzaine);
    final moisCle = '${now.year}-${now.month.toString().padLeft(2,'0')}';
    final hsSuppMois = hsSuppParMois[moisCle] ?? 0;
    final majSuppMois = Calculs.majorationHSSurMontant(hsSuppMois, tauxHoraire);
    double totalMajNuit = gardesMois.fold(0.0, (s, g) => s + Calculs.majorationNuit(g, tauxHoraire));
    double totalMajDim = gardesMois.fold(0.0, (s, g) => s + Calculs.majorationDimanche(g, tauxHoraire));
    double totalIdaj = gardesMois.fold(0.0, (s, g) => s + Calculs.idaj(g, tauxHoraire));
    int nbDimanche = gardesMois.where((g) => g.isDimancheOuFerie).length;
    double totalPaniers = gardesMois.fold(0.0, (s, g) => s + g.panierRepasGarde);
    double totalLongueDistance = gardesMois.fold(0.0, (s, g) => s + g.primeLongueDistance);
    double totalIndDim = nbDimanche * indemnitesDimanche;
    double baseHeures = totalHeures * tauxHoraire;

    final int totalJoursCP = jourscpMois;
    final String labelModeCp = 'CCN ÷ 26 jours';

    double montantImpot = montantImpotMois;
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Simulation salaire', style: AppTheme.titleStyle()),
                GestureDetector(
                  onTap: () => _exporterPDF(
                    context: context, now: now,
                    brutAvecPrimesMois: brutAvecPrimesMois,
                    netBrutMois: netBrutMois, netFinalMois: netFinalMois,
                    totalHeures: totalHeures, baseHeures: baseHeures,
                    totalMajNuit: totalMajNuit, totalMajDim: totalMajDim,
                    majSuppMois: majSuppMois, totalIdaj: totalIdaj,
                    totalPaniers: totalPaniers, totalIndDim: totalIndDim,
                    totalLongueDistance: totalLongueDistance,
                    indemniteCpMois: 0, joursCpMois: jourscpMois,
                    indemniteCp: indemniteCp, totalJoursCP: totalJoursCP,
                    labelModeCp: labelModeCp, primes: primes,
                    primeAnnuelle: primeAnnuelle, estMai: estMai,
                    montantImpot: montantImpot, impotSource: impotSource,
                    nbGardes: gardesMoisCours.where((g) => !g.jourNonTravaille).length,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.colorGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.colorGreen.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 14, color: AppTheme.colorGreen),
                      const SizedBox(width: 5),
                      Text('Export PDF', style: TextStyle(fontSize: 11, color: AppTheme.colorGreen, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text('Taux horaire : ${tauxHoraire.toStringAsFixed(2)} €/h',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),

              // ── Carte principale — Modèle 1 ───────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C447C),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_nomMois(now.month).toUpperCase()} ${now.year}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('${brutAvecPrimesMois.toStringAsFixed(0)} €',
                      style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w700, color: Colors.white, height: 1)),
                  const SizedBox(height: 4),
                  Text('Salaire brut estimé',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: 14),
                  // Pilules
                  Row(children: [
                    _pilule('${netBrutMois.toStringAsFixed(0)} €', 'Net'),
                    const SizedBox(width: 8),
                    _pilule(impotSource > 0 ? '${netFinalMois.toStringAsFixed(0)} €' : '—', 'Après impôt'),
                    const SizedBox(width: 8),
                    _pilule(Calculs.formatHeures(totalHeuresMois), 'Travaillées'),
                  ]),
                  if (estMai && primeAnnuelle > 0) ...[
                    const SizedBox(height: 10),
                    Text('⭐ Prime annuelle incluse : +${primeAnnuelle.toStringAsFixed(0)} €',
                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6))),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    gardesMoisCours.isEmpty
                        ? 'Aucune garde ce mois-ci'
                        : '${gardesMoisCours.where((g) => !g.jourNonTravaille).length} garde(s) · ${impotSource > 0 ? "${impotSource.toStringAsFixed(1)}% prélevé à la source" : "Pas de prélèvement"}',
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.45)),
                  ),
                ]),
              ),
              const SizedBox(height: 10),

              Text('DÉTAIL DU CALCUL',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                      color: AppTheme.textTertiary, letterSpacing: 0.8)),
              const SizedBox(height: 8),

              Row(children: [
                Expanded(child: _encartResume(
                  titre: 'SALAIRE',
                  lignes: [
                    ('Base', '${baseHeures.toStringAsFixed(0)} €', const Color(0xFF185FA5)),
                    if (totalMajNuit > 0)
                      ('Nuit +25%', '+${totalMajNuit.toStringAsFixed(0)} €', const Color(0xFF185FA5)),
                    if (totalMajDim > 0)
                      ('Dim. +25%', '+${totalMajDim.toStringAsFixed(0)} €', const Color(0xFF185FA5)),
                    if (majSuppMois > 0)
                      ('HS CCN', '+${majSuppMois.toStringAsFixed(0)} €', const Color(0xFF185FA5)),
                    ('Dim./fériés', '+${totalIndDim.toStringAsFixed(0)} €', const Color(0xFFBA7517)),
                    ('IDAJ', '+${totalIdaj.toStringAsFixed(0)} €', const Color(0xFF0F6E56)),
                    ('Paniers', '+${totalPaniers.toStringAsFixed(0)} €', const Color(0xFF0F6E56)),
                    if (totalJoursCP > 0)
                      ('CP $totalJoursCP j.', '+${indemniteCp.toStringAsFixed(0)} €', const Color(0xFF0F6E56)),
                  ],
                )),
                const SizedBox(width: 8),
                Expanded(child: _encartResume(
                  titre: 'PRIMES',
                  lignes: [
                    if (totalLongueDistance > 0)
                      ('Longue dist.', '+${totalLongueDistance.toStringAsFixed(0)} €', const Color(0xFF0F6E56)),
                    for (final p in primes)
                      (p.nom, '+${p.montant.toStringAsFixed(0)} €', Colors.amber),
                    if (estMai && primeAnnuelle > 0)
                      ('Prime annuelle', '+${primeAnnuelle.toStringAsFixed(0)} €', Colors.amber),
                    if (totalLongueDistance == 0 && primes.isEmpty && !(estMai && primeAnnuelle > 0))
                      ('—', '0 €', AppTheme.textTertiary),
                  ],
                )),
              ]),
              const SizedBox(height: 8),
              // ── Toggle prime annuelle ────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: AppTheme.cardDecoration(),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prime annuelle',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      Text(
                        primeAnnuelleActivee
                            ? 'Versée en mai · ${primeAnnuelleAuto.toStringAsFixed(0)} €'
                            : 'Désactivée · auto ${primeAnnuelleAuto.toStringAsFixed(0)} €',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ],
                  )),
                  Switch(
                    value: primeAnnuelleActivee,
                    onChanged: onPrimeAnnuelleToggle,
                    activeThumbColor: Colors.amber,
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              _encartResume(
                titre: 'PRÉLÈVEMENTS',
                lignes: [
                  if (impotSource > 0)
                    ('Impôt prél. source', '−${montantImpot.toStringAsFixed(0)} €', AppTheme.colorRed),
                  if (impotSource == 0)
                    ('Aucun prélèvement', '0 €', AppTheme.textTertiary),
                ],
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 4),

              // ── Congés payés ───────────────────────────────────────
              _sectionTitre('CONGÉS PAYÉS (CCN)'),
              Builder(builder: (ctx) {
                final now = DateTime.now();
                // Période de référence : 1er juin N-1 → 31 mai N
                final debutRef = now.month >= 6
                    ? DateTime(now.year, 6, 1)
                    : DateTime(now.year - 1, 6, 1);
                final finRef = DateTime(debutRef.year + 1, 5, 31);

                // Mois travaillés dans la période de référence
                // Un mois est acquis si au moins 1 garde travaillée
                final Set<String> moisTravailles = {};
                for (final g in gardes) {
                  if (g.jourNonTravaille) continue;
                  if (!g.date.isBefore(debutRef) && !g.date.isAfter(finRef)) {
                    moisTravailles.add(
                        '${g.date.year}-${g.date.month.toString().padLeft(2, '0')}');
                  }
                }
                final nbMoisTravailles = moisTravailles.length;
                final joursDepuisAppli = (nbMoisTravailles * 2.5);
                final joursAcquis = (joursDepuisAppli + congesAcquisAvant).clamp(0, 30);
                // CP déjà pris (toutes les gardes CP)
                final cpPris = gardes.where((g) => g.isCongesPaies).fold(0, (s, g) => s + g.nbJoursCP);
                // Jours disponibles = acquis - pris
                final joursDisponibles = (joursAcquis - cpPris).clamp(0.0, 30.0);
                final progression = joursAcquis / 30;

                return Container(
                  decoration: AppTheme.cardDecoration(
                      borderColor: const Color(0xFF9FE1CB).withValues(alpha: 0.5)),
                  child: Column(children: [
                    // En-tête période
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9FE1CB).withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Période de référence',
                                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            Text(
                              '1 juin ${debutRef.year} → 31 mai ${finRef.year}',
                              style: const TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w600, color: Color(0xFF1D9E75)),
                            ),
                          ]),
                          Text('2,5 j/mois',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),

                    // Barre de progression
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: Column(children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Jours acquis', style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                          Text('${joursAcquis.toStringAsFixed(1)} / 30 jours',
                              style: const TextStyle(fontSize: 12,
                                  fontWeight: FontWeight.w600, color: Color(0xFF1D9E75))),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progression,
                            minHeight: 8,
                            backgroundColor: const Color(0xFF9FE1CB).withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1D9E75)),
                          ),
                        ),
                      ]),
                    ),

                    // Métriques
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Expanded(child: _metricCP(
                            'Jours acquis',
                            joursAcquis.toStringAsFixed(1),
                            'sur 30 max',
                            const Color(0xFF1D9E75))),
                        const SizedBox(width: 8),
                        Expanded(child: _metricCP(
                            'CP pris',
                            '$cpPris',
                            'jours posés',
                            cpPris > 0 ? AppTheme.colorAmber : AppTheme.textSecondary)),
                        const SizedBox(width: 8),
                        Expanded(child: _metricCP(
                            'Disponibles',
                            joursDisponibles.toStringAsFixed(1),
                            'jours restants',
                            joursDisponibles > 0 ? const Color(0xFF1D9E75) : AppTheme.colorRed)),
                      ]),
                    ),

                    // Note
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Column(children: [
                        if (congesAcquisAvant > 0) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9FE1CB).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF1D9E75).withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.add_circle_outline, size: 13,
                                  color: Color(0xFF1D9E75)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(
                                '${joursDepuisAppli.toStringAsFixed(1)} j. (appli) + ${congesAcquisAvant.toStringAsFixed(1)} j. (avant) = ${joursAcquis.toStringAsFixed(1)} j. total',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF1D9E75)),
                              )),
                            ]),
                          ),
                        ],
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.amber.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.amber.withValues(alpha: 0.2)),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.info_outline, size: 13, color: AppTheme.colorAmber),
                            const SizedBox(width: 6),
                            Expanded(child: Text(
                              'Calcul basé sur les gardes saisies. 1 mois = au moins 1 garde travaillée dans le mois.',
                              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                            )),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                );
              }),

              // ── Moyenne des salaires mensuels ───────────────────
              if (evolution.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: AppTheme.cardDecoration(
                      borderColor: AppTheme.colorGreen.withValues(alpha: 0.3)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(children: [
                        Icon(Icons.auto_graph, size: 16, color: AppTheme.colorGreen),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'Prime annuelle',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary),
                        )),
                        Text(
                          '${((evolution.last['moyenne'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} €',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              color: AppTheme.colorGreen),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Text('Versée en mai',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ),
                  ]),
                ),
              ],

              if (gardes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(),
                  child: Center(
                    child: Text('Saisissez des gardes pour voir la simulation',
                        style: TextStyle(color: AppTheme.textSecondary),
                        textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCP(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        Text(sub, style: TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
      ]),
    );
  }

  Widget _sectionTitre(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
        color: AppTheme.textTertiary, letterSpacing: 0.8)),
  );

  Future<void> _exporterPDF({
    required BuildContext context,
    required DateTime now,
    required double brutAvecPrimesMois,
    required double netBrutMois,
    required double netFinalMois,
    required double totalHeures,
    required double baseHeures,
    required double totalMajNuit,
    required double totalMajDim,
    required double majSuppMois,
    required double totalIdaj,
    required double totalPaniers,
    required double totalIndDim,
    required double totalLongueDistance,
    required double indemniteCpMois,
    required int joursCpMois,
    required double indemniteCp,
    required int totalJoursCP,
    required String labelModeCp,
    required List<PrimeMensuelle> primes,
    required double primeAnnuelle,
    required bool estMai,
    required double montantImpot,
    required double impotSource,
    required int nbGardes,
  }) async {
    final pdf = pw.Document();
    final moisNom = _nomMois(now.month);

    pw.Widget ligne(String label, String detail, String val, {bool bold = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            if (detail.isNotEmpty)
              pw.Text(detail, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ])),
          pw.Text(val, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color)),
        ]),
      );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // En-tête
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(color: PdfColor(0.047, 0.267, 0.486), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('FEUILLE DE SALAIRE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.Text('$moisNom ${now.year}  ·  $nbGardes garde(s)  ·  ${Calculs.formatHeures(totalHeures)} travaillées',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey200)),
          ]),
        ),
        pw.SizedBox(height: 16),

        // 3 montants
        pw.Row(children: [
          pw.Expanded(child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Column(children: [
              pw.Text('Brut total', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('${brutAvecPrimesMois.toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor(0.094, 0.373, 0.647))),
            ]),
          )),
          pw.SizedBox(width: 8),
          pw.Expanded(child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Column(children: [
              pw.Text('Net estimé', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('${netBrutMois.toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor(0.059, 0.431, 0.337))),
            ]),
          )),
          if (impotSource > 0) ...[
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
              child: pw.Column(children: [
                pw.Text('Net après impôt', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('${netFinalMois.toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor(0.114, 0.620, 0.459))),
              ]),
            )),
          ],
        ]),
        pw.SizedBox(height: 16),

        // Détail
        pw.Text('DÉTAIL DU CALCUL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
        pw.Divider(),
        ligne('Heures de base', '${Calculs.formatHeures(totalHeures)} travaillées', '${baseHeures.toStringAsFixed(2)} €'),
        ligne('Majorations nuit', totalMajNuit > 0 ? '+25%' : 'Aucune', '+${totalMajNuit.toStringAsFixed(2)} €'),
        ligne('Maj. dim./fériés', totalMajDim > 0 ? '+25%' : 'Aucune', '+${totalMajDim.toStringAsFixed(2)} €'),
        ligne('Heures supp.', majSuppMois > 0 ? 'CCN > 78h' : 'Seuil non atteint', '+${majSuppMois.toStringAsFixed(2)} €'),
        ligne('IDAJ', totalIdaj > 0 ? '> 12h amplitude' : 'Aucune', '+${totalIdaj.toStringAsFixed(2)} €'),
        ligne('Ind. forfait dim./férié', '', '+${totalIndDim.toStringAsFixed(2)} €'),
        ligne('Paniers repas', '', '+${totalPaniers.toStringAsFixed(2)} €'),
        if (totalLongueDistance > 0) ligne('Prime longue distance', '', '+${totalLongueDistance.toStringAsFixed(2)} €'),
        if (joursCpMois > 0) ligne('CP ce mois ($joursCpMois j.)', 'CCN ÷ 26 jours', '+${indemniteCp.toStringAsFixed(2)} €', color: PdfColor(0.059, 0.431, 0.337)),
        if (totalJoursCP > 0) ligne('Indemnité CP', '$totalJoursCP j. — $labelModeCp', '+${indemniteCp.toStringAsFixed(2)} €', color: PdfColor(0.059, 0.431, 0.337)),
        for (final p in primes) ligne(p.nom, 'prime mensuelle', '+${p.montant.toStringAsFixed(2)} €'),
        if (estMai && primeAnnuelle > 0) ligne('Prime annuelle', 'versée en mai', '+${primeAnnuelle.toStringAsFixed(2)} €'),
        pw.Divider(),
        ligne('Brut total', '', '${brutAvecPrimesMois.toStringAsFixed(2)} €', bold: true, color: PdfColor(0.094, 0.373, 0.647)),
        ligne('Net estimé (~78%)', '', '${netBrutMois.toStringAsFixed(2)} €', bold: true, color: PdfColor(0.059, 0.431, 0.337)),
        if (impotSource > 0) ...[
          ligne('Impôt (${impotSource.toStringAsFixed(1)}%)', '', '- ${montantImpot.toStringAsFixed(2)} €', color: PdfColors.red),
          ligne('Net après impôt', '', '${netFinalMois.toStringAsFixed(2)} €', bold: true, color: PdfColor(0.114, 0.620, 0.459)),
        ],

        pw.Spacer(),
        pw.Text('Document généré par Ambu Time — ${now.day}/${now.month}/${now.year}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
      ]),
    ));

    await Printing.layoutPdf(onLayout: (fmt) async => pdf.save());
  }

  String _nomMois(int mois) {
    const noms = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
        'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    return noms[mois];
  }

  Widget _pilule(String val, String lbl) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
        const SizedBox(height: 2),
        Text(lbl, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.55))),
      ]),
    ),
  );

  Widget _encartResume({required String titre, required List<(String, String, Color)> lignes}) =>
    Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: AppTheme.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titre, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        ...lignes.map((l) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(l.$1, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            Text(l.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: l.$3)),
          ]),
        )),
      ]),
    );

}
