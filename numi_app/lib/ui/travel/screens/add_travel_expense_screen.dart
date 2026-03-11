import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/constants.dart';
import '../../../models/travel_expense.dart';
import '../../../providers/providers.dart';
import '../../../utils/date_utils.dart';
import '../../common/widgets/loading_button.dart';
import '../../common/widgets/dialogs.dart';

class AddTravelExpenseScreen extends ConsumerStatefulWidget {
  final int tripId;
  final DateTime tripStartDate;
  final DateTime tripEndDate;
  /// Pass an existing expense to open in edit mode.
  final TravelExpense? expense;

  const AddTravelExpenseScreen({
    super.key,
    required this.tripId,
    required this.tripStartDate,
    required this.tripEndDate,
    this.expense,
  });

  @override
  ConsumerState<AddTravelExpenseScreen> createState() =>
      _AddTravelExpenseScreenState();
}

class _AddTravelExpenseScreenState
    extends ConsumerState<AddTravelExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late String _currency;
  late String _category;
  late DateTime _date;
  bool _saving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amountController =
        TextEditingController(text: e != null ? e.amount.toString() : '');
    _nameController = TextEditingController(text: e?.name ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _currency = e?.currency ?? AppConstants.defaultCurrency;
    _category = e?.category ?? AppConstants.travelCategories.first;
    _date = e?.date ?? widget.tripStartDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Edit Travel Expense' : 'Add Travel Expense',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (_isEditing)
                    IconButton(
                      icon: Icon(Icons.delete,
                          color: Theme.of(context).colorScheme.error),
                      onPressed: () async {
                        final confirm = await showDeleteConfirmDialog(
                          context,
                          title: 'Delete Expense',
                          content: 'Delete "${widget.expense!.name}"?',
                        );
                        if (confirm && context.mounted) {
                          await ref
                              .read(travelRepositoryProvider)
                              .deleteTravelExpense(
                                  widget.expense!.id, widget.tripId);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Amount'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
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
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: AppConstants.travelCategories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(AppDateUtils.displayDate(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: widget.tripStartDate
                        .subtract(const Duration(days: 365)),
                    lastDate:
                        widget.tripEndDate.add(const Duration(days: 100)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              LoadingButton(
                loading: _saving,
                onPressed: _save,
                label: _isEditing ? 'Save Changes' : 'Add Expense',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final amount = double.parse(_amountController.text);
      final name = _nameController.text.trim();
      final notes = _notesController.text.trim();

      if (_isEditing) {
        await ref.read(travelRepositoryProvider).updateTravelExpense(
              widget.expense!.id,
              amount: amount,
              currency: _currency,
              date: _date,
              category: _category,
              name: name,
              notes: notes,
            );
      } else {
        await ref.read(travelRepositoryProvider).addTravelExpense(
              tripId: widget.tripId,
              amount: amount,
              currency: _currency,
              date: _date,
              category: _category,
              name: name,
              notes: notes,
            );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  _isEditing ? 'Expense updated' : 'Expense added')),
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
