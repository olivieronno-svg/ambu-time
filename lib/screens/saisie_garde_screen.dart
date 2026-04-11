
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/garde.dart';
import '../models/achat.dart';
import '../utils/calculs.dart';
import '../app_theme.dart';

class SaisieGardeScreen extends StatefulWidget {
  final Function(Garde) onGardeAjoutee;
  final double tauxHoraire;
  final double panierRepas;
  final double indemnitesDimanche;
  final double montantIdaj;
  final Garde? gardeAModifier;
  final Function(Garde)? onGardeModifiee;
  final DateTime? debutQuatorzaine;
  final double kmDomicileTravail;
  final String poste;

  const SaisieGardeScreen({
    super.key,
    required this.onGardeAjoutee,
    required this.tauxHoraire,
    required this.panierRepas,
    required this.indemnitesDimanche,
    required this.montantIdaj,
    required this.kmDomicileTravail,
    required this.poste,
    this.gardeAModifier,
    this.onGardeModifiee,
    this.debutQuatorzaine,
  });

  @override
  State<SaisieGardeScreen> createState() => _SaisieGardeScreenState();
}

class _SaisieGardeScreenState extends State<SaisieGardeScreen> {
  late DateTime _date;
  bool _jourNonTravaille = false;
  bool _avecPause = false;
  int _pauseMinutes = 30;
  bool _avecPanier = true;
  late double _panierRepasGarde;
  late TextEditingController _debutHeureCtrl;
  late TextEditingController _debutMinCtrl;
  late TextEditingController _finHeureCtrl;
  late TextEditingController _finMinCtrl;
  late TextEditingController _collegueCtrl;
  late TextEditingController _vehiculeCtrl;
  List<Achat> _achats = [];

  @override
  void initState() {
    super.initState();
    final g = widget.gardeAModifier;
    _date = g?.date ?? DateTime.now();
    _jourNonTravaille = g?.jourNonTravaille ?? false;
    _avecPanier = g?.avecPanier ?? true;
    _panierRepasGarde = g?.panierRepasGarde ?? widget.panierRepas;
    if (g != null && g.pauseMinutes > 0) { _avecPause = true; _pauseMinutes = g.pauseMinutes; }
    _achats = g != null ? List.from(g.achats) : [];

    final dh = g?.heureDebut.hour ?? 7;
    final dm = g?.heureDebut.minute ?? 0;
    final fh = g?.heureFin.hour ?? 17;
    final fm = g?.heureFin.minute ?? 0;
    _debutHeureCtrl = TextEditingController(text: dh.toString().padLeft(2, '0'));
    _debutMinCtrl   = TextEditingController(text: dm.toString().padLeft(2, '0'));
    _finHeureCtrl   = TextEditingController(text: fh.toString().padLeft(2, '0'));
    _finMinCtrl     = TextEditingController(text: fm.toString().padLeft(2, '0'));
    _collegueCtrl   = TextEditingController(text: g?.collegue ?? '');
    _vehiculeCtrl   = TextEditingController(text: g?.vehiculeUtilise ?? '');

    // Listeners pour mise à jour dynamique du calcul CCN
    _debutHeureCtrl.addListener(() => setState(() {}));
    _debutMinCtrl.addListener(() => setState(() {}));
    _finHeureCtrl.addListener(() => setState(() {}));
    _finMinCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debutHeureCtrl.dispose(); _debutMinCtrl.dispose();
    _finHeureCtrl.dispose(); _finMinCtrl.dispose();
    _collegueCtrl.dispose(); _vehiculeCtrl.dispose();
    super.dispose();
  }

  int _val(TextEditingController c, int max) =>
      (int.tryParse(c.text) ?? 0).clamp(0, max);

