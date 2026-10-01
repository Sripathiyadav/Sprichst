import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sprichst/features/auth/auth_view_model.dart';

import '../features/ai_coach/ai_coach_view.dart';
import '../features/auth/auth_view.dart';
import '../features/home/home_view.dart';
import '../features/learn/learn_view.dart';
import '../features/onboarding/onboarding_view.dart';
import '../features/practice/practice_view.dart';
import '../features/progress/progress_view.dart';
import 'app_controller.dart';
import 'theme/app_theme.dart';

class SprichstApp extends ConsumerStatefulWidget {
  const SprichstApp({super.key});

  @override
  ConsumerState<SprichstApp> createState() => _SprichstAppState();
}

class _SprichstAppState extends ConsumerState<SprichstApp> {
  var _selectedIndex = 0;
  bool _learningInitialized = false;

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final authState = ref.watch(authViewModelProvider);

    return MaterialApp(
      title: 'Sprichst',
      debugShowCheckedModeBanner: false,
      theme: SprichstTheme.light,
      home: authState.when(
        loading: () => const _SplashView(),
        error: (_, __) => const AuthView(),
        data: (user) {
          if (user == null) {
            return const AuthView();
          }

          if (app.isLoading) {
            if (!_learningInitialized) {
              _learningInitialized = true;

              Future.microtask(() {
                ref.read(appControllerProvider).initialize();
              });
            }

            return const _SplashView();
          }

          return app.isOnboarded
              ? _LearningShell(
                  selectedIndex: _selectedIndex,
                  onSelect: (index) {
                    setState(() => _selectedIndex = index);
                  },
                )
              : const OnboardingView();
        },
      ),
    );
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
                'SPRICHTS',
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

class _LearningShell extends StatelessWidget {
  const _LearningShell({
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _items = [
    (
      label: 'Home',
      icon: Icons.home_outlined,
      selected: Icons.home,
    ),
    (
      label: 'Learn',
      icon: Icons.menu_book_outlined,
      selected: Icons.menu_book,
    ),
    (
      label: 'Practice',
      icon: Icons.bolt_outlined,
      selected: Icons.bolt,
    ),
    (
      label: 'Coach',
      icon: Icons.forum_outlined,
      selected: Icons.forum,
    ),
    (
      label: 'Progress',
      icon: Icons.insights_outlined,
      selected: Icons.insights,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const pages = [
      HomeView(),
      LearnView(),
      PracticeView(),
      AICoachView(),
      ProgressView(),
    ];

    final isDesktop = MediaQuery.sizeOf(context).width >= 840;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelect,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'S',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: SprichstTheme.forest,
                  ),
                ),
              ),
              destinations: [
                for (final item in _items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selected),
                    label: Text(item.label),
                  ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelect,
              destinations: [
                for (final item in _items)
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
