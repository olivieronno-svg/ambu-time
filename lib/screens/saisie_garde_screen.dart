
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/garde.dart';
import '../models/achat.dart';
import '../utils/calculs.dart';
import '../app_theme.dart';

class SaisieGardeScreen extends StatefulWidget {
  final Function(Garde) onGardeAjoutee;
  final double tauxHoraire;
  final double panierRepas;
  final double indemnitesDimanche;
  final double montantIdaj;
  final Garde? gardeAModifier;
  final Function(Garde)? onGardeModifiee;
  final DateTime? debutQuatorzaine;
  final double kmDomicileTravail;
  final String poste;
  final Function(String)? onSupprimerGardeId;
  final List<Garde> toutesGardes;

  const SaisieGardeScreen({
    super.key,
    required this.onGardeAjoutee,
    required this.tauxHoraire,
    required this.panierRepas,
    required this.indemnitesDimanche,
    required this.montantIdaj,
    required this.kmDomicileTravail,
    required this.poste,
    this.gardeAModifier,
    this.onGardeModifiee,
    this.debutQuatorzaine,
    this.onSupprimerGardeId,
    this.toutesGardes = const [],
  });

  @override
  State<SaisieGardeScreen> createState() => _SaisieGardeScreenState();
}

class _SaisieGardeScreenState extends State<SaisieGardeScreen> {
  late DateTime _date;
  bool _jourNonTravaille = false;
  bool _isCongesPaies = false;
  DateTime? _cpDateFin;
  bool _avecPause = false;
  int _pauseMinutes = 0;
  bool _avecPanier = false;
  late double _panierRepasGarde;
  bool _avecLongueDistance = false;
  double _primeLongueDistance = 0;
  late TextEditingController _debutHeureCtrl;
  late TextEditingController _debutMinCtrl;
  late TextEditingController _finHeureCtrl;
  late TextEditingController _finMinCtrl;
  late TextEditingController _collegueCtrl;
  late TextEditingController _vehiculeCtrl;
  late TextEditingController _longuePrimeCtrl;
  List<Achat> _achats = [];

  // ── Reconnaissance vocale ──────────────────────────────────────────
  // ── ASSISTANT VOCAL CONVERSATIONNEL ─────────────────────────────
  // Machine à états : guide l'utilisateur question par question
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechAvailable = false;
  bool _ecoute = false;
  bool _ttsActif = false;
  String _texteVocal = '';
  String _etatConv = ''; // état courant de la conversation
  String _articleEnAttente = ''; // article dont on attend le prix

