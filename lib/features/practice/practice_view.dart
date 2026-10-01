import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/review_scheduler.dart';
import '../../domain/models/learning_models.dart';
import '../../shared/widgets/app_widgets.dart';

class PracticeView extends ConsumerWidget {
  const PracticeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final due = app.profile!.reviewItems.where((item) => item.isDue).toList();
    return PageFrame(
      title: 'Practice',
      subtitle: 'The next useful practice is based on your learning state.',
      child: ListView(children: [
        SoftCard(
          color: SprichstTheme.sand,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('RECOMMENDED',
                style: TextStyle(
                    color: SprichstTheme.forest,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1)),
            const SizedBox(height: 8),
            Text(due.isEmpty ? 'You are caught up.' : 'Fix your weakest areas',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(due.isEmpty
                ? 'Complete your next lesson to schedule fresh recall practice.'
                : '${due.length} items are ready for a quick recall session.'),
          ]),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Review queue'),
        const SizedBox(height: 12),
        if (due.isEmpty)
          const SoftCard(
              child: Text('Nothing is due right now. Great consistency!'))
        else
          for (final item in due)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SoftCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(item.kind),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _RateButton('Again', ReviewRating.again, item),
                        _RateButton('Hard', ReviewRating.hard, item),
                        _RateButton('Good', ReviewRating.good, item),
                        _RateButton('Easy', ReviewRating.easy, item),
                      ]),
                    ]),
              ),
            ),
        const SizedBox(height: 24),
        const SectionTitle('Choose a skill'),
        const SizedBox(height: 12),
        Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              'Vocabulary',
              'Articles',
              'Grammar',
              'Cases',
              'Listening',
              'Writing',
              'Speaking'
            ]
                .map((label) => OutlinedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '$label practice will be added with the next curriculum pack.'))),
                    icon: const Icon(Icons.bolt, size: 18),
                    label: Text(label)))
                .toList()),
      ]),
    );
  }
}

class _RateButton extends ConsumerWidget {
  const _RateButton(this.label, this.rating, this.item);
  final String label;
  final ReviewRating rating;
  final ReviewItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton(
        onPressed: () async {
          await ref.read(appControllerProvider).rateReview(item, rating);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Scheduled ${item.label} again.')));
          }
        },
        child: Text(label),
      );
}
