
import '../models/garde.dart';

class Calculs {
  static const double tauxHoraireDefaut = 13.10;
  static const double panierRepasDefaut = 7.30;
  static const double indemnitesDimancheDefaut = 26.00;
  static const double idajMontantDefaut = 35.00;

  // ── Réglages réglables depuis Paramètres ─────────────────────────────────
  // Majoration de nuit
  static bool majorationNuitActivee = true;
  static double majorationNuitPourcentage = 25; // % du taux horaire
  static int majorationNuitDebut = 21; // heure de début de la "nuit" (fin = 6h)

  // IDAJ (indemnité de dépassement d'amplitude journalière)
  // Deux tranches configurables. La tranche 2 ne s'applique que si son seuil
  // est strictement supérieur à celui de la tranche 1 — sinon seule la tranche
  // 1 est utilisée sur l'intégralité du dépassement.
  static bool idajActivee = true;
  static double idajPourcentage = 100;     // % de la tranche 1
  static double idajSeuilHeures = 12;      // seuil tranche 1 (en h)
  static double idajTier2Pourcentage = 100; // % de la tranche 2
  static double idajTier2Seuil = 12;        // seuil tranche 2 (en h)

  // Calcule les minutes "de nuit" d'une garde, fenêtre [majorationNuitDebut, 6h[.
  static int heuresNuitMinutes(Garde g) {
    if (g.jourNonTravaille) return 0;
    final debut = majorationNuitDebut.clamp(0, 23);
    int total = 0;
    DateTime day = DateTime(g.heureDebut.year, g.heureDebut.month, g.heureDebut.day);
    final lastDay = DateTime(g.heureFin.year, g.heureFin.month, g.heureFin.day);
    while (!day.isAfter(lastDay)) {
      for (final interval in [
        [day, day.add(const Duration(hours: 6))],
        [day.add(Duration(hours: debut)), day.add(const Duration(hours: 24))],
      ]) {
        final s = g.heureDebut.isAfter(interval[0]) ? g.heureDebut : interval[0];
        final e = g.heureFin.isBefore(interval[1]) ? g.heureFin : interval[1];
        if (e.isAfter(s)) total += e.difference(s).inMinutes;
      }
      day = day.add(const Duration(days: 1));
    }
    return total.clamp(0, g.dureeMinutes);
  }

  static double heuresNuit(Garde g) => heuresNuitMinutes(g) / 60;

  static double majorationNuit(Garde g, double taux) {
    if (!majorationNuitActivee) return 0;
    final t = g.tauxHoraireUtilise ?? taux;
    return heuresNuit(g) * t * (majorationNuitPourcentage / 100);
  }

  // Majoration 25% sur toute la durée si dimanche ou jour férié
  static double majorationDimanche(Garde g, double taux) {
    if (!g.isDimancheOuFerie) return 0;
    final t = g.tauxHoraireUtilise ?? taux;
    return g.dureeHeures * t * 0.25;
  }

  // IDAJ : majoration sur l'amplitude au-delà du seuil configuré, à 2 tranches
  static double idaj(Garde g, double taux) {
    if (!idajActivee || g.jourNonTravaille) return 0;
    final t = g.tauxHoraireUtilise ?? taux;
    final amplitudeH = g.amplitudeMinutes / 60;
    if (amplitudeH <= idajSeuilHeures) return 0;

    final tier2Active = idajTier2Seuil > idajSeuilHeures;
    if (!tier2Active || amplitudeH <= idajTier2Seuil) {
      return (amplitudeH - idajSeuilHeures) * t * (idajPourcentage / 100);
    }
    final h1 = idajTier2Seuil - idajSeuilHeures;
    final h2 = amplitudeH - idajTier2Seuil;
    return h1 * t * (idajPourcentage / 100)
         + h2 * t * (idajTier2Pourcentage / 100);
  }

  static double salaireBrutGarde(
    Garde g, {
    double taux = tauxHoraireDefaut,
    double panier = panierRepasDefaut,
    double indDimanche = indemnitesDimancheDefaut,
    double montantIdaj = idajMontantDefaut,
  }) {
    // Utilise le snapshot de la Garde si disponible, sinon les paramètres passés
    final t = g.tauxHoraireUtilise ?? taux;
    final indD = g.indemnitesDimancheUtilise ?? indDimanche;

    // CCN Transports Sanitaires — accord cadre :
    // Jour férié non travaillé = maintien de salaire sur base 7h
    if (g.jourNonTravaille) {
      if (g.isJourFerieSeulement) return 7 * t;
      return 0;
    }
    double base = g.dureeHeures * t;
    double majNuit = majorationNuit(g, taux);
    double majDim = majorationDimanche(g, taux);
    double indaj = idaj(g, taux);
    double panierGarde = g.panierRepasGarde;
    double indDim = g.isDimancheOuFerie ? indD : 0;
    return base + majNuit + majDim + indaj + panierGarde + indDim + g.primeLongueDistance;
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
    final totalMinutes = (heures * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  // ── CP : taux journalier unifié ──────────────────────────────────────────
  // Si brutPeriodeRef saisi → méthode exacte (brut période / 26)
  // Sinon → approximation CCN (152h + 17h majorées) / 26
  static double tauxJournalierCP(double taux, double brutPeriodeRef) {
    if (brutPeriodeRef > 0) return brutPeriodeRef / 26;
    return ((152 * taux) + (17 * taux * 1.25)) / 26;
  }

  // ── Jours CP dans un mois calendaire donné (gère CP chevauchant 2 mois) ──
  static int joursCPDansMois(List<Garde> gardes, int annee, int mois) {
    int total = 0;
    for (final g in gardes.where((gg) => gg.isCongesPaies)) {
      final debut = g.date;
      final fin = g.cpDateFin ?? g.date;
      for (int i = 0; i <= fin.difference(debut).inDays; i++) {
        final j = debut.add(Duration(days: i));
        if (j.year == annee && j.month == mois) total++;
      }
    }
    return total;
  }

  // ── Source de vérité unique : brut mensuel complet ───────────────────────
  // Inclut : gardes travaillées + fériés seuls + primes mensuelles +
  // prime annuelle (mai) + indemnité CP.
  // Utilisé par AccueilScreen, HistoriqueScreen (vue année + détail mois) et
  // SalaireScreen pour afficher le MÊME chiffre partout.
  // HS CCN exclue du total brut (affichée séparément en info dans Salaire).
  static double brutMoisComplet({
    required List<Garde> toutesGardes,
    required int annee,
    required int mois,
    required double taux,
    required double panier,
    required double indDimanche,
    required double montantIdaj,
    double brutPeriodeRef = 0,
    double primesMensuellesMois = 0,
    double primeAnnuelle = 0,
  }) {
    // 1. Gardes du mois (y.c. fériés seuls, via filtre interne de totalBrut)
    final gardesMois = toutesGardes
        .where((g) => g.date.year == annee && g.date.month == mois)
        .toList();
    final brutGardes = totalBrut(gardesMois,
        taux: taux, panier: panier,
        indDimanche: indDimanche, montantIdaj: montantIdaj);

    // 2. Indemnité CP (jours CP de ce mois × taux journalier)
    final nbCP = joursCPDansMois(toutesGardes, annee, mois);
    final indemniteCP = nbCP * tauxJournalierCP(taux, brutPeriodeRef);

    // 3. Primes
    final estMai = mois == 5;
    final primeAnnuelleApplicable = estMai ? primeAnnuelle : 0.0;

    return brutGardes + indemniteCP + primesMensuellesMois + primeAnnuelleApplicable;
  }
}
