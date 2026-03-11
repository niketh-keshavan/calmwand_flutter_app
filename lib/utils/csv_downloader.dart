// lib/utils/csv_downloader.dart
// This version runs on MOBILE (iPhone, Android)
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadCSV(String csv, String fileName) async {
  final directory = await getTemporaryDirectory();
  final path = '${directory.path}/$fileName';
  final file = File(path);
  await file.writeAsString(csv);
  await Share.shareXFiles([XFile(path)], subject: 'Calmwand Session Data');
}
