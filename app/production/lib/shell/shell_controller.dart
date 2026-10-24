import 'dart:async';
import 'package:flutter/foundation.dart';
import '../platform/nexus_platform.dart';

/// One device/status owner for the shell. Navigation never starts native work.
class ShellController extends ChangeNotifier {
  ShellController(this.platform) {
    _statusSubscription = platform.statuses.listen((value) {
      if (_disposed) return;
      _statusRevision++;
      status = value;
      statusError = null;
      notifyListeners();
    });
  }

  final NexusPlatform platform;
  DeviceProfile? profile;
  RuntimeStatus? status;
  String? profileError;
  String? statusError;
  bool refreshing = false;
  bool _disposed = false;
  int _statusRevision = 0;
  late final StreamSubscription<RuntimeStatus> _statusSubscription;

  Future<void> refresh() async {
    if (_disposed || refreshing) return;
    refreshing = true;
    profileError = null;
    statusError = null;
    notifyListeners();
    await Future.wait([_loadProfile(), _loadStatus()]);
    if (_disposed) return;
    refreshing = false;
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    try {
      final value = await platform.getDeviceProfile().timeout(
        const Duration(seconds: 10),
      );
      if (!_disposed) profile = value;
    } catch (_) {
      if (_disposed) return;
      profile = null;
      profileError = 'Could not read this device. Please try again.';
    }
  }

  Future<void> _loadStatus() async {
    final revision = _statusRevision;
    try {
      final value = await platform.getRuntimeStatus().timeout(
        const Duration(seconds: 10),
      );
      if (!_disposed && revision == _statusRevision) status = value;
    } catch (_) {
      if (_disposed || revision != _statusRevision) return;
      status = null;
      statusError = 'Could not read runtime status. Please try again.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_statusSubscription.cancel());
    super.dispose();
  }
}
