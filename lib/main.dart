
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/accueil_screen.dart';
import 'screens/saisie_garde_screen.dart';
import 'screens/salaire_screen.dart';
import 'screens/historique_screen.dart';
import 'screens/parametres_screen.dart';
import 'screens/info_screen.dart';
import 'screens/graphiques_screen.dart';
import 'screens/impots_screen.dart';
import 'models/garde.dart';
import 'models/prime.dart';
import 'utils/calculs.dart';
import 'utils/storage.dart';
import 'utils/purchase_service.dart';
import 'app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PurchaseService.initialiser();
  runApp(const AmbulancierApp());
}

class AmbulancierApp extends StatefulWidget {
  const AmbulancierApp({super.key});
  static _AmbulancierAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_AmbulancierAppState>();
  @override
  State<AmbulancierApp> createState() => _AmbulancierAppState();
}

class _AmbulancierAppState extends State<AmbulancierApp> {
  bool _isDark = true;
  @override
  void initState() { super.initState(); _chargerTheme(); }
  Future<void> _chargerTheme() async {
    final isDark = await Storage.chargerTheme();
    setState(() { _isDark = isDark; AppTheme.isDark = isDark; });
  }
  void toggleTheme() {
    setState(() { _isDark = !_isDark; AppTheme.isDark = _isDark; });
    Storage.sauvegarderTheme(_isDark);
  }
  bool get isDark => _isDark;
  @override
  Widget build(BuildContext context) {
    AppTheme.isDark = _isDark;
    return MaterialApp(
      title: 'Ambu Time',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR')],
      home: const MainPage(),
    );
  }
}

