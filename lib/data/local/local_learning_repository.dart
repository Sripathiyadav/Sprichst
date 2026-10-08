import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/dialogue_models.dart';
import '../../domain/models/learning_models.dart';
import '../../domain/repositories/learning_repository.dart';
import '../curriculum_parser.dart';
import '../profile_codec.dart';

class LocalLearningRepository implements LearningRepository {
  static const _profileKey = 'sprichst_profile_v1';

  List<Lesson>? _lessons;
  List<Dialogue>? _dialogues;

  @override
  Future<LearningProfile?> loadProfile() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_profileKey);
    if (raw == null) return null;
    return ProfileCodec.decode(
      jsonDecode(raw) as Map<String, dynamic>,
      decodeDate: (value) => DateTime.parse(value as String),
    );
  }

  @override
  Future<void> saveProfile(LearningProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _profileKey,
      jsonEncode(ProfileCodec.encode(
        profile,
        encodeDate: (date) => date.toIso8601String(),
      )),
    );
  }

  @override
  Future<void> deleteLearningData() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_profileKey);
  }

  /// Parsed once per repository; the bundled course never changes at runtime.
  @override
  Future<List<Lesson>> loadLessons() async =>
      _lessons ??= CurriculumParser.parse(
          await rootBundle.loadString(CurriculumParser.assetPath));

  @override
  Future<List<Dialogue>> loadDialogues() async =>
      _dialogues ??= CurriculumParser.parseDialogues(
          await rootBundle.loadString(CurriculumParser.assetPath));
}
