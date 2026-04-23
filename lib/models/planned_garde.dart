
class PlannedGarde {
  final String id;
  DateTime date;
  int heureDebutH;
  int heureDebutM;
  int heureFinH;
  int heureFinM;
  String? notes;
  String? collegue;
  bool confirme;
  String typeGarde; // 'UPH Jour', 'UPH Nuit', 'Art 80'

  PlannedGarde({
    required this.id,
    required this.date,
    this.heureDebutH = 7,
    this.heureDebutM = 0,
    this.heureFinH = 17,
    this.heureFinM = 0,
    this.notes,
    this.collegue,
    this.confirme = false,
    this.typeGarde = 'UPH Jour',
  });

  String get heuresLabel =>
      '${heureDebutH.toString().padLeft(2, '0')}h${heureDebutM.toString().padLeft(2, '0')} → ${heureFinH.toString().padLeft(2, '0')}h${heureFinM.toString().padLeft(2, '0')}';

  int get dureeMinutes =>
      (heureFinH * 60 + heureFinM) - (heureDebutH * 60 + heureDebutM);

  double get dureeHeures => dureeMinutes > 0 ? dureeMinutes / 60 : 0;

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'heureDebutH': heureDebutH,
    'heureDebutM': heureDebutM,
    'heureFinH': heureFinH,
    'heureFinM': heureFinM,
    'notes': notes,
    'collegue': collegue,
    'confirme': confirme,
    'typeGarde': typeGarde,
  };

  factory PlannedGarde.fromMap(Map<String, dynamic> m) => PlannedGarde(
    id: m['id'] as String? ?? '',
    date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
    heureDebutH: (m['heureDebutH'] as int?) ?? 7,
    heureDebutM: (m['heureDebutM'] as int?) ?? 0,
    heureFinH: (m['heureFinH'] as int?) ?? 17,
    heureFinM: (m['heureFinM'] as int?) ?? 0,
    notes: m['notes'] as String?,
    collegue: m['collegue'] as String?,
    confirme: (m['confirme'] as bool?) ?? false,
    typeGarde: (m['typeGarde'] as String?) ?? 'UPH Jour',
  );
}
