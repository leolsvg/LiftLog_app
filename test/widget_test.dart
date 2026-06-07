import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import '../lib/screens/kcal_tab.dart';

void main() {
  testWidgets('le bouton en haut à droite ouvre le profil nutrition', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: KcalTab()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Modifier le profil'), findsOneWidget);

    await tester.tap(find.byTooltip('Modifier le profil'));
    await tester.pumpAndSettle();

    expect(find.text('Profil nutrition'), findsOneWidget);
  });
}
