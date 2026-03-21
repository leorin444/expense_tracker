import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/category_provider.dart';
import '../models/category.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  void _showCategoryDialog(BuildContext context, {Category? category}) {
    final controller = TextEditingController(text: category?.name ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(category == null ? "Add Category" : "Edit Category"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Category Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty) return;

              final provider = context.read<CategoryProvider>();

              if (category == null) {
                await provider.addCategory(value);
              } else {
                await provider.updateCategory(category.id, value);
              }

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Category"),
        content: Text("Are you sure you want to delete '${category.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<CategoryProvider>().deleteCategory(
                category.id,
              );

              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final categories = provider.categories;

    return Scaffold(
      appBar: AppBar(title: const Text("Manage Categories")),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context),
        child: const Icon(Icons.add),
      ),

      body: categories.isEmpty
          ? const Center(child: Text("No categories yet"))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final category = categories[index];

                return Card(
                  child: ListTile(
                    title: Text(category.name),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              _showCategoryDialog(context, category: category),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(context, category),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
