import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/ai_server_url.dart';

/// Where the app looks for the AI gateway.
///
/// The address is a setting of this device, not of the learner's account:
/// "127.0.0.1" is right on a simulator and wrong on a real phone, where it
/// means the phone itself. A learner on a phone enters their computer's address
/// once (Account → AI & voice → AI server) and it is remembered.
class AiServerSettings extends ChangeNotifier {
  AiServerSettings({String Function()? defaultUrl})
      : _defaultUrl = defaultUrl ?? aiServerUrl;

  static const _key = 'sprichst_ai_server_url';

  final String Function() _defaultUrl;
  String? _custom;
  var _loaded = false;

  /// The address in use: the learner's own, else the platform default.
  String get url => _custom ?? _defaultUrl();

  String get defaultUrl => _defaultUrl();
  bool get isCustom => _custom != null;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_key);
      if (saved != null && normalise(saved) != null) _custom = saved;
    } catch (_) {
      // Settings storage can be unavailable; the default still works.
    }
    notifyListeners();
  }

  /// Saves [input] as the gateway address. Returns false (and changes nothing)
  /// when it is not a usable address. An empty value restores the default.
  Future<bool> save(String input) async {
    final trimmed = input.trim();
    final preferences = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      _custom = null;
      await preferences.remove(_key);
      notifyListeners();
      return true;
    }
    final clean = normalise(trimmed);
    if (clean == null) return false;
    if (clean == _defaultUrl()) {
      // Typing the default back in is the same as having no custom address.
      _custom = null;
      await preferences.remove(_key);
      notifyListeners();
      return true;
    }
    _custom = clean;
    await preferences.setString(_key, clean);
    notifyListeners();
    return true;
  }

  /// A tidy `http(s)://host[:port]` form of what the learner typed, or null if
  /// it cannot be an address. Accepts "192.168.2.212", "mac.local:8000" and
  /// full URLs; a bare host gets `http://` and the gateway's usual port.
  static String? normalise(String input) {
    var text = input.trim();
    if (text.isEmpty || RegExp(r'\s').hasMatch(text)) return null;
    if (!text.contains('://')) text = 'http://$text';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(uri.host)) {
      return null;
    }
    final port = uri.hasPort
        ? uri.port
        : (input.contains('://') && uri.scheme == 'https' ? null : 8000);
    return Uri(scheme: uri.scheme, host: uri.host, port: port).toString();
  }
}

/// What a connection test found, in words a learner can act on.
class ConnectionReport {
  const ConnectionReport.ok(this.detail)
      : isOk = true,
        hint = null;
  const ConnectionReport.failed(this.detail, this.hint) : isOk = false;

  final bool isOk;
  final String detail;
  final String? hint;
}

/// Asks the gateway at [baseUrl] for `/health` and explains what happened.
Future<ConnectionReport> checkAiServer(
  String baseUrl, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 6),
}) async {
  final http_ = client ?? http.Client();
  final isLoopback =
      baseUrl.contains('127.0.0.1') || baseUrl.contains('localhost');
  try {
    final response =
        await http_.get(Uri.parse('$baseUrl/health')).timeout(timeout);
    if (response.statusCode == 200) {
      return const ConnectionReport.ok('Connected. The AI server is running.');
    }
    return ConnectionReport.failed(
      'The address answered, but it is not the Sprichst AI server '
          '(status ${response.statusCode}).',
      'Check the port. The gateway listens on 8000 by default.',
    );
  } on TimeoutException {
    return const ConnectionReport.failed(
      'No answer within a few seconds.',
      'Make sure your phone and computer are on the same Wi-Fi, and that your '
          "computer's firewall allows incoming connections on port 8000.",
    );
  } on SocketException catch (error) {
    return _refused(error.message, isLoopback);
  } on http.ClientException catch (error) {
    return _refused(error.message, isLoopback);
  } catch (error) {
    return ConnectionReport.failed('Could not connect: $error', null);
  } finally {
    if (client == null) http_.close();
  }
}

ConnectionReport _refused(String message, bool isLoopback) =>
    ConnectionReport.failed(
      'Could not connect ($message).',
      isLoopback
          ? '127.0.0.1 means this device itself. On a real phone, enter your '
              "computer's address, such as 192.168.1.20, and start the server with "
              '--host 0.0.0.0 (ai-server/run.sh does this).'
          : 'Is the server running? Start it with ai-server/run.sh, which '
              'listens on your network and not only on this computer.',
    );
