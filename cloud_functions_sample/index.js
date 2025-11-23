import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";
import { getFirestore } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

// Initialize admin SDK (for local emulation you can supply credentials differently)
initializeApp({ credential: applicationDefault() });

// Callable to promote a user to admin (only existing admins can call)
export const promoteToAdmin = onCall(async (request) => {
  const caller = request.auth;
  if (!caller || caller.token.admin !== true) {
    throw new Error("Unauthorized");
  }
  const targetUid = request.data?.uid;
  if (!targetUid) throw new Error("Missing uid");
  await getAuth().setCustomUserClaims(targetUid, { admin: true });
  await getFirestore().collection("adminAudit").add({
    promoterUid: caller.uid,
    targetUid,
    ts: Date.now(),
    action: "promoteToAdmin",
  });
  return { status: "ok", targetUid };
});

// Firestore trigger: send FCM when user status moves from pending -> approved
export const notifyApproval = onDocumentUpdated(
  "Users/{uid}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;
    if (before.status === "pending" && after.status === "approved") {
      const token = after.fcmToken;
      if (!token) return;
      await getMessaging().send({
        token,
        notification: {
          title: "Approval Complete",
          body: "Your account has been approved.",
        },
        data: { uid: event.params.uid },
      });
      await getFirestore().collection("notifications").add({
        uid: event.params.uid,
        type: "approval",
        ts: Date.now(),
      });
    }
  }
);

// One-off script style function to set admin claim (manually invoke with emulator or node runner)
export async function setAdminClaim(uid) {
  await getAuth().setCustomUserClaims(uid, { admin: true });
  console.log("Admin claim set for", uid);
}
