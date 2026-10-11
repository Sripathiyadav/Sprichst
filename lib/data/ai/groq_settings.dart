import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Somewhere to keep one secret. The Groq key goes to the platform's secure
/// storage (Keychain on Apple devices, Keystore-backed storage on Android).
abstract class SecretStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
}

class SecureStorageSecretStore implements SecretStore {
  const SecureStorageSecretStore(
      [this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);

  @override
  Future<void> delete(String name) => _storage.delete(key: name);
}

/// A model the learner may choose on Groq's free tier.
class GroqModel {
  const GroqModel(this.id, this.label, this.note);
  final String id;
  final String label;
  final String note;
}

const groqModels = <GroqModel>[
  GroqModel('llama-3.3-70b-versatile', 'Llama 3.3 70B (best answers)',
      'The most accurate German. Uses your daily allowance faster.'),
  GroqModel('llama-3.1-8b-instant', 'Llama 3.1 8B (more messages)',
      'Quicker and lighter, so your daily allowance lasts longer.'),
];

/// The learner's own Groq account details: the API key (secret, this device
/// only, never synced or logged) and the chosen model.
///
/// There is no Sprichst-owned AI server in the production path: the app calls
/// Groq directly, so what is used counts against the learner's own free quota.
class GroqSettings extends ChangeNotifier {
  GroqSettings({SecretStore? store})
      : _store = store ?? const SecureStorageSecretStore();

  static const _keyName = 'sprichst_groq_api_key';
  static const _modelName = 'sprichst_groq_model';

  final SecretStore _store;
  String? _key;
  String _model = groqModels.first.id;
  var _loaded = false;

  bool get hasKey => _key != null;
  String get model => _model;

  /// The key, for the one place that sends it to Groq.
  String? get key => _key;

  /// Enough of the key to recognise it, never all of it: `gsk_…a1b2`.
  String? get maskedKey {
    final k = _key;
    if (k == null) return null;
    return k.length <= 8
        ? 'gsk_…'
        : '${k.substring(0, 4)}…${k.substring(k.length - 4)}';
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final saved = await _store.read(_keyName);
      if (saved != null && validKey(saved) != null) _key = saved;
    } catch (_) {
      // Secure storage can be unavailable (some browsers, locked keychain).
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      final model = preferences.getString(_modelName);
      if (model != null && groqModels.any((m) => m.id == model)) _model = model;
    } catch (_) {}
    notifyListeners();
  }

  /// A Groq key as typed: trimmed, and only if it looks like one.
  static String? validKey(String input) {
    final trimmed = input.trim();
    return RegExp(r'^gsk_[A-Za-z0-9]{20,200}$').hasMatch(trimmed)
        ? trimmed
        : null;
  }

  /// Saves [input] as the key. Returns false, changing nothing, when it does
  /// not look like a Groq key or cannot be stored.
  Future<bool> saveKey(String input) async {
    final clean = validKey(input);
    if (clean == null) return false;
    try {
      await _store.write(_keyName, clean);
    } catch (_) {
      return false;
    }
    _key = clean;
    notifyListeners();
    return true;
  }

  Future<void> removeKey() async {
    _key = null;
    notifyListeners();
    try {
      await _store.delete(_keyName);
    } catch (_) {}
  }

  Future<void> setModel(String id) async {
    if (!groqModels.any((m) => m.id == id)) return;
    _model = id;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_modelName, id);
    } catch (_) {}
  }
}
