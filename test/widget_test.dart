import 'package:flutter_test/flutter_test.dart';

import 'package:echomesh/app/echomesh_app.dart';

void main() {
  testWidgets('EchoMesh boot smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EchoMeshApp());

    // Let initial async init/splash settle for at least one frame.
    await tester.pump();

    // Smoke test: app should build without throwing.
    expect(find.byType(EchoMeshApp), findsOneWidget);
  });
}
