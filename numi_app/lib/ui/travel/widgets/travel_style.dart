import 'package:flutter/material.dart';

/// Travel layout refinements that inherit the shared app palette.
class TravelTheme extends StatelessWidget {
  const TravelTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final scheme = base.colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide:
          BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
    );
    return Theme(
      data: base.copyWith(
        appBarTheme: base.appBarTheme.copyWith(
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: base.textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5),
        ),
        textTheme: base.textTheme
            .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
        cardTheme: CardThemeData(
          color: scheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: .35))),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surface,
          border: border,
          enabledBorder: border,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          dividerColor: scheme.outlineVariant.withValues(alpha: .4),
          indicatorSize: TabBarIndicatorSize.label,
        ),
        chipTheme: ChipThemeData(
          side: BorderSide.none,
          backgroundColor: scheme.surface,
          selectedColor: scheme.primaryContainer,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        )),
        floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: scheme.surface,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        ),
        dividerTheme: DividerThemeData(
            color: scheme.outlineVariant.withValues(alpha: .4)),
      ),
      child: child,
    );
  }
}

IconData travelKindIcon(String kind) => switch (kind) {
      'food' => Icons.restaurant_rounded,
      'hotel' => Icons.bed_outlined,
      'flight' => Icons.flight_takeoff_rounded,
      'train' => Icons.train_outlined,
      'transport' => Icons.directions_bus_outlined,
      'note' => Icons.notes_rounded,
      'booking' => Icons.confirmation_number_outlined,
      _ => Icons.explore_outlined,
    };

class TravelKindIcon extends StatelessWidget {
  const TravelKindIcon(this.kind, {super.key});
  final String kind;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14)),
      child: Icon(travelKindIcon(kind), color: color, size: 22),
    );
  }
}

class TravelPageWidth extends StatelessWidget {
  const TravelPageWidth({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160), child: child),
      );
}
