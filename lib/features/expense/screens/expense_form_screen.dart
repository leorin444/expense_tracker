import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense; // Pass this for editing

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

  double? _warningAmount;

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
    final finance = context.read<FinanceProvider>();
    final spendable = finance.profile?.spendableAmount ?? double.infinity;

    final input = double.tryParse(_amountController.text);
    setState(() {
      if (input != null && input > spendable) {
        _warningAmount = input - spendable;
      } else {
        _warningAmount = null;
      }
    });
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
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: Colors.teal)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ExpenseProvider>();
    final finance = context.read<FinanceProvider>();
    final spendable = finance.profile?.spendableAmount ?? double.infinity;

    final title = _titleController.text;
    final amount = double.tryParse(_amountController.text) ?? 0;

    // ------------------ MONTHLY LIMIT VALIDATION ------------------
    final now = _selectedDate;
    final monthlyTotal = provider.expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold<double>(0, (sum, e) => sum + e.amount);

    // If editing, subtract old expense amount to avoid double-count
    final previousAmount = widget.expense?.amount ?? 0;
    final projectedTotal = monthlyTotal - previousAmount + amount;

    if (projectedTotal > spendable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot add expense! Monthly limit of Rs ${spendable.toStringAsFixed(2)} exceeded.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    // -----------------------------------------------------------

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
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Expense' : 'Add Expense'),
          centerTitle: true,
          backgroundColor: Colors.teal[600],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildTitleField(),
                              const SizedBox(height: 20),
                              _buildAmountField(),
                              if (_warningAmount != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Amount exceeds your spendable by Rs ${_warningAmount!.toStringAsFixed(2)}!',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              _buildCategoryField(),
                              const SizedBox(height: 20),
                              _buildDatePicker(),
                              const SizedBox(height: 30),
                              _buildSaveButton(isEditing),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: _inputDecoration(label: 'Title', hint: 'Enter expense title'),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Title is required' : null,
    );
  }

  Widget _buildAmountField() {
    final provider = context.read<ExpenseProvider>();
    final finance = context.watch<FinanceProvider>();
    final spendable = finance.profile?.spendableAmount ?? double.infinity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration(
            label: 'Amount',
            hint: 'Enter amount',
            prefix: 'Rs ',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty)
              return 'Amount is required';
            final amt = double.tryParse(value);
            if (amt == null) return 'Enter a valid number';

            // Monthly total check
            final now = _selectedDate;
            final monthlyTotal = provider.expenses
                .where(
                  (e) => e.date.year == now.year && e.date.month == now.month,
                )
                .fold<double>(0, (sum, e) => sum + e.amount);

            final previousAmount = widget.expense?.amount ?? 0;
            final projectedTotal = monthlyTotal - previousAmount + amt;

            if (projectedTotal > spendable) {
              return 'Exceeds monthly spendable limit of Rs ${spendable.toStringAsFixed(2)}';
            }
            return null;
          },
          onChanged: (_) =>
              setState(() {}), // triggers rebuild for live feedback
        ),
        const SizedBox(height: 6),
        Builder(
          builder: (context) {
            final amt = double.tryParse(_amountController.text) ?? 0;
            final now = _selectedDate;
            final monthlyTotal = provider.expenses
                .where(
                  (e) => e.date.year == now.year && e.date.month == now.month,
                )
                .fold<double>(0, (sum, e) => sum + e.amount);
            final previousAmount = widget.expense?.amount ?? 0;
            final projectedTotal = monthlyTotal - previousAmount + amt;

            if (projectedTotal > spendable) {
              return Text(
                'Warning: This will exceed your monthly limit!',
                style: const TextStyle(color: Colors.red, fontSize: 13),
              );
            } else if (projectedTotal > 0.9 * spendable) {
              return Text(
                'Caution: You are nearing your monthly limit.',
                style: const TextStyle(color: Colors.orange, fontSize: 13),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildCategoryField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: _inputDecoration(label: 'Category'),
      items: _categories
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (value) => setState(() => _selectedCategory = value),
      validator: (value) => value == null ? 'Select a category' : null,
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: _inputDecoration(label: 'Date'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
            ),
            const Icon(Icons.calendar_today, color: Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool isEditing) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveExpense,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal[600],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          isEditing ? 'Update Expense' : 'Save Expense',
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    String? prefix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      filled: true,
      fillColor: Colors.grey[50],
      floatingLabelStyle: const TextStyle(color: Colors.teal),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
