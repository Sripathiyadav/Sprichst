import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../shared/widgets/app_widgets.dart';
import 'account_view.dart';

/// The learner's avatar in a page header. It opens Account, which on phones
/// has no tab of its own.
class AccountButton extends ConsumerWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(appControllerProvider).profile?.name ?? '';
    return Semantics(
      button: true,
      label: 'Account',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const GlassPage(body: AccountView()))),
        child: ProfileAvatar(name: name),
      ),
    );
  }
}
