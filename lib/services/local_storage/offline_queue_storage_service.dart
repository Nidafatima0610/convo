import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/nearby/domain/models/queued_message.dart';

class OfflineQueueStorageService {
  OfflineQueueStorageService();

  static const String _fileName = 'convo_offline_queue.json';
  File? _fileCache;
  List<QueuedMessage> _inMemoryQueue = [];
  bool _isLoaded = false;

  final _queueStreamController =
      StreamController<List<QueuedMessage>>.broadcast();

  Stream<List<QueuedMessage>> get queueStream async* {
    if (!_isLoaded) {
      await loadQueue();
    }
    yield List.unmodifiable(_inMemoryQueue);
    yield* _queueStreamController.stream;
  }

  List<QueuedMessage> get currentQueue => List.unmodifiable(_inMemoryQueue);

  Future<File> _getFile() async {
    if (_fileCache != null) return _fileCache!;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _fileCache = File('${dir.path}/$_fileName');
      return _fileCache!;
    } catch (e) {
      debugPrint('Notice getting application documents directory: $e');
      final tempDir = Directory.systemTemp;
      _fileCache = File('${tempDir.path}/$_fileName');
      return _fileCache!;
    }
  }

  /// Loads queued messages from persistent disk storage.
  Future<List<QueuedMessage>> loadQueue() async {
    if (_isLoaded) return _inMemoryQueue;

    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            _inMemoryQueue = decoded
                .map(
                  (e) => QueuedMessage.fromMap(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading offline queue from file: $e');
      _inMemoryQueue = [];
    }

    _isLoaded = true;
    _queueStreamController.add(List.unmodifiable(_inMemoryQueue));
    return _inMemoryQueue;
  }

  /// Persists the current in-memory queue to disk.
  Future<void> _persistQueue() async {
    try {
      final file = await _getFile();
      final data = _inMemoryQueue.map((m) => m.toMap()).toList();
      final content = jsonEncode(data);
      await file.writeAsString(content, flush: true);
    } catch (e) {
      debugPrint('Error persisting offline queue to file: $e');
    }
    _queueStreamController.add(List.unmodifiable(_inMemoryQueue));
  }

  /// Adds a message to the persistent queue.
  Future<void> enqueueMessage(QueuedMessage message) async {
    await loadQueue();
    // Prevent duplicate entries
    final index = _inMemoryQueue.indexWhere(
      (m) => m.localMessageId == message.localMessageId,
    );
    if (index >= 0) {
      _inMemoryQueue[index] = message;
    } else {
      _inMemoryQueue.add(message);
    }
    await _persistQueue();
  }

  /// Updates an existing queued message's delivery status.
  Future<void> updateMessageState(
    String localMessageId,
    DeliveryState newState,
  ) async {
    await loadQueue();
    final index = _inMemoryQueue.indexWhere(
      (m) => m.localMessageId == localMessageId,
    );
    if (index >= 0) {
      _inMemoryQueue[index] = _inMemoryQueue[index].copyWith(
        deliveryState: newState,
      );
      await _persistQueue();
    }
  }

  /// Removes a synced or discarded message from the queue.
  Future<void> removeMessage(String localMessageId) async {
    await loadQueue();
    _inMemoryQueue.removeWhere((m) => m.localMessageId == localMessageId);
    await _persistQueue();
  }

  /// Clears the entire offline queue.
  Future<void> clearQueue() async {
    _inMemoryQueue.clear();
    await _persistQueue();
  }

  /// Disposes stream controller.
  void dispose() {
    _queueStreamController.close();
  }
}
