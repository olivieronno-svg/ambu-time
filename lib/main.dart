import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/ad_service.dart';
import 'utils/cloud_sync_service.dart';
import 'firebase_options.dart';
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
  // Edge-to-edge requis par Android 15+ : le contenu peut s'afficher derriere
  // status bar et navigation bar. Scaffold/SafeArea gerent le clipping.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PurchaseService.initialiser();
  if (Platform.isIOS) {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await Future.delayed(const Duration(milliseconds: 500));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  }
  runApp(const AmbulancierApp());
}

class AmbulancierApp extends StatefulWidget {
  const AmbulancierApp({super.key});
  // ignore: library_private_types_in_public_api
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
  double _tauxHoraire = 13.10;
  double _panierRepas = 7.30;
  double _indemnitesDimanche = 26.00;
  double _montantIdaj = 35.00;
  List<PrimeMensuelle> _primes = [];
  double _impotSource = 0;
  double _kmDomicileTravail = 0;
  String _poste = 'dea';
  double _congesAcquisAvant = 0;
  int _modeCp = 0;
  double _brutPeriodeRef = 0;
  bool _primeAnnuelleActivee = true;
  DateTime? _debutQuatorzaine;
  bool _chargement = true;
  bool _isPro = false;
  int? _compteurNavigation = 0;
  Garde? _gardeAModifier;
  final List<Garde> _gardes = [];
  StreamSubscription<User?>? _authSub;
  String? _dernierUid;
  bool _syncHorsLigne = false; // évite les snackbars en rafale quand offline

