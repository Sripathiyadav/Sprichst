import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprichst/app/theme/app_theme.dart';
import 'package:sprichst/shared/widgets/app_widgets.dart';

Widget _page({required int items, bool reduceMotion = false}) => MaterialApp(
      theme: SprichstTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
            size: const Size(390, 844), disableAnimations: reduceMotion),
        child: Scaffold(
          body: PageFrame(
            title: 'Settings',
            subtitle: 'A line that explains the page.',
            child: ListView(
              children: [
                for (var i = 0; i < items; i++)
                  SizedBox(height: 80, child: Text('Row $i')),
              ],
            ),
          ),
        ),
      ),
    );

double _titleSize(WidgetTester tester) => tester
    .widget<AnimatedDefaultTextStyle>(find
        .ancestor(
            of: find.text('Settings'),
            matching: find.byType(AnimatedDefaultTextStyle))
        .first)
    .style
    .fontSize!;

void main() {
  group('the page heading folds as the list scrolls', () {
    testWidgets(
        'large at the top, compact once scrolled, large again at the top',
        (tester) async {
      await tester.pumpWidget(_page(items: 30));
      expect(_titleSize(tester), 34);
      expect(find.text('A line that explains the page.'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(_titleSize(tester), 22);
      expect(find.text('A line that explains the page.'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(_titleSize(tester), 34);
      expect(find.text('A line that explains the page.'), findsOneWidget);
    });

    testWidgets('a list that barely overflows keeps its heading',
        (tester) async {
      // Find a list length whose overflow is real but small (under the
      // threshold), whatever the heading's height turns out to be.
      var found = false;
      for (var items = 6; items < 16 && !found; items++) {
        await tester.pumpWidget(_page(items: items));
        final extent = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .maxScrollExtent;
        if (extent < 40 || extent > PageFrame.minScrollForCollapse - 40) {
          continue;
        }
        found = true;
        await tester.drag(find.byType(ListView), Offset(0, -extent));
        await tester.pumpAndSettle();
        expect(_titleSize(tester), 34,
            reason: 'only $extent px to scroll: folding would make it flicker');
      }
      expect(found, isTrue);
    });

    testWidgets('with reduced motion it changes without animating',
        (tester) async {
      await tester.pumpWidget(_page(items: 30, reduceMotion: true));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      await tester.pump(); // the post-frame rebuild, no animation frames
      expect(_titleSize(tester), 22);
    });

    testWidgets('the title is announced as a heading', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_page(items: 3));
      expect(tester.getSemantics(find.text('Settings')),
          matchesSemantics(label: 'Settings', isHeader: true));
      handle.dispose();
    });
  });

  testWidgets('a settings page shows its title once, not in the bar too',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: SprichstTheme.light,
      home: const SettingsPage(title: 'Privacy', children: [Text('body')]),
    ));
    expect(find.text('Privacy'), findsOneWidget);
  });
}
