import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';

class CategoryProvider with ChangeNotifier {
  static const String _boxName = 'categoriesBox';

  late Box<Category> _box;
  final Uuid _uuid = const Uuid();

  List<Category> _categories = [];
  List<Category> get categories => List.unmodifiable(_categories);

  Future<void> init() async {
    _box = await Hive.openBox<Category>(_boxName);
    _loadCategories();
  }

  void _loadCategories() {
    _categories = _box.values.toList();
    notifyListeners();
  }

  /// ADD
  Future<void> addCategory(String name) async {
    if (name.trim().isEmpty) return;

    final exists = _categories.any(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) return;

    final category = Category(id: _uuid.v4(), name: name);

    await _box.put(category.id, category);
    _loadCategories();
  }

  /// UPDATE
  Future<void> updateCategory(String id, String newName) async {
    if (newName.trim().isEmpty) return;

    final category = _box.get(id);
    if (category == null) return;

    category.name = newName;
    await category.save();

    _loadCategories();
  }

  /// DELETE
  Future<void> deleteCategory(String id) async {
    await _box.delete(id);
    _loadCategories();
  }
}
