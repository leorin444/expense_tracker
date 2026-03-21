import 'package:flutter/material.dart';

class CategoryProvider with ChangeNotifier {
  final List<String> _categories = [
    'Food',
    'Transport',
    'Bills',
    'Shopping',
    'Other',
  ];

  List<String> get categories => List.unmodifiable(_categories);

  void addCategory(String category) {
    if (category.trim().isEmpty) return;
    if (_categories.contains(category)) return;

    _categories.add(category);
    notifyListeners();
  }

  void updateCategory(int index, String newName) {
    if (newName.trim().isEmpty) return;
    if (index < 0 || index >= _categories.length) return;

    _categories[index] = newName;
    notifyListeners();
  }

  void deleteCategory(int index) {
    if (index < 0 || index >= _categories.length) return;

    _categories.removeAt(index);
    notifyListeners();
  }
}
