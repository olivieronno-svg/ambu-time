import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/garde.dart';
import '../models/prime.dart';
import 'calculs.dart';

class ExcelService {
  static const _moisNoms = [
    '', 'Janvier', 'Fevrier', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Aout', 'Septembre', 'Octobre', 'Novembre', 'Decembre'
  ];

  static String _nomMois(int mois) =>
      (mois >= 1 && mois <= 12) ? _moisNoms[mois] : '?';

  static Future<void> exporterMois({
    required List<Garde> gardes,
    required int annee,
    required int mois,
    required double tauxHoraire,
    required double panierRepas,
    required double indemnitesDimanche,
    required double montantIdaj,
    required List<PrimeMensuelle> primes,
  }) async {
    final gardesMois = gardes
        .where((g) => g.date.year == annee && g.date.month == mois)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final buf = StringBuffer();
    // BOM UTF-8 pour Excel
    buf.write('\uFEFF');

    // Titre
    buf.writeln('Ambu Time - ${_nomMois(mois)} $annee');
    buf.writeln();

    // En-têtes
    buf.writeln('Date;Debut;Fin;Heures;Coupure;Panier;Dimanche/Ferie;Brut (Eur);Achats (Eur);Total (Eur)');

    double totalBrut = 0, totalAchats = 0, totalHeures = 0;

    for (final g in gardesMois) {
      if (g.isCongesPaies) {
        final fin = g.cpDateFin;
        final label = fin != null
            ? 'CP du ${g.date.day}/${g.date.month} au ${fin.day}/${fin.month}'
            : 'Congé payé';
        buf.writeln('${g.date.day}/${g.date.month};$label;;;;;;;;');
        continue;
      }
      if (g.jourNonTravaille) {
        buf.writeln('${g.date.day}/${g.date.month};Non travaillé;;;;;;;;');
        continue;
      }

      final brut = Calculs.salaireBrutGarde(g,
          taux: tauxHoraire, panier: panierRepas,
          indDimanche: indemnitesDimanche, montantIdaj: montantIdaj);
      final heures = g.dureeHeures;
      final achatsTotal = g.achats.fold(0.0, (s, a) => s + a.montant);
      final isDim = g.date.weekday == DateTime.sunday || g.nomJourFerie != null;

      buf.writeln(
        '${g.date.day}/${g.date.month};'
        '${g.heureDebut.hour}h${g.heureDebut.minute.toString().padLeft(2,'0')};'
        '${g.heureFin.hour}h${g.heureFin.minute.toString().padLeft(2,'0')};'
        '${Calculs.formatHeures(heures)};'
        '${g.pauseMinutes > 0 ? "${g.pauseMinutes}min" : "-"};'
        '${g.avecPanier ? "Oui" : "Non"};'
        '${isDim ? "Oui" : "Non"};'
        '${brut.toStringAsFixed(2)};'
        '${achatsTotal.toStringAsFixed(2)};'
        '${(brut + achatsTotal).toStringAsFixed(2)}',
      );

      totalBrut += brut;
      totalAchats += achatsTotal;
      totalHeures += heures;
    }

    // Total
    buf.writeln();
    buf.writeln('TOTAL;;;${Calculs.formatHeures(totalHeures)};;;; '
        '${totalBrut.toStringAsFixed(2)};'
        '${totalAchats.toStringAsFixed(2)};'
        '${(totalBrut + totalAchats).toStringAsFixed(2)}');

    // Détail achats
    final avecAchats = gardesMois.where((g) => g.achats.isNotEmpty).toList();
    if (avecAchats.isNotEmpty) {
      buf.writeln();
      buf.writeln('DÉTAIL DES ACHATS');
      buf.writeln('Date;Article;Montant (€)');
      for (final g in avecAchats) {
        for (final a in g.achats) {
          buf.writeln('${g.date.day}/${g.date.month};${a.intitule};${a.montant.toStringAsFixed(2)}');
        }
      }
    }

    // Sauvegarde et partage — on NE supprime PAS le fichier après,
    // car WhatsApp/Drive lisent souvent le fichier APRÈS que le share sheet
    // se soit fermé. Le répertoire temporaire est nettoyé par l'OS.
    final dir = await getTemporaryDirectory();
    final nomFichier = 'AmbuTime_${_nomMois(mois)}_$annee.csv';
    final file = File('${dir.path}/$nomFichier');
    // BOM UTF-8 pour que Excel Windows affiche les accents
    await file.writeAsString(buf.toString());
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'Ambu Time — Export ${_nomMois(mois)} $annee',
    );
  }
}
