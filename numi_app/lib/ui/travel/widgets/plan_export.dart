import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';
import '../../../utils/trip_export.dart';

Future<void> showPlanExport(BuildContext context, Trip trip, TripPlan plan) =>
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ExportSheet(trip: trip, plan: plan));

class _ExportSheet extends StatefulWidget {
  final Trip trip;
  final TripPlan plan;
  const _ExportSheet({required this.trip, required this.plan});
  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool references = false;
  bool busy = false;
  String get text =>
      tripPlanText(widget.trip, widget.plan, includeReferences: references);
  Future<void> share(bool file) async {
    setState(() => busy = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin =
          box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      if (file) {
        final dir = await getTemporaryDirectory();
        final path = File('${dir.path}/numi-trip-${widget.trip.id}.html');
        await path.writeAsString(tripPlanHtml(widget.trip, widget.plan,
            includeReferences: references));
        await Share.shareXFiles([XFile(path.path, mimeType: 'text/html')],
            subject: '${widget.trip.destination} trip plan',
            sharePositionOrigin: origin);
      } else {
        await Share.share(text,
            subject: '${widget.trip.destination} trip plan',
            sharePositionOrigin: origin);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Sharing is unavailable. You can copy the itinerary instead.')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Share itinerary',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'Preview what you share. Expenses and packing lists are kept private.'),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include confirmation numbers'),
                value: references,
                onChanged: (v) => setState(() => references = v)),
            Expanded(child: SingleChildScrollView(child: SelectableText(text))),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  onPressed: busy ? null : () => share(false),
                  icon: const Icon(Icons.share),
                  label: const Text('Share text')),
              OutlinedButton.icon(
                  onPressed: busy ? null : () => share(true),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Export printable HTML')),
              TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Itinerary copied')));
                    }
                  },
                  child: const Text('Copy')),
            ]),
          ])));
}
