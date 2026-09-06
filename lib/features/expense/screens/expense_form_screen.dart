// ignore_for_file: use_build_context_synchronously

import 'package:expense_tracker/core/utils/expense_policy.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../finance/providers/finance_provider.dart';
import '../../category/providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';

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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<bool?> _showIncomePrompt(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Income Required"),
        content: const Text(
          "Your expenses exceeded total income. Add extra income?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Add Income"),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Warning"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Continue"),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _showAddIncomeDialog(BuildContext context) async {
    final sourceController = TextEditingController();
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Extra Income"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sourceController,
              decoration: const InputDecoration(labelText: "Income Source"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final source = sourceController.text.trim();
              final amount = double.tryParse(amountController.text.trim()) ?? 0;

              if (source.isNotEmpty && amount > 0) {
                context.read<FinanceProvider>().addExtraIncome(
                  source: source,
                  amount: amount,
                );
              }

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) return;

    final finance = context.read<FinanceProvider>();
    final expenseProvider = context.read<ExpenseProvider>();

    final amount = double.parse(_amountController.text.trim());

    final decision = expenseProvider.checkExpense(
      amount: amount,
      date: _selectedDate,
      spendable: finance.spendableAmount,
      totalIncome: finance.totalIncome,
    );

    // 🚨 LEVEL 2 → Income exceeded
    if (decision.type == ExpenseDecisionType.needsIncome) {
      final addIncome = await _showIncomePrompt(context);

      if (addIncome == true) {
        await _showAddIncomeDialog(context);
        return _saveExpense(); // retry after income update
      }
      return;
    }

    // ⚠️ LEVEL 1 → Spendable exceeded
    if (decision.type == ExpenseDecisionType.warnSpendableExceeded) {
      final proceed = await _showConfirmDialog(
        context,
        decision.message ?? "Warning",
      );

      if (!proceed) return;
    }

    // ✅ Proceed
    final userId = expenseProvider.currentUserId;
    if (userId == null) return;

    final newTitle = _titleController.text.trim();
    final newCategory = _selectedCategory!;

    if (widget.expense != null) {
      final existing = widget.expense!;
      final bool isSameDate = existing.date.year == _selectedDate.year &&
          existing.date.month == _selectedDate.month &&
          existing.date.day == _selectedDate.day;

      final bool hasChanges = existing.title.trim() != newTitle ||
          existing.amount != amount ||
          existing.category != newCategory ||
          !isSameDate;

      if (!hasChanges) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No changes made")),
          );
        }
        return;
      }

      await expenseProvider.updateExpense(
        id: existing.id,
        title: newTitle,
        amount: amount,
        category: newCategory,
        date: _selectedDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Expense updated successfully")),
        );
        Navigator.pop(context);
      }
      return;
    }

    final expense = Expense(
      id: const Uuid().v4(),
      userId: userId,
      title: newTitle,
      amount: amount,
      category: newCategory,
      date: _selectedDate,
    );

    await expenseProvider.addExpense(expense);
    // ✅ Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense added successfully")),
      );
      Navigator.pop(context); // go back only once
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;
    final provider = context.watch<ExpenseProvider>();

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
                    // Title
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

                    // Amount
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
                        if (amt == null) return 'Enter valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Category
                    Consumer<CategoryProvider>(
                      builder: (context, categoryProvider, _) {
                        final categories = categoryProvider.categories;
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: const OutlineInputBorder(),
                          ),
                          items: categories
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c.name, // ✅ use property
                                  child: Text(c.name), // ✅ no casting
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedCategory = val),
                          validator: (val) =>
                              val == null ? 'Select a category' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Date
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

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: provider.isAdding ? null : _saveExpense,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: provider.isAdding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing ? 'Update Expense' : 'Save Expense',
                                style: const TextStyle(fontSize: 16),
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
