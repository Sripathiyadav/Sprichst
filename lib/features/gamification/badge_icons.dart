import 'package:flutter/material.dart';

import '../../domain/learning/achievements.dart' as game;

/// Maps a badge's icon key to a symbol.
IconData badgeIcon(String key) => switch (key) {
      'flag' => Icons.flag_rounded,
      'school' => Icons.school_rounded,
      'target' => Icons.gps_fixed_rounded,
      'trending' => Icons.trending_up_rounded,
      'fire' => Icons.local_fire_department_rounded,
      'cards' => Icons.style_rounded,
      'memory' => Icons.psychology_rounded,
      'game' => Icons.sports_esports_rounded,
      'article' => Icons.tag_rounded,
      'quest' => Icons.task_alt_rounded,
      'star' => Icons.star_rounded,
      _ => Icons.emoji_events_rounded,
    };

IconData iconOf(game.Achievement badge) => badgeIcon(badge.icon);
