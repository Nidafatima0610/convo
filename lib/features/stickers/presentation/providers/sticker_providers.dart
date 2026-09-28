import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sticker_storage_service.dart';
import '../../domain/models/sticker_model.dart';

final stickerStorageServiceProvider = Provider<StickerStorageService>((ref) {
  final service = StickerStorageService();
  ref.onDispose(service.dispose);
  return service;
});

final myStickersStreamProvider = StreamProvider<List<StickerModel>>((ref) {
  final storage = ref.watch(stickerStorageServiceProvider);
  return storage.myStickersStream;
});

final recentStickersStreamProvider = StreamProvider<List<StickerModel>>((ref) {
  final storage = ref.watch(stickerStorageServiceProvider);
  return storage.recentStickersStream;
});

final starterStickersProvider = Provider<List<StickerModel>>((ref) {
  final storage = ref.watch(stickerStorageServiceProvider);
  return storage.starterPacks;
});
