import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/trip_plan.dart';

Future<void> openPlanLink(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return;
  }
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }
}

Future<void> navigateToPlace(BuildContext context, PlanPlace place) =>
    openPlanLink(
        context,
        Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': place.hasCoordinates
              ? '${place.lat},${place.lng}'
              : (place.address.isEmpty
                  ? place.title
                  : '${place.title} ${place.address}')
        }).toString());

class PlanMap extends StatelessWidget {
  final TripPlan plan;
  final TileProvider? tileProvider;
  final String? day;
  final ValueChanged<PlanPlace> onPlace;
  final void Function(double lat, double lng) onAdd;
  const PlanMap(
      {super.key,
      required this.plan,
      this.tileProvider,
      this.day,
      required this.onPlace,
      required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final entries = plan.entries
        .where(
            (e) => (day == null || e.occursOn(day!)) && e.status != 'cancelled')
        .toList();
    final placeIds = entries.map((e) => e.placeId).toSet();
    final places = plan.places
        .where(
            (p) => p.hasCoordinates && (day == null || placeIds.contains(p.id)))
        .toList();
    final points = places.map((p) => LatLng(p.lat!, p.lng!)).toList();
    final missing = plan.places
        .where((p) =>
            !p.hasCoordinates && (day == null || placeIds.contains(p.id)))
        .length;
    final signature =
        '${day ?? 'all'}:${points.map((p) => '${p.latitude},${p.longitude}').join(';')}';
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
              '${day == null ? 'All saved places' : 'Places on $day'} · ${points.length} pins${missing > 0 ? ' · $missing without coordinates' : ''}\nLong-press the map to save a place.',
              style: Theme.of(context).textTheme.bodySmall)),
      Expanded(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: FlutterMap(
                    key: ValueKey(signature),
                    options: MapOptions(
                        initialCenter:
                            points.isEmpty ? const LatLng(20, 0) : points.first,
                        initialZoom: points.isEmpty ? 2 : 13,
                        maxZoom: 19,
                        initialCameraFit: points.length > 1
                            ? CameraFit.bounds(
                                bounds: LatLngBounds.fromPoints(points),
                                padding: const EdgeInsets.all(50),
                                maxZoom: 15)
                            : null,
                        onLongPress: (_, point) =>
                            onAdd(point.latitude, point.longitude)),
                    children: [
                      TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.steaunk.numi_app',
                          tileProvider: tileProvider,
                          maxNativeZoom: 19),
                      MarkerLayer(
                          markers: places
                              .map((p) => Marker(
                                  point: LatLng(p.lat!, p.lng!),
                                  width: 48,
                                  height: 48,
                                  child: IconButton(
                                      tooltip: p.title,
                                      icon: Icon(Icons.location_on,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 36),
                                      onPressed: () => onPlace(p))))
                              .toList()),
                      RichAttributionWidget(attributions: [
                        TextSourceAttribution('OpenStreetMap contributors',
                            onTap: () => openPlanLink(context,
                                'https://www.openstreetmap.org/copyright'))
                      ]),
                    ],
                  )))),
      const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
              'Map tiles need a connection. Saved places and itinerary remain available offline.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12))),
    ]);
  }
}
