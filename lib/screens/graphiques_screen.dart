
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/garde.dart';
import '../utils/calculs.dart';
import '../app_theme.dart';

class GraphiquesScreen extends StatefulWidget {
  final List<Garde> gardes;
  final double tauxHoraire;
  final double panierRepas;
  final double indemnitesDimanche;
  final double montantIdaj;

  const GraphiquesScreen({
    super.key,
    required this.gardes,
    required this.tauxHoraire,
    required this.panierRepas,
    required this.indemnitesDimanche,
    required this.montantIdaj,
  });

  @override
  State<GraphiquesScreen> createState() => _GraphiquesScreenState();
}

class _GraphiquesScreenState extends State<GraphiquesScreen> {
  bool _afficherSalaire = true;

  List<_MoisData> _donneesParMois() {
    Map<String, List<Garde>> parMois = {};
    for (var g in widget.gardes) {
      String cle =
          '${g.date.year}-${g.date.month.toString().padLeft(2, '0')}';
      parMois.putIfAbsent(cle, () => []);
      parMois[cle]!.add(g);
    }
    final cles = parMois.keys.toList()..sort();
    return cles.map((cle) {
      final parts = cle.split('-');
      final mois = int.parse(parts[1]);
      final gardesMois = parMois[cle]!;
      final brut = Calculs.totalBrut(gardesMois,
          taux: widget.tauxHoraire,
          panier: widget.panierRepas,
          indDimanche: widget.indemnitesDimanche,
          montantIdaj: widget.montantIdaj);
      final heures = Calculs.totalHeures(gardesMois);
      return _MoisData(
        cle: cle,
        mois: mois,
        brut: brut,
        net: Calculs.netEstime(brut),
        heures: heures,
      );
    }).toList();
  }

  String _nomMoisCourt(int mois) {
    const noms = [
      '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
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
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _afficherSalaire = true),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _afficherSalaire
                                ? AppTheme.blueAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text('Salaire',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _afficherSalaire
                                        ? Colors.white
                                        : AppTheme.textSecondary)),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _afficherSalaire = false),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_afficherSalaire
                                ? AppTheme.blueAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text('Heures',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: !_afficherSalaire
                                        ? Colors.white
                                        : AppTheme.textSecondary)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              donnees.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(30),
                      decoration: AppTheme.cardDecoration(),
                      child: Center(
                        child: Text(
                          'Saisissez des gardes pour voir les graphiques',
                          style: TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: AppTheme.cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _afficherSalaire
                                    ? 'Salaire brut par mois (€)'
                                    : 'Heures travaillées par mois',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white)),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child: BarChart(
                                  BarChartData(
                                    alignment:
                                        BarChartAlignment.spaceAround,
                                    maxY: _afficherSalaire
                                        ? donnees
                                                .map((d) => d.brut)
                                                .reduce((a, b) =>
                                                    a > b ? a : b) *
                                            1.2
                                        : donnees
                                                .map((d) => d.heures)
                                                .reduce((a, b) =>
                                                    a > b ? a : b) *
                                            1.2,
                                    barGroups: donnees
                                        .asMap()
                                        .entries
                                        .map((e) {
                                      final val = _afficherSalaire
                                          ? e.value.brut
                                          : e.value.heures;
                                      return BarChartGroupData(
                                        x: e.key,
                                        barRods: [
                                          BarChartRodData(
                                            toY: val,
                                            color: AppTheme.blueAccent,
                                            width: 16,
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft:
                                                  Radius.circular(4),
                                              topRight:
                                                  Radius.circular(4),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (val, meta) {
                                            final idx = val.toInt();
                                            if (idx >= 0 &&
                                                idx < donnees.length) {
                                              return Text(
                                                _nomMoisCourt(
                                                    donnees[idx].mois),
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: AppTheme
                                                        .textSecondary),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (val, meta) {
                                            return Text(
                                              _afficherSalaire
                                                  ? '${val.toInt()}€'
                                                  : '${val.toInt()}h',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: AppTheme
                                                      .textSecondary),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                              showTitles: false)),
                                      rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                              showTitles: false)),
                                    ),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (val) =>
                                          FlLine(
                                        color: AppTheme.bgCardBorder,
                                        strokeWidth: 1,
                                      ),
                                    ),
                                    borderData:
                                        FlBorderData(show: false),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: AppTheme.cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _afficherSalaire
                                    ? 'Évolution salaire net (€)'
                                    : 'Évolution heures travaillées',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white)),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child: LineChart(
                                  LineChartData(
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: donnees
                                            .asMap()
                                            .entries
                                            .map((e) {
                                          final val = _afficherSalaire
                                              ? e.value.net
                                              : e.value.heures;
                                          return FlSpot(
                                              e.key.toDouble(), val);
                                        }).toList(),
                                        isCurved: true,
                                        color: AppTheme.green,
                                        barWidth: 2.5,
                                        dotData: const FlDotData(
                                            show: true),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: AppTheme.green
                                              .withOpacity(0.1),
                                        ),
                                      ),
                                    ],
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (val, meta) {
                                            final idx = val.toInt();
                                            if (idx >= 0 &&
                                                idx < donnees.length) {
                                              return Text(
                                                _nomMoisCourt(
                                                    donnees[idx].mois),
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: AppTheme
                                                        .textSecondary),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (val, meta) {
                                            return Text(
                                              _afficherSalaire
                                                  ? '${val.toInt()}€'
                                                  : '${val.toInt()}h',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: AppTheme
                                                      .textSecondary),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                              showTitles: false)),
                                      rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                              showTitles: false)),
                                    ),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (val) =>
                                          FlLine(
                                        color: AppTheme.bgCardBorder,
                                        strokeWidth: 1,
                                      ),
                                    ),
                                    borderData:
                                        FlBorderData(show: false),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: AppTheme.cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Résumé annuel',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white)),
                              const SizedBox(height: 10),
                              _statRow('Total brut annuel',
                                  '${donnees.fold(0.0, (s, d) => s + d.brut).toStringAsFixed(0)} €'),
                              _statRow('Total net annuel',
                                  '${donnees.fold(0.0, (s, d) => s + d.net).toStringAsFixed(0)} €'),
                              _statRow('Total heures annuel',
                                  Calculs.formatHeures(donnees.fold(
                                      0.0, (s, d) => s + d.heures))),
                              _statRow('Moyenne brut / mois',
                                  '${(donnees.fold(0.0, (s, d) => s + d.brut) / donnees.length).toStringAsFixed(0)} €'),
                              _statRow('Meilleur mois',
                                  '${_nomMoisCourt(donnees.reduce((a, b) => a.brut > b.brut ? a : b).mois)} — ${donnees.reduce((a, b) => a.brut > b.brut ? a : b).brut.toStringAsFixed(0)} €'),
                            ],
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white)),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.blue)),
        ],
      ),
    );
  }
}

class _MoisData {
  final String cle;
  final int mois;
  final double brut;
  final double net;
  final double heures;

  _MoisData({
    required this.cle,
    required this.mois,
    required this.brut,
    required this.net,
    required this.heures,
  });
}