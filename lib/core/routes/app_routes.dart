class AppRoutes {
  AppRoutes._();

  // Auth routes
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';

  // Authenticated app shell routes
  static const String chats = '/chats';
  static const String chat = '/chat/:conversationId';
  static const String nearby = '/nearby';
  static const String calls = '/calls';
  static const String discover = '/discover';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String profileSettings = '/profile/settings';

  // Calling routes
  static const String activeCall = '/call/active';
  static const String incomingCall = '/call/incoming';

  // Chat Magic routes
  static const String stickerStudio = '/stickers/studio';
  static const String capsules = '/capsules';
  static const String createGroup = '/create-group';
  static const String starredMessages = '/starred-messages';
  static const String archivedChats = '/chats/archived';
}
