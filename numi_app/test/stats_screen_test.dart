import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numi_app/providers/providers.dart';
import 'package:numi_app/ui/charts/widgets/stats_screen.dart';
import 'package:numi_app/utils/currency_utils.dart';

Future<void> pumpStats(
  WidgetTester tester,
  Map<String, Map<String, double>> stats,
) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      displayCurrencyProvider.overrideWith((ref) => 'USD'),
      monthlyStatsProvider(null).overrideWith((ref) async => stats),
      netWorthTrendProvider.overrideWith((ref) async => []),
    ],
    child: const MaterialApp(home: StatsScreen()),
  ));
  await tester.pumpAndSettle();
}

List<PieChartSectionData> sections(WidgetTester tester) =>
    tester.widget<PieChart>(find.byType(PieChart)).data.sections;

void main() {
  testWidgets('category filters update every monthly bar and its tooltip',
      (tester) async {
    await pumpStats(tester, {
      '2026-08': {'Rent': 600, 'Food': 200},
      '2026-09': {'Rent': 600, 'Food': 300},
    });
    BarChartData barData() =>
        tester.widget<BarChart>(find.byType(BarChart)).data;
    final foodColor =
        barData().barGroups.first.barRods.single.rodStackItems.first.color;

    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();
    expect(barData().barGroups.map((g) => g.barRods.single.toY), [200, 300]);
    expect(sections(tester).single.title, '100%');
    final filtered = barData();
    for (final group in filtered.barGroups) {
      final rod = group.barRods.single;
      expect(rod.rodStackItems.single.color, foodColor);
      final tooltip = filtered.barTouchData.touchTooltipData.getTooltipItem(
        group,
        group.x,
        rod,
        0,
      );
      final month = group.x == 0 ? '2026-08' : '2026-09';
      final amount = group.x == 0 ? 200.0 : 300.0;
      expect(tooltip?.text, '$month\n${CurrencyUtils.format(amount, 'USD')}');
    }

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(barData().barGroups.map((g) => g.barRods.single.toY), [0, 0]);
    expect(find.text('All categories hidden'), findsOneWidget);

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(barData().barGroups.map((g) => g.barRods.single.toY), [800, 900]);
    expect(sections(tester).length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legend toggles recalculate distribution and preserve colors',
      (tester) async {
    await pumpStats(tester, {
      '2026-09': {'Rent': 600, 'Food': 300, 'Travel': 100},
    });
    final colors = {
      for (final section in sections(tester)) section.value: section.color,
    };
    expect(sections(tester).map((s) => s.title), ['60%', '30%', '10%']);

    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();
    expect(sections(tester).map((s) => s.value), [300, 100]);
    expect(sections(tester).map((s) => s.title), ['75%', '25%']);
    for (final section in sections(tester)) {
      expect(section.color, colors[section.value]);
    }
    expect(tester.widget<Text>(find.text('Rent')).style?.decoration,
        TextDecoration.lineThrough);

    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();
    expect(sections(tester).map((s) => s.title), ['60%', '30%', '10%']);
    expect(find.text('Show all'), findsNothing);
  });

  testWidgets('all categories can be hidden and restored', (tester) async {
    await pumpStats(tester, {
      '2026-09': {'Rent': 600, 'Food': 300},
    });
    for (final category in ['Rent', 'Food']) {
      await tester.tap(find.text(category));
      await tester.pumpAndSettle();
    }
    expect(find.text('All categories hidden'), findsOneWidget);
    expect(find.byType(PieChart), findsNothing);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(sections(tester).single.title, '100%');

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(sections(tester).length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero totals show an empty state with usable category controls',
      (tester) async {
    await pumpStats(tester, {
      '2026-09': {'Food': 0},
    });
    expect(find.text('No expenses in visible categories'), findsOneWidget);
    expect(find.byType(PieChart), findsNothing);
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('All categories hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
