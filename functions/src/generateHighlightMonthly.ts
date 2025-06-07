import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';
import axios from 'axios';

interface Photo {
  takenAt: admin.firestore.Timestamp;
  storagePath: string;
}

export const generateHighlightMonthly = onSchedule({
  schedule: '0 0 1 * *',
  timeZone: 'Asia/Tokyo',
}, async (event) => {
  const db = admin.firestore();
  const now = new Date();
  const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const yyyyMM = `${lastMonth.getFullYear()}${String(lastMonth.getMonth() + 1).padStart(2, '0')}`;
  
  // 全ユーザーの写真を取得
  const usersSnapshot = await db.collectionGroup('photos')
    .where('takenAt', '>=', admin.firestore.Timestamp.fromDate(lastMonth))
    .where('takenAt', '<', admin.firestore.Timestamp.fromDate(now))
    .get();
  
  // ユーザーごとにグループ化
  const userPhotos = new Map<string, Photo[]>();
  usersSnapshot.forEach(doc => {
    const uid = doc.ref.parent.parent?.id;
    if (!uid) return;
    
    const photos = userPhotos.get(uid) || [];
    photos.push(doc.data() as Photo);
    userPhotos.set(uid, photos);
  });
  
  // 各ユーザーのハイライト生成をトリガー
  for (const [uid, photos] of userPhotos) {
    if (photos.length < 5) continue; // 5枚未満はスキップ
    
    const highlightRef = db.collection('highlights').doc(uid).collection(yyyyMM).doc();
    await highlightRef.set({
      createdAt: admin.firestore.Timestamp.now(),
      status: 'processing',
    });
    
    // Cloud Run を呼び出し
    await axios.post(process.env.CLOUD_RUN_URL!, {
      uid,
      yyyyMM,
      photos: photos.map(p => p.storagePath),
      highlightId: highlightRef.id,
    });
  }
}); 