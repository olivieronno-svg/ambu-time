import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/garde.dart';
import '../models/prime.dart';

class Storage {
  static const _gardesKey = 'gardes';
  static const _tauxKey = 'taux_horaire';
  static const _panierKey = 'panier_repas';
  static const _dimancheKey = 'indemnites_dimanche';
  static const _idajKey = 'montant_idaj';
  static const _quatorzaineKey = 'debut_quatorzaine';
  static const _themeKey = 'is_dark';
  static const _primesKey = 'primes_mensuelles';
  static const _impotSourceKey = 'impot_source';
  static const _rappelCollegueKey = 'rappel_collegue';
  static const _rappelDistanceKey = 'rappel_distance';
  static const _testerProKey = 'tester_pro_unlocked';
  static const _kmDomicileKey = 'km_domicile_travail';
  static const _posteKey = 'poste';
  static const _congesAcquisKey = 'conges_acquis_avant';
  static const _modeCpKey = 'mode_calcul_cp';

  static Future<void> sauvegarderGardes(List<Garde> gardes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _gardesKey, gardes.map((g) => jsonEncode(g.toMap())).toList());
  }

  static Future<List<Garde>> chargerGardes() async {
    final prefs = await SharedPreferences.getInstance();
    final liste = prefs.getStringList(_gardesKey) ?? [];
    return liste.map((s) => Garde.fromMap(jsonDecode(s))).toList();
  }

  static Future<void> sauvegarderParametres({
    required double taux,
    required double panier,
    required double dimanche,
    required double idaj,
    DateTime? debutQuatorzaine,
    List<PrimeMensuelle> primes = const [],
    double impotSource = 0,
    double kmDomicileTravail = 0,
    String poste = 'dea',
    double congesAcquisAvant = 0,
    int modeCp = 0, // 0=auto, 1=dixième, 2=maintien
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_tauxKey, taux);
    await prefs.setDouble(_panierKey, panier);
    await prefs.setDouble(_dimancheKey, dimanche);
    await prefs.setDouble(_idajKey, idaj);
    await prefs.setDouble(_impotSourceKey, impotSource);
    await prefs.setDouble(_kmDomicileKey, kmDomicileTravail);
    await prefs.setString(_posteKey, poste);
    await prefs.setDouble(_congesAcquisKey, congesAcquisAvant);
    await prefs.setInt(_modeCpKey, modeCp);
    await prefs.setStringList(
        _primesKey, primes.map((p) => jsonEncode(p.toMap())).toList());
    if (debutQuatorzaine != null) {
      await prefs.setString(_quatorzaineKey, debutQuatorzaine.toIso8601String());
    } else {
      await prefs.remove(_quatorzaineKey);
    }
  }

  static Future<Map<String, dynamic>> chargerParametres() async {
    final prefs = await SharedPreferences.getInstance();
    final quatStr = prefs.getString(_quatorzaineKey);
    final primesRaw = prefs.getStringList(_primesKey) ?? [];
    return {
      'taux': prefs.getDouble(_tauxKey) ?? 13.10,
      'panier': prefs.getDouble(_panierKey) ?? 7.30,
      'dimanche': prefs.getDouble(_dimancheKey) ?? 26.00,
      'idaj': prefs.getDouble(_idajKey) ?? 35.00,
      'debutQuatorzaine': quatStr != null ? DateTime.parse(quatStr) : null,
      'primes': primesRaw.map((s) => PrimeMensuelle.fromMap(jsonDecode(s))).toList(),
      'impotSource': prefs.getDouble(_impotSourceKey) ?? 0.0,
      'kmDomicileTravail': prefs.getDouble(_kmDomicileKey) ?? 0.0,
      'poste': prefs.getString(_posteKey) ?? 'dea',
      'congesAcquisAvant': prefs.getDouble(_congesAcquisKey) ?? 0.0,
      'modeCp': prefs.getInt(_modeCpKey) ?? 0,
    };
  }

  static Future<void> sauvegarderRappel({required String collegue, required double distance}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rappelCollegueKey, collegue);
    await prefs.setDouble(_rappelDistanceKey, distance);
  }

  static Future<Map<String, dynamic>> chargerRappel() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'collegue': prefs.getString(_rappelCollegueKey) ?? '',
      'distance': prefs.getDouble(_rappelDistanceKey) ?? 0.0,
    };
  }

  static Future<void> activerModeTester() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testerProKey, true);
  }

  // ── EXPORT / IMPORT JSON ─────────────────────────────────────────
  static Future<void> exporterDonnees(List<Garde> gardes) async {
    final params = await chargerParametres();
    final data = {
      'version': 2,
      'exportDate': DateTime.now().toIso8601String(),
      'gardes': gardes.map((g) => g.toMap()).toList(),
      'parametres': {
        'taux': params['taux'],
        'panier': params['panier'],
        'dimanche': params['dimanche'],
        'idaj': params['idaj'],
        'debutQuatorzaine': (params['debutQuatorzaine'] as DateTime?)?.toIso8601String(),
        'primes': (params['primes'] as List<PrimeMensuelle>).map((p) => p.toMap()).toList(),
        'impotSource': params['impotSource'],
        'kmDomicileTravail': params['kmDomicileTravail'],
        'poste': params['poste'],
        'congesAcquisAvant': params['congesAcquisAvant'],
        'modeCp': params['modeCp'],
      },
    };
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final nomFichier = 'ambutime_${now.day}-${now.month}-${now.year}.json';
    final file = File('${dir.path}/$nomFichier');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)],
        text: 'Sauvegarde Ambu Time — $nomFichier');
  }

  static Future<String> importerDonnees(String jsonContent) async {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      // Restaure les gardes
      final gardesRaw = data['gardes'] as List<dynamic>? ?? [];
      final gardes = gardesRaw
          .map((g) => Garde.fromMap(Map<String, dynamic>.from(g)))
          .toList();
      await prefs.setStringList(
          _gardesKey, gardes.map((g) => jsonEncode(g.toMap())).toList());

      // Restaure les paramètres
      final p = data['parametres'] as Map<String, dynamic>? ?? {};
      if (p['taux'] != null) await prefs.setDouble(_tauxKey, (p['taux'] as num).toDouble());
      if (p['panier'] != null) await prefs.setDouble(_panierKey, (p['panier'] as num).toDouble());
      if (p['dimanche'] != null) await prefs.setDouble(_dimancheKey, (p['dimanche'] as num).toDouble());
      if (p['idaj'] != null) await prefs.setDouble(_idajKey, (p['idaj'] as num).toDouble());
      if (p['impotSource'] != null) await prefs.setDouble(_impotSourceKey, (p['impotSource'] as num).toDouble());
      if (p['kmDomicileTravail'] != null) await prefs.setDouble(_kmDomicileKey, (p['kmDomicileTravail'] as num).toDouble());
      if (p['poste'] != null) await prefs.setString(_posteKey, p['poste'] as String);
      if (p['congesAcquisAvant'] != null) await prefs.setDouble(_congesAcquisKey, (p['congesAcquisAvant'] as num).toDouble());
      if (p['modeCp'] != null) await prefs.setInt(_modeCpKey, p['modeCp'] as int);
      if (p['debutQuatorzaine'] != null) await prefs.setString(_quatorzaineKey, p['debutQuatorzaine'] as String);
      if (p['primes'] != null) {
        final primesRaw = p['primes'] as List<dynamic>;
        await prefs.setStringList(_primesKey, primesRaw.map((x) => jsonEncode(x)).toList());
      }

      return '✓ ${gardes.length} gardes restaurées avec succès';
    } catch (e) {
      return '❌ Fichier invalide : $e';
    }
  }

  static Future<bool> isTesterPro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_testerProKey) ?? false;
  }

  static Future<void> sauvegarderTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  static Future<bool> chargerTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? true;
  }
}