// ── Onglets de navigation ────────────────────────────────────────────────────
const _tabLabels = ['Accueil','Garde','Salaire','Graphiques','Historique','Paramètres','Impôts','Info'];
const _tabColors = [
  Color(0xFFB5D4F4), // bleu pastel
  Color(0xFFC0DD97), // vert pastel
  Color(0xFF9FE1CB), // teal pastel
  Color(0xFFCECBF6), // violet pastel
  Color(0xFFFAC775), // amber pastel
  Color(0xFFF5C4B3), // coral pastel
  Color(0xFFF7C1C1), // rouge pastel
  Color(0xFFD3D1C7), // gris pastel
];
const _tabTextColors = [
  Color(0xFF042C53),
  Color(0xFF173404),
  Color(0xFF04342C),
  Color(0xFF26215C),
  Color(0xFF412402),
  Color(0xFF711B0C),
  Color(0xFF501313),
  Color(0xFF2C2C2A),
];

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _prevIndex = 0;
  double _tauxHoraire = 13.10;
  double _panierRepas = 7.30;
  double _indemnitesDimanche = 26.00;
  double _montantIdaj = 35.00;
  List<PrimeMensuelle> _primes = [];
  double _impotSource = 0;
  double _kmDomicileTravail = 0;
  String _poste = 'dea';
  DateTime? _debutQuatorzaine;
  bool _chargement = true;
  Garde? _gardeAModifier;
  final List<Garde> _gardes = [];

  @override
  void initState() { super.initState(); _chargerDonnees(); }

  Future<void> _chargerDonnees() async {
    final gardes = await Storage.chargerGardes();
    final params = await Storage.chargerParametres();
    setState(() {
      _gardes.addAll(gardes);
      _tauxHoraire = params['taux'] as double;
      _panierRepas = params['panier'] as double;
      _indemnitesDimanche = params['dimanche'] as double;
      _montantIdaj = params['idaj'] as double;
      _debutQuatorzaine = params['debutQuatorzaine'] as DateTime?;
      _primes = params['primes'] as List<PrimeMensuelle>;
      _impotSource = params['impotSource'] as double;
      _kmDomicileTravail = params['kmDomicileTravail'] as double;
      _poste = params['poste'] as String;
      _chargement = false;
    });
  }

  void _ajouterGarde(Garde g) {
    setState(() { _gardes.insert(0, g); _gardeAModifier = null; });
    Storage.sauvegarderGardes(_gardes);
    setState(() => _currentIndex = 0);
  }

  void _modifierGarde(Garde g) {
    setState(() {
      final i = _gardes.indexWhere((e) => e.id == g.id);
      if (i != -1) _gardes[i] = g;
      _gardeAModifier = null;
    });
    Storage.sauvegarderGardes(_gardes);
    setState(() => _currentIndex = 0);
  }

  void _supprimerGarde(String id) {
    setState(() => _gardes.removeWhere((g) => g.id == id));
    Storage.sauvegarderGardes(_gardes);
  }

  void _modifierParametres(double taux, double panier, double dimanche,
      double idaj, DateTime? debutQuatorzaine, List<PrimeMensuelle> primes,
      double impotSource, double kmDomicileTravail, String poste) {
    setState(() {
      _tauxHoraire = taux; _panierRepas = panier;
      _indemnitesDimanche = dimanche; _montantIdaj = idaj;
      _debutQuatorzaine = debutQuatorzaine; _primes = primes;
      _impotSource = impotSource; _kmDomicileTravail = kmDomicileTravail;
      _poste = poste;
    });
    Storage.sauvegarderParametres(
      taux: taux, panier: panier, dimanche: dimanche, idaj: idaj,
      debutQuatorzaine: debutQuatorzaine, primes: primes,
      impotSource: impotSource, kmDomicileTravail: kmDomicileTravail, poste: poste,
    );
  }

  void _ouvrirModification(Garde g) {
    setState(() { _gardeAModifier = g; _currentIndex = 1; });
  }

  void _navigateTo(int index) {
    if (index == _currentIndex) return;
    setState(() { _prevIndex = _currentIndex; _currentIndex = index; });
  }

  List<Garde> get _gardesQuatorzaine {
    if (_debutQuatorzaine == null) return _gardes;
    final fin = _debutQuatorzaine!.add(const Duration(days: 13));
    return _gardes.where((g) =>
        !g.date.isBefore(_debutQuatorzaine!) && !g.date.isAfter(fin)).toList();
  }

  double get _primeAnnuelleCalculee {
    if (_gardes.isEmpty) return 0;
    final Map<String, double> brutParMois = {};
    for (final g in _gardes) {
      final key = '${g.date.year}-${g.date.month.toString().padLeft(2, '0')}';
      brutParMois[key] = (brutParMois[key] ?? 0) +
          Calculs.salaireBrutGarde(g, taux: _tauxHoraire, panier: _panierRepas,
              indDimanche: _indemnitesDimanche, montantIdaj: _montantIdaj);
    }
    if (brutParMois.isEmpty) return 0;
    return brutParMois.values.fold(0.0, (s, v) => s + v) / brutParMois.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return Scaffold(
        backgroundColor: AppTheme.bgPrimary,
        body: Center(child: CircularProgressIndicator(color: AppTheme.blueAccent)),
      );
    }

    final screens = [
      AccueilScreen(
        gardes: _gardes, gardesQuatorzaine: _gardesQuatorzaine,
        tauxHoraire: _tauxHoraire, debutQuatorzaine: _debutQuatorzaine,
        onSupprimerGarde: _supprimerGarde, onModifierGarde: _ouvrirModification,
        poste: _poste,
      ),
      SaisieGardeScreen(
        onGardeAjoutee: _ajouterGarde, onGardeModifiee: _modifierGarde,
        tauxHoraire: _tauxHoraire, panierRepas: _panierRepas,
        indemnitesDimanche: _indemnitesDimanche, montantIdaj: _montantIdaj,
        gardeAModifier: _gardeAModifier, debutQuatorzaine: _debutQuatorzaine,
        kmDomicileTravail: _kmDomicileTravail, poste: _poste,
      ),
      SalaireScreen(
        gardes: _gardes, tauxHoraire: _tauxHoraire, panierRepas: _panierRepas,
        indemnitesDimanche: _indemnitesDimanche, montantIdaj: _montantIdaj,
        primes: _primes, primeAnnuelle: _primeAnnuelleCalculee, impotSource: _impotSource,
      ),
      GraphiquesScreen(
        gardes: _gardes, tauxHoraire: _tauxHoraire, panierRepas: _panierRepas,
        indemnitesDimanche: _indemnitesDimanche, montantIdaj: _montantIdaj,
      ),
      HistoriqueScreen(
        gardes: _gardes, tauxHoraire: _tauxHoraire, panierRepas: _panierRepas,
        indemnitesDimanche: _indemnitesDimanche, montantIdaj: _montantIdaj,
        primes: _primes, impotSource: _impotSource,
        onModifierGarde: _ouvrirModification,
        onSupprimerGarde: _supprimerGarde,
      ),
      ParametresScreen(
        tauxHoraire: _tauxHoraire, panierRepas: _panierRepas,
        indemnitesDimanche: _indemnitesDimanche, montantIdaj: _montantIdaj,
        debutQuatorzaine: _debutQuatorzaine, onParametresModifies: _modifierParametres,
        gardes: _gardes, montantIdajParam: _montantIdaj,
        primes: _primes, impotSource: _impotSource,
        primeAnnuelleCalculee: _primeAnnuelleCalculee,
        kmDomicileTravail: _kmDomicileTravail, poste: _poste,
      ),
      ImpotsScreen(
        gardes: _gardes, tauxHoraire: _tauxHoraire, panierRepas: _panierRepas,
        indemnitesDimanche: _indemnitesDimanche, montantIdaj: _montantIdaj,
        impotSource: _impotSource, primes: _primes,
        primeAnnuelle: _primeAnnuelleCalculee,
        kmDomicileTravail: _kmDomicileTravail,
      ),
      const InfoScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: Row(
          children: [
            // ── Contenu principal ─────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-0.05, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_currentIndex),
                  child: screens[_currentIndex],
                ),
              ),
            ),
            // ── Onglets latéraux droits ───────────────────────────────
            _LateralNav(
              currentIndex: _currentIndex,
              onTap: _navigateTo,
            ),
          ],
        ),
      ),
    );
  }
}

class _LateralNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  const _LateralNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary,
        border: Border(left: BorderSide(color: AppTheme.bgCardBorder, width: 0.5)),
      ),
      child: Column(
        children: List.generate(_tabLabels.length, (i) {
          final isActive = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isActive
                      ? _tabColors[i]
                      : _tabColors[i].withOpacity(AppTheme.isDark ? 0.55 : 0.35),
                  border: Border(
                    top: i == 0
                        ? BorderSide.none
                        : BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5),
                    left: isActive
                        ? BorderSide(color: _tabTextColors[i], width: 2.5)
                        : BorderSide.none,
                  ),
                ),
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      _tabLabels[i],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                        color: isActive
                            ? _tabTextColors[i]
                            : AppTheme.isDark
                                ? Colors.white.withOpacity(0.9)
                                : _tabTextColors[i].withOpacity(0.85),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
