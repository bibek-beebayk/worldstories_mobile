import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worldstories_mobile/features/reader/presentation/reader_shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget shell({required VoidCallback onNext}) => ProviderScope(
    child: MaterialApp(
      home: ReaderShell(
        controller: ReaderShellController(),
        sectionKey: 'chapter-1',
        title: 'Story',
        subtitle: 'Chapter 1',
        bottomLabel: 'Chapter 1',
        overallProgress: (fraction) => fraction,
        blocks: [
          for (var i = 0; i < 60; i++)
            SizedBox(height: 40, child: Text('Block $i')),
        ],
        onNext: onNext,
      ),
    ),
  );

  testWidgets('builds a long section a chunk per frame', (tester) async {
    await tester.pumpWidget(shell(onNext: () {}));
    // The first screenful is there straight away...
    expect(find.text('Block 0', skipOffstage: false), findsOneWidget);
    expect(find.text('Block 59', skipOffstage: false), findsNothing);
    // ...and the rest follows over the next frames.
    await tester.pumpAndSettle();
    expect(find.text('Block 59', skipOffstage: false), findsOneWidget);
  });

  testWidgets('pulling past the end opens the next section with feedback', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(shell(onNext: () => opened++));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -4000),
    );
    await tester.pump();

    expect(opened, 1);
    expect(find.text(ReaderShell.nextLabel), findsOneWidget);
  });
}
