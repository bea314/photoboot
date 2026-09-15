import 'package:flutter_test/flutter_test.dart';
import 'package:fotoboot_operator/main.dart';
import 'package:fotoboot_operator/router/app_router.dart';

void main() {
  testWidgets('app boots on login placeholder', (tester) async {
    await tester.pumpWidget(FotobootOperatorApp(router: createAppRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Fase A — placeholder'), findsOneWidget);
  });
}
