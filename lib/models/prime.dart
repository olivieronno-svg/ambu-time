
class PrimeMensuelle {
  final String id;
  String nom;
  double montant;
  /// Mois d'application au format "YYYY-MM". Null = s'applique au mois courant (rétrocompat).
  String? mois;

  PrimeMensuelle({
    required this.id,
    required this.nom,
    required this.montant,
    this.mois,
  });

  /// Vrai si cette prime s'applique au mois cible (format "YYYY-MM").
  /// Les primes sans `mois` sont ignorées (migrées au chargement par Storage).
  bool appliqueAu(String moisCible) => mois == moisCible;

  Map<String, dynamic> toMap() => {
    'id': id,
    'nom': nom,
    'montant': montant,
    'mois': mois,
  };

  factory PrimeMensuelle.fromMap(Map<String, dynamic> m) => PrimeMensuelle(
    id: m['id'] as String? ?? '',
    nom: m['nom'] as String? ?? '',
    montant: (m['montant'] as num?)?.toDouble() ?? 0.0,
    mois: m['mois'] as String?,
  );
}
