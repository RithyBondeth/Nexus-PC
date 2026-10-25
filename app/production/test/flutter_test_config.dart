import 'dart:async';
import 'package:nexus_app/theme/ascii_field.dart';

/// Holds the ASCII background still so `pumpAndSettle` can settle.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AsciiField.animate = false;
  await testMain();
}
