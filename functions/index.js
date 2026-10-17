const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Formats message notification body text based on message type, text content,
 * and user privacy preferences.
 */
function formatPreview(type, text, senderName, isGroup, includePreview) {
  if (!includePreview) {
    return "New message";
  }

  const normalizedType = (type || "text").toLowerCase();
  switch (normalizedType) {
    case "image":
      return isGroup ? `${senderName} sent a photo` : "Sent a photo";
    case "video":
      return isGroup ? `${senderName} sent a video` : "Sent a video";
    case "voice":
      return isGroup ? `${senderName} sent a voice message` : "Sent a voice message";
    case "file":
      return isGroup ? `${senderName} sent a file` : "Sent a file";
    case "sticker":
      return isGroup ? `${senderName} sent a sticker` : "Sent a sticker";
    case "game":
      return isGroup ? `${senderName} started a game` : "Invited you to play a game";
    case "capsule":
      return isGroup ? `${senderName} locked a time capsule` : "Sent a time capsule";
    case "text":
    default:
      if (text && text.trim().length > 0) {
        return isGroup ? `${senderName}: ${text.trim()}` : text.trim();
      }
      return isGroup ? `${senderName} sent a message` : "Sent a message";
  }
}

/**
 * Real-time Message Notification Dispatcher
 * Trigger: onCreate in conversations/{conversationId}/messages/{messageId}
 */
exports.onMessageCreated = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const { conversationId, messageId } = context.params;
    const messageData = snapshot.data();

    if (!messageData) {
      console.log(`[PushDispatcher] Message document ${messageId} is empty.`);
      return null;
    }

    const senderId = messageData.senderId;
    if (!senderId) {
      console.log(`[PushDispatcher] Message ${messageId} missing senderId.`);
      return null;
    }

    // Do not notify for soft-deleted or ephemeral sync records
    if (messageData.isDeleted === true) {
      return null;
    }

    try {
      // 1. Fetch parent conversation to verify participants and mute preferences
      const convDoc = await db.collection("conversations").doc(conversationId).get();
      if (!convDoc.exists) {
        console.warn(`[PushDispatcher] Conversation ${conversationId} not found.`);
        return null;
      }

      const convData = convDoc.data() || {};
      const participants = convData.participants || [];

      // Validate that the sender is actually a participant of this conversation
      if (!participants.includes(senderId)) {
        console.warn(`[PushDispatcher] Unauthorized: sender ${senderId} not in conversation ${conversationId}.`);
        return null;
      }

      // Filter out sender (never notify self)
      const targetRecipientIds = participants.filter((uid) => uid !== senderId);
      if (targetRecipientIds.length === 0) {
        return null;
      }

      const mutedBy = convData.mutedBy || [];
      const isGroup = convData.type === "group";
      const groupName = convData.name || "Group Chat";

      // 2. Fetch sender profile to get display name
      let senderName = "Someone";
      const senderDoc = await db.collection("users").doc(senderId).get();
      if (senderDoc.exists) {
        const sData = senderDoc.data() || {};
        senderName = sData.name || "Someone";
      }

      // 3. Dispatch to all eligible recipients concurrently
      const dispatchPromises = targetRecipientIds.map(async (recipientId) => {
        // Skip recipient if conversation is muted by this user
        if (mutedBy.includes(recipientId)) {
          console.log(`[PushDispatcher] User ${recipientId} muted conversation ${conversationId}. Skipping.`);
          return null;
        }

        // Fetch recipient's user document
        const recipientDoc = await db.collection("users").doc(recipientId).get();
        if (!recipientDoc.exists) {
          return null;
        }

        const recipientData = recipientDoc.data() || {};

        // Privacy check 1: Has recipient blocked the sender?
        const blockedUsers = recipientData.blockedUsers || [];
        if (blockedUsers.includes(senderId)) {
          console.log(`[PushDispatcher] Recipient ${recipientId} has blocked sender ${senderId}. Suppressing notification.`);
          return null;
        }

        // Privacy check 2: Are notifications enabled for recipient?
        const notifSettings = recipientData.notificationSettings || {};
        if (notifSettings.enabled === false) {
          console.log(`[PushDispatcher] User ${recipientId} has notifications disabled.`);
          return null;
        }

        const token = recipientData.fcmToken;
        if (!token || typeof token !== "string" || token.trim().length === 0) {
          console.log(`[PushDispatcher] User ${recipientId} has no registered FCM token.`);
          return null;
        }

        const includePreview = notifSettings.preview !== false;
        const soundEnabled = notifSettings.sound !== false;

        const title = isGroup ? groupName : senderName;
        const bodyText = formatPreview(
          messageData.type,
          messageData.text,
          senderName,
          isGroup,
          includePreview
        );

        const fcmPayload = {
          token: token.trim(),
          notification: {
            title: title,
            body: bodyText,
          },
          data: {
            conversationId: conversationId,
            messageId: messageId,
            senderId: senderId,
            type: messageData.type || "text",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "convo_messages",
              sound: soundEnabled ? "default" : undefined,
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: soundEnabled ? "default" : undefined,
                badge: 1,
              },
            },
          },
        };

        try {
          const response = await admin.messaging().send(fcmPayload);
          console.log(`[PushDispatcher] Notification successfully sent to ${recipientId}: ${response}`);
          return response;
        } catch (sendError) {
          console.error(`[PushDispatcher] Error sending notification to ${recipientId}:`, sendError);

          // Handle invalid / expired / unregistered token cleanup
          const errorCode = sendError.code || (sendError.errorInfo && sendError.errorInfo.code);
          if (
            errorCode === "messaging/registration-token-not-registered" ||
            errorCode === "messaging/invalid-registration-token" ||
            errorCode === "messaging/mismatched-credential"
          ) {
            console.log(`[PushDispatcher] Stale or invalid token detected for user ${recipientId}. Cleaning up from Firestore.`);
            try {
              await db.collection("users").doc(recipientId).update({
                fcmToken: admin.firestore.FieldValue.delete(),
                fcmTokenInvalidatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            } catch (cleanupErr) {
              console.warn(`[PushDispatcher] Token cleanup warning for ${recipientId}:`, cleanupErr);
            }
          }
          return null;
        }
      });

      await Promise.all(dispatchPromises);
      return null;
    } catch (globalError) {
      console.error(`[PushDispatcher] Unexpected error processing message ${messageId}:`, globalError);
      return null;
    }
  });

