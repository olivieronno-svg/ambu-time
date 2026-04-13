
import '../models/garde.dart';

class Calculs {
  static const double tauxHoraireDefaut = 13.10;
  static const double panierRepasDefaut = 7.30;
  static const double indemnitesDimancheDefaut = 26.00;
  static const double idajMontantDefaut = 35.00;

  static double heuresNuit(Garde g) => g.heuresNuitMinutes / 60;

  static double majorationNuit(Garde g, double taux) =>
      heuresNuit(g) * taux * 0.25;

  // Majoration 25% sur toute la durée si dimanche ou jour férié
  static double majorationDimanche(Garde g, double taux) {
    if (!g.isDimancheOuFerie) return 0;
    return g.dureeHeures * taux * 0.25;
  }

  // IDAJ : majoration sur l'amplitude au-delà de 12h
  // 12h → 13h : +75% du taux horaire
  // au-delà de 13h : +100% du taux horaire
  static double idaj(Garde g, double taux) {
    if (!g.hasIDAJ) return 0;
    final amplitudeH = g.amplitudeMinutes / 60;
    double indemnite = 0;

    // Tranche 12h → 13h : 75% du taux sur les minutes dans cette tranche
    final tranche1 = (amplitudeH.clamp(12, 13) - 12); // en heures
    indemnite += tranche1 * taux * 0.75;

    // Tranche > 13h : 100% du taux sur le reste
    if (amplitudeH > 13) {
      final tranche2 = amplitudeH - 13;
      indemnite += tranche2 * taux * 1.00;
    }

    return indemnite;
  }

  static double salaireBrutGarde(
    Garde g, {
    double taux = tauxHoraireDefaut,
    double panier = panierRepasDefaut,
    double indDimanche = indemnitesDimancheDefaut,
    double montantIdaj = idajMontantDefaut,
  }) {
    // CCN Transports Sanitaires — accord cadre :
    // Jour férié non travaillé = maintien de salaire sur base 7h
    if (g.jourNonTravaille) {
      if (g.isJourFerieSeulement) return 7 * taux;
      return 0;
    }
    double base = g.dureeHeures * taux;
    double majNuit = majorationNuit(g, taux);
    double majDim = majorationDimanche(g, taux);
    double indaj = idaj(g, taux);
    double panierGarde = g.panierRepasGarde;
    double indDim = g.isDimancheOuFerie ? indDimanche : 0;
    return base + majNuit + majDim + indaj + panierGarde + indDim;
  }

  static double totalBrut(
    List<Garde> gardes, {
    double taux = tauxHoraireDefaut,
    double panier = panierRepasDefaut,
    double indDimanche = indemnitesDimancheDefaut,
    double montantIdaj = idajMontantDefaut,
  }) {
    return gardes
        // Inclut les jours fériés non travaillés (payés 7h par CCN)
        .where((g) => !g.isCongesPaies && (!g.jourNonTravaille || g.isJourFerieSeulement))
        .fold(0.0, (sum, g) => sum +
            salaireBrutGarde(g, taux: taux, panier: panier,
                indDimanche: indDimanche, montantIdaj: montantIdaj));
  }

  static double netEstime(double brut) => brut * 0.78;

  static double totalHeures(List<Garde> gardes) =>
      gardes.where((g) => !g.jourNonTravaille)
          .fold(0.0, (sum, g) => sum + g.dureeHeures);

  static double heuresSupp(List<Garde> gardes) {
    double total = totalHeures(gardes);
    return total <= 78 ? 0 : total - 78;
  }

  static double majorationHeuresSupp(List<Garde> gardes, double taux) {
    double total = totalHeures(gardes);
    if (total <= 78) return 0;
    double supp = total - 78;
    if (supp <= 8) return supp * taux * 0.25;
    return 8 * taux * 0.25 + (supp - 8) * taux * 0.50;
  }

  // ── CCN : Heures supp par quatorzaine, rattachées au mois de fin ──────────
  // Si la quatorzaine se termine dans le même mois → HS comptées ce mois
  // Si elle chevauche 2 mois → HS rattachées au mois où la quatorzaine SE TERMINE
  static Map<String, double> heuresSuppParMois(
      List<Garde> gardes, DateTime? debutPremQuatorzaine) {
    final Map<String, double> result = {};
    if (gardes.isEmpty) return result;

    // Reconstitue toutes les quatorzaines à partir du début configuré
    // Si pas de début configuré, on groupe par mois simplement
    if (debutPremQuatorzaine == null) {
      // Fallback : calcul par mois
      final Map<String, List<Garde>> parMois = {};
      for (final g in gardes.where((g) => !g.jourNonTravaille && !g.isCongesPaies)) {
        final k = '${g.date.year}-${g.date.month.toString().padLeft(2,'0')}';
        parMois.putIfAbsent(k, () => []).add(g);
      }
      for (final e in parMois.entries) {
        result[e.key] = heuresSupp(e.value);
      }
      return result;
    }

    // Génère les quatorzaines couvrant toutes les gardes
    final gardesToutes = gardes
        .where((g) => !g.jourNonTravaille && !g.isCongesPaies)
        .toList()..sort((a, b) => a.date.compareTo(b.date));
    if (gardesToutes.isEmpty) return result;

    DateTime debut = debutPremQuatorzaine;
    // Remonte au début si nécessaire
    while (debut.isAfter(gardesToutes.first.date)) {
      debut = debut.subtract(const Duration(days: 14));
    }

    // Parcourt toutes les quatorzaines jusqu'à couvrir toutes les gardes
    while (!debut.isAfter(gardesToutes.last.date)) {
      final fin = debut.add(const Duration(days: 13));
      final gardesQ = gardesToutes
          .where((g) => !g.date.isBefore(debut) && !g.date.isAfter(fin))
          .toList();

      if (gardesQ.isNotEmpty) {
        final hs = heuresSupp(gardesQ);
        if (hs > 0) {
          // HS rattachées au mois de FIN de la quatorzaine (CCN)
          final moisFin = '${fin.year}-${fin.month.toString().padLeft(2,'0')}';
          result[moisFin] = (result[moisFin] ?? 0) + hs;
        }
      }
      debut = debut.add(const Duration(days: 14));
    }
    return result;
  }

  static double majorationHSSurMontant(double hs, double taux) {
    if (hs <= 0) return 0;
    if (hs <= 8) return hs * taux * 0.25;
    return 8 * taux * 0.25 + (hs - 8) * taux * 0.50;
  }

  static String formatHeures(double heures) {
    int h = heures.floor();
    int m = ((heures - h) * 60).round();
    return '${h}h${m.toString().padLeft(2, '0')}';
  }
}
