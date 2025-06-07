import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';

interface Stats {
  streakCurrent: number;
  streakMax: number;
  lastDate: admin.firestore.Timestamp;
}

export const updateStreak = onDocumentCreated('photos/{uid}/{yyyyMMdd}', async (event) => {
  const db = admin.firestore();
  const { uid } = event.params;
  const statsRef = db.collection('stats').doc(uid);
  
  const statsDoc = await statsRef.get();
  const now = admin.firestore.Timestamp.now();
  
  if (!statsDoc.exists) {
    // 初回写真の場合
    await statsRef.set({
      streakCurrent: 1,
      streakMax: 1,
      lastDate: now,
    });
    return;
  }
  
  const stats = statsDoc.data() as Stats;
  const lastDate = stats.lastDate.toDate();
  const hoursSinceLastPhoto = (now.toDate().getTime() - lastDate.getTime()) / (1000 * 60 * 60);
  
  if (hoursSinceLastPhoto <= 28) {
    // 28時間以内ならストリーク継続
    const newStreak = stats.streakCurrent + 1;
    await statsRef.update({
      streakCurrent: newStreak,
      streakMax: Math.max(stats.streakMax, newStreak),
      lastDate: now,
    });
  } else {
    // ストリーク切れ
    await statsRef.update({
      streakCurrent: 1,
      lastDate: now,
    });
  }
}); 