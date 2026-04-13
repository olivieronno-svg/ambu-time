
import 'package:flutter/material.dart';
import '../models/garde.dart';
import '../models/prime.dart';
import '../utils/calculs.dart';
import '../utils/pdf_service.dart';
import '../utils/purchase_service.dart';
import '../utils/storage.dart';
import '../app_theme.dart';

class HistoriqueScreen extends StatefulWidget {
  final List<Garde> gardes;
  final double tauxHoraire;
  final double panierRepas;
  final double indemnitesDimanche;
  final double montantIdaj;
  final List<PrimeMensuelle> primes;
  final double impotSource;
  final Function(Garde)? onModifierGarde;
  final Function(String)? onSupprimerGarde;

  const HistoriqueScreen({
    super.key,
    required this.gardes,
    required this.tauxHoraire,
    required this.panierRepas,
    required this.indemnitesDimanche,
    required this.montantIdaj,
    this.primes = const [],
    this.impotSource = 0,
    this.onModifierGarde,
    this.onSupprimerGarde,
  });

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  int? _annee;
  String? _mois;
  bool _isPro = false;
  bool _exportEnCours = false;

  static const _moisNoms = [
    '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];
  static const _moisCourts = [
    '', 'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
    'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'
  ];

  @override
  void initState() { super.initState(); _verifierPro(); }

  Future<void> _verifierPro() async {
    final pro = await PurchaseService.isPro();
    final tester = await Storage.isTesterPro();
    setState(() => _isPro = pro || tester);
  }

  void _ouvrirModification(Garde g) {
    if (widget.onModifierGarde == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifier cette garde ?',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        content: Text('${_dateCourte(g.date)} — voulez-vous modifier ou supprimer cette garde ?',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          if (widget.onSupprimerGarde != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                showDialog(context: context, builder: (ctx2) => AlertDialog(
                  title: Text('Supprimer ?',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                  content: Text('Cette action est irréversible.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx2),
                        child: const Text('Annuler')),
                    TextButton(
                      onPressed: () {
                        widget.onSupprimerGarde!(g.id);
                        Navigator.pop(ctx2);
                        setState(() => _mois = null);
                      },
                      child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ));
              },
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onModifierGarde!(g);
            },
            child: Text('Modifier', style: TextStyle(color: AppTheme.blueAccent,
                fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _exporterMois(int annee, int mois) async {
    setState(() => _exportEnCours = true);
    try {
      await PdfService.exporterMois(
        gardes: widget.gardes, annee: annee, mois: mois,
        tauxHoraire: widget.tauxHoraire, panierRepas: widget.panierRepas,
        indemnitesDimanche: widget.indemnitesDimanche, montantIdaj: widget.montantIdaj,
        primes: widget.primes, impotSource: widget.impotSource,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export : $e')));
    }
    setState(() => _exportEnCours = false);
  }

  Map<int, List<Garde>> _parAnnee() {
    final map = <int, List<Garde>>{};
    for (var g in widget.gardes) {
      map.putIfAbsent(g.date.year, () => []).add(g);
    }
    return map;
  }

  Map<String, List<Garde>> _parMois(List<Garde> gardes) {
    final map = <String, List<Garde>>{};
    for (var g in gardes) {
      final cle = '${g.date.year}-${g.date.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(cle, () => []).add(g);
    }
    return map;
  }

  String _dateCourte(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_moisCourts[d.month]}';

  String _titre() {
    if (_mois != null) {
      final p = _mois!.split('-');
      return '${_moisNoms[int.parse(p[1])]} ${p[0]}';
    }
    if (_annee != null) return '$_annee';
    return 'Historique';
  }

  void _retour() {
    if (_mois != null) setState(() => _mois = null);
    else if (_annee != null) setState(() => _annee = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_titre(), style: AppTheme.titleStyle()),
              if (_annee != null)
                GestureDetector(
                  onTap: _retour,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.blueAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.blueAccent.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.arrow_back_ios, size: 11, color: AppTheme.blueAccent),
                      const SizedBox(width: 4),
                      Text('Retour', style: TextStyle(fontSize: 11, color: AppTheme.blueAccent)),
                    ]),
                  ),
                ),
            ]),
          ),
          Expanded(child: widget.gardes.isEmpty
              ? Center(child: Text('Aucune garde enregistrée.',
                  style: TextStyle(color: AppTheme.textSecondary)))
              : _mois != null ? _vueJours()
              : _annee != null ? _vueDetailAnnee()
              : _vueListeAnnees()),
        ]),
      ),
    );
  }

  // ── 1. Liste des années ───────────────────────────────────────────────────
  Widget _vueListeAnnees() {
    final parAnnee = _parAnnee();
    final annees = parAnnee.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: annees.length,
      itemBuilder: (ctx, i) {
        final annee = annees[i];
        final gs = parAnnee[annee]!;
        final brut = Calculs.totalBrut(gs, taux: widget.tauxHoraire,
            panier: widget.panierRepas, indDimanche: widget.indemnitesDimanche,
            montantIdaj: widget.montantIdaj);
        final heures = Calculs.totalHeures(gs);
        final nbMois = _parMois(gs).length;
        return GestureDetector(
          onTap: () => setState(() => _annee = annee),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.cardDecoration(),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$annee', style: TextStyle(fontSize: 28,
                    fontWeight: FontWeight.w800, color: AppTheme.blueAccent)),
                const SizedBox(height: 2),
                Text('$nbMois mois · ${Calculs.formatHeures(heures)} travaillées',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${brut.toStringAsFixed(0)} €', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.green)),
                Text('brut total', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Row(children: [
                  Text('Voir', style: TextStyle(fontSize: 11, color: AppTheme.blueAccent)),
                  Icon(Icons.chevron_right, size: 14, color: AppTheme.blueAccent),
                ]),
              ]),
            ]),
          ),
        );
      },
    );
  }

  // ── 2. Détail d'une année — mois en encadrés cliquables ──────────────────
  Widget _vueDetailAnnee() {
    final gs = (_parAnnee()[_annee] ?? []);
    final brut = Calculs.totalBrut(gs, taux: widget.tauxHoraire,
        panier: widget.panierRepas, indDimanche: widget.indemnitesDimanche,
        montantIdaj: widget.montantIdaj);
    final heures = Calculs.totalHeures(gs);
    final parMois = _parMois(gs);
    final moisDansAnnee = parMois.keys.toList()..sort((a, b) => a.compareTo(b));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: AppTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── En-tête ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$_annee', style: TextStyle(fontSize: 28,
                    fontWeight: FontWeight.w800, color: AppTheme.blueAccent)),
                Text('${Calculs.formatHeures(heures)} travaillées',
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${brut.toStringAsFixed(0)} €', style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.green)),
                Text('brut total', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ]),
            ]),
          ),

          // ── Mois en encadrés cliquables ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: moisDansAnnee.map((cle) {
                final moisNum = int.parse(cle.split('-')[1]);
                final gm = parMois[cle]!;
                final brutMois = Calculs.totalBrut(
                    gm.where((g) => !g.isCongesPaies).toList(),
                    taux: widget.tauxHoraire,
                    panier: widget.panierRepas, indDimanche: widget.indemnitesDimanche,
                    montantIdaj: widget.montantIdaj);
                final hMois = Calculs.totalHeures(gm.where((g) => !g.isCongesPaies).toList());
                final nbCp = gm.where((g) => g.isCongesPaies).fold(0, (s, g) => s + g.nbJoursCP);
                final cpEstim = nbCp * 7 * widget.tauxHoraire;
                final brutTotal = brutMois + cpEstim;
                return GestureDetector(
                  onTap: () => setState(() => _mois = cle),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.blueAccent.withOpacity(0.3)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_moisNoms[moisNum], style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppTheme.blueAccent)),
                      const SizedBox(height: 2),
                      Text('${Calculs.formatHeures(hMois)}',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      if (nbCp > 0)
                        Text('🏖️ $nbCp j. CP',
                            style: const TextStyle(fontSize: 10,
                                color: Color(0xFF1D9E75), fontWeight: FontWeight.w500)),
                      Text('${brutTotal.toStringAsFixed(0)} €',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: AppTheme.green)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Export PDF ─────────────────────────────────────────
          Divider(height: 1, color: AppTheme.bgCardBorder),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${moisDansAnnee.length} mois · ${gs.length} entrées',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              GestureDetector(
                onTap: _exportEnCours ? null : () {
                  if (moisDansAnnee.isNotEmpty) {
                    final dernierMois = moisDansAnnee.last;
                    if (_isPro) {
                      _exporterMois(int.parse(dernierMois.split('-')[0]),
                          int.parse(dernierMois.split('-')[1]));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Activez le mode testeur dans Info !')));
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isPro
                        ? AppTheme.colorGreen.withOpacity(0.15)
                        : AppTheme.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _isPro
                        ? AppTheme.colorGreen.withOpacity(0.4)
                        : AppTheme.blueAccent.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(_isPro ? Icons.picture_as_pdf : Icons.lock_outline,
                        size: 14,
                        color: _isPro ? AppTheme.colorGreen : AppTheme.blueAccent),
                    const SizedBox(width: 5),
                    Text('Export PDF', style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _isPro ? AppTheme.colorGreen : AppTheme.blueAccent)),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── 3. Jours d'un mois (non modifiable) ──────────────────────────────────
  Widget _vueJours() {
    final gs = (_parAnnee()[_annee] ?? []);
    final parMois = _parMois(gs);
    final gardes = [...(parMois[_mois!] ?? [])]
      ..sort((a, b) => a.date.compareTo(b.date));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: gardes.length,
      itemBuilder: (ctx, i) {
        final g = gardes[i];
        final brut = g.isCongesPaies
            ? 0.0
            : Calculs.salaireBrutGarde(g,
                taux: widget.tauxHoraire, panier: widget.panierRepas,
                indDimanche: widget.indemnitesDimanche, montantIdaj: widget.montantIdaj);
        return GestureDetector(
          onTap: () => _ouvrirModification(g),
          child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.cardDecoration(
            borderColor: g.isCongesPaies ? const Color(0xFF1D9E75).withOpacity(0.5)
                : g.jourNonTravaille ? Colors.orange.withOpacity(0.3)
                : g.isDimancheOuFerie ? AppTheme.amber.withOpacity(0.3) : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Text(_dateCourte(g.date), style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w500, color: Colors.white)),
                const SizedBox(width: 8),
                if (g.isCongesPaies)
                  _badge('🏖️ CP · ${g.nbJoursCP}j',
                      const Color(0xFF1D9E75).withOpacity(0.15),
                      const Color(0xFF1D9E75))
                else if (g.jourNonTravaille && g.isJourFerieSeulement)
                  _badge('🎉 Férié — 7h payées', Colors.purple.withOpacity(0.15), Colors.purple)
                else if (g.jourNonTravaille)
                  _badge('Non travaillé', Colors.orange.withOpacity(0.15), Colors.orange)
                else if (g.isDimancheOuFerie)
                  _badge(g.nomJourFerie ?? 'Dim.', AppTheme.amber.withOpacity(0.15), AppTheme.amber)
                else if (g.heuresNuitMinutes > 0)
                  _badge('Nuit', AppTheme.blue.withOpacity(0.15), AppTheme.blue)
                else
                  _badge(_dateCourte(g.date), AppTheme.green.withOpacity(0.15), AppTheme.green),
              ]),
              Row(children: [
                if (!g.isCongesPaies)
                  Text('${brut.toStringAsFixed(0)} €', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: g.jourNonTravaille && g.isJourFerieSeulement
                          ? Colors.purple
                          : AppTheme.green)),
                const SizedBox(width: 8),
                Icon(Icons.edit_outlined, size: 14, color: AppTheme.blueAccent),
              ]),
            ]),
            if (g.isCongesPaies) ...[
              const SizedBox(height: 4),
              Text(
                g.cpDateFin != null
                    ? 'Période : ${g.date.day}/${g.date.month} → ${g.cpDateFin!.day}/${g.cpDateFin!.month}/${g.cpDateFin!.year}'
                    : 'Journée CP — ${g.date.day}/${g.date.month}/${g.date.year}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF1D9E75)),
              ),
            ] else if (!g.jourNonTravaille) ...[
              const SizedBox(height: 4),
              Text('${g.heureDebut.hour}h${g.heureDebut.minute.toString().padLeft(2, '0')} → ${g.heureFin.hour}h${g.heureFin.minute.toString().padLeft(2, '0')} · ${Calculs.formatHeures(g.dureeHeures)}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              if (g.pauseMinutes > 0)
                Text('Pause : ${Calculs.formatHeures(g.pauseMinutes / 60)}',
                    style: TextStyle(fontSize: 10, color: AppTheme.amber.withOpacity(0.8))),
              if (g.hasIDAJ)
                Text('IDAJ applicable', style: TextStyle(fontSize: 10,
                    color: AppTheme.red, fontWeight: FontWeight.w500)),
            ],
            if (g.collegue != null) ...[
              const SizedBox(height: 3),
              Text('👤 ${g.collegue}', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
            if (g.vehiculeUtilise != null)
              Text('🚗 ${g.vehiculeUtilise}', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            if (g.kmDomicileTravail > 0)
              Text('📍 ${g.kmDomicileTravail.toStringAsFixed(0)} km dom-travail',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            if (g.achats.isNotEmpty) ...[
              const SizedBox(height: 3),
              for (final a in g.achats)
                Text('🛒 ${a.intitule} — ${a.montant.toStringAsFixed(2)} €',
                    style: TextStyle(fontSize: 10, color: AppTheme.colorAmber)),
            ],
          ]),
        ),
        );
      },
    );
  }

  Widget _badge(String label, Color bg, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: color)),
  );
}
