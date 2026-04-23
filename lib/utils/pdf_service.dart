
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/garde.dart';
import '../models/prime.dart';
import 'calculs.dart';

class PdfService {
  // ── Couleurs pastels ──────────────────────────────────────────────────────
  static const _bleu    = PdfColor.fromInt(0xFFB5D4F4);
  static const _vert    = PdfColor.fromInt(0xFFC0DD97);
  static const _teal    = PdfColor.fromInt(0xFF9FE1CB);
  static const _amber   = PdfColor.fromInt(0xFFFAC775);
  static const _coral   = PdfColor.fromInt(0xFFF5C4B3);
  static const _violet  = PdfColor.fromInt(0xFFCECBF6);
  static const _gris    = PdfColor.fromInt(0xFFE8EDF5);

  static const _noir    = PdfColors.grey900;
  static const _grisTexte = PdfColor.fromInt(0xFF555566);
  static const _blanc   = PdfColors.white;

  static const _moisNoms = [
    '', 'Janvier', 'Fevrier', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Aout', 'Septembre', 'Octobre', 'Novembre', 'Decembre'
  ];

  static String _nomMois(int mois) =>
      (mois >= 1 && mois <= 12) ? _moisNoms[mois] : '?';

  // ── Export mensuel ────────────────────────────────────────────────────────
  static Future<void> exporterMois({
    required List<Garde> gardes,
    required int annee,
    required int mois,
    required double tauxHoraire,
    required double panierRepas,
    required double indemnitesDimanche,
    required double montantIdaj,
    required List<PrimeMensuelle> primes,
    required double impotSource,
  }) async {
    final gardesMois = gardes
        .where((g) => g.date.year == annee && g.date.month == mois)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Filtre les primes qui s'appliquent à ce mois précis
    final moisCle = '$annee-${mois.toString().padLeft(2, '0')}';
    final primesDuMois = primes.where((p) => p.appliqueAu(moisCle)).toList();

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => _header(annee, mois),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        _resume(gardesMois, tauxHoraire, panierRepas, indemnitesDimanche,
            montantIdaj, primesDuMois, impotSource, annee),
        pw.SizedBox(height: 16),
        _tableGardes(gardesMois, tauxHoraire, panierRepas,
            indemnitesDimanche, montantIdaj),
        pw.SizedBox(height: 16),
        _detailCalcul(gardesMois, tauxHoraire, panierRepas,
            indemnitesDimanche, montantIdaj, primesDuMois, impotSource, annee, mois),
      ],
    ));

    await Printing.layoutPdf(
      onLayout: (fmt) async => pdf.save(),
      name: 'EXPORT_PDF_${_nomMois(mois)}_$annee.pdf',
    );
  }

  // ── En-tete ───────────────────────────────────────────────────────────────
  static pw.Widget _header(int annee, int mois) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _bleu,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Ambu Time',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold,
                    color: _noir)),
            pw.Text('Releve mensuel - ${_nomMois(mois)} $annee',
                style: pw.TextStyle(fontSize: 11, color: _grisTexte)),
          ]),
          pw.Text('${_nomMois(mois)} $annee',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold,
                  color: _noir)),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _gris, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Estimation indicative - CCN Transports Sanitaires',
              style: pw.TextStyle(fontSize: 8, color: _grisTexte)),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _grisTexte)),
        ],
      ),
    );
  }

  // ── Resume ────────────────────────────────────────────────────────────────
  static pw.Widget _resume(
    List<Garde> gardes,
    double taux, double panier, double dimanche, double idaj,
    List<PrimeMensuelle> primes, double impotSource,
    int annee,
  ) {
    final brut = Calculs.totalBrut(gardes, taux: taux, panier: panier,
        indDimanche: dimanche, montantIdaj: idaj);
    final totalPrimes = primes.fold(0.0, (s, p) => s + p.montant);
    final brutAvecPrimes = brut + totalPrimes;
    final net = Calculs.netEstime(brutAvecPrimes);
    final impot = impotSource > 0 ? net * (impotSource / 100) : 0.0;
    final netFinal = net - impot;
    final heures = Calculs.totalHeures(gardes);
    final supp = Calculs.heuresSupp(gardes);
    final nbNT = gardes.where((g) => g.jourNonTravaille).length;

    final cards = [
      _resumeCard('Salaire brut', '${brutAvecPrimes.toStringAsFixed(2)} EUR', _vert),
      _resumeCard('Net estime (~78%)', '${net.toStringAsFixed(2)} EUR', _teal),
      if (impotSource > 0)
        _resumeCard('Net apres impot', '${netFinal.toStringAsFixed(2)} EUR', _bleu),
      _resumeCard('Heures travaillees', Calculs.formatHeures(heures), _violet),
      _resumeCard('H. supplementaires', Calculs.formatHeures(supp), _amber),
      _resumeCard('Jours non travailles', '$nbNT jour(s)', _coral),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('RESUME DU MOIS', _bleu),
        pw.SizedBox(height: 8),
        pw.Wrap(
          spacing: 8, runSpacing: 8,
          children: cards,
        ),
      ],
    );
  }

  static pw.Widget _resumeCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 155,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _grisTexte)),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold,
                  color: _noir)),
        ],
      ),
    );
  }

  // ── Table des gardes ──────────────────────────────────────────────────────
  static pw.Widget _tableGardes(
    List<Garde> gardes,
    double taux, double panier, double dimanche, double idaj,
  ) {
    if (gardes.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('DETAIL DES GARDES', _vert),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _gris, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(48),
            1: const pw.FixedColumnWidth(78),
            2: const pw.FixedColumnWidth(42),
            3: const pw.FlexColumnWidth(),
            4: const pw.FixedColumnWidth(52),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _gris),
              children: [
                _cellHeader('Date'),
                _cellHeader('Horaires'),
                _cellHeader('Duree'),
                _cellHeader('Infos'),
                _cellHeader('Brut'),
              ],
            ),
            ...gardes.map((g) {
              final brut = g.jourNonTravaille ? 0.0 :
                  Calculs.salaireBrutGarde(g, taux: taux, panier: g.panierRepasGarde,
                      indDimanche: dimanche, montantIdaj: idaj);
              final rowColor = g.jourNonTravaille ? _coral.flatten()
                  : g.isDimancheOuFerie ? _amber.flatten()
                  : g.heuresNuitMinutes > 0 ? _bleu.flatten()
                  : _blanc;
              final infos = <String>[];
              if (g.jourNonTravaille) infos.add('Non travaille');
              if (g.pauseMinutes > 0) infos.add('Pause ${Calculs.formatHeures(g.pauseMinutes/60)}');
              if (g.hasIDAJ) infos.add('IDAJ');
              if (g.isDimancheOuFerie) infos.add(g.nomJourFerie ?? 'Dim');
              if (g.collegue != null) infos.add(g.collegue!);
              if (g.vehiculeUtilise != null) infos.add(g.vehiculeUtilise!);
              if (g.achats.isNotEmpty) infos.add('Achats: ${g.totalAchats.toStringAsFixed(2)} EUR');
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: rowColor),
                children: [
                  _cell('${g.date.day}/${g.date.month}'),
                  _cell(g.jourNonTravaille ? ''
                      : '${g.heureDebut.hour}h${g.heureDebut.minute.toString().padLeft(2,'0')} - ${g.heureFin.hour}h${g.heureFin.minute.toString().padLeft(2,'0')}'),
                  _cell(g.jourNonTravaille ? '' : Calculs.formatHeures(g.dureeHeures)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: infos.isEmpty
                          ? [pw.Text('', style: pw.TextStyle(fontSize: 9, color: _noir))]
                          : infos.map((info) => pw.Text(info,
                              style: pw.TextStyle(fontSize: 9, color: _noir))).toList(),
                    ),
                  ),
                  _cell(g.jourNonTravaille ? '' : '${brut.toStringAsFixed(2)} EUR',
                      bold: !g.jourNonTravaille),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── Detail du calcul ──────────────────────────────────────────────────────
  static pw.Widget _detailCalcul(
    List<Garde> gardes,
    double taux, double panier, double dimanche, double idaj,
    List<PrimeMensuelle> primes, double impotSource,
    int annee, int mois,
  ) {
    final gardsTravailles = gardes.where((g) => !g.jourNonTravaille).toList();
    final brut = Calculs.totalBrut(gardes, taux: taux, panier: panier,
        indDimanche: dimanche, montantIdaj: idaj);
    final totalHeures = Calculs.totalHeures(gardes);
    final heuresSupp = Calculs.heuresSupp(gardes);
    final majSupp = Calculs.majorationHeuresSupp(gardes, taux);
    final totalNuit = gardes.fold(0.0, (s, g) => s + Calculs.heuresNuit(g));
    final totalMajNuit = gardes.fold(0.0, (s, g) => s + Calculs.majorationNuit(g, taux));
    final totalMajDim = gardes.fold(0.0, (s, g) => s + Calculs.majorationDimanche(g, taux));
    final totalIdaj = gardes.fold(0.0, (s, g) => s + Calculs.idaj(g, taux));
    final nbDim = gardes.where((g) => g.isDimancheOuFerie).length;
    final totalPaniers = gardes.fold(0.0, (s, g) => s + g.panierRepasGarde);
    final totalAchats = gardes.fold(0.0, (s, g) => s + g.totalAchats);
    final totalKm = gardes.fold(0.0, (s, g) => s + g.kmDomicileTravail);
    final nbNT = gardes.where((g) => g.jourNonTravaille).length;

    final totalPrimes = primes.fold(0.0, (s, p) => s + p.montant);
    final brutAvecPrimes = brut + totalPrimes;
    final net = Calculs.netEstime(brutAvecPrimes);
    final impot = impotSource > 0 ? net * (impotSource / 100) : 0.0;
    final netFinal = net - impot;

    final lignes = <_Ligne>[
      _Ligne('Heures de base',
          '${Calculs.formatHeures(totalHeures)} ${taux.toStringAsFixed(2)} EUR/h',
          '${(totalHeures * taux).toStringAsFixed(2)} EUR', _vert),
      if (totalNuit > 0)
        _Ligne('Majorations nuit (21h-6h)',
            '${Calculs.formatHeures(totalNuit)} +25%',
            '+${totalMajNuit.toStringAsFixed(2)} EUR', _bleu),
      if (nbDim > 0)
        _Ligne('Majorations dim./ferie',
            '$nbDim jour(s) +25%',
            '+${totalMajDim.toStringAsFixed(2)} EUR', _amber),
      if (heuresSupp > 0)
        _Ligne('Heures supplementaires',
            '${Calculs.formatHeures(heuresSupp)} (25%/50%)',
            '+${majSupp.toStringAsFixed(2)} EUR', _amber),
      if (totalIdaj > 0)
        _Ligne('IDAJ',
            '${gardsTravailles.where((g) => g.hasIDAJ).length} garde(s)',
            '+${totalIdaj.toStringAsFixed(2)} EUR', _violet),
      if (totalPaniers > 0)
        _Ligne('Paniers repas',
            '${gardsTravailles.where((g) => g.avecPanier).length} garde(s)',
            '+${totalPaniers.toStringAsFixed(2)} EUR', _vert),
      _Ligne('Total brut gardes', '', '${brut.toStringAsFixed(2)} EUR', _gris, bold: true),
      if (totalPrimes > 0)
        ...primes.map((p) => _Ligne(p.nom, 'prime mensuelle',
            '+${p.montant.toStringAsFixed(2)} EUR', _violet)),
      _Ligne('Total brut avec primes', '', '${brutAvecPrimes.toStringAsFixed(2)} EUR',
          _vert, bold: true),
      _Ligne('Net estime (~78%)', 'estimation indicative',
          '${net.toStringAsFixed(2)} EUR', _teal, bold: true),
      if (impotSource > 0) ...[
        _Ligne('Impot prel. a la source',
            '${impotSource.toStringAsFixed(1)}% du net',
            '- ${impot.toStringAsFixed(2)} EUR', _coral),
        _Ligne('Net apres impot', 'montant percu',
            '${netFinal.toStringAsFixed(2)} EUR', _bleu, bold: true),
      ],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('DETAIL DU CALCUL', _violet),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: _gris, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _gris),
              children: [
                _cellHeader('Element'),
                _cellHeader('Detail'),
                _cellHeader('Montant'),
              ],
            ),
            ...lignes.map((l) => pw.TableRow(
              decoration: pw.BoxDecoration(color: l.color),
              children: [
                _cell(l.label, bold: l.bold),
                _cell(l.detail),
                _cell(l.valeur, bold: l.bold),
              ],
            )),
          ],
        ),
        if (nbNT > 0 || totalAchats > 0 || totalKm > 0) ...[
          pw.SizedBox(height: 16),
          _sectionTitle('INFORMATIONS COMPLEMENTAIRES', _coral),
          pw.SizedBox(height: 8),
          pw.Wrap(spacing: 8, runSpacing: 8, children: [
            if (nbNT > 0)
              _resumeCard('Jours non travailles', '$nbNT jour(s)', _coral),
            if (totalAchats > 0)
              _resumeCard('Total achats (frais reels)', '${totalAchats.toStringAsFixed(2)} EUR', _amber),
            if (totalKm > 0)
              _resumeCard('Km domicile-travail', '${totalKm.toStringAsFixed(0)} km', _bleu),
          ]),
        ],
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static pw.Widget _sectionTitle(String title, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(title,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _noir)),
    );
  }

  static pw.Widget _cellHeader(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _noir)),
  );

  static pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(text,
        style: pw.TextStyle(fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: _noir)),
  );

  // Attestation fiscale annuelle
  static Future<void> exporterAttestation({
    required List<Garde> gardes,
    required int annee,
    required double tauxHoraire,
    required double panierRepas,
    required double indemnitesDimanche,
    required double montantIdaj,
    required List<PrimeMensuelle> primes,
    required double impotSource,
    required double kmDomicileTravail,
  }) async {
    final gsTrav = gardes.where((g) => !g.jourNonTravaille).toList();
    final brut = Calculs.totalBrut(gsTrav, taux: tauxHoraire, panier: panierRepas,
        indDimanche: indemnitesDimanche, montantIdaj: montantIdaj);
    // Pour les primes datées : somme toutes celles de l'année concernée.
    // Pour les primes non datées (rétrocompat) : * 12 (supposées récurrentes).
    final anneeStr = annee.toString();
    final primesAnneeSpecifique = primes
        .where((p) => p.mois != null && p.mois!.startsWith('$anneeStr-'))
        .fold(0.0, (s, p) => s + p.montant);
    final primesLegacy = primes
        .where((p) => p.mois == null)
        .fold(0.0, (s, p) => s + p.montant) * 12;
    final primesAnnuelles = primesAnneeSpecifique + primesLegacy;
    final brutTotal = brut + primesAnnuelles;
    final net = Calculs.netEstime(brutTotal);
    final impot = impotSource > 0 ? net * (impotSource / 100) : 0.0;
    final kmTotal = gsTrav.fold(0.0, (s, g) => s + g.kmDomicileTravail);
    final totalKm = kmTotal > 0 ? kmTotal : kmDomicileTravail * gsTrav.length;
    final paniersTotal = gsTrav.fold(0.0, (s, g) => s + g.panierRepasGarde);
    final achatsTotal = gardes.fold(0.0, (s, g) => s + g.totalAchats);

    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // En-tete
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(color: _violet, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Ambu Time', style: pw.TextStyle(fontSize: 16,
                    fontWeight: pw.FontWeight.bold, color: _noir)),
                pw.Text('Attestation fiscale $annee',
                    style: pw.TextStyle(fontSize: 11, color: _grisTexte)),
              ]),
              pw.Text('1er jan. $annee - 31 dec. $annee',
                  style: pw.TextStyle(fontSize: 10, color: _grisTexte)),
            ]),
          ),
          pw.SizedBox(height: 20),

          // Salaires
          _sectionTitle('SALAIRES', _vert),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _gris, width: 0.5),
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: _gris), children: [
                _cellHeader('Element'), _cellHeader('Montant'),
              ]),
              pw.TableRow(decoration: pw.BoxDecoration(color: _vert.flatten()), children: [
                _cell('Salaire brut annuel (gardes)'), _cell('${brut.toStringAsFixed(2)} EUR'),
              ]),
              pw.TableRow(decoration: pw.BoxDecoration(color: _vert.flatten()), children: [
                _cell('Primes annuelles'), _cell('${primesAnnuelles.toStringAsFixed(2)} EUR'),
              ]),
              pw.TableRow(decoration: pw.BoxDecoration(color: _teal.flatten()), children: [
                _cell('Total brut annuel', bold: true), _cell('${brutTotal.toStringAsFixed(2)} EUR', bold: true),
              ]),
              pw.TableRow(decoration: pw.BoxDecoration(color: _teal.flatten()), children: [
                _cell('Net estime (~78%)', bold: true), _cell('${net.toStringAsFixed(2)} EUR', bold: true),
              ]),
              if (impotSource > 0)
                pw.TableRow(decoration: pw.BoxDecoration(color: _coral.flatten()), children: [
                  _cell('Impot preleve (${impotSource.toStringAsFixed(1)}%)'),
                  _cell('- ${impot.toStringAsFixed(2)} EUR'),
                ]),
            ],
          ),
          pw.SizedBox(height: 16),

          // Frais reels
          _sectionTitle('FRAIS REELS DEDUCTIBLES', _bleu),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: _gris, width: 0.5),
            children: [
              pw.TableRow(decoration: pw.BoxDecoration(color: _gris), children: [
                _cellHeader('Nature'), _cellHeader('Quantite'), _cellHeader('Montant'),
              ]),
              pw.TableRow(decoration: pw.BoxDecoration(color: _bleu.flatten()), children: [
                _cell('Km domicile-travail'),
                _cell('${totalKm.toStringAsFixed(0)} km'),
                _cell('${(totalKm * 0.099).toStringAsFixed(2)} EUR'),
              ]),
              pw.TableRow(decoration: pw.BoxDecoration(color: _vert.flatten()), children: [
                _cell('Paniers repas'),
                _cell('${gsTrav.where((g) => g.avecPanier).length} repas'),
                _cell('${paniersTotal.toStringAsFixed(2)} EUR'),
              ]),
              pw.TableRow(decoration: pw.BoxDecoration(color: _amber.flatten()), children: [
                _cell('Autres depenses'), _cell(''), _cell('${achatsTotal.toStringAsFixed(2)} EUR'),
              ]),
              pw.TableRow(decoration: pw.BoxDecoration(color: _violet.flatten()), children: [
                _cell('TOTAL FRAIS REELS', bold: true),
                _cell(''),
                _cell('${(totalKm * 0.099 + paniersTotal + achatsTotal).toStringAsFixed(2)} EUR', bold: true),
              ]),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Document genere par Ambu Time - Estimation indicative - CCN Transports Sanitaires',
            style: pw.TextStyle(fontSize: 8, color: _grisTexte),
          ),
        ],
      ),
    ));

    await Printing.layoutPdf(
      onLayout: (fmt) async => pdf.save(),
      name: 'ATTESTATION_FISCALE_$annee.pdf',
    );
  }

  // Compatibilite ancienne signature
  static Future<void> exporterGardes({
    required List<Garde> gardes,
    required double tauxHoraire,
    required double panierRepas,
    required double indemnitesDimanche,
    required double montantIdaj,
    DateTime? debutQuatorzaine,
  }) async {
    final now = DateTime.now();
    await exporterMois(
      gardes: gardes, annee: now.year, mois: now.month,
      tauxHoraire: tauxHoraire, panierRepas: panierRepas,
      indemnitesDimanche: indemnitesDimanche, montantIdaj: montantIdaj,
      primes: [], impotSource: 0,
    );
  }
}

class _Ligne {
  final String label, detail, valeur;
  final PdfColor color;
  final bool bold;
  _Ligne(this.label, this.detail, this.valeur, this.color, {this.bold = false});
}

