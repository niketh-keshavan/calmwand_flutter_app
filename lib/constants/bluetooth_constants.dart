/// Bluetooth LE UUIDs for Calmwand device
/// Extracted from BluetoothManager.swift
class BluetoothConstants {
  // Service UUID
  static const String serviceUUID = "87f23fe2-4b42-11ed-bdc3-0242ac120000";

  // Characteristic UUIDs
  static const String temperatureCharacteristicUUID =
      "87f23fe2-4b42-11ed-bdc3-0242ac12000A";
  static const String brightnessCharacteristicUUID =
      "87f23fe2-4b42-11ed-bdc3-0242ac12000B";
  static const String inhaleTimeCharacteristicUUID =
      "87f23fe2-4b42-11ed-bdc3-0242ac12000C";
  static const String exhaleTimeCharacteristicUUID =
      "87f23fe2-4b42-11ed-bdc3-0242ac12000D";
  static const String motorStrengthCharacteristicUUID =
      "87f23fe2-4b42-11ed-bdc3-0242ac12000E";
  static const String fileListRequestCharacteristicUUID =
      "87f23fe2-4b42-11ed-bdc3-0242ac12000F";
  static const String fileNameCharacteristicUUID =
      "87f23fe2-4b42-11ed-bdc3-0242ac120010";
  static const String fileContentRequestCharacteristicUUID =
      "87f23fe2-4b42-11ed-bdc3-0242ac120011";
  static const String fileContentCharacteristicUUID =
      "87f23fe2-4b42-11ed-bdc3-0242ac120012";
  static const String fileActionCharacteristicUUID =
      "87f23fe2-4b42-11ed-bdc3-0242ac120013";
  static const String sessionIdCharacteristicUUID =
      "87f23fe2-4b42-11ed-bdc3-0242ac120014";

  // Arduino protocol commands
  static const String cmdGetList = "GETLIST";
  static const String cmdGetFile = "GETFILE:";
  static const String cmdDelete = "DELETE:";
  static const String cmdDeleteAll = "DELETEALL";
  static const String cmdStart = "START";
  static const String cmdCancel = "CANCEL";
  static const String markerEnd = "END";
  static const String markerEOF = "EOF";
}
