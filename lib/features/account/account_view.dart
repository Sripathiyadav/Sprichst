import 'dart:convert';

import 'package:flutter/material.dart';

import '../onboarding/onboarding_view.dart' show GoalPicker;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/app_info.dart';
import '../../app/theme/app_theme.dart';
import '../../data/profile_codec.dart';
import '../../domain/models/learning_models.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../shared/widgets/app_widgets.dart';
import '../auth/auth_view_model.dart';
import 'appearance_page.dart';

class AccountView extends ConsumerWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appControllerProvider).profile!;
    final user = ref.watch(authViewModelProvider).valueOrNull;
    final email = user?.email ?? 'Signed-in learner';

    return PageFrame(
      title: 'Account',
      subtitle: 'Your learning preferences, privacy, and app settings.',
      trailing: ProfileAvatar(name: profile.name),
      child: ListView(
        padding: pageListPadding(context),
        children: [
          SoftCard(
            color: context.softSurface,
            child: Row(
              children: [
                ProfileAvatar(name: profile.name, radius: 28, filled: true),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(email),
                      const SizedBox(height: AppSpacing.xxs),
                      Text('${profile.currentLevel.label} learner'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => _push(context, const _ProfilePage()),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SettingsSection(
            title: 'Learning',
            children: [
              SettingsTile(
                icon: Icons.school_outlined,
                title: 'Learning preferences',
                subtitle:
                    '${profile.currentLevel.label} now · ${profile.dailyGoalMinutes} minutes a day',
                onTap: () => _push(context, const _LearningPreferencesPage()),
              ),
            ],
          ),
          SettingsSection(
            title: 'App',
            children: [
              SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: _appearanceSummary(profile),
                onTap: () => _push(context, const AppearancePage()),
              ),
              SettingsTile(
                icon: Icons.smart_toy_outlined,
                title: 'AI & voice',
                subtitle:
                    '${profile.aiProviderPreference.label} · ${profile.voice} · ${profile.speechRate} wpm',
                onTap: () => _push(context, const _AIAndVoicePage()),
              ),
              SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: _notificationSummary(profile),
                onTap: () => _push(context, const _NotificationsPage()),
              ),
            ],
          ),
          SettingsSection(
            title: 'Privacy & support',
            children: [
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy & data',
                subtitle:
                    'See what stays on your account, device, and AI gateway.',
                onTap: () => _push(context, const _PrivacyAndDataPage()),
              ),
              SettingsTile(
                icon: Icons.support_agent_outlined,
                title: 'Contact developer',
                subtitle: 'Report a problem or share feedback.',
                onTap: () => _push(context, const _ContactPage()),
              ),
              SettingsTile(
                icon: Icons.info_outline,
                title: 'About Sprichst',
                subtitle: 'Version ${AppInfo.version}',
                onTap: () => _push(context, const _AboutPage()),
              ),
            ],
          ),
          SettingsSection(
            title: 'Account',
            children: [
              SettingsTile(
                icon: Icons.logout,
                title: 'Sign out',
                subtitle: 'Keep your saved learning data and sign in later.',
                onTap: () => ref.read(authViewModelProvider.notifier).signOut(),
              ),
            ],
          ),
          SettingsSection(
            title: 'Danger zone',
            description:
                'These actions are permanent. Read each confirmation carefully.',
            children: [
              SettingsTile(
                icon: Icons.restart_alt,
                title: 'Reset learning progress',
                subtitle:
                    'Remove lessons, reviews, XP, and streaks but keep your account.',
                destructive: true,
                onTap: () => _resetLearningProgress(context, ref),
              ),
              SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Delete account',
                subtitle:
                    'Delete your current learning data and Firebase account.',
                destructive: true,
                onTap: () => _deleteAccount(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _appearanceSummary(LearningProfile profile) {
    final mode = profile.appearancePreference.label;
    return profile.surfaceStyle == SurfaceStyle.glass
        ? '$mode · Liquid Glass ${profile.glassIntensity}%'
        : '$mode · Standard';
  }

  static String _notificationSummary(LearningProfile profile) {
    final enabled = [
      profile.lessonRemindersEnabled,
      profile.reviewRemindersEnabled,
      profile.streakRemindersEnabled,
    ].where((value) => value).length;
    return enabled == 0
        ? 'Off'
        : '$enabled reminder${enabled == 1 ? '' : 's'} on';
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _resetLearningProgress(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showSprichstConfirmation(
      context,
      title: 'Reset learning progress?',
      message:
          'This removes completed lessons, scheduled reviews, XP, and your streak. Your account and settings will remain.',
      confirmLabel: 'Reset progress',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(appControllerProvider).resetLearningProgress();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Learning progress reset.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reset learning progress.')),
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showSprichstConfirmation(
      context,
      title: 'Delete your account?',
      message:
          'You will reauthenticate with Google, then Sprichst will delete the learning data stored for this account and the Firebase account itself. This cannot be undone.',
      confirmLabel: 'Delete account',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    // Capture before awaiting: clearing learning data swaps this screen out, so
    // `context` may be gone by the time a step fails.
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator()),
            SizedBox(width: AppSpacing.md),
            Expanded(child: Text('Deleting your account securely…')),
          ],
        ),
      ),
    );

    try {
      final auth = ref.read(authViewModelProvider.notifier);
      await auth.reauthenticateWithGoogle();
      await ref.read(appControllerProvider).deleteLearningData();
      await auth.deleteCurrentUser();
      // On success the auth state change ends the session, which removes this
      // dialog along with every other pushed route.
    } catch (error) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is AuthCancelledException
                ? 'Account deletion cancelled. Nothing was deleted.'
                : 'We could not finish deleting the account. Please sign in again and retry.',
          ),
        ),
      );
    }
  }
}

