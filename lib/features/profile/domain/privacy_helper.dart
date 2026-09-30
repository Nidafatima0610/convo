import '../../auth/domain/models/convo_user.dart';

class PrivacyHelper {
  const PrivacyHelper._();

  /// Determines whether [viewerUserId] can view the profile photo of [targetUser].
  static bool canViewPhoto({
    required ConvoUser targetUser,
    required String? viewerUserId,
    bool hasConversation = false,
  }) {
    if (viewerUserId == null || viewerUserId.isEmpty) return false;
    if (viewerUserId == targetUser.uid) return true;
    if (targetUser.isUserBlocked(viewerUserId)) return false;

    final privacy = targetUser.photoPrivacy;
    if (privacy == 'everyone') return true;
    if (privacy == 'contacts') return hasConversation;
    return false; // 'nobody'
  }

  /// Determines whether [viewerUserId] can view the bio of [targetUser].
  static bool canViewBio({
    required ConvoUser targetUser,
    required String? viewerUserId,
    bool hasConversation = false,
  }) {
    if (viewerUserId == null || viewerUserId.isEmpty) return false;
    if (viewerUserId == targetUser.uid) return true;
    if (targetUser.isUserBlocked(viewerUserId)) return false;

    final privacy = targetUser.bioPrivacy;
    if (privacy == 'everyone') return true;
    if (privacy == 'contacts') return hasConversation;
    return false; // 'nobody'
  }

  /// Determines whether [viewerUserId] can view the online status of [targetUser].
  static bool canViewOnline({
    required ConvoUser targetUser,
    required String? viewerUserId,
    bool hasConversation = false,
  }) {
    if (viewerUserId == null || viewerUserId.isEmpty) return false;
    if (viewerUserId == targetUser.uid) return true;
    if (targetUser.isUserBlocked(viewerUserId)) return false;

    final privacy = targetUser.onlinePrivacy;
    if (privacy == 'everyone') return true;
    if (privacy == 'contacts') return hasConversation;
    return false; // 'nobody'
  }

  /// Determines whether [viewerUserId] can view the last seen timestamp of [targetUser].
  static bool canViewLastSeen({
    required ConvoUser targetUser,
    required String? viewerUserId,
    bool hasConversation = false,
  }) {
    if (viewerUserId == null || viewerUserId.isEmpty) return false;
    if (viewerUserId == targetUser.uid) return true;
    if (targetUser.isUserBlocked(viewerUserId)) return false;

    final privacy = targetUser.lastSeenPrivacy;
    if (privacy == 'everyone') return true;
    if (privacy == 'contacts') return hasConversation;
    return false; // 'nobody'
  }
}
