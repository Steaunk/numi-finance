import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import '../../../models/trip_plan.dart';
import '../../../providers/providers.dart';

class TicketPdf extends ConsumerStatefulWidget {
  final int tripId;
  final PlanItem item;
  const TicketPdf({super.key, required this.tripId, required this.item});
  @override
  ConsumerState<TicketPdf> createState() => _TicketPdfState();
}

class _TicketPdfState extends ConsumerState<TicketPdf> {
  bool opening = false;
  Future<void> attach() async {
    setState(() => opening = true);
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
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await ref.read(travelRepositoryProvider).flushTrips();
      final trip =
          await ref.read(databaseProvider).tripDao.getById(widget.tripId);
      if (trip?.remoteId == null) {
        throw StateError('Connect to the server to attach a PDF.');
      }
      final document = await ref
          .read(travelApiProvider)!
          .attachPdf(trip!.remoteId!, bytes, file.name);
      final plan = await ref.read(tripPlanProvider(widget.tripId).future);
      final current = plan.find(widget.item.id);
      if (current == null) throw StateError('This arrangement was removed.');
      await ref.read(tripPlanRepositoryProvider).save(
          widget.tripId,
          current.copy({
            'documentId': document['id'] as String,
            'documentName': document['name'] as String
          }));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is StateError
                ? e.message.toString()
                : 'Could not attach the PDF. Check your connection and try again.')));
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> open() async {
    setState(() => opening = true);
    try {
      final id = widget.item['documentId'];
      if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
        throw StateError('Invalid PDF attachment.');
      }
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/travel-tickets/$id.pdf');
      if (!await file.exists()) {
        final trip =
            await ref.read(databaseProvider).tripDao.getById(widget.tripId);
        if (trip?.remoteId == null) {
          throw StateError('Sync the trip before opening its PDF.');
        }
        final bytes =
            await ref.read(travelApiProvider)!.downloadPdf(trip!.remoteId!, id);
        if (bytes.length < 5 ||
            String.fromCharCodes(bytes.take(5)) != '%PDF-') {
          throw StateError('The server did not return a PDF.');
        }
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(file.path);
      }
      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (result.type != ResultType.done) {
        throw StateError('Install a PDF viewer to open the ticket.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is StateError
                ? e.message.toString()
                : 'Could not open the PDF. Check your connection and try again.')));
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.picture_as_pdf),
        title: Text(widget.item['documentId'].isEmpty
            ? 'Attach ticket PDF'
            : widget.item['documentName'].isEmpty
                ? 'Original ticket PDF'
                : widget.item['documentName']),
        subtitle: Text(opening
            ? 'Working…'
            : widget.item['documentId'].isEmpty
                ? 'Original file · shared with invited trip members'
                : 'Open original ticket · available offline after opening'),
        onTap: opening
            ? null
            : widget.item['documentId'].isEmpty
                ? attach
                : open,
        trailing: widget.item['documentId'].isEmpty
            ? null
            : IconButton(
                tooltip: 'Replace PDF',
                onPressed: opening ? null : attach,
                icon: const Icon(Icons.attach_file)),
      );
}
