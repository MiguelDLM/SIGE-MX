// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttendanceRecordAdapter extends TypeAdapter<AttendanceRecord> {
  @override
  final int typeId = 0;

  @override
  AttendanceRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttendanceRecord(
      studentId: fields[0] as String,
      groupId: fields[1] as String,
      fecha: fields[2] as String,
      status: fields[3] as String,
      syncState: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AttendanceRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.studentId)
      ..writeByte(1)
      ..write(obj.groupId)
      ..writeByte(2)
      ..write(obj.fecha)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.syncState);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
