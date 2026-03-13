import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/account.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/loading_button.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  int? _fromId;
  int? _toId;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountListProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: accountsAsync.when(
        data: (accounts) => _buildForm(context, accounts),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<Account> accounts) {
    if (accounts.length < 2) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Transfer', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const Text('Need at least 2 accounts to transfer.'),
        ],
      );
    }

    final fromAccount = accounts.where((a) => a.id == _fromId).firstOrNull;
    final toAccount = accounts.where((a) => a.id == _toId).firstOrNull;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Transfer', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),

            // From account
            DropdownButtonFormField<int>(
              initialValue: _fromId,
              decoration: const InputDecoration(labelText: 'From'),
              items: accounts
                  .where((a) => a.id != _toId)
                  .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${a.name} (${CurrencyUtils.format(a.balance, a.currency)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _fromId = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 8),

            // Swap button
            Center(
              child: IconButton(
                icon: const Icon(Icons.swap_vert),
                onPressed: _fromId != null || _toId != null
                    ? () => setState(() {
                          final tmp = _fromId;
                          _fromId = _toId;
                          _toId = tmp;
                        })
                    : null,
              ),
            ),
            const SizedBox(height: 8),

            // To account
            DropdownButtonFormField<int>(
              initialValue: _toId,
              decoration: const InputDecoration(labelText: 'To'),
              items: accounts
                  .where((a) => a.id != _fromId)
                  .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${a.name} (${CurrencyUtils.format(a.balance, a.currency)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _toId = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: fromAccount?.currency ?? '',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final amount = double.tryParse(v);
                if (amount == null || amount <= 0) return 'Invalid amount';
                if (fromAccount != null && amount > fromAccount.balance) {
                  return 'Exceeds balance';
                }
                return null;
              },
            ),

            // Show conversion info
            if (fromAccount != null &&
                toAccount != null &&
                fromAccount.currency != toAccount.currency) ...[
              const SizedBox(height: 8),
              Text(
                '${fromAccount.currency} → ${toAccount.currency}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],

            const SizedBox(height: 20),
            LoadingButton(
              loading: _saving,
              onPressed: _transfer,
              label: 'Transfer',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _transfer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(assetRepositoryProvider).transfer(
            fromAccountId: _fromId!,
            toAccountId: _toId!,
            amount: double.parse(_amountController.text),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer completed')),
        );
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
