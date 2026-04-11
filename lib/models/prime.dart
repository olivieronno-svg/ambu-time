
class PrimeMensuelle {
  final String id;
  String nom;
  double montant;

  PrimeMensuelle({
    required this.id,
    required this.nom,
    required this.montant,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nom': nom,
    'montant': montant,
  };

  factory PrimeMensuelle.fromMap(Map<String, dynamic> m) => PrimeMensuelle(
    id: m['id'] as String,
    nom: m['nom'] as String,
    montant: (m['montant'] as num).toDouble(),
  );
}
