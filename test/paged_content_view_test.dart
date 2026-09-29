import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worldstories_mobile/features/reader/presentation/paged_content_view.dart';

void main() {
  testWidgets('splits long text into pages and reports progress', (
    tester,
  ) async {
    final key = GlobalKey<PagedContentViewState>();
    final progress = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            height: 600,
            child: PagedContentView(
              key: key,
              padding: const EdgeInsets.all(20),
              onProgress: progress.add,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 40; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Paragraph $i. ${'Lorem ipsum dolor sit amet. ' * 6}',
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = key.currentState!;
    expect(state.pageCount, greaterThan(3));
    expect(progress.last, 0);

    state.nextPage();
    await tester.pumpAndSettle();
    expect(state.currentPage, 1);
    expect(progress.last, closeTo(1 / (state.pageCount - 1), 1e-9));

    state.jumpToFraction(1);
    await tester.pumpAndSettle();
    expect(state.currentPage, state.pageCount - 1);
    expect(progress.last, 1);
  });

  testWidgets('keeps a short text on a single page', (tester) async {
    final key = GlobalKey<PagedContentViewState>();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 600,
          child: PagedContentView(
            key: key,
            padding: EdgeInsets.zero,
            onProgress: (_) {},
            child: const Text('Just one line.'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(key.currentState!.pageCount, 1);
  });
}
