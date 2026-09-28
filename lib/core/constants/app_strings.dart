class AppStrings {
  AppStrings._();

  // Common
  static const String appName = 'CONVO';
  static const String tagline = 'Stay Connected. Even Offline.';
  static const String comingSoon = 'Coming Soon';
  static const String search = 'Search';
  static const String cancel = 'Cancel';
  static const String done = 'Done';
  static const String save = 'Save';

  // Navigation Tabs
  static const String navChats = 'Chats';
  static const String navNearby = 'Nearby';
  static const String navCalls = 'Calls';
  static const String navDiscover = 'Discover';
  static const String navProfile = 'Profile';

  // Chats Screen
  static const String chatsTitle = 'Chats';
  static const String chatsEmptyTitle = 'Your conversations will appear here.';
  static const String chatsEmptySubtitle =
      'Connect with contacts online or discover people nearby without needing internet access.';
  static const String newChat = 'New Chat';
  static const String searchChatsHint = 'Search messages or people...';

  // Nearby Screen
  static const String nearbyTitle = 'Connect Nearby';
  static const String nearbySubtitle =
      'Message people around you, even without internet.';
  static const String enableNearby = 'Enable Nearby';
  static const String nearbyDisclaimer =
      'Nearby mesh network engine is currently in development. '
      'Upcoming versions will enable local Bluetooth Low Energy and Wi-Fi Direct peer discovery.';
  static const String meshFeatureP2PTitle = 'Direct Peer-to-Peer';
  static const String meshFeatureP2PDesc =
      'Forms ad-hoc mesh networks directly with surrounding CONVO devices.';
  static const String meshFeatureOfflineTitle = 'Zero Internet Required';
  static const String meshFeatureOfflineDesc =
      'Chat on flights, subways, remote trails, or during network blackouts.';
  static const String meshFeatureEncryptedTitle = 'End-to-End Encrypted';
  static const String meshFeatureEncryptedDesc =
      'Every packet relayed across peer devices is cryptographically secured.';

  // Calls Screen
  static const String callsTitle = 'Calls';
  static const String callsEmptyTitle =
      'Your voice and video calls will appear here.';
  static const String callsEmptySubtitle =
      'Reach friends with encrypted HD audio and video calling.';
  static const String newCall = 'New Call';

  // Discover Screen
  static const String discoverTitle = 'Discover';
  static const String discoverSubtitle =
      'Explore stickers, moods, games, and voice effects.';
  static const String stickerStudioTitle = 'Sticker Studio';
  static const String stickerStudioDesc =
      'Create, edit, and share custom animated sticker packs.';
  static const String chatMoodsTitle = 'Chat Moods';
  static const String chatMoodsDesc =
      'Ambient lighting and dynamic themes reflecting your current state.';
  static const String chatGamesTitle = 'Chat Games';
  static const String chatGamesDesc =
      'Lightweight multiplayer games to play right in your conversation.';
  static const String voiceEffectsTitle = 'Voice Effects';
  static const String voiceEffectsDesc =
      'Studio-grade modulation and spatial filters for voice notes.';
  static const String messageCapsulesTitle = 'Message Capsules';
  static const String messageCapsulesDesc =
      'Time-locked messages that unlock at a future moment or location.';

  // Profile Screen
  static const String profileTitle = 'Your Profile';
  static const String profileSubtitle =
      'Your CONVO identity and device status.';
  static const String editProfile = 'Edit Profile';
  static const String shareProfile = 'Share QR';
  static const String settings = 'Settings';
  static const String defaultUserDisplayName = 'Alex Rivera';
  static const String defaultUserHandle = '@alex.convo';
  static const String defaultMeshAddress = 'convo:mesh:7f8a9b';
  static const String nodeStatusReady = 'Mesh Node Ready';

  // Settings Screen
  static const String settingsTitle = 'Settings';
  static const String appearance = 'Appearance';
  static const String appearanceDesc = 'App theme, dark mode, accent colors';
  static const String notifications = 'Notifications';
  static const String notificationsDesc = 'Message alerts, sound, vibration';
  static const String privacy = 'Privacy';
  static const String privacyDesc = 'Read receipts, last seen, mesh visibility';
  static const String security = 'Security';
  static const String securityDesc =
      'Screen lock, biometric auth, encryption keys';
  static const String about = 'About CONVO';
  static const String aboutDesc =
      'App version, open-source licenses, mesh protocol';
}
