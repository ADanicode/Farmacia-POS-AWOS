import 'package:flutter_test/flutter_test.dart';
import 'package:farmacia_pos_awos/main.dart';
import 'package:farmacia_pos_awos/core/di/injection_container.dart' as di;

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await di.init();
    await tester.pumpWidget(const MyApp());
    expect(find.text('FARMACIA AWOS'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ingresar con Google'), findsOneWidget);
  });
}
