
import 'package:flutter/material.dart';
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
  final DateTime? debutQuatorzaine;

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
    this.debutQuatorzaine,
  });

  static const _moisNoms = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];

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
    double brutMois = Calculs.totalBrut(gardesMoisCours,
        taux: tauxHoraire, panier: panierRepas,
        indDimanche: indemnitesDimanche, montantIdaj: montantIdaj);
    double totalPrimesMensuelles = primes.fold(0.0, (s, p) => s + p.montant);
    double primeAnnuelleApplicable = estMai ? primeAnnuelle : 0;
    double brutAvecPrimesMois = brutMois + totalPrimesMensuelles + primeAnnuelleApplicable;
    double netBrutMois = Calculs.netEstime(brutAvecPrimesMois);
    double montantImpotMois = impotSource > 0 ? netBrutMois * (impotSource / 100) : 0;
    double netFinalMois = netBrutMois - montantImpotMois;

    // ── Toutes les gardes pour le détail du calcul ───────────────────
    double totalHeures = Calculs.totalHeures(gardes);
    double brut = Calculs.totalBrut(gardes,
        taux: tauxHoraire, panier: panierRepas,
        indDimanche: indemnitesDimanche, montantIdaj: montantIdaj);
    double heuresSupp = Calculs.heuresSupp(gardes);
    double majSupp = Calculs.majorationHeuresSupp(gardes, tauxHoraire);

    // ── HS par quatorzaine CCN — rattachées au mois de fin de quatorzaine ──
    final hsSuppParMois = Calculs.heuresSuppParMois(gardes, debutQuatorzaine);
    final moisCle = '${now.year}-${now.month.toString().padLeft(2,'0')}';
    final hsSuppMois = hsSuppParMois[moisCle] ?? 0;
    final majSuppMois = Calculs.majorationHSSurMontant(hsSuppMois, tauxHoraire);
    double totalNuit = gardes.fold(0.0, (s, g) => s + Calculs.heuresNuit(g));
    double totalMajNuit = gardes.fold(0.0, (s, g) => s + Calculs.majorationNuit(g, tauxHoraire));
    double totalMajDim = gardes.fold(0.0, (s, g) => s + Calculs.majorationDimanche(g, tauxHoraire));
    double totalIdaj = gardes.fold(0.0, (s, g) => s + Calculs.idaj(g, montantIdaj));
    int nbDimanche = gardes.where((g) => g.isDimancheOuFerie).length;
    double totalPaniers = gardes.fold(0.0, (s, g) => s + g.panierRepasGarde);
    double totalIndDim = nbDimanche * indemnitesDimanche;
    double baseHeures = totalHeures * tauxHoraire;
    double brutAvecPrimes = brut + totalPrimesMensuelles + primeAnnuelleApplicable;

    // ── CP du mois en cours ──────────────────────────────────────────
    final gardesCpMois = gardesMoisCours.where((g) => g.isCongesPaies).toList();
    final joursCP_mois = gardesCpMois.fold(0, (s, g) => s + g.nbJoursCP);
    final indemniteCpMois = joursCP_mois * 7 * tauxHoraire; // estimation min CCN

    // ── Calcul indemnité CP ───────────────────────────────────────
    final gardesCp = gardes.where((g) => g.isCongesPaies).toList();
    final totalJoursCP = gardesCp.fold(0, (s, g) => s + g.nbJoursCP);
    double indemniteCp = 0;
    String labelModeCp = '';

    if (gardesCp.isNotEmpty && totalJoursCP > 0) {
      final now2 = DateTime.now();
      // Période de référence : 1er juin N-1 → 31 mai N
      final debutRef = now2.month >= 6
          ? DateTime(now2.year - 1, 6, 1) : DateTime(now2.year - 2, 6, 1);
      final finRef = DateTime(debutRef.year + 1, 5, 31);
      final gardesRef = gardes.where((g) =>
          !g.jourNonTravaille && !g.isCongesPaies &&
          !g.date.isBefore(debutRef) && !g.date.isAfter(finRef)).toList();

      final brutRef = Calculs.totalBrut(gardesRef,
          taux: tauxHoraire, panier: panierRepas,
          indDimanche: indemnitesDimanche, montantIdaj: montantIdaj);

      // Nombre de jours travaillés dans la période de référence
      final nbJoursRef = gardesRef.length;

      // Méthode 1 : 1/10 du brut annuel de référence
      // L'indemnité totale annuelle = brutRef/10 → pour N jours sur 30 : × (N/30)
      final indemn1_10 = brutRef > 0
          ? (brutRef / 10) * (totalJoursCP / 30)
          : tauxHoraire * 7 * totalJoursCP;

      // Méthode 2 : maintien du salaire
      // Salaire moyen journalier = brut ref / nb jours travaillés en ref
      final salMoyenJour = nbJoursRef > 0
          ? brutRef / nbJoursRef
          : tauxHoraire * 7;
      final indemn2Maintien = salMoyenJour * totalJoursCP;

      if (modeCp == 1) {
        indemniteCp = indemn1_10;
        labelModeCp = 'Règle du 1/10';
      } else if (modeCp == 2) {
        indemniteCp = indemn2Maintien;
        labelModeCp = 'Maintien du salaire';
      } else {
        if (indemn2Maintien >= indemn1_10) {
          indemniteCp = indemn2Maintien;
          labelModeCp = 'Maintien (plus favorable)';
        } else {
          indemniteCp = indemn1_10;
          labelModeCp = '1/10 (plus favorable)';
        }
      }
    }

    // CP ajouté au brut avant calcul net
    brutAvecPrimes += indemniteCp;
    double netBrut = Calculs.netEstime(brutAvecPrimes);
    double montantImpot = impotSource > 0 ? netBrut * (impotSource / 100) : 0;
    double netFinal = netBrut - montantImpot;

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Simulation salaire', style: AppTheme.titleStyle()),
              const SizedBox(height: 4),
              Text('Taux horaire : ${tauxHoraire.toStringAsFixed(2)} €/h',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),

              // ── Carte principale ───────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('Salaire brut estimé',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.blueAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_nomMois(now.month)} ${now.year}',
                          style: const TextStyle(fontSize: 10,
                              color: AppTheme.blueAccent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text('${brutAvecPrimesMois.toStringAsFixed(2)} €',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600,
                            color: AppTheme.green)),
                    const SizedBox(height: 4),
                    Text('Net avant impôt : ${netBrutMois.toStringAsFixed(2)} €',
                        style: const TextStyle(fontSize: 13, color: AppTheme.blue,
                            fontWeight: FontWeight.w500)),
                    if (impotSource > 0) ...[
                      const SizedBox(height: 2),
                      Text('Net après impôt (${impotSource.toStringAsFixed(1)}%) : ${netFinalMois.toStringAsFixed(2)} €',
                          style: TextStyle(fontSize: 15, color: AppTheme.colorGreen,
                              fontWeight: FontWeight.w700)),
                    ],
                    if (gardesMoisCours.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Aucune garde ce mois-ci',
                          style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text('${gardesMoisCours.where((g) => !g.jourNonTravaille).length} garde(s) · ${Calculs.formatHeures(totalHeuresMois)}',
                          style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
                    ],
                    if (estMai && primeAnnuelle > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 6),
                          Text('Prime annuelle incluse : +${primeAnnuelle.toStringAsFixed(2)} €',
                              style: const TextStyle(fontSize: 11, color: Colors.amber,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Text('DÉTAIL DU CALCUL',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                      color: AppTheme.textTertiary, letterSpacing: 0.8)),
              const SizedBox(height: 8),

              Container(
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  children: [
                    _ligne('Heures de base',
                        '${Calculs.formatHeures(totalHeures)} × ${tauxHoraire.toStringAsFixed(2)} €/h',
                        '${baseHeures.toStringAsFixed(2)} €', false),
                    _divider(),
                    _ligne('Maj. nuit (21h–6h)',
                        totalNuit > 0
                            ? '${Calculs.formatHeures(totalNuit)} × +25%'
                            : 'Aucune heure de nuit',
                        '+${totalMajNuit.toStringAsFixed(2)} €', false),
                    _divider(),
                    _ligne('Maj. dim. / jour férié',
                        nbDimanche > 0
                            ? '$nbDimanche jour(s) × +25% du taux horaire'
                            : 'Aucun dimanche / férié',
                        '+${totalMajDim.toStringAsFixed(2)} €', false),
                    _divider(),
                    _ligne('Heures supp. (CCN > 78h/quatorz.)',
                        hsSuppMois > 0
                            ? '${Calculs.formatHeures(hsSuppMois)} rattachées à ce mois'
                            : heuresSupp > 0
                                ? '${Calculs.formatHeures(heuresSupp)} — rattachées au mois de fin'
                                : 'Seuil de 78h non atteint',
                        '+${majSuppMois.toStringAsFixed(2)} €', false),
                    _divider(),
                    _ligne('IDAJ (amplitude > 12h)',
                        gardes.where((g) => g.hasIDAJ).isNotEmpty
                            ? '${gardes.where((g) => g.hasIDAJ).length} garde(s) — +75%/+100%'
                            : 'Aucune garde > 12h amplitude',
                        '+${totalIdaj.toStringAsFixed(2)} €', false),
                    _divider(),
                    _ligne('Paniers repas',
                        '${gardes.where((g) => g.avecPanier).length} garde(s) avec panier',
                        '+${totalPaniers.toStringAsFixed(2)} €', false),
                    _divider(),
                    _ligne('Ind. forfait dim. / férié',
                        nbDimanche > 0
                            ? '$nbDimanche jour(s) × ${indemnitesDimanche.toStringAsFixed(2)} €'
                            : 'Aucun dimanche / férié',
                        '+${totalIndDim.toStringAsFixed(2)} €', false),
                    _divider(),
                    _ligne('Total brut gardes', 'cumul de tous les éléments ci-dessus',
                        '${brut.toStringAsFixed(2)} €', true, color: AppTheme.blue),

                    // ── Congés payés du mois ──────────────────────────
                    if (joursCP_mois > 0) ...[
                      _divider(),
                      _ligne('CP pris ce mois',
                          '$joursCP_mois jour(s) × 7h × ${tauxHoraire.toStringAsFixed(2)} €/h',
                          '+${indemniteCpMois.toStringAsFixed(2)} €', false,
                          color: const Color(0xFF1D9E75)),
                    ],

                    // ── Congés payés globaux ──────────────────────────
                    if (gardesCp.isNotEmpty) ...[
                      _divider(),
                      _ligne('Indemnité CP',
                          '$totalJoursCP jour(s) — $labelModeCp',
                          '+${indemniteCp.toStringAsFixed(2)} €', false,
                          color: const Color(0xFF1D9E75)),
                    ],

                    // ── Primes dynamiques ──────────────────────────
                    for (final p in primes) ...[
                      _divider(),
                      _ligne(p.nom, 'prime mensuelle',
                          '+${p.montant.toStringAsFixed(2)} €', false,
                          color: Colors.amber),
                    ],
                    if (estMai && primeAnnuelle > 0) ...[
                      _divider(),
                      _ligne('Prime annuelle', 'versée en mai uniquement',
                          '+${primeAnnuelle.toStringAsFixed(2)} €', false,
                          color: Colors.amber),
                    ],
                    if (primes.isNotEmpty || (estMai && primeAnnuelle > 0)) ...[
                      _divider(),
                      _ligne('Total brut avec primes', 'base charges salariales',
                          '${brutAvecPrimes.toStringAsFixed(2)} €', true,
                          color: AppTheme.green),
                    ],
                    _divider(),
                    _ligne('Net estimé (~78%)', 'estimation indicative',
                        '${netBrut.toStringAsFixed(2)} €', true, color: AppTheme.blue),

                    if (impotSource > 0) ...[
                      _divider(),
                      _ligne('Impôt prél. à la source',
                          '${impotSource.toStringAsFixed(1)}% du net (×1/mois)',
                          '- ${montantImpot.toStringAsFixed(2)} €', false,
                          color: AppTheme.red),
                      _divider(),
                      _ligne('Net après impôt', 'montant perçu',
                          '${netFinal.toStringAsFixed(2)} €', true,
                          color: AppTheme.colorGreen),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 16),

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
                      borderColor: const Color(0xFF9FE1CB).withOpacity(0.5)),
                  child: Column(children: [
                    // En-tête période
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9FE1CB).withOpacity(0.2),
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
                                  fontWeight: FontWeight.w600, color: const Color(0xFF1D9E75)),
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
                                  fontWeight: FontWeight.w600, color: const Color(0xFF1D9E75))),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progression,
                            minHeight: 8,
                            backgroundColor: const Color(0xFF9FE1CB).withOpacity(0.2),
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
                            '${joursAcquis.toStringAsFixed(1)}',
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
                            '${joursDisponibles.toStringAsFixed(1)}',
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
                              color: const Color(0xFF9FE1CB).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF1D9E75).withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.add_circle_outline, size: 13,
                                  color: Color(0xFF1D9E75)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(
                                '${joursDepuisAppli.toStringAsFixed(1)} j. (appli) + ${congesAcquisAvant.toStringAsFixed(1)} j. (avant) = ${joursAcquis.toStringAsFixed(1)} j. total',
                                style: const TextStyle(fontSize: 10, color: const Color(0xFF1D9E75)),
                              )),
                            ]),
                          ),
                        ],
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.amber.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.amber.withOpacity(0.2)),
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
                      borderColor: AppTheme.colorGreen.withOpacity(0.3)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(children: [
                        Icon(Icons.auto_graph, size: 16, color: AppTheme.colorGreen),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'Moyenne des salaires mensuels',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary),
                        )),
                        Text(
                          '${(evolution.last['moyenne'] as double).toStringAsFixed(2)} €',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              color: AppTheme.colorGreen),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                      child: Text('Versée en mai comme prime annuelle',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Column(children: [
                        for (final e in evolution.reversed.take(6).toList().reversed)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              SizedBox(width: 44, child: Text(
                                '${_moisNoms[e['mois']]} ${(e['annee'] as int) % 100}',
                                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              )),
                              Expanded(child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: (e['brut'] as double) / (evolution
                                      .map((x) => x['brut'] as double)
                                      .reduce((a, b) => a > b ? a : b)),
                                  minHeight: 6,
                                  backgroundColor: AppTheme.bgCard,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.blueAccent.withOpacity(0.6)),
                                ),
                              )),
                              const SizedBox(width: 8),
                              SizedBox(width: 65, child: Text(
                                '${(e['brut'] as double).toStringAsFixed(0)} €',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                                    color: AppTheme.blueAccent),
                              )),
                            ]),
                          ),
                      ]),
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
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

  String _nomMois(int mois) {
    const noms = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
        'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    return noms[mois];
  }

  Widget _ligne(String label, String detail, String valeur,
      bool isBold, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13,
                    fontWeight: isBold ? FontWeight.w500 : FontWeight.normal,
                    color: Colors.white)),
                Text(detail, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text(valeur, style: TextStyle(fontSize: 13,
              fontWeight: isBold ? FontWeight.w500 : FontWeight.normal,
              color: color ?? AppTheme.blue)),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: AppTheme.bgCardBorder);
}
