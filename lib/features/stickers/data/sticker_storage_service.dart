import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models/sticker_model.dart';

class StickerStorageService {
  StickerStorageService();

  static const String _fileName = 'convo_custom_stickers.json';
  static const String _recentsFileName = 'convo_recent_stickers.json';

  File? _fileCache;
  File? _recentsFileCache;

  List<StickerModel> _myStickers = [];
  List<StickerModel> _recentStickers = [];
  bool _isLoaded = false;

  final _myStickersController =
      StreamController<List<StickerModel>>.broadcast();
  final _recentStickersController =
      StreamController<List<StickerModel>>.broadcast();

  Stream<List<StickerModel>> get myStickersStream async* {
    if (!_isLoaded) await loadStickers();
    yield List.unmodifiable(_myStickers);
    yield* _myStickersController.stream;
  }

  Stream<List<StickerModel>> get recentStickersStream async* {
    if (!_isLoaded) await loadStickers();
    yield List.unmodifiable(_recentStickers);
    yield* _recentStickersController.stream;
  }

  List<StickerModel> get currentMyStickers => List.unmodifiable(_myStickers);
  List<StickerModel> get currentRecentStickers =>
      List.unmodifiable(_recentStickers);

  /// Default built-in starter stickers for CONVO
  List<StickerModel> get starterPacks => [
    StickerModel(
      id: 'builtin_convo_pulse',
      creatorId: 'system',
      name: 'CONVO Pulse',
      imagePath: 'emoji:💜:CONVO Vibe',
      packId: 'pack_convo_official',
      packName: 'Official CONVO',
      emoji: '💜',
      createdAt: DateTime(2026, 1, 1),
      isBuiltIn: true,
    ),
    StickerModel(
      id: 'builtin_fire',
      creatorId: 'system',
      name: 'Lit / Fire',
      imagePath: 'emoji:🔥:Straight Fire',
      packId: 'pack_convo_official',
      packName: 'Official CONVO',
      emoji: '🔥',
      createdAt: DateTime(2026, 1, 1),
      isBuiltIn: true,
    ),
    StickerModel(
      id: 'builtin_radar',
      creatorId: 'system',
      name: 'Mesh Connected',
      imagePath: 'emoji:📡:In The Mesh',
      packId: 'pack_convo_official',
      packName: 'Official CONVO',
      emoji: '📡',
      createdAt: DateTime(2026, 1, 1),
      isBuiltIn: true,
    ),
    StickerModel(
      id: 'builtin_laugh',
      creatorId: 'system',
      name: 'Dead Laughing',
      imagePath: 'emoji:💀:Dead',
      packId: 'pack_convo_official',
      packName: 'Official CONVO',
      emoji: '💀',
      createdAt: DateTime(2026, 1, 1),
      isBuiltIn: true,
    ),
    StickerModel(
      id: 'builtin_rocket',
      creatorId: 'system',
      name: 'To The Moon',
      imagePath: 'emoji:🚀:Full Send',
      packId: 'pack_convo_official',
      packName: 'Official CONVO',
      emoji: '🚀',
      createdAt: DateTime(2026, 1, 1),
      isBuiltIn: true,
    ),
    StickerModel(
      id: 'builtin_offline',
      creatorId: 'system',
      name: 'Offline Mode',
      imagePath: 'emoji:📶:No Internet Needed',
      packId: 'pack_convo_official',
      packName: 'Official CONVO',
      emoji: '📶',
      createdAt: DateTime(2026, 1, 1),
      isBuiltIn: true,
    ),
  ];

  Future<File> _getFile() async {
    if (_fileCache != null) return _fileCache!;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _fileCache = File('${dir.path}/$_fileName');
      return _fileCache!;
    } catch (_) {
      final tempDir = Directory.systemTemp;
      _fileCache = File('${tempDir.path}/$_fileName');
      return _fileCache!;
    }
  }

  Future<File> _getRecentsFile() async {
    if (_recentsFileCache != null) return _recentsFileCache!;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _recentsFileCache = File('${dir.path}/$_recentsFileName');
      return _recentsFileCache!;
    } catch (_) {
      final tempDir = Directory.systemTemp;
      _recentsFileCache = File('${tempDir.path}/$_recentsFileName');
      return _recentsFileCache!;
    }
  }

  Future<void> loadStickers() async {
    if (_isLoaded) return;

    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            _myStickers = decoded
                .map(
                  (e) =>
                      StickerModel.fromMap(Map<String, dynamic>.from(e as Map)),
                )
                .toList();
          }
        }
      }

      final recentsFile = await _getRecentsFile();
      if (await recentsFile.exists()) {
        final content = await recentsFile.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            _recentStickers = decoded
                .map(
                  (e) =>
                      StickerModel.fromMap(Map<String, dynamic>.from(e as Map)),
                )
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Notice loading stickers: $e');
    }

    _isLoaded = true;
    _myStickersController.add(List.unmodifiable(_myStickers));
    _recentStickersController.add(List.unmodifiable(_recentStickers));
  }

  Future<void> saveCustomSticker(StickerModel sticker) async {
    await loadStickers();
    _myStickers.insert(0, sticker);
    await _persistStickers();
  }

  Future<void> deleteSticker(String stickerId) async {
    await loadStickers();
    _myStickers.removeWhere((s) => s.id == stickerId);
    _recentStickers.removeWhere((s) => s.id == stickerId);
    await _persistStickers();
    await _persistRecents();
  }

  Future<void> markStickerUsed(StickerModel sticker) async {
    await loadStickers();
    _recentStickers.removeWhere((s) => s.id == sticker.id);
    _recentStickers.insert(0, sticker);
    if (_recentStickers.length > 20) {
      _recentStickers = _recentStickers.sublist(0, 20);
    }
    await _persistRecents();
  }

  Future<void> _persistStickers() async {
    try {
      final file = await _getFile();
      final data = _myStickers.map((s) => s.toMap()).toList();
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Error persisting custom stickers: $e');
    }
    _myStickersController.add(List.unmodifiable(_myStickers));
  }

  Future<void> _persistRecents() async {
    try {
      final file = await _getRecentsFile();
      final data = _recentStickers.map((s) => s.toMap()).toList();
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Error persisting recent stickers: $e');
    }
    _recentStickersController.add(List.unmodifiable(_recentStickers));
  }

  void dispose() {
    _myStickersController.close();
    _recentStickersController.close();
  }
}
