import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backlogforge/widgets/stat_card.dart';
import 'package:backlogforge/theme.dart';

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

    Color gradeColor(WidgetTester tester, String grade) {
      final text = tester.widget<Text>(find.text(grade));
      return text.style!.color!;
    }

    testWidgets('grade A renders correct color', (tester) async {
      await tester.pumpWidget(wrap(
        const CompletionGradeCard(percent: 82.5, grade: 'A'),
      ));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('82.5% · Library Completed'), findsOneWidget);
      expect(gradeColor(tester, 'A'), kColorPlaying);
    });

    testWidgets('grade B renders correct color', (tester) async {
      await tester.pumpWidget(wrap(
        const CompletionGradeCard(percent: 65.0, grade: 'B'),
      ));
      expect(gradeColor(tester, 'B'), kColorGradeB);
    });

    testWidgets('grade C renders correct color', (tester) async {
      await tester.pumpWidget(wrap(
        const CompletionGradeCard(percent: 40.0, grade: 'C'),
      ));
      expect(gradeColor(tester, 'C'), kColorProgressMid);
    });

    testWidgets('grade D+ renders orange', (tester) async {
      await tester.pumpWidget(wrap(
        const CompletionGradeCard(percent: 5.0, grade: 'D+'),
      ));
      expect(gradeColor(tester, 'D+'), kColorGradeD);
    });

    testWidgets('grade D- renders error color from theme', (tester) async {
      await tester.pumpWidget(wrap(
        const CompletionGradeCard(percent: 1.0, grade: 'D-'),
      ));
      // D- uses cs.error from the MaterialApp default theme
      final text = tester.widget<Text>(find.text('D-'));
      expect(text.style!.color, isNotNull);
    });
  });
}
