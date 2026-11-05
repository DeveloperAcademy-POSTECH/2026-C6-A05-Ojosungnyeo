const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.notifyGroupConfirmationCancelled = onDocumentUpdated(
  {
    document: "trips/{tripID}/participants/{participantID}",
    region: "asia-northeast3",
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const beforeEventID = before.groupCancellationEvent?.id;
    const cancellation = after.groupCancellationEvent;

    if (!cancellation?.id || cancellation.id === beforeEventID) {
      return;
    }

    const { tripID, participantID } = event.params;
    const groupID = cancellation.groupID;
    if (typeof groupID !== "string" || groupID.length === 0) {
      return;
    }

    const database = getFirestore();
    const cancellingMemberName = typeof after.name === "string" && after.name.length > 0
      ? after.name
      : "다른 친구";
    const participants = await database
      .collection("trips")
      .doc(tripID)
      .collection("participants")
      .where("status", "==", "joined")
      .get();

    const recipientUserIDs = new Set();
    const batch = database.batch();
    for (const participant of participants.docs) {
      if (participant.id === participantID) {
        continue;
      }
      batch.set(
        participant.ref,
        {
          confirmedGroupIDs: FieldValue.arrayRemove(groupID),
          groupingConfirmed: false,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      const userID = participant.get("uid") || participant.id;
      if (typeof userID === "string" && userID.length > 0) {
        recipientUserIDs.add(userID);
      }
    }
    await batch.commit();

    const userDocuments = await Promise.all(
      [...recipientUserIDs].map((userID) =>
        database.collection("users").doc(userID).get()
      )
    );
    const installationIDs = [
      ...new Set(
        userDocuments.flatMap((document) => document.get("fcmTokens") || [])
      ),
    ];
    if (installationIDs.length === 0) {
      return;
    }

    for (let index = 0; index < installationIDs.length; index += 500) {
      await getMessaging().sendEachForMulticast({
        fids: installationIDs.slice(index, index + 500),
        notification: {
          title: "추천 그룹 확정 취소",
          body: `${cancellingMemberName}가 그룹 확정을 취소했어요. 다시 확인해주세요.`,
        },
        data: {
          type: "group_confirmation_cancelled",
          tripID,
          groupID,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });
    }
  }
);

exports.notifyGroupPlaceDeleted = onDocumentUpdated(
  {
    document: "trips/{tripID}/participants/{participantID}",
    region: "asia-northeast3",
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const edit = after.groupEditEvent;
    if (!edit?.id || edit.id === before.groupEditEvent?.id) {
      return;
    }

    const { tripID, participantID } = event.params;
    const groupID = String(edit.groupID || "");
    if (groupID.length === 0) {
      return;
    }
    const database = getFirestore();
    const participants = await database
      .collection("trips")
      .doc(tripID)
      .collection("participants")
      .where("status", "==", "joined")
      .get();
    const batch = database.batch();
    for (const participant of participants.docs) {
      batch.set(
        participant.ref,
        {
          confirmedGroupIDs: FieldValue.arrayRemove(groupID),
          groupingConfirmed: false,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
    await batch.commit();

    const recipientUserIDs = participants.docs
      .filter((participant) => participant.id !== participantID)
      .map((participant) => participant.get("uid") || participant.id)
      .filter((userID) => typeof userID === "string" && userID.length > 0);
    const userDocuments = await Promise.all(
      [...new Set(recipientUserIDs)].map((userID) =>
        database.collection("users").doc(userID).get()
      )
    );
    const installationIDs = [
      ...new Set(
        userDocuments.flatMap((document) => document.get("fcmTokens") || [])
      ),
    ];
    const editorName = typeof after.name === "string" && after.name.length > 0
      ? after.name
      : "다른 친구";

    for (let index = 0; index < installationIDs.length; index += 500) {
      await getMessaging().sendEachForMulticast({
        fids: installationIDs.slice(index, index + 500),
        notification: {
          title: "여행 일정 변경",
          body: `${editorName}가 그룹 일정을 수정했어요. 변경된 일정을 확인해주세요.`,
        },
        data: {
          type: "group_places_updated",
          tripID,
          groupID,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });
    }
  }
);
