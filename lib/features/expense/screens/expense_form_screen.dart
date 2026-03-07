import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../../dayend/providers/dayend_provider.dart';

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense;

  const ExpenseFormScreen({super.key, this.expense});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _amountController;

  final List<String> _categories = [
    'Food',
    'Transport',
    'Bills',
    'Shopping',
    'Other',
  ];

  String? _selectedCategory;

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.expense?.title ?? '');

    _amountController = TextEditingController(
      text: widget.expense?.amount.toString() ?? '',
    );

    _selectedCategory = widget.expense?.category;
    _selectedDate = widget.expense?.date ?? DateTime.now();

    _amountController.addListener(_checkAmount);
  }

  void _checkAmount() {
    // Left intentionally blank if we just wanted a listener to trigger build
    // or we can remove the listener entirely since Form validator handles it on submit.
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveExpense() {
    final dayEnd = context.read<DayEndProvider>();

    if (!dayEnd.canAddExpense()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day is closed. Cannot add expense.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ExpenseProvider>();
    final finance = context.read<FinanceProvider>();
    final spendable = finance.profile?.spendableAmount ?? double.infinity;

    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    // ---------------- MONTHLY LIMIT VALIDATION ----------------

    final monthlyTotal = provider.expenses
        .where(
          (e) =>
              e.date.year == _selectedDate.year &&
              e.date.month == _selectedDate.month,
        )
        .fold<double>(0, (sum, e) => sum + e.amount);

    final previousAmount = widget.expense?.amount ?? 0;
    final projectedTotal = monthlyTotal - previousAmount + amount;

    if (projectedTotal > spendable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot save! Monthly limit of Rs ${spendable.toStringAsFixed(2)} exceeded.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ----------------------------------------------------------

    if (widget.expense == null) {
      provider.addExpense(
        context: context,
        title: title,
        amount: amount,
        category: _selectedCategory!,
        date: _selectedDate,
      );
    } else {
      provider.updateExpense(
        id: widget.expense!.id,
        title: title,
        amount: amount,
        category: _selectedCategory!,
        date: _selectedDate,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.expense == null ? 'Expense saved!' : 'Expense updated!',
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;

    final finance = context.watch<FinanceProvider>();
    final provider = context.read<ExpenseProvider>();
    final spendable = finance.profile?.spendableAmount ?? double.infinity;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Expense' : 'Add Expense'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // TITLE
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Title is required'
                          : null,
                    ),

                    const SizedBox(height: 20),

                    // AMOUNT
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: 'Rs ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Amount is required';
                        }

                        final amt = double.tryParse(value.trim());

                        if (amt == null) {
                          return 'Enter valid number';
                        }

                        final monthlyTotal = provider.expenses
                            .where(
                              (e) =>
                                  e.date.year == _selectedDate.year &&
                                  e.date.month == _selectedDate.month,
                            )
                            .fold<double>(0, (sum, e) => sum + e.amount);

                        final previousAmount = widget.expense?.amount ?? 0;

                        final projectedTotal =
                            monthlyTotal - previousAmount + amt;

                        if (projectedTotal > spendable) {
                          return 'Exceeds monthly limit (Rs ${spendable.toStringAsFixed(2)})';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 8),

                    Builder(
                      builder: (_) {
                        final amt =
                            double.tryParse(_amountController.text) ?? 0;

                        final monthlyTotal = provider.expenses
                            .where(
                              (e) =>
                                  e.date.year == _selectedDate.year &&
                                  e.date.month == _selectedDate.month,
                            )
                            .fold<double>(0, (sum, e) => sum + e.amount);

                        final previousAmount = widget.expense?.amount ?? 0;

                        final projectedTotal =
                            monthlyTotal - previousAmount + amt;

                        if (projectedTotal > spendable) {
                          return const Text(
                            '⚠ This will exceed your monthly limit',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          );
                        }

                        if (projectedTotal > spendable * 0.9) {
                          return const Text(
                            '⚠ You are nearing your monthly limit',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),

                    const SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCategory = value),
                      validator: (value) =>
                          value == null ? 'Select a category' : null,
                    ),

                    const SizedBox(height: 20),

                    // DATE
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveExpense,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          isEditing ? 'Update Expense' : 'Save Expense',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
