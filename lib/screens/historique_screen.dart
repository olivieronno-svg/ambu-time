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
  final double primeAnnuelle;
  final double brutPeriodeRef;
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
    this.primeAnnuelle = 0,
    this.brutPeriodeRef = 0,
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
    if (!mounted) return;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur export : $e')));
      }
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
      if (g.isCongesPaies && g.cpDateFin != null &&
          (g.cpDateFin!.month != g.date.month || g.cpDateFin!.year != g.date.year)) {
        // CP chevauchant 2 mois — ajoute dans chaque mois concerné
        DateTime cursor = DateTime(g.date.year, g.date.month, 1);
        final finMois = DateTime(g.cpDateFin!.year, g.cpDateFin!.month, 1);
        while (!cursor.isAfter(finMois)) {
          final cle = "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}";
          map.putIfAbsent(cle, () => []).add(g);
          cursor = DateTime(cursor.year, cursor.month + 1, 1);
        }
      } else {
        final cle = "${g.date.year}-${g.date.month.toString().padLeft(2, '0')}";
        map.putIfAbsent(cle, () => []).add(g);
      }
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
    if (_mois != null) {
      setState(() => _mois = null);
    } else if (_annee != null) {
      setState(() => _annee = null);
    }
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
                      color: AppTheme.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.blueAccent.withValues(alpha: 0.3)),
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
        final brutGardesAnnee = Calculs.totalBrut(gs, taux: widget.tauxHoraire,
            panier: widget.panierRepas, indDimanche: widget.indemnitesDimanche,
            montantIdaj: widget.montantIdaj);
        int nbJoursCPAnnee = 0;
        for (final g in gs.where((g) => g.isCongesPaies)) {
          final debut = g.date;
          final fin = g.cpDateFin ?? g.date;
          nbJoursCPAnnee += fin.difference(debut).inDays + 1;
        }
        final brut = brutGardesAnnee + nbJoursCPAnnee * 7 * widget.tauxHoraire;
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
    final brutGardes = Calculs.totalBrut(gs, taux: widget.tauxHoraire,
        panier: widget.panierRepas, indDimanche: widget.indemnitesDimanche,
        montantIdaj: widget.montantIdaj);
    // Ajoute l'indemnité CP (estimation 7h × taux par jour)
    int totalJoursCP = 0;
    for (final g in gs.where((g) => g.isCongesPaies)) {
      final debut = g.date;
      final fin = g.cpDateFin ?? g.date;
      totalJoursCP += fin.difference(debut).inDays + 1;
    }
    final brutCP = totalJoursCP * 7 * widget.tauxHoraire;
    final brut = brutGardes + brutCP;
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
                final anneeNum = int.parse(cle.split('-')[0]);
                final moisNum = int.parse(cle.split('-')[1]);
                final gm = parMois[cle]!;
                final hMois = Calculs.totalHeures(gm.where((g) => !g.isCongesPaies).toList());
                final nbCp = Calculs.joursCPDansMois(widget.gardes, anneeNum, moisNum);
                // Primes mensuelles applicables à ce mois précis
                final primesMois = widget.primes
                    .where((p) => p.appliqueAu(cle))
                    .fold(0.0, (s, p) => s + p.montant);
                // Source de vérité unique — même chiffre que SalaireScreen/Graphiques
                final brutTotal = Calculs.brutMoisComplet(
                  toutesGardes: widget.gardes,
                  annee: anneeNum,
                  mois: moisNum,
                  taux: widget.tauxHoraire,
                  panier: widget.panierRepas,
                  indDimanche: widget.indemnitesDimanche,
                  montantIdaj: widget.montantIdaj,
                  brutPeriodeRef: widget.brutPeriodeRef,
                  primesMensuellesMois: primesMois,
                  primeAnnuelle: widget.primeAnnuelle,
                );
                return GestureDetector(
                  onTap: () => setState(() => _mois = cle),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.blueAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_moisNoms[moisNum], style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppTheme.blueAccent)),
                      const SizedBox(height: 2),
                      Text(Calculs.formatHeures(hMois),
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
                        ? AppTheme.colorGreen.withValues(alpha: 0.15)
                        : AppTheme.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _isPro
                        ? AppTheme.colorGreen.withValues(alpha: 0.4)
                        : AppTheme.blueAccent.withValues(alpha: 0.3)),
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

    final partsM = _mois!.split('-');
    final moisNum = int.parse(partsM[1]);
    final anneeNum = int.parse(partsM[0]);

    // Stats header — même brut que SalaireScreen/Graphiques pour cohérence
    final gardesTravaillees = gardes.where((g) => !g.isCongesPaies && !g.jourNonTravaille).toList().cast<Garde>();
    final totalH = Calculs.totalHeures(gardesTravaillees);
    final primesMois = widget.primes
        .where((p) => p.appliqueAu(_mois!))
        .fold(0.0, (s, p) => s + p.montant);
    final brutTotal = Calculs.brutMoisComplet(
      toutesGardes: widget.gardes,
      annee: anneeNum,
      mois: moisNum,
      taux: widget.tauxHoraire,
      panier: widget.panierRepas,
      indDimanche: widget.indemnitesDimanche,
      montantIdaj: widget.montantIdaj,
      brutPeriodeRef: widget.brutPeriodeRef,
      primesMensuellesMois: primesMois,
      primeAnnuelle: widget.primeAnnuelle,
    );
    final netTotal = Calculs.netEstime(brutTotal);
    final nbDim = gardesTravaillees.where((g) => g.isDimancheOuFerie).length;
    final moisNoms = ['','jan','fév','mars','avr','mai','juin','juil','août','sep','oct','nov','déc'];
    final moisLongs = ['','Janvier','Février','Mars','Avril','Mai','Juin',
        'Juillet','Août','Septembre','Octobre','Novembre','Décembre'];

    return Column(children: [
      // ── Header ────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          border: Border(bottom: BorderSide(color: AppTheme.bgCardBorder)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(
              onTap: () => setState(() => _mois = null),
              child: Row(children: [
                Icon(Icons.chevron_left, size: 16, color: AppTheme.blueAccent),
                Text('$anneeNum', style: TextStyle(fontSize: 12, color: AppTheme.blueAccent)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.bgSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${gardes.length} garde${gardes.length > 1 ? "s" : ""}',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('${moisLongs[moisNum]} $anneeNum',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Row(children: [
            _statHdr(Calculs.formatHeures(totalH), 'travaillées', AppTheme.colorBlue),
            const SizedBox(width: 16),
            _statHdr('${brutTotal.toStringAsFixed(0)} €', 'brut', AppTheme.colorGreen),
            const SizedBox(width: 16),
            _statHdr('${netTotal.toStringAsFixed(0)} €', 'net (~78%)', AppTheme.colorGreen),
            if (nbDim > 0) ...[
              const SizedBox(width: 16),
              _statHdr('$nbDim dim.', 'majorés', const Color(0xFFBA7517)),
            ],
          ]),
        ]),
      ),

      // ── Timeline ──────────────────────────────────────────────────
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: gardes.length,
        itemBuilder: (ctx, i) {
          final g = gardes[i];
          final isLast = i == gardes.length - 1;
          final brut = g.isCongesPaies || g.jourNonTravaille
              ? (g.jourNonTravaille && g.isJourFerieSeulement ? widget.tauxHoraire * 7 : 0.0)
              : Calculs.salaireBrutGarde(g,
                  taux: widget.tauxHoraire, panier: widget.panierRepas,
                  indDimanche: widget.indemnitesDimanche, montantIdaj: widget.montantIdaj);

          // Couleurs selon type
          Color dayBg, dayText, cardBg, cardBorder, lineColor, brutColor;
          String badgeLabel;
          if (g.isCongesPaies) {
            dayBg = const Color(0xFF9FE1CB); dayText = const Color(0xFF085041);
            cardBg = const Color(0xFFE1F5EE); cardBorder = const Color(0xFF1D9E75);
            lineColor = const Color(0xFF9FE1CB); brutColor = const Color(0xFF0F6E56);
            badgeLabel = '🏖️ CP';
          } else if (g.jourNonTravaille && g.isJourFerieSeulement) {
            dayBg = const Color(0xFFCECBF6); dayText = const Color(0xFF26215C);
            cardBg = const Color(0xFFEEEDFE); cardBorder = const Color(0xFF7F77DD);
            lineColor = const Color(0xFFCECBF6); brutColor = const Color(0xFF534AB7);
            badgeLabel = '🎉 Férié';
          } else if (g.jourNonTravaille) {
            dayBg = const Color(0xFFFAC775); dayText = const Color(0xFF412402);
            cardBg = const Color(0xFFFAEEDA); cardBorder = const Color(0xFFBA7517);
            lineColor = const Color(0xFFFAC775); brutColor = AppTheme.colorAmber;
            badgeLabel = 'Non travaillé';
          } else if (g.isDimancheOuFerie) {
            dayBg = const Color(0xFFFDE68A); dayText = const Color(0xFF854F0B);
            cardBg = const Color(0xFFFFFBEB); cardBorder = const Color(0xFFBA7517);
            lineColor = const Color(0xFFFDE68A); brutColor = const Color(0xFFBA7517);
            badgeLabel = g.nomJourFerie ?? 'Dimanche';
          } else if (g.heuresNuitMinutes > 0) {
            dayBg = const Color(0xFFAFA9EC); dayText = const Color(0xFF26215C);
            cardBg = const Color(0xFFF5F4FE); cardBorder = const Color(0xFF7F77DD);
            lineColor = const Color(0xFFAFA9EC); brutColor = const Color(0xFF0F6E56);
            badgeLabel = 'Nuit';
          } else {
            dayBg = const Color(0xFFE6F1FB); dayText = const Color(0xFF185FA5);
            cardBg = AppTheme.bgCard; cardBorder = AppTheme.bgCardBorder;
            lineColor = const Color(0xFFE6F1FB); brutColor = const Color(0xFF0F6E56);
            badgeLabel = 'Garde';
          }

          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Colonne date + fil
            SizedBox(width: 40, child: Column(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: dayBg, borderRadius: BorderRadius.circular(9)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${g.date.day}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dayText, height: 1)),
                  Text(moisNoms[g.date.month], style: TextStyle(fontSize: 8, color: dayText.withValues(alpha: 0.7))),
                ]),
              ),
              if (!isLast)
                Container(width: 1, height: 20, color: lineColor, margin: const EdgeInsets.only(top: 3)),
            ])),
            const SizedBox(width: 10),

            // Carte
            Expanded(child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _ouvrirModification(g),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorder.withValues(alpha: 0.5)),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Badge type + alerte conflit
                      Builder(builder: (bCtx) {
                        // Vérifie si cette garde chevauche un CP ou vice versa
                        final gDate = DateTime(g.date.year, g.date.month, g.date.day);
                        final hasConflit = !g.isCongesPaies && !g.jourNonTravaille && gardes.any((other) {
                          if (!other.isCongesPaies) return false;
                          final debut = DateTime(other.date.year, other.date.month, other.date.day);
                          final fin = other.cpDateFin != null
                              ? DateTime(other.cpDateFin!.year, other.cpDateFin!.month, other.cpDateFin!.day)
                              : debut;
                          return !gDate.isBefore(debut) && !gDate.isAfter(fin);
                        });
                        return Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: dayBg, borderRadius: BorderRadius.circular(4)),
                            child: Text(badgeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: dayText)),
                          ),
                          if (hasConflit) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                              child: const Text('⚠️ Conflit CP', style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ]);
                      }),
                      const SizedBox(height: 3),
                      // Horaires / CP info
                      if (g.isCongesPaies)
                        Builder(builder: (ctx) {
                          final debut = g.date; final fin = g.cpDateFin ?? g.date;
                          if (debut.month != fin.month || debut.year != fin.year) {
                            if (debut.month == moisNum && debut.year == anneeNum) {
                              final dernierJour = DateTime(debut.year, debut.month + 1, 0);
                              final jours = dernierJour.difference(debut).inDays + 1;
                              return Text('${debut.day} au ${dernierJour.day} ${moisNoms[debut.month]} · $jours j',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: dayText));
                            } else {
                              return Text('01 au ${fin.day} ${moisNoms[fin.month]} · ${fin.day} j',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: dayText));
                            }
                          }
                          return Text('${debut.day}/${debut.month} → ${fin.day}/${fin.month} · ${g.nbJoursCP}j',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: dayText));
                        })
                      else if (!g.jourNonTravaille)
                        Text('${g.heureDebut.hour}h${g.heureDebut.minute.toString().padLeft(2,'0')} → ${g.heureFin.hour}h${g.heureFin.minute.toString().padLeft(2,'0')} · ${Calculs.formatHeures(g.dureeHeures)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                      // Détails
                      Wrap(spacing: 8, children: [
                        if (g.pauseMinutes > 0)
                          Text('Pause ${Calculs.formatHeures(g.pauseMinutes/60)}',
                              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        if (g.hasIDAJ)
                          Text('IDAJ', style: TextStyle(fontSize: 10, color: AppTheme.colorRed)),
                        if (g.collegue != null)
                          Text('👤 ${g.collegue}', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        if (g.vehiculeUtilise != null)
                          Text('🚗 ${g.vehiculeUtilise}', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        for (final a in g.achats)
                          Text('🛒 ${a.intitule} ${a.montant.toStringAsFixed(2)}€',
                              style: TextStyle(fontSize: 10, color: AppTheme.colorAmber)),
                        if (g.primeLongueDistance > 0)
                          Text('🚌 ${g.primeLongueDistance.toStringAsFixed(0)}€',
                              style: const TextStyle(fontSize: 10, color: Colors.lightBlue)),
                      ]),
                    ])),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (!g.isCongesPaies || brut > 0)
                        Text('${brut.toStringAsFixed(0)} €',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: brutColor)),
                      const SizedBox(height: 4),
                      Icon(Icons.edit_outlined, size: 13, color: AppTheme.textTertiary),
                    ]),
                  ]),
                ),
              ),
            )),
          ]);
        },
      )),
    ]);
  }

  Widget _statHdr(String val, String lbl, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
    Text(lbl, style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
  ]);

}