  void Function(CustomerInfo)? _customerInfoListener;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
    _chargerStatutPro();
    AdService.initialiser();
    _dernierUid = FirebaseAuth.instance.currentUser?.uid;
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChange);

    // RevenueCat notifie l'app a chaque changement d'abonnement (achat,
    // expiration, restauration). Source unique de verite pour _isPro.
    _customerInfoListener = (info) {
      if (!mounted) return;
      final pro = info.entitlements.active.containsKey(PurchaseService.entitlementId);
      if (pro != _isPro) {
        setState(() {
          _isPro = pro;
          if (pro) _compteurNavigation = 0;
        });
        if (_isPro) {
          AdService.disposerInterstitielle();
        } else {
          AdService.chargerInterstitielle();
        }
      }
    };
    Purchases.addCustomerInfoUpdateListener(_customerInfoListener!);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    if (_customerInfoListener != null) {
      Purchases.removeCustomerInfoUpdateListener(_customerInfoListener!);
    }
    super.dispose();
  }

  Future<void> _onAuthChange(User? user) async {
    final nouvelUid = user?.uid;
    // Purge des données locales dès que l'uid change vers un autre ou vers null.
    // Cela couvre : sign-out (A → null), switch de compte sans sign-out (A → B),
    // et préserve l'état quand Firebase re-émet le même user (A → A, démarrage).
    final uidChange = _dernierUid != null && _dernierUid != nouvelUid;
    if (uidChange) {
      await Storage.effacerDonneesUtilisateur();
      if (!mounted) {
        _dernierUid = nouvelUid;
        return;
      }
      _invaliderCacheQuatorzaine();
      setState(() {
        _gardes.clear();
        _tauxHoraire = 13.10;
        _panierRepas = 7.30;
        _indemnitesDimanche = 26.00;
        _montantIdaj = 35.00;
        _primes = [];
        _impotSource = 0;
        _kmDomicileTravail = 0;
        _poste = 'dea';
        _congesAcquisAvant = 0;
        _modeCp = 0;
        _brutPeriodeRef = 0;
        _debutQuatorzaine = null;
        _gardeAModifier = null;
        _currentIndex = 0;
      });
      // _isPro n'est PAS reset : RevenueCat est lie au compte Google Play (pas
      // au compte Firebase), donc l'abonnement reste actif au switch Firebase.
      // Le listener Purchases.addCustomerInfoUpdateListener corrigera si besoin.
      _chargerStatutPro();
    }
    _dernierUid = nouvelUid;
  }

  Future<void> _chargerStatutPro() async {
    final pro = await PurchaseService.isPro();
    final tester = await Storage.isTesterPro();
    if (!mounted) return;
    setState(() => _isPro = pro || tester);
    if (!_isPro) AdService.chargerInterstitielle();
  }

  // Bascule _isPro a true des le retour de PurchaseService.acheterPro
  // (achat / restauration deja confirme par RevenueCat). Pas de re-check
  // _chargerStatutPro ensuite : pour les testeurs de licence Google Play,
  // getCustomerInfo retourne false (entitlement sandbox non persiste) et
  // ecraserait _isPro juste apres l'avoir mis a true. Le listener
  // Purchases.addCustomerInfoUpdateListener corrigera si l'entitlement
  // change plus tard (expiration, annulation).
  Future<void> _onAchatProSucces() async {
    if (!mounted) return;
    setState(() {
      _isPro = true;
      _compteurNavigation = 0;
    });
    AdService.disposerInterstitielle();
    // Persistance locale pour les testeurs de licence Google Play : leur
    // entitlement RevenueCat n'est pas garanti entre sessions (sandbox).
    // Pour un vrai client, RevenueCat suffit ; ce flag est juste belt &
    // suspenders. Le listener Purchases corrigera si l'entitlement expire.
    await Storage.setTesterPro(true);
  }

  Future<void> _chargerDonnees() async {
    try {
      final gardes = await Storage.chargerGardes();
      final params = await Storage.chargerParametres();
      if (!mounted) return;

      final tauxLu = (params['taux'] as num?)?.toDouble() ?? _tauxHoraire;
      final panierLu = (params['panier'] as num?)?.toDouble() ?? _panierRepas;
      final dimancheLu = (params['dimanche'] as num?)?.toDouble() ?? _indemnitesDimanche;
      final idajLu = (params['idaj'] as num?)?.toDouble() ?? _montantIdaj;

      // ── Migration : fige les paramètres historiques sur les gardes sans snapshot ──
      // Au 1er chargement après mise à jour, les anciennes gardes n'ont pas de
      // tauxHoraireUtilise. On les remplit avec les valeurs courantes pour que
      // tout changement futur n'affecte plus leur calcul.
      final gardesMigrees = gardes.map((g) {
        // Migre si au moins un champ snapshot manque (copyWithSnapshot
        // préserve les existants grâce au `??`, ne complète que les nulls).
        if (g.tauxHoraireUtilise == null ||
            g.panierRepasUtilise == null ||
            g.indemnitesDimancheUtilise == null ||
            g.montantIdajUtilise == null) {
          return g.copyWithSnapshot(
            tauxHoraire: tauxLu,
            panierRepas: panierLu,
            indemnitesDimanche: dimancheLu,
            montantIdaj: idajLu,
          );
        }
        return g;
      }).toList();

      final besoinSauvegarde = gardesMigrees.any((g) =>
          g.tauxHoraireUtilise != null &&
          gardes.firstWhere((og) => og.id == g.id).tauxHoraireUtilise == null);

      _invaliderCacheQuatorzaine();
      setState(() {
        _gardes.addAll(gardesMigrees);
        _tauxHoraire = tauxLu;
        _panierRepas = panierLu;
        _indemnitesDimanche = dimancheLu;
        _montantIdaj = idajLu;
        _debutQuatorzaine = params['debutQuatorzaine'] as DateTime?;
        _primes = params['primes'] as List<PrimeMensuelle>? ?? _primes;
        _impotSource = (params['impotSource'] as num?)?.toDouble() ?? _impotSource;
        _kmDomicileTravail = (params['kmDomicileTravail'] as num?)?.toDouble() ?? _kmDomicileTravail;
        _poste = params['poste'] as String? ?? _poste;
        _congesAcquisAvant = (params['congesAcquisAvant'] as num?)?.toDouble() ?? 0.0;
        _modeCp = params['modeCp'] as int? ?? 0;
        _brutPeriodeRef = (params['brutPeriodeRef'] as num?)?.toDouble() ?? 0.0;
        _primeAnnuelleActivee = params['primeAnnuelleActivee'] as bool? ?? true;
        _chargement = false;
      });

      if (besoinSauvegarde) {
        // Fire-and-forget : le UI est déjà affiché, pas besoin d'attendre.
        unawaited(Storage.sauvegarderGardes(_gardes));
      }
    } catch (e, stack) {
      debugPrint('Erreur chargement données : $e\n$stack');
      if (!mounted) return;
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur au chargement des données. Certaines gardes peuvent être manquantes.'),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _ajouterGarde(Garde g) async {
    _invaliderCacheQuatorzaine();
    setState(() { _gardes.insert(0, g); _gardeAModifier = null; });
    await Storage.sauvegarderGardes(_gardes);
    _syncToCloud();
    if (mounted) setState(() => _currentIndex = 0);
  }

  Future<void> _modifierGarde(Garde g) async {
    _invaliderCacheQuatorzaine();
    setState(() {
      final i = _gardes.indexWhere((e) => e.id == g.id);
      if (i != -1) _gardes[i] = g;
      _gardeAModifier = null;
    });
    await Storage.sauvegarderGardes(_gardes);
    _syncToCloud();
    if (mounted) setState(() => _currentIndex = 0);
  }

  Future<void> _supprimerGarde(String id) async {
    _invaliderCacheQuatorzaine();
    setState(() => _gardes.removeWhere((g) => g.id == id));
    await Storage.sauvegarderGardes(_gardes);
    _syncToCloud();
  }

  Future<void> _modifierParametres(double taux, double panier, double dimanche,
      double idaj, DateTime? debutQuatorzaine, List<PrimeMensuelle> primes,
      double impotSource, double kmDomicileTravail, String poste,
      [double congesAcquisAvant = 0, int modeCp = 0, double brutPeriodeRef = 0]) async {
    _invaliderCacheQuatorzaine();
    setState(() {
      _tauxHoraire = taux; _panierRepas = panier;
      _indemnitesDimanche = dimanche; _montantIdaj = idaj;
      _debutQuatorzaine = debutQuatorzaine; _primes = primes;
      _impotSource = impotSource; _kmDomicileTravail = kmDomicileTravail;
      _poste = poste; _congesAcquisAvant = congesAcquisAvant;
      _modeCp = modeCp; _brutPeriodeRef = brutPeriodeRef;
    });
    await Storage.sauvegarderParametres(
      taux: taux, panier: panier, dimanche: dimanche, idaj: idaj,
      debutQuatorzaine: debutQuatorzaine, primes: primes,
      impotSource: impotSource, kmDomicileTravail: kmDomicileTravail,
      poste: poste, congesAcquisAvant: congesAcquisAvant, modeCp: modeCp,
      brutPeriodeRef: brutPeriodeRef,
    );
    _syncToCloud();
  }

  // ── Cloud sync ────────────────────────────────────────────────────────────

  void _syncToCloud() {
    // Ne notifie que si l'utilisateur est connecté — sinon c'est normal que
    // le sync soit no-op (retourne false).
    if (FirebaseAuth.instance.currentUser == null) return;
    SharedPreferences.getInstance().then((prefs) {
      final planningRaw = prefs.getStringList('app_planning_v1') ?? [];
      final planningMaps = planningRaw
          .map((s) => Map<String, dynamic>.from(jsonDecode(s) as Map))
          .toList();
      return CloudSyncService.syncToCloud(
        gardes: _gardes,
        params: {
          'taux': _tauxHoraire, 'panier': _panierRepas,
          'dimanche': _indemnitesDimanche, 'idaj': _montantIdaj,
          'debutQuatorzaine': _debutQuatorzaine,
          'primes': _primes, 'impotSource': _impotSource,
          'kmDomicileTravail': _kmDomicileTravail, 'poste': _poste,
          'congesAcquisAvant': _congesAcquisAvant, 'modeCp': _modeCp,
          'brutPeriodeRef': _brutPeriodeRef,
        },
        planningMaps: planningMaps,
      );
    }).then((ok) {
      if (!mounted) return;
      if (ok == true && _syncHorsLigne) {
        // Reconnecté — informe l'utilisateur
        _syncHorsLigne = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Synchronisation rétablie'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      } else if (ok == false && !_syncHorsLigne) {
        // Premier échec depuis la dernière réussite → notifie une fois
        _syncHorsLigne = true;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('⚠ Synchronisation cloud échouée — données en local uniquement'),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 4),
        ));
      }
    }).catchError((e, st) {
      debugPrint('Sync cloud échouée : $e');
    });
  }

  Future<void> _onSignInSuccess() async {
    final hasCloud = await CloudSyncService.hasCloudData();
    if (!hasCloud) { _syncToCloud(); return; }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    // Si les données locales sont vides, on restaure automatiquement depuis le cloud
    // sans demander, pour éviter d'écraser le cloud avec un état vide.
    if (_gardes.isEmpty) {
      await _restaurerDepuisCloud(messenger);
      return;
    }

    if (!mounted) return;
    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: Text('Données cloud trouvées',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Text(
          'Des données existent dans le cloud pour ce compte.\n\n'
          'Voulez-vous restaurer vos données depuis le cloud ou '
          'conserver les données locales actuelles ?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Conserver local'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blueAccent),
            child: const Text('Restaurer cloud', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (restore == true) {
      await _restaurerDepuisCloud(messenger);
    } else {
      _syncToCloud();
    }
  }

  Future<void> _restaurerDepuisCloud(ScaffoldMessengerState messenger) async {
    final data = await CloudSyncService.fetchFromCloud();
    if (!mounted) return;
    if (data == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('❌ Échec de la restauration — impossible d\'accéder au cloud'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ));
      return;
    }

    final gardesRaw = (data['gardes'] as List<dynamic>? ?? []);
    final gardes = gardesRaw
        .map((m) => Garde.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();

    final p = data['parametres'] as Map<String, dynamic>? ?? {};
    final primesRaw = p['primes'] as List<dynamic>? ?? [];
    final primes = primesRaw
        .map((m) => PrimeMensuelle.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
    final debutStr = p['debutQuatorzaine'] as String?;
    final debutQuatorzaine = debutStr != null ? DateTime.tryParse(debutStr) : null;

    // Restaure le planning dans SharedPreferences en ne gardant que les
    // entrées qui sont bien des Maps. Évite de réécrire du JSON corrompu
    // qui ferait échouer le chargement dans AccueilScreen.
    final planningRaw = (data['planning'] as List<dynamic>? ?? []);
    final planningValide = <String>[];
    for (final m in planningRaw) {
      if (m is Map) {
        try {
          planningValide.add(jsonEncode(Map<String, dynamic>.from(m)));
        } catch (e) {
          debugPrint('Planning cloud item ignoré : $e');
        }
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('app_planning_v1', planningValide);

    // Persiste localement
    await Storage.sauvegarderGardes(gardes);
    await Storage.sauvegarderParametres(
      taux: (p['taux'] as num?)?.toDouble() ?? _tauxHoraire,
      panier: (p['panier'] as num?)?.toDouble() ?? _panierRepas,
      dimanche: (p['dimanche'] as num?)?.toDouble() ?? _indemnitesDimanche,
      idaj: (p['idaj'] as num?)?.toDouble() ?? _montantIdaj,
      debutQuatorzaine: debutQuatorzaine,
      primes: primes,
      impotSource: (p['impotSource'] as num?)?.toDouble() ?? _impotSource,
      kmDomicileTravail: (p['kmDomicileTravail'] as num?)?.toDouble() ?? _kmDomicileTravail,
      poste: p['poste'] as String? ?? _poste,
      congesAcquisAvant: (p['congesAcquisAvant'] as num?)?.toDouble() ?? _congesAcquisAvant,
      modeCp: p['modeCp'] as int? ?? _modeCp,
      brutPeriodeRef: (p['brutPeriodeRef'] as num?)?.toDouble() ?? _brutPeriodeRef,
    );

    if (!mounted) return;
    _invaliderCacheQuatorzaine();
    setState(() {
      _gardes..clear()..addAll(gardes);
      _tauxHoraire = (p['taux'] as num?)?.toDouble() ?? _tauxHoraire;
      _panierRepas = (p['panier'] as num?)?.toDouble() ?? _panierRepas;
      _indemnitesDimanche = (p['dimanche'] as num?)?.toDouble() ?? _indemnitesDimanche;
      _montantIdaj = (p['idaj'] as num?)?.toDouble() ?? _montantIdaj;
      _debutQuatorzaine = debutQuatorzaine;
      _primes = primes;
      _impotSource = (p['impotSource'] as num?)?.toDouble() ?? _impotSource;
      _kmDomicileTravail = (p['kmDomicileTravail'] as num?)?.toDouble() ?? _kmDomicileTravail;
      _poste = p['poste'] as String? ?? _poste;
      _congesAcquisAvant = (p['congesAcquisAvant'] as num?)?.toDouble() ?? _congesAcquisAvant;
      _modeCp = p['modeCp'] as int? ?? _modeCp;
      _brutPeriodeRef = (p['brutPeriodeRef'] as num?)?.toDouble() ?? _brutPeriodeRef;
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('✓ Données restaurées depuis le cloud')),
    );
  }

  void _ouvrirModification(Garde g) {
    setState(() { _gardeAModifier = g; _currentIndex = 1; });
  }

  void _navigateTo(int index) {
    if (index == _currentIndex) return;
    if (!_isPro) {
      _compteurNavigation = (_compteurNavigation ?? 0) + 1;
      if (_compteurNavigation! >= 3) {
        AdService.afficherInterstitielle(isPro: _isPro);
        _compteurNavigation = 0;
      }
    }
    setState(() => _currentIndex = index);
  }

  // Cache du filtrage quatorzaine — invalidé par _invaliderCacheQuatorzaine()
  List<Garde>? _gardesQuatorzaineCache;

  void _invaliderCacheQuatorzaine() {
    _gardesQuatorzaineCache = null;
  }

  List<Garde> get _gardesQuatorzaine {
    if (_gardesQuatorzaineCache != null) return _gardesQuatorzaineCache!;
    if (_debutQuatorzaine == null) {
      _gardesQuatorzaineCache = _gardes;
      return _gardes;
    }
    final fin = _debutQuatorzaine!.add(const Duration(days: 13));
    final result = _gardes.where((g) =>
        !g.date.isBefore(_debutQuatorzaine!) && !g.date.isAfter(fin)).toList();
    _gardesQuatorzaineCache = result;
    return result;
  }

  /// Valeur effective de la prime annuelle :
  /// - 0 si l'utilisateur l'a désactivée
  /// - sinon la moyenne mensuelle calculée
  double get _primeAnnuelleEffective =>
      _primeAnnuelleActivee ? _primeAnnuelleCalculee : 0.0;

  Future<void> _togglePrimeAnnuelle(bool activee) async {
    setState(() => _primeAnnuelleActivee = activee);
    // Persiste tous les paramètres avec la nouvelle valeur
    await Storage.sauvegarderParametres(
      taux: _tauxHoraire, panier: _panierRepas,
      dimanche: _indemnitesDimanche, idaj: _montantIdaj,
      debutQuatorzaine: _debutQuatorzaine, primes: _primes,
      impotSource: _impotSource, kmDomicileTravail: _kmDomicileTravail,
      poste: _poste, congesAcquisAvant: _congesAcquisAvant, modeCp: _modeCp,
      brutPeriodeRef: _brutPeriodeRef,
      primeAnnuelleActivee: _primeAnnuelleActivee,
    );
    _syncToCloud();
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
        onSupprimerGardeId: _supprimerGarde,
        toutesGardes: _gardes,
      ),
      SalaireScreen(
        gardes: _gardes, tauxHoraire: _tauxHoraire, panierRepas: _panierRepas,
        indemnitesDimanche: _indemnitesDimanche, montantIdaj: _montantIdaj,
        primes: _primes, primeAnnuelle: _primeAnnuelleEffective,
        impotSource: _impotSource, congesAcquisAvant: _congesAcquisAvant,
        modeCp: _modeCp, debutQuatorzaine: _debutQuatorzaine,
        brutPeriodeRef: _brutPeriodeRef,
        primeAnnuelleActivee: _primeAnnuelleActivee,
        primeAnnuelleAuto: _primeAnnuelleCalculee,
        onPrimeAnnuelleToggle: _togglePrimeAnnuelle,
      ),
      GraphiquesScreen(
        gardes: _gardes, tauxHoraire: _tauxHoraire, panierRepas: _panierRepas,
        indemnitesDimanche: _indemnitesDimanche, montantIdaj: _montantIdaj,
        primes: _primes, primeAnnuelle: _primeAnnuelleEffective,
        brutPeriodeRef: _brutPeriodeRef,
      ),
      HistoriqueScreen(
        gardes: _gardes, tauxHoraire: _tauxHoraire, panierRepas: _panierRepas,
        indemnitesDimanche: _indemnitesDimanche, montantIdaj: _montantIdaj,
        primes: _primes, impotSource: _impotSource,
        primeAnnuelle: _primeAnnuelleEffective,
        brutPeriodeRef: _brutPeriodeRef,
        onModifierGarde: _ouvrirModification,
        onSupprimerGarde: _supprimerGarde,
        isPro: _isPro,
      ),
      ParametresScreen(
        tauxHoraire: _tauxHoraire, panierRepas: _panierRepas,
        indemnitesDimanche: _indemnitesDimanche, montantIdaj: _montantIdaj,
        debutQuatorzaine: _debutQuatorzaine, onParametresModifies: _modifierParametres,
        gardes: _gardes, montantIdajParam: _montantIdaj,
        primes: _primes, impotSource: _impotSource,
        primeAnnuelleCalculee: _primeAnnuelleEffective,
        kmDomicileTravail: _kmDomicileTravail, poste: _poste,
        congesAcquisAvant: _congesAcquisAvant, modeCp: _modeCp,
        brutPeriodeRef: _brutPeriodeRef,
        onSignInSuccess: _onSignInSuccess,
        isPro: _isPro,
        onPurchaseSuccess: _onAchatProSucces,
      ),
      ImpotsScreen(
        gardes: _gardes, tauxHoraire: _tauxHoraire, panierRepas: _panierRepas,
        indemnitesDimanche: _indemnitesDimanche, montantIdaj: _montantIdaj,
        impotSource: _impotSource, primes: _primes,
        primeAnnuelle: _primeAnnuelleEffective,
        kmDomicileTravail: _kmDomicileTravail,
        isPro: _isPro,
      ),
      InfoScreen(isPro: _isPro),
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
                      : _tabColors[i].withValues(alpha: AppTheme.isDark ? 0.55 : 0.35),
                  border: Border(
                    top: i == 0
                        ? BorderSide.none
                        : BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
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
                                ? Colors.white.withValues(alpha: 0.9)
                                : _tabTextColors[i].withValues(alpha: 0.85),
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
