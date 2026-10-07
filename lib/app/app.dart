import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sprichst/features/auth/auth_view_model.dart';

import '../features/ai_coach/ai_coach_view.dart';
import '../features/account/account_view.dart';
import '../features/auth/auth_view.dart';
import '../features/home/home_view.dart';
import '../features/learn/learn_view.dart';
import '../features/onboarding/onboarding_view.dart';
import '../features/practice/practice_view.dart';
import '../features/progress/progress_view.dart';
import '../domain/models/learning_models.dart';
import '../shared/widgets/app_widgets.dart';
import 'app_controller.dart';
import 'theme/app_theme.dart';
import 'theme/breakpoints.dart';

class SprichstApp extends ConsumerStatefulWidget {
  const SprichstApp({super.key});

  @override
  ConsumerState<SprichstApp> createState() => _SprichstAppState();
}

class _SprichstAppState extends ConsumerState<SprichstApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  var _selectedIndex = 0;
  String? _initializedForUserId;

  @override
  Widget build(BuildContext context) {
    // Watch only what this widget renders so unrelated profile changes (a new
    // XP total, say) do not rebuild the whole MaterialApp.
    final appearance = ref.watch(appControllerProvider
        .select((app) => app.profile?.appearancePreference));
    final isLoading =
        ref.watch(appControllerProvider.select((app) => app.isLoading));
    final isOnboarded =
        ref.watch(appControllerProvider.select((app) => app.isOnboarded));
    final authState = ref.watch(authViewModelProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Sprichst',
      debugShowCheckedModeBanner: false,
      theme: SprichstTheme.light,
      darkTheme: SprichstTheme.dark,
      themeMode: switch (appearance) {
        AppearancePreference.light => ThemeMode.light,
        AppearancePreference.dark => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: authState.when(
        loading: () => const _SplashView(),
        error: (_, __) => const AuthView(),
        data: (user) {
          if (user == null) {
            if (_initializedForUserId != null) {
              _initializedForUserId = null;
              Future.microtask(_endSession);
            }
            return const AuthView();
          }

          if (_initializedForUserId != user.uid) {
            _initializedForUserId = user.uid;
            Future.microtask(
                () => ref.read(appControllerProvider).initialize());
            return const _SplashView();
          }

          if (isLoading) return const _SplashView();

          return isOnboarded
              ? _LearningShell(
                  selectedIndex: _selectedIndex,
                  onSelect: (index) => setState(() => _selectedIndex = index),
                )
              : const OnboardingView();
        },
      ),
    );
  }

  /// Clears session state and drops any pushed routes (settings pages, dialogs)
  /// so none can linger above the sign-in screen after sign-out or deletion.
  void _endSession() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    _selectedIndex = 0;
    ref.read(appControllerProvider).clearSession();
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SPRICHST',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(letterSpacing: 3),
              ),
              const SizedBox(height: 12),
              const Text(
                'Deutsch lernen.\nDeutsch sprechen.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
          ),
        ),
      );
}

typedef _Destination = ({String label, IconData icon, IconData selected});

class _LearningShell extends StatelessWidget {
  const _LearningShell({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _destinations = <_Destination>[
    (label: 'Home', icon: Icons.home_outlined, selected: Icons.home),
    (label: 'Learn', icon: Icons.menu_book_outlined, selected: Icons.menu_book),
    (label: 'Practice', icon: Icons.bolt_outlined, selected: Icons.bolt),
    (label: 'Coach', icon: Icons.forum_outlined, selected: Icons.forum),
    (
      label: 'Progress',
      icon: Icons.insights_outlined,
      selected: Icons.insights
    ),
    (label: 'Account', icon: Icons.person_outline, selected: Icons.person),
  ];

  /// Phones have room for four destinations; the rest live behind "More".
  static const _primaryCount = 4;
  static const _moreDestination = (
    label: 'More',
    icon: Icons.more_horiz,
    selected: Icons.more_horiz,
  );

  static const _pages = <Widget>[
    HomeView(),
    LearnView(),
    PracticeView(),
    AICoachView(),
    ProgressView(),
    AccountView(),
  ];

  @override
  Widget build(BuildContext context) {
    final layout = MediaQuery.sizeOf(context).width.navigationLayout;
    final useRail = layout != NavigationLayout.bottomBar;

    return Scaffold(
      body: Row(
        children: [
          if (useRail)
            // Scrollable so six destinations still fit on a short landscape
            // phone; IntrinsicHeight keeps the rail full-height otherwise.
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                      child: NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onSelect,
                    extended: layout == NavigationLayout.extendedRail,
                    labelType: layout == NavigationLayout.extendedRail
                        ? null
                        : NavigationRailLabelType.all,
                    leading: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Text(
                        'S',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    destinations: [
                      for (final item in _destinations)
                        NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selected),
                          label: Text(item.label),
                        ),
                    ],
                  )),
                ),
              ),
            ),
          Expanded(
            child: useRail
                ? IndexedStack(index: selectedIndex, children: _pages)
                : IndexedStack(
                    index: math.min(selectedIndex, _primaryCount),
                    children: [
                      ..._pages.take(_primaryCount),
                      const _MoreView(),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: math.min(selectedIndex, _primaryCount),
              onDestinationSelected: onSelect,
              destinations: [
                for (final item in [
                  ..._destinations.take(_primaryCount),
                  _moreDestination,
                ])
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selected),
                    label: item.label,
                  ),
              ],
            ),
    );
  }
}

/// The phone-only overflow destination: opens the screens that do not fit in
/// the bottom bar.
class _MoreView extends StatelessWidget {
  const _MoreView();

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'More',
        subtitle: 'Your progress, account, and app settings.',
        child: ListView(
          children: const [
            _MoreTile(
              icon: Icons.insights_outlined,
              title: 'Progress',
              subtitle: 'See your skills, XP, and milestones.',
              page: ProgressView(),
            ),
            SizedBox(height: AppSpacing.sm),
            _MoreTile(
              icon: Icons.person_outline,
              title: 'Account',
              subtitle: 'Learning preferences, AI, privacy, and support.',
              page: AccountView(),
            ),
          ],
        ),
      );
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(appBar: AppBar(), body: page),
            ),
          ),
        ),
      );
}
