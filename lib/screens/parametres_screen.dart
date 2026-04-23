
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/auth_service.dart';
import '../utils/excel_service.dart';
import '../utils/pdf_service.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/garde.dart';
import '../models/prime.dart';
import '../utils/purchase_service.dart';
import '../utils/storage.dart';
import '../main.dart';

class ParametresScreen extends StatefulWidget {
  final double tauxHoraire;
  final double panierRepas;
  final double indemnitesDimanche;
  final double montantIdaj;
  final DateTime? debutQuatorzaine;
  final List<Garde> gardes;
  final double montantIdajParam;
  final List<PrimeMensuelle> primes;
  final double impotSource;
  final double primeAnnuelleCalculee;
  final double kmDomicileTravail;
  final double congesAcquisAvant;
  final int modeCp;
  final String poste;
  final Function(double, double, double, double, DateTime?,
      List<PrimeMensuelle>, double, double, String, double, int) onParametresModifies;
  final Future<void> Function()? onSignInSuccess;

  const ParametresScreen({
    super.key,
    required this.tauxHoraire,
    required this.panierRepas,
    required this.indemnitesDimanche,
    required this.montantIdaj,
    required this.onParametresModifies,
    required this.gardes,
    required this.montantIdajParam,
    required this.primes,
    required this.impotSource,
    required this.primeAnnuelleCalculee,
    required this.kmDomicileTravail,
    this.congesAcquisAvant = 0,
    this.modeCp = 0,
    required this.poste,
    this.debutQuatorzaine,
    this.onSignInSuccess,
  });

  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  late TextEditingController _tauxCtrl;
  late TextEditingController _panierCtrl;
  late TextEditingController _dimancheCtrl;
  late TextEditingController _idajCtrl;
  late TextEditingController _impotCtrl;
  late TextEditingController _kmCtrl;
  late TextEditingController _congesCtrl;
  late int _modeCp;
  late List<PrimeMensuelle> _primes;
  late String _poste;
  DateTime? _debutQuatorzaine;
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _tauxCtrl    = TextEditingController(text: widget.tauxHoraire.toStringAsFixed(2));
    _panierCtrl  = TextEditingController(text: widget.panierRepas.toStringAsFixed(2));
    _dimancheCtrl = TextEditingController(text: widget.indemnitesDimanche.toStringAsFixed(2));
    _idajCtrl    = TextEditingController(text: widget.montantIdaj.toStringAsFixed(2));
    _impotCtrl   = TextEditingController(text: widget.impotSource.toStringAsFixed(1));
    _kmCtrl = TextEditingController(text: widget.kmDomicileTravail > 0
        ? widget.kmDomicileTravail.toStringAsFixed(0) : '');
    _congesCtrl = TextEditingController(text: widget.congesAcquisAvant > 0
        ? widget.congesAcquisAvant.toStringAsFixed(1) : '');
    _modeCp = widget.modeCp;
    _primes = List.from(widget.primes);
    _poste = widget.poste;
    _debutQuatorzaine = widget.debutQuatorzaine;
    _verifierPro();
  }

  @override
  void dispose() {
    _tauxCtrl.dispose(); _panierCtrl.dispose(); _dimancheCtrl.dispose();
    _idajCtrl.dispose(); _impotCtrl.dispose(); _kmCtrl.dispose(); _congesCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifierPro() async {
    final pro = await PurchaseService.isPro();
    final tester = await Storage.isTesterPro();
    setState(() => _isPro = pro || tester);
  }

  Future<void> _selectDateQuatorzaine() async {
    final picked = await showDatePicker(
      context: context, initialDate: _debutQuatorzaine ?? DateTime.now(),
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
    if (picked != null) setState(() => _debutQuatorzaine = picked);
  }

  double _parse(TextEditingController c, double fallback) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? fallback;

  void _sauvegarder() {
    widget.onParametresModifies(
      _parse(_tauxCtrl, widget.tauxHoraire),
      _parse(_panierCtrl, widget.panierRepas),
      _parse(_dimancheCtrl, widget.indemnitesDimanche),
      _parse(_idajCtrl, widget.montantIdaj),
      _debutQuatorzaine, _primes,
      _parse(_impotCtrl, 0),
      _parse(_kmCtrl, 0),
      _poste,
      _parse(_congesCtrl, 0),
      _modeCp,
    );
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres sauvegardés !')));
  }

  Future<void> _exporterFormat(String format) async {
    // Sélecteur de période
    final now = DateTime.now();
    int moisSel = now.month;
    int anneeSel = now.year;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        title: Text('Exporter en $format'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Choisissez la période :'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: DropdownButton<int>(
              value: moisSel,
              isExpanded: true,
              items: List.generate(12, (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'][i]),
              )),
              onChanged: (v) => setSt(() => moisSel = v!),
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButton<int>(
              value: anneeSel,
              isExpanded: true,
              items: [now.year - 1, now.year, now.year + 1].map((y) =>
                  DropdownMenuItem(value: y, child: Text('$y'))).toList(),
              onChanged: (v) => setSt(() => anneeSel = v!),
            )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Exporter')),
        ],
      )),
    );

    if (ok != true || !mounted) return;

    try {
      if (format == 'PDF') {
        await PdfService.exporterMois(
          gardes: widget.gardes,
          annee: anneeSel,
          mois: moisSel,
          tauxHoraire: widget.tauxHoraire,
          panierRepas: widget.panierRepas,
          indemnitesDimanche: widget.indemnitesDimanche,
          montantIdaj: widget.montantIdaj,
          primes: widget.primes,
          impotSource: widget.impotSource,
        );
      } else if (format == 'Excel') {
        await ExcelService.exporterMois(
          gardes: widget.gardes,
          annee: anneeSel,
          mois: moisSel,
          tauxHoraire: widget.tauxHoraire,
          panierRepas: widget.panierRepas,
          indemnitesDimanche: widget.indemnitesDimanche,
          montantIdaj: widget.montantIdaj,
          primes: widget.primes,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export : $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _importerDonnees() async {
    // Sélection du fichier (JSON, PDF, Excel, Word, etc.)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
      dialogTitle: 'Choisir le fichier de sauvegarde',
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    String? json;
    if (file.bytes != null) {
      json = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      json = await File(file.path!).readAsString();
    }
    if (json == null || json.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier vide ou illisible'), backgroundColor: Colors.red));
      }
      return;
    }

    final resultat = await Storage.importerDonnees(json);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resultat),
        backgroundColor: resultat.startsWith('✓') ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ));
      if (resultat.startsWith('✓')) {
        // Informe l'utilisateur de relancer l'appli
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Importation réussie !'),
              content: const Text('Fermez et relancez l\'application pour voir vos données restaurées.'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
            ),
          );
          }
        });
      }
    }
  }

  void _ouvrirEditeurPrime({PrimeMensuelle? prime}) {
    final nomCtrl = TextEditingController(text: prime?.nom ?? '');
    final montantCtrl = TextEditingController(
        text: prime != null ? prime.montant.toStringAsFixed(2) : '');
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFFF5C4B3),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(prime == null ? 'Nouvelle prime' : 'Modifier la prime',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: Color(0xFF711B0C))),
            if (prime != null)
              GestureDetector(
                onTap: () { Navigator.pop(ctx);
                  setState(() => _primes.removeWhere((p) => p.id == prime.id)); },
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(controller: nomCtrl, autofocus: true,
            style: const TextStyle(color: Color(0xFF4A1B0C)),
            decoration: InputDecoration(
                labelText: 'Nom de la prime',
                labelStyle: const TextStyle(color: Color(0xFF993C1D)),
                hintText: 'Ex: Prime qualité...',
                hintStyle: const TextStyle(color: Color(0xFFD85A30)))),
          const SizedBox(height: 12),
          TextField(controller: montantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Color(0xFF4A1B0C)),
            decoration: InputDecoration(
                labelText: 'Montant mensuel (€)',
                labelStyle: const TextStyle(color: Color(0xFF993C1D)),
                suffixText: '€')),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              final nom = nomCtrl.text.trim();
              if (nom.isEmpty) return;
              final montant = double.tryParse(montantCtrl.text.replaceAll(',', '.')) ?? 0;
              if (prime == null) {
                setState(() => _primes.add(PrimeMensuelle(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    nom: nom, montant: montant)));
              } else {
                setState(() { prime.nom = nom; prime.montant = montant; });
              }
              Navigator.pop(ctx);
            },
            child: Text(prime == null ? 'Ajouter' : 'Mettre à jour',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AmbulancierApp.of(context);
    final totalPrimes = _primes.fold(0.0, (s, p) => s + p.montant);

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Paramètres', style: AppTheme.titleStyle()),
            const SizedBox(height: 16),

            // ── Poste ──────────────────────────────────────────────
            _sectionTitle('Poste'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sélectionnez votre qualification',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _posteChip('ADE', 'Ambulancier Diplômé d\'État', 'dea')),
                  const SizedBox(width: 10),
                  Expanded(child: _posteChip('AUXI', 'Auxiliaire Ambulancier', 'auxiliaire')),
                ]),
              ]),
            ),

            // ── Apparence ──────────────────────────────────────────
            _sectionTitle('Apparence'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mode sombre', style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                  Text(AppTheme.isDark ? 'Thème bleu nuit activé' : 'Thème clair activé',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ]),
                Switch(value: AppTheme.isDark, onChanged: (v) {
                  appState?.toggleTheme(); setState(() {});
                }),
              ]),
            ),

            // ── Mon compte ─────────────────────────────────────────
            _sectionTitle('Mon compte'),
            StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                final user = snapshot.data;
                if (user == null) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: AppTheme.cardDecoration(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        'Connectez-vous pour synchroniser vos données automatiquement sur tous vos appareils.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final cred = await AuthService.signInWithGoogle();
                            if (cred != null) await widget.onSignInSuccess?.call();
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(
                              content: Text('Erreur Google : $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 8),
                            ));
                          }
                        },
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text('Continuer avec Google'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.colorBlue,
                          side: BorderSide(color: AppTheme.colorBlue),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      )),
                      if (!kIsWeb && Platform.isIOS) ...[
                        const SizedBox(height: 8),
                        SizedBox(width: double.infinity, child: ElevatedButton.icon(
                          onPressed: () async {
                            final cred = await AuthService.signInWithApple();
                            if (cred != null) await widget.onSignInSuccess?.call();
                          },
                          icon: const Icon(Icons.apple, size: 20),
                          label: const Text('Continuer avec Apple'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                        )),
                      ],
                    ]),
                  );
                }
                // Connecté
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.cardDecoration(
                      borderColor: AppTheme.colorGreen.withValues(alpha: 0.35)),
                  child: Column(children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: user.photoURL != null
                            ? NetworkImage(user.photoURL!) : null,
                        backgroundColor: AppTheme.blueAccent.withValues(alpha: 0.2),
                        child: user.photoURL == null
                            ? Icon(Icons.person, color: AppTheme.blueAccent) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (user.displayName != null)
                          Text(user.displayName!,
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                        Text(user.email ?? 'Compte connecté',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.colorGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('SYNC ✓',
                            style: TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.colorGreen)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                      onPressed: () async { await AuthService.signOut(); },
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('Se déconnecter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.colorRed,
                        side: BorderSide(color: AppTheme.colorRed),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    )),
                  ]),
                );
              },
            ),

            // ── Version Pro ────────────────────────────────────────
            _sectionTitle('Version Pro'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(
                borderColor: _isPro
                    ? AppTheme.colorGreen.withValues(alpha: 0.4)
                    : AppTheme.colorAmber.withValues(alpha: 0.4)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_isPro ? 'Version Pro activée ✓' : 'Version gratuite',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: _isPro ? AppTheme.colorGreen : AppTheme.textPrimary)),
                  if (_isPro)
                    AppTheme.badge('PRO', AppTheme.colorGreen.withValues(alpha: 0.15), AppTheme.colorGreen),
                ]),
                if (!_isPro) ...[
                  const SizedBox(height: 8),
                  _featurePro('Export PDF illimité'),
                  _featurePro('Graphiques avancés'),
                  _featurePro('Mes Droits — CCN & Code du travail'),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await PurchaseService.acheterPro();
                      if (!mounted) return;
                      if (ok) {
                        setState(() => _isPro = true);
                        messenger.showSnackBar(
                            const SnackBar(content: Text('Version Pro activée !')));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.colorAmber),
                    child: const Text('Passer à la version Pro — 2,99 €',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  )),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await PurchaseService.restaurerAchats();
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(
                          content: Text(ok ? 'Achats restaurés !' : 'Aucun achat trouvé')));
                      if (ok) setState(() => _isPro = true);
                    },
                    child: Center(child: Text('Restaurer mes achats',
                        style: TextStyle(fontSize: 12, color: AppTheme.colorBlue))),
                  ),
                ],
              ]),
            ),

            // ── Quatorzaine ────────────────────────────────────────
            _sectionTitle('Quatorzaine'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Date de début', style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                    Text('Calcul automatique', style: TextStyle(fontSize: 10,
                        color: AppTheme.textSecondary)),
                  ]),
                  GestureDetector(
                    onTap: _selectDateQuatorzaine,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.blueAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppTheme.blueAccent),
                        const SizedBox(width: 6),
                        Text(_debutQuatorzaine == null ? 'Choisir'
                            : '${_debutQuatorzaine!.day}/${_debutQuatorzaine!.month}/${_debutQuatorzaine!.year}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.blueAccent,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ]),
              ]),
            ),

            // ── Rémunération ───────────────────────────────────────
            _sectionTitle('Rémunération'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(),
              child: Column(children: [
                _paramField('Taux horaire brut (€)', 'Base de calcul', _tauxCtrl, '€'),
                _paramField('Panier repas par défaut (€)', 'Modifiable par garde', _panierCtrl, '€'),
                _paramField('Indemnité dim./férié (€)', 'Forfait par jour', _dimancheCtrl, '€'),
                const SizedBox(height: 4),
                Divider(color: AppTheme.bgCardBorder),
                const SizedBox(height: 8),
                _paramField('Km domicile-travail', 'Reporté automatiquement dans chaque garde',
                    _kmCtrl, 'km'),
                _paramField('Congés acquis avant l\'appli',
                    'Jours CP acquis avant de télécharger l\'appli',
                    _congesCtrl, 'j'),
                const SizedBox(height: 12),
                // ── Mode calcul CP ─────────────────────────────────
                Text('Mode de calcul des congés payés',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text('CCN Transports Sanitaires — 2 méthodes',
                    style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
                const SizedBox(height: 8),
                _modeCpSelector(),
              ]),
            ),

            // ── Primes mensuelles ──────────────────────────────────
            _sectionTitle('Primes mensuelles'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: AppTheme.cardDecoration(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Mes primes', style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                      Text('Ajoutées 1×/mois au salaire',
                          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ]),
                    GestureDetector(
                      onTap: () => _ouvrirEditeurPrime(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.blueAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.blueAccent.withValues(alpha: 0.3)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.add, size: 14, color: AppTheme.blueAccent),
                          SizedBox(width: 4),
                          Text('Ajouter', style: TextStyle(fontSize: 11, color: AppTheme.blueAccent)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                if (_primes.isEmpty)
                  Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text('Aucune prime — appuyez sur "Ajouter"',
                        style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)))
                else ...[
                  Divider(height: 1, color: AppTheme.bgCardBorder),
                  for (int i = 0; i < _primes.length; i++) ...[
                    GestureDetector(
                      onTap: () => _ouvrirEditeurPrime(prime: _primes[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Container(padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.star_outline, size: 16, color: Colors.amber)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_primes[i].nom, style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                            Text('mensuelle', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          ])),
                          Text('${_primes[i].montant.toStringAsFixed(2)} €',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                  color: Colors.amber)),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, size: 16, color: AppTheme.textTertiary),
                        ]),
                      ),
                    ),
                    if (i < _primes.length - 1)
                      Divider(height: 1, color: AppTheme.bgCardBorder, indent: 14, endIndent: 14),
                  ],
                  Divider(height: 1, color: AppTheme.bgCardBorder),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Total / mois', style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                      Text('${totalPrimes.toStringAsFixed(2)} €', style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.colorGreen)),
                    ]),
                  ),
                ],
              ]),
            ),

            // ── Prime annuelle calculée ────────────────────────────
            // ── Majorations CCN ────────────────────────────────────
            _sectionTitle('Majorations CCN (auto)'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(),
              child: Column(children: [
                _infoRow('Heures de nuit (21h–6h)', '+25%'),
                _infoRow('Heures supp. (78h → 86h)', '+25%'),
                _infoRow('Heures supp. (au-delà 86h)', '+50%'),
                _infoRow('Dimanche / jour férié', '+25% + forfait'),
              ]),
            ),

            // ── Profil ─────────────────────────────────────────────
            _sectionTitle('Profil'),
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _infoRow('Conv. Coll.', 'CCN Transports sanitaires'),
                _infoRow('Réf. quatorzaine', '78h'),
                _infoRow('Seuil IDAJ', 'Amplitude > 12h'),
                _infoRow('IDAJ 12h-13h', '+75% taux horaire'),
                _infoRow('IDAJ > 13h', '+100% taux horaire'),
                const SizedBox(height: 10),
                Divider(color: AppTheme.bgCardBorder),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.account_balance_outlined, size: 16, color: AppTheme.blueAccent),
                  const SizedBox(width: 8),
                  Text('Impôt prélèvement à la source',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                ]),
                const SizedBox(height: 4),
                Text('Calculé en % du net — déduit 1×/mois',
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _impotCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(hintText: 'Ex: 8.5',
                    hintStyle: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
                    suffixText: '%',
                    helperText: 'Taux de prélèvement à la source',
                    helperStyle: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ]),
            ),

            // ── Sauvegarde / Restauration ──────────────────────────
            _sectionTitle('Sauvegarde des données'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(
                  borderColor: AppTheme.blueAccent.withValues(alpha: 0.3)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.backup_outlined, size: 16, color: AppTheme.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Exportez vos données avant chaque mise à jour',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  )),
                ]),
                const SizedBox(height: 12),
                // Sauvegarde JSON
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try { await Storage.exporterDonnees(widget.gardes); }
                    catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  icon: const Icon(Icons.backup_outlined, size: 16),
                  label: const Text('Sauvegarder (WhatsApp, Drive, Email...)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                )),
                const SizedBox(height: 8),
                Row(children: [
                  // Export PDF
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _exporterFormat('PDF'),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  )),
                  const SizedBox(width: 8),
                  // Export Excel
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => _exporterFormat('Excel'),
                    icon: const Icon(Icons.table_chart_outlined, size: 15),
                    label: const Text('Export Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  )),
                ]),
                const SizedBox(height: 8),
                // Import sauvegarde
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: _importerDonnees,
                  icon: const Icon(Icons.folder_open_outlined, size: 16),
                  label: const Text('Restaurer une sauvegarde'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.blueAccent,
                    side: BorderSide(color: AppTheme.blueAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                )),
              ]),
            ),

            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _sauvegarder,
              child: const Text('Sauvegarder',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _posteChip(String code, String label, String value) {
    final selected = _poste == value;
    return GestureDetector(
      onTap: () => setState(() => _poste = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.blueAccent : AppTheme.blueAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppTheme.blueAccent
              : AppTheme.blueAccent.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Text(code, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.blueAccent)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9,
                  color: selected ? Colors.white.withValues(alpha: 0.85) : AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title.toUpperCase(), style: TextStyle(fontSize: 10,
        fontWeight: FontWeight.w500, color: AppTheme.textTertiary, letterSpacing: 0.8)),
  );

  Widget _modeCpSelector() {
    final modes = [
      {'id': 0, 'label': 'Auto (plus favorable)', 'desc': 'Compare les 2 méthodes et applique la meilleure'},
      {'id': 1, 'label': 'Règle du 1/10', 'desc': '1/10 du brut annuel de la période de référence'},
      {'id': 2, 'label': 'Maintien du salaire', 'desc': 'Salaire moyen journalier × nb jours CP'},
    ];
    return Column(children: modes.map((m) {
      final isSelected = _modeCp == m['id'];
      return GestureDetector(
        onTap: () => setState(() => _modeCp = m['id'] as int),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.blueAccent.withValues(alpha: 0.12)
                : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected
                ? AppTheme.blueAccent
                : AppTheme.bgCardBorder),
          ),
          child: Row(children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.blueAccent : Colors.transparent,
                border: Border.all(color: isSelected
                    ? AppTheme.blueAccent : AppTheme.textTertiary, width: 2),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['label'] as String, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.blueAccent : AppTheme.textPrimary)),
              Text(m['desc'] as String, style: TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
            ])),
          ]),
        ),
      );
    }).toList());
  }

  Widget _paramField(String label, String hint, TextEditingController ctrl, String suffix) {
    return Padding(padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(hint, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        TextField(controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(suffixText: suffix,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
      ]));
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      Flexible(child: Text(value, textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.colorBlue),
          overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _featurePro(String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.check_circle_outline, size: 14, color: AppTheme.colorAmber),
      const SizedBox(width: 6),
      Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
    ]),
  );
}
