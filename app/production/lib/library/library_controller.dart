import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../platform/nexus_api.g.dart';

/// UI state only. Android owns import IO, persistence, and cancellation outcomes.
class LibraryController extends ChangeNotifier {
  LibraryController(this.api);
  final NexusLibraryApi api;
  static const pageSize = 50;
  List<GameRecord> games = [];
  int total = 0;
  int offset = 0;
  String query = '';
  String? error;
  bool loading = false;
  bool initialized = false;
  ImportProgress? progress;
  bool starting = false;
  bool cancelling = false;
  bool _disposed = false;
  bool _syncing = false;
  int _readGeneration = 0;
  int _jobGeneration = 0;
  Timer? _poll;
  Timer? _search;

  bool get importing => switch (progress?.state) {
    ImportState.choosing ||
    ImportState.copying ||
    ImportState.committing => true,
    _ => false,
  };
  bool get busy => starting || importing;
  bool get canImport => !busy && progress?.code != 'cleanup_pending';
  bool get canCancel =>
      !cancelling &&
      switch (progress?.state) {
        ImportState.choosing || ImportState.copying => true,
        _ => false,
      };
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> synchronize({bool reload = false}) async {
    if (_disposed || _syncing || starting) return;
    _poll?.cancel();
    _syncing = true;
    final generation = _jobGeneration;
    ImportProgress snapshot;
    try {
      snapshot = await api.getImportProgress();
    } catch (failure) {
      if (!_disposed && generation == _jobGeneration) {
        error = libraryFailure(failure);
        _changed();
      }
      return;
    } finally {
      _syncing = false;
      _schedule();
    }
    if (_disposed || generation != _jobGeneration) {
      _schedule();
      return;
    }
    final completed =
        snapshot.state == ImportState.completed &&
        (progress?.jobId != snapshot.jobId ||
            progress?.state != ImportState.completed);
    final retry = error != null;
    progress = snapshot;
    error = null;
    if (importing) {
      _readGeneration++;
      loading = false;
    }
    _changed();
    _schedule();
    if (!busy && (reload || !initialized || completed || retry)) {
      await load(pageOffset: completed ? 0 : offset);
    }
  }

  Future<void> load({int? pageOffset}) async {
    if (_disposed || busy) return;
    _search?.cancel();
    if (pageOffset != null && pageOffset != offset) {
      offset = pageOffset;
      games = [];
    }
    final generation = ++_readGeneration;
    loading = true;
    error = null;
    _changed();
    try {
      final result = await api.listGames(offset, pageSize, query);
      if (_disposed || generation != _readGeneration || busy) return;
      games = result.games;
      total = result.total;
      initialized = true;
      // A removal can make the last page empty; return to the last valid page.
      if (offset > 0 && games.isEmpty) {
        final last = total == 0 ? 0 : ((total - 1) ~/ pageSize) * pageSize;
        await load(pageOffset: last >= offset ? 0 : last);
      }
    } catch (failure) {
      if (!_disposed && generation == _readGeneration) {
        error = libraryFailure(failure);
      }
    } finally {
      if (!_disposed && generation == _readGeneration) {
        loading = false;
        _changed();
      }
    }
  }

  void search(String value) {
    if (_disposed || busy || value == query) return;
    _search?.cancel();
    _readGeneration++;
    query = value;
    offset = 0;
    games = [];
    initialized = false;
    loading = true;
    error = null;
    _changed();
    _search = Timer(const Duration(milliseconds: 300), () => unawaited(load()));
  }

  Future<void> begin(ImportKind kind) async {
    if (_disposed || !canImport) return;
    _jobGeneration++;
    _readGeneration++;
    _poll?.cancel();
    _search?.cancel();
    starting = true;
    cancelling = false;
    loading = false;
    progress = null;
    error = null;
    _changed();
    try {
      final snapshot = await api.beginImport(kind);
      if (!_disposed) progress = snapshot;
    } catch (failure) {
      if (!_disposed) error = libraryFailure(failure);
    } finally {
      if (!_disposed) {
        starting = false;
        _changed();
        _schedule();
      }
    }
  }

  Future<void> cancel() async {
    final id = progress?.jobId;
    if (_disposed || !canCancel || id == null) return;
    final generation = _jobGeneration;
    cancelling = true;
    _changed();
    try {
      await api.cancelImport(id);
      if (!_disposed && generation == _jobGeneration) await synchronize();
    } catch (failure) {
      if (!_disposed && generation == _jobGeneration) {
        error = libraryFailure(failure);
      }
    } finally {
      if (!_disposed && generation == _jobGeneration) {
        cancelling = false;
        _changed();
      }
    }
  }

  void _schedule() {
    _poll?.cancel();
    if (!_disposed && importing && error == null) {
      _poll = Timer(
        const Duration(milliseconds: 500),
        () => unawaited(synchronize()),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _readGeneration++;
    _jobGeneration++;
    _poll?.cancel();
    _search?.cancel();
    // Closing a screen must not silently cancel an Android-owned import.
    super.dispose();
  }
}

String libraryFailure(Object failure) =>
    failure is PlatformException &&
        failure.code != 'channel-error' &&
        failure.message?.isNotEmpty == true
    ? failure.message!
    : 'Could not access the local library. Retry or restart Nexus-PC.';
