import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayto/app.dart';

void main() {
  testWidgets('KaytoApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KaytoApp()));
    expect(find.text('Kayto'), findsWidgets);
  });
}
