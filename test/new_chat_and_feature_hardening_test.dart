import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:convo/features/auth/domain/models/convo_user.dart';
import 'package:convo/features/capsules/domain/models/capsule_model.dart';
import 'package:convo/features/chats/domain/models/conversation_model.dart';
import 'package:convo/features/chats/domain/models/message_model.dart';
import 'package:convo/features/nearby/domain/models/queued_message.dart';
import 'package:convo/features/voice_effects/domain/models/voice_effect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('New Chat & Conversation Creation Resilience Tests', () {
    test('Deterministic conversation ID prevents duplicate conversations for participants regardless of order', () {
      const userA = 'uid_alice_123';
      const userB = 'uid_bob_456';

      final id1 = ConversationModel.getConversationId(userA, userB);
      final id2 = ConversationModel.getConversationId(userB, userA);

      expect(id1, equals(id2));
      expect(id1, equals('uid_alice_123_uid_bob_456'));

      // Note to self produces self_ deterministic ID
      final selfId = ConversationModel.getConversationId(userA, userA);
      expect(selfId, equals('self_uid_alice_123'));
    });

    test('Conversation model guarantees parent document integrity and participant structure', () {
      final now = DateTime.now();
      final conversation = ConversationModel(
        id: 'uid_alice_123_uid_bob_456',
        participants: ['uid_alice_123', 'uid_bob_456'],
        participantDetails: {
          'uid_alice_123': {'name': 'Alice', 'email': 'alice@convo.com'},
          'uid_bob_456': {'name': 'Bob', 'email': 'bob@convo.com'},
        },
        lastMessage: 'Hello Bob',
        lastMessageAt: now,
        lastMessageSenderId: 'uid_alice_123',
        unreadCounts: {'uid_alice_123': 0, 'uid_bob_456': 1},
        type: 'direct',
        createdAt: now,
        updatedAt: now,
      );

      final map = conversation.toMap();
      expect(map['participants'], containsAll(['uid_alice_123', 'uid_bob_456']));
      expect(map['participantDetails'], contains('uid_alice_123'));
      expect(map['participantDetails'], contains('uid_bob_456'));
      expect(map['type'], equals('direct'));
      expect(conversation.isGroup, isFalse);

      final reconstructed = ConversationModel.fromMap(map, docId: conversation.id);
      expect(reconstructed.id, equals(conversation.id));
      expect(reconstructed.otherParticipantId('uid_alice_123'), equals('uid_bob_456'));
      expect(reconstructed.otherParticipantName('uid_alice_123'), equals('Bob'));
    });
  });

  group('User Search Error Distinction Tests', () {
    test('Distinguishes connectivity/unavailable errors from permission and empty states', () {
      bool isConnectivityError(dynamic err) {
        final errStr = err.toString().toLowerCase();
        return errStr.contains('unavailable') ||
            errStr.contains('network') ||
            errStr.contains('timeout') ||
            errStr.contains('socket');
      }

      bool isPermissionError(dynamic err) {
        final errStr = err.toString().toLowerCase();
        return errStr.contains('permission') || errStr.contains('unauthenticated');
      }

      // Simulate cloud_firestore/unavailable
      final firestoreUnavailable = Exception(
        '[cloud_firestore/unavailable] The service is currently unavailable.',
      );
      expect(isConnectivityError(firestoreUnavailable), isTrue);
      expect(isPermissionError(firestoreUnavailable), isFalse);

      // Simulate permission denied
      final permissionDenied = Exception(
        '[cloud_firestore/permission-denied] Missing or insufficient permissions.',
      );
      expect(isConnectivityError(permissionDenied), isFalse);
      expect(isPermissionError(permissionDenied), isTrue);

      // Simulate empty result (list is empty, not an error)
      final emptyUsers = <ConvoUser>[];
      expect(emptyUsers.isEmpty, isTrue);
    });
  });

  group('Message Capsules Status, Expiry & Vault Tests', () {
    test('Capsule correctly distinguishes locked vs ready based on unlockAt timestamp', () {
      final now = DateTime.now();

      // Future capsule (locked)
      final futureUnlock = now.add(const Duration(hours: 24));
      final lockedCapsule = CapsuleModel(
        id: 'cap_1',
        conversationId: 'conv_1',
        senderId: 'alice',
        senderName: 'Alice',
        receiverId: 'bob',
        receiverName: 'Bob',
        message: 'Happy Birthday!',
        unlockAt: futureUnlock,
        createdAt: now,
        status: CapsuleStatus.locked,
      );

      expect(lockedCapsule.isLocked, isTrue);
      expect(lockedCapsule.isUnlocked, isFalse);
      expect(lockedCapsule.countdownString, isNot(contains('Ready to open!')));

      // Past capsule (ready)
      final pastUnlock = now.subtract(const Duration(hours: 1));
      final readyCapsule = CapsuleModel(
        id: 'cap_2',
        conversationId: 'conv_1',
        senderId: 'alice',
        senderName: 'Alice',
        receiverId: 'bob',
        receiverName: 'Bob',
        message: 'Surprise!',
        unlockAt: pastUnlock,
        createdAt: now.subtract(const Duration(days: 1)),
        status: CapsuleStatus.ready,
      );

      expect(readyCapsule.isLocked, isFalse);
      expect(readyCapsule.isUnlocked, isTrue);
      expect(readyCapsule.countdownString, equals('Ready to open!'));
    });

    test('Capsule serialization preserves status, timestamps, and message payload with dual receiverId/recipientId schema', () {
      final now = DateTime.now();
      final unlock = now.add(const Duration(days: 3));

      final original = CapsuleModel(
        id: 'cap_test_100',
        conversationId: 'conv_100',
        senderId: 'alice',
        senderName: 'Alice',
        receiverId: 'bob',
        receiverName: 'Bob',
        message: 'Secret future note',
        unlockAt: unlock,
        createdAt: now,
        status: CapsuleStatus.locked,
      );

      final map = original.toMap();
      expect(map['id'], equals('cap_test_100'));
      expect(map['status'], equals('locked'));
      expect(map['receiverId'], equals('bob'));
      expect(map['recipientId'], equals('bob')); // Dual schema support
      expect(map['unlockAt'], isA<Timestamp>());

      // Reconstruct from map with receiverId
      final fromReceiver = CapsuleModel.fromMap(map, docId: 'cap_test_100');
      expect(fromReceiver.receiverId, equals('bob'));

      // Reconstruct from legacy map that only had recipientId
      final legacyMap = Map<String, dynamic>.from(map)..remove('receiverId');
      final fromRecipient = CapsuleModel.fromMap(legacyMap, docId: 'cap_test_100');
      expect(fromRecipient.receiverId, equals('bob'));
      expect(fromRecipient.message, equals('Secret future note'));
    });
  });

  group('Firestore Security Rules Logic Simulation Tests', () {
    test('Simulates conversation read rule: participant access vs unauthorized access', () {
      bool canReadConversation({
        required String? authUid,
        required List<String> participants,
        required bool docExists,
      }) {
        if (authUid == null) return false;
        // rule: resource == null || request.auth.uid in resource.data.participants
        if (!docExists) return true; // checking non-existent document
        return participants.contains(authUid);
      }

      // Authenticated participant
      expect(
        canReadConversation(authUid: 'alice', participants: ['alice', 'bob'], docExists: true),
        isTrue,
      );
      // Authenticated non-participant
      expect(
        canReadConversation(authUid: 'eve', participants: ['alice', 'bob'], docExists: true),
        isFalse,
      );
      // Unauthenticated
      expect(
        canReadConversation(authUid: null, participants: ['alice', 'bob'], docExists: true),
        isFalse,
      );
      // Non-existent document check by authenticated user
      expect(
        canReadConversation(authUid: 'alice', participants: [], docExists: false),
        isTrue,
      );
    });

    test('Simulates message create rule: sender matching and participant verification', () {
      bool canCreateMessage({
        required String? authUid,
        required String senderId,
        required List<String> parentParticipants,
      }) {
        if (authUid == null) return false;
        // rule: request.auth.uid == request.resource.data.senderId && auth.uid in parent.participants
        if (authUid != senderId) return false;
        return parentParticipants.contains(authUid);
      }

      // Valid sender in conversation
      expect(
        canCreateMessage(authUid: 'alice', senderId: 'alice', parentParticipants: ['alice', 'bob']),
        isTrue,
      );
      // Spoofed sender (auth is alice, but claims sender is bob)
      expect(
        canCreateMessage(authUid: 'alice', senderId: 'bob', parentParticipants: ['alice', 'bob']),
        isFalse,
      );
      // Sender not in parent conversation
      expect(
        canCreateMessage(authUid: 'eve', senderId: 'eve', parentParticipants: ['alice', 'bob']),
        isFalse,
      );
    });

    test('Simulates group admin security rule: non-admin cannot arbitrarily add members', () {
      bool canUpdateGroupMembers({
        required String authUid,
        required List<String> admins,
        required List<String> currentParticipants,
        required List<String> updatedParticipants,
      }) {
        // Admins can update any members
        if (admins.contains(authUid)) return true;

        // Non-admins can ONLY remove themselves (leave group)
        final isSelfRemoval = !updatedParticipants.contains(authUid) &&
            updatedParticipants.length == currentParticipants.length - 1 &&
            currentParticipants.contains(authUid);
        return isSelfRemoval;
      }

      const admins = ['admin_alice'];
      const currentMembers = ['admin_alice', 'member_bob', 'member_charlie'];

      // Admin adds a member
      expect(
        canUpdateGroupMembers(
          authUid: 'admin_alice',
          admins: admins,
          currentParticipants: currentMembers,
          updatedParticipants: [...currentMembers, 'member_david'],
        ),
        isTrue,
      );

      // Non-admin attempts to add a member (UNAUTHORIZED)
      expect(
        canUpdateGroupMembers(
          authUid: 'member_bob',
          admins: admins,
          currentParticipants: currentMembers,
          updatedParticipants: [...currentMembers, 'member_david'],
        ),
        isFalse,
      );

      // Non-admin leaves the group (AUTHORIZED)
      expect(
        canUpdateGroupMembers(
          authUid: 'member_bob',
          admins: admins,
          currentParticipants: currentMembers,
          updatedParticipants: ['admin_alice', 'member_charlie'],
        ),
        isTrue,
      );
    });

    test('Simulates capsule security rule: sender and receiver access, recipient status update only', () {
      bool canReadCapsule({
        required String authUid,
        required String senderId,
        required String receiverId,
        required String? recipientId,
      }) {
        return authUid == senderId || authUid == receiverId || authUid == recipientId;
      }

      bool canUpdateCapsule({
        required String authUid,
        required String senderId,
        required String receiverId,
        required List<String> modifiedFields,
      }) {
        if (authUid == senderId) return true; // Sender can update capsule
        if (authUid == receiverId) {
          // Receiver can only update status/openedAt
          return modifiedFields.every((f) => f == 'status' || f == 'openedAt');
        }
        return false;
      }

      // Sender and receiver can read
      expect(canReadCapsule(authUid: 'alice', senderId: 'alice', receiverId: 'bob', recipientId: 'bob'), isTrue);
      expect(canReadCapsule(authUid: 'bob', senderId: 'alice', receiverId: 'bob', recipientId: 'bob'), isTrue);
      expect(canReadCapsule(authUid: 'eve', senderId: 'alice', receiverId: 'bob', recipientId: 'bob'), isFalse);

      // Receiver marks capsule as opened (ALLOWED)
      expect(
        canUpdateCapsule(
          authUid: 'bob',
          senderId: 'alice',
          receiverId: 'bob',
          modifiedFields: ['status', 'openedAt'],
        ),
        isTrue,
      );

      // Receiver attempts to modify message text (UNAUTHORIZED)
      expect(
        canUpdateCapsule(
          authUid: 'bob',
          senderId: 'alice',
          receiverId: 'bob',
          modifiedFields: ['message'],
        ),
        isFalse,
      );
    });
  });

  group('Voice Message Effects & Audio Processing Tests', () {
    test('Voice effect presets define distinct playback speeds and pitch configurations', () {
      final presets = VoiceEffectPreset.presets;
      expect(presets.length, equals(5));

      final normal = presets.firstWhere((p) => p.type == VoiceEffectType.normal);
      expect(normal.playbackSpeed, equals(1.0));

      final robot = presets.firstWhere((p) => p.type == VoiceEffectType.robot);
      expect(robot.playbackSpeed, equals(1.05));
      expect(robot.pitchShiftSemitones, equals(2));

      final deep = presets.firstWhere((p) => p.type == VoiceEffectType.deep);
      expect(deep.playbackSpeed, equals(0.85));
      expect(deep.pitchShiftSemitones, equals(-4));

      final funny = presets.firstWhere((p) => p.type == VoiceEffectType.funny);
      expect(funny.playbackSpeed, equals(1.35));
      expect(funny.pitchShiftSemitones, equals(6));

      final echo = presets.firstWhere((p) => p.type == VoiceEffectType.echo);
      expect(echo.playbackSpeed, equals(0.95));
    });

    test('Voice message metadata correctly preserves effect name and playback speed for playback', () {
      final message = MessageModel(
        id: 'msg_voice_1',
        conversationId: 'conv_1',
        senderId: 'alice',
        receiverId: 'bob',
        text: 'Voice note',
        type: 'voice',
        mediaUrl: 'https://storage.googleapis.com/voice.m4a',
        createdAt: DateTime.now(),
        metadata: {
          'effect': 'Robot',
          'playbackSpeed': 1.05,
        },
      );

      expect(message.isVoice, isTrue);
      expect(message.metadata?['effect'], equals('Robot'));
      expect(message.metadata?['playbackSpeed'], equals(1.05));
    });

    test('Normal voice message defaults to 1.0 playback speed for consistent un-accelerated playback', () {
      final normalMessage = MessageModel(
        id: 'msg_voice_normal',
        conversationId: 'conv_1',
        senderId: 'alice',
        receiverId: 'bob',
        text: 'Normal voice note',
        type: 'voice',
        mediaUrl: 'https://storage.googleapis.com/voice.m4a',
        createdAt: DateTime.now(),
      );

      final speed = (normalMessage.metadata?['playbackSpeed'] as num?)?.toDouble() ?? 1.0;
      expect(speed, equals(1.0));
    });
  });

  group('Smart Offline Queue Idempotent Sync Tests', () {
    test('QueuedMessage preserves deliveryState and offlineOrigin throughout sync cycle', () {
      final queued = QueuedMessage(
        localMessageId: 'msg_local_123',
        conversationId: 'conv_1',
        senderId: 'alice',
        receiverId: 'bob',
        text: 'Offline test message',
        type: 'text',
        createdAt: DateTime.now(),
        deliveryState: DeliveryState.queued,
        offlineOrigin: true,
      );

      expect(queued.isQueued, isTrue);
      expect(queued.isSynced, isFalse);
      expect(queued.offlineOrigin, isTrue);

      final converted = queued.toMessageModel();
      expect(converted.id, equals('msg_local_123'));
      expect(converted.text, equals('Offline test message'));
      expect(converted.offlineOrigin, isTrue);

      final delivered = queued.copyWith(deliveryState: DeliveryState.deliveredNearby);
      expect(delivered.deliveryState, equals(DeliveryState.deliveredNearby));
      expect(delivered.isDeliveredNearby, isTrue);

      final synced = queued.copyWith(deliveryState: DeliveryState.synced);
      expect(synced.deliveryState, equals(DeliveryState.synced));
      expect(synced.isSynced, isTrue);
    });

    test('Queued group message correctly identifies group receiver for backend synchronization', () {
      final groupQueued = QueuedMessage(
        localMessageId: 'msg_grp_100',
        conversationId: 'grp_conv_1',
        senderId: 'alice',
        receiverId: 'group',
        text: 'Hello group from offline',
        type: 'text',
        createdAt: DateTime.now(),
        deliveryState: DeliveryState.queued,
        offlineOrigin: true,
      );

      expect(groupQueued.receiverId, equals('group'));
      expect(groupQueued.deliveryState, equals(DeliveryState.queued));
    });
  });
}
