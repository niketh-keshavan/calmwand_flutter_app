// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionModelAdapter extends TypeAdapter<SessionModel> {
  @override
  final int typeId = 0;

  @override
  SessionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionModel(
      sessionNumber: fields[0] as int,
      duration: fields[1] as int,
      temperatureChange: fields[2] as double,
      tempSetData: (fields[3] as List).cast<double>(),
      inhaleTime: fields[4] as double,
      exhaleTime: fields[5] as double,
      regressionA: fields[6] as double?,
      regressionB: fields[7] as double?,
      regressionK: fields[8] as double?,
      score: fields[9] as double?,
      comment: fields[10] as String,
      timestamp: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SessionModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.sessionNumber)
      ..writeByte(1)
      ..write(obj.duration)
      ..writeByte(2)
      ..write(obj.temperatureChange)
      ..writeByte(3)
      ..write(obj.tempSetData)
      ..writeByte(4)
      ..write(obj.inhaleTime)
      ..writeByte(5)
      ..write(obj.exhaleTime)
      ..writeByte(6)
      ..write(obj.regressionA)
      ..writeByte(7)
      ..write(obj.regressionB)
      ..writeByte(8)
      ..write(obj.regressionK)
      ..writeByte(9)
      ..write(obj.score)
      ..writeByte(10)
      ..write(obj.comment)
      ..writeByte(11)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
