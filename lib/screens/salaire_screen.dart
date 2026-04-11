
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
  final double impotSource; // en %

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
  });

  @override
  Widget build(BuildContext context) {
    final estMai = DateTime.now().month == 5;

    double totalHeures = Calculs.totalHeures(gardes);
    double brut = Calculs.totalBrut(gardes,
        taux: tauxHoraire, panier: panierRepas,
        indDimanche: indemnitesDimanche, montantIdaj: montantIdaj);
    double heuresSupp = Calculs.heuresSupp(gardes);
    double majSupp = Calculs.majorationHeuresSupp(gardes, tauxHoraire);
    double totalNuit = gardes.fold(0.0, (s, g) => s + Calculs.heuresNuit(g));
    double totalMajNuit = gardes.fold(0.0, (s, g) => s + Calculs.majorationNuit(g, tauxHoraire));
    double totalMajDim = gardes.fold(0.0, (s, g) => s + Calculs.majorationDimanche(g, tauxHoraire));
    double totalIdaj = gardes.fold(0.0, (s, g) => s + Calculs.idaj(g, montantIdaj));
    int nbDimanche = gardes.where((g) => g.isDimancheOuFerie).length;
    double totalPaniers = gardes.fold(0.0, (s, g) => s + g.panierRepasGarde);
    double totalIndDim = nbDimanche * indemnitesDimanche;
    double baseHeures = totalHeures * tauxHoraire;

    // ── Primes ────────────────────────────────────────────────────────────
    double totalPrimesMensuelles = primes.fold(0.0, (s, p) => s + p.montant);
    double primeAnnuelleApplicable = estMai ? primeAnnuelle : 0;
    double brutAvecPrimes = brut + totalPrimesMensuelles + primeAnnuelleApplicable;

    // ── Net et impôt ──────────────────────────────────────────────────────
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
                    Text('Salaire brut estimé',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Text('${brutAvecPrimes.toStringAsFixed(2)} €',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600,
                            color: AppTheme.green)),
                    const SizedBox(height: 4),
                    Text('Net avant impôt : ${netBrut.toStringAsFixed(2)} €',
                        style: const TextStyle(fontSize: 13, color: AppTheme.blue,
                            fontWeight: FontWeight.w500)),
                    if (impotSource > 0) ...[
                      const SizedBox(height: 2),
                      Text('Net après impôt (${impotSource.toStringAsFixed(1)}%) : ${netFinal.toStringAsFixed(2)} €',
                          style: TextStyle(fontSize: 15, color: AppTheme.colorGreen,
                              fontWeight: FontWeight.w700)),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                            const SizedBox(width: 6),
                            Text('Prime annuelle incluse : +${primeAnnuelle.toStringAsFixed(2)} €',
                                style: const TextStyle(fontSize: 11, color: Colors.amber,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
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
                    _ligne('Heures supp. (> 78h)',
                        heuresSupp > 0
                            ? '${Calculs.formatHeures(heuresSupp)} au-delà de 78h'
                            : 'Seuil de 78h non atteint',
                        '+${majSupp.toStringAsFixed(2)} €', false),
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
