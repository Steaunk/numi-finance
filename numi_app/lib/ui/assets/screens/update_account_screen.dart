import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/constants.dart';
import '../../../models/account.dart';
import '../../../providers/providers.dart';
import '../../common/widgets/loading_button.dart';
import '../../../utils/currency_utils.dart';

class UpdateAccountScreen extends ConsumerStatefulWidget {
  final Account account;
  const UpdateAccountScreen({super.key, required this.account});

  @override
  ConsumerState<UpdateAccountScreen> createState() =>
      _UpdateAccountScreenState();
}

class _UpdateAccountScreenState extends ConsumerState<UpdateAccountScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final TextEditingController _notesController;
  late String _currency;
  late bool _includeInTotal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.name);
    _balanceController =
        TextEditingController(text: widget.account.balance.toString());
    _notesController = TextEditingController(text: widget.account.notes);
    _currency = widget.account.currency;
    _includeInTotal = widget.account.includeInTotal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Account',
                    style: Theme.of(context).textTheme.headlineSmall),
                IconButton(
                  icon: Icon(Icons.delete,
                      color: Theme.of(context).colorScheme.error),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Account'),
                        content:
                            Text('Delete "${widget.account.name}"?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await ref
                          .read(assetRepositoryProvider)
                          .deleteAccount(widget.account.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Current: ${CurrencyUtils.format(widget.account.balance, widget.account.currency)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _balanceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'New Balance'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration:
                        const InputDecoration(labelText: 'Currency'),
                    items: AppConstants.currencies
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include in net worth'),
              value: _includeInTotal,
              onChanged: (v) => setState(() => _includeInTotal = v),
            ),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            LoadingButton(
              loading: _saving,
              onPressed: _save,
              label: 'Save Changes',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final newBalance = double.tryParse(_balanceController.text);
      await ref.read(assetRepositoryProvider).updateAccount(
            widget.account.id,
            name: _nameController.text.trim(),
            currency: _currency,
            balance: newBalance,
            includeInTotal: _includeInTotal,
            notes: _notesController.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Account updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
