
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

  // ── Contrat & cycle de calcul des heures ─────────────────────────────────
  // Heures contractuelles hebdomadaires (35, 39, ou valeur libre pour les
  // contrats à temps partiel : 28, 30…).
  static double heuresContractuellesHebdo = 39;
  // false = temps plein  → heures supplémentaires (+25% les 8 premières, +50%)
  // true  = temps partiel → heures complémentaires (+10% jusqu'à 1/10 du
  //         contrat, +25% au-delà, plafonnées à 1/3 du contrat — Code du travail)
  static bool tempsPartiel = false;
  // true  = calcul par quatorzaine (cycle de 14 jours, seuil = heures hebdo ×2)
  // false = calcul à la semaine    (cycle de 7 jours,  seuil = heures hebdo ×1)
  static bool quatorzaineActivee = true;

  // Seuil d'heures sur la période de calcul (au-delà = heures sup / compl.).
  static double get seuilHeuresPeriode =>
      heuresContractuellesHebdo * (quatorzaineActivee ? 2 : 1);

  // Durée de la période de calcul en jours.
  static int get dureePeriodeJours => quatorzaineActivee ? 14 : 7;

  // Majoration € pour `extra` heures au-delà du seuil `seuil` (= heures
  // contractuelles de la période). Temps plein : +25% pour les 8 premières
  // puis +50%. Temps partiel : heures complémentaires +10% jusqu'à 1/10 du
  // contrat, +25% au-delà, le tout plafonné à 1/3 du contrat.
  static double _majorationExtra(double extra, double seuil, double taux) {
    if (extra <= 0) return 0;
    if (tempsPartiel) {
      final plafond = seuil / 3;
      final e = extra > plafond ? plafond : extra;
      final seuil10 = seuil / 10;
      final t1 = e <= seuil10 ? e : seuil10; // +10%
      final t2 = e - t1; // +25%
      return t1 * taux * 0.10 + t2 * taux * 0.25;
    }
    if (extra <= 8) return extra * taux * 0.25;
    return 8 * taux * 0.25 + (extra - 8) * taux * 0.50;
  }

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

  // Heures "en plus" sur la période : heures supplémentaires (temps plein) ou
  // heures complémentaires (temps partiel, plafonnées à 1/3 du contrat).
  static double heuresSupp(List<Garde> gardes) {
    final total = totalHeures(gardes);
    final seuil = seuilHeuresPeriode;
    if (total <= seuil) return 0;
    double extra = total - seuil;
    if (tempsPartiel) {
      final plafond = seuil / 3;
      if (extra > plafond) extra = plafond;
    }
    return extra;
  }

  static double majorationHeuresSupp(List<Garde> gardes, double taux) {
    final total = totalHeures(gardes);
    final seuil = seuilHeuresPeriode;
    if (total <= seuil) return 0;
    return _majorationExtra(total - seuil, seuil, taux);
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
    final periodeJours = dureePeriodeJours;
    while (debut.isAfter(gardesToutes.first.date)) {
      debut = debut.subtract(Duration(days: periodeJours));
    }

    // Parcourt toutes les périodes jusqu'à couvrir toutes les gardes
    while (!debut.isAfter(gardesToutes.last.date)) {
      final fin = debut.add(Duration(days: periodeJours - 1));
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
      debut = debut.add(Duration(days: periodeJours));
    }
    return result;
  }

  static double majorationHSSurMontant(double hs, double taux) {
    if (hs <= 0) return 0;
    return _majorationExtra(hs, seuilHeuresPeriode, taux);
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
