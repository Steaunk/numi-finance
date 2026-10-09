import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/constants.dart';
import '../../../models/travel_expense.dart';
import '../../../models/trip_plan.dart';
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
  final String initialDestination;

  const AddTravelExpenseScreen({
    super.key,
    required this.tripId,
    required this.tripStartDate,
    required this.tripEndDate,
    this.expense,
    this.initialDestination = '',
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
  late String _destinationId;
  late Set<String> _planItemIds;

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
    _category = e?.category ?? 'Other';
    _date = e?.date ?? DateTime.now();
    _destinationId = e?.destinationId ?? widget.initialDestination;
    _planItemIds = {...?e?.planItemIds};
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
    final plan =
        ref.watch(tripPlanProvider(widget.tripId)).valueOrNull ?? TripPlan();
    final destination = plan.destinations.any((d) => d.id == _destinationId)
        ? _destinationId
        : '';
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
                  Expanded(
                      child: Text(
                    _isEditing ? 'Edit Travel Expense' : 'Add Travel Expense',
                    style: Theme.of(context).textTheme.headlineSmall,
                  )),
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final amount = double.tryParse(v);
                        if (amount == null || !amount.isFinite || amount <= 0) {
                          return 'Enter a positive amount';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Autocomplete<String>(
                      initialValue: TextEditingValue(text: _currency),
                      optionsBuilder: (textEditingValue) {
                        final query =
                            textEditingValue.text.toUpperCase().trim();
                        if (query.isEmpty) {
                          return AppConstants.travelCurrencies;
                        }
                        return AppConstants.travelCurrencies
                            .where((c) => c.contains(query));
                      },
                      onSelected: (value) => setState(() => _currency = value),
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration:
                              const InputDecoration(labelText: 'Currency'),
                          textCapitalization: TextCapitalization.characters,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (!AppConstants.travelCurrencies
                                .contains(v.toUpperCase())) {
                              return 'Invalid';
                            }
                            return null;
                          },
                          onChanged: (v) {
                            final upper = v.toUpperCase();
                            if (AppConstants.travelCurrencies.contains(upper)) {
                              _currency = upper;
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: AppConstants.travelCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              if (plan.destinations.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('expense-city-$destination'),
                  initialValue: destination,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Destination'),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Unassigned'),
                    ),
                    ...plan.destinations.map(
                      (d) =>
                          DropdownMenuItem(value: d.id, child: Text(d.title)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _destinationId = v!),
                ),
                const SizedBox(height: 12),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Payment date'),
                subtitle: Text(AppDateUtils.displayDate(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Linked itinerary'),
                subtitle:
                    Text('${_planItemIds.length} selected · choose any number'),
                initiallyExpanded: _planItemIds.isNotEmpty,
                children: [
                  if (!plan.items
                      .any((i) => i.kind == 'activity' || i.kind == 'booking'))
                    const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                            'Add activities or bookings in your itinerary first.')),
                  for (final item in plan.items.where((i) =>
                      (i.kind == 'activity' || i.kind == 'booking') &&
                      i['category'] != 'No accommodation needed'))
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(plan.itemTitle(item)),
                      subtitle: Text([
                        item['date'].isEmpty ? 'Anytime' : item['date'],
                        item['time'],
                        item['category']
                      ].where((v) => v.isNotEmpty).join(' · ')),
                      value: _planItemIds.contains(item.id),
                      onChanged: (selected) => setState(() {
                        if (selected == true) {
                          _planItemIds.add(item.id);
                        } else {
                          _planItemIds.remove(item.id);
                        }
                      }),
                    ),
                ],
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

  Future<bool> _save({bool close = true}) async {
    if (!_formKey.currentState!.validate()) return false;
    setState(() => _saving = true);
    try {
      final amount = double.parse(_amountController.text);
      final name = _nameController.text.trim();
      final notes = _notesController.text.trim();
      final plan =
          ref.read(tripPlanProvider(widget.tripId)).valueOrNull ?? TripPlan();
      final destinationId = plan.destinations.any((d) => d.id == _destinationId)
          ? _destinationId
          : '';

      if (_isEditing) {
        await ref.read(travelRepositoryProvider).updateTravelExpense(
              widget.expense!.id,
              amount: amount,
              currency: _currency,
              date: _date,
              category: _category,
              name: name,
              notes: notes,
              destinationId: destinationId,
              planItemIds: _planItemIds.toList(),
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
              destinationId: destinationId,
              planItemIds: _planItemIds.toList(),
            );
      }

      if (mounted && close) {
        Navigator.pop(context, destinationId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEditing ? 'Expense updated' : 'Expense added')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
