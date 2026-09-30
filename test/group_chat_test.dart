import 'package:convo/features/chats/domain/models/conversation_model.dart';
import 'package:convo/features/chats/domain/models/message_model.dart';
import 'package:convo/services/notifications/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  group('ConversationModel Group Chat Tests', () {
    test('ConversationModel correctly identifies direct vs group chats', () {
      final directConv = ConversationModel(
        id: 'direct_1',
        participants: ['user_a', 'user_b'],
        participantDetails: {
          'user_a': {'name': 'User A'},
          'user_b': {'name': 'User B'},
        },
        lastMessageAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final groupConv = ConversationModel(
        id: 'group_1',
        type: 'group',
        name: 'Flutter Engineers',
        description: 'Building CONVO together',
        photoUrl: 'https://storage.googleapis.com/group_dp.jpg',
        createdBy: 'user_a',
        admins: ['user_a'],
        participants: ['user_a', 'user_b', 'user_c'],
        participantDetails: {
          'user_a': {'name': 'User A'},
          'user_b': {'name': 'User B'},
          'user_c': {'name': 'User C'},
        },
        lastMessageAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(directConv.isGroup, isFalse);
      expect(groupConv.isGroup, isTrue);
      expect(groupConv.name, 'Flutter Engineers');
      expect(groupConv.description, 'Building CONVO together');
      expect(groupConv.photoUrl, contains('group_dp.jpg'));
      expect(groupConv.createdBy, 'user_a');
      expect(groupConv.admins, contains('user_a'));
      expect(groupConv.participants.length, 3);
    });

    test('ConversationModel handles admin role checks correctly', () {
      final groupConv = ConversationModel(
        id: 'group_2',
        type: 'group',
        name: 'Core Team',
        createdBy: 'admin_1',
        admins: ['admin_1', 'admin_2'],
        participants: ['admin_1', 'admin_2', 'member_3'],
        participantDetails: {},
        lastMessageAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(groupConv.isAdmin('admin_1'), isTrue);
      expect(groupConv.isAdmin('admin_2'), isTrue);
      expect(groupConv.isAdmin('member_3'), isFalse);
      expect(groupConv.isAdmin('unknown_user'), isFalse);
    });

    test('ConversationModel handles mute status correctly', () {
      final groupConv = ConversationModel(
        id: 'group_3',
        type: 'group',
        name: 'Alerts',
        mutedBy: ['quiet_user'],
        participants: ['quiet_user', 'loud_user'],
        participantDetails: {},
        lastMessageAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(groupConv.isMutedFor('quiet_user'), isTrue);
      expect(groupConv.isMutedFor('loud_user'), isFalse);
    });

    test('ConversationModel serializes toMap and deserializes fromMap with group metadata', () {
      final groupConv = ConversationModel(
        id: 'group_roundtrip',
        type: 'group',
        name: 'CONVO Developers',
        description: 'Discussion and PR reviews',
        photoUrl: 'https://example.com/convo_group.png',
        createdBy: 'creator_uid',
        admins: ['creator_uid', 'co_admin_uid'],
        mutedBy: ['member_muted'],
        participants: ['creator_uid', 'co_admin_uid', 'member_muted'],
        participantDetails: {
          'creator_uid': {
            'name': 'Ali Raza',
            'email': 'ali@convo.app',
            'photoUrl': 'https://example.com/ali.png',
          },
          'co_admin_uid': {
            'name': 'Sarah Smith',
            'email': 'sarah@convo.app',
          },
        },
        unreadCounts: {'member_muted': 5},
        lastMessage: 'Let us deploy!',
        lastMessageSenderId: 'creator_uid',
        lastMessageAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final map = groupConv.toMap();
      expect(map['type'], 'group');
      expect(map['name'], 'CONVO Developers');
      expect(map['description'], 'Discussion and PR reviews');
      expect(map['photoUrl'], 'https://example.com/convo_group.png');
      expect(map['createdBy'], 'creator_uid');
      expect(map['admins'], containsAll(['creator_uid', 'co_admin_uid']));
      expect(map['mutedBy'], contains('member_muted'));
      expect(map['participants'].length, 3);
      expect(map['lastMessage'], 'Let us deploy!');

      final restored = ConversationModel.fromMap(map, docId: 'group_roundtrip');
      expect(restored.id, 'group_roundtrip');
      expect(restored.isGroup, isTrue);
      expect(restored.name, 'CONVO Developers');
      expect(restored.description, 'Discussion and PR reviews');
      expect(restored.photoUrl, 'https://example.com/convo_group.png');
      expect(restored.createdBy, 'creator_uid');
      expect(restored.isAdmin('creator_uid'), isTrue);
      expect(restored.isAdmin('co_admin_uid'), isTrue);
      expect(restored.isAdmin('member_muted'), isFalse);
      expect(restored.isMutedFor('member_muted'), isTrue);
      expect(restored.isMutedFor('creator_uid'), isFalse);
      expect(restored.memberName('creator_uid'), 'Ali Raza');
      expect(restored.memberPhoto('creator_uid'), 'https://example.com/ali.png');
      expect(restored.memberEmail('co_admin_uid'), 'sarah@convo.app');
      expect(restored.unreadCountFor('member_muted'), 5);
    });

    test('ConversationModel copyWith updates group metadata cleanly', () {
      final initial = ConversationModel(
        id: 'group_copy',
        type: 'group',
        name: 'Old Name',
        admins: ['admin_1'],
        participants: ['admin_1', 'user_2'],
        participantDetails: {},
        lastMessageAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final updated = initial.copyWith(
        name: 'New Name',
        photoUrl: 'https://example.com/new.png',
        admins: ['admin_1', 'user_2'],
        participants: ['admin_1', 'user_2', 'user_3'],
      );

      expect(updated.name, 'New Name');
      expect(updated.photoUrl, 'https://example.com/new.png');
      expect(updated.admins.length, 2);
      expect(updated.participants.length, 3);
      expect(updated.id, 'group_copy');
      expect(updated.isGroup, isTrue);
    });
  });

  group('MessageModel Group Sender Tests', () {
    test('MessageModel retains senderName and senderPhotoUrl for group chat bubbles', () {
      final msg = MessageModel(
        id: 'msg_101',
        conversationId: 'group_test_1',
        senderId: 'member_ali',
        senderName: 'Ali Raza',
        senderPhotoUrl: 'https://example.com/ali_dp.jpg',
        receiverId: 'group',
        text: 'Hello everyone in the group!',
        createdAt: now,
      );

      expect(msg.senderName, 'Ali Raza');
      expect(msg.senderPhotoUrl, 'https://example.com/ali_dp.jpg');

      final map = msg.toMap();
      expect(map['senderName'], 'Ali Raza');
      expect(map['senderPhotoUrl'], 'https://example.com/ali_dp.jpg');

      final restored = MessageModel.fromMap(map, docId: 'msg_101');
      expect(restored.senderName, 'Ali Raza');
      expect(restored.senderPhotoUrl, 'https://example.com/ali_dp.jpg');
      expect(restored.text, 'Hello everyone in the group!');
    });

    test('MessageModel copyWith preserves and modifies sender details', () {
      final msg = MessageModel(
        id: 'msg_102',
        conversationId: 'group_test_1',
        senderId: 'user_x',
        senderName: 'User X',
        receiverId: 'group',
        text: 'Draft text',
        createdAt: now,
      );

      final copied = msg.copyWith(
        text: 'Published text',
        senderPhotoUrl: 'https://example.com/dp.jpg',
      );

      expect(copied.text, 'Published text');
      expect(copied.senderName, 'User X');
      expect(copied.senderPhotoUrl, 'https://example.com/dp.jpg');
    });
  });

  group('Group Notification Preview Tests', () {
    test('formatGroupMessageNotification produces correct format for text messages', () {
      final preview = NotificationService.formatGroupMessageNotification(
        groupName: 'CONVO Developers',
        senderName: 'Ali',
        type: 'text',
        text: 'Hey everyone',
        includePreview: true,
      );

      expect(preview.title, 'CONVO Developers');
      expect(preview.body, 'Ali: Hey everyone');
    });

    test('formatGroupMessageNotification handles various media types cleanly', () {
      final photoPreview = NotificationService.formatGroupMessageNotification(
        groupName: 'Trip to Northern Areas',
        senderName: 'Fatima',
        type: 'image',
        includePreview: true,
      );
      expect(photoPreview.title, 'Trip to Northern Areas');
      expect(photoPreview.body, 'Fatima sent a photo');

      final videoPreview = NotificationService.formatGroupMessageNotification(
        groupName: 'Trip to Northern Areas',
        senderName: 'Fatima',
        type: 'video',
        includePreview: true,
      );
      expect(videoPreview.body, 'Fatima sent a video');

      final voicePreview = NotificationService.formatGroupMessageNotification(
        groupName: 'Project Team',
        senderName: 'Usman',
        type: 'voice',
        includePreview: true,
      );
      expect(voicePreview.body, 'Usman sent a voice message');

      final filePreview = NotificationService.formatGroupMessageNotification(
        groupName: 'Project Team',
        senderName: 'Usman',
        type: 'file',
        includePreview: true,
      );
      expect(filePreview.body, 'Usman sent a file');

      final stickerPreview = NotificationService.formatGroupMessageNotification(
        groupName: 'Friends',
        senderName: 'Zain',
        type: 'sticker',
        includePreview: true,
      );
      expect(stickerPreview.body, 'Zain sent a sticker');
    });

    test('formatGroupMessageNotification respects privacy setting when previews disabled', () {
      final privacyPreview = NotificationService.formatGroupMessageNotification(
        groupName: 'Secret Project',
        senderName: 'Boss',
        type: 'text',
        text: 'Confidential message',
        includePreview: false,
      );

      expect(privacyPreview.title, 'Secret Project');
      expect(privacyPreview.body, 'New message');
    });
  });

  group('Sole Admin Reassignment Safety Simulation', () {
    test('Leaving group reassigns sole admin role to the first remaining member', () {
      // Simulation of the exact logic in ChatService.leaveGroup:
      final group = ConversationModel(
        id: 'group_leave_test',
        type: 'group',
        name: 'Startup Founders',
        createdBy: 'founder_1',
        admins: ['founder_1'],
        participants: ['founder_1', 'member_2', 'member_3'],
        participantDetails: {},
        lastMessageAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final leavingUserId = 'founder_1';
      final updatedParticipants = List<String>.from(group.participants)
        ..remove(leavingUserId);
      final updatedAdmins = List<String>.from(group.admins)
        ..remove(leavingUserId);

      // Sole admin safe fallback:
      if (updatedAdmins.isEmpty && updatedParticipants.isNotEmpty) {
        updatedAdmins.add(updatedParticipants.first);
      }

      expect(updatedParticipants, ['member_2', 'member_3']);
      expect(updatedAdmins, ['member_2']);
      expect(updatedAdmins.contains('member_2'), isTrue);
      // Group is NOT left orphaned!
    });

    test('Leaving group preserves remaining admin when another admin exists', () {
      final group = ConversationModel(
        id: 'group_multi_admin',
        type: 'group',
        name: 'Active Commits',
        createdBy: 'admin_1',
        admins: ['admin_1', 'admin_2'],
        participants: ['admin_1', 'admin_2', 'member_3'],
        participantDetails: {},
        lastMessageAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final leavingUserId = 'admin_1';
      final updatedParticipants = List<String>.from(group.participants)
        ..remove(leavingUserId);
      final updatedAdmins = List<String>.from(group.admins)
        ..remove(leavingUserId);

      if (updatedAdmins.isEmpty && updatedParticipants.isNotEmpty) {
        updatedAdmins.add(updatedParticipants.first);
      }

      expect(updatedParticipants, ['admin_2', 'member_3']);
      expect(updatedAdmins, ['admin_2']);
      expect(updatedAdmins.contains('member_3'), isFalse);
    });
  });

  group('Group System Messages and Forwarding Tests', () {
    test('System message creates valid model with correct type and text', () {
      final systemMsg = MessageModel(
        id: 'sys_101',
        conversationId: 'group_test_sys',
        senderId: 'admin_1',
        receiverId: 'group',
        text: 'Ali Raza created group "Flutter Engineers"',
        type: 'system',
        senderName: 'Ali Raza',
        createdAt: now,
      );

      expect(systemMsg.type, 'system');
      expect(systemMsg.text, contains('Flutter Engineers'));
      expect(systemMsg.receiverId, 'group');

      final map = systemMsg.toMap();
      expect(map['type'], 'system');
      expect(map['text'], 'Ali Raza created group "Flutter Engineers"');

      final restored = MessageModel.fromMap(map, docId: 'sys_101');
      expect(restored.type, 'system');
      expect(restored.text, 'Ali Raza created group "Flutter Engineers"');
      expect(restored.senderName, 'Ali Raza');
    });

    test('Forwarded message preserves metadata flag across serialization', () {
      final forwardedMsg = MessageModel(
        id: 'fwd_202',
        conversationId: 'group_dest_1',
        senderId: 'forwarder_uid',
        receiverId: 'group',
        text: 'Important project update forwarded here',
        type: 'text',
        metadata: {'isForwarded': true},
        createdAt: now,
      );

      expect(forwardedMsg.metadata?['isForwarded'], isTrue);

      final map = forwardedMsg.toMap();
      expect(map['metadata']?['isForwarded'], isTrue);

      final restored = MessageModel.fromMap(map, docId: 'fwd_202');
      expect(restored.metadata?['isForwarded'], isTrue);
      expect(restored.text, 'Important project update forwarded here');
    });

    test('Adding and removing members correctly updates participant list and details', () {
      final initialConv = ConversationModel(
        id: 'group_mem_test',
        type: 'group',
        name: 'Sprint Team',
        createdBy: 'admin_1',
        admins: ['admin_1'],
        participants: ['admin_1', 'member_2'],
        participantDetails: {
          'admin_1': {'name': 'Admin 1'},
          'member_2': {'name': 'Member 2'},
        },
        lastMessageAt: now,
        createdAt: now,
        updatedAt: now,
      );

      // Simulate adding member_3
      final newMemberDetails = <String, Map<String, dynamic>>{
        'member_3': {'name': 'Member 3', 'email': 'm3@convo.app'},
      };
      final afterAdd = initialConv.copyWith(
        participants: [...initialConv.participants, 'member_3'],
        participantDetails: {
          ...initialConv.participantDetails,
          ...newMemberDetails,
        },
      );

      expect(afterAdd.participants.length, 3);
      expect(afterAdd.participants, contains('member_3'));
      expect(afterAdd.memberName('member_3'), 'Member 3');
      expect(afterAdd.memberEmail('member_3'), 'm3@convo.app');

      // Simulate removing member_2
      final updatedDetails = Map<String, Map<String, dynamic>>.from(afterAdd.participantDetails)
        ..remove('member_2');
      final updatedParticipants = afterAdd.participants.where((id) => id != 'member_2').toList();
      final afterRemove = afterAdd.copyWith(
        participants: updatedParticipants,
        participantDetails: updatedDetails,
      );

      expect(afterRemove.participants.length, 2);
      expect(afterRemove.participants, isNot(contains('member_2')));
      expect(afterRemove.participantDetails.containsKey('member_2'), isFalse);
    });
  });
}

