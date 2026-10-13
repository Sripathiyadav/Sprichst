import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/breakpoints.dart';
import '../../domain/learning/achievements.dart';
import '../../domain/learning/adaptive_planner.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../account/account_view.dart';
import '../account/web_ai_notice.dart';
import '../learn/lesson_view.dart';
import '../practice/practice_session_view.dart';
import '../practice/writing_practice_view.dart';
import '../translator/translator_view.dart';
import '../gamification/open_quest.dart';
import '../gamification/quests_card.dart';
import 'plan_card.dart';

/// Home: what to learn next, what progress there is, how to continue at once.
/// From the top: the date and greeting, the streak as the one big number beside
/// the level and today's quests, CONTINUE LEARNING as the screen's one feature
/// panel, YOUR DAILY PRACTICE, and the rest of the picture.
class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  /// The greeting for the device's local [hour].
  static String greeting(int hour) => _HomeViewState.greeting(hour);

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();

  /// Bumped on every refresh so the level gauge sweeps up from zero again.
  var _refreshes = 0;

  /// Rebuilds when the hour (or the device's time zone) changes, so the
  /// greeting and date follow the device clock without a restart.
  Timer? _clock;
  late int _hour = DateTime.now().hour;
  late String _zone = DateTime.now().timeZoneName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  void _tick() {
    final now = DateTime.now();
    if (!mounted || (now.hour == _hour && now.timeZoneName == _zone)) return;
    setState(() {
      _hour = now.hour;
      _zone = now.timeZoneName;
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  /// Pull-to-refresh and the logo both end up here.
  Future<void> _refresh() async {
    final ok = await ref.read(appControllerProvider).refresh();
    if (!mounted) return;
    setState(() => _refreshes++);
    if (ok) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not refresh. Check your connection.')));
  }

  /// The logo: back to the top, then refresh.
  void _logoTapped() {
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(0,
          duration: motionDuration(context, 250), curve: Curves.easeOut);
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final profile = app.profile!;
    final plan = app.plan;
    final lesson = app.currentLesson;
    final weak = app.weakSkills;
    final now = DateTime.now();
    final streak = profile.streakAt(now);

    return PageFrame(
      eyebrow: dateEyebrow(now),
      title: '${greeting(now.hour)}, ${profile.name}',
      titleLocale: const Locale('de'),
      subtitle: 'Ready for today’s practice?',
      onLogoTap: _logoTapped,
      trailing: Semantics(
        button: true,
        label: 'Account',
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('home-account'),
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const GlassPage(body: AccountView()))),
          child: ProfileAvatar(name: profile.name),
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: pageListPadding(context),
          children: [
            const WebAiNotice(),
            _Today(
              profile: profile,
              streak: streak,
              now: now,
              levelProgress: app.curriculum.levelProgress(
                  profile.currentLevel, profile.isLessonCompleted),
              replay: _refreshes,
              onStartQuests: () {
                final next = Achievements.todaysQuests(now)
                    .where((q) =>
                        !Achievements.isDone(profile.gamification, q, now))
                    .firstOrNull;
                if (next != null) openQuest(context, ref, next);
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (plan != null) ...[
              const SectionTitle('Continue learning'),
              const SizedBox(height: AppSpacing.sm),
              PlanCard(plan: plan),
              if (plan.kind != PlanKind.lesson && lesson != null) ...[
                const SizedBox(height: AppSpacing.md),
                _NextLessonCard(lesson: lesson),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
            const SectionTitle('Your daily practice'),
            const SizedBox(height: AppSpacing.sm),
            _PracticeCards(due: app.dueReviews),
            const SizedBox(height: AppSpacing.sm),
            Consumer(
              builder: (context, ref, _) => _ToolTile(
                tileKey: const ValueKey('home-writing'),
                icon: Icons.keyboard_alt_outlined,
                title: 'Writing practice',
                subtitle: 'Type German with ä ö ü ß, faster.',
                onTap: () => openWritingPractice(context, ref),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ToolTile(
              tileKey: const ValueKey('home-translator'),
              icon: Icons.translate,
              title: 'Translator',
              subtitle: 'Translate any text, German to English and back.',
              onTap: () => openTranslator(context),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SectionTitle(
              'Daily quests',
              action: Text(
                  '${_questsDone(profile, now)} / ${Achievements.todaysQuests(now).length}',
                  style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: AppSpacing.sm),
            QuestsCard(
              profile: profile,
              now: now,
              onStart: (quest) => openQuest(context, ref, quest),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionTitle('Your progress'),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                // Two columns whenever they fit, including on phones; one column
                // when the width is tight or text is enlarged.
                final enlarged =
                    MediaQuery.textScalerOf(context).scale(1) >= 1.5;
                final twoColumns =
                    constraints.maxWidth >= Breakpoints.twoStatTiles &&
                        !enlarged;
                final width = twoColumns
                    ? (constraints.maxWidth - AppSpacing.sm) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final tile in [
                      StatTile(
                        icon: Icons.bolt_outlined,
                        value: '${profile.xp}',
                        label: 'XP earned',
                      ),
                      StatTile(
                        icon: Icons.refresh,
                        value: '${app.dueReviews}',
                        label: 'Reviews due',
                      ),
                      StatTile(
                        icon: Icons.auto_fix_high_outlined,
                        value: '${app.pendingMistakes}',
                        label: 'Mistakes to fix',
                      ),
                    ])
                      SizedBox(width: width, child: tile),
                  ],
                );
              },
            ),
            if (weak.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              const SectionTitle('Needs practice'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final skill in weak)
                    ActionChip(
                      label: Text(skillLabel(skill)),
                      avatar: const Icon(Icons.bolt, size: 18),
                      onPressed: () => openPractice(
                        context,
                        ref,
                        skillIds: [skill],
                        title: skillLabel(skill),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static int _questsDone(LearningProfile profile, DateTime now) {
    final state = profile.gamification;
    return Achievements.todaysQuests(now)
        .where((q) => Achievements.isDone(state, q, now))
        .length;
  }

  /// The greeting for the device's local hour (the device clock and time zone
  /// decide it, not a server).
  static String greeting(int hour) {
    if (hour >= 5 && hour < 11) return 'Guten Morgen';
    if (hour >= 11 && hour < 18) return 'Guten Tag';
    if (hour >= 18 && hour < 22) return 'Guten Abend';
    return 'Gute Nacht';
  }

  /// "FRIDAY, 9 OCTOBER" (capitals come from the eyebrow style).
  static String dateEyebrow(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }
}

/// The top of Home, in a column: the streak with the level ring beside it,
/// then today's quests across the full width with the button that starts them.
/// A learner without a streak yet gets an invitation, not a zero.
class _Today extends StatelessWidget {
  const _Today({
    required this.profile,
    required this.streak,
    required this.now,
    required this.levelProgress,
    required this.replay,
    required this.onStartQuests,
  });

  final LearningProfile profile;
  final int streak;
  final DateTime now;
  final double levelProgress;
  final int replay;
  final VoidCallback onStartQuests;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quests = Achievements.todaysQuests(now);
    final state = profile.gamification;
    final done = quests.where((q) => Achievements.isDone(state, q, now)).length;
    final total = quests.length;
    final allDone = total > 0 && done == total;

    final streakPart = streak < 1
        ? Text('Finish a lesson today to start your streak.',
            style: theme.textTheme.bodyLarge)
        : EditorialNumber(
            value: streak,
            label: 'Day streak',
            unit: streak == 1 ? 'day' : 'days',
            size: EditorialSize.numeral,
            disc: true,
          );
    return SummaryBlock(
      lead: streakPart,
      level: profile.currentLevel,
      levelProgress: levelProgress,
      replay: replay,
      meterLabel: 'Today’s quests',
      meterValue: total == 0 ? 0 : done / total,
      meterValueLabel: '$done / $total',
      action: allDone
          ? Row(children: [
              Icon(Icons.check_circle, color: context.tokens.success),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                  child: Text('All of today’s quests are done.',
                      style: theme.textTheme.titleSmall)),
            ])
          : PrimaryButton(
              key: const ValueKey('start-quests'),
              label: 'Start today’s quests',
              block: true,
              onPressed: onStartQuests,
            ),
    );
  }
}

/// Words due, and the coach: two cards, each with one quiet forward link.
class _PracticeCards extends ConsumerWidget {
  const _PracticeCards({required this.due});

  final int due;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = context.tokens;

    Widget card({
      required Widget lead,
      required String label,
      required String caption,
      required String action,
      required VoidCallback onTap,
    }) =>
        SoftCard(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              lead,
              const SizedBox(height: AppSpacing.xxs),
              Text(label, style: theme.textTheme.labelLarge),
              Text(caption,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: t.inkMuted)),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onTap,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(action),
                    const SizedBox(width: AppSpacing.xxs),
                    const Icon(Icons.arrow_forward, size: 20),
                  ]),
                ),
              ),
            ],
          ),
        );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: card(
              lead: Text(due.toString().padLeft(2, '0'),
                  style: theme.textTheme.headlineLarge),
              label: due == 1 ? 'Review due' : 'Reviews due',
              caption: due == 0 ? 'Nothing waiting' : 'Before they fade',
              action: 'Review',
              onTap: () => openPractice(context, ref, title: 'Review'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: card(
              lead: Icon(Icons.forum_outlined, size: 32, color: t.ink),
              label: 'Coach',
              caption: 'Practise a conversation',
              action: 'Talk',
              onTap: () => ref.read(shellTabRequestProvider.notifier).state = 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// A way in to a tool (writing practice, the translator) from Home.
class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: tileKey,
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: SoftCard(
          child: Row(
            children: [
              Icon(icon, color: t.ink, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: t.inkMuted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextLessonCard extends StatelessWidget {
  const _NextLessonCard({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return SoftCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEXT LESSON', style: theme.textTheme.labelSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(lesson.title, style: theme.textTheme.titleLarge),
                Text('${lesson.durationMinutes} min · ${lesson.objective}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: t.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LessonView(lesson: lesson),
              ),
            ),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}
