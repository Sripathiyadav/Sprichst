import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/dialogue_models.dart';
import '../../domain/models/learning_models.dart';
import '../../domain/repositories/learning_repository.dart';
import '../local/local_learning_repository.dart';
import '../profile_codec.dart';
import '../profile_sync.dart';

class FirestoreLearningRepository implements LearningRepository {
  FirestoreLearningRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    LocalLearningRepository? localRepository,
    ProfileCache Function(String uid)? cacheFor,
    this.syncDelay = const Duration(seconds: 8),
  })  : _cacheFor = cacheFor ?? SharedPrefsProfileCache.new,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _localRepository = localRepository ?? LocalLearningRepository();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final LocalLearningRepository _localRepository;
  final ProfileCache Function(String uid) _cacheFor;

  /// How long profile changes are gathered before one write to Firestore.
  final Duration syncDelay;
  final _stores = <String, SyncedProfileStore>{};
  DocumentReference<Map<String, dynamic>> get _profileDocument {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError('User must be signed in to access learning data.');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('learning')
        .doc('profile');
  }

  /// The profile with an on-device copy behind it (see [SyncedProfileStore]
  /// for the offline and conflict policy).
  SyncedProfileStore get _store {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('User must be signed in to access learning data.');
    }
    return _stores.putIfAbsent(
      user.uid,
      () => SyncedProfileStore(
        cache: _cacheFor(user.uid),
        loadRemote: _loadRemote,
        saveRemote: _saveRemote,
        isUnreachable: _isUnreachable,
        delay: syncDelay,
      ),
    );
  }

  @override
  Future<void> flush() async {
    for (final store in _stores.values) {
      await store.flush();
    }
  }

  /// Offline, or the service did not answer in time.
  static bool _isUnreachable(Object error) =>
      error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded');

  Future<LearningProfile?> _loadRemote() async {
    final data = (await _profileDocument.get()).data();
    if (data == null) return null;

    return ProfileCodec.decode(
      data,
      decodeDate: (value) => (value as Timestamp).toDate(),
    );
  }

  Future<void> _saveRemote(LearningProfile profile) async {
    // A full overwrite, not a merge: Firestore merges nested maps, so a merge
    // would resurrect lesson progress and skill stats removed by a reset.
    await _profileDocument.set(
      ProfileCodec.encode(profile, encodeDate: Timestamp.fromDate),
    );
  }

  @override
  Future<LearningProfile?> loadProfile() => _store.load();

  @override
  Future<void> saveProfile(LearningProfile profile) => _store.save(profile);

  @override
  Future<void> deleteLearningData() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError('User must be signed in to delete learning data.');
    }

    // Learning data currently lives in documents directly below this
    // collection. Deleting each document (rather than only its parent) makes
    // the operation real for today's schema and keeps it extensible.
    final learning =
        _firestore.collection('users').doc(user.uid).collection('learning');
    final documents = await learning.get();
    final batch = _firestore.batch();

    for (final document in documents.docs) {
      batch.delete(document.reference);
    }

    if (documents.docs.isNotEmpty) {
      await batch.commit();
    }

    await _firestore.collection('users').doc(user.uid).delete();
    await (_stores.remove(user.uid)?.clear() ?? _cacheFor(user.uid).clear());
  }

  @override
  Future<List<Dialogue>> loadDialogues() => _localRepository.loadDialogues();

  @override
  Future<List<Lesson>> loadLessons() {
    return _localRepository.loadLessons();
  }
}
