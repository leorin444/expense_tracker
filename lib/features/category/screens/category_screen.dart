import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/category_provider.dart';
import '../models/category.dart';
import 'package:expense_tracker/main.dart';

class CategoryScreen extends StatelessWidget {
  final bool showFinishButton;

  const CategoryScreen({super.key, this.showFinishButton = false});

  void _showCategoryDialog(BuildContext context, {Category? category}) {
    if (category != null && category.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("System categories cannot be edited.")),
      );
      return;
    }

    final controller = TextEditingController(text: category?.name ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(category == null ? "Add Custom Category" : "Edit Category"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Category Name",
            hintText: "e.g., Subscriptions, Books",
          ),
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
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Category category) {
    if (category.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Default system categories cannot be deleted.")),
      );
      return;
    }

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
              if (!context.mounted) return;
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Categories"),
        automaticallyImplyLeading: !showFinishButton,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Fetch Categories from Server",
            onPressed: () async {
              await provider.fetchCategoriesFromServer();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Categories refreshed")),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(context),
        icon: const Icon(Icons.add),
        label: const Text("Add Custom"),
      ),
      bottomNavigationBar: showFinishButton
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Finish & Go to Dashboard',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          : null,
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? const Center(child: Text("No categories yet"))
              : RefreshIndicator(
                  onRefresh: () => provider.fetchCategoriesFromServer(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSystem = category.isDefault;

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSystem
                                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                : Colors.transparent,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSystem
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.secondaryContainer,
                            child: Icon(
                              isSystem ? Icons.public : Icons.person,
                              color: isSystem
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.secondary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            category.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            isSystem ? "Global (System Default)" : "Custom Category",
                            style: TextStyle(
                              fontSize: 12,
                              color: isSystem ? theme.colorScheme.primary : Colors.grey,
                            ),
                          ),
                          trailing: isSystem
                              ? const Tooltip(
                                  message: "System category (Default for all users)",
                                  child: Icon(Icons.lock_outline, size: 20, color: Colors.grey),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () =>
                                          _showCategoryDialog(context, category: category),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () => _confirmDelete(context, category),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