/**
 * Real-time Incoming Call Notification Dispatcher
 * Trigger: onCreate in calls/{callId}
 */
exports.onCallCreated = functions.firestore
  .document("calls/{callId}")
  .onCreate(async (snapshot, context) => {
    const { callId } = context.params;
    const callData = snapshot.data();

    if (!callData) return null;

    const callerId = callData.callerId;
    const callerName = callData.callerName || "Someone";
    const participants = callData.participants || [];
    const isVideo = callData.isVideo === true;

    // Recipient is the participant who isn't the caller
    const recipientId = participants.find((uid) => uid !== callerId);
    if (!recipientId) return null;

    try {
      const recipientDoc = await db.collection("users").doc(recipientId).get();
      if (!recipientDoc.exists) return null;

      const recipientData = recipientDoc.data() || {};
      const blockedUsers = recipientData.blockedUsers || [];
      if (blockedUsers.includes(callerId)) return null;

      const token = recipientData.fcmToken;
      if (!token) return null;

      const callPayload = {
        token: token.trim(),
        notification: {
          title: callerName,
          body: isVideo ? "Incoming video call..." : "Incoming voice call...",
        },
        data: {
          type: "call",
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          isVideo: String(isVideo),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "convo_messages",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      };

      await admin.messaging().send(callPayload);
      console.log(`[PushDispatcher] Incoming call notification sent for call ${callId}`);
      return null;
    } catch (e) {
      console.error(`[PushDispatcher] Error sending call notification:`, e);
      return null;
    }
  });
