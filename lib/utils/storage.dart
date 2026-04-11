
import 'dart:convert';
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_tauxKey, taux);
    await prefs.setDouble(_panierKey, panier);
    await prefs.setDouble(_dimancheKey, dimanche);
    await prefs.setDouble(_idajKey, idaj);
    await prefs.setDouble(_impotSourceKey, impotSource);
    await prefs.setDouble(_kmDomicileKey, kmDomicileTravail);
    await prefs.setString(_posteKey, poste);
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
