// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FinanceProfileAdapter extends TypeAdapter<FinanceProfile> {
  @override
  final int typeId = 1;

  @override
  FinanceProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinanceProfile(
      monthlyIncome: fields[0] as double,
      savingsPercentage: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, FinanceProfile obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.monthlyIncome)
      ..writeByte(1)
      ..write(obj.savingsPercentage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
