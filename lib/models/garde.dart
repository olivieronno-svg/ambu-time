
import 'achat.dart';

class Garde {
  final String id;
  final DateTime date;
  final DateTime heureDebut;
  final DateTime heureFin;
  final bool jourNonTravaille;
  final String? collegue;
  final String? vehiculeUtilise;
  final double kmDomicileTravail;
  final List<Achat> achats;
  final int pauseMinutes;
  final double panierRepasGarde;
  final bool avecPanier;
  final DateTime? debutQuatorzaine;
  final String qualification;
  final bool isCongesPaies;
  final DateTime? cpDateFin;
  final int nbJoursCP;
  final double primeLongueDistance;

  // Snapshot des paramètres en vigueur au moment de la saisie.
  // Nullable pour rétrocompat avec les anciennes gardes.
  final double? tauxHoraireUtilise;
  final double? panierRepasUtilise;
  final double? indemnitesDimancheUtilise;
  final double? montantIdajUtilise;

  Garde({
    required this.id,
    required this.date,
    required this.heureDebut,
    required this.heureFin,
    this.jourNonTravaille = false,
    this.collegue,
    this.vehiculeUtilise,
    this.kmDomicileTravail = 0,
    this.achats = const [],
    this.pauseMinutes = 0,
    this.panierRepasGarde = 0,
    this.avecPanier = true,
    this.debutQuatorzaine,
    this.qualification = 'dea',
    this.isCongesPaies = false,
    this.cpDateFin,
    this.nbJoursCP = 1,
    this.primeLongueDistance = 0,
    this.tauxHoraireUtilise,
    this.panierRepasUtilise,
    this.indemnitesDimancheUtilise,
    this.montantIdajUtilise,
  });

  /// Retourne une copie avec les snapshots mis à jour.
  /// Utilisé par la migration pour figer les valeurs historiques.
  Garde copyWithSnapshot({
    double? tauxHoraire,
    double? panierRepas,
    double? indemnitesDimanche,
    double? montantIdaj,
  }) {
    return Garde(
      id: id,
      date: date,
      heureDebut: heureDebut,
      heureFin: heureFin,
      jourNonTravaille: jourNonTravaille,
      collegue: collegue,
      vehiculeUtilise: vehiculeUtilise,
      kmDomicileTravail: kmDomicileTravail,
      achats: achats,
      pauseMinutes: pauseMinutes,
      panierRepasGarde: panierRepasGarde,
      avecPanier: avecPanier,
      debutQuatorzaine: debutQuatorzaine,
      qualification: qualification,
      isCongesPaies: isCongesPaies,
      cpDateFin: cpDateFin,
      nbJoursCP: nbJoursCP,
      primeLongueDistance: primeLongueDistance,
      tauxHoraireUtilise: tauxHoraireUtilise ?? tauxHoraire,
      panierRepasUtilise: panierRepasUtilise ?? panierRepas,
      indemnitesDimancheUtilise: indemnitesDimancheUtilise ?? indemnitesDimanche,
      montantIdajUtilise: montantIdajUtilise ?? montantIdaj,
    );
  }

  int get dureeMinutesBrut => jourNonTravaille ? 0 : heureFin.difference(heureDebut).inMinutes;
  int get dureeMinutes => dureeMinutesBrut - pauseMinutes;
  double get dureeHeures => dureeMinutes > 0 ? dureeMinutes / 60 : 0;
  int get amplitudeMinutes => dureeMinutesBrut;
  bool get hasIDAJ => amplitudeMinutes > 720;
  double get totalAchats => achats.fold(0.0, (s, a) => s + a.montant);

  static DateTime _paques(int annee) {
    int a = annee % 19, b = annee ~/ 100, c = annee % 100;
    int d = b ~/ 4, e = b % 4, f = (b + 8) ~/ 25;
    int g = (b - f + 1) ~/ 3, h = (19 * a + b - d - g + 15) % 30;
    int i = c ~/ 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
    int m = (a + 11 * h + 22 * l) ~/ 451;
    int mois = (h + l - 7 * m + 114) ~/ 31;
    int jour = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(annee, mois, jour);
  }

  static Set<String> joursFeries(int annee) {
    final p = _paques(annee);
    String fmt(DateTime d) => '${d.year}-${d.month}-${d.day}';
    return {
      fmt(DateTime(annee, 1, 1)),
      fmt(p.add(const Duration(days: 1))),
      fmt(DateTime(annee, 5, 1)),
      fmt(DateTime(annee, 5, 8)),
      fmt(p.add(const Duration(days: 39))),
      fmt(p.add(const Duration(days: 50))),
      fmt(DateTime(annee, 7, 14)),
      fmt(DateTime(annee, 8, 15)),
      fmt(DateTime(annee, 11, 1)),
      fmt(DateTime(annee, 11, 11)),
      fmt(DateTime(annee, 12, 25)),
    };
  }

