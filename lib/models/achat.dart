
class Achat {
  final String id;
  String intitule;
  double montant;

  Achat({required this.id, required this.intitule, required this.montant});

  Map<String, dynamic> toMap() => {
    'id': id,
    'intitule': intitule,
    'montant': montant,
  };

  factory Achat.fromMap(Map<String, dynamic> m) => Achat(
    id: m['id'] as String,
    intitule: m['intitule'] as String,
    montant: (m['montant'] as num).toDouble(),
  );
}
