import 'package:flutter_test/flutter_test.dart';
import 'package:pmusic/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PmusicApp()));
    expect(find.byType(PmusicApp), findsOneWidget);
  });
}
