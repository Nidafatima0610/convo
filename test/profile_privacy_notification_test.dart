import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:convo/core/utils/date_formatter.dart';
import 'package:convo/features/auth/domain/models/convo_user.dart';
import 'package:convo/features/profile/domain/privacy_helper.dart';
import 'package:convo/services/notifications/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConvoUser Profile, Privacy & Settings Model Tests', () {
    test('ConvoUser serializes and deserializes all profile & privacy fields', () {
      final now = DateTime.now();
      final user = ConvoUser(
        uid: 'user_123',
        name: 'Ahmed Khan',
        email: 'ahmed@example.com',
        photoUrl: 'https://storage.googleapis.com/convo/users/user_123/profile/dp.jpg',
        bio: 'Building peer mesh tech!',
        lastSeen: now,
        fcmToken: 'fcm_token_sample_abc123',
        blockedUsers: ['bad_actor_999'],
        privacySettings: {
          'lastSeen': 'contacts',
          'online': 'everyone',
          'photo': 'contacts',
          'bio': 'nobody',
        },
        notificationSettings: {
          'enabled': true,
          'preview': false,
          'sound': true,
        },
        createdAt: now,
        updatedAt: now,
        isOnline: true,
      );

      final map = user.toMap();
      expect(map['uid'], 'user_123');
      expect(map['name'], 'Ahmed Khan');
      expect(map['email'], 'ahmed@example.com');
      expect(map['photoUrl'], contains('user_123/profile/dp.jpg'));
      expect(map['bio'], 'Building peer mesh tech!');
      expect(map['fcmToken'], 'fcm_token_sample_abc123');
      expect(map['blockedUsers'], contains('bad_actor_999'));
      expect(map['lastSeen'], isA<Timestamp>());
      expect(map['privacySettings']['lastSeen'], 'contacts');
      expect(map['notificationSettings']['preview'], false);

      final fromMapUser = ConvoUser.fromMap(map, docId: 'user_123');
      expect(fromMapUser.uid, 'user_123');
      expect(fromMapUser.name, 'Ahmed Khan');
      expect(fromMapUser.effectiveBio, 'Building peer mesh tech!');
      expect(fromMapUser.lastSeenPrivacy, 'contacts');
      expect(fromMapUser.onlinePrivacy, 'everyone');
      expect(fromMapUser.photoPrivacy, 'contacts');
      expect(fromMapUser.bioPrivacy, 'nobody');
      expect(fromMapUser.notificationsEnabled, true);
      expect(fromMapUser.notificationPreviewsEnabled, false);
      expect(fromMapUser.notificationSoundEnabled, true);
      expect(fromMapUser.isUserBlocked('bad_actor_999'), isTrue);
      expect(fromMapUser.isUserBlocked('good_peer'), isFalse);
    });

    test('ConvoUser defaults provide safe fallbacks for missing Firestore fields', () {
      final minimalMap = <String, dynamic>{
        'uid': 'user_new',
        'name': 'Newbie',
        'email': 'newbie@convo.app',
      };

      final user = ConvoUser.fromMap(minimalMap);
      expect(user.uid, 'user_new');
      expect(user.effectiveBio, 'Hey there! I am using CONVO.');
      expect(user.photoUrl, isNull);
      expect(user.lastSeen, isNull);
      expect(user.blockedUsers, isEmpty);
      expect(user.lastSeenPrivacy, 'everyone');
      expect(user.onlinePrivacy, 'everyone');
      expect(user.photoPrivacy, 'everyone');
      expect(user.bioPrivacy, 'everyone');
      expect(user.notificationsEnabled, isTrue);
      expect(user.notificationPreviewsEnabled, isTrue);
    });
  });

  group('PrivacyHelper Access Control Tests', () {
    late ConvoUser ownerUser;

    setUp(() {
      final now = DateTime.now();
      ownerUser = ConvoUser(
        uid: 'target_owner',
        name: 'Target Owner',
        email: 'target@convo.app',
        photoUrl: 'https://example.com/target.jpg',
        bio: 'Private target bio',
        lastSeen: now,
        blockedUsers: ['blocked_villain'],
        privacySettings: {
          'lastSeen': 'contacts',
          'online': 'nobody',
          'photo': 'contacts',
          'bio': 'everyone',
        },
        createdAt: now,
        updatedAt: now,
        isOnline: true,
      );
    });

    test('Viewer viewing own profile always has complete visibility', () {
      expect(
        PrivacyHelper.canViewPhoto(targetUser: ownerUser, viewerUserId: 'target_owner'),
        isTrue,
      );
      expect(
        PrivacyHelper.canViewBio(targetUser: ownerUser, viewerUserId: 'target_owner'),
        isTrue,
      );
      expect(
        PrivacyHelper.canViewOnline(targetUser: ownerUser, viewerUserId: 'target_owner'),
        isTrue,
      );
      expect(
        PrivacyHelper.canViewLastSeen(targetUser: ownerUser, viewerUserId: 'target_owner'),
        isTrue,
      );
    });

    test('Blocked user has zero visibility into target profile regardless of settings', () {
      expect(
        PrivacyHelper.canViewPhoto(
          targetUser: ownerUser,
          viewerUserId: 'blocked_villain',
          hasConversation: true,
        ),
        isFalse,
      );
      expect(
        PrivacyHelper.canViewBio(
          targetUser: ownerUser,
          viewerUserId: 'blocked_villain',
          hasConversation: true,
        ),
        isFalse,
      );
      expect(
        PrivacyHelper.canViewOnline(
          targetUser: ownerUser,
          viewerUserId: 'blocked_villain',
          hasConversation: true,
        ),
        isFalse,
      );
      expect(
        PrivacyHelper.canViewLastSeen(
          targetUser: ownerUser,
          viewerUserId: 'blocked_villain',
          hasConversation: true,
        ),
        isFalse,
      );
    });

    test('Contact with active conversation respects "contacts" privacy rule', () {
      // Photo is 'contacts'
      expect(
        PrivacyHelper.canViewPhoto(
          targetUser: ownerUser,
          viewerUserId: 'chat_partner',
          hasConversation: true,
        ),
        isTrue,
      );
      // Photo for stranger with no conversation is hidden
      expect(
        PrivacyHelper.canViewPhoto(
          targetUser: ownerUser,
          viewerUserId: 'random_stranger',
          hasConversation: false,
        ),
        isFalse,
      );

      // Bio is 'everyone'
      expect(
        PrivacyHelper.canViewBio(
          targetUser: ownerUser,
          viewerUserId: 'random_stranger',
          hasConversation: false,
        ),
        isTrue,
      );

      // Online is 'nobody'
      expect(
        PrivacyHelper.canViewOnline(
          targetUser: ownerUser,
          viewerUserId: 'chat_partner',
          hasConversation: true,
        ),
        isFalse,
      );
    });
  });

  group('FCM Notification Formatting & Previews Tests', () {
    test('Notification previews format standard and media messages correctly', () {
      expect(
        NotificationService.formatMessagePreview(
          senderName: 'Ahmed',
          type: 'text',
          text: 'Hey, are you free?',
          includePreview: true,
        ),
        'Hey, are you free?',
      );

      expect(
        NotificationService.formatMessagePreview(
          senderName: 'Ahmed',
          type: 'image',
          text: '',
          includePreview: true,
        ),
        'Ahmed sent a photo',
      );

      expect(
        NotificationService.formatMessagePreview(
          senderName: 'Ahmed',
          type: 'voice',
          text: '',
          includePreview: true,
        ),
        'Ahmed sent a voice message',
      );

      expect(
        NotificationService.formatMessagePreview(
          senderName: 'Ahmed',
          type: 'video',
          text: '',
          includePreview: true,
        ),
        'Ahmed sent a video',
      );

      expect(
        NotificationService.formatMessagePreview(
          senderName: 'Ahmed',
          type: 'file',
          text: '',
          includePreview: true,
        ),
        'Ahmed sent a file',
      );
    });

    test('Notification previews redact sensitive content when preview setting is disabled', () {
      expect(
        NotificationService.formatMessagePreview(
          senderName: 'Ahmed',
          type: 'text',
          text: 'Confidential project details',
          includePreview: false,
        ),
        'New message from Ahmed',
      );

      expect(
        NotificationService.formatMessagePreview(
          senderName: 'Ahmed',
          type: 'image',
          text: '',
          includePreview: false,
        ),
        'New message from Ahmed',
      );
    });
  });

  group('DateFormatter Relative Timestamp Tests', () {
    test('formatTimeAgo computes clean human-readable relative time', () {
      final now = DateTime.now();

      final justNow = now.subtract(const Duration(seconds: 15));
      expect(DateFormatter.formatTimeAgo(justNow), 'just now');

      final fiveMinAgo = now.subtract(const Duration(minutes: 5));
      expect(DateFormatter.formatTimeAgo(fiveMinAgo), '5m ago');

      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      expect(DateFormatter.formatTimeAgo(twoHoursAgo), '2h ago');
    });
  });
}
