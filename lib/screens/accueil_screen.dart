
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/garde.dart';
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
  static const _keyNotes = 'app_notes_v1';
  String _lettreActive = 'A';
  final ScrollController _notesScroll = ScrollController();

  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  @override
  void initState() { super.initState(); _chargerNotes(); }

  @override
  void dispose() { _notesScroll.dispose(); super.dispose(); }

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

              // ── Notes calepin A-Z ──────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('NOTES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiary, letterSpacing: 0.8)),
                GestureDetector(
                  onTap: () => _ouvrirEditeur(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.blueAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.blueAccent.withOpacity(0.3)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.add, size: 14, color: AppTheme.blueAccent),
                      SizedBox(width: 4),
                      Text('Nouvelle', style: TextStyle(fontSize: 11, color: AppTheme.blueAccent)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 8),

              // ── Calepin avec onglets A-Z ───────────────────────────
              Container(
                height: 380,
                decoration: AppTheme.cardDecoration(),
                clipBehavior: Clip.hardEdge,
                child: Row(
                  children: [
                    // Contenu des notes
                    Expanded(
                      child: Column(
                        children: [
                          // En-tête lettre active
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            color: AppTheme.blueAccent.withOpacity(0.1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_lettreActive, style: TextStyle(fontSize: 18,
                                    fontWeight: FontWeight.w700, color: AppTheme.blueAccent,
                                    letterSpacing: 1)),
                                Text(
                                  '${_notesPourLettre.length} note${_notesPourLettre.length != 1 ? 's' : ''}',
                                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          // Liste des notes
                          Expanded(
                            child: _notesPourLettre.isEmpty
                                ? Center(child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.notes, size: 28, color: AppTheme.textTertiary),
                                      const SizedBox(height: 6),
                                      Text('Aucune note pour $_lettreActive',
                                          style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                                    ],
                                  ))
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    itemCount: _notesPourLettre.length,
                                    separatorBuilder: (_, __) => Divider(height: 1,
                                        color: AppTheme.bgCardBorder, indent: 14, endIndent: 14),
                                    itemBuilder: (ctx, i) {
                                      final note = _notesPourLettre[i];
                                      return GestureDetector(
                                        onTap: () => _ouvrirEditeur(note),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          child: Row(children: [
                                            Expanded(child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(note.titre, style: TextStyle(fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppTheme.textPrimary)),
                                                if (note.contenu.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(note.contenu, maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(fontSize: 11,
                                                          color: AppTheme.textSecondary)),
                                                ],
                                              ],
                                            )),
                                            Icon(Icons.chevron_right, size: 16,
                                                color: AppTheme.textTertiary),
                                          ]),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    // Onglets A-Z à droite
                    Container(
                      width: 22,
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: AppTheme.bgCardBorder, width: 0.5)),
                      ),
                      child: ListView.builder(
                        itemCount: _alphabet.length,
                        itemBuilder: (ctx, i) {
                          final lettre = _alphabet[i];
                          final hasNotes = _notes.any((n) =>
                              n.titre.isNotEmpty && n.titre[0].toUpperCase() == lettre);
                          final isActive = lettre == _lettreActive;
                          return GestureDetector(
                            onTap: () => setState(() => _lettreActive = lettre),
                            child: Container(
                              height: 14,
                              color: isActive
                                  ? AppTheme.blueAccent.withOpacity(0.2)
                                  : Colors.transparent,
                              child: Center(
                                child: Text(lettre,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                                    color: hasNotes
                                        ? (isActive ? AppTheme.blueAccent : AppTheme.textPrimary)
                                        : AppTheme.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
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
}