  Garde _buildGarde() {
    final dh = _val(_debutHeureCtrl, 23); final dm = _val(_debutMinCtrl, 59);
    final fh = _val(_finHeureCtrl, 23);   final fm = _val(_finMinCtrl, 59);
    final debut = DateTime(_date.year, _date.month, _date.day, dh, dm);
    var fin    = DateTime(_date.year, _date.month, _date.day, fh, fm);
    if (!_jourNonTravaille && fin.isBefore(debut))
      fin = fin.add(const Duration(days: 1));
    return Garde(
      id: widget.gardeAModifier?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: _date,
      heureDebut: debut,
      heureFin: _jourNonTravaille ? debut : fin,
      jourNonTravaille: _jourNonTravaille,
      collegue: _collegueCtrl.text.trim().isEmpty ? null : _collegueCtrl.text.trim(),
      vehiculeUtilise: _vehiculeCtrl.text.trim().isEmpty ? null : _vehiculeCtrl.text.trim(),
      kmDomicileTravail: widget.kmDomicileTravail,
      achats: _achats,
      pauseMinutes: _avecPause && !_jourNonTravaille ? _pauseMinutes : 0,
      panierRepasGarde: _avecPanier ? _panierRepasGarde : 0,
      avecPanier: _avecPanier,
      debutQuatorzaine: widget.debutQuatorzaine,
      qualification: widget.poste,
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.blueAccent,
              onPrimary: Colors.white, surface: AppTheme.bgSecondaryDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _ouvrirAjoutAchat({Achat? achat}) {
    final intCtrl = TextEditingController(text: achat?.intitule ?? '');
    final montantCtrl = TextEditingController(
        text: achat != null ? achat.montant.toStringAsFixed(2) : '');
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFFEAF3DE),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(achat == null ? 'Nouvel achat' : 'Modifier l\'achat',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: Color(0xFF173404))),
            if (achat != null)
              GestureDetector(
                onTap: () { Navigator.pop(ctx);
                  setState(() => _achats.removeWhere((a) => a.id == achat.id)); },
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(controller: intCtrl, autofocus: true,
            style: const TextStyle(color: Color(0xFF173404)),
            decoration: InputDecoration(labelText: 'Intitulé de l\'achat',
                labelStyle: const TextStyle(color: Color(0xFF3B6D11)),
                hintText: 'Ex: Carburant, Péage...',
                hintStyle: const TextStyle(color: Color(0xFF639922)))),
          const SizedBox(height: 12),
          TextField(controller: montantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Color(0xFF173404)),
            decoration: InputDecoration(labelText: 'Montant (€)',
                labelStyle: const TextStyle(color: Color(0xFF3B6D11)),
                suffixText: '€',
                hintStyle: const TextStyle(color: Color(0xFF639922)))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              final int = intCtrl.text.trim();
              if (int.isEmpty) return;
              final montant = double.tryParse(
                  montantCtrl.text.replaceAll(',', '.')) ?? 0;
              if (achat == null) {
                setState(() => _achats.add(Achat(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  intitule: int, montant: montant)));
              } else {
                setState(() { achat.intitule = int; achat.montant = montant; });
              }
              Navigator.pop(ctx);
            },
            child: Text(achat == null ? 'Ajouter' : 'Mettre à jour',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          )),
        ]),
      ),
    );
  }

  Widget _champHeure(String label, TextEditingController heureCtrl,
      TextEditingController minCtrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(color: AppTheme.bgCard,
          border: Border.all(color: AppTheme.bgCardBorder),
          borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _champNum(heureCtrl, 'HH'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary))),
          _champNum(minCtrl, 'MM'),
        ]),
      ]),
    );
  }

  Widget _champNum(TextEditingController ctrl, String hint) {
    return SizedBox(width: 44, child: TextField(
      controller: ctrl, textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2)],
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.blueAccent),
      decoration: InputDecoration(hintText: hint,
        hintStyle: TextStyle(fontSize: 16, color: AppTheme.textTertiary),
        contentPadding: EdgeInsets.zero, isDense: true,
        enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.bgCardBorder, width: 1)),
        focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.blueAccent, width: 2)),
      ),
    ));
  }

  Widget _btnPM(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppTheme.blueAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 18, color: AppTheme.blueAccent)),
  );

  @override
  Widget build(BuildContext context) {
    final garde = _buildGarde();
    final brut = _jourNonTravaille ? 0.0 : Calculs.salaireBrutGarde(garde,
        taux: widget.tauxHoraire, panier: _panierRepasGarde,
        indDimanche: widget.indemnitesDimanche, montantIdaj: widget.montantIdaj);
    final heuresNuit = Calculs.heuresNuit(garde);
    final majNuit = Calculs.majorationNuit(garde, widget.tauxHoraire);
    final majDim  = Calculs.majorationDimanche(garde, widget.tauxHoraire);
    final idaj    = Calculs.idaj(garde, widget.tauxHoraire);
    final estModif = widget.gardeAModifier != null;
    final nomFerie = garde.nomJourFerie;
    final estFerieOuDim = garde.isDimancheOuFerie;
    final dq = widget.debutQuatorzaine;
    double prog = 0;
    String labelQ = 'Quatorzaine non définie — voir Paramètres';
    if (dq != null) {
      prog = (_date.difference(dq).inDays.clamp(0, 13) / 13);
      labelQ = '${dq.day}/${dq.month} → ${dq.add(const Duration(days: 13)).day}/${dq.add(const Duration(days: 13)).month}/${dq.add(const Duration(days: 13)).year}';
    }
    final totalAchats = _achats.fold(0.0, (s, a) => s + a.montant);

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── En-tête ────────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(estModif ? 'Modifier la garde' : 'Saisir une garde',
                  style: AppTheme.titleStyle()),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.blueAccent.withOpacity(0.4))),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 13, color: AppTheme.blueAccent),
                    const SizedBox(width: 5),
                    Text('${_date.day}/${_date.month}/${_date.year}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.blueAccent,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ]),

            if (estFerieOuDim) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.4))),
                child: Row(children: [
                  const Icon(Icons.star_rounded, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(nomFerie != null ? '$nomFerie — majorations appliquées'
                      : 'Dimanche — majorations appliquées',
                      style: const TextStyle(fontSize: 12, color: Colors.orange,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ],
            const SizedBox(height: 12),

            // ── Quatorzaine ────────────────────────────────────────
            _sectionCard('Quatorzaine', Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(labelQ, style: TextStyle(fontSize: 11,
                      color: dq != null ? AppTheme.blueAccent : AppTheme.textTertiary,
                      fontWeight: FontWeight.w500)),
                  if (dq == null)
                    Text('Paramètres →',
                        style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
                ]),
                if (dq != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: prog, minHeight: 6,
                      backgroundColor: AppTheme.blueAccent.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.blueAccent))),
                  const SizedBox(height: 4),
                  Text('Jour ${(_date.difference(dq).inDays.clamp(0, 13) + 1)} / 14',
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ],
              ],
            )),
            const SizedBox(height: 10),

            // ── Jour non travaillé ─────────────────────────────────
            _sectionCard('Horaires de travail', Column(children: [
              // Bouton jour non travaillé
              GestureDetector(
                onTap: () => setState(() => _jourNonTravaille = !_jourNonTravaille),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _jourNonTravaille
                        ? Colors.orange.withOpacity(0.15)
                        : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _jourNonTravaille
                        ? Colors.orange.withOpacity(0.5)
                        : AppTheme.bgCardBorder),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_jourNonTravaille ? Icons.event_busy : Icons.event_busy_outlined,
                        size: 16,
                        color: _jourNonTravaille ? Colors.orange : AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text('Jour non travaillé',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: _jourNonTravaille ? Colors.orange : AppTheme.textSecondary)),
                  ]),
                ),
              ),
              if (!_jourNonTravaille) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _champHeure('Début', _debutHeureCtrl, _debutMinCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _champHeure('Fin', _finHeureCtrl, _finMinCtrl)),
                ]),
                const SizedBox(height: 8),
                ClipRect(
                  child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppTheme.blueAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.timer_outlined, size: 13, color: AppTheme.blueAccent),
                    const SizedBox(width: 5),
                    Flexible(child: Text('Durée : ${Calculs.formatHeures(garde.dureeHeures)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppTheme.blueAccent,
                            fontWeight: FontWeight.w500))),
                  ]),
                  ),
                ),
              ],
            ])),
            const SizedBox(height: 10),

            // ── Pause (seulement si journée travaillée) ────────────
            if (!_jourNonTravaille) ...[
              _sectionCard('Pause', Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Inclure une pause',
                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  Switch(value: _avecPause,
                      onChanged: (v) => setState(() => _avecPause = v)),
                ]),
                if (_avecPause) ...[
                  const SizedBox(height: 12),
                  Center(child: Text(
                    '${_pauseMinutes ~/ 60 > 0 ? '${_pauseMinutes ~/ 60}h ' : ''}${(_pauseMinutes % 60).toString().padLeft(2, '0')}min',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                        color: AppTheme.blueAccent))),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Column(children: [
                      Text('Heures', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _btnPM(Icons.remove, () => setState(() {
                          if (_pauseMinutes >= 60) _pauseMinutes -= 60;
                        })),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('${_pauseMinutes ~/ 60}h', style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary))),
                        _btnPM(Icons.add, () => setState(() => _pauseMinutes += 60)),
                      ]),
                    ])),
                    Container(width: 1, height: 40, color: AppTheme.bgCardBorder),
                    Expanded(child: Column(children: [
                      Text('Minutes', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _btnPM(Icons.remove, () => setState(() {
                          if (_pauseMinutes % 60 > 0) _pauseMinutes -= 1;
                        })),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('${(_pauseMinutes % 60).toString().padLeft(2, '0')}min',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary))),
                        _btnPM(Icons.add, () => setState(() => _pauseMinutes += 1)),
                      ]),
                    ])),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.free_breakfast_outlined, size: 14, color: AppTheme.colorAmber),
                      const SizedBox(width: 6),
                      Text('Pause déduite : ${Calculs.formatHeures(_pauseMinutes / 60)}',
                          style: TextStyle(fontSize: 12, color: AppTheme.colorAmber,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ],
              ])),
              const SizedBox(height: 10),
            ],

            // ── Panier repas ───────────────────────────────────────
            if (!_jourNonTravaille) ...[
              _sectionCard('Panier repas', Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Inclure un panier repas',
                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  Switch(value: _avecPanier,
                      onChanged: (v) => setState(() => _avecPanier = v)),
                ]),
                if (_avecPanier) ...[
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Montant',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    _compteur(_panierRepasGarde.toStringAsFixed(2),
                      onMoins: () => setState(() {
                        if (_panierRepasGarde >= 0.5) _panierRepasGarde = double.parse(
                            (_panierRepasGarde - 0.5).toStringAsFixed(2));
                      }),
                      onPlus: () => setState(() => _panierRepasGarde = double.parse(
                          (_panierRepasGarde + 0.5).toStringAsFixed(2))),
                      unite: '€',
                    ),
                  ]),
                ],
              ])),
              const SizedBox(height: 10),
            ],

            // ── Rappel (collègue + véhicule) ──────────────────────
            _sectionCard('Rappel', Column(children: [
              TextField(
                controller: _collegueCtrl,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nom du collègue',
                  labelStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  prefixIcon: Icon(Icons.person_outline, size: 18, color: AppTheme.blueAccent),
                  hintText: 'Ex: Jean Dupont',
                  hintStyle: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _vehiculeCtrl,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Véhicule utilisé',
                  labelStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  prefixIcon: Icon(Icons.directions_car_outlined, size: 18,
                      color: AppTheme.blueAccent),
                  hintText: 'Ex: Voiture personnelle, Moto...',
                  hintStyle: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                ),
              ),
              if (widget.kmDomicileTravail > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.blueAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.route_outlined, size: 14, color: AppTheme.blueAccent),
                    const SizedBox(width: 6),
                    Text('${widget.kmDomicileTravail.toStringAsFixed(0)} km domicile-travail',
                        style: TextStyle(fontSize: 11, color: AppTheme.blueAccent)),
                    const Spacer(),
                    Text('(Paramètres)',
                        style: TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
                  ]),
                ),
              ],
            ])),
            const SizedBox(height: 10),

            // ── Achats divers ──────────────────────────────────────
            _sectionCard('Achats divers', Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Frais du jour',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                GestureDetector(
                  onTap: () => _ouvrirAjoutAchat(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.blueAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.blueAccent.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.add, size: 13, color: AppTheme.blueAccent),
                      const SizedBox(width: 3),
                      Text('Ajouter', style: TextStyle(fontSize: 11, color: AppTheme.blueAccent)),
                    ]),
                  ),
                ),
              ]),
              if (_achats.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final a in _achats)
                  GestureDetector(
                    onTap: () => _ouvrirAjoutAchat(achat: a),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Icon(Icons.receipt_outlined, size: 14, color: AppTheme.colorAmber),
                        const SizedBox(width: 8),
                        Expanded(child: Text(a.intitule, style: TextStyle(
                            fontSize: 12, color: AppTheme.textPrimary))),
                        Text('${a.montant.toStringAsFixed(2)} €',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                                color: AppTheme.colorAmber)),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 14, color: AppTheme.textTertiary),
                      ]),
                    ),
                  ),
                Divider(color: AppTheme.bgCardBorder),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary)),
                  Text('${totalAchats.toStringAsFixed(2)} €',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppTheme.colorAmber)),
                ]),
              ] else ...[
                const SizedBox(height: 8),
                Text('Aucun achat — appuyez sur "Ajouter"',
                    style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
              ],
            ])),
            const SizedBox(height: 12),

            // ── Récapitulatif CCN ──────────────────────────────────
            if (!_jourNonTravaille) Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.blueAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.blueAccent.withOpacity(0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Calcul automatique CCN',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: AppTheme.blueAccent)),
                const SizedBox(height: 10),
                _calcRow('Durée effective', Calculs.formatHeures(garde.dureeHeures), null),
                if (_avecPause)
                  _calcRow('Pause déduite',
                      '- ${Calculs.formatHeures(_pauseMinutes / 60)}', null),
                _calcRow('Heures de nuit (21h-6h)', Calculs.formatHeures(heuresNuit),
                    'maj. +${majNuit.toStringAsFixed(2)} €'),
                _calcRow(nomFerie != null ? 'Jour férié ($nomFerie)' : 'Dimanche / férié',
                    estFerieOuDim ? 'Oui' : 'Non',
                    estFerieOuDim ? '+${majDim.toStringAsFixed(2)} €' : null),
                _calcRow('IDAJ (amplitude > 12h)',
                    garde.hasIDAJ
                        ? (garde.amplitudeMinutes / 60 > 13
                            ? '+75% puis +100%'
                            : '+75% du taux')
                        : 'Non',
                    garde.hasIDAJ ? '+${idaj.toStringAsFixed(2)} €' : null),
                if (_avecPanier)
                  _calcRow('Panier repas', '${_panierRepasGarde.toStringAsFixed(2)} €', null),
                Divider(color: AppTheme.bgCardBorder),
                _calcRow('Total brut estimé', '${brut.toStringAsFixed(2)} €', null, isBold: true),
              ]),
            ),

            if (_jourNonTravaille) Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.event_busy, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Jour non travaillé enregistré',
                    style: TextStyle(fontSize: 13, color: Colors.orange,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final g = _buildGarde();
                  if (estModif) { widget.onGardeModifiee!(g); }
                  else { widget.onGardeAjoutee(g); }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(estModif ? 'Garde modifiée !' : 'Garde enregistrée !')));
                },
                child: Text(estModif ? 'Enregistrer les modifications' : 'Enregistrer la garde',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sectionCard(String label, Widget child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: AppTheme.cardDecoration(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      const SizedBox(height: 8), child,
    ]),
  );

  Widget _compteur(String valeur, {required VoidCallback onMoins,
      required VoidCallback onPlus, required String unite}) {
    return Row(children: [
      GestureDetector(onTap: onMoins,
        child: Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: AppTheme.blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.remove, size: 16, color: AppTheme.blueAccent))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('$valeur $unite', style: TextStyle(fontSize: 15,
            fontWeight: FontWeight.w500, color: AppTheme.textPrimary))),
      GestureDetector(onTap: onPlus,
        child: Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: AppTheme.blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.add, size: 16, color: AppTheme.blueAccent))),
    ]);
  }

  Widget _calcRow(String label, String value, String? sub, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12,
              fontWeight: isBold ? FontWeight.w500 : FontWeight.normal,
              color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary)),
          if (sub != null)
            Text(sub, style: const TextStyle(fontSize: 10, color: AppTheme.blueAccent)),
        ]),
        Text(value, style: TextStyle(fontSize: 12,
            fontWeight: isBold ? FontWeight.w500 : FontWeight.normal,
            color: isBold ? AppTheme.colorGreen : AppTheme.blueAccent)),
      ]),
    );
  }
}
