import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/sync_action.dart';

class CategoryProvider with ChangeNotifier {
  final Uuid _uuid = const Uuid();
  final ApiService _apiService = ApiService();

  List<Category> _categories = [];
  bool _isLoading = false;

  List<Category> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;

  // Standard global default categories matching Database
  static final List<Category> defaultSystemCategories = [
    Category(id: '1', name: 'Food', isDefault: true, icon: 'restaurant'),
    Category(id: '2', name: 'Transport', isDefault: true, icon: 'directions_car'),
    Category(id: '3', name: 'Shopping', isDefault: true, icon: 'shopping_cart'),
    Category(id: '4', name: 'Bills', isDefault: true, icon: 'receipt'),
    Category(id: '5', name: 'Entertainment', isDefault: true, icon: 'movie'),
    Category(id: '6', name: 'Healthcare', isDefault: true, icon: 'medical_services'),
    Category(id: '7', name: 'Housing & Rent', isDefault: true, icon: 'home'),
    Category(id: '8', name: 'Other', isDefault: true, icon: 'more_horiz'),
  ];

  Future<void> init() async {
    await _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final box = HiveService.getCategories();
      
      // Clean up legacy default category keys if present
      final legacyKeys = [
        'cat_food', 'cat_transport', 'cat_shopping', 'cat_utilities',
        'cat_entertainment', 'cat_health', 'cat_housing', 'cat_other'
      ];
      for (var k in legacyKeys) {
        if (box.containsKey(k)) {
          await box.delete(k);
        }
      }

      // Seed / ensure standard default categories with numeric IDs
      for (var cat in defaultSystemCategories) {
        if (!box.containsKey(cat.id)) {
          await box.put(cat.id, jsonEncode(cat.toMap()));
        }
      }

      final Map<String, Category> uniqueByName = {};
      // 1. Defaults first
      for (var def in defaultSystemCategories) {
        uniqueByName[def.name.toLowerCase()] = def;
      }
      // 2. Load stored categories
      for (var val in box.values) {
        try {
          final cat = Category.fromMap(jsonDecode(val) as Map<String, dynamic>);
          final key = cat.name.toLowerCase().trim();
          if (key.isNotEmpty) {
            // Normalize legacy names to standard defaults
            if (key == 'food & dining') {
              uniqueByName['food'] = defaultSystemCategories[0];
            } else if (key == 'transportation') {
              uniqueByName['transport'] = defaultSystemCategories[1];
            } else if (key == 'bills & utilities') {
              uniqueByName['bills'] = defaultSystemCategories[3];
            } else {
              uniqueByName[key] = cat;
            }
          }
        } catch (_) {}
      }

      _categories = uniqueByName.values.toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading categories: $e");
    }
  }

  /// Fetch latest global and user custom categories from the backend server with deduplication
  Future<void> fetchCategoriesFromServer() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Pass firebaseUid so the API returns: global categories (UserId=NULL) + this user's custom categories
      final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
      final endpoint = firebaseUid != null
          ? '/categories?firebaseUid=$firebaseUid'
          : '/categories';

      final dynamic response = await _apiService.get(endpoint);
      if (response != null && response is List) {
        final box = HiveService.getCategories();
        final Map<String, Category> merged = {};

        // 1. Keep system defaults as base (IDs 1-8)
        for (var def in defaultSystemCategories) {
          merged[def.name.toLowerCase()] = def;
        }

        // 2. Load existing local custom categories
        for (var val in box.values) {
          try {
            final cat = Category.fromMap(jsonDecode(val) as Map<String, dynamic>);
            final idNum = int.tryParse(cat.id);
            if (idNum == null || idNum > 8) {
              merged[cat.name.toLowerCase().trim()] = cat;
            }
          } catch (_) {}
        }

        // 3. Merge server categories
        for (var item in response) {
          try {
            final cat = Category.fromMap(item as Map<String, dynamic>);
            final name = cat.name.trim();
            if (name.isNotEmpty) {
              final key = name.toLowerCase();
              final idNum = int.tryParse(cat.id);
              if (idNum != null && idNum <= 8) {
                // System category: preserve isDefault = true
                merged[key] = cat.copyWith(isDefault: true);
              } else {
                merged[key] = cat;
              }
              await box.put(cat.id, jsonEncode(merged[key]!.toMap()));
            }
          } catch (_) {}
        }

        _categories = merged.values.toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to fetch categories from server (offline or error): $e');
      // Fallback to local Hive categories
      await _loadCategories();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ADD Custom Category
  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final lower = trimmed.toLowerCase();
    final exists = _categories.any((c) => c.name.trim().toLowerCase() == lower) ||
                   defaultSystemCategories.any((c) => c.name.trim().toLowerCase() == lower);
    if (exists) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final category = Category(
      id: _uuid.v4(),
      name: trimmed,
      userId: currentUserId,
      isDefault: false,
    );

    try {
      final box = HiveService.getCategories();
      final jsonStr = jsonEncode(category.toMap());
      await box.put(category.id, jsonStr);

      final syncAction = SyncAction(
        id: _uuid.v4(),
        collection: 'categories',
        action: 'CREATE',
        payload: jsonStr,
      );
      SyncService.queueAction(syncAction);

      _categories.add(category);
      notifyListeners();
    } catch (e) {
      debugPrint("Error adding category: $e");
    }
  }

  /// UPDATE Custom Category
  Future<bool> updateCategory(String id, String newName) async {
    if (newName.trim().isEmpty) return false;

    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) return false;

    final existing = _categories[index];
    if (existing.isDefault) {
      debugPrint("Cannot modify a default system category");
      return false;
    }

    final updatedCategory = existing.copyWith(name: newName.trim());

    try {
      final box = HiveService.getCategories();
      final jsonStr = jsonEncode(updatedCategory.toMap());
      await box.put(updatedCategory.id, jsonStr);

      final syncAction = SyncAction(
        id: _uuid.v4(),
        collection: 'categories',
        action: 'UPDATE',
        payload: jsonStr,
      );
      SyncService.queueAction(syncAction);

      _categories[index] = updatedCategory;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error updating category: $e");
      return false;
    }
  }

  /// DELETE Custom Category
  Future<bool> deleteCategory(String id) async {
    final category = _categories.firstWhere(
      (c) => c.id == id,
      orElse: () => Category(id: '', name: ''),
    );

    if (category.id.isEmpty) return false;

    if (category.isDefault) {
      debugPrint("Cannot delete a default system category");
      return false;
    }

    try {
      final box = HiveService.getCategories();
      await box.delete(id);

      final syncAction = SyncAction(
        id: _uuid.v4(),
        collection: 'categories',
        action: 'DELETE',
        payload: jsonEncode({'id': id}),
      );
      SyncService.queueAction(syncAction);

      _categories.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error deleting category: $e");
      return false;
    }
  }
}

