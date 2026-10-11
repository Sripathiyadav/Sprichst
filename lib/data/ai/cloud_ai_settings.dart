import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_providers.dart';

/// Somewhere to keep secrets. API keys go to the platform's secure storage
/// (Keychain on Apple devices, Keystore-backed storage on Android).
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

/// The learner's own AI accounts: which provider they use, a key per provider
/// (secret, this device only, never synced or logged) and a model per
/// provider.
///
/// There is no Sprichst-owned AI server in the production path: the app calls
/// the provider directly, so what is used counts against the learner's own
/// account. Each provider keeps its own key, so switching back and forth does
/// not mean pasting keys again.
class CloudAISettings extends ChangeNotifier {
  CloudAISettings({SecretStore? store})
      : _store = store ?? const SecureStorageSecretStore();

  // Groq's names predate the other providers; they are what the scheme below
  // produces for it, so keys saved by earlier versions still load.
  static String keyNameOf(String providerId) =>
      'sprichst_${providerId}_api_key';
  static String modelNameOf(String providerId) =>
      'sprichst_${providerId}_model';
  static const _providerName = 'sprichst_ai_provider';
  static const _customUrlName = 'sprichst_custom_base_url';

  final SecretStore _store;
  final _keys = <String, String>{};
  final _models = <String, String>{};
  CloudProvider _provider = CloudProvider.groq;
  String? _customBaseUrl;
  var _loaded = false;
  var _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Loading and saving finish asynchronously, possibly after the owner is gone.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  CloudProvider get provider => _provider;

  /// The address requests go to: the provider's, or the one the learner typed
  /// for [CloudProvider.custom].
  String? get baseUrl =>
      _provider.isCustom ? _customBaseUrl : _provider.baseUrl;
  String? get customBaseUrl => _customBaseUrl;

  /// Whether the chosen provider can be called: it has a key (or needs none)
  /// and an address and model.
  bool get isConfigured {
    if (baseUrl == null || model.isEmpty) return false;
    return _keys.containsKey(_provider.id) || _provider.keyOptional;
  }

  /// Kept for the places that only ask "can the cloud answer?".
  bool get hasKey => isConfigured;

  bool hasKeyFor(CloudProvider provider) => _keys.containsKey(provider.id);

  /// The chosen provider's key, for the one place that sends it.
  String? get key => _keys[_provider.id];

  String get model => _models[_provider.id] ?? _provider.defaultModel;

  /// Enough of the key to recognise it, never all of it: `gsk_…a1b2`.
  String? get maskedKey => maskedKeyFor(_provider);

  String? maskedKeyFor(CloudProvider provider) {
    final k = _keys[provider.id];
    if (k == null) return null;
    return k.length <= 12
        ? '…'
        : '${k.substring(0, 4)}…${k.substring(k.length - 4)}';
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    for (final p in cloudProviders) {
      try {
        final saved = await _store.read(keyNameOf(p.id));
        if (saved != null && validKey(saved) != null) _keys[p.id] = saved;
      } catch (_) {
        // Secure storage can be unavailable (some browsers, locked keychain).
      }
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      _provider = CloudProvider.byId(preferences.getString(_providerName));
      _customBaseUrl =
          validBaseUrl(preferences.getString(_customUrlName) ?? '');
      for (final p in cloudProviders) {
        final model = preferences.getString(modelNameOf(p.id));
        if (model != null && validModel(model) != null) _models[p.id] = model;
      }
    } catch (_) {}
    notifyListeners();
  }

  /// An API key as typed: trimmed, and only if it looks like one. Providers
  /// change their key formats, so only the shape is checked here; the
  /// provider itself says whether the key works.
  static String? validKey(String input) {
    final trimmed = input.trim();
    return RegExp(r'^[A-Za-z0-9_\-.:]{16,300}$').hasMatch(trimmed)
        ? trimmed
        : null;
  }

  /// A model id as typed, such as `gpt-4.1-mini` or
  /// `meta-llama/llama-3.3-70b-instruct:free`.
  static String? validModel(String input) {
    final trimmed = input.trim();
    return RegExp(r'^[A-Za-z0-9_\-.:/@]{1,120}$').hasMatch(trimmed)
        ? trimmed
        : null;
  }

  /// An OpenAI-compatible address: https only (keys must not travel in the
  /// clear), without a trailing slash or a `/chat/completions` the learner
  /// may have pasted along with it.
  static String? validBaseUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return null;
    url = url.replaceFirst(RegExp(r'/chat/completions/?$'), '');
    url = url.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) return null;
    return url;
  }

  Future<void> setProvider(String id) async {
    final next = CloudProvider.byId(id);
    if (next.id != id) return;
    _provider = next;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_providerName, id);
    } catch (_) {}
  }

  /// Saves [input] as the chosen provider's key. Returns false, changing
  /// nothing, when it does not look like a key or cannot be stored.
  Future<bool> saveKey(String input) async {
    final clean = validKey(input);
    if (clean == null) return false;
    final id = _provider.id;
    try {
      await _store.write(keyNameOf(id), clean);
    } catch (_) {
      return false;
    }
    _keys[id] = clean;
    notifyListeners();
    return true;
  }

  Future<void> removeKey() async {
    final id = _provider.id;
    _keys.remove(id);
    notifyListeners();
    try {
      await _store.delete(keyNameOf(id));
    } catch (_) {}
  }

  /// Chooses the chosen provider's model: a suggested one or any id typed.
  Future<bool> setModel(String input) async {
    final id = validModel(input);
    if (id == null) return false;
    final providerId = _provider.id;
    _models[providerId] = id;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(modelNameOf(providerId), id);
    } catch (_) {}
    return true;
  }

  Future<bool> setCustomBaseUrl(String input) async {
    final url = validBaseUrl(input);
    if (url == null) return false;
    _customBaseUrl = url;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_customUrlName, url);
    } catch (_) {}
    return true;
  }
}
