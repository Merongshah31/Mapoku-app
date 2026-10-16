import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapoku/widgets/mapoku_logo.dart';

void main() {
  testWidgets('renders the mapOKU wordmark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: MapokuLogo()))),
    );

    expect(find.text('mapOKU'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}