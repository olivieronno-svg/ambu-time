import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/garde.dart';
import '../models/prime.dart';

class CloudSyncService {
  static final _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>>? _docRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('data')
        .doc('main');
  }

  /// Pousse toutes les données vers Firestore.
  /// Retourne `true` si l'écriture a réussi, `false` sinon (réseau, règles, etc.).
  /// Retourne aussi `false` si l'utilisateur n'est pas connecté (no-op).
  static Future<bool> syncToCloud({
    required List<Garde> gardes,
    required Map<String, dynamic> params,
    required List<Map<String, dynamic>> planningMaps,
  }) async {
    final ref = _docRef();
    if (ref == null) return false;
    try {
      await ref.set({
        'gardes': gardes.map((g) => g.toMap()).toList(),
        'parametres': _serializeParams(params),
        'planning': planningMaps,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('CloudSync erreur : $e');
      return false;
    }
  }

  /// Récupère les données depuis Firestore. Retourne null si non connecté ou absent.
  static Future<Map<String, dynamic>?> fetchFromCloud() async {
    final ref = _docRef();
    if (ref == null) return null;
    try {
      final snap = await ref.get();
      if (!snap.exists) return null;
      return snap.data();
    } catch (e) {
      debugPrint('CloudSync fetch erreur : $e');
      return null;
    }
  }

  /// Supprime toutes les données cloud de l'utilisateur connecté.
  /// Utilisé pour la suppression de compte (conformité Google Play).
  static Future<bool> deleteCloudData() async {
    final ref = _docRef();
    if (ref == null) return false;
    try {
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('CloudSync delete erreur : $e');
      return false;
    }
  }

  /// Vérifie si des données cloud existent pour l'utilisateur connecté.
  static Future<bool> hasCloudData() async {
    final ref = _docRef();
    if (ref == null) return false;
    try {
      final snap = await ref.get();
      return snap.exists;
    } catch (e) {
      debugPrint('CloudSync hasData erreur : $e');
      return false;
    }
  }

  static Map<String, dynamic> _serializeParams(Map<String, dynamic> params) {
    final p = Map<String, dynamic>.from(params);
    // DateTime → ISO8601
    final dt = p['debutQuatorzaine'];
    if (dt is DateTime) {
      p['debutQuatorzaine'] = dt.toIso8601String();
    } else {
      p['debutQuatorzaine'] = null;
    }
    // List<PrimeMensuelle> → List<Map>
    final primes = p['primes'];
    if (primes is List) {
      p['primes'] = primes
          .whereType<PrimeMensuelle>()
          .map((pr) => pr.toMap())
          .toList();
    }
    return p;
  }
}
