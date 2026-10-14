import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory(
    Platform.environment['NEXUS_EVIDENCE_DIR'] ?? 'build/shell-evidence',
  );
  await output.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (!['home', 'library', 'device', 'settings'].contains(name)) {
        return false;
      }
      await File('${output.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      final report = {...?data}..remove('screenshots');
      report['passed'] = true;
      report['testedAtUtc'] = DateTime.now().toUtc().toIso8601String();
      await File(
        '${output.path}/report.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    },
  );
}
