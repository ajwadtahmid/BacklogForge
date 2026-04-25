import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backlogforge/widgets/stat_card.dart';

void main() {
  group('StatCard', () {
    testWidgets('renders label, value, and icon', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Games in Backlog',
            value: '42',
            icon: Icons.inbox,
          ),
        ),
      ));
      expect(find.text('Games in Backlog'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });
  });

  group('CompletionGradeCard', () {
    Widget wrap(Widget child) => MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 200, height: 200, child: child),
          ),
        );

    testWidgets('grade A renders green', (tester) async {
      await tester.pumpWidget(wrap(
        const CompletionGradeCard(percent: 82.5, grade: 'A'),
      ));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('82.5%'), findsOneWidget);
      expect(find.text('Library Completed'), findsOneWidget);
      final text = tester.widget<Text>(find.text('A'));
      expect(text.style!.color, Colors.green);
    });

    testWidgets('grade B renders teal', (tester) async {
      await tester.pumpWidget(wrap(
        const CompletionGradeCard(percent: 65.0, grade: 'B'),
      ));
      final text = tester.widget<Text>(find.text('B'));
      expect(text.style!.color, Colors.teal);
    });

    testWidgets('grade C renders amber', (tester) async {
      await tester.pumpWidget(wrap(
        const CompletionGradeCard(percent: 40.0, grade: 'C'),
      ));
      final text = tester.widget<Text>(find.text('C'));
      expect(text.style!.color, Colors.amber);
    });

    testWidgets('grade D renders red', (tester) async {
      await tester.pumpWidget(wrap(
        const CompletionGradeCard(percent: 12.0, grade: 'D'),
      ));
      final text = tester.widget<Text>(find.text('D'));
      expect(text.style!.color, Colors.red);
    });
  });
}
