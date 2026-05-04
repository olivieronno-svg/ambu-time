
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/garde.dart';
import '../models/prime.dart';
import '../utils/calculs.dart';
import '../app_theme.dart';

class GraphiquesScreen extends StatefulWidget {
  final List<Garde> gardes;
  final double tauxHoraire;
  final double panierRepas;
  final double indemnitesDimanche;
  final double montantIdaj;
  final List<PrimeMensuelle> primes;
  final double primeAnnuelle;
  final double brutPeriodeRef;

  const GraphiquesScreen({
    super.key,
    required this.gardes,
    required this.tauxHoraire,
    required this.panierRepas,
    required this.indemnitesDimanche,
    required this.montantIdaj,
    this.primes = const [],
    this.primeAnnuelle = 0,
    this.brutPeriodeRef = 0,
  });

  @override
  State<GraphiquesScreen> createState() => _GraphiquesScreenState();
}

class _GraphiquesScreenState extends State<GraphiquesScreen> {
  // 0 = Salaire/Heures, 1 = Comparatif
  int _onglet = 0;
  bool _afficherSalaire = true;

  List<_MoisData> _donneesParMois() {
    // Groupe uniquement les gardes travaillées (hors CP)
    final Map<String, List<Garde>> parMois = {};
    for (var g in widget.gardes.where((g) => !g.isCongesPaies)) {
      final cle = '${g.date.year}-${g.date.month.toString().padLeft(2, '0')}';
      parMois.putIfAbsent(cle, () => []);
      parMois[cle]!.add(g);
    }

    // Ajoute les mois couverts par des CP (même sans garde travaillée ce mois)
    final cpGardes = widget.gardes.where((g) => g.isCongesPaies).toList();
    for (var g in cpGardes) {
      final fin = g.cpDateFin ?? g.date;
      for (int i = 0; i <= fin.difference(g.date).inDays; i++) {
        final jour = g.date.add(Duration(days: i));
        final cle = '${jour.year}-${jour.month.toString().padLeft(2, '0')}';
        parMois.putIfAbsent(cle, () => []);
      }
    }

    final taux = widget.tauxHoraire;

    final cles = parMois.keys.toList()..sort();
    return cles.map((cle) {
      final parts = cle.split('-');
      final mois = int.parse(parts[1]);
      final annee = int.parse(parts[0]);
      final gardesMois = parMois[cle]!;

      final heures = Calculs.totalHeures(gardesMois);
      final supp = Calculs.heuresSupp(gardesMois);
      final nbGardes = gardesMois.where((g) => !g.jourNonTravaille).length;

      // Primes mensuelles applicables à ce mois précis
      final primesMois = widget.primes
          .where((p) => p.appliqueAu(cle))
          .fold(0.0, (s, p) => s + p.montant);

      // Source de vérité unique — même chiffre que Salaire/Historique
      final brutTotal = Calculs.brutMoisComplet(
        toutesGardes: widget.gardes,
        annee: annee,
        mois: mois,
        taux: taux,
        panier: widget.panierRepas,
        indDimanche: widget.indemnitesDimanche,
        montantIdaj: widget.montantIdaj,
        brutPeriodeRef: widget.brutPeriodeRef,
        primesMensuellesMois: primesMois,
        primeAnnuelle: widget.primeAnnuelle,
      );

      return _MoisData(
        cle: cle, mois: mois, annee: annee,
        brut: brutTotal, net: Calculs.netEstime(brutTotal),
        heures: heures, heuresSupp: supp, nbGardes: nbGardes,
      );
    }).toList();
  }

  String _nomMoisCourt(int mois) {
    const noms = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
        'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return noms[mois];
  }

  String _nomMoisLong(int mois) {
    const noms = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
        'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    return noms[mois];
  }

  @override
  Widget build(BuildContext context) {
    final donnees = _donneesParMois();

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Graphiques', style: AppTheme.titleStyle()),
              const SizedBox(height: 16),

              // ── Onglets principaux ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  _ongletBtn('Évolution', 0),
                  _ongletBtn('Comparatif', 1),
                ]),
              ),
              const SizedBox(height: 16),

              if (donnees.isEmpty)
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: AppTheme.cardDecoration(),
                  child: Center(child: Text(
                    'Saisissez des gardes pour voir les graphiques',
                    style: TextStyle(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  )),
                )
              else if (_onglet == 0)
                _vueEvolution(donnees)
              else
                _vueComparatif(donnees),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ongletBtn(String label, int index) {
    final isActive = _onglet == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _onglet = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.blueAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : AppTheme.textSecondary))),
        ),
      ),
    );
  }

  // ── Vue Évolution ─────────────────────────────────────────────────────────
  Widget _vueEvolution(List<_MoisData> donnees) {
    return Column(children: [
      // Toggle salaire/heures
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _afficherSalaire = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: _afficherSalaire ? AppTheme.blueAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text('Salaire',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                      color: _afficherSalaire ? Colors.white : AppTheme.textSecondary))),
            ),
          )),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _afficherSalaire = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: !_afficherSalaire ? AppTheme.blueAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text('Heures',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                      color: !_afficherSalaire ? Colors.white : AppTheme.textSecondary))),
            ),
          )),
        ]),
      ),
      const SizedBox(height: 12),

      // Graphique barres
      Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_afficherSalaire ? 'Salaire brut par mois (€)' : 'Heures travaillées par mois',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: BarChart(BarChartData(
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppTheme.isDark
                    ? const Color(0xFF1d4ed8) : Colors.white,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final d = donnees[group.x];
                  final val = _afficherSalaire ? d.brut : d.heures;
                  final label = _afficherSalaire
                      ? '${val.toStringAsFixed(0)} €'
                      : Calculs.formatHeures(val);
                  return BarTooltipItem(
                    '${_nomMoisCourt(d.mois)}\n$label',
                    TextStyle(color: AppTheme.textPrimary,
                        fontSize: 12, fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
            alignment: BarChartAlignment.spaceAround,
            maxY: _afficherSalaire
                ? (donnees.fold(0.0, (m, d) => d.brut > m ? d.brut : m)).clamp(1.0, double.infinity) * 1.2
                : (donnees.fold(0.0, (m, d) => d.heures > m ? d.heures : m)).clamp(1.0, double.infinity) * 1.2,
            barGroups: donnees.asMap().entries.map((e) {
              final val = _afficherSalaire ? e.value.brut : e.value.heures;
              return BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(toY: val, color: AppTheme.blueAccent, width: 16,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4), topRight: Radius.circular(4))),
              ]);
            }).toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                  getTitlesWidget: (val, meta) {
                    final idx = val.toInt();
                    if (idx >= 0 && idx < donnees.length) {
                      return Text(_nomMoisCourt(donnees[idx].mois),
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary));
                    }
                    return const Text('');
                  })),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                  getTitlesWidget: (val, meta) => Text(
                      _afficherSalaire ? '${val.toInt()}€' : '${val.toInt()}h',
                      style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (val) =>
                    FlLine(color: AppTheme.bgCardBorder, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
          ))),
        ]),
      ),
      const SizedBox(height: 12),

      // Courbe évolution
      Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_afficherSalaire ? 'Évolution salaire net (€)' : 'Évolution heures travaillées',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: LineChart(LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppTheme.isDark
                    ? const Color(0xFF1d4ed8) : Colors.white,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final idx = spot.x.toInt();
                    final mois = (idx >= 0 && idx < donnees.length)
                        ? _nomMoisCourt(donnees[idx].mois) : '';
                    final label = _afficherSalaire
                        ? '${spot.y.toStringAsFixed(2)} €'
                        : Calculs.formatHeures(spot.y);
                    return LineTooltipItem(
                      '$mois\n$label',
                      TextStyle(color: AppTheme.textPrimary,
                          fontSize: 12, fontWeight: FontWeight.w600),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [LineChartBarData(
              spots: donnees.asMap().entries.map((e) {
                final val = _afficherSalaire ? e.value.net : e.value.heures;
                return FlSpot(e.key.toDouble(), val);
              }).toList(),
              isCurved: true, color: AppTheme.green, barWidth: 2.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: AppTheme.green.withValues(alpha: 0.1)),
            )],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                  getTitlesWidget: (val, meta) {
                    final idx = val.toInt();
                    if (idx >= 0 && idx < donnees.length) {
                      return Text(_nomMoisCourt(donnees[idx].mois),
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary));
                    }
                    return const Text('');
                  })),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                  getTitlesWidget: (val, meta) => Text(
                      _afficherSalaire ? '${val.toInt()}€' : '${val.toInt()}h',
                      style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (val) =>
                    FlLine(color: AppTheme.bgCardBorder, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
          ))),
        ]),
      ),
      const SizedBox(height: 12),

      // Résumé annuel
      Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.summarize_outlined, size: 16, color: AppTheme.blueAccent),
            const SizedBox(width: 8),
            Text('Résumé annuel', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ]),
          const SizedBox(height: 12),
          Divider(color: AppTheme.bgCardBorder),
          const SizedBox(height: 6),

          // Salaires
          _sectionResume('SALAIRES'),
          _statRow('Total brut annuel',
              '${donnees.fold(0.0, (s, d) => s + d.brut).toStringAsFixed(2)} €'),
          _statRow('Total net annuel (~78%)',
              '${donnees.fold(0.0, (s, d) => s + d.net).toStringAsFixed(2)} €'),
          _statRow('Moyenne brut / mois',
              '${(donnees.fold(0.0, (s, d) => s + d.brut) / donnees.length).toStringAsFixed(2)} €'),
          _statRow('Moyenne net / mois',
              '${(donnees.fold(0.0, (s, d) => s + d.net) / donnees.length).toStringAsFixed(2)} €'),

          const SizedBox(height: 8),
          Divider(color: AppTheme.bgCardBorder),
          const SizedBox(height: 6),

          // Heures
          _sectionResume('HEURES'),
          _statRow('Total heures annuel',
              Calculs.formatHeures(donnees.fold(0.0, (s, d) => s + d.heures))),
          _statRow('Moyenne heures / mois',
              Calculs.formatHeures(donnees.fold(0.0, (s, d) => s + d.heures) / donnees.length)),
          _statRow('Total heures supp.',
              Calculs.formatHeures(donnees.fold(0.0, (s, d) => s + d.heuresSupp))),
          _statRow('Total gardes travaillées',
              '${donnees.fold(0, (s, d) => s + d.nbGardes)} garde(s)'),

          const SizedBox(height: 8),
          Divider(color: AppTheme.bgCardBorder),
          const SizedBox(height: 6),

          // Palmarès
          _sectionResume('PALMARÈS'),
          _statRow('Meilleur mois (salaire)',
              '${_nomMoisLong(donnees.reduce((a, b) => a.brut > b.brut ? a : b).mois)} — ${donnees.reduce((a, b) => a.brut > b.brut ? a : b).brut.toStringAsFixed(0)} €'),
          _statRow('Mois le plus chargé (heures)',
              '${_nomMoisLong(donnees.reduce((a, b) => a.heures > b.heures ? a : b).mois)} — ${Calculs.formatHeures(donnees.reduce((a, b) => a.heures > b.heures ? a : b).heures)}'),
          _statRow('Mois le moins élevé',
              '${_nomMoisLong(donnees.reduce((a, b) => a.brut < b.brut ? a : b).mois)} — ${donnees.reduce((a, b) => a.brut < b.brut ? a : b).brut.toStringAsFixed(0)} €'),
        ]),
      ),
    ]);
  }

  // ── Vue Comparatif mois/mois ──────────────────────────────────────────────
  Widget _vueComparatif(List<_MoisData> donnees) {
    if (donnees.length < 2) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(),
        child: Center(child: Text(
          'Il faut au moins 2 mois de données pour le comparatif.',
          style: TextStyle(color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        )),
      );
    }

    // Graphique barres groupées (mois précédent vs actuel)
    final derniers = donnees.length >= 6 ? donnees.sublist(donnees.length - 6) : donnees;

    return Column(children: [
      // ── Graphique comparatif barres ──────────────────────────────
      Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Salaire brut — 6 derniers mois',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Row(children: [
            _legende(AppTheme.blueAccent, 'Brut'),
            const SizedBox(width: 16),
            _legende(AppTheme.green, 'Net'),
          ]),
          const SizedBox(height: 12),
          SizedBox(height: 200, child: BarChart(BarChartData(
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppTheme.isDark
                    ? const Color(0xFF1d4ed8) : Colors.white,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final d = derniers[group.x];
                  final label = rodIndex == 0
                      ? 'Brut: ${d.brut.toStringAsFixed(0)} €'
                      : 'Net: ${d.net.toStringAsFixed(0)} €';
                  return BarTooltipItem(
                    '${_nomMoisCourt(d.mois)}\n$label',
                    TextStyle(color: AppTheme.textPrimary,
                        fontSize: 12, fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
            alignment: BarChartAlignment.spaceAround,
            barGroups: derniers.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(toY: e.value.brut, color: AppTheme.blueAccent,
                      width: 10, borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(3), topRight: Radius.circular(3))),
                  BarChartRodData(toY: e.value.net, color: AppTheme.green,
                      width: 10, borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(3), topRight: Radius.circular(3))),
                ],
              );
            }).toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                  getTitlesWidget: (val, meta) {
                    final idx = val.toInt();
                    if (idx >= 0 && idx < derniers.length) {
                      return Text(_nomMoisCourt(derniers[idx].mois),
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary));
                    }
                    return const Text('');
                  })),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                  getTitlesWidget: (val, meta) => Text('${val.toInt()}€',
                      style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (val) =>
                    FlLine(color: AppTheme.bgCardBorder, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
          ))),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Tableau comparatif mois par mois ─────────────────────────
      Container(
        decoration: AppTheme.cardDecoration(),
        child: Column(children: [
          // En-tête
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.blueAccent.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Expanded(flex: 2, child: Text('Mois',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary))),
              Expanded(child: Text('Brut', textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary))),
              Expanded(child: Text('Heures', textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary))),
              Expanded(child: Text('Évol.', textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary))),
            ]),
          ),

          // Lignes
          ...donnees.asMap().entries.map((e) {
            final d = e.value;
            final prev = e.key > 0 ? donnees[e.key - 1] : null;
            final diff = prev != null ? d.brut - prev.brut : 0.0;
            final pct = prev != null && prev.brut > 0
                ? (diff / prev.brut * 100) : 0.0;
            final isPositif = diff >= 0;
            final color = prev == null
                ? AppTheme.textSecondary
                : isPositif ? AppTheme.colorGreen : AppTheme.colorRed;

            return Column(children: [
              Divider(height: 1, color: AppTheme.bgCardBorder),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Expanded(flex: 2, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_nomMoisLong(d.mois)} ${d.annee}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary)),
                      Text('${d.nbGardes} garde(s)',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  )),
                  Expanded(child: Text('${d.brut.toStringAsFixed(0)} €',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppTheme.colorBlue))),
                  Expanded(child: Text(Calculs.formatHeures(d.heures),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                  Expanded(child: prev == null
                      ? Text('—', textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 12, color: AppTheme.textTertiary))
                      : Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          Icon(isPositif ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 12, color: color),
                          const SizedBox(width: 2),
                          Text('${pct.abs().toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.w600, color: color)),
                        ])),
                ]),
              ),
            ]);
          }),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Meilleur / Moins bon mois ────────────────────────────────
      Row(children: [
        Expanded(child: _podiumCard(
          '🏆 Meilleur mois',
          '${_nomMoisLong(donnees.reduce((a, b) => a.brut > b.brut ? a : b).mois)} ${donnees.reduce((a, b) => a.brut > b.brut ? a : b).annee}',
          '${donnees.reduce((a, b) => a.brut > b.brut ? a : b).brut.toStringAsFixed(0)} €',
          AppTheme.colorGreen,
          const Color(0xFFC0DD97).withValues(alpha: 0.2),
        )),
        const SizedBox(width: 10),
        Expanded(child: _podiumCard(
          '📉 Mois le plus bas',
          '${_nomMoisLong(donnees.reduce((a, b) => a.brut < b.brut ? a : b).mois)} ${donnees.reduce((a, b) => a.brut < b.brut ? a : b).annee}',
          '${donnees.reduce((a, b) => a.brut < b.brut ? a : b).brut.toStringAsFixed(0)} €',
          AppTheme.colorAmber,
          const Color(0xFFFAC775).withValues(alpha: 0.2),
        )),
      ]),
    ]);
  }

  Widget _legende(Color color, String label) => Row(children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
  ]);

  Widget _podiumCard(String titre, String mois, String valeur,
      Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titre, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(mois, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(valeur, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
            color: color)),
      ]),
    );
  }

  Widget _sectionResume(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
        color: AppTheme.blueAccent, letterSpacing: 0.8)),
  );

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
        Text(value, style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.w500, color: AppTheme.blue)),
      ]),
    );
  }
}

class _MoisData {
  final String cle;
  final int mois;
  final int annee;
  final double brut;
  final double net;
  final double heures;
  final double heuresSupp;
  final int nbGardes;

  _MoisData({
    required this.cle,
    required this.mois,
    required this.annee,
    required this.brut,
    required this.net,
    required this.heures,
    required this.heuresSupp,
    required this.nbGardes,
  });
}
