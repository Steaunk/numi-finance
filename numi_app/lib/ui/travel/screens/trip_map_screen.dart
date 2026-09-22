import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';
import '../../../models/trip_map.dart';
import '../../../providers/providers.dart';
import '../widgets/plan_links.dart';

class TripMapScreen extends ConsumerStatefulWidget {
  final Trip trip;
  final TileProvider? tileProvider;
  final String day, destination, person;
  const TripMapScreen(
      {super.key,
      required this.trip,
      this.tileProvider,
      this.day = '',
      this.destination = '',
      this.person = ''});
  @override
  ConsumerState<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends ConsumerState<TripMapScreen> {
  final controller = MapController();
  late String day = widget.day,
      destination = widget.destination,
      person = widget.person;
  bool savedPlaces = true, busy = false, tileError = false;
  String? selected;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void fit(List<TripMapStop> stops) {
    final points = stops.map((s) => s.point).whereType<LatLng>().toList();
    if (points.isEmpty) return;
    controller.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
        maxZoom: 15));
  }

  Future<void> locate(TripMapStop stop) async {
    var input = stop.googleLink ?? '';
    final link = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Locate ${stop.title}'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'Paste the Google Maps share link for this exact place.'),
                const SizedBox(height: 12),
                TextFormField(
                    initialValue: input,
                    onChanged: (value) => input = value,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Google Maps link')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, input.trim()),
                    child: const Text('Locate'))
              ],
            ));
    if (link == null || !mounted) return;
    final urls = extractPlanLinks(link);
    if (urls.length != 1 || linkPlatform(urls.single) != 'Google Maps') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paste one Google Maps place link.')));
      return;
    }
    setState(() => busy = true);
    try {
      final url = urls.single;
      LatLng? point = googleMapPoint(url);
      if (point == null) {
        final result = await ref.read(travelApiProvider)!.previewShare('', url);
        point = mapPoint(result['latitude'] as String? ?? '',
            result['longitude'] as String? ?? '');
      }
      if (point == null) {
        throw StateError(
            'No exact pin found. Share the place itself, not the map view.');
      }
      // Read again after the network call so unrelated edits are preserved.
      final plan = await ref.read(tripPlanProvider(widget.trip.id).future);
      final current = plan.find(stop.location.id);
      if (current == null) throw StateError('This place was removed.');
      final links = current.links.toList();
      if (!links.any((l) => l.url == url) && links.length < 50) {
        links.add(PlanLink(
            url: url,
            purpose: 'Map',
            label: stop.arrival ? 'Arrival map' : 'Google Maps'));
      }
      await ref.read(tripPlanRepositoryProvider).save(
          widget.trip.id,
          current.copy({
            stop.latitudeField: '${point.latitude}',
            stop.longitudeField: '${point.longitude}'
          }, links: links));
      if (mounted) setState(() => selected = stop.key);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Could not locate this place. ${e is StateError ? e.message : 'Check your connection and try again.'}')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tripPlanProvider(widget.trip.id));
    return Scaffold(
        appBar: AppBar(title: const Text('Trip map')),
        body: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Center(child: Text('Could not load places')),
            data: (plan) {
              final validDestination = plan.destinations
                          .any((d) => d.id == destination) ||
                      ['__unassigned__', '__transfers__'].contains(destination)
                  ? destination
                  : '';
              final validPerson =
                  plan.people.any((p) => p.id == person) ? person : '';
              final stops = tripMapStops(plan,
                  day: day,
                  destination: validDestination,
                  person: validPerson,
                  savedPlaces: savedPlaces);
              final pins = stops.where((s) => s.point != null).toList();
              final active = pins.where((s) => s.key == selected).firstOrNull;
              final days = {
                ...tripDays(widget.trip.startDate, widget.trip.endDate)
                    .map(planDate),
                ...plan.items
                    .where((i) => ['booking', 'activity'].contains(i.kind))
                    .expand((i) => [i['date'], i['endDate']])
                    .where((d) => d.isNotEmpty)
              }.toList()
                ..sort();
              Widget select(
                      String label,
                      String value,
                      List<DropdownMenuItem<String>> options,
                      ValueChanged<String> change) =>
                  SizedBox(
                      width: 165,
                      child: DropdownButtonFormField<String>(
                          key: ValueKey('$label-$value'),
                          initialValue: value,
                          isExpanded: true,
                          decoration:
                              InputDecoration(labelText: label, isDense: true),
                          items: options,
                          onChanged: (v) => setState(() {
                                change(v!);
                                selected = null;
                              })));
              final points = pins.map((s) => s.point!).toList();
              return Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          select(
                              'Day',
                              days.contains(day) ? day : '',
                              [
                                const DropdownMenuItem(
                                    value: '', child: Text('Whole trip')),
                                ...days.map((d) =>
                                    DropdownMenuItem(value: d, child: Text(d)))
                              ],
                              (v) => day = v),
                          const SizedBox(width: 12),
                          select(
                              'Destination',
                              validDestination,
                              [
                                const DropdownMenuItem(
                                    value: '', child: Text('All destinations')),
                                const DropdownMenuItem(
                                    value: '__unassigned__',
                                    child: Text('Unassigned')),
                                const DropdownMenuItem(
                                    value: '__transfers__',
                                    child: Text('Between destinations')),
                                ...plan.destinations.map((d) =>
                                    DropdownMenuItem(
                                        value: d.id,
                                        child: Text(d.title,
                                            overflow: TextOverflow.ellipsis)))
                              ],
                              (v) => destination = v),
                          const SizedBox(width: 12),
                          select(
                              'People',
                              validPerson,
                              [
                                const DropdownMenuItem(
                                    value: '', child: Text('Everyone')),
                                ...plan.people.map((p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(p.title,
                                        overflow: TextOverflow.ellipsis)))
                              ],
                              (v) => person = v),
                        ]))),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      FilterChip(
                          label: const Text('Saved places'),
                          selected: savedPlaces,
                          onSelected: (v) => setState(() => savedPlaces = v)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              '${pins.length} mapped · ${stops.length - pins.length} to locate',
                              style: Theme.of(context).textTheme.bodySmall)),
                      if (pins.isNotEmpty)
                        IconButton(
                            tooltip: 'Fit all places',
                            onPressed: () => fit(stops),
                            icon: const Icon(Icons.fit_screen)),
                    ])),
                if (busy) const LinearProgressIndicator(),
                Expanded(
                    flex: 3,
                    child: pins.isEmpty
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                    'No mapped places in this view. Use Locate below or import a Google Maps place link.',
                                    textAlign: TextAlign.center)))
                        : FlutterMap(
                            key: ValueKey(pins
                                .map((s) => '${s.key}:${s.point}')
                                .join('|')),
                            mapController: controller,
                            options: MapOptions(
                                initialCenter: points.first,
                                initialZoom: 13,
                                maxZoom: 19,
                                initialCameraFit: CameraFit.bounds(
                                    bounds: LatLngBounds.fromPoints(points),
                                    padding: const EdgeInsets.all(48),
                                    maxZoom: 15),
                                interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.all &
                                        ~InteractiveFlag.rotate)),
                            children: [
                                TileLayer(
                                    tileProvider: widget.tileProvider,
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.steaunk.numi_app',
                                    maxZoom: 19,
                                    panBuffer: 1,
                                    errorTileCallback: (tile, error, stack) {
                                      if (!tileError && mounted) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (mounted) {
                                            setState(() => tileError = true);
                                          }
                                        });
                                      }
                                    }),
                                MarkerLayer(
                                    markers: pins
                                        .asMap()
                                        .entries
                                        .map((e) => Marker(
                                            point: e.value.point!,
                                            width: 40,
                                            height: 40,
                                            child: Semantics(
                                                label:
                                                    'Map pin ${e.key + 1}: ${e.value.title}',
                                                button: true,
                                                child: GestureDetector(
                                                    onTap: () => setState(() =>
                                                        selected = e.value.key),
                                                    child: Container(
                                                        alignment:
                                                            Alignment.center,
                                                        decoration:
                                                            BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                color: e.value.key ==
                                                                        selected
                                                                    ? Colors.orange.shade800
                                                                    : e.value.saved
                                                                        ? Colors.blueGrey
                                                                        : e.value.item.isStay
                                                                            ? Colors.indigo
                                                                            : Colors.teal.shade700,
                                                                border: Border.all(color: Colors.white, width: 3),
                                                                boxShadow: const [
                                                              BoxShadow(
                                                                  blurRadius: 4,
                                                                  color: Colors
                                                                      .black26)
                                                            ]),
                                                        child: Text(
                                                            '${e.key + 1}',
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)))))))
                                        .toList()),
                                Align(
                                    alignment: Alignment.bottomRight,
                                    child: Material(
                                        color: Colors.white,
                                        child: InkWell(
                                            onTap: () => openPlanLink(context,
                                                'https://www.openstreetmap.org/copyright'),
                                            child: const Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Text(
                                                    '© OpenStreetMap contributors',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .black87)))))),
                              ])),
                Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text(
                        tileError
                            ? 'Map tiles unavailable. Place details and distances still work.'
                            : active == null
                                ? 'Tap a pin to compare distances. Distances are straight-line, not travel times.'
                                : 'Distances from ${active.title} · straight-line',
                        style: Theme.of(context).textTheme.bodySmall)),
                Expanded(
                    flex: 2,
                    child: ListView(
                        children: stops.map((stop) {
                      final index = pins.indexOf(stop);
                      final distance = active?.point != null &&
                              stop.point != null &&
                              active!.key != stop.key
                          ? mapDistanceKm(active.point!, stop.point!)
                          : null;
                      return ListTile(
                          selected: stop.key == selected,
                          leading: CircleAvatar(
                              child: Text(index < 0 ? '?' : '${index + 1}')),
                          title: Text(stop.title),
                          subtitle: Text([
                            if (stop.day.isNotEmpty) '${stop.day} ${stop.time}',
                            if (stop.saved) 'Saved place',
                            if (!stop.saved) plan.participantsLabel(stop.item),
                            if (distance != null)
                              '${distance.toStringAsFixed(1)} km away',
                            if (stop.point == null) 'Location not set'
                          ].join(' · ')),
                          onTap: stop.point == null
                              ? (busy ? null : () => locate(stop))
                              : () {
                                  setState(() => selected = stop.key);
                                  controller.move(stop.point!, 15);
                                },
                          trailing: stop.point == null
                              ? TextButton(
                                  onPressed: busy ? null : () => locate(stop),
                                  child: const Text('Locate'))
                              : PopupMenuButton<String>(
                                  tooltip: 'Map actions',
                                  onSelected: (v) {
                                    if (v == 'locate') {
                                      locate(stop);
                                    } else if (v == 'route' &&
                                        active?.point != null) {
                                      openPlanLink(
                                          context,
                                          mapDirections(
                                                  active!.point!, stop.point!)
                                              .toString());
                                    } else {
                                      openPlanLink(
                                          context,
                                          stop.googleLink ??
                                              mapSearchLink('',
                                                      '${stop.point!.latitude},${stop.point!.longitude}')
                                                  .toString());
                                    }
                                  },
                                  itemBuilder: (_) => [
                                        const PopupMenuItem(
                                            value: 'open',
                                            child: Text('Open in Google Maps')),
                                        if (distance != null)
                                          const PopupMenuItem(
                                              value: 'route',
                                              child: Text(
                                                  'Directions from selected place')),
                                        const PopupMenuItem(
                                            value: 'locate',
                                            child: Text('Change map pin')),
                                      ]));
                    }).toList())),
              ]);
            }));
  }
}
