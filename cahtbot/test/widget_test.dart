import 'package:cahtbot/chatbot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChatBot screen loads correctly', (WidgetTester tester) async {
    // Build ChatBotScreen instead of MyApp
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatBotScreen(),
      ),
    );

    // ✅ Verify app bar title is present
    expect(find.text('ChatBot'), findsOneWidget);

    // ✅ Verify the text field for messages exists
    expect(find.byType(TextField), findsOneWidget);
  });
}