enum _FeedbackType {
  bug('Report a problem', Icons.bug_report_outlined),
  feature('Request a feature', Icons.lightbulb_outline),
  general('General feedback', Icons.chat_bubble_outline);

  const _FeedbackType(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Feedback delivery is not configured, so this builds a complete report and
/// copies it to the clipboard instead of pretending to send it.
class _ContactPage extends ConsumerStatefulWidget {
  const _ContactPage();

  @override
  ConsumerState<_ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends ConsumerState<_ContactPage> {
  final _message = TextEditingController();
  var _type = _FeedbackType.bug;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsPage(
        title: 'Contact developer',
        subtitle:
            'Describe what happened or what you would like. Sprichst prepares a report you can send to the developer.',
        children: [
          SettingsSection(
            title: 'What is this about?',
            children: [
              for (final type in _FeedbackType.values)
                RadioListTile<_FeedbackType>(
                  value: type,
                  groupValue: _type,
                  secondary: Icon(type.icon),
                  title: Text(type.label),
                  onChanged: (value) => setState(() => _type = value!),
                ),
            ],
          ),
          TextField(
            controller: _message,
            minLines: 4,
            maxLines: 8,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Your message'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _message.text.trim().isEmpty ? null : _copy,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy report'),
            ),
          ),
        ],
      );

  Future<void> _copy() async {
    final profile = ref.read(appControllerProvider).profile;
    final report = [
      '[${_type.label}] ${AppInfo.name} ${AppInfo.version}',
      'Platform: ${Theme.of(context).platform.name}',
      if (profile != null) 'Level: ${profile.currentLevel.label}',
      '',
      _message.text.trim(),
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Report copied. Paste it into an email or message to the developer.')),
    );
  }
}

class _ProfilePage extends ConsumerStatefulWidget {
  const _ProfilePage();

  @override
  ConsumerState<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<_ProfilePage> {
  late final TextEditingController _name;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: ref.read(appControllerProvider).profile!.name,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(appControllerProvider).profile!;
    final email = ref.watch(authViewModelProvider).valueOrNull?.email;
    return SettingsPage(
      title: 'Profile',
      subtitle: 'The details Sprichst uses to personalise your learning space.',
      children: [
        SettingsSection(
          title: 'Profile information',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            ),
            SettingsTile(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: email ?? 'Not available',
            ),
            SettingsTile(
              icon: Icons.school_outlined,
              title: 'Current level',
              subtitle: profile.currentLevel.label,
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save profile'),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final current = ref.read(appControllerProvider).profile!;
      await ref.read(appControllerProvider).updateProfile(
            current.copyWith(name: name),
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _LearningPreferencesPage extends ConsumerWidget {
  const _LearningPreferencesPage();

  static const _languages = ['English', 'Hindi', 'Telugu', 'Other'];
  static const _topics = [
    'Everyday life',
    'Travel',
    'Work',
    'Culture',
    'Family',
    'Food',
    'Study',
    'Health',
  ];
  static const _skills = [
    'Vocabulary',
    'Grammar',
    'Speaking',
    'Listening',
    'Writing',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appControllerProvider).profile!;
    return SettingsPage(
      title: 'Learning preferences',
      subtitle: 'These choices guide lessons and the tutor’s explanations.',
      children: [
        SettingsSection(
          title: 'Learning plan',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: DropdownButtonFormField<CefrLevel>(
                value: profile.currentLevel,
                decoration:
                    const InputDecoration(labelText: 'Current German level'),
                items: [
                  for (final level in CefrLevel.values)
                    DropdownMenuItem(value: level, child: Text(level.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _save(ref, profile.copyWith(currentLevel: value));
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: DropdownButtonFormField<CefrLevel>(
                value: profile.targetLevel,
                decoration: const InputDecoration(labelText: 'Learning goal'),
                items: [
                  for (final level in CefrLevel.values)
                    DropdownMenuItem(value: level, child: Text(level.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _save(ref, profile.copyWith(targetLevel: value));
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: DropdownButtonFormField<String>(
                value: _languages.contains(profile.nativeLanguage)
                    ? profile.nativeLanguage
                    : 'Other',
                decoration:
                    const InputDecoration(labelText: 'Explanation language'),
                items: [
                  for (final language in _languages)
                    DropdownMenuItem(value: language, child: Text(language)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _save(ref, profile.copyWith(nativeLanguage: value));
                  }
                },
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'My goal',
          description:
              'Your lessons, vocabulary, games and mock exams follow this goal.',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: GoalPicker(
                selected: profile.goal,
                onSelect: (goal) => _save(ref, profile.copyWith(goal: goal)),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Daily target',
          description:
              'Choose a realistic study target. It is used for planning, not a streak penalty.',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [5, 10, 15, 20, 30]
                    .map(
                      (minutes) => ChoiceChip(
                        label: Text('$minutes min'),
                        selected: profile.dailyGoalMinutes == minutes,
                        onSelected: (_) => _save(
                          ref,
                          profile.copyWith(dailyGoalMinutes: minutes),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Preferred topics',
          description:
              'The tutor can use these topics for examples and conversation prompts.',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: _topics
                    .map(
                      (topic) => FilterChip(
                        label: Text(topic),
                        selected: profile.preferredTopics.contains(topic),
                        onSelected: (selected) => _save(
                          ref,
                          profile.copyWith(
                            preferredTopics: _toggle(
                              profile.preferredTopics,
                              topic,
                              selected,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        SettingsSection(
          title: 'Practice focus',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: _skills
                    .map(
                      (skill) => FilterChip(
                        label: Text(skill),
                        selected: profile.focusSkills.contains(skill),
                        onSelected: (selected) => _save(
                          ref,
                          profile.copyWith(
                            focusSkills:
                                _toggle(profile.focusSkills, skill, selected),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<String> _toggle(List<String> current, String item, bool add) {
    final next = [...current];
    if (add) {
      next.add(item);
    } else {
      next.remove(item);
    }
    return next;
  }

  Future<void> _save(WidgetRef ref, LearningProfile updated) {
    return ref.read(appControllerProvider).updateProfile(updated);
  }
}

class _AIAndVoicePage extends ConsumerStatefulWidget {
  const _AIAndVoicePage();

  @override
  ConsumerState<_AIAndVoicePage> createState() => _AIAndVoicePageState();
}

class _AIAndVoicePageState extends ConsumerState<_AIAndVoicePage> {
  late double _speechRate;

  @override
  void initState() {
    super.initState();
    _speechRate =
        ref.read(appControllerProvider).profile!.speechRate.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(appControllerProvider).profile!;
    return SettingsPage(
      title: 'AI & voice',
      subtitle:
          'The app sends requests to the Sprichst gateway, never directly to a model provider. Provider and voice choices are saved for the account; live gateway routing stays server-controlled.',
      children: [
        SettingsSection(
          title: 'Tutor provider',
          description:
              'Automatic is the recommended saved preference. The current gateway configuration controls live routing and fallback.',
          children: [
            for (final provider in AIProviderPreference.values)
              RadioListTile<AIProviderPreference>(
                value: provider,
                groupValue: profile.aiProviderPreference,
                title: Text(provider.label),
                subtitle: Text(provider.description),
                onChanged: (value) {
                  if (value != null) {
                    _save(profile.copyWith(aiProviderPreference: value));
                  }
                },
              ),
          ],
        ),
        SettingsSection(
          title: 'Voice',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: DropdownButtonFormField<String>(
                value: profile.voice,
                decoration: const InputDecoration(labelText: 'Tutor voice'),
                items: const [
                  DropdownMenuItem(value: 'Anna', child: Text('Anna'))
                ],
                onChanged: (value) {
                  if (value != null) _save(profile.copyWith(voice: value));
                },
              ),
            ),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              title: const Text('Speech speed'),
              subtitle: Text('${_speechRate.round()} words per minute'),
            ),
            Slider(
              value: _speechRate,
              min: 150,
              max: 300,
              divisions: 15,
              label: '${_speechRate.round()} wpm',
              onChanged: (value) => setState(() => _speechRate = value),
              onChangeEnd: (value) => _save(
                profile.copyWith(speechRate: value.round()),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
        SettingsSection(
          title: 'Advanced',
          description:
              'Model selection is constrained by the gateway configuration, so credentials and provider access remain private.',
          children: [
            SwitchListTile.adaptive(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              title: const Text('Show advanced controls'),
              subtitle: const Text(
                  'Show the gateway-selected model and technical context.'),
              value: profile.advancedAiControls,
              onChanged: (value) => _save(
                profile.copyWith(advancedAiControls: value),
              ),
            ),
            if (profile.advancedAiControls)
              SettingsTile(
                icon: Icons.memory_outlined,
                title: 'Configured model',
                subtitle:
                    '${profile.aiModel} · managed by the Sprichst AI gateway',
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _save(LearningProfile updated) {
    return ref.read(appControllerProvider).updateProfile(updated);
  }
}

class _NotificationsPage extends ConsumerWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appControllerProvider).profile!;
    return SettingsPage(
      title: 'Notifications',
      subtitle:
          'Choose which reminders Sprichst may schedule when notification delivery is enabled.',
      children: [
        SoftCard(
          color: context.softSurface,
          child: const Text(
            'Reminders are saved now, but this local build does not yet schedule operating-system notifications. Your choices will be used when delivery is added.',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SettingsSection(
          title: 'Reminder preferences',
          children: [
            SwitchListTile.adaptive(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              title: const Text('Daily lesson reminder'),
              subtitle: const Text('A nudge to begin your planned study time.'),
              value: profile.lessonRemindersEnabled,
              onChanged: (value) => _save(
                ref,
                profile.copyWith(lessonRemindersEnabled: value),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              title: const Text('Review reminder'),
              subtitle:
                  const Text('A nudge when a scheduled review becomes due.'),
              value: profile.reviewRemindersEnabled,
              onChanged: (value) => _save(
                ref,
                profile.copyWith(reviewRemindersEnabled: value),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              title: const Text('Streak reminder'),
              subtitle: const Text(
                  'A gentle reminder before a learning streak ends.'),
              value: profile.streakRemindersEnabled,
              onChanged: (value) => _save(
                ref,
                profile.copyWith(streakRemindersEnabled: value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _save(WidgetRef ref, LearningProfile updated) {
    return ref.read(appControllerProvider).updateProfile(updated);
  }
}

class _PrivacyAndDataPage extends ConsumerWidget {
  const _PrivacyAndDataPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsPage(
        title: 'Privacy & data',
        subtitle: 'A clear summary of the current local-first architecture.',
        children: [
          const SettingsSection(
            title: 'What is stored',
            children: [
              SettingsTile(
                icon: Icons.cloud_outlined,
                title: 'Learning profile',
                subtitle:
                    'Your level, completed lessons, review queue, scores, and saved preferences are stored in your private Firestore path.',
              ),
              SettingsTile(
                icon: Icons.phone_android_outlined,
                title: 'On this device',
                subtitle:
                    'The app can cache learning information locally to keep the learning experience responsive.',
              ),
            ],
          ),
          const SettingsSection(
            title: 'AI and speech',
            children: [
              SettingsTile(
                icon: Icons.psychology_outlined,
                title: 'Cloud AI',
                subtitle:
                    'When the gateway is configured to use Groq, your tutor message and the existing compact learning context are sent through Sprichst to that provider.',
              ),
              SettingsTile(
                icon: Icons.mic_none_outlined,
                title: 'Speech recognition',
                subtitle:
                    'Voice recordings are sent to the Sprichst gateway for local Whisper transcription in the current setup.',
              ),
              SettingsTile(
                icon: Icons.volume_up_outlined,
                title: 'Speech playback',
                subtitle:
                    'Tutor speech is synthesized by the local gateway. Voice and speed preferences are saved for future gateway support.',
              ),
            ],
          ),
          SettingsSection(
            title: 'Your data',
            children: [
              SettingsTile(
                icon: Icons.download_outlined,
                title: 'Export my data',
                subtitle:
                    'Copy everything stored in your learning profile as JSON.',
                onTap: () => _export(context, ref),
              ),
            ],
          ),
          SoftCard(
            color: context.dangerSurface,
            child: Text(
              'You can reset only learning progress or delete the account from Account → Danger zone. Account deletion removes the current learning documents before removing the Firebase account.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        ],
      );

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(appControllerProvider).profile;
    if (profile == null) return;
    final json = const JsonEncoder.withIndent('  ').convert(
      ProfileCodec.encode(profile,
          encodeDate: (date) => date.toIso8601String()),
    );
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your data was copied as JSON.')),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) => SettingsPage(
        title: 'About Sprichst',
        subtitle: 'A curriculum-led, AI-powered German learning workspace.',
        children: [
          SoftCard(
            color: context.softSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SPRICHST',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                const Text('Version ${AppInfo.version}'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SettingsSection(
            title: 'Built with',
            children: [
              SettingsTile(icon: Icons.flutter_dash, title: 'Flutter'),
              SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Firebase Authentication & Firestore'),
              SettingsTile(
                  icon: Icons.smart_toy_outlined,
                  title: 'Groq, Qwen & Ollama gateway'),
              SettingsTile(
                  icon: Icons.mic_none_outlined,
                  title: 'Whisper.cpp & local text-to-speech'),
            ],
          ),
          SettingsSection(
            title: 'Open-source licenses',
            children: [
              SettingsTile(
                icon: Icons.article_outlined,
                title: 'View licenses',
                subtitle: 'Flutter and package acknowledgements.',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Sprichst',
                  applicationVersion: AppInfo.version,
                ),
              ),
            ],
          ),
        ],
      );
}