  bool get isDimancheOuFerie {
    if (jourNonTravaille) return false;
    if (date.weekday == DateTime.sunday) return true;
    return joursFeries(date.year)
        .contains('${date.year}-${date.month}-${date.day}');
  }

  /// Vrai uniquement pour les jours fériés légaux (pas les dimanches ordinaires)
  bool get isJourFerieSeulement {
    return joursFeries(date.year)
        .contains('${date.year}-${date.month}-${date.day}');
  }

  String? get nomJourFerie {
    if (jourNonTravaille) return null;
    if (date.weekday == DateTime.sunday) return 'Dimanche';
    final p = _paques(date.year);
    final m = date.month; final j = date.day;
    if (m == 1 && j == 1) return 'Jour de l\'An';
    if (m == 5 && j == 1) return 'Fête du Travail';
    if (m == 5 && j == 8) return 'Victoire 1945';
    if (m == 7 && j == 14) return 'Fête Nationale';
    if (m == 8 && j == 15) return 'Assomption';
    if (m == 11 && j == 1) return 'Toussaint';
    if (m == 11 && j == 11) return 'Armistice';
    if (m == 12 && j == 25) return 'Noël';
    final lp = p.add(const Duration(days: 1));
    if (date.year == lp.year && m == lp.month && j == lp.day) return 'Lundi de Pâques';
    final asc = p.add(const Duration(days: 39));
    if (date.year == asc.year && m == asc.month && j == asc.day) return 'Ascension';
    final pent = p.add(const Duration(days: 50));
    if (date.year == pent.year && m == pent.month && j == pent.day) return 'Lundi de Pentecôte';
    return null;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'heureDebut': heureDebut.toIso8601String(),
    'heureFin': heureFin.toIso8601String(),
    'jourNonTravaille': jourNonTravaille,
    'collegue': collegue,
    'vehiculeUtilise': vehiculeUtilise,
    'kmDomicileTravail': kmDomicileTravail,
    'achats': achats.map((a) => a.toMap()).toList(),
    'pauseMinutes': pauseMinutes,
    'panierRepasGarde': panierRepasGarde,
    'avecPanier': avecPanier,
    'debutQuatorzaine': debutQuatorzaine?.toIso8601String(),
    'qualification': qualification,
    'isCongesPaies': isCongesPaies,
    'cpDateFin': cpDateFin?.toIso8601String(),
    'nbJoursCP': nbJoursCP,
    'primeLongueDistance': primeLongueDistance,
    'tauxHoraireUtilise': tauxHoraireUtilise,
    'panierRepasUtilise': panierRepasUtilise,
    'indemnitesDimancheUtilise': indemnitesDimancheUtilise,
    'montantIdajUtilise': montantIdajUtilise,
  };

  factory Garde.fromMap(Map<String, dynamic> map) {
    final achatsRaw = map['achats'] as List<dynamic>? ?? [];
    final now = DateTime.now();
    return Garde(
      id: map['id'] as String? ?? '',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? now,
      heureDebut: DateTime.tryParse(map['heureDebut'] as String? ?? '') ?? now,
      heureFin: DateTime.tryParse(map['heureFin'] as String? ?? '') ?? now,
      jourNonTravaille: map['jourNonTravaille'] ?? false,
      collegue: map['collegue'],
      vehiculeUtilise: map['vehiculeUtilise'],
      kmDomicileTravail: (map['kmDomicileTravail'] ?? map['distanceTrajet'] ?? 0).toDouble(),
      achats: achatsRaw.map((a) => Achat.fromMap(Map<String, dynamic>.from(a))).toList(),
      pauseMinutes: map['pauseMinutes'] ?? 0,
      panierRepasGarde: (map['panierRepasGarde'] ?? 0).toDouble(),
      avecPanier: map['avecPanier'] ?? true,
      debutQuatorzaine: map['debutQuatorzaine'] != null
          ? DateTime.tryParse(map['debutQuatorzaine'] as String? ?? '')
          : null,
      qualification: map['qualification'] ?? 'dea',
      isCongesPaies: map['isCongesPaies'] ?? false,
      cpDateFin: map['cpDateFin'] != null
          ? DateTime.tryParse(map['cpDateFin'] as String? ?? '')
          : null,
      nbJoursCP: map['nbJoursCP'] ?? 1,
      primeLongueDistance: (map['primeLongueDistance'] ?? 0).toDouble(),
      tauxHoraireUtilise: (map['tauxHoraireUtilise'] as num?)?.toDouble(),
      panierRepasUtilise: (map['panierRepasUtilise'] as num?)?.toDouble(),
      indemnitesDimancheUtilise: (map['indemnitesDimancheUtilise'] as num?)?.toDouble(),
      montantIdajUtilise: (map['montantIdajUtilise'] as num?)?.toDouble(),
    );
  }
}
