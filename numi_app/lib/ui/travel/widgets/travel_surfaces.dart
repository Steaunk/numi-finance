import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/trip_plan.dart';

Color travelBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF15171E)
        : const Color(0xFFF7F8FC);
Color travelSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF22252E)
        : Colors.white;

String travelDate(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? value : DateFormat('d MMM').format(date);
}

IconData planIcon(PlanItem item) => switch (item['category']) {
      'Cafe' => Icons.local_cafe_outlined,
      'Restaurant' => Icons.restaurant_outlined,
      'Shopping' => Icons.shopping_bag_outlined,
      'Park' => Icons.park_outlined,
      'Accommodation' => Icons.hotel_outlined,
      'Flight' => Icons.flight_outlined,
      'Train' => Icons.train_outlined,
      'Bus' => Icons.directions_bus_outlined,
      'Car rental' => Icons.directions_car_outlined,
      'No accommodation needed' => Icons.nights_stay_outlined,
      'Preparation' || 'Packing' => Icons.checklist_outlined,
      _ => item.kind == 'booking'
          ? Icons.confirmation_number_outlined
          : Icons.place_outlined,
    };

/// Opaque, quiet surfaces shared by trip lists, timelines and modal details.
class TravelTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool tinted;
  const TravelTile(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap,
      this.trailing,
      this.tinted = false});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: tinted
          ? colors.primaryContainer.withValues(alpha: .45)
          : travelSurface(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(children: [
              Icon(icon,
                  size: 22,
                  color: tinted ? colors.primary : colors.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: colors.onSurfaceVariant)),
                    ],
                  ])),
              const SizedBox(width: 8),
              trailing ??
                  Icon(Icons.chevron_right,
                      size: 18, color: colors.onSurfaceVariant),
            ])),
      ),
    );
  }
}

Future<T?> showTravelSheet<T>(BuildContext context,
        {required String title,
        required WidgetBuilder builder,
        Widget? action}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: travelBackground(context),
      constraints: const BoxConstraints(maxWidth: 720),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .86,
        child: SafeArea(
            top: false,
            child: Column(children: [
              Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
                  child: Row(children: [
                    Expanded(
                        child: Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600))),
                    if (action != null) action,
                    IconButton(
                        tooltip: 'Close panel',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close)),
                  ])),
              Expanded(child: builder(sheetContext)),
            ])),
      ),
    );

class TripDayStrip extends StatefulWidget {
  final List<String> days;
  final String selected;
  final int unassigned;
  final ValueChanged<String> onSelected;
  const TripDayStrip(
      {super.key,
      required this.days,
      required this.selected,
      required this.onSelected,
      required this.unassigned});
  @override
  State<TripDayStrip> createState() => _TripDayStripState();
}

class _TripDayStripState extends State<TripDayStrip> {
  late final ScrollController controller;
  @override
  void initState() {
    super.initState();
    controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => reveal());
  }

  @override
  void didUpdateWidget(TripDayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => reveal());
    }
  }

  double get dayWidth => 76 * MediaQuery.textScalerOf(context).scale(14) / 14;

  void reveal() {
    if (!mounted || !controller.hasClients) return;
    final index = widget.selected.isEmpty
        ? widget.days.length
        : widget.days.indexOf(widget.selected);
    final start = index * (dayWidth + 4);
    final position = controller.position;
    if (start < position.pixels ||
        start + dayWidth > position.pixels + position.viewportDimension) {
      controller.jumpTo(start.clamp(0, position.maxScrollExtent));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 30 + MediaQuery.textScalerOf(context).scale(52),
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        itemCount: widget.days.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final value = index == widget.days.length ? '' : widget.days[index];
          final selected = value == widget.selected;
          final colors = Theme.of(context).colorScheme;
          final date = DateTime.tryParse(value);
          return Semantics(
              selected: selected,
              child: SizedBox(
                  width: dayWidth,
                  child: TextButton(
                    key: ValueKey('day-$value'),
                    onPressed: () => widget.onSelected(value),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        backgroundColor:
                            selected ? colors.primary : Colors.transparent,
                        foregroundColor:
                            selected ? colors.onPrimary : colors.onSurface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                              date == null
                                  ? 'Unassigned'
                                  : DateFormat('EEE').format(date),
                              style: const TextStyle(fontSize: 11)),
                          const SizedBox(height: 6),
                          Text(
                              date == null
                                  ? '${widget.unassigned}'
                                  : DateFormat('d MMM').format(date),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ]),
                  )));
        },
      ));
}
