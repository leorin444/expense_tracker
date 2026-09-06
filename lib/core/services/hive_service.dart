import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String expensesBox = 'expensesBox';
  static const String categoriesBox = 'categoriesBox';
  static const String financeBox = 'financeBox';
  static const String syncQueueBox = 'syncQueueBox';
  static const String appSettingsBox = 'appSettingsBox';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(expensesBox);
    await Hive.openBox<String>(categoriesBox);
    await Hive.openBox<String>(financeBox);
    await Hive.openBox<String>(syncQueueBox);
    await Hive.openBox<String>(appSettingsBox);
  }
  
  static Box<String> getExpenses() => Hive.box<String>(expensesBox);
  static Box<String> getCategories() => Hive.box<String>(categoriesBox);
  static Box<String> getFinance() => Hive.box<String>(financeBox);
  static Box<String> getSyncQueue() => Hive.box<String>(syncQueueBox);
  static Box<String> getAppSettings() => Hive.box<String>(appSettingsBox);
}