  Future<void> _initSpeech() async {
    // Configuration TTS — sélection automatique de la meilleure voix
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.50);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    // Important: évite la coupure sur les points intermédiaires
    try { await _tts.setSharedInstance(true); } catch (_) {}
    // Cherche automatiquement la meilleure voix Google française
    try {
      final voices = await _tts.getVoices as List?;
      if (voices != null) {
        // Priorité : Google WaveNet > Google Standard > autres
        Map? best;
        for (final v in voices) {
          final name = ((v['name'] ?? '') as String).toLowerCase();
          final locale = ((v['locale'] ?? '') as String).toLowerCase();
          if (!locale.contains('fr')) continue;
          if (name.contains('wavenet')) { best = v as Map; break; }
          if (name.contains('google') && best == null) best = v as Map;
          if (best == null) best = v as Map;
        }
        if (best != null) {
          await _tts.setVoice({
            'name': best['name'] as String,
            'locale': best['locale'] as String,
          });
        }
      }
    } catch (_) {}
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _ttsActif = false);
        if (_etatConv.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 600), _ecouterReponse);
        }
      }
    });
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _ecoute = false);
        }
      },
      onError: (e) {
        if (mounted) setState(() => _ecoute = false);
      },
    );
  }

  // ── Parle et attend la fin avant de réécouter ─────────────────
  Future<void> _parler(String texte) async {
    if (!mounted) return;
    await _speech.stop();
    setState(() { _ttsActif = true; _ecoute = false; });
    await _tts.stop();
    await _tts.speak(texte);
    // Timer de secours si completionHandler ne se déclenche pas (8s)
    if (_etatConv.isNotEmpty) {
      final etatTimer = _etatConv;
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _etatConv == etatTimer && !_ecoute && _ttsActif) {
          setState(() => _ttsActif = false);
          _ecouterReponse();
        }
      });
    }
  }

  // ── Lance l'écoute pour capter la réponse ─────────────────────
  Future<void> _ecouterReponse() async {
    if (!mounted || _etatConv.isEmpty) return;
    if (!_speechAvailable) await _initSpeech();
    setState(() { _ecoute = true; _texteVocal = ''; });
    await _speech.listen(
      localeId: 'fr_FR',
      onResult: (result) {
        if (!mounted) return;
        setState(() => _texteVocal = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          final rep = result.recognizedWords.trim();
          setState(() { _ecoute = false; _texteVocal = ''; });
          _traiterReponse(rep);
        }
      },
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      cancelOnError: false,
      listenMode: ListenMode.dictation,
    );
  }

  // ── Démarre la conversation ────────────────────────────────────
  Future<void> _demarrerEcoute() async {
    if (_ecoute || _ttsActif) {
      // Stop mais garde l'état de la conversation
      await _tts.stop();
      await _speech.stop();
      setState(() { _ecoute = false; _ttsActif = false; _texteVocal = ''; });
      return;
    }
    // Si conversation déjà en cours — reprend et répète la question
    if (_etatConv.isNotEmpty) {
      final questions = {
        'date': 'Quelle garde dois-je inscrire ?',
        'heures': 'Quels sont les horaires ?',
        'pause': 'Avez-vous fait une coupure ?',
        'duree_pause': 'Combien de minutes de coupure ?',
        'achats': 'Quels ont ete vos achats divers ?',
        'autres_achats': 'Avez-vous d\'autres achats ?',
        'demande_achats': 'Avez-vous effectué des achats ?',
        'fin_achats': 'Est-ce tout ?',
        'longue_distance': 'Avez-vous eu une prime longue distance ?',
        'montant_longue_distance': 'Quel est le montant de la prime longue distance ?',
        'confirmer': 'Dois-je sauvegarder cette garde ?',
        'confirmer_doublon': 'Voulez-vous quand meme enregistrer ?',
        'confirmer_cp_garde': 'Voulez-vous enregistrer le congé quand même ?',
        'conge_debut': 'Quel est le premier jour ?',
        'conge_fin': 'Quel est le dernier jour ?',
      };
      final q = questions[_etatConv];
      if (q != null) {
        await _parler(q);
      } else {
        await _ecouterReponse();
      }
      return;
    }
    if (!_speechAvailable) await _initSpeech();
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Micro non disponible')));
      return;
    }
    _etatConv = 'date';
    final h = DateTime.now().hour;
    final salut = h >= 18 ? 'Bonsoir' : 'Bonjour';
    await _parler('$salut ! Quelle garde dois-je inscrire ?');
  }

  Future<void> _traiterReponse(String rep) async {
    final t = rep.toLowerCase()
        .replaceAll('é','e').replaceAll('è','e').replaceAll('ê','e')
        .replaceAll('à','a').replaceAll('â','a').replaceAll('ç','c')
        .replaceAll("'", " ");

    // Sauvegarde globale — à tout moment
    final tSav = t.replaceAll(' ', '');
    if (t.contains('sauvegarde') || t.contains('enregistre') ||
        t.contains('sauvegarder') || t.contains('enregistrer') ||
        t.contains('c est bon') || t.contains('valide') ||
        tSav.contains('sauvegarde') || tSav.contains('enregistre')) {
      setState(() => _etatConv = '');
      if (_checkCPChevauchement()) return;
      _enregistrerGarde();
      await _parler('Parfait, garde enregistree !');
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) _reinitialiserFormulaire();
      });
      return;
    }

    // Stop / réinitialise global — fonctionne toujours
    if (t == 'reinitialise' || t == 'reinitialiser' || t == 'efface' || t == 'efface tout' ||
        t.contains('reinitialise') || t.contains('efface tout') || t.contains('recommence tout') ||
        t.contains('tout effacer') || t.contains('tout reinitialiser') ||
        (t.contains('annule') && (t.contains('tout') || t.length < 10))) {
      _reinitialiserFormulaire();
      await _parler('Formulaire réinitialisé.');
      return;
    }

    // Retour en arrière / correction
    final estCorrection = t.contains('trompe') || t.contains('tort') || t.contains('erreur') || t.contains('faux') ||
        t.contains('retour') || t.contains('recommence') ||
        t.contains('modifier') || t.contains('changer') ||
        t.contains('pas ca') || t.contains('pas correct') || t.contains('pas bon') ||
        (t.contains('non') && (t.contains('ca') || t.contains('pas') || t.contains('correct')));

    if (estCorrection) {
      // Détecte si la phrase contient des heures (Xh à Yh / de X à Y)
      String tCorr = t.replaceAll('heures','h').replaceAll('heure','h')
          .replaceAll('à','a').replaceAll('de ','');
      tCorr = tCorr.replaceAllMapped(RegExp(r'(\d{1,2})\s+h'), (m) => '${m.group(1)}h');
      final hCorr = <List<int>>[];
      for (final m in RegExp(r'(\d{1,2})h(\d{2})?').allMatches(tCorr)) {
        final h = int.tryParse(m.group(1) ?? '') ?? -1;
        final mn = int.tryParse(m.group(2) ?? '0') ?? 0;
        if (h >= 0 && h <= 23) hCorr.add([h, mn]);
      }

      // Détecte si la phrase contient une date explicite
      final contientDateExplicite = t.contains('aujourd') || t.contains('hier') ||
          t.contains('demain') || t.contains('avant hier') ||
          ['janvier','fevrier','mars','avril','mai','juin','juillet',
           'aout','septembre','octobre','novembre','decembre'].any((m) => t.contains(m)) ||
          RegExp(r'\ble\s+\d{1,2}\b').hasMatch(t);

      if (hCorr.length >= 2) {
        // Correction d'heures de garde (début + fin)
        setState(() {
          _debutHeureCtrl.text = hCorr[0][0].toString().padLeft(2,'0');
          _debutMinCtrl.text   = hCorr[0][1].toString().padLeft(2,'0');
          _finHeureCtrl.text   = hCorr[1][0].toString().padLeft(2,'0');
          _finMinCtrl.text     = hCorr[1][1].toString().padLeft(2,'0');
        });
        final dStr = hCorr[0][1] > 0 ? '${hCorr[0][0]} heures ${hCorr[0][1]}' : '${hCorr[0][0]} heures';
        final fStr = hCorr[1][1] > 0 ? '${hCorr[1][0]} heures ${hCorr[1][1]}' : '${hCorr[1][0]} heures';
        _etatConv = 'pause';
        await _parler('Pas de problème, j\'ai corrigé : de $dStr à $fStr. Avez-vous fait une coupure ?');
      } else if (hCorr.length == 1 && hCorr[0][0] >= 4 && !t.contains('coupure') && !t.contains('pause')) {
        // 1 heure valide (ex: 13h10) → corrige l'heure de fin
        final hF = hCorr[0][0];
        final mF = hCorr[0][1];
        setState(() {
          _finHeureCtrl.text = hF.toString().padLeft(2,'0');
          _finMinCtrl.text   = mF.toString().padLeft(2,'0');
        });
        final fStr = mF > 0 ? '$hF heures $mF' : '$hF heures';
        _etatConv = 'pause';
        await _parler('Pas de problème, heure de fin corrigée à $fStr. Avez-vous fait une coupure ?');
      } else if (t.contains('coupure') || t.contains('pause') || t.contains('min') ||
                 (hCorr.length == 1 && hCorr.isNotEmpty && hCorr[0][0] < 4)) {
        // Correction d'une durée de coupure (petite valeur = minutes/heures de pause)
        final mins = _parseMinutes(t);
        if (mins > 0) {
          setState(() { _avecPause = true; _pauseMinutes = mins; });
          final pauseStr = mins >= 60
              ? '${mins ~/ 60} heure${mins ~/ 60 > 1 ? "s" : ""}${mins % 60 > 0 ? " et ${mins % 60} minutes" : ""}'
              : '$mins minutes';
          _etatConv = 'achats';
          await _parler('Pas de problème, coupure de $pauseStr. Quels ont été vos achats divers ?');
        } else {
          // Pas de durée trouvée → retour à l'étape précédente
          final etatsOrdre2 = ['date','heures','pause','duree_pause','achats','autres_achats','fin_achats','confirmer'];
          final idx2 = etatsOrdre2.indexOf(_etatConv);
          if (idx2 > 0) { _etatConv = etatsOrdre2[idx2 - 1]; }
          await _parler('Désolé, nous allons reprendre.');
        }
      } else if (contientDateExplicite) {
        // Correction de date
        _analyserVoix(rep);
        final moisN = ['','janvier','fevrier','mars','avril','mai','juin',
            'juillet','aout','septembre','octobre','novembre','decembre'];
        final jour = _date.day == 1 ? 'premier' : '${_date.day}';
        final mois = moisN[_date.month];
        _etatConv = 'heures';
        await _parler('Pas de problème, j\'ai noté le $jour $mois. Quels sont les horaires ?');
      } else {
        // Retour à l'étape précédente — repose la bonne question
        // Flux CP/non-travaillé a son propre ordre de retour
        final etatsOrdreCP = {'conge_fin': 'conge_debut', 'conge_debut': 'date'};
        if (etatsOrdreCP.containsKey(_etatConv)) {
          final etatPrec = etatsOrdreCP[_etatConv]!;
          _etatConv = etatPrec;
          final qCP = etatPrec == 'date' ? 'Quelle garde dois-je inscrire ?' :
                      etatPrec == 'conge_debut' ? 'Quel est le premier jour ?' : '';
          await _parler('Désolé, nous allons reprendre. $qCP');
          return;
        }
        final etatsOrdre = ['date','heures','pause','duree_pause','demande_achats','achats','autres_achats','fin_achats','longue_distance','montant_longue_distance','confirmer'];
        final questions = {
          'date': 'Quelle garde dois-je inscrire ?',
          'heures': 'Quels sont les horaires ?',
          'pause': 'Avez-vous fait une coupure ?',
          'duree_pause': 'Combien de minutes de coupure ?',
          'achats': 'Quels ont été vos achats divers ?',
          'autres_achats': 'Avez-vous d\'autres achats ?',
          'fin_achats': 'Est-ce tout ?',
          'confirmer': 'Dois-je sauvegarder cette garde ?',
          'conge_debut': 'Quelle est la date de début ?',
          'conge_fin': 'Quelle est la date de fin du congé ?',
        };
        final idxActuel = etatsOrdre.indexOf(_etatConv);
        if (idxActuel > 0) {
          _etatConv = etatsOrdre[idxActuel - 1];
          final question = questions[_etatConv] ?? 'Pouvez-vous répéter ?';
          await _parler('Désolé, nous allons reprendre. $question');
          // Sécurité : relance l'écoute si le completionHandler ne se déclenche pas
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && !_ecoute && !_ttsActif && _etatConv.isNotEmpty) _ecouterReponse();
          });
        } else {
          _etatConv = 'date';
          await _parler('Désolé, nous allons reprendre depuis le début. Quelle garde dois-je inscrire ?');
        }
      }
      return;
    }

    // Véhicule — détectable à tout moment
    if (t.contains('vehicule') || t.contains('voiture') || t.contains('ambulance') ||
        t.contains('vsl') || t.contains('smur') ||
        RegExp(r'\b(ford|renault|peugeot|citroen|toyota|mercedes|volkswagen|fiat|opel|'
               r'scenic|kangoo|transit|master|sprinter|boxer|ducato|jumper|'
               r'mercedes|308|301|320|321|partner|dokker|trafic|\d{3})\b').hasMatch(t)) {
      _analyserVoix(rep);
      final veh = _vehiculeCtrl.text;
      if (veh.isNotEmpty) {
        final questions = {
          'achats': 'Quels ont ete vos achats divers ?',
          'autres_achats': 'Avez-vous d\'autres achats ?',
          'pause': 'Avez-vous fait une coupure ?',
          'heures': 'Quels sont les horaires ?',
          'fin_achats': 'Est-ce tout ?',
          'confirmer': 'Dois-je sauvegarder cette garde ?',
        };
        final suite = questions[_etatConv] ?? '';
        await _parler(suite.isNotEmpty ? 'Vehicule $veh. $suite' : 'Vehicule $veh.');
        return;
      }
    }

    // Collègue — détectable à tout moment
    if (t.contains('avec') || t.contains('collegue') || t.contains('binome') ||
        t.contains('equipier') || t.contains('jess') || t.contains('etais avec') ||
        t.contains('travaille avec')) {
      _analyserVoix(rep);
      final col = _collegueCtrl.text;
      if (col.isNotEmpty) {
        final questions = {
          'achats': 'Quels ont ete vos achats divers ?',
          'autres_achats': 'Avez-vous d\'autres achats ?',
          'pause': 'Avez-vous fait une coupure ?',
          'heures': 'Quels sont les horaires ?',
          'fin_achats': 'Est-ce tout ?',
          'confirmer': 'Dois-je sauvegarder cette garde ?',
        };
        final suite = questions[_etatConv] ?? '';
        await _parler(suite.isNotEmpty ? 'Colleague $col note. $suite' : 'Colleague $col note.');
        return;
      }
    }

    // Coupure/pause — détectable à tout moment
    if (_etatConv != 'confirmer' && _etatConv != 'fin_achats' && _etatConv != 'confirmer_doublon' &&
        (t.contains('pause') || t.contains('coupure') || t.contains('j ai une') || t.contains('j avais')) &&
        (t.contains('min') || t.contains('heure') || RegExp(r'\d').hasMatch(t))) {
      final mins = _parseMinutes(t);
      if (mins > 0) {
        setState(() { _avecPause = true; _pauseMinutes = mins; });
        final pauseStr = mins >= 60
            ? '${mins ~/ 60} heure${mins ~/ 60 > 1 ? "s" : ""}${mins % 60 > 0 ? " et ${mins % 60} minutes" : ""}'
            : '$mins minutes';
        // Reste dans l'état courant
        final questions = {
          'achats': 'Quels ont ete vos achats divers ?',
          'autres_achats': 'Avez-vous d\'autres achats ?',
          'fin_achats': 'Est-ce tout ?',
          'confirmer': 'Dois-je sauvegarder cette garde ?',
        };
        final suite = questions[_etatConv] ?? '';
        if (suite.isNotEmpty) {
          await _parler('Coupure de $pauseStr notee. $suite');
        } else {
          await _parler('Coupure de $pauseStr notee.');
        }
        return;
      }
    }

    // Suppression d'un achat pendant la conversation
    if (t.contains('efface') || t.contains('retire') || t.contains('enleve') || t.contains('supprime')) {
      // "efface moi" / "réinitialise moi" = reinit global
      if ((t == 'efface moi' || t == 'efface' || t == 'reinitialise' || t == 'annule' ||
           t.contains('reinitialise') || t.contains('efface tout') || t.contains('tout effacer')) &&
          !t.contains('achat') && !t.contains('cafe') && !t.contains('sandwich') &&
          !t.contains('essence') && !t.contains('conge')) {
        _reinitialiserFormulaire();
        await _parler('Formulaire réinitialisé.');
        return;
      }
      // Détecte si c'est une demande d'effacement de CP/non-travaillé (pas d'achat)
      if (t.contains('conge') || t.contains('cp') || t.contains('non travaille') ||
          t.contains('ferie') || t.contains('jour non')) {
        // Cherche et supprime les CP dans toutesGardes via le callback
        final cpIds = widget.toutesGardes
            .where((g) => g.isCongesPaies || g.jourNonTravaille)
            .map((g) => g.id)
            .toList();
        if (cpIds.isNotEmpty && widget.onSupprimerGardeId != null) {
          for (final id in cpIds) widget.onSupprimerGardeId!(id);
          _reinitialiserFormulaire();
          await _parler('Conges supprimes. Quelle garde dois-je inscrire ?');
        } else {
          setState(() {
            _isCongesPaies = false;
            _jourNonTravaille = false;
            _cpDateFin = null;
            _etatConv = 'date';
          });
          await _parler('Pas de congés enregistrés. Quelle garde dois-je inscrire ?');
        }
        return;
      }
      final avant = _achats.length;
      _analyserVoix(rep);

      if (_achats.length < avant) {
        // Réponses variées
        final repOk = [
          'Très bien, je vais faire ça.',
          'Parfait, considéré comme fait.',
          'C\'est fait.',
          'Bien sûr, c\'est supprimé.',
        ];
        repOk.shuffle();
        await _parler(repOk.first);
      } else {
        final repNok = [
          'Je ne trouve pas cet article dans ma liste.',
          'Cet article ne figure pas dans vos achats.',
        ];
        repNok.shuffle();
        await _parler(repNok.first);
      }
      return;
    }

    switch (_etatConv) {

      case 'date':
        // Détection congé payé ou jour non travaillé
        final tDate = rep.toLowerCase()
            .replaceAll('é','e').replaceAll('è','e').replaceAll('à','a')
            .replaceAll("'", ' ');

        // Si la phrase contient efface/retire ET cp → suppression de CP (pas création)
        if ((tDate.contains('efface') || tDate.contains('retire') || tDate.contains('enleve') ||
             tDate.contains('supprime') || tDate.contains('annule')) &&
            (tDate.contains('cp') || tDate.contains('conge'))) {
          final cpIds = widget.toutesGardes
              .where((g) => g.isCongesPaies || g.jourNonTravaille)
              .map((g) => g.id).toList();
          if (cpIds.isNotEmpty && widget.onSupprimerGardeId != null) {
            for (final id in cpIds) widget.onSupprimerGardeId!(id);
            _reinitialiserFormulaire();
            await _parler('Congés supprimés. Quelle garde dois-je inscrire ?');
          } else {
            await _parler('Pas de congés enregistrés. Quelle garde dois-je inscrire ?');
          }
          break;
        }

        if (tDate.contains('conge') || tDate.contains('conges') || tDate.contains('cp') ||
            tDate.contains('vacances')) {
          setState(() { _isCongesPaies = true; _jourNonTravaille = false; });
          // Détecte si une date de début est déjà dans la phrase
          final dateDebutCP = _parseDate(rep);
          final dateDejaPresente = tDate.contains('aujourd') || tDate.contains('hier') ||
              tDate.contains('lundi') || tDate.contains('mardi') || tDate.contains('mercredi') ||
              tDate.contains('jeudi') || tDate.contains('vendredi') || tDate.contains('samedi') ||
              tDate.contains('dimanche') || RegExp(r'\ble\s+\d').hasMatch(tDate) ||
              ['janvier','fevrier','mars','avril','mai','juin','juillet',
               'aout','septembre','octobre','novembre','decembre'].any((m) => tDate.contains(m));
          if (dateDejaPresente) {
            setState(() => _date = dateDebutCP);
            final mN = ['','janvier','fevrier','mars','avril','mai','juin',
                'juillet','aout','septembre','octobre','novembre','decembre'];
            final j = dateDebutCP.day == 1 ? 'premier' : '${dateDebutCP.day}';
            final mo = mN[dateDebutCP.month];
            // Détecte durée dans la phrase ("pendant 6 jours", "6 jours")
            final mDuree = RegExp(r'pendant\s+(\d+)\s*jours?|(\d+)\s*jours?').firstMatch(tDate);
            if (mDuree != null) {
              final nbJ = int.tryParse(mDuree.group(1) ?? mDuree.group(2) ?? '1') ?? 1;
              final dateFin2 = dateDebutCP.add(Duration(days: nbJ - 1));
              setState(() { _cpDateFin = dateFin2; });
              final jF = dateFin2.day == 1 ? 'premier' : '${dateFin2.day}';
              final moF = mN[dateFin2.month];
              _etatConv = 'confirmer';
              await _parler('Congés du $j $mo au $jF $moF, soit $nbJ jours. Dois-je sauvegarder ?');
            } else {
              _etatConv = 'conge_fin';
              await _parler('Entendu, congés à partir du $j $mo. Quel est le dernier jour ?');
            }
          } else {
            _etatConv = 'conge_debut';
            await _parler('Entendu, congés payés. Quel est le premier jour ?');
          }
          break;
        }
        if (tDate.contains('non travaille') || tDate.contains('pas travaille') ||
            tDate.contains('jour ferie') || tDate.contains('ferie') ||
            tDate.contains('repos') || tDate.contains('absent')) {
          setState(() { _jourNonTravaille = true; _isCongesPaies = false; });
          _etatConv = 'conge_debut';
          await _parler('Noté, jour non travaillé. Quelle est la date ?');
          break;
        }
        final nowD = DateTime.now();
        if (tDate.contains('avant-hier') || tDate.contains('avant hier') || tDate.contains('avanthier')) {
          setState(() => _date = nowD.subtract(const Duration(days: 2)));
        } else if (tDate.contains('hier')) {
          setState(() => _date = nowD.subtract(const Duration(days: 1)));
        } else if (tDate.contains('aujourd') || tDate.contains('maintenant')) {
          setState(() => _date = nowD);
        } else {
          // Vérifie d'abord si un mois est mentionné (janvier, février, mars...)
          const moisNoms2 = ['janvier','fevrier','mars','avril','mai','juin',
              'juillet','aout','septembre','octobre','novembre','decembre'];
          final contientMois = moisNoms2.any((m) => tDate.contains(m));
          if (contientMois) {
            // Utilise _parseDate qui gère correctement les noms de mois
            final dateAvecMois = _parseDate(rep);
            setState(() => _date = dateAvecMois);
          } else {
            // Chiffre seul → jour du mois courant ("le 10" ou juste "10")
            final mJseul = RegExp(r'\b(\d{1,2})\b').firstMatch(tDate);
            if (mJseul != null && !tDate.contains('h') && !tDate.contains('heure')) {
              final j = int.tryParse(mJseul.group(1) ?? '') ?? nowD.day;
              if (j >= 1 && j <= 31) {
                setState(() => _date = DateTime(nowD.year, nowD.month, j));
              } else {
                _analyserVoix(rep);
              }
            } else {
              _analyserVoix(rep); // parser complet pour les autres cas
            }
          }
        }
        // Détecte aussi les heures si elles sont dans la même phrase
        String tHD = rep.toLowerCase().replaceAll('heures','h').replaceAll('heure','h')
            .replaceAll('é','e').replaceAll('è','e').replaceAll('à','a').replaceAll('â','a');
        tHD = tHD.replaceAllMapped(RegExp(r'(\d{1,2})\s+h'), (m) => '${m.group(1)}h');
        final heuresDate = <List<int>>[];
        for (final mh in RegExp(r'(\d{1,2})h(\d{2})?').allMatches(tHD)) {
          final h = int.tryParse(mh.group(1) ?? '') ?? -1;
          final mn = int.tryParse(mh.group(2) ?? '0') ?? 0;
          if (h >= 0 && h <= 23) heuresDate.add([h, mn]);
        }
        if (heuresDate.length < 2) {
          // Fallback: cherche tous les nombres 0-23 dans le texte
          final nums = RegExp(r'\b(\d{1,2})\b').allMatches(tHD)
              .map((m) => int.tryParse(m.group(1) ?? '') ?? -1)
              .where((n) => n >= 0 && n <= 23).toList();
          if (heuresDate.isEmpty && nums.length >= 2) {
            // Aucune heure trouvée — utilise les nombres bruts
            heuresDate.add([nums[0], 0]);
            heuresDate.add([nums[1], 0]);
          } else if (heuresDate.length == 1 && nums.length >= 2) {
            // Une heure trouvée — cherche la 2e parmi les nombres restants
            final dejaH = heuresDate[0][0];
            final autre = nums.firstWhere((n) => n != dejaH, orElse: () => -1);
            if (autre >= 0) heuresDate.add([autre, 0]);
          }
        }
        final moisN = ['','janvier','fevrier','mars','avril','mai','juin',
            'juillet','aout','septembre','octobre','novembre','decembre'];
        final jour = _date.day == 1 ? 'premier' : '${_date.day}';
        final mois = moisN[_date.month];
        final conf = 'Très bien, pour le $jour $mois.';
        if (heuresDate.length >= 2) {
          setState(() {
            _debutHeureCtrl.text = heuresDate[0][0].toString().padLeft(2,'0');
            _debutMinCtrl.text   = heuresDate[0][1].toString().padLeft(2,'0');
            _finHeureCtrl.text   = heuresDate[1][0].toString().padLeft(2,'0');
            _finMinCtrl.text     = heuresDate[1][1].toString().padLeft(2,'0');
          });
          _etatConv = 'pause';
          await _parler('$conf De ${heuresDate[0][0]} heures à ${heuresDate[1][0]} heures, avez-vous fait une coupure ?');
        } else {
          _etatConv = 'heures';
          await _parler('$conf Quels sont les horaires ?');
        }
        break;

      case 'heures':
        // Parser dédié pour la conversation — plus robuste que _analyserVoix
        String tH = rep.toLowerCase()
            .replaceAll('heures', 'h').replaceAll('heure', 'h')
            .replaceAll('é','e').replaceAll('è','e').replaceAll('à','a');
        // "8 h 20" → "8h20" puis sépare, "20 h" → "20h"
        tH = tH.replaceAllMapped(RegExp(r'(\d{1,2})\s+h'), (m) => '${m.group(1)}h');
        final heures = <List<int>>[];
        for (final m in RegExp(r'(\d{1,2})h(\d{2})?').allMatches(tH)) {
          final h = int.tryParse(m.group(1) ?? '') ?? -1;
          final mn = int.tryParse(m.group(2) ?? '0') ?? 0;
          if (h >= 0 && h <= 23) heures.add([h, mn]);
        }
        // Si moins de 2 heures trouvées, cherche 2 nombres distincts
        if (heures.length < 2) {
          final nums = RegExp(r'\b(\d{1,2})\b').allMatches(tH)
              .map((m) => int.tryParse(m.group(1) ?? '') ?? -1)
              .where((n) => n >= 0 && n <= 23).toList();
          if (heures.isEmpty && nums.length >= 2) {
            heures.add([nums[0], 0]);
            heures.add([nums[1], 0]);
          } else if (heures.length == 1 && nums.length >= 2) {
            final dejaH = heures[0][0];
            final autre = nums.firstWhere((n) => n != dejaH, orElse: () => -1);
            if (autre >= 0) heures.add([autre, 0]);
          }
        }
        if (heures.length >= 2) {
          setState(() {
            _debutHeureCtrl.text = heures[0][0].toString().padLeft(2,'0');
            _debutMinCtrl.text   = heures[0][1].toString().padLeft(2,'0');
            _finHeureCtrl.text   = heures[1][0].toString().padLeft(2,'0');
            _finMinCtrl.text     = heures[1][1].toString().padLeft(2,'0');
          });
        } else if (heures.length == 1) {
          setState(() {
            _debutHeureCtrl.text = heures[0][0].toString().padLeft(2,'0');
            _debutMinCtrl.text   = heures[0][1].toString().padLeft(2,'0');
          });
        }
        final dhI = int.tryParse(_debutHeureCtrl.text) ?? 0;
        final dmI = int.tryParse(_debutMinCtrl.text) ?? 0;
        final fhI = int.tryParse(_finHeureCtrl.text) ?? 0;
        final fmI = int.tryParse(_finMinCtrl.text) ?? 0;
        final dStr = dmI > 0 ? '$dhI heures $dmI' : '$dhI heures';
        final fStr = fmI > 0 ? '$fhI heures $fmI' : '$fhI heures';
        _etatConv = 'pause';
        // Phrase courte pour éviter la coupure TTS
        await _parler('De $dStr à $fStr, avez-vous fait une coupure ?');
        break;

      case 'pause':
        if (t.contains('non') || t.contains('pas') || t.contains('aucune')) {
          setState(() { _avecPause = false; _pauseMinutes = 0; });
          _etatConv = 'demande_achats';
          await _parler('Pas de coupure. Avez-vous effectué des achats ?');
        } else if (RegExp(r'\d').hasMatch(t) || t.contains('heure') || t.contains('minute') || t.contains('min') || t.contains('une h')) {
          // Contient une durée → parse directement
          final mins = _parseMinutes(t);
          if (mins > 0) {
            setState(() { _avecPause = true; _pauseMinutes = mins; });
            _etatConv = 'demande_achats';
            final pauseStr = mins >= 60 ? '${mins ~/ 60} heure${mins ~/ 60 > 1 ? "s" : ""}${mins % 60 > 0 ? " et ${mins % 60} minutes" : ""}' : '$mins minutes';
            await _parler('Coupure de $pauseStr. Avez-vous effectué des achats ?');
          } else {
            // Nombre non reconnu → demande
            setState(() => _avecPause = true);
            _etatConv = 'duree_pause';
            await _parler('Combien de minutes de coupure ?');
          }
        } else if (t.contains('oui')) {
          setState(() => _avecPause = true);
          _etatConv = 'duree_pause';
          await _parler('Combien de minutes de coupure ?');
        } else {
          await _parler('Avez-vous fait une coupure ? Répondez oui ou non.');
        }
        break;

      case 'duree_pause':
        final mins = _parseMinutes(t);
        if (mins > 0) {
          setState(() { _pauseMinutes = mins; });
          _etatConv = 'demande_achats';
          final pauseStr = mins >= 60 ? '${mins ~/ 60} heure${mins ~/ 60 > 1 ? "s" : ""}${mins % 60 > 0 ? " et ${mins % 60} minutes" : ""}' : '$mins minutes';
          await _parler('Coupure de $pauseStr. Avez-vous effectué des achats ?');
        } else {
          await _parler('Combien de minutes de coupure ?');
        }
        break;

      case 'demande_achats':
        if (t.contains('oui') || t.contains('j ai') || t.contains('achats') || t.contains('cafe') ||
            t.contains('essence') || t.contains('repas') || t.contains('boisson')) {
          _etatConv = 'achats';
          await _parler('Quels ont été vos achats ?');
        } else if (t.contains('non') || t.contains('rien') || t.contains('aucun') || t.contains('pas')) {
          if (!_isCongesPaies && !_jourNonTravaille) {
            _etatConv = 'longue_distance';
            await _parler('Avez-vous eu une prime longue distance ?');
          } else {
            _etatConv = 'confirmer';
            await _parler('Dois-je sauvegarder cette garde ?');
          }
        } else {
          await _parler('Avez-vous effectué des achats ? Répondez oui ou non.');
        }
        break;

      case 'achats':
        if (t.contains('rien') || t.contains('aucun') || t.contains('c est tout') ||
            t.contains('termine') || t.contains('pas d achat') || t.contains('pas de frais') ||
            (t.contains('non') && t.length < 8)) {
                    if (!_isCongesPaies && !_jourNonTravaille) {
            _etatConv = 'longue_distance';
            await _parler('Avez-vous eu une prime longue distance ?');
          } else {
            _etatConv = 'confirmer';
            await _parler('Dois-je sauvegarder cette garde ?');
          }
        } else {
          final avant = _achats.length;
          _analyserVoix(rep);
          if (_achats.length > avant) {
            _etatConv = 'autres_achats';
            await _parler('Très bien. Avez-vous d\'autres achats ?');
          } else {
            final mots = ['cafe','chocolat','the','tisane','sandwich','croissant',
                'boisson','pizza','jus','eau','repas','essence','carburant','gasoil',
                'red bull','redbull','monster','orangina','fanta','coca','coca cola','coca-cola','pepsi','limonade','schweppes'];
            final nom = mots.firstWhere((m) => t.contains(m), orElse: () => '');
            if (nom.isNotEmpty) {
              _articleEnAttente = nom;
              _etatConv = 'prix_achat';
              await _parler('Quel est le prix de $nom ?');
            } else {
              await _parler('Je n\'ai pas reconnu cet achat. Pouvez-vous préciser ? Dites par exemple : un café à un euro cinquante, ou bien : rien.');
            }
          }
        }
        break;

      case 'prix_achat':
        String rn = t
            .replaceAllMapped(RegExp(r'(\d+)\s+euros?\s+(\d{1,2})'),
                (m) => '${m.group(1)}.${m.group(2)!.padLeft(2,"0")}')
            .replaceAll(RegExp(r'euros?'), '')
            .replaceAllMapped(RegExp(r'(\d{1,3})\s*(?:centimes?|cts?)'),
                (m) { final v = (int.tryParse(m.group(1) ?? '0') ?? 0) / 100; return v.toStringAsFixed(2); })
            .replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m.group(1)}.${m.group(2)}');
        final mp = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(rn);
        if (mp != null) {
          final montant = double.tryParse(mp.group(1) ?? '0') ?? 0;
          if (montant > 0) {
            _achats.add(Achat(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              intitule: _capitaliser(_articleEnAttente),
              montant: montant,
            ));
            setState(() {});
            _etatConv = 'autres_achats';
            await _parler('${_capitaliser(_articleEnAttente)}, ${_montantEnMots(montant)}. Avez-vous d\'autres achats ?');
            break;
          }
        }
        await _parler('Je n\'ai pas compris le prix. Dites par exemple : un euro cinquante.');
        break;

      case 'autres_achats':
        if (t.contains('rien') || t.contains('c est tout') || t.contains('suffit') ||
            t.contains('termine') || t.contains('pas d autre') || t.contains('pas de frais') ||
            (t.contains('non') && t.length < 8)) {
                    if (!_isCongesPaies && !_jourNonTravaille) {
            _etatConv = 'longue_distance';
            await _parler('Avez-vous eu une prime longue distance ?');
          } else {
            _etatConv = 'confirmer';
            await _parler('Dois-je sauvegarder cette garde ?');
          }
        } else {
          _etatConv = 'achats';
          await _traiterReponse(rep);
        }
        break;

      case 'fin_achats':
        if (t.contains('oui') || t.contains('c est tout') || t.contains('suffit') ||
            t.contains('termine') || t.contains('rien')) {
          if (!_isCongesPaies && !_jourNonTravaille) {
            _etatConv = 'longue_distance';
            await _parler('Avez-vous eu une prime longue distance ?');
          } else {
            _etatConv = 'confirmer';
            await _parler('Dois-je sauvegarder cette garde ?');
          }
        } else if (t.contains('non') || t.contains('encore') || t.contains('autre')) {
          _etatConv = 'achats';
          await _parler('D\'accord. Quels autres achats ?');
        } else {
          await _parler('Est-ce tout ? Répondez oui ou non.');
        }
        break;

      case 'longue_distance':
        if (t.contains('oui') || t.contains('longue') || t.contains('prime')) {
          _etatConv = 'montant_longue_distance';
          await _parler('Quel est le montant de la prime longue distance ?');
        } else if (t.contains('non') || t.contains('pas') || t.contains('aucune')) {
          setState(() { _avecLongueDistance = false; _primeLongueDistance = 0; _longuePrimeCtrl.clear(); });
          _etatConv = 'confirmer';
          await _parler('Dois-je sauvegarder cette garde ?');
        } else {
          await _parler('Avez-vous eu une prime longue distance ? Répondez oui ou non.');
        }
        break;

      case 'montant_longue_distance':
        {
          final mMontant = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(t);
          if (mMontant != null) {
            final montant = double.tryParse(mMontant.group(1)!.replaceAll(',', '.')) ?? 0;
            setState(() {
              _avecLongueDistance = true;
              _primeLongueDistance = montant;
              _longuePrimeCtrl.text = montant.toStringAsFixed(2);
            });
            _etatConv = 'confirmer';
            await _parler('Prime longue distance de ${montant.toStringAsFixed(0)} euros enregistrée. Dois-je sauvegarder cette garde ?');
          } else {
            await _parler('Je n\'ai pas compris le montant. Répétez le montant en euros, par exemple cinquante euros.');
          }
        }
        break;

      case 'conge_debut':
        {
          final dateD = _parseDate(rep);
          setState(() => _date = dateD);
          final moisNCD = ['','janvier','fevrier','mars','avril','mai','juin',
              'juillet','aout','septembre','octobre','novembre','decembre'];
          final jourDebutD = dateD.day == 1 ? 'premier' : dateD.day.toString();
          final moisDebutD = moisNCD[dateD.month];
          if (_isCongesPaies) {
            _etatConv = 'conge_fin';
            await _parler('Du $jourDebutD $moisDebutD. Quel est le dernier jour des congés ?');
          } else {
            _etatConv = 'confirmer';
            await _parler('Jour non travaille le $jourDebutD $moisDebutD. Dois-je sauvegarder ?');
          }
        }
        break;

      case 'conge_fin':
        {
        final dateDebutSaved = _date;
        final moisNC2 = ['','janvier','fevrier','mars','avril','mai','juin',
            'juillet','aout','septembre','octobre','novembre','decembre'];
        final jourD2 = dateDebutSaved.day == 1 ? 'premier' : '${dateDebutSaved.day}';
        final moisD2 = moisNC2[dateDebutSaved.month];
        // Détecte "pendant X jours" ou "X jours"
        final mDuree2 = RegExp(r'pendant\s+(\d+)\s*jours?|(\d+)\s*jours?').firstMatch(t);
        DateTime dateFin;
        int? nbJoursTotal;
        if (mDuree2 != null) {
          nbJoursTotal = int.tryParse(mDuree2.group(1) ?? mDuree2.group(2) ?? '1') ?? 1;
          dateFin = dateDebutSaved.add(Duration(days: nbJoursTotal - 1));
        } else {
          dateFin = _parseDate(rep);
        }
        setState(() {
          _date = dateDebutSaved;
          _cpDateFin = dateFin;
          _isCongesPaies = true;
          _jourNonTravaille = false;
        });
        final jourF = dateFin.day == 1 ? 'premier' : '${dateFin.day}';
        final moisF = moisNC2[dateFin.month];
        _etatConv = 'confirmer';
        if (nbJoursTotal != null) {
          await _parler('Conges payes du $jourD2 $moisD2 pendant $nbJoursTotal jours, jusqu au $jourF $moisF. Dois-je sauvegarder ?');
        } else {
          await _parler('Conges payes du $jourD2 $moisD2 au $jourF $moisF. Dois-je sauvegarder ?');
        }
        }
        break;

      case 'cp_conflict':
        if (t.contains('annule') || t.contains('supprime') || t.contains('conge') ||
            t.contains('oui')) {
          // Supprime le CP et garde la date choisie
          final cpIds = widget.toutesGardes
              .where((g) => g.isCongesPaies)
              .map((g) => g.id).toList();
          if (widget.onSupprimerGardeId != null) {
            for (final id in cpIds) widget.onSupprimerGardeId!(id);
          }
          _etatConv = 'heures';
          await _parler('Conges annules. Quels sont les horaires ?');
        } else if (t.contains('changer') || t.contains('modifier') || t.contains('non') ||
                   t.contains('autre') || t.contains('date')) {
          _etatConv = 'date';
          await _parler('D\'accord. Quelle autre date ?');
        } else {
          await _parler('Voulez-vous annuler le congé ou changer la date ?');
        }
        break;

      case 'confirmer':
        if (t.contains('oui') || t.contains('sauvegarde') || t.contains('enregistre') ||
            t.contains('c est bon') || t.contains('parfait') || t.contains('valide') ||
            t.contains('ok') || t == 'oui' || t.trim() == 'oui') {
          // Vérifie doublon avant d'enregistrer
          if (!_isCongesPaies && !_jourNonTravaille) {
            final estModif = widget.gardeAModifier != null;
            final gardeExistante = widget.toutesGardes.where((g) {
              if (g.isCongesPaies || g.jourNonTravaille) return false;
              if (estModif && g.id == widget.gardeAModifier!.id) return false;
              final gD = DateTime(g.date.year, g.date.month, g.date.day);
              final cible = DateTime(_date.year, _date.month, _date.day);
              return gD == cible;
            }).firstOrNull;
            if (gardeExistante != null) {
              _etatConv = 'confirmer_doublon';
              final mN = ['','janvier','fevrier','mars','avril','mai','juin','juillet','aout','septembre','octobre','novembre','decembre'];
              final jW = _date.day == 1 ? 'premier' : '${_date.day}';
              final moW = mN[_date.month];
              await _parler('Attention, il y a deja une garde le $jW $moW. Voulez-vous quand meme enregistrer ?');
              break;
            }
          }
          setState(() => _etatConv = '');
          await _tts.stop();
          if (_isCongesPaies) {
            final debutCP = DateTime(_date.year, _date.month, _date.day);
            final finCP = _cpDateFin != null ? DateTime(_cpDateFin!.year, _cpDateFin!.month, _cpDateFin!.day) : debutCP;
            final estModif = widget.gardeAModifier != null;
            // CP-on-CP → alerte orale + blocage
            final conflitCP = widget.toutesGardes.where((g) {
              if (!g.isCongesPaies) return false;
              if (estModif && g.id == widget.gardeAModifier!.id) return false;
              final gDate = DateTime(g.date.year, g.date.month, g.date.day);
              final gFin = g.cpDateFin != null ? DateTime(g.cpDateFin!.year, g.cpDateFin!.month, g.cpDateFin!.day) : gDate;
              return !(finCP.isBefore(gDate) || debutCP.isAfter(gFin));
            }).firstOrNull;
            if (conflitCP != null) {
              await _parler('Attention, des congés payés sont déjà enregistrés sur cette période. Enregistrement annulé.');
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('⛔ Période déjà saisie en congés payés',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ));
              return;
            }
            // CP-on-garde → alerte orale + demande confirmation
            final gardesConflits = widget.toutesGardes.where((g) {
              if (g.isCongesPaies || g.jourNonTravaille) return false;
              if (estModif && g.id == widget.gardeAModifier!.id) return false;
              final gDate = DateTime(g.date.year, g.date.month, g.date.day);
              return !gDate.isBefore(debutCP) && !gDate.isAfter(finCP);
            }).toList();
            if (gardesConflits.isNotEmpty) {
              final nbG = gardesConflits.length;
              setState(() => _etatConv = 'confirmer_cp_garde');
              await _parler('Attention, ${nbG > 1 ? "$nbG gardes sont" : "une garde est"} déjà enregistrée${nbG > 1 ? "s" : ""} sur cette période. Voulez-vous enregistrer le congé quand même ?');
              return;
            }
          }
          _enregistrerGarde();
          await _parler(_isCongesPaies ? 'Congés payés enregistrés !' : 'Parfait, garde enregistrée !');
          Future.delayed(const Duration(milliseconds: 2000), () {
            if (mounted) _reinitialiserFormulaire();
          });
        } else if (t.contains('non') || t.contains('annule') || t.contains('modifier')) {
          _reinitialiserFormulaire();
          await _parler('D\'accord, formulaire réinitialisé.');
        } else {
          await _parler('Dois-je sauvegarder cette garde ? Dites oui ou non.');
        }
        break;

      case 'confirmer_doublon':
        if (t.contains('oui') || t.contains('quand meme') || t.contains('confirme')) {
          setState(() => _etatConv = '');
          _enregistrerGarde();
          await _parler('Garde enregistrée !');
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (mounted) setState(() {
              _date = DateTime.now();
              _debutHeureCtrl.text = '07'; _debutMinCtrl.text = '00';
              _finHeureCtrl.text = '17'; _finMinCtrl.text = '00';
              _avecPause = false; _pauseMinutes = 0;
              _avecPanier = false; _achats = [];
              _collegueCtrl.text = ''; _vehiculeCtrl.text = '';
              _isCongesPaies = false; _jourNonTravaille = false; _cpDateFin = null;
              _etatConv = '';
            });
          });
        } else {
          setState(() {
            _etatConv = '';
            // Réinitialise le formulaire
            _date = DateTime.now();
            _debutHeureCtrl.text = '07';
            _debutMinCtrl.text = '00';
            _finHeureCtrl.text = '17';
            _finMinCtrl.text = '00';
            _avecPause = false; _pauseMinutes = 0;
            _avecPanier = false;
            _achats = [];
            _collegueCtrl.text = '';
            _vehiculeCtrl.text = '';
            _isCongesPaies = false;
            _jourNonTravaille = false;
            _cpDateFin = null;
          });
          await _parler('D\'accord, garde annulée. Formulaire réinitialisé.');
        }
        break;

      case 'confirmer_cp_garde':
        if (t.contains('oui') || t.contains('quand meme') || t.contains('confirme') || t.contains('enregistre')) {
          setState(() => _etatConv = '');
          _enregistrerGarde();
          await _parler('Congés payés enregistrés !');
          Future.delayed(const Duration(milliseconds: 2000), () {
            if (mounted) _reinitialiserFormulaire();
          });
        } else if (t.contains('non') || t.contains('annule')) {
          _reinitialiserFormulaire();
          await _parler('D\'accord, enregistrement annulé.');
        } else {
          await _parler('Voulez-vous enregistrer le congé quand même ? Dites oui ou non.');
        }
        break;
    }
  }

  void _arreterEcoute() {
    // Arrête uniquement l'écoute — NE réinitialise PAS la conversation
    _tts.stop();
    _speech.stop();
    setState(() { _ecoute = false; _ttsActif = false; _texteVocal = ''; });
    // _etatConv conservé pour pouvoir reprendre
  }

  // Vérifie chevauchement CP — retourne true si conflit (et affiche message)
  bool _checkCPChevauchement() {
    if (!_isCongesPaies) return false;
    final debutCP = DateTime(_date.year, _date.month, _date.day);
    final finCP = _cpDateFin != null
        ? DateTime(_cpDateFin!.year, _cpDateFin!.month, _cpDateFin!.day)
        : debutCP;
    final estModif = widget.gardeAModifier != null;

    final chevauchement = widget.toutesGardes.where((g) {
      if (estModif && g.id == widget.gardeAModifier!.id) return false;
      final gDate = DateTime(g.date.year, g.date.month, g.date.day);
      if (g.isCongesPaies) {
        final gFin = g.cpDateFin != null
            ? DateTime(g.cpDateFin!.year, g.cpDateFin!.month, g.cpDateFin!.day)
            : gDate;
        return !(finCP.isBefore(gDate) || debutCP.isAfter(gFin));
      } else if (!g.jourNonTravaille) {
        return !gDate.isBefore(debutCP) && !gDate.isAfter(finCP);
      }
      return false;
    }).firstOrNull;

    if (chevauchement != null) {
      final msg = chevauchement.isCongesPaies
          ? '⛔ Période déjà saisie en congés payés'
          : '⛔ Période déjà saisie — une garde existe le ${chevauchement.date.day}/${chevauchement.date.month}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ));
      return true;
    }
    return false;
  }

  void _sauvegarderGarde() {
    if (!mounted) return;
    if (!_isCongesPaies) {
      final dateGarde = _date;

      // ── Check CP existant ──────────────────────────────────────
      final conflitCP = widget.toutesGardes.where((g) {
        if (!g.isCongesPaies) return false;
        if (g.cpDateFin == null) {
          return g.date.year == dateGarde.year &&
              g.date.month == dateGarde.month &&
              g.date.day == dateGarde.day;
        } else {
          final debut = DateTime(g.date.year, g.date.month, g.date.day);
          final fin = DateTime(g.cpDateFin!.year, g.cpDateFin!.month, g.cpDateFin!.day);
          final cible = DateTime(dateGarde.year, dateGarde.month, dateGarde.day);
          return !cible.isBefore(debut) && !cible.isAfter(fin);
        }
      }).firstOrNull;
      if (conflitCP != null) {
        final fin = conflitCP.cpDateFin;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(fin != null
              ? '🏖️ CP du ${conflitCP.date.day}/${conflitCP.date.month} au ${fin.day}/${fin.month} — impossible de saisir une garde.'
              : '🏖️ CP le ${conflitCP.date.day}/${conflitCP.date.month} — impossible de saisir une garde.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
        // Réinitialiser le formulaire pour éviter que le CP reste affiché
        setState(() {
          _isCongesPaies = false; _jourNonTravaille = false; _cpDateFin = null;
          _etatConv = '';
        });
        return;
      }

      // ── Check doublon garde même jour ─────────────────────────
      final estModif = widget.gardeAModifier != null;
      final gardeExistante = widget.toutesGardes.where((g) {
        if (g.isCongesPaies) return false;
        if (g.jourNonTravaille) return false;
        // Ignore la garde en cours de modification
        if (estModif && g.id == widget.gardeAModifier!.id) return false;
        final gDate = DateTime(g.date.year, g.date.month, g.date.day);
        final cible = DateTime(dateGarde.year, dateGarde.month, dateGarde.day);
        return gDate == cible;
      }).firstOrNull;

      if (gardeExistante != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('⚠️ Garde déjà existante'),
            content: Text(
              'Une garde existe déjà le ${dateGarde.day}/${dateGarde.month}/${dateGarde.year} '
              '(${gardeExistante.heureDebut.hour}h${gardeExistante.heureDebut.minute.toString().padLeft(2,'0')} '
              '→ ${gardeExistante.heureFin.hour}h${gardeExistante.heureFin.minute.toString().padLeft(2,'0')}).\n\n'
              'Voulez-vous quand même enregistrer cette nouvelle garde ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _enregistrerGarde();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Enregistrer quand même'),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (_checkCPChevauchement()) return;
    _enregistrerGarde();
  }


  void _reinitialiserFormulaire() {
    setState(() {
      _date = DateTime.now();
      _debutHeureCtrl.text = '07'; _debutMinCtrl.text = '00';
      _finHeureCtrl.text = '17'; _finMinCtrl.text = '00';
      _avecPause = false; _pauseMinutes = 0;
      _avecPanier = false; _achats = [];
      _collegueCtrl.text = ''; _vehiculeCtrl.text = '';
      _isCongesPaies = false; _jourNonTravaille = false; _cpDateFin = null;
      _etatConv = '';
    });
  }
  void _enregistrerGarde() {
    final g = _buildGarde();
    final estModif = widget.gardeAModifier != null;
    if (estModif) { widget.onGardeModifiee!(g); }
    else { widget.onGardeAjoutee(g); }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✓ Garde sauvegardée !'),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 2),
    ));
  }

  void _analyserVoix(String texte) {
    if (texte.trim().isEmpty) return;

    // Normalisation complète
    String t = texte.toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e')
        .replaceAll('î', 'i').replaceAll('ï', 'i')
        .replaceAll('ô', 'o').replaceAll('ù', 'u').replaceAll('û', 'u')
        .replaceAll('ç', 'c')
        // Chiffres en lettres — composés D'ABORD, puis simples
        .replaceAll('trente et un', '31').replaceAll('trente-et-un', '31')
        .replaceAll('trente et une', '31')
        .replaceAll('vingt-neuf', '29').replaceAll('vingt neuf', '29')
        .replaceAll('vingt-huit', '28').replaceAll('vingt huit', '28')
        .replaceAll('vingt-sept', '27').replaceAll('vingt sept', '27')
        .replaceAll('vingt-six', '26').replaceAll('vingt six', '26')
        .replaceAll('vingt-cinq', '25').replaceAll('vingt cinq', '25')
        .replaceAll('vingt-quatre', '24').replaceAll('vingt quatre', '24')
        .replaceAll('vingt-trois', '23').replaceAll('vingt trois', '23')
        .replaceAll('vingt-deux', '22').replaceAll('vingt deux', '22')
        .replaceAll('vingt et un', '21').replaceAll('vingt-et-un', '21')
        .replaceAll('vingt et une', '21')
        .replaceAll('dix-neuf', '19').replaceAll('dix neuf', '19')
        .replaceAll('dix-huit', '18').replaceAll('dix huit', '18')
        .replaceAll('dix-sept', '17').replaceAll('dix sept', '17')
        .replaceAll('vingt', '20').replaceAll('trente', '30')
        .replaceAll('quarante', '40').replaceAll('cinquante', '50')
        .replaceAll('soixante', '60').replaceAll('onze', '11')
        .replaceAll('douze', '12').replaceAll('treize', '13')
        .replaceAll('quatorze', '14').replaceAll('quinze', '15')
        .replaceAll('seize', '16').replaceAll('deux', '2')
        .replaceAll('trois', '3').replaceAll('quatre', '4')
        .replaceAll('cinq', '5').replaceAll('neuf', '9')
        .replaceAll('six', '6').replaceAll('sept', '7').replaceAll('huit', '8')
        .replaceAll('premier', '1').replaceAll('premiere', '1')
        .replaceAll('un', '1').replaceAll('une', '1')
        // Apostrophes et liaisons
        .replaceAll("j'etais", 'jetais').replaceAll("j'étais", 'jetais')
        .replaceAll("j.ai", 'jai').replaceAll("j'ai", 'jai').replaceAll("j'", 'j ')
        .replaceAll('collegue', 'collegue').replaceAll('véhicule', 'vehicule')
        .replaceAll('équipier', 'equipier').replaceAll('binôme', 'binome')
        .replaceAll("jusqu'a", 'a').replaceAll('jusqu a', 'a')
        // "de 6h à 20h" → retire "de" parasite devant un chiffre
        .replaceAllMapped(RegExp(r'\bde\s+(\d)'), (m) => ' ${m.group(1)}')
        .replaceAll(' a ', ' pour ');   // "sandwich à 3€" → "sandwich pour 3"

    final List<String> champsRemplis = [];

    // ── 0b. SUPPRESSION VOCALE DE GARDE ──────────────────────────
    // "supprime la garde", "supprime moi la garde d'hier", "supprime les frais d'essence d'hier"
    if (t.contains('supprime') || t.contains('efface') || t.contains('annule la garde')) {

      // Détecte la date cible
      DateTime? dateCible;
      if (t.contains('hier')) {
        dateCible = DateTime.now().subtract(const Duration(days: 1));
      } else if (t.contains('aujourd')) {
        dateCible = DateTime.now();
      } else if (t.contains('demain')) {
        dateCible = DateTime.now().add(const Duration(days: 1));
      }

      // "supprime la garde" → supprime la garde de la date cible ou actuelle
      if (t.contains('la garde') || t.contains('cette garde') || t.contains('mon tour')) {
        final dateTarget = dateCible ?? _date;
        final garde = widget.toutesGardes.where((g) =>
            g.date.year == dateTarget.year &&
            g.date.month == dateTarget.month &&
            g.date.day == dateTarget.day).firstOrNull;
        if (garde != null && widget.onSupprimerGardeId != null) {
          widget.onSupprimerGardeId!(garde.id);
          _feedback('✓ Garde du ${dateTarget.day}/${dateTarget.month} supprimée');
          return;
        } else if (garde == null && widget.gardeAModifier == null) {
          // Remet à zéro le formulaire actuel
          setState(() {
            _debutHeureCtrl.text = '07'; _debutMinCtrl.text = '00';
            _finHeureCtrl.text = '17'; _finMinCtrl.text = '00';
            _collegueCtrl.text = ''; _vehiculeCtrl.text = '';
            _achats = []; _avecPause = false; _avecPanier = false;
            _jourNonTravaille = false;
          });
          _feedback('✓ Formulaire réinitialisé');
          return;
        }
      }

      // "supprime le congé du 10 avril" / "efface mon congé d'hier"
      if (t.contains('conge') || t.contains('cp') || t.contains('conges payes') ||
          t.contains('conges paye')) {
        final dateTarget = dateCible ?? _date;
        final cp = widget.toutesGardes.where((g) {
          if (!g.isCongesPaies) return false;
          // Si période CP, vérifie que la date cible est dans la plage
          if (g.cpDateFin != null) {
            final debut = DateTime(g.date.year, g.date.month, g.date.day);
            final fin = DateTime(g.cpDateFin!.year, g.cpDateFin!.month, g.cpDateFin!.day);
            final cible = DateTime(dateTarget.year, dateTarget.month, dateTarget.day);
            return !cible.isBefore(debut) && !cible.isAfter(fin);
          }
          return g.date.year == dateTarget.year &&
              g.date.month == dateTarget.month &&
              g.date.day == dateTarget.day;
        }).firstOrNull;
        if (cp != null && widget.onSupprimerGardeId != null) {
          widget.onSupprimerGardeId!(cp.id);
          _feedback('✓ CP du ${cp.date.day}/${cp.date.month} supprimé');
          return;
        } else {
          _feedback('❌ Aucun CP trouvé à cette date');
          return;
        }
      }
      final motsCles = ['essence', 'carburant', 'gasoil', 'parking', 'peage',
          'sandwich', 'cafe', 'chocolat', 'the', 'tisane', 'repas', 'croissant', 'boisson', 'pizza',
            'red bull', 'redbull', 'monster', 'orangina', 'fanta', 'coca', 'coca cola', 'coca-cola', 'pepsi', 'limonade', 'schweppes'];
      for (final mc in motsCles) {
        if (t.contains(mc)) {
          // Cherche si un montant est mentionné
          final regexMontantRetire = RegExp(r'(\d+(?:[.,]\d{1,2})?)\s*(?:euros?|€)?');
          final mmRetire = regexMontantRetire.firstMatch(t);
          final montantRetire = mmRetire != null
              ? double.tryParse(mmRetire.group(1)?.replaceAll(',', '.') ?? '')
              : null;

          final dateTarget = dateCible ?? _date;
          final garde = widget.toutesGardes.where((g) =>
              g.date.year == dateTarget.year &&
              g.date.month == dateTarget.month &&
              g.date.day == dateTarget.day).firstOrNull;
          if (garde != null && widget.onGardeModifiee != null) {
            final achatsModifies = garde.achats.where((a) {
              final matchNom = a.intitule.toLowerCase().contains(mc);
              if (!matchNom) return true; // garde
              if (montantRetire != null) return a.montant != montantRetire; // garde si montant différent
              return false; // retire tout ce qui correspond au nom
            }).toList();
            if (achatsModifies.length < garde.achats.length) {
              final gardeModifiee = Garde(
                id: garde.id, date: garde.date,
                heureDebut: garde.heureDebut, heureFin: garde.heureFin,
                pauseMinutes: garde.pauseMinutes, avecPanier: garde.avecPanier,
                panierRepasGarde: garde.panierRepasGarde,
                jourNonTravaille: garde.jourNonTravaille,
                collegue: garde.collegue, vehiculeUtilise: garde.vehiculeUtilise,
                kmDomicileTravail: garde.kmDomicileTravail,
                achats: achatsModifies,
              );
              widget.onGardeModifiee!(gardeModifiee);
              _feedback('✓ $mc retiré du ${dateTarget.day}/${dateTarget.month}');
              return;
            }
          } else if (dateCible == null) {
            setState(() => _achats.removeWhere((a) {
              final matchNom = a.intitule.toLowerCase().contains(mc);
              if (!matchNom) return false;
              if (montantRetire != null) return a.montant == montantRetire;
              return true;
            }));
            _feedback('✓ $mc retiré');
            return;
          }
        }
      }
    }
    // ── 0c. RÉINITIALISATION VOCALE ──────────────────────────────
    if (t.contains('recommence') || t.contains('efface tout') ||
        t.contains('remet a zero') || t.contains('annule tout') ||
        t.contains('reset') || t.contains('tout effacer') ||
        t.contains('recommencer')) {
      setState(() {
        _debutHeureCtrl.text = '07'; _debutMinCtrl.text = '00';
        _finHeureCtrl.text = '17';   _finMinCtrl.text = '00';
        _collegueCtrl.text = '';     _vehiculeCtrl.text = '';
        _achats = [];
        _avecPause = false;          _pauseMinutes = 0;
        _avecPanier = false;          _jourNonTravaille = false;
        _avecLongueDistance = false; _primeLongueDistance = 0; _longuePrimeCtrl.clear();
        _isCongesPaies = false;      _cpDateFin = null;
      });
      _feedback('✓ Formulaire réinitialisé');
      return;
    }

    // ── 1. JOUR NON TRAVAILLÉ ─────────────────────────────────────
    if (t.contains('repos') || t.contains('non travaille') ||
        t.contains('pas travaille') || t.contains('conge') ||
        t.contains('malade') || t.contains('arret')) {
      setState(() => _jourNonTravaille = true);
      _feedback('✓ Jour non travaillé');
      return;
    }

    // ── HEURES + DATE ─────────────────────────────────────────────
    // 1. Prépare le texte heures
    String tH = t.replaceAll('heures', 'h').replaceAll('heure', 'h');
    // Fusionne "20 h" → "20h" (espace avant h)
    tH = tH.replaceAllMapped(RegExp(r'(\d{1,2}) h'), (m) => '${m.group(1)}h');
    // Sépare "8h20h" → "8h 20h"
    tH = tH.replaceAllMapped(RegExp(r'(\d{1,2})h(\d{2})h'), (m) => '${m.group(1)}h ${m.group(2)}h');

    // 2. Extrait TOUTES les heures — méthode manuelle robuste
    final heuresTrouvees = <List<int>>[];
    final reH = RegExp(r'(\d{1,2})h(\d{2})?');
    for (final mh in reH.allMatches(tH)) {
      final h = int.tryParse(mh.group(1) ?? '') ?? -1;
      final min = int.tryParse(mh.group(2) ?? '0') ?? 0;
      if (h >= 0 && h <= 23 && min >= 0 && min <= 59) {
        heuresTrouvees.add([h, min]);
      }
    }
    // Filtre les doublons consécutifs
    final hUniq = <List<int>>[];
    for (final h in heuresTrouvees) {
      if (hUniq.isEmpty || hUniq.last[0] != h[0] || hUniq.last[1] != h[1]) hUniq.add(h);
    }

    // ── 2. DATE ───────────────────────────────────────────────────
    DateTime? nouvellDate;
    final now = DateTime.now();

    // Jours relatifs simples
    if (t.contains('aujourd') || t.contains('ce matin') || t.contains('ce soir'))
      nouvellDate = now;
    else if (t.contains('demain'))
      nouvellDate = now.add(const Duration(days: 1));
    else if (t.contains('hier'))
      nouvellDate = now.subtract(const Duration(days: 1));
    else if (t.contains('avant hier') || t.contains('avant-hier'))
      nouvellDate = now.subtract(const Duration(days: 2));

    // Jours de la semaine relatifs — "lundi dernier", "vendredi dernier", "mardi prochain"
    if (nouvellDate == null) {
      const joursMap = {
        'lundi': 1, 'mardi': 2, 'mercredi': 3, 'jeudi': 4,
        'vendredi': 5, 'samedi': 6, 'dimanche': 7,
      };
      for (final entry in joursMap.entries) {
        if (t.contains(entry.key)) {
          final cibleWeekday = entry.value;
          final estDernier = t.contains('dernier') || t.contains('passe') || t.contains('passé');
          final estProchain = t.contains('prochain') || t.contains('prochaine');
          final todayWeekday = now.weekday;
          int diff = 0;
          if (estDernier) {
            // Trouve le jour de la semaine PASSÉE
            diff = cibleWeekday - todayWeekday;
            if (diff >= 0) diff -= 7; // toujours dans le passé
          } else if (estProchain) {
            // Trouve le jour de la semaine PROCHAINE
            diff = cibleWeekday - todayWeekday;
            if (diff <= 0) diff += 7; // toujours dans le futur
          } else {
            // Par défaut : le plus récent (passé ou aujourd'hui)
            diff = cibleWeekday - todayWeekday;
            if (diff > 0) diff -= 7;
          }
          nouvellDate = now.add(Duration(days: diff));
          break;
        }
      }
    }

    // Semaine relative — "la semaine dernière", "la semaine prochaine"
    if (nouvellDate == null) {
      if (t.contains('semaine derniere') || t.contains('semaine passee')) {
        nouvellDate = now.subtract(const Duration(days: 7));
      } else if (t.contains('semaine prochaine')) {
        nouvellDate = now.add(const Duration(days: 7));
      }
    }

    const moisMap = {'janvier':1,'fevrier':2,'mars':3,'avril':4,'mai':5,'juin':6,
      'juillet':7,'aout':8,'septembre':9,'octobre':10,'novembre':11,'decembre':12};
    int? jourTrouve; int? moisTrouve;
    final mDC = RegExp(r'(?:le\s+)?(\d{1,2})(?:er|e|eme)?\s+(janvier|fevrier|mars|avril|mai|juin|juillet|aout|septembre|octobre|novembre|decembre)').firstMatch(t);
    if (mDC != null) {
      jourTrouve = int.tryParse(mDC.group(1) ?? '');
      moisTrouve = moisMap[mDC.group(2)];
    } else {
      final mJ = RegExp(r'\ble\s+(\d{1,2})\b').firstMatch(t);
      if (mJ != null) {
        jourTrouve = int.tryParse(mJ.group(1) ?? '');
      } else {
        // Chiffre seul sans "le" → jour du mois courant
        final mJseul = RegExp(r'^\s*(\d{1,2})\s*$').firstMatch(t.trim());
        if (mJseul != null) jourTrouve = int.tryParse(mJseul.group(1) ?? '');
      }
    }
    if (jourTrouve != null && jourTrouve >= 1 && jourTrouve <= 31)
      nouvellDate = DateTime(_date.year, moisTrouve ?? _date.month, jourTrouve);

    if (nouvellDate != null) {
      final change = nouvellDate.day != _date.day || nouvellDate.month != _date.month;
      if (change) {
        final dh = hUniq.length >= 1 ? hUniq[0][0] : 7;
        final dm = hUniq.length >= 1 ? hUniq[0][1] : 0;
        final fh = hUniq.length >= 2 ? hUniq[1][0] : 17;
        final fm = hUniq.length >= 2 ? hUniq[1][1] : 0;
        setState(() {
          _date = nouvellDate!;
          _debutHeureCtrl.text = dh.toString().padLeft(2,'0');
          _debutMinCtrl.text   = dm.toString().padLeft(2,'0');
          _finHeureCtrl.text   = fh.toString().padLeft(2,'0');
          _finMinCtrl.text     = fm.toString().padLeft(2,'0');
          _collegueCtrl.text = ''; _vehiculeCtrl.text = '';
          _achats = []; _avecPause = false; _pauseMinutes = 0;
          _avecPanier = false; _jourNonTravaille = false;
          _isCongesPaies = false; _cpDateFin = null;
        });
        champsRemplis.add(hUniq.length >= 2
          ? 'garde ${nouvellDate.day}/${nouvellDate.month} ${dh}h→${fh}h'
          : 'nouvelle garde ${nouvellDate.day}/${nouvellDate.month}');
      } else {
        setState(() => _date = nouvellDate!);
        champsRemplis.add('date');
      }
    }

    // ── 3. HEURES sans changement de date ─────────────────────────
    final hFait = champsRemplis.any((c) => c.contains('→'));
    if (!hFait && hUniq.length >= 2) {
      _debutHeureCtrl.text = hUniq[0][0].toString().padLeft(2,'0');
      _debutMinCtrl.text   = hUniq[0][1].toString().padLeft(2,'0');
      _finHeureCtrl.text   = hUniq[1][0].toString().padLeft(2,'0');
      _finMinCtrl.text     = hUniq[1][1].toString().padLeft(2,'0');
      champsRemplis.add('${hUniq[0][0]}h→${hUniq[1][0]}h');
    } else if (!hFait && hUniq.length == 1) {
      _debutHeureCtrl.text = hUniq[0][0].toString().padLeft(2,'0');
      _debutMinCtrl.text   = hUniq[0][1].toString().padLeft(2,'0');
      champsRemplis.add('début ${hUniq[0][0]}h');
    }

    // ── 4. PAUSE ──────────────────────────────────────────────────
    if (t.contains('sans pause') || t.contains('pas de pause')) {
      setState(() => _avecPause = false);
      champsRemplis.add('pause désactivée');
    } else {
      final regexPause = RegExp(r'pause\s+(?:de\s+)?(\d{1,3})\s*(?:minutes?|min|mn)?');
      final mp = regexPause.firstMatch(t);
      if (mp != null) {
        final mins = int.tryParse(mp.group(1) ?? '') ?? 0;
        if (mins > 0 && mins <= 120) {
          setState(() { _avecPause = true; _pauseMinutes = mins; });
          champsRemplis.add('pause ${mins}min');
        }
      } else if (t.contains('pause')) {
        setState(() { _avecPause = true; });
        champsRemplis.add('pause');
      }
    }

    // ── 5. PANIER REPAS ───────────────────────────────────────────
    if (t.contains('pas de panier') || t.contains('sans panier') ||
        t.contains('pas panier') || t.contains('sans repas')) {
      setState(() => _avecPanier = false);
      champsRemplis.add('sans panier');
    } else if (t.contains('panier') || t.contains('repas')) {
      setState(() => _avecPanier = true);
      champsRemplis.add('panier');
    }

    // ── 6. COLLÈGUE ───────────────────────────────────────────────
    final regexCollegue = RegExp(
        r'(?:avec|collegue|binome|equipier|partenaire|coequipier|travaille avec|jetais avec|etais avec)\s+([a-z\u00e0-\u024f]{2,}(?:\s+[a-z\u00e0-\u024f]{2,})?)');
    final mc = regexCollegue.firstMatch(t);
    if (mc != null) {
      String nom = mc.group(1)?.trim() ?? '';
      final stopWords = ['vehicule', 'voiture', 'ambulance', 'vsl', 'pause',
          'panier', 'achat', 'frais', 'jai', 'pour', 'ford', 'renault',
          'peugeot', 'citroen', 'mercedes', 'fiat', 'opel', 'kangoo',
          'master', 'sprinter', 'boxer', 'transit',
          'aujourd', 'hui', 'demain', 'hier', 'matin', 'soir', 'ce',
          'janvier', 'fevrier', 'mars', 'avril', 'mai', 'juin',
          'juillet', 'aout', 'septembre', 'octobre', 'novembre', 'decembre',
          'travaille', 'travaillee', 'garde', 'et', 'de', 'du', 'le', 'la',
          'les', 'un', 'une', 'en', 'au', 'aux', 'dans', 'sur', 'sous',
          'j', 'ai', 'pris', 'achete', 'paye', 'mis', 'fait', 'plein',
          'etais', 'etait', 'suis'];
      final mots = nom.split(' ');
      final motsFiltres = <String>[];
      for (final mot in mots) {
        if (stopWords.contains(mot)) break;
        motsFiltres.add(mot);
      }
      nom = motsFiltres.join(' ').trim();
      if (nom.isNotEmpty && nom.length > 1) {
        _collegueCtrl.text = nom.split(' ').map(_capitaliser).join(' ');
        champsRemplis.add('collègue');
      }
    }

    // ── 7. VÉHICULE ───────────────────────────────────────────────
    final marques = ['ford', 'renault', 'peugeot', 'citroen', 'toyota',
        'mercedes', 'volkswagen', 'fiat', 'opel', 'scenic', 'kangoo',
        'transit', 'master', 'sprinter', 'boxer', 'ducato', 'jumper'];
    final parasitesVeh = ['et', 'avec', 'pour', 'en', 'de', 'du', 'la', 'le',
        'jai', 'pause', 'panier', 'collegue', 'achat', 'frais'];
    for (final m in marques) {
      if (t.contains(m)) {
        final regexMarque = RegExp('$m\\s*([a-z0-9]*)');
        final mm = regexMarque.firstMatch(t);
        String veh = _capitaliser(m);
        if (mm != null && mm.group(1)?.isNotEmpty == true) {
          final suffix = mm.group(1)!;
          if (!parasitesVeh.contains(suffix)) veh += ' ${suffix.toUpperCase()}';
        }
        _vehiculeCtrl.text = veh;
        champsRemplis.add('véhicule');
        break;
      }
    }
    if (!champsRemplis.contains('véhicule')) {
      final regexVeh = RegExp(
          r'(?:vehicule|voiture|ambulance|vsl|smur|en)\s+([a-z0-9]{2,}(?:\s+[a-z0-9]{1,})?)');
      final mv = regexVeh.firstMatch(t);
      if (mv != null) {
        final mots = (mv.group(1)?.trim() ?? '').split(' ');
        while (mots.isNotEmpty && parasitesVeh.contains(mots.last)) {
          mots.removeLast();
        }
        String veh = mots.join(' ');
        // Reconnaît les numéros de modèles courants
        final modelesPeugeot = ['308', '207', '208', '301', '408', '508', '2008', '3008', '5008'];
        final modelesCitroen = ['c3', 'c4', 'c5', 'berlingo', 'jumpy', 'jumper'];
        final modelesRenault = ['clio', 'megane', 'scenic', 'laguna', 'trafic', 'master'];
        if (modelesPeugeot.contains(veh.toLowerCase())) veh = 'Peugeot $veh';
        else if (modelesCitroen.contains(veh.toLowerCase())) veh = 'Citroën $veh';
        else if (modelesRenault.contains(veh.toLowerCase())) veh = 'Renault $veh';
        if (veh.isNotEmpty && !parasitesVeh.contains(veh.toLowerCase())) {
          _vehiculeCtrl.text = _capitaliser(veh);
          champsRemplis.add('véhicule');
        }
      }
    }

    // ── 8b. SUPPRIMER UN ACHAT PAR VOIX ───────────────────────────
    if (t.contains('retire') || t.contains('enleve') || t.contains('supprime') ||
        t.contains('efface') || t.contains('annule')) {
      // Gère les infinitifs (enlever, retirer, supprimer, effacer, annuler)
      final apresCmd = t.replaceAll(RegExp(
          r'^.*?(?:retirer?|enl[eè]ve[rz]?|supprimer?|effacer?|annuler?)\s*'), '');
      final items = apresCmd.split(RegExp(r'\bet\b|,'));
      bool unRetire = false;
      for (final item in items) {
        // Retire chiffre de quantité, "moi", articles en début
        String s = item.trim();
        // "1 café", "2 sandwichs" → retire le chiffre
        int qteRetirer = 1;
        final mQteR = RegExp(r'^(\d+)\s+').firstMatch(s);
        if (mQteR != null) {
          qteRetirer = int.tryParse(mQteR.group(1) ?? '1') ?? 1;
          s = s.substring(mQteR.end);
        }
        final motCle = s
            .replaceAll(RegExp(r'^(?:moi|nous|me|lui)\s+'), '')
            .replaceAll(RegExp(r"^(?:le|la|les|l'|l'|l|un|une|du|de la|des)\s*"), '')
            .trim();
        if (motCle.length < 2) continue;
        // Retire exactement qteRetirer occurrences (ou toutes si qte=1)
        int retiresCount = 0;
        setState(() => _achats.removeWhere((a) {
          if (retiresCount >= qteRetirer) return false;
          final match = a.intitule.toLowerCase()
              .replaceAll('é','e').replaceAll('è','e').replaceAll('à','a').replaceAll('ç','c')
              .contains(motCle);
          if (match) { retiresCount++; return true; }
          return false;
        }));
        if (retiresCount > 0) {
          champsRemplis.add('retiré ${retiresCount}× $motCle');
          unRetire = true;
        }
      }
      if (!unRetire) {
        _feedback('❌ "${ apresCmd.trim()}" non trouvé dans les achats');
        return;
      }
      // Suppression réussie → on affiche et on sort sans analyser les achats
      setState(() {});
      _feedback('✓ Retiré : ${champsRemplis.join(', ')}');
      return;
    }
    final tAchatBase = t
        .replaceAll("j'ai", 'jai').replaceAll("j ai", 'jai')
        .replaceAll("d'un", 'dun').replaceAll("d'une", 'dune')
        .replaceAll("d'essence", 'dessence').replaceAll("de carburant", 'decarburant')
        .replaceAll("de gasoil", 'degasoil').replaceAll("de diesel", 'dediesel')
        // plein d'essence — gère les mauvaises reconnaissances vocales
        // IMPORTANT: traiter "plein dessence" AVANT "plein d" pour éviter les fusions
        .replaceAll('plein dessence', 'essence').replaceAll('plein essence', 'essence')
        .replaceAll('plein decarburant', 'carburant').replaceAll('plein carburant', 'carburant')
        .replaceAll('plein degasoil', 'gasoil')
        .replaceAll('plan dessence', 'essence').replaceAll('plan essence', 'essence')
        .replaceAll('fait le plein', 'essence').replaceAll('fait plein', 'essence')
        .replaceAll('le plein', 'essence')
        .replaceAll('plan ', 'plein ')
        .replaceAll('esence', 'essence').replaceAll('essance', 'essence')
        // "j'ai usé" = dépense
        .replaceAll('jai use', 'jai depense').replaceAll('jai utilisé', 'jai depense')
        .replaceAll('jai mis', 'jai depense');

    // ── CONVERSION NOMBRES EN LETTRES → CHIFFRES ────────────────
    // Android peut dire "un euro cinquante" ou "un point zero zero"
    String tConv = tAchatBase
        .replaceAll('zero', '0').replaceAll('zéro', '0')
        .replaceAll('\bun\b', '1').replaceAll('\bdeux\b', '2')
        .replaceAll('\btrois\b', '3').replaceAll('\bquatre\b', '4')
        .replaceAll('\bcinq\b', '5').replaceAll('\bsix\b', '6')
        .replaceAll('\bsept\b', '7').replaceAll('\bhuit\b', '8')
        .replaceAll('\bneuf\b', '9').replaceAll('\bdix\b', '10')
        .replaceAll('\bonze\b', '11').replaceAll('\bdouze\b', '12')
        .replaceAll('\bquinze\b', '15').replaceAll('\bvingt\b', '20')
        .replaceAll('\btrente\b', '30').replaceAll('\bquarante\b', '40')
        .replaceAll('cinquante', '50').replaceAll('cinquant', '50')
        .replaceAll('\bsoixante\b', '60').replaceAll('\bsoixante-dix\b', '70')
        .replaceAll('\bquatre-vingts?\b', '80').replaceAll('\bquatre-vingt-dix\b', '90')
        .replaceAll('point', '.') // "un point cinquante" → "1.50"
        .replaceAll('virgule', '.'); // "un virgule cinquante" → "1.50"

    // ── NORMALISATION DES MONTANTS ────────────────────────────────
    // "7 euros 50" → "7.50", "1 euro 50" → "1.50", "50 centimes" → "0.50"
    String tNorm = tConv
        // "X euros Y" → "X.Y" (ex: "7 euros 50" → "7.50")
        .replaceAllMapped(
            RegExp(r'(\d+)\s+euros?\s+(\d{1,2})\b'),
            (m) => '${m.group(1)}.${m.group(2)!.padLeft(2, '0')}')
        // "X euro" → "X"
        .replaceAll(RegExp(r'euros?'), '')
        // "50 centimes" → "0.50"
        .replaceAllMapped(
            RegExp(r'(\d{1,3})\s*(?:centimes?|cts?)'),
            (m) { final v = (int.tryParse(m.group(1) ?? '0') ?? 0) / 100; return v.toStringAsFixed(2); })
        // virgule → point pour les décimales
        .replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m.group(1)}.${m.group(2)}');

    final tAchatNorm = tNorm;

    // ── DÉTECTION DES ACHATS ──────────────────────────────────────
    // Mots déclencheurs élargis — tout ce qui indique une dépense
    final declencheurs = RegExp(
        r'jai\s+(?:pris|achete|paye|mange|dejeune|dine|bu|commande|offert|depense|mis|fait\s+le\s+plein)|'
        r'(?:repas|cafe|chocolat|the|tisane|sandwich|croissant|boisson|pizza|jus|eau|menu|pain|baguette|red bull|redbull|monster|orangina|fanta|coca|coca cola|pepsi|limonade|schweppes|'
        r'essence|carburant|gasoil|parking|peage)\s+(?:pour|a|au prix)?\s*\d|'
        r'\d+(?:\.\d+)?\s*(?:pour\s+(?:le|la|un|une|du|mon|ma))');

    if (declencheurs.hasMatch(tAchatNorm)) {
      // Normalise les articles et connecteurs
      String phrase = tAchatNorm
          .replaceAll(RegExp(r'\bjai\s+(?:pris|achete|paye|mange|dejeune|dine|bu|commande|offert|depense)\s+'), 'ACHAT ')
          .replaceAll(RegExp(r'\bjai\s+(?:mis|fait\s+le\s+plein)\b'), 'ACHAT carburant');

      // Découpe en items par "et" et virgule
      final segments = phrase.split(RegExp(r'\bet\b|,'));

      for (String seg in segments) {
        seg = seg.trim();
        // Retire ACHAT en premier
        seg = seg.replaceAll(RegExp(r'^ACHAT\s+'), '');
        // Enlève articles en début
        seg = seg.replaceAll(RegExp(r'^(?:un|une|du|de la|dun|dune|le|la|des|au|aux|mon|ma)\s+'), '');
        // Détecte une quantité en début : "2 café", "3 sandwichs"
        int quantite = 1;
        final regexQte = RegExp(r'^(\d+)\s+');
        final mQte = regexQte.firstMatch(seg);
        if (mQte != null) {
          quantite = int.tryParse(mQte.group(1) ?? '1') ?? 1;
          seg = seg.substring(mQte.end); // retire la quantité
        }

        // Cherche [nom composé possible] [montant]
        final regexItemMontant = RegExp(
            r'([a-z\u00e0-\u024f]+(?:\s+(?:de|au|du|a|al|avec)?\s*[a-z\u00e0-\u024f]+)?)'
            r'\s+(?:pour\s+|a\s+)?(\d+(?:\.\d+)?)');
        final m = regexItemMontant.firstMatch(seg);

        final regexMontantSeul = RegExp(r'(?:pour|a)\s+(\d+(?:\.\d+)?)');
        final mMontant = regexMontantSeul.firstMatch(seg);

        String intitule = '';
        double montant = 0;

        if (m != null) {
          intitule = m.group(1)?.trim() ?? '';
          montant = double.tryParse(m.group(2) ?? '0') ?? 0;
          intitule = intitule.replaceAll(RegExp(r'\s+(de|du|au|a|le|la|pour)$'), '').trim();
        } else if (mMontant != null && seg.contains(RegExp(r'(?:mange|dejeune|dine|repas)'))) {
          intitule = 'Repas';
          montant = double.tryParse(mMontant.group(1) ?? '0') ?? 0;
        }

        final exclus = {'aujourd', 'demain', 'hier', 'travaille', 'garde',
            'pause', 'panier', 'collegue', 'vehicule', 'ford', 'renault',
            'peugeot', 'mercedes', 'jai', 'avec', 'pour', 'etais'};

        // Si article reconnu SANS montant → demande vocalement
        if (intitule.length > 1 && montant == 0 &&
            !exclus.contains(intitule.split(' ').first)) {
          _articleEnAttente = intitule;
          _etatConv = 'prix_achat';
          _parler('Quel est le prix de ' + intitule + ' ?');
          return;
        }
        if (intitule.length > 1 && montant > 0 &&
            !exclus.contains(intitule.split(' ').first)) {
          // Ajoute autant d'exemplaires que la quantité demandée
          for (int q = 0; q < quantite; q++) {
            _achats.add(Achat(
              id: '${DateTime.now().microsecondsSinceEpoch}$q',
              intitule: _capitaliser(intitule),
              montant: montant,
            ));
          }
          champsRemplis.add('${quantite > 1 ? "${quantite}× " : ""}${_capitaliser(intitule)} ${montant.toStringAsFixed(2)}€');
        }
      }
    }

    // ── CARBURANT SPÉCIFIQUE ──────────────────────────────────────
    final carbuMots = ['essence', 'carburant', 'gasoil', 'plein', 'diesel'];
    final dejaCarbu = _achats.any((a) =>
        carbuMots.any((k) => a.intitule.toLowerCase().contains(k)));
    if (!dejaCarbu && tAchatNorm.contains(RegExp(r'(?:essence|carburant|gasoil|plein)'))) {
      final mm = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(tAchatNorm);
      final montant = mm != null ? (double.tryParse(mm.group(1) ?? '0') ?? 0) : 0.0;
      String intitule = 'Carburant';
      if (tAchatNorm.contains('essence')) intitule = 'Essence';
      if (tAchatNorm.contains('gasoil')) intitule = 'Gasoil';
      _achats.add(Achat(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        intitule: intitule,
        montant: montant,
      ));
      champsRemplis.add('$intitule ${montant > 0 ? "${montant.toStringAsFixed(2)}€" : "(à saisir)"}');
    }

    // ── MOTS-CLÉS SEULS SANS MONTANT ─────────────────────────────
    // "j'ai mangé" sans prix → Repas 0€
    if (!champsRemplis.any((c) => c.contains('€'))) {
      if (tAchatNorm.contains(RegExp(r'jai\s+(?:mange|dejeune|dine)'))) {
        final mm = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(tAchatNorm);
        final montant = mm != null ? (double.tryParse(mm.group(1) ?? '0') ?? 0) : 0.0;
        _achats.add(Achat(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          intitule: 'Repas',
          montant: montant,
        ));
        champsRemplis.add('Repas ${montant > 0 ? "${montant.toStringAsFixed(2)}€" : "(à saisir)"}');
      }
    }

    setState(() {});

    if (champsRemplis.isEmpty) {
      _feedback('❌ Pas compris — réessayez');
      _parler('Je n ai pas compris, pouvez-vous répéter ?');
    } else {
      _feedback('✓ Rempli : ${champsRemplis.join(', ')}');
    }
  }

  String _capitaliser(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  void _feedback(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.colorGreen,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  void initState() {
    super.initState();
    _initSpeech();
    final g = widget.gardeAModifier;
    _date = g?.date ?? DateTime.now();
    _jourNonTravaille = g?.jourNonTravaille ?? false;
    _isCongesPaies = g?.isCongesPaies ?? false;
    _cpDateFin = g?.cpDateFin;
    _avecPanier = g?.avecPanier ?? false;
    _panierRepasGarde = g?.panierRepasGarde ?? widget.panierRepas;
    _avecLongueDistance = (g?.primeLongueDistance ?? 0) > 0;
    _primeLongueDistance = g?.primeLongueDistance ?? 0;
    if (g != null && g.pauseMinutes > 0) { _avecPause = true; _pauseMinutes = g.pauseMinutes; }
    _achats = g != null ? List.from(g.achats) : [];

    final dh = g?.heureDebut.hour ?? 7;
    final dm = g?.heureDebut.minute ?? 0;
    final fh = g?.heureFin.hour ?? 17;
    final fm = g?.heureFin.minute ?? 0;
    _debutHeureCtrl = TextEditingController(text: dh.toString().padLeft(2, '0'));
    _debutMinCtrl   = TextEditingController(text: dm.toString().padLeft(2, '0'));
    _finHeureCtrl   = TextEditingController(text: fh.toString().padLeft(2, '0'));
    _finMinCtrl     = TextEditingController(text: fm.toString().padLeft(2, '0'));
    _collegueCtrl   = TextEditingController(text: g?.collegue ?? '');
    _vehiculeCtrl   = TextEditingController(text: g?.vehiculeUtilise ?? '');
    _longuePrimeCtrl = TextEditingController(text: (g?.primeLongueDistance ?? 0) > 0 ? (g!.primeLongueDistance.toStringAsFixed(2)) : '');

    // Listeners pour mise à jour dynamique du calcul CCN
    _debutHeureCtrl.addListener(() => setState(() {}));
    _debutMinCtrl.addListener(() => setState(() {}));
    _finHeureCtrl.addListener(() => setState(() {}));
    _finMinCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debutHeureCtrl.dispose(); _debutMinCtrl.dispose();
    _finHeureCtrl.dispose(); _finMinCtrl.dispose();
    _collegueCtrl.dispose(); _vehiculeCtrl.dispose();
    _longuePrimeCtrl.dispose();
    super.dispose();
  }


  // Convertit un montant en texte naturel pour la TTS
  String _montantEnMots(double montant) {
    final euros = montant.truncate();
    final centimes = ((montant - euros) * 100).round();
    if (centimes == 0) {
      return euros == 1 ? '1 euro' : '$euros euros';
    } else if (euros == 0) {
      return '$centimes centimes';
    } else {
      return euros == 1 ? '1 euro $centimes' : '$euros euros $centimes';
    }
  }
  int _val(TextEditingController c, int max) =>
      (int.tryParse(c.text) ?? 0).clamp(0, max);

  // Parse une date sans toucher aux flags isCongesPaies / jourNonTravaille
  // Convertit les nombres écrits en chiffres pour la reconnaissance vocale
  String _normaliserNombres(String t) {
    return t
      .replaceAll('trente et un', '31').replaceAll('trente-et-un', '31')
      .replaceAll('trente et une', '31')
      .replaceAll('trente', '30')
      .replaceAll('vingt-neuf', '29').replaceAll('vingt neuf', '29')
      .replaceAll('vingt-huit', '28').replaceAll('vingt huit', '28')
      .replaceAll('vingt-sept', '27').replaceAll('vingt sept', '27')
      .replaceAll('vingt-six', '26').replaceAll('vingt six', '26')
      .replaceAll('vingt-cinq', '25').replaceAll('vingt cinq', '25')
      .replaceAll('vingt-quatre', '24').replaceAll('vingt quatre', '24')
      .replaceAll('vingt-trois', '23').replaceAll('vingt trois', '23')
      .replaceAll('vingt-deux', '22').replaceAll('vingt deux', '22')
      .replaceAll('vingt et un', '21').replaceAll('vingt-et-un', '21')
      .replaceAll('vingt', '20')
      .replaceAll('dix-neuf', '19').replaceAll('dix neuf', '19')
      .replaceAll('dix-huit', '18').replaceAll('dix huit', '18')
      .replaceAll('dix-sept', '17').replaceAll('dix sept', '17')
      .replaceAllMapped(RegExp(r'\bseize\b'), (m) => '16')
      .replaceAllMapped(RegExp(r'\bquinze\b'), (m) => '15')
      .replaceAllMapped(RegExp(r'\bquatorze\b'), (m) => '14')
      .replaceAllMapped(RegExp(r'\btreize\b'), (m) => '13')
      .replaceAllMapped(RegExp(r'\bdouze\b'), (m) => '12')
      .replaceAllMapped(RegExp(r'\bonze\b'), (m) => '11')
      .replaceAllMapped(RegExp(r'\bdix\b'), (m) => '10')
      .replaceAllMapped(RegExp(r'\bneuf\b'), (m) => '9')
      .replaceAllMapped(RegExp(r'\bhuit\b'), (m) => '8')
      .replaceAllMapped(RegExp(r'\bsept\b'), (m) => '7')
      .replaceAllMapped(RegExp(r'\bsix\b'), (m) => '6')
      .replaceAllMapped(RegExp(r'\bcinq\b'), (m) => '5')
      .replaceAllMapped(RegExp(r'\bquatre\b'), (m) => '4')
      .replaceAllMapped(RegExp(r'\btrois\b'), (m) => '3')
      .replaceAllMapped(RegExp(r'\bdeux\b'), (m) => '2')
      .replaceAllMapped(RegExp(r'\bpremier\b'), (m) => '1')
      .replaceAllMapped(RegExp(r'\bpremière\b'), (m) => '1')
      .replaceAllMapped(RegExp(r'\bun\b'), (m) => '1')
      .replaceAllMapped(RegExp(r'\bune\b'), (m) => '1');
  }

  DateTime _parseDate(String rep) {
    String t = rep.toLowerCase()
        .replaceAll('é','e').replaceAll('è','e').replaceAll('à','a')
        .replaceAll("'", ' ');
    final now = DateTime.now();
    if (t.contains('avant hier') || t.contains('avanthier')) return now.subtract(const Duration(days: 2));
    if (t.contains('hier')) return now.subtract(const Duration(days: 1));
    if (t.contains('aujourd') || t.contains('maintenant')) return now;
    // Protège les noms de mois avant la normalisation des nombres
    // (ex: 'septembre' contient 'sept', 'janvier' contient 'un', etc.)
    const _moisPlaceholders = {
      'janvier': 'MOIS01', 'fevrier': 'MOIS02', 'mars': 'MOIS03',
      'avril': 'MOIS04', 'mai': 'MOIS05', 'juin': 'MOIS06',
      'juillet': 'MOIS07', 'aout': 'MOIS08', 'septembre': 'MOIS09',
      'octobre': 'MOIS10', 'novembre': 'MOIS11', 'decembre': 'MOIS12',
    };
    for (final e in _moisPlaceholders.entries) {
      t = t.replaceAll(e.key, e.value);
    }
    // Convertir les nombres écrits en chiffres
    t = _normaliserNombres(t);
    // Restaure les noms de mois
    for (final e in _moisPlaceholders.entries) {
      t = t.replaceAll(e.value, e.key);
    }
    final moisMap = {'janvier':1,'fevrier':2,'mars':3,'avril':4,'mai':5,'juin':6,
        'juillet':7,'aout':8,'septembre':9,'octobre':10,'novembre':11,'decembre':12};
    // "le 10 avril", "10 avril"
    for (final entry in moisMap.entries) {
      // Use word boundary for 'mai' to avoid false matches
      final moisRegex = entry.key == 'mai'
          ? RegExp(r'\bmai\b')
          : RegExp(entry.key);
      if (moisRegex.hasMatch(t)) {
        final mR = RegExp(r'(?:le\s+)?(\d{1,2})(?:er|e|eme)?\s+' + entry.key).firstMatch(t);
        if (mR != null) {
          final jour = int.tryParse(mR.group(1) ?? '') ?? now.day;
          return DateTime(now.year, entry.value, jour);
        }
        // Cherche aussi le chiffre seul après le mois : "mars 15"
        final mR2 = RegExp(entry.key + r'\s+(\d{1,2})').firstMatch(t);
        if (mR2 != null) {
          final jour = int.tryParse(mR2.group(1) ?? '') ?? now.day;
          return DateTime(now.year, entry.value, jour);
        }
        // Cherche un chiffre n'importe où dans la phrase
        final mN2 = RegExp(r'\b(\d{1,2})\b').firstMatch(t);
        if (mN2 != null) {
          final jour = int.tryParse(mN2.group(1) ?? '') ?? 1;
          if (jour >= 1 && jour <= 31) return DateTime(now.year, entry.value, jour);
        }
        // Mois seul → 1er du mois
        return DateTime(now.year, entry.value, 1);
      }
    }
    // Nombre seul → jour du mois courant
    final mN = RegExp(r'\b(\d{1,2})\b').firstMatch(t);
    if (mN != null) {
      final j = int.tryParse(mN.group(1) ?? '') ?? now.day;
      return DateTime(now.year, now.month, j);
    }
    return now;
  }


  int _parseMinutes(String t) {
    // Convertit les nombres écrits en chiffres d'abord
    String s = t
        .replaceAll('une heure et demie', '90min').replaceAll('heure et demie', '90min')
        .replaceAll('une demi heure', '30min').replaceAll('demi heure', '30min')
        .replaceAll('une heure', '60min').replaceAll('un heure', '60min')
        .replaceAll('deux heures', '120min').replaceAll('deux heure', '120min')
        .replaceAll('trente cinq minutes', '35min').replaceAll('trente-cinq minutes', '35min').replaceAll('trente cinq', '35').replaceAll('trente-cinq', '35').replaceAll('trente minutes', '30min').replaceAll('trente', '30')
        .replaceAll('quarante cinq', '45').replaceAll('quarante-cinq', '45')
        .replaceAll('quinze minutes', '15min').replaceAll('quinze', '15')
        .replaceAll('vingt minutes', '20min').replaceAll('vingt', '20')
        .replaceAll('dix minutes', '10min').replaceAll('dix', '10')
        .replaceAll('cinq minutes', '5min').replaceAll('cinq', '5');
    int total = 0;
    // "1h30" combiné → priorité maximale
    final mComb = RegExp(r'(\d+)h(\d{2})').firstMatch(s);
    if (mComb != null) {
      return (int.tryParse(mComb.group(1) ?? '0') ?? 0) * 60 +
             (int.tryParse(mComb.group(2) ?? '0') ?? 0);
    }
    // "Xh" ou "X heure(s)" → heures × 60
    final mH = RegExp(r'(\d+)\s*h(?:eure)?s?').firstMatch(s);
    if (mH != null) total += (int.tryParse(mH.group(1) ?? '0') ?? 0) * 60;
    // "X min" → minutes
    final mM = RegExp(r'(\d+)\s*(?:min(?:ute)?s?)').firstMatch(s);
    if (mM != null) total += int.tryParse(mM.group(1) ?? '0') ?? 0;
    // Aucun match → premier nombre brut
    if (total == 0) {
      final mN = RegExp(r'(\d+)').firstMatch(s);
      total = int.tryParse(mN?.group(1) ?? '0') ?? 0;
    }
    return total;
  }


  Garde _buildGarde() {
    final dh = _val(_debutHeureCtrl, 23); final dm = _val(_debutMinCtrl, 59);
    final fh = _val(_finHeureCtrl, 23);   final fm = _val(_finMinCtrl, 59);
    final debut = DateTime(_date.year, _date.month, _date.day, dh, dm);
    var fin    = DateTime(_date.year, _date.month, _date.day, fh, fm);
    if (!_jourNonTravaille && fin.isBefore(debut))
      fin = fin.add(const Duration(days: 1));
    // Calcule le nombre de jours CP depuis la plage de dates
    int nbJoursCP = 0;
    if (_isCongesPaies) {
      if (_cpDateFin != null) {
        final debut2 = DateTime(_date.year, _date.month, _date.day);
        final fin2 = DateTime(_cpDateFin!.year, _cpDateFin!.month, _cpDateFin!.day);
        nbJoursCP = fin2.difference(debut2).inDays + 1;
      } else {
        nbJoursCP = 1;
      }
    }
    return Garde(
      id: widget.gardeAModifier?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: _date,
      heureDebut: debut,
      heureFin: _jourNonTravaille || _isCongesPaies ? debut : fin,
      jourNonTravaille: _jourNonTravaille,
      isCongesPaies: _isCongesPaies,
      cpDateFin: _isCongesPaies ? _cpDateFin : null,
      nbJoursCP: nbJoursCP,
      collegue: _collegueCtrl.text.trim().isEmpty ? null : _collegueCtrl.text.trim(),
      vehiculeUtilise: _vehiculeCtrl.text.trim().isEmpty ? null : _vehiculeCtrl.text.trim(),
      kmDomicileTravail: widget.kmDomicileTravail,
      achats: _achats,
      pauseMinutes: _avecPause && !_jourNonTravaille && !_isCongesPaies ? _pauseMinutes : 0,
      panierRepasGarde: _avecPanier && !_isCongesPaies ? _panierRepasGarde : 0,
      avecPanier: _avecPanier,
      primeLongueDistance: _avecLongueDistance && !_isCongesPaies ? _primeLongueDistance : 0,
      debutQuatorzaine: widget.debutQuatorzaine,
      qualification: widget.poste,
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.blueAccent,
              onPrimary: Colors.white, surface: AppTheme.bgSecondaryDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _ouvrirAjoutAchat({Achat? achat}) {
    final intCtrl = TextEditingController(text: achat?.intitule ?? '');
    final montantCtrl = TextEditingController(
        text: achat != null ? achat.montant.toStringAsFixed(2) : '');
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFFEAF3DE),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(achat == null ? 'Nouvel achat' : 'Modifier l\'achat',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: Color(0xFF173404))),
            if (achat != null)
              GestureDetector(
                onTap: () { Navigator.pop(ctx);
                  setState(() => _achats.removeWhere((a) => a.id == achat.id)); },
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(controller: intCtrl, autofocus: true,
            style: const TextStyle(color: Color(0xFF173404)),
            decoration: InputDecoration(labelText: 'Intitulé de l\'achat',
                labelStyle: const TextStyle(color: Color(0xFF3B6D11)),
                hintText: 'Ex: Carburant, Péage...',
                hintStyle: const TextStyle(color: Color(0xFF639922)))),
          const SizedBox(height: 12),
          TextField(controller: montantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Color(0xFF173404)),
            decoration: InputDecoration(labelText: 'Montant (€)',
                labelStyle: const TextStyle(color: Color(0xFF3B6D11)),
                suffixText: '€',
                hintStyle: const TextStyle(color: Color(0xFF639922)))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              final int = intCtrl.text.trim();
              if (int.isEmpty) return;
              final montant = double.tryParse(
                  montantCtrl.text.replaceAll(',', '.')) ?? 0;
              if (achat == null) {
                setState(() => _achats.add(Achat(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  intitule: int, montant: montant)));
              } else {
                setState(() { achat.intitule = int; achat.montant = montant; });
              }
              Navigator.pop(ctx);
            },
            child: Text(achat == null ? 'Ajouter' : 'Mettre à jour',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          )),
        ]),
      ),
    );
  }

  Widget _champHeure(String label, TextEditingController heureCtrl,
      TextEditingController minCtrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(color: AppTheme.bgCard,
          border: Border.all(color: AppTheme.bgCardBorder),
          borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _champNum(heureCtrl, 'HH'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary))),
          _champNum(minCtrl, 'MM'),
        ]),
      ]),
    );
  }

  Widget _champNum(TextEditingController ctrl, String hint) {
    return SizedBox(width: 44, child: TextField(
      controller: ctrl, textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2)],
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.blueAccent),
      decoration: InputDecoration(hintText: hint,
        hintStyle: TextStyle(fontSize: 16, color: AppTheme.textTertiary),
        contentPadding: EdgeInsets.zero, isDense: true,
        enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.bgCardBorder, width: 1)),
        focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.blueAccent, width: 2)),
      ),
    ));
  }

  Widget _btnPM(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppTheme.blueAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 18, color: AppTheme.blueAccent)),
  );

  @override
  Widget build(BuildContext context) {
    final garde = _buildGarde();
    final brut = _jourNonTravaille ? 0.0 : Calculs.salaireBrutGarde(garde,
        taux: widget.tauxHoraire, panier: _panierRepasGarde,
        indDimanche: widget.indemnitesDimanche, montantIdaj: widget.montantIdaj);
    final heuresNuit = Calculs.heuresNuit(garde);
    final majNuit = Calculs.majorationNuit(garde, widget.tauxHoraire);
    final majDim  = Calculs.majorationDimanche(garde, widget.tauxHoraire);
    final idaj    = Calculs.idaj(garde, widget.tauxHoraire);
    final estModif = widget.gardeAModifier != null;
    final nomFerie = garde.nomJourFerie;
    final estFerieOuDim = garde.isDimancheOuFerie;
    final dq = widget.debutQuatorzaine;
    double prog = 0;
    String labelQ = 'Quatorzaine non définie — voir Paramètres';
    if (dq != null) {
      prog = (_date.difference(dq).inDays.clamp(0, 13) / 13);
      labelQ = '${dq.day}/${dq.month} → ${dq.add(const Duration(days: 13)).day}/${dq.add(const Duration(days: 13)).month}/${dq.add(const Duration(days: 13)).year}';
    }
    final totalAchats = _achats.fold(0.0, (s, a) => s + a.montant);

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── En-tête ────────────────────────────────────────────
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(child: Text(estModif ? 'Modifier la garde' : 'Saisir une garde',
                    style: AppTheme.titleStyle(), overflow: TextOverflow.ellipsis)),
                GestureDetector(
                  onTap: () {
                    if (_ttsActif) {
                      // TTS en cours → stop et réécoute
                      _tts.stop();
                      setState(() { _ttsActif = false; });
                      if (_etatConv.isNotEmpty) _ecouterReponse();
                    } else if (_ecoute) {
                      // Écoute en cours → pause (garde l'état)
                      _arreterEcoute();
                    } else {
                      // Inactif → démarre ou reprend
                      _demarrerEcoute();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _ttsActif ? Colors.blue.withOpacity(0.9)
                          : _ecoute ? Colors.red.withOpacity(0.9)
                          : _etatConv.isNotEmpty ? AppTheme.blueAccent.withOpacity(0.9)
                          : AppTheme.colorGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _ttsActif ? Colors.blue
                          : _ecoute ? Colors.red
                          : _etatConv.isNotEmpty ? AppTheme.blueAccent
                          : AppTheme.colorGreen.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        _ttsActif ? Icons.volume_up
                            : _ecoute ? Icons.stop
                            : Icons.mic,
                        size: 14,
                        color: (_ttsActif || _ecoute || _etatConv.isNotEmpty)
                            ? Colors.white : AppTheme.colorGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _ttsActif ? 'Parle...'
                            : _ecoute ? 'Écoute'
                            : _etatConv.isNotEmpty ? 'Continuer'
                            : 'Vocal',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: (_ttsActif || _ecoute || _etatConv.isNotEmpty)
                                ? Colors.white : AppTheme.colorGreen),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              // Message de la question en cours
              if (_etatConv.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.blueAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.blueAccent.withOpacity(0.3)),
                  ),
                  child: Text(
                    _ttsActif ? '🔊 Je réponds...'
                        : _ecoute ? '🎤 Parlez maintenant...'
                        : '🎤 Appuyez pour continuer',
                    style: TextStyle(fontSize: 11, color: AppTheme.blueAccent,
                        fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.blueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.blueAccent.withOpacity(0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_today, size: 12, color: AppTheme.blueAccent),
                    const SizedBox(width: 5),
                    Text('${_date.day}/${_date.month}/${_date.year}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.blueAccent,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ]),

            // Texte vocal reconnu
            if (_texteVocal.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.colorGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.colorGreen.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.record_voice_over, size: 14, color: AppTheme.colorGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text('"$_texteVocal"',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary))),
                ]),
              ),
            ],

            // Instruction vocale
            if (_ecoute) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.mic, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('J\'écoute... parlez librement',
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600, color: Colors.red))),
                  ]),
                  const SizedBox(height: 2),
                  Text('Appuyez ⏹ Stop quand vous avez fini · Dites "sauvegarde" pour terminer',
                      style: TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
                  const SizedBox(height: 6),
                  if (_texteVocal.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('"$_texteVocal"',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic,
                              color: AppTheme.textPrimary)),
                    )
                  else
                    Text('Ex: "7h à 17h avec Jean en Ford" puis retappez pour ajouter des infos',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ]),
              ),
            ],

            if (estFerieOuDim) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.4))),
                child: Row(children: [
                  const Icon(Icons.star_rounded, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(nomFerie != null ? '$nomFerie — majorations appliquées'
                      : 'Dimanche — majorations appliquées',
                      style: const TextStyle(fontSize: 12, color: Colors.orange,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ],
            const SizedBox(height: 12),

            // ── Quatorzaine ────────────────────────────────────────
            _sectionCard('Quatorzaine', Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dq == null)
                  Row(children: [
                    const Icon(Icons.info_outline, size: 12, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Non définie — à configurer dans Paramètres',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: AppTheme.textTertiary))),
                  ])
                else ...[
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(labelQ, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: AppTheme.blueAccent,
                            fontWeight: FontWeight.w500))),
                    const SizedBox(width: 8),
                    Text('J.${(_date.difference(dq).inDays.clamp(0, 13) + 1)}/14',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: prog, minHeight: 5,
                      backgroundColor: AppTheme.blueAccent.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.blueAccent))),
                ],
              ],
            )),
            const SizedBox(height: 8),

            // ── Alerte si date en période CP ───────────────────────
            Builder(builder: (ctx) {
              if (_isCongesPaies) return const SizedBox.shrink();
              final conflitCP = widget.toutesGardes.where((g) {
                if (!g.isCongesPaies) return false;
                if (g.cpDateFin == null) {
                  return g.date.year == _date.year && g.date.month == _date.month && g.date.day == _date.day;
                }
                final debut = DateTime(g.date.year, g.date.month, g.date.day);
                final fin = DateTime(g.cpDateFin!.year, g.cpDateFin!.month, g.cpDateFin!.day);
                final cible = DateTime(_date.year, _date.month, _date.day);
                return !cible.isBefore(debut) && !cible.isAfter(fin);
              }).firstOrNull;
              if (conflitCP == null) return const SizedBox.shrink();
              final fin = conflitCP.cpDateFin;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.block, size: 14, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    fin != null
                        ? '🏖️ CP du ${conflitCP.date.day}/${conflitCP.date.month} au ${fin.day}/${fin.month} — cette date est en congé payé'
                        : '🏖️ CP posé le ${conflitCP.date.day}/${conflitCP.date.month} — cette date est en congé payé',
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  )),
                ]),
              );
            }),

            // ── Congés payés ───────────────────────────────────────
            _sectionCard('Congés payés', Column(children: [
              GestureDetector(
                onTap: () => setState(() {
                  _isCongesPaies = !_isCongesPaies;
                  if (_isCongesPaies) _jourNonTravaille = false;
                }),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _isCongesPaies
                        ? const Color(0xFF1D9E75).withOpacity(0.15)
                        : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isCongesPaies
                        ? const Color(0xFF1D9E75).withOpacity(0.5)
                        : AppTheme.bgCardBorder),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_isCongesPaies ? Icons.beach_access : Icons.beach_access_outlined,
                        size: 16, color: _isCongesPaies
                            ? const Color(0xFF1D9E75) : AppTheme.textTertiary),
                    const SizedBox(width: 8),
                    Text('Congé payé',
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _isCongesPaies
                                ? const Color(0xFF1D9E75) : AppTheme.textSecondary)),
                  ]),
                ),
              ),
              if (_isCongesPaies) ...[
                const SizedBox(height: 12),
                // Période ou journée seule
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Début', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final p = await showDatePicker(
                          context: context, initialDate: _date,
                          firstDate: DateTime(2020), lastDate: DateTime(2030),
                          locale: const Locale('fr', 'FR'),
                        );
                        if (p != null) setState(() => _date = p);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D9E75).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1D9E75).withOpacity(0.3)),
                        ),
                        child: Text('${_date.day}/${_date.month}/${_date.year}',
                            style: const TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w600, color: Color(0xFF085041))),
                      ),
                    ),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Fin (optionnel)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _cpDateFin ?? _date.add(const Duration(days: 1)),
                          firstDate: _date,
                          lastDate: DateTime(2030),
                          locale: const Locale('fr', 'FR'),
                        );
                        if (p != null) setState(() => _cpDateFin = p);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _cpDateFin != null
                              ? const Color(0xFF1D9E75).withOpacity(0.1)
                              : AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _cpDateFin != null
                              ? const Color(0xFF1D9E75).withOpacity(0.3)
                              : AppTheme.bgCardBorder),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(_cpDateFin != null
                              ? '${_cpDateFin!.day}/${_cpDateFin!.month}/${_cpDateFin!.year}'
                              : 'Journée seule',
                              style: TextStyle(fontSize: 12,
                                  fontWeight: _cpDateFin != null ? FontWeight.w600 : FontWeight.normal,
                                  color: _cpDateFin != null
                                      ? const Color(0xFF085041) : AppTheme.textTertiary)),
                          if (_cpDateFin != null)
                            GestureDetector(
                              onTap: () => setState(() => _cpDateFin = null),
                              child: Icon(Icons.close, size: 14, color: AppTheme.textTertiary),
                            ),
                        ]),
                      ),
                    ),
                  ])),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D9E75).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, size: 14, color: Color(0xFF1D9E75)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      _cpDateFin != null
                          ? 'Période : ${_date.day}/${_date.month} → ${_cpDateFin!.day}/${_cpDateFin!.month} (${_date.difference(_cpDateFin!).inDays.abs() + 1} jours)'
                          : 'Journée CP du ${_date.day}/${_date.month}/${_date.year}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF085041)),
                    )),
                  ]),
                ),
              ],
            ])),

            // ── Jour non travaillé ─────────────────────────────────
            _sectionCard('Horaires de travail', Column(children: [
              // Bouton jour non travaillé
              GestureDetector(
                onTap: () => setState(() => _jourNonTravaille = !_jourNonTravaille),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _jourNonTravaille
                        ? Colors.orange.withOpacity(0.15)
                        : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _jourNonTravaille
                        ? Colors.orange.withOpacity(0.5)
                        : AppTheme.bgCardBorder),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_jourNonTravaille ? Icons.event_busy : Icons.event_busy_outlined,
                        size: 16,
                        color: _jourNonTravaille ? Colors.orange : AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text('Jour non travaillé',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: _jourNonTravaille ? Colors.orange : AppTheme.textSecondary)),
                  ]),
                ),
              ),
              if (!_jourNonTravaille) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _champHeure('Début', _debutHeureCtrl, _debutMinCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _champHeure('Fin', _finHeureCtrl, _finMinCtrl)),
                ]),
                const SizedBox(height: 8),
                ClipRect(
                  child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppTheme.blueAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.timer_outlined, size: 13, color: AppTheme.blueAccent),
                    const SizedBox(width: 5),
                    Flexible(child: Text('Durée : ${Calculs.formatHeures(garde.dureeHeures)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppTheme.blueAccent,
                            fontWeight: FontWeight.w500))),
                  ]),
                  ),
                ),
              ],
            ])),
            const SizedBox(height: 10),

            // ── Pause (seulement si journée travaillée) ────────────
            if (!_jourNonTravaille) ...[
              _sectionCard('Pause', Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Inclure une pause',
                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  Switch(value: _avecPause,
                      onChanged: (v) => setState(() => _avecPause = v)),
                ]),
                if (_avecPause) ...[
                  const SizedBox(height: 12),
                  Center(child: Text(
                    '${_pauseMinutes ~/ 60 > 0 ? '${_pauseMinutes ~/ 60}h ' : ''}${(_pauseMinutes % 60).toString().padLeft(2, '0')}min',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                        color: AppTheme.blueAccent))),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Column(children: [
                      Text('Heures', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _btnPM(Icons.remove, () => setState(() {
                          if (_pauseMinutes >= 60) _pauseMinutes -= 60;
                        })),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('${_pauseMinutes ~/ 60}h', style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary))),
                        _btnPM(Icons.add, () => setState(() => _pauseMinutes += 60)),
                      ]),
                    ])),
                    Container(width: 1, height: 40, color: AppTheme.bgCardBorder),
                    Expanded(child: Column(children: [
                      Text('Minutes', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _btnPM(Icons.remove, () => setState(() {
                          if (_pauseMinutes % 60 > 0) _pauseMinutes -= 1;
                        })),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('${(_pauseMinutes % 60).toString().padLeft(2, '0')}min',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary))),
                        _btnPM(Icons.add, () => setState(() => _pauseMinutes += 1)),
                      ]),
                    ])),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.free_breakfast_outlined, size: 14, color: AppTheme.colorAmber),
                      const SizedBox(width: 6),
                      Text('Pause déduite : ${Calculs.formatHeures(_pauseMinutes / 60)}',
                          style: TextStyle(fontSize: 12, color: AppTheme.colorAmber,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ],
              ])),
              const SizedBox(height: 10),
            ],

            // ── Panier repas ───────────────────────────────────────
            if (!_jourNonTravaille) ...[
              _sectionCard('Panier repas', Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Inclure un panier repas',
                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  Switch(value: _avecPanier,
                      onChanged: (v) => setState(() => _avecPanier = v)),
                ]),
                if (_avecPanier) ...[
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Montant',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    _compteur(_panierRepasGarde.toStringAsFixed(2),
                      onMoins: () => setState(() {
                        if (_panierRepasGarde >= 0.5) _panierRepasGarde = double.parse(
                            (_panierRepasGarde - 0.5).toStringAsFixed(2));
                      }),
                      onPlus: () => setState(() => _panierRepasGarde = double.parse(
                          (_panierRepasGarde + 0.5).toStringAsFixed(2))),
                      unite: '€',
                    ),
                  ]),
                ],
              ])),
              const SizedBox(height: 10),
            ],

            // ── Longue distance ─────────────────────────────────────
            if (!_isCongesPaies && !_jourNonTravaille) _sectionCard('Longue distance', Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Prime longue distance',
                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                Switch(value: _avecLongueDistance,
                    onChanged: (v) => setState(() {
                      _avecLongueDistance = v;
                      if (!v) _primeLongueDistance = 0;
                    })),
              ]),
              if (_avecLongueDistance) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _longuePrimeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Montant de la prime (€)',
                    labelStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    prefixIcon: Icon(Icons.directions_car_outlined, size: 18, color: AppTheme.blueAccent),
                    suffixText: '€',
                    suffixStyle: TextStyle(color: AppTheme.textSecondary),
                  ),
                  onChanged: (v) {
                    final val = double.tryParse(v.replaceAll(',', '.'));
                    setState(() => _primeLongueDistance = val ?? 0);
                  },
                ),
              ],
            ])),
            const SizedBox(height: 10),

            // ── Rappel (collègue + véhicule) ──────────────────────
            _sectionCard('Rappel', Column(children: [
              TextField(
                controller: _collegueCtrl,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nom du collègue',
                  labelStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  prefixIcon: Icon(Icons.person_outline, size: 18, color: AppTheme.blueAccent),
                  hintText: 'Ex: Jean Dupont',
                  hintStyle: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _vehiculeCtrl,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Véhicule utilisé',
                  labelStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  prefixIcon: Icon(Icons.directions_car_outlined, size: 18,
                      color: AppTheme.blueAccent),
                  hintText: 'Ex: Voiture personnelle, Moto...',
                  hintStyle: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                ),
              ),
              if (widget.kmDomicileTravail > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.blueAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.route_outlined, size: 14, color: AppTheme.blueAccent),
                    const SizedBox(width: 6),
                    Text('${widget.kmDomicileTravail.toStringAsFixed(0)} km domicile-travail',
                        style: TextStyle(fontSize: 11, color: AppTheme.blueAccent)),
                    const Spacer(),
                    Text('(Paramètres)',
                        style: TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
                  ]),
                ),
              ],
            ])),
            const SizedBox(height: 10),

            // ── Achats divers ──────────────────────────────────────
            _sectionCard('Achats divers', Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Frais du jour',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                GestureDetector(
                  onTap: () => _ouvrirAjoutAchat(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.blueAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.blueAccent.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.add, size: 13, color: AppTheme.blueAccent),
                      const SizedBox(width: 3),
                      Text('Ajouter', style: TextStyle(fontSize: 11, color: AppTheme.blueAccent)),
                    ]),
                  ),
                ),
              ]),
              if (_achats.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final a in _achats)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.colorAmber.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.colorAmber.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Icon(Icons.receipt_outlined, size: 14, color: AppTheme.colorAmber),
                      const SizedBox(width: 8),
                      Expanded(child: Text(a.intitule, style: TextStyle(
                          fontSize: 12, color: AppTheme.textPrimary))),
                      Text('${a.montant.toStringAsFixed(2)} €',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppTheme.colorAmber)),
                      const SizedBox(width: 8),
                      // Bouton modifier
                      GestureDetector(
                        onTap: () => _ouvrirAjoutAchat(achat: a),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.blueAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.edit_outlined, size: 13,
                              color: AppTheme.blueAccent),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Bouton supprimer
                      GestureDetector(
                        onTap: () => setState(
                            () => _achats.removeWhere((x) => x.id == a.id)),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.delete_outline, size: 13,
                              color: AppTheme.colorRed),
                        ),
                      ),
                    ]),
                  ),
                Divider(color: AppTheme.bgCardBorder),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary)),
                  Text('${totalAchats.toStringAsFixed(2)} €',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppTheme.colorAmber)),
                ]),
              ] else ...[
                const SizedBox(height: 8),
                Text('Aucun achat — appuyez sur "Ajouter"',
                    style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
              ],
            ])),
            const SizedBox(height: 12),

            // ── Récapitulatif CCN ──────────────────────────────────
            if (!_jourNonTravaille) Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.blueAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.blueAccent.withOpacity(0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Calcul automatique CCN',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: AppTheme.blueAccent)),
                const SizedBox(height: 10),
                _calcRow('Durée effective', Calculs.formatHeures(garde.dureeHeures), null),
                if (_avecPause)
                  _calcRow('Pause déduite',
                      '- ${Calculs.formatHeures(_pauseMinutes / 60)}', null),
                _calcRow('Heures de nuit (21h-6h)', Calculs.formatHeures(heuresNuit),
                    'maj. +${majNuit.toStringAsFixed(2)} €'),
                _calcRow(nomFerie != null ? 'Jour férié ($nomFerie)' : 'Dimanche / férié',
                    estFerieOuDim ? 'Oui' : 'Non',
                    estFerieOuDim ? '+${majDim.toStringAsFixed(2)} €' : null),
                _calcRow('IDAJ (amplitude > 12h)',
                    garde.hasIDAJ
                        ? (garde.amplitudeMinutes / 60 > 13
                            ? '+75% puis +100%'
                            : '+75% du taux')
                        : 'Non',
                    garde.hasIDAJ ? '+${idaj.toStringAsFixed(2)} €' : null),
                if (_avecPanier)
                  _calcRow('Panier repas', '${_panierRepasGarde.toStringAsFixed(2)} €', null),
                if (_avecLongueDistance && _primeLongueDistance > 0)
                  _calcRow('Prime longue distance', '+${_primeLongueDistance.toStringAsFixed(2)} €', null),
                Divider(color: AppTheme.bgCardBorder),
                _calcRow('Total brut estimé', '${brut.toStringAsFixed(2)} €', null, isBold: true),
              ]),
            ),

            if (_jourNonTravaille) Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.event_busy, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Jour non travaillé enregistré',
                    style: TextStyle(fontSize: 13, color: Colors.orange,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sauvegarderGarde,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.blueAccent,
                ),
                child: Text(estModif ? 'Enregistrer les modifications' : 'Enregistrer la garde',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sectionCard(String label, Widget child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: AppTheme.cardDecoration(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      const SizedBox(height: 8), child,
    ]),
  );

  Widget _compteur(String valeur, {required VoidCallback onMoins,
      required VoidCallback onPlus, required String unite}) {
    return Row(children: [
      GestureDetector(onTap: onMoins,
        child: Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: AppTheme.blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.remove, size: 16, color: AppTheme.blueAccent))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('$valeur $unite', style: TextStyle(fontSize: 15,
            fontWeight: FontWeight.w500, color: AppTheme.textPrimary))),
      GestureDetector(onTap: onPlus,
        child: Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: AppTheme.blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.add, size: 16, color: AppTheme.blueAccent))),
    ]);
  }

  Widget _calcRow(String label, String value, String? sub, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12,
              fontWeight: isBold ? FontWeight.w500 : FontWeight.normal,
              color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary)),
          if (sub != null)
            Text(sub, style: const TextStyle(fontSize: 10, color: AppTheme.blueAccent)),
        ]),
        Text(value, style: TextStyle(fontSize: 12,
            fontWeight: isBold ? FontWeight.w500 : FontWeight.normal,
            color: isBold ? AppTheme.colorGreen : AppTheme.blueAccent)),
      ]),
    );
  }
}
