import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../../category/screens/category_screen.dart';

class FinanceSetupScreen extends StatefulWidget {
  const FinanceSetupScreen({super.key});

  @override
  State<FinanceSetupScreen> createState() => _FinanceSetupScreenState();
}

class _FinanceSetupScreenState extends State<FinanceSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _incomeController = TextEditingController();
  double _savingsPercentage = 20;

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  double get _income =>
      double.tryParse(_incomeController.text.replaceAll(',', '')) ?? 0;

  double get _savingsAmount => (_income * _savingsPercentage / 100);

  double get _spendableAmount => (_income - _savingsAmount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Finance Setup'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _incomeCard()),
                            const SizedBox(width: 24),
                            Expanded(child: _savingsCard()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _incomeCard(),
                            const SizedBox(height: 20),
                            _savingsCard(),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _saveFinance,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Save Finance Settings',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- INCOME CARD ----------------
  Widget _incomeCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Monthly Income', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _incomeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixText: 'Rs ',
                hintText: 'Enter your monthly income',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Income is required';
                }
                if (double.tryParse(value.replaceAll(',', '')) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- SAVINGS CARD ----------------
  Widget _savingsCard() {
    final spendableWarning = _spendableAmount < 0.1 * _income;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Savings: ${_savingsPercentage.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            // Increment/Decrement buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _income > 0 && _savingsPercentage > 0
                      ? () {
                          setState(
                            () => _savingsPercentage = (_savingsPercentage - 1)
                                .clamp(0, 100),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Text(
                  '${_savingsPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _income > 0 && _savingsPercentage < 100
                      ? () {
                          setState(
                            () => _savingsPercentage = (_savingsPercentage + 1)
                                .clamp(0, 100),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            Slider(
              value: _savingsPercentage.clamp(0, 100),
              min: 0,
              max: 100, // max percentage
              divisions: 100,
              label: '${_savingsPercentage.toStringAsFixed(0)}%',
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: _income > 0
                  ? (v) {
                      setState(() => _savingsPercentage = v);
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            Text('Savings Amount: Rs ${_savingsAmount.toStringAsFixed(2)}'),
            Text(
              'Spendable Balance: Rs ${_spendableAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: spendableWarning ? Colors.red : Colors.black,
              ),
            ),
            if (spendableWarning)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Warning: Spendable balance is very low!',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveFinance() async {
    if (!_formKey.currentState!.validate()) return;
    if (_savingsAmount > _income) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Savings cannot exceed income!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final provider = context.read<FinanceProvider>();
    await provider.setupFinance(
      income: _income,
      savingsPercent: _savingsPercentage,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Finance settings saved!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CategoryScreen(showFinishButton: true),
      ),
    );
  }
}
