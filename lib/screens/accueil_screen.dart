import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/garde.dart';
import '../models/planned_garde.dart';
import '../utils/calculs.dart';
import '../utils/notification_service.dart';
import '../app_theme.dart';

class AccueilScreen extends StatefulWidget {
  final List<Garde> gardes;
  final List<Garde> gardesQuatorzaine;
  final double tauxHoraire;
  final DateTime? debutQuatorzaine;
  final Function(String) onSupprimerGarde;
  final Function(Garde) onModifierGarde;
  final String poste;

  const AccueilScreen({
    super.key,
    required this.gardes,
    required this.gardesQuatorzaine,
    required this.tauxHoraire,
    required this.onSupprimerGarde,
    required this.onModifierGarde,
    required this.poste,
    this.debutQuatorzaine,
  });

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  List<PlannedGarde> _planning = [];
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  static const _keyPlanning = 'app_planning_v1';

  @override
  void initState() { super.initState(); _chargerPlanning(); }

  @override
  void dispose() { super.dispose(); }

  Future<void> _chargerPlanning() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_keyPlanning) ?? [];
      final now = DateTime.now();
      if (!mounted) return;
      setState(() {
        _planning = raw
            .map((s) => PlannedGarde.fromMap(jsonDecode(s)))
            .where((g) => !g.date.isBefore(DateTime(now.year, now.month, now.day)))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
      });
    } catch (e) {
      debugPrint('Erreur chargement planning : $e');
    }
  }

  Future<void> _sauvegarderPlanning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyPlanning,
        _planning.map((g) => jsonEncode(g.toMap())).toList());
  }

  Future<void> _ouvrirAjoutPlanning({PlannedGarde? garde}) async {
    DateTime dateSelectionnee = garde?.date ?? DateTime.now().add(const Duration(days: 1));
    int dhH = garde?.heureDebutH ?? 7, dhM = garde?.heureDebutM ?? 0;
    int dfH = garde?.heureFinH ?? 17, dfM = garde?.heureFinM ?? 0;
    final collegueCtrl = TextEditingController(text: garde?.collegue ?? '');
    String typeGarde = garde?.typeGarde ?? 'UPH Jour';
    // Controllers fixes pour les heures — ne se réinitialisent pas au rebuild
    final dhHCtrl = TextEditingController(text: dhH.toString().padLeft(2, '0'));
    final dhMCtrl = TextEditingController(text: dhM.toString().padLeft(2, '0'));
    final dfHCtrl = TextEditingController(text: dfH.toString().padLeft(2, '0'));
    final dfMCtrl = TextEditingController(text: dfM.toString().padLeft(2, '0'));

    final result = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFFB5D4F4).withValues(alpha: 0.97),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Titre + supprimer
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Planifier une garde', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF042C53))),
                if (garde != null)
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, 'delete'),
                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                  ),
              ]),
              const SizedBox(height: 14),

              // Date
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: dateSelectionnee,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) setModalState(() => dateSelectionnee = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF185FA5).withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF185FA5)),
                    const SizedBox(width: 10),
                    Text(
                      '${dateSelectionnee.day}/${dateSelectionnee.month}/${dateSelectionnee.year}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: Color(0xFF042C53)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),

              // Horaires — mêmes champs que saisie garde
              Row(children: [
                Expanded(child: _champHeureFixe('Début', dhHCtrl, dhMCtrl,
                    (h, m) => setModalState(() { dhH = h; dhM = m; }))),
                const SizedBox(width: 10),
                Expanded(child: _champHeureFixe('Fin', dfHCtrl, dfMCtrl,
                    (h, m) => setModalState(() { dfH = h; dfM = m; }))),
              ]),
              const SizedBox(height: 10),

              // Type de garde
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF185FA5).withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Type de garde', style: TextStyle(fontSize: 10, color: Color(0xFF185FA5), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Row(children: [
                    for (final t in ['UPH Jour', 'UPH Nuit', 'Art 80']) ...[
                      GestureDetector(
                        onTap: () => setModalState(() {
                          typeGarde = t;
                          // Pré-remplir les horaires selon le type
                          if (t == 'UPH Jour') {
                            dhH = 7; dhM = 0; dfH = 19; dfM = 0;
                            dhHCtrl.text = '07'; dhMCtrl.text = '00';
                            dfHCtrl.text = '19'; dfMCtrl.text = '00';
                          } else if (t == 'UPH Nuit') {
                            dhH = 19; dhM = 0; dfH = 7; dfM = 0;
                            dhHCtrl.text = '19'; dhMCtrl.text = '00';
                            dfHCtrl.text = '07'; dfMCtrl.text = '00';
                          } else {
                            dhH = 7; dhM = 0; dfH = 17; dfM = 0;
                            dhHCtrl.text = '07'; dhMCtrl.text = '00';
                            dfHCtrl.text = '17'; dfMCtrl.text = '00';
                          }
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: typeGarde == t
                                ? const Color(0xFF185FA5)
                                : const Color(0xFF185FA5).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: typeGarde == t
                                  ? const Color(0xFF185FA5)
                                  : const Color(0xFF185FA5).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(t, style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500,
                            color: typeGarde == t ? Colors.white : const Color(0xFF185FA5),
                          )),
                        ),
                      ),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(height: 8),
              TextField(controller: collegueCtrl,
                style: const TextStyle(color: Color(0xFF042C53)),
                decoration: InputDecoration(
                  labelText: 'Collègue prévu',
                  labelStyle: const TextStyle(color: Color(0xFF185FA5)),
                  prefixIcon: const Icon(Icons.person_outline, size: 18, color: Color(0xFF185FA5)),
                  fillColor: Colors.white.withValues(alpha: 0.7),
                )),
              const SizedBox(height: 16),

              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: Text(garde == null ? 'Ajouter au planning' : 'Mettre à jour',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              )),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );

    final collegue = collegueCtrl.text.trim();
    collegueCtrl.dispose();
    dhHCtrl.dispose();
    dhMCtrl.dispose();
    dfHCtrl.dispose();
    dfMCtrl.dispose();

    if (!mounted) return;

    if (result == 'save') {
      final pg = PlannedGarde(
        id: garde?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        date: dateSelectionnee,
        heureDebutH: dhH, heureDebutM: dhM,
        heureFinH: dfH, heureFinM: dfM,
        typeGarde: typeGarde,
        collegue: collegue.isEmpty ? null : collegue,
      );
      setState(() {
        _planning.removeWhere((g) => g.id == pg.id);
        _planning.add(pg);
        _planning.sort((a, b) => a.date.compareTo(b.date));
      });
      _sauvegarderPlanning();
      // Programme les rappels (1h avant + 6h le matin du jour J)
      NotificationService.programmerAlarme(pg);
    } else if (result == 'delete' && garde != null) {
      setState(() => _planning.removeWhere((g) => g.id == garde.id));
      _sauvegarderPlanning();
      NotificationService.annulerAlarme(garde.id);
    }
  }

  void _supprimerGardePlanning(PlannedGarde g) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Supprimer du planning ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.blue))),
        TextButton(onPressed: () {
          Navigator.pop(ctx);
          setState(() { _planning.removeWhere((p) => p.id == g.id); _sauvegarderPlanning(); });
          NotificationService.annulerAlarme(g.id);
        }, child: const Text('Supprimer', style: TextStyle(color: AppTheme.red))),
      ],
    ));
  }

  String get _badgePoste => widget.poste == 'auxiliaire' ? 'AUX' : 'ADE';

  DateTime? _quatorzaineActive() {
    if (widget.debutQuatorzaine == null) return null;
    final today = DateTime.now();
    DateTime debut = widget.debutQuatorzaine!;
    while (debut.add(const Duration(days: 13)).isBefore(
        DateTime(today.year, today.month, today.day))) {
      debut = debut.add(const Duration(days: 14));
    }
    return debut;
  }

  List<Garde> _gardesDeQuatorzaine(DateTime debut) {
    final fin = debut.add(const Duration(days: 13));
    return widget.gardes.where((g) =>
        !g.date.isBefore(debut) && !g.date.isAfter(fin)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final quatorzaineActive = _quatorzaineActive();
    final gardesQ = quatorzaineActive != null
        ? _gardesDeQuatorzaine(quatorzaineActive)
        : widget.gardes;

    double totalHeures = Calculs.totalHeures(gardesQ);
    double heuresSupp = Calculs.heuresSupp(gardesQ);
    // Brut inclut les indemnités CP du mois
    final now = DateTime.now();
    int joursCP = 0;
    for (final g in gardesQ.where((g) => g.isCongesPaies)) {
      final debut = g.date;
      final fin = g.cpDateFin ?? g.date;
      for (int i = 0; i <= fin.difference(debut).inDays; i++) {
        final j = debut.add(Duration(days: i));
        if (j.year == now.year && j.month == now.month) joursCP++;
      }
    }
    double brut = Calculs.totalBrut(gardesQ, taux: widget.tauxHoraire)
        + joursCP * ((152 * widget.tauxHoraire) + (17 * widget.tauxHoraire * 1.25)) / 26;
    double net = Calculs.netEstime(brut);
    double progression = (totalHeures / 78).clamp(0.0, 1.0);

    String periodeLabel = quatorzaineActive == null
        ? 'Toutes les gardes'
        : '${quatorzaineActive.day}/${quatorzaineActive.month}/${quatorzaineActive.year}'
            ' → '
            '${quatorzaineActive.add(const Duration(days: 13)).day}/${quatorzaineActive.add(const Duration(days: 13)).month}/${quatorzaineActive.add(const Duration(days: 13)).year}';

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête ────────────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mes heures', style: AppTheme.titleStyle()),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.blueAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.blueAccent.withValues(alpha: 0.4)),
                  ),
                  child: Text(_badgePoste, style: const TextStyle(
                      color: AppTheme.blue, fontWeight: FontWeight.w500, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 14),

              // ── Quatorzaine ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.cardDecoration(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Quatorzaine en cours',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      Text(periodeLabel, style: const TextStyle(
                          fontSize: 11, color: AppTheme.blue, fontWeight: FontWeight.w500)),
                    ]),
                    Text('${Calculs.formatHeures(totalHeures)} / 78h',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: AppTheme.blue)),
                  ]),
                  const SizedBox(height: 8),
                  AppTheme.progressBar(progression),
                  if (widget.debutQuatorzaine == null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 14, color: AppTheme.amber.withValues(alpha: 0.8)),
                        const SizedBox(width: 6),
                        const Expanded(child: Text('Définissez la date de début dans Paramètres',
                            style: TextStyle(fontSize: 11, color: AppTheme.amber))),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 10),

              // ── Alerte 78h ─────────────────────────────────────────
              if (totalHeures >= 70 && totalHeures < 78) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.warning_amber_rounded, size: 20, color: AppTheme.colorAmber),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Attention — seuil 78h proche !',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppTheme.colorAmber)),
                      Text(
                        'Il te reste ${Calculs.formatHeures(78 - totalHeures)} avant les heures supplémentaires.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ])),
                  ]),
                ),
                const SizedBox(height: 10),
              ] else if (totalHeures >= 78) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.red.withValues(alpha: 0.5)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.alarm_on_rounded, size: 20, color: AppTheme.colorRed),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Heures supplémentaires !',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppTheme.colorRed)),
                      Text(
                        '${Calculs.formatHeures(heuresSupp)} en heures supp. (+25% puis +50%)',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ])),
                  ]),
                ),
                const SizedBox(height: 10),
              ],

              // ── Métriques ──────────────────────────────────────────
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
                children: [
                  _metricCard('Total travaillé', Calculs.formatHeures(totalHeures),
                      'cette quatorzaine', AppTheme.blue),
                  _metricCard('Salaire brut', '${brut.toStringAsFixed(0)} €',
                      'estimé ce mois', AppTheme.green),
                  _metricCard('Net estimé', '${net.toStringAsFixed(0)} €',
                      '~78% du brut', AppTheme.teal),
                  _metricCard('H. supp.', Calculs.formatHeures(heuresSupp),
                      'seuil à 78h',
                      heuresSupp > 0 ? AppTheme.red : AppTheme.textSecondary),
                ],
              ),
              const SizedBox(height: 14),

              // ── Planning calendrier ──────────────────────────────
              _buildCalendar(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    final premierJour = DateTime(year, month, 1);
    final dernierJour = DateTime(year, month + 1, 0);
    final offset = premierJour.weekday - 1;
    final rows = ((offset + dernierJour.day) / 7).ceil();

    final moisNoms = ['','Janvier','Février','Mars','Avril','Mai','Juin',
        'Juillet','Août','Septembre','Octobre','Novembre','Décembre'];
    final moisCourts = ['','jan','fév','mars','avr','mai','juin',
        'juil','août','sep','oct','nov','déc'];
    final joursNoms = ['L','M','M','J','V','S','D'];

    final gardesMois = _planning.where((g) =>
        g.date.year == year && g.date.month == month).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final totalH = gardesMois.fold(0.0, (s, g) => s + g.dureeHeures);

    // Cherche la prochaine garde dans tous les mois futurs
    String prochaine = '—';
    final toutesGardesFutures = _planning.where((g) =>
        !g.date.isBefore(DateTime(now.year, now.month, now.day))).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (toutesGardesFutures.isNotEmpty) {
      final nxt = toutesGardesFutures.first;
      final diff = nxt.date.difference(DateTime(now.year, now.month, now.day)).inDays;
      prochaine = diff == 0 ? "Auj." : diff == 1 ? "Dem." : "${diff}j";
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('PLANNING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
            color: AppTheme.textTertiary, letterSpacing: 0.8)),
        GestureDetector(
          onTap: () => _ouvrirAjoutPlanning(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: AppTheme.blueAccent, borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Icon(Icons.add, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text('Ajouter', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 8),

      Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.bgCardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header bleu ─────────────────────────────────────
          Container(
            color: const Color(0xFF0C447C),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                GestureDetector(
                  onTap: () => setState(() => _calendarMonth = DateTime(year, month - 1, 1)),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chevron_left, size: 20, color: Colors.white),
                  ),
                ),
                Column(children: [
                  Text('${moisNoms[month]} $year',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('${gardesMois.length} garde${gardesMois.length > 1 ? "s" : ""} · ${totalH.toStringAsFixed(0)}h planifiées',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65))),
                ]),
                GestureDetector(
                  onTap: () => setState(() => _calendarMonth = DateTime(year, month + 1, 1)),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chevron_right, size: 20, color: Colors.white),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              // Stats — types de gardes
              Builder(builder: (ctx2) {
                final nbJour = gardesMois.where((g) => g.typeGarde == 'UPH Jour').length;
                final nbNuit = gardesMois.where((g) => g.typeGarde == 'UPH Nuit').length;
                final nbArt = gardesMois.where((g) => g.typeGarde == 'Art 80').length;
                return Row(children: [
                  _statBloc('$nbJour', 'UPH JOUR'),
                  const SizedBox(width: 8),
                  _statBloc('$nbNuit', 'UPH NUIT'),
                  const SizedBox(width: 8),
                  _statBloc('$nbArt', 'ART 80'),
                  const SizedBox(width: 8),
                  _statBloc(prochaine, 'PROCHAINE'),
                ]);
              }),
            ]),
          ),

          // ── Noms des jours ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(children: List.generate(7, (i) => Expanded(
              child: Center(child: Text(joursNoms[i], style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w500,
                color: i >= 5 ? AppTheme.colorRed : AppTheme.textTertiary,
              ))),
            ))),
          ),

          // ── Grille ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(children: List.generate(rows, (row) => Row(
              children: List.generate(7, (col) {
                final idx = row * 7 + col;
                final day = idx - offset + 1;
                if (day < 1 || day > dernierJour.day) return const Expanded(child: SizedBox(height: 42));
                final date = DateTime(year, month, day);
                final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                final garde = gardesMois.where((g) => g.date.day == day).firstOrNull;
                final hasGarde = garde != null;
                final isWe = date.weekday >= 6;

                Color bgColor = Colors.transparent;
                Color textColor = isWe ? AppTheme.colorRed : AppTheme.textPrimary;
                Color dotColor = const Color(0xFF1D9E75);

                if (isToday) {
                  bgColor = const Color(0xFF185FA5);
                  textColor = Colors.white;
                  dotColor = Colors.white.withValues(alpha: 0.8);
                } else if (hasGarde && isWe) {
                  bgColor = const Color(0xFFFEF3C7);
                  textColor = const Color(0xFF854F0B);
                  dotColor = const Color(0xFFBA7517);
                } else if (hasGarde) {
                  bgColor = const Color(0xFFE1F5EE);
                  textColor = const Color(0xFF0F6E56);
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (hasGarde) {
                        _ouvrirAjoutPlanning(garde: garde);
                      } else {
                        final g = PlannedGarde(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          date: date,
                        );
                        _ouvrirAjoutPlanning(garde: g);
                      }
                    },
                    child: Container(
                      height: 42, margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('$day', style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday || hasGarde ? FontWeight.w600 : FontWeight.w400,
                          color: textColor,
                        )),
                        if (hasGarde)
                          Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                      ]),
                    ),
                  ),
                );
              }),
            ))),
          ),

          // ── Liste gardes ────────────────────────────────────
          Divider(color: AppTheme.bgCardBorder, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('GARDES DU MOIS', style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w500,
                  color: AppTheme.textTertiary, letterSpacing: 0.5)),
              if (gardesMois.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D9E75).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${gardesMois.length} garde${gardesMois.length > 1 ? "s" : ""}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0F6E56), fontWeight: FontWeight.w500)),
                ),
            ]),
          ),

          if (gardesMois.isNotEmpty)
            ...gardesMois.map((g) {
              final isToday = g.date.year == now.year && g.date.month == now.month && g.date.day == now.day;
              final isWe = g.date.weekday >= 6;

              Color avBg = const Color(0xFFE6F1FB);
              Color avDay = const Color(0xFF185FA5);
              Color avMon = const Color(0xFF378ADD);
              Color durColor = const Color(0xFF0F6E56);
              Color giBg = Colors.transparent;

              if (isToday) {
                avBg = const Color(0xFF185FA5); avDay = Colors.white;
                avMon = Colors.white70; durColor = const Color(0xFF185FA5);
                giBg = const Color(0xFFEEF4FC);
              } else if (isWe) {
                avBg = const Color(0xFFFEF3C7); avDay = const Color(0xFF854F0B);
                avMon = const Color(0xFFBA7517); durColor = const Color(0xFF854F0B);
                giBg = const Color(0xFFFFFBEB);
              }

              final extras = g.collegue != null && g.collegue!.isNotEmpty ? g.collegue! : '';

              return GestureDetector(
                onTap: () => _ouvrirAjoutPlanning(garde: g),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: giBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: avBg, borderRadius: BorderRadius.circular(10)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${g.date.day}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: avDay, height: 1)),
                        Text(moisCourts[month], style: TextStyle(fontSize: 9, color: avMon)),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.heuresLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                      const SizedBox(height: 3),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.blueAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(g.typeGarde, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.blueAccent)),
                        ),
                        if (extras.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text('👤 $extras', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        ],
                      ]),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${g.dureeHeures.toStringAsFixed(0)}h',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: durColor)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _supprimerGardePlanning(g),
                        child: Icon(Icons.close, size: 16, color: AppTheme.textTertiary),
                      ),
                    ]),
                  ]),
                ),
              );
            }),
          const SizedBox(height: 6),

          // ── Jours fériés du mois ────────────────────────────
          ..._feriesDuMois(year, month),
        ]),
      ),
    ]);
  }

  List<Widget> _feriesDuMois(int year, int month) {
    final feries = Garde.joursFeries(year)
        .map((s) {
          final parts = s.split('-');
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        })
        .where((d) => d.month == month)
        .toList()
      ..sort((a, b) => a.compareTo(b));

    if (feries.isEmpty) return [];

    final moisCourts = ['','jan','fév','mars','avr','mai','juin','juil','août','sep','oct','nov','déc'];
    final nomsFeries = {
      '1-1': ('Jour de l\'An', false),
      '5-1': ('Fête du Travail', true),
      '5-8': ('Victoire 1945', false),
      '7-14': ('Fête Nationale', false),
      '8-15': ('Assomption', false),
      '11-1': ('Toussaint', false),
      '11-11': ('Armistice', false),
      '12-25': ('Noël', false),
    };
    // Calcul Pâques inline
    int a=year%19,b=year~/100,c=year%100,d=b~/4,e=b%4,f=(b+8)~/25;
    int g=(b-f+1)~/3,h=(19*a+b-d-g+15)%30,i=c~/4,k=c%4;
    int l=(32+2*e+2*i-h-k)%7,mm=(a+11*h+22*l)~/451;
    final pM=(h+l-7*mm+114)~/31, pJ=((h+l-7*mm+114)%31)+1;
    final paques = DateTime(year, pM, pJ);
    final feriesCalc = {
      '${paques.add(const Duration(days:1)).month}-${paques.add(const Duration(days:1)).day}': ('Lundi de Pâques', false),
      '${paques.add(const Duration(days:39)).month}-${paques.add(const Duration(days:39)).day}': ('Ascension', false),
      '${paques.add(const Duration(days:50)).month}-${paques.add(const Duration(days:50)).day}': ('Lundi de Pentecôte', false),
    };

    return [
      Divider(color: AppTheme.bgCardBorder, height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('JOURS FÉRIÉS', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500,
              color: AppTheme.textTertiary, letterSpacing: 0.5)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFBA7517).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${feries.length} férié${feries.length > 1 ? "s" : ""}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF854F0B), fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
      ...feries.map((d) {
        final key = '${d.month}-${d.day}';
        final info = nomsFeries[key] ?? feriesCalc[key] ?? ('Jour férié', false);
        final nom = info.$1;
        final majore = info.$2; // true = +100% si travaillé, false = payé 7h

        return Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: majore ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: majore ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${d.day}', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500,
                    color: majore ? const Color(0xFF166534) : const Color(0xFF854F0B), height: 1)),
                Text(moisCourts[d.month], style: TextStyle(
                    fontSize: 9, color: majore ? const Color(0xFF166534) : const Color(0xFF854F0B))),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nom, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              Builder(builder: (ctx) {
                final hasGarde = _planning.any((g) =>
                    g.date.year == d.year && g.date.month == d.month && g.date.day == d.day);
                return Text(
                  hasGarde ? '✓ Garde prévue' : 'Aucune garde prévue',
                  style: TextStyle(
                    fontSize: 10,
                    color: hasGarde ? const Color(0xFF0F6E56) : AppTheme.textTertiary,
                    fontWeight: hasGarde ? FontWeight.w500 : FontWeight.w400,
                  ),
                );
              }),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: majore ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                majore ? '+100%' : 'Payé 7h',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: majore ? const Color(0xFF166534) : const Color(0xFF854F0B),
                ),
              ),
            ),
          ]),
        );
      }),
      const SizedBox(height: 6),
    ];
  }

  Widget _statBloc(String val, String lbl) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
        const SizedBox(height: 2),
        Text(lbl, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 0.3)),
      ]),
    ));
  }

  Widget _champHeureFixe(String label, TextEditingController hCtrl,
      TextEditingController mCtrl, Function(int, int) onChange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF185FA5).withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF185FA5), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 44, child: TextField(
            controller: hCtrl, textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF042C53)),
            decoration: const InputDecoration(
              hintText: 'HH', contentPadding: EdgeInsets.zero, isDense: true,
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF185FA5), width: 1)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF185FA5), width: 2)),
            ),
            onChanged: (v) {
              final h = (int.tryParse(v) ?? 0).clamp(0, 23);
              final m = (int.tryParse(mCtrl.text) ?? 0).clamp(0, 59);
              onChange(h, m);
            },
          )),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF042C53)))),
          SizedBox(width: 44, child: TextField(
            controller: mCtrl, textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF042C53)),
            decoration: const InputDecoration(
              hintText: 'MM', contentPadding: EdgeInsets.zero, isDense: true,
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF185FA5), width: 1)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF185FA5), width: 2)),
            ),
            onChanged: (v) {
              final h = (int.tryParse(hCtrl.text) ?? 0).clamp(0, 23);
              final m = (int.tryParse(v) ?? 0).clamp(0, 59);
              onChange(h, m);
            },
          )),
        ]),
      ]),
    );
  }

  Widget _metricCard(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color)),
          Text(sub, style: TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
        ],
      ),
    );
  }

}