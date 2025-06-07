import { onCall } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import axios from 'axios';

interface GenerateHighlightRequest {
  startDate: string;
  endDate: string;
}

export const generateHighlightOnDemand = onCall<GenerateHighlightRequest>(async (request) => {
  if (!request.auth) {
    throw new Error('ログインが必要です');
  }
  
  const { startDate, endDate } = request.data;
  const start = new Date(startDate);
  const end = new Date(endDate);
  
  // 日数チェック
  const days = (end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24);
  if (days > 90) {
    throw new Error('最大90日までです');
  }
  
  const db = admin.firestore();
  const uid = request.auth.uid;
  
  // 期間内の写真を取得
  const photosSnapshot = await db.collection('photos').doc(uid)
    .collection('photos')
    .where('takenAt', '>=', admin.firestore.Timestamp.fromDate(start))
    .where('takenAt', '<=', admin.firestore.Timestamp.fromDate(end))
    .get();
  
  const photos = photosSnapshot.docs.map(doc => doc.data() as { storagePath: string });
  if (photos.length < 5) {
    throw new Error('5枚以上の写真が必要です');
  }
  if (photos.length > 50) {
    throw new Error('最大50枚までです');
  }
  
  // カスタムハイライト生成
  const highlightRef = db.collection('highlights_custom').doc(uid).collection('videos').doc();
  await highlightRef.set({
    startDate: admin.firestore.Timestamp.fromDate(start),
    endDate: admin.firestore.Timestamp.fromDate(end),
    createdAt: admin.firestore.Timestamp.now(),
    status: 'processing',
  });
  
  // Cloud Run を呼び出し
  await axios.post(process.env.CLOUD_RUN_URL!, {
    uid,
    highlightId: highlightRef.id,
    photos: photos.map(p => p.storagePath),
    isCustom: true,
  });
  
  return { highlightId: highlightRef.id };
}); 