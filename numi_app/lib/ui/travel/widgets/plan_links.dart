import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/trip_plan.dart';

Future<void> openPlanLink(BuildContext context, String value) async {
  final uri = safeExternalLink(value);
  var opened = false;
  if (uri != null) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
  if (opened || !context.mounted) return;
  await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
            title: const Text('Could not open link'),
            content: SelectableText(value),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
              FilledButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Copy link'))
            ],
          ));
}

class PlanLinks extends StatelessWidget {
  final List<PlanLink> links;
  const PlanLinks({super.key, required this.links});
  @override
  Widget build(BuildContext context) => Column(
      children: links
          .map((link) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(link.purpose == 'Map'
                    ? Icons.map_outlined
                    : Icons.open_in_new),
                title: Text(link.displayName,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${link.purpose} · ${link.platform}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => openPlanLink(context, link.url),
                trailing: IconButton(
                    tooltip: 'Copy link',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link.url));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied')));
                      }
                    }),
              ))
          .toList());
}

class PlanLinksEditor extends StatefulWidget {
  final List<PlanLink> links;
  final ValueChanged<List<PlanLink>> onChanged;
  const PlanLinksEditor(
      {super.key, required this.links, required this.onChanged});
  @override
  State<PlanLinksEditor> createState() => _PlanLinksEditorState();
}

class _PlanLinksEditorState extends State<PlanLinksEditor> {
  Future<void> edit([int? index]) async {
    final result = await showDialog<List<PlanLink>>(
        context: context,
        builder: (_) =>
            _LinkDialog(link: index == null ? null : widget.links[index]));
    if (result == null || !mounted) return;
    final links = widget.links.toList();
    if (index == null) {
      links.addAll(result);
    } else {
      links[index] = result.single;
    }
    widget.onChanged(links);
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
              child: Text('External links',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          TextButton.icon(
              onPressed: widget.links.length >= 50 ? null : () => edit(),
              icon: const Icon(Icons.add_link),
              label: const Text('Add links'))
        ]),
        ...widget.links.asMap().entries.map((e) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e.value.displayName,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${e.value.purpose} · ${e.value.platform}'),
            onTap: () => edit(e.key),
            trailing: IconButton(
                tooltip: 'Remove link',
                icon: const Icon(Icons.close),
                onPressed: () {
                  final links = widget.links.toList()..removeAt(e.key);
                  widget.onChanged(links);
                }))),
      ]);
}

class _LinkDialog extends StatefulWidget {
  final PlanLink? link;
  const _LinkDialog({this.link});
  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final TextEditingController text;
  late final TextEditingController label;
  late String purpose;
  late List<String> candidates;
  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: widget.link?.url ?? '');
    label = TextEditingController(text: widget.link?.label ?? '');
    purpose = widget.link?.purpose ?? 'Other';
    candidates = widget.link == null ? [] : [widget.link!.url];
  }

  @override
  void dispose() {
    text.dispose();
    label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.link == null ? 'Add links' : 'Edit link'),
        content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: text,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'URL or share text',
                      hintText: 'Paste a link or a shared post'),
                  onChanged: (value) =>
                      setState(() => candidates = extractPlanLinks(value))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  initialValue: purpose,
                  decoration: const InputDecoration(labelText: 'Purpose'),
                  items: linkPurposes
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => purpose = v!),
              TextField(
                  controller: label,
                  decoration: const InputDecoration(
                      labelText: 'Display name (optional)')),
              const SizedBox(height: 12),
              if (candidates.isEmpty)
                const Text('Paste an http or https link to see a preview.')
              else
                ...candidates.map((url) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(linkPlatform(url)),
                    subtitle: Text(url,
                        maxLines: 3, overflow: TextOverflow.ellipsis))),
              if (widget.link != null && candidates.length > 1)
                const Text('Keep one URL when editing a link.'),
            ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: candidates.isEmpty ||
                      (widget.link != null && candidates.length != 1)
                  ? null
                  : () => Navigator.pop(
                      context,
                      candidates
                          .map((url) => PlanLink(
                              purpose: purpose,
                              label: label.text.trim(),
                              url: url))
                          .toList()),
              child: const Text('Save links'))
        ],
      );
}
