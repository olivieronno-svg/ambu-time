
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/garde.dart';
import '../models/planned_garde.dart';
import '../utils/calculs.dart';
import '../app_theme.dart';

class _Note {
  final String id;
  String titre;
  String contenu;
  _Note({required this.id, required this.titre, required this.contenu});
  Map<String, dynamic> toMap() => {'id': id, 'titre': titre, 'contenu': contenu};
  factory _Note.fromMap(Map<String, dynamic> m) =>
      _Note(id: m['id'], titre: m['titre'], contenu: m['contenu'] ?? '');
}

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
  List<_Note> _notes = [];
  List<PlannedGarde> _planning = [];
  static const _keyNotes = 'app_notes_v1';
  static const _keyPlanning = 'app_planning_v1';
  String _lettreActive = 'A';
  final ScrollController _notesScroll = ScrollController();

  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  @override
  void initState() { super.initState(); _chargerNotes(); _chargerPlanning(); }

  @override
  void dispose() { _notesScroll.dispose(); super.dispose(); }

  Future<void> _chargerPlanning() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyPlanning) ?? [];
    final now = DateTime.now();
    setState(() {
      _planning = raw
          .map((s) => PlannedGarde.fromMap(jsonDecode(s)))
          .where((g) => !g.date.isBefore(DateTime(now.year, now.month, now.day)))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    });
  }

  Future<void> _sauvegarderPlanning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyPlanning,
        _planning.map((g) => jsonEncode(g.toMap())).toList());
  }

  void _ouvrirAjoutPlanning({PlannedGarde? garde}) {
    DateTime dateSelectionnee = garde?.date ?? DateTime.now().add(const Duration(days: 1));
    int dhH = garde?.heureDebutH ?? 7, dhM = garde?.heureDebutM ?? 0;
    int dfH = garde?.heureFinH ?? 17, dfM = garde?.heureFinM ?? 0;
    final notesCtrl = TextEditingController(text: garde?.notes ?? '');
    final collegueCtrl = TextEditingController(text: garde?.collegue ?? '');

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFFB5D4F4).withOpacity(0.95),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Planifier une garde', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF042C53))),
                if (garde != null)
                  GestureDetector(
                    onTap: () { Navigator.pop(ctx);
                      setState(() => _planning.removeWhere((g) => g.id == garde.id));
                      _sauvegarderPlanning(); },
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
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) setModalState(() => dateSelectionnee = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF185FA5).withOpacity(0.3)),
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
              const SizedBox(height: 12),

              // Horaires
              Row(children: [
                Expanded(child: _champHeureModal('Début',
                    dhH, dhM, (h, m) => setModalState(() { dhH = h; dhM = m; }))),
                const SizedBox(width: 10),
                Expanded(child: _champHeureModal('Fin',
                    dfH, dfM, (h, m) => setModalState(() { dfH = h; dfM = m; }))),
              ]),
              const SizedBox(height: 12),

              TextField(controller: collegueCtrl,
                style: const TextStyle(color: Color(0xFF042C53)),
                decoration: InputDecoration(
                  labelText: 'Collègue prévu',
                  labelStyle: const TextStyle(color: Color(0xFF185FA5)),
                  prefixIcon: const Icon(Icons.person_outline, size: 18, color: Color(0xFF185FA5)),
                  fillColor: Colors.white.withOpacity(0.7),
                )),
              const SizedBox(height: 8),
              TextField(controller: notesCtrl,
                style: const TextStyle(color: Color(0xFF042C53)),
                decoration: InputDecoration(
                  labelText: 'Notes',
                  labelStyle: const TextStyle(color: Color(0xFF185FA5)),
                  prefixIcon: const Icon(Icons.notes, size: 18, color: Color(0xFF185FA5)),
                  fillColor: Colors.white.withOpacity(0.7),
                )),
              const SizedBox(height: 16),

              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () {
                  final pg = PlannedGarde(
                    id: garde?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    date: dateSelectionnee,
                    heureDebutH: dhH, heureDebutM: dhM,
                    heureFinH: dfH, heureFinM: dfM,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    collegue: collegueCtrl.text.trim().isEmpty ? null : collegueCtrl.text.trim(),
                  );
                  setState(() {
                    if (garde == null) {
                      _planning.add(pg);
                    } else {
                      final i = _planning.indexWhere((g) => g.id == garde.id);
                      if (i != -1) _planning[i] = pg;
                    }
                    _planning.sort((a, b) => a.date.compareTo(b.date));
                  });
                  _sauvegarderPlanning();
                  Navigator.pop(ctx);
                },
                child: Text(garde == null ? 'Ajouter au planning' : 'Mettre à jour',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _champHeureModal(String label, int h, int m, Function(int, int) onChanged) {
    final hCtrl = TextEditingController(text: h.toString().padLeft(2, '0'));
    final mCtrl = TextEditingController(text: m.toString().padLeft(2, '0'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF185FA5).withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF185FA5))),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 36, child: TextField(
            controller: hCtrl, textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: Color(0xFF042C53)),
            decoration: const InputDecoration(
                hintText: 'HH', contentPadding: EdgeInsets.zero, isDense: true,
                border: InputBorder.none),
            onChanged: (v) {
              final hv = int.tryParse(v) ?? h;
              onChanged(hv.clamp(0, 23), m);
            },
          )),
          const Text(' : ', style: TextStyle(fontSize: 18, color: Color(0xFF042C53))),
          SizedBox(width: 36, child: TextField(
            controller: mCtrl, textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: Color(0xFF042C53)),
            decoration: const InputDecoration(
                hintText: 'MM', contentPadding: EdgeInsets.zero, isDense: true,
                border: InputBorder.none),
            onChanged: (v) {
              final mv = int.tryParse(v) ?? m;
              onChanged(h, mv.clamp(0, 59));
            },
          )),
        ]),
      ]),
    );
  }

  Future<void> _chargerNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyNotes) ?? [];
    setState(() {
      _notes = raw.map((s) => _Note.fromMap(jsonDecode(s))).toList()
        ..sort((a, b) => a.titre.toLowerCase().compareTo(b.titre.toLowerCase()));
    });
  }

  Future<void> _sauvegarderNotes() async {
    final prefs = await SharedPreferences.getInstance();
    _notes.sort((a, b) => a.titre.toLowerCase().compareTo(b.titre.toLowerCase()));
    await prefs.setStringList(_keyNotes, _notes.map((n) => jsonEncode(n.toMap())).toList());
  }

  void _ouvrirEditeur(_Note? note) {
    final titreCtrl = TextEditingController(text: note?.titre ?? '');
    final contenuCtrl = TextEditingController(text: note?.contenu ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(note == null ? 'Nouvelle note' : 'Modifier la note',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              if (note != null)
                GestureDetector(
                  onTap: () { Navigator.pop(ctx); _supprimerNote(note); },
                  child: Icon(Icons.delete_outline, color: AppTheme.red, size: 22),
                ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: titreCtrl, autofocus: true,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(hintText: 'Titre...',
                  hintStyle: TextStyle(color: AppTheme.textTertiary)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contenuCtrl, maxLines: 5,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(hintText: 'Contenu...',
                  hintStyle: TextStyle(color: AppTheme.textTertiary)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final titre = titreCtrl.text.trim();
                  if (titre.isEmpty) return;
                  if (note == null) {
                    _notes.add(_Note(id: DateTime.now().millisecondsSinceEpoch.toString(),
                        titre: titre, contenu: contenuCtrl.text.trim()));
                  } else { note.titre = titre; note.contenu = contenuCtrl.text.trim(); }
                  setState(() => _notes.sort((a, b) =>
                      a.titre.toLowerCase().compareTo(b.titre.toLowerCase())));
                  _sauvegarderNotes();
                  Navigator.pop(ctx);
                },
                child: Text(note == null ? 'Enregistrer' : 'Mettre à jour',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _supprimerNote(_Note note) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Supprimer la note ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppTheme.blue))),
        TextButton(onPressed: () {
          setState(() => _notes.removeWhere((n) => n.id == note.id));
          _sauvegarderNotes(); Navigator.pop(ctx);
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

  List<_Note> get _notesPourLettre {
    return _notes.where((n) =>
        n.titre.isNotEmpty &&
        n.titre[0].toUpperCase() == _lettreActive).toList();
  }

  @override
  Widget build(BuildContext context) {
    final quatorzaineActive = _quatorzaineActive();
    final gardesQ = quatorzaineActive != null
        ? _gardesDeQuatorzaine(quatorzaineActive)
        : widget.gardes;

    double totalHeures = Calculs.totalHeures(gardesQ);
    double heuresSupp = Calculs.heuresSupp(gardesQ);
    double brut = Calculs.totalBrut(gardesQ, taux: widget.tauxHoraire);
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
                  Text('Bonjour,', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  Text('Mes heures', style: AppTheme.titleStyle()),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.blueAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.blueAccent.withOpacity(0.4)),
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
                        color: AppTheme.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 14, color: AppTheme.amber.withOpacity(0.8)),
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
                    color: AppTheme.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.amber.withOpacity(0.5)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.amber.withOpacity(0.2),
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
                    color: AppTheme.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.red.withOpacity(0.5)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.red.withOpacity(0.2),
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

              // ── Planning des gardes à venir ────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('PLANNING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiary, letterSpacing: 0.8)),
                GestureDetector(
                  onTap: () => _ouvrirAjoutPlanning(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.blueAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      const Icon(Icons.add, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      const Text('Ajouter', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 8),

              if (_planning.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration(),
                  child: Row(children: [
                    Icon(Icons.event_outlined, size: 18, color: AppTheme.textTertiary),
                    const SizedBox(width: 10),
                    Text('Aucune garde planifiée',
                        style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                  ]),
                )
              else
                Column(children: _planning.take(5).map((g) {
                  final joursRestants = g.date.difference(DateTime.now()).inDays;
                  final color = g.isToday
                      ? const Color(0xFF1D9E75)
                      : g.isTomorrow
                          ? const Color(0xFFd97706)
                          : const Color(0xFF185FA5);
                  final bgColor = g.isToday
                      ? const Color(0xFF9FE1CB).withOpacity(0.2)
                      : g.isTomorrow
                          ? const Color(0xFFFAC775).withOpacity(0.2)
                          : const Color(0xFFB5D4F4).withOpacity(0.2);
                  final label = g.isToday ? "Aujourd'hui"
                      : g.isTomorrow ? 'Demain'
                      : 'Dans $joursRestants j.';

                  return GestureDetector(
                    onTap: () => _ouvrirAjoutPlanning(garde: g),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('${g.date.day}', style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w800, color: color)),
                            Text(_moisCourt(g.date.month), style: TextStyle(
                                fontSize: 9, color: color)),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(label, style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600, color: color)),
                          Text(g.heuresLabel, style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                          if (g.collegue != null)
                            Text('👤 ${g.collegue}', style: TextStyle(
                                fontSize: 10, color: AppTheme.textSecondary)),
                          if (g.notes != null)
                            Text('📝 ${g.notes}', style: TextStyle(
                                fontSize: 10, color: AppTheme.textSecondary)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${g.dureeHeures.toStringAsFixed(1)}h',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                  color: color)),
                          Icon(Icons.edit_outlined, size: 12, color: AppTheme.textTertiary),
                        ]),
                      ]),
                    ),
                  );
                }).toList()),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
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

  String _moisCourt(int mois) {
    const noms = ['', 'jan', 'fév', 'mar', 'avr', 'mai', 'jun',
        'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return noms[mois];
  }
}
