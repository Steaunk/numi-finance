import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/trip_plan.dart';
import '../../../models/travel_share.dart';
import '../../../providers/providers.dart';
import '../widgets/plan_item_editor.dart';

class ImportTravelScreen extends ConsumerStatefulWidget {
  final String sharedText;
  final Map<String, dynamic>? sharedPdf;
  const ImportTravelScreen({super.key, this.sharedText = '', this.sharedPdf});
  @override
  ConsumerState<ImportTravelScreen> createState() => _ImportTravelScreenState();
}

class _ImportTravelScreenState extends ConsumerState<ImportTravelScreen> {
  late final TextEditingController text;
  TravelShareDraft? draft;
  PlanItem? reviewed;
  List<TravelShareDraft> drafts = [];
  int selectedDraft = 0;
  String? selectedUrl;
  int? tripId;
  String kind = 'place';
  bool loading = false, saving = false;
  String? message;
  Uint8List? pdfBytes;
  String? pdfName;

  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: widget.sharedText);
    if (widget.sharedPdf != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => receivePdf());
    } else if (widget.sharedText.trim().isNotEmpty &&
        extractPlanLinks(widget.sharedText).length <= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => analyze());
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> receivePdf() async {
    final share = widget.sharedPdf!;
    if (share['error'] != null) {
      setState(() => message = share['error'] as String);
      return;
    }
    try {
      final file = File(share['path'] as String);
      if (await file.length() > 10 * 1024 * 1024) {
        throw StateError('PDF must be at most 10 MB.');
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      pdfBytes = bytes;
      pdfName = share['name'] as String? ?? 'Ticket.pdf';
      await analyzePdf();
    } catch (_) {
      if (mounted) {
        setState(() => message =
            'Could not read the shared PDF. Use Select PDF to try again.');
      }
    }
  }

  Future<void> pickPdf() async {
    try {
      final file = await openFile(acceptedTypeGroups: [
        const XTypeGroup(
            label: 'PDF',
            extensions: ['pdf'],
            mimeTypes: ['application/pdf'],
            uniformTypeIdentifiers: ['com.adobe.pdf'])
      ]);
      if (file == null || !mounted) return;
      if (await file.length() > 10 * 1024 * 1024) {
        throw StateError('PDF must be at most 10 MB.');
      }
      final builder = BytesBuilder();
      await for (final chunk in file.openRead()) {
        builder.add(chunk);
        if (builder.length > 10 * 1024 * 1024) {
          throw StateError('PDF must be at most 10 MB.');
        }
      }
      if (!mounted) return;
      pdfBytes = builder.takeBytes();
      pdfName = file.name;
      await analyzePdf();
    } catch (e) {
      if (mounted) {
        setState(() => message = e is StateError
            ? e.message.toString()
            : 'Could not select the PDF. Try again.');
      }
    }
  }

  Future<void> analyzePdf() async {
    setState(() {
      loading = true;
      message = null;
      draft = null;
      reviewed = null;
    });
    try {
      final response =
          await ref.read(travelApiProvider)!.previewPdf(pdfBytes!, pdfName!);
      if (!mounted) return;
      setState(() {
        drafts = (response['items'] as List)
            .map((item) => TravelShareDraft(Map<String, dynamic>.from(item)))
            .toList();
        selectedDraft = 0;
        draft = drafts.first;
        kind = draft!.suggestedKind;
      });
    } catch (e) {
      if (mounted) {
        setState(() => message = e is DioException && e.response?.data is Map
            ? (e.response!.data['error'] as String? ??
                'Could not read the PDF.')
            : 'Could not read the PDF. Check your server connection and try again.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> analyze() async {
    final links = extractPlanLinks(text.text);
    final url = selectedUrl ??
        (links.length == 1
            ? links.single
            : links.isEmpty
                ? ''
                : null);
    if (url == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      message = null;
      draft = null;
      reviewed = null;
    });
    List<TravelShareDraft> results;
    try {
      final response =
          await ref.read(travelApiProvider)!.previewShare(text.text, url);
      results = (response['items'] as List? ?? [response])
          .map((item) => TravelShareDraft(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      results = [TravelShareDraft.offline(text.text, url)];
    }
    if (!mounted) return;
    setState(() {
      drafts = results;
      selectedDraft = 0;
      draft = drafts.first;
      kind = draft!.suggestedKind;
      loading = false;
    });
  }

  Future<void> review() async {
    final trip = ref
        .read(tripListProvider)
        .valueOrNull
        ?.where((t) => t.id == tripId)
        .firstOrNull;
    if (trip == null || draft == null) return;
    setState(() {
      saving = true;
      message = null;
    });
    try {
      final plan = await ref.read(tripPlanProvider(trip.id).future);
      if (!mounted) return;
      var item = reviewed ?? draft!.item(kind);
      if (reviewed == null) {
        final matches = plan.items.where((existing) =>
            sameScheduledActivity(existing, item) ||
            (existing.kind == item.kind &&
                existing.title == item.title &&
                existing['date'] == item['date'] &&
                existing['time'] == item['time'] &&
                existing.links
                    .any((l) => item.links.any((n) => n.url == l.url))));
        if (matches.isNotEmpty) {
          final existing = matches.first;
          final decision = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('Already in your trip?'),
                    content: Text(
                        '“${existing.title}” is already saved for the same date and time. Review it with the imported details?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, 'new'),
                          child: const Text('Add separately')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, 'update'),
                          child: const Text('Update existing')),
                    ],
                  ));
          if (decision == null || !mounted) return;
          if (decision == 'update') {
            final links = [...existing.links];
            for (final link in item.links) {
              if (!links.any((l) => l.url == link.url)) links.add(link);
            }
            item = existing.copy({
              for (final entry in item.fields.entries)
                if (entry.value.isNotEmpty &&
                    !['id', 'kind', 'status', 'priority'].contains(entry.key))
                  entry.key: entry.value
            }, links: links);
          }
        }
      }
      var edited = await editPlanItem(context, trip, plan, item);
      if (edited == null || !mounted) return;
      // Keep the reviewed draft if a local save fails, so edits are not lost.
      reviewed = edited;
      if (pdfBytes != null) {
        await ref.read(travelRepositoryProvider).flushTrips();
        final remote =
            await ref.read(databaseProvider).tripDao.getById(trip.id);
        if (remote?.remoteId == null) {
          throw StateError('Connect to the server to attach your PDF.');
        }
        final document = await ref
            .read(travelApiProvider)!
            .attachPdf(remote!.remoteId!, pdfBytes!, pdfName!);
        edited = edited.copy({
          'documentId': document['id'] as String,
          'documentName': document['name'] as String
        });
        reviewed = edited;
      }
      draft = TravelShareDraft({
        ...draft!.data,
        ...edited.fields,
        'links': edited.links.map((l) => l.toJson()).toList()
      });
      await ref.read(tripPlanRepositoryProvider).save(trip.id, edited);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Added to trip')));
      drafts.removeAt(selectedDraft);
      if (drafts.isEmpty) {
        context.pop();
      } else {
        setState(() {
          selectedDraft = 0;
          draft = drafts.first;
          reviewed = null;
          kind = draft!.suggestedKind;
          message = 'Item saved. Review the remaining itinerary items.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            message = 'Could not save. Your draft is still here; try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripListProvider);
    final links = extractPlanLinks(text.text);
    final records = trips.valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Import to travel')),
      body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const Text(
                  'Share an Airbnb, Trip.com or Google Maps link, paste itinerary text, or select a PDF ticket. Review each item before adding it to a trip.'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                  onPressed: loading || saving ? null : pickPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Select PDF')),
              if (pdfName != null) ...[
                Text(pdfName!, style: Theme.of(context).textTheme.titleSmall),
                const Text(
                    'Up to 10 MB / 20 pages. Scanned pages may use OCR. The original PDF will be available to invited trip members.'),
                TextButton(
                    onPressed: loading || saving ? null : analyzePdf,
                    child: const Text('Read PDF again')),
                TextButton(
                    onPressed: loading || saving
                        ? null
                        : () => setState(() {
                              pdfBytes = null;
                              pdfName = null;
                              draft = null;
                              reviewed = null;
                            }),
                    child: const Text('Remove PDF')),
              ],
              const SizedBox(height: 16),
              if (pdfName == null) ...[
                TextField(
                    controller: text,
                    maxLines: 4,
                    maxLength: 10000,
                    enabled: !loading && !saving,
                    decoration: const InputDecoration(
                        labelText: 'Link or itinerary text'),
                    onChanged: (_) => setState(() {
                          draft = null;
                          reviewed = null;
                          selectedUrl = null;
                          message = null;
                        })),
                if (links.length > 1)
                  DropdownButtonFormField<String>(
                      key: ValueKey(text.text),
                      initialValue: selectedUrl,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Choose a link to import'),
                      items: links
                          .map((url) => DropdownMenuItem(
                              value: url,
                              child:
                                  Text(url, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: loading || saving
                          ? null
                          : (v) => setState(() {
                                selectedUrl = v;
                                draft = null;
                                reviewed = null;
                              })),
                const SizedBox(height: 12),
                FilledButton.icon(
                    onPressed: loading ||
                            saving ||
                            text.text.trim().isEmpty ||
                            (links.length > 1 && selectedUrl == null)
                        ? null
                        : analyze,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.link),
                    label: Text(loading ? 'Reading share…' : 'Analyze share')),
              ],
              if (pdfName != null && loading) const LinearProgressIndicator(),
              if (draft != null) ...[
                if (drafts.length > 1)
                  DropdownButtonFormField<int>(
                      key: ValueKey('segments-${drafts.length}-$selectedDraft'),
                      initialValue: selectedDraft,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Itinerary item'),
                      items: drafts
                          .asMap()
                          .entries
                          .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                  '${e.key + 1}. ${e.value.value('title')}',
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: saving
                          ? null
                          : (v) => setState(() {
                                selectedDraft = v!;
                                draft = drafts[v];
                                reviewed = null;
                                kind = draft!.suggestedKind;
                              })),
                const SizedBox(height: 24),
                Text(
                    draft!.value('title').isEmpty
                        ? '${draft!.source} link'
                        : draft!.value('title'),
                    style: Theme.of(context).textTheme.titleLarge),
                if (draft!.value('time').isNotEmpty)
                  Text(
                      '${draft!.value('time')} ${draft!.value('timezone')} → ${draft!.value('endTime')} ${draft!.value('endTimezone')}'),
                if (draft!.value('endAddress').isNotEmpty)
                  Text('To: ${draft!.value('endAddress')}'),
                if (draft!.value('address').isNotEmpty)
                  Text(draft!.value('address')),
                if (draft!.value('date').isNotEmpty)
                  Text('${draft!.value('date')} → ${draft!.value('endDate')}'),
                if (pdfName != null)
                  ExpansionTile(
                      title: const Text('Extracted ticket text'),
                      children: [SelectableText(draft!.value('notes'))]),
                if (draft!.warning.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(draft!.warning)),
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(pdfName != null
                        ? 'Check dates and local times against the original PDF before saving.'
                        : 'Confirm dates and local times before saving. Dates in hotel links may be search dates.')),
                if (trips.isLoading) const LinearProgressIndicator(),
                if (trips.hasError)
                  const Text(
                      'Could not load trips. Return to Travel and retry.'),
                if (!trips.isLoading && records.isEmpty)
                  const Text(
                      'Create a trip in Travel first, then import this item.'),
                if (records.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                      initialValue: tripId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Trip'),
                      items: records
                          .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                  '${t.destination} · ${planDate(t.startDate)}',
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged:
                          saving ? null : (v) => setState(() => tripId = v)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                      key: ValueKey(kind),
                      isExpanded: true,
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Add as'),
                      items: const [
                        DropdownMenuItem(
                            value: 'place', child: Text('Saved place')),
                        DropdownMenuItem(
                            value: 'activity', child: Text('Activity')),
                        DropdownMenuItem(
                            value: 'booking',
                            child: Text('Transport / stay / reservation'))
                      ],
                      onChanged: saving
                          ? null
                          : (v) => setState(() {
                                kind = v!;
                                reviewed = null;
                              })),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: saving || tripId == null ? null : review,
                      child: Text(saving ? 'Saving…' : 'Review details')),
                ],
              ],
              if (message != null)
                Text(message!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ]),
          )),
    );
  }
}
