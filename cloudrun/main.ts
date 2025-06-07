import express from 'express';
import { Storage } from '@google-cloud/storage';
import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs';
import * as path from 'path';

const execAsync = promisify(exec);
const app = express();
const storage = new Storage();

interface GenerateRequest {
  uid: string;
  yyyyMM?: string;
  highlightId: string;
  photos: string[];
  isCustom?: boolean;
}

app.use(express.json());

app.post('/generate', async (req, res) => {
  try {
    const { uid, yyyyMM, highlightId, photos, isCustom } = req.body as GenerateRequest;
    const bucket = storage.bucket(process.env.BUCKET_NAME!);
    const tempDir = path.join('/tmp', highlightId);
    
    // 一時ディレクトリ作成
    await fs.promises.mkdir(tempDir, { recursive: true });
    
    // 写真をダウンロード
    for (let i = 0; i < photos.length; i++) {
      const photoPath = photos[i];
      const localPath = path.join(tempDir, `${i}.jpg`);
      await bucket.file(photoPath).download({ destination: localPath });
    }
    
    // 出力パス
    const outputPath = isCustom
      ? `highlights_custom/${uid}/${highlightId}.mp4`
      : `highlights/${uid}/${yyyyMM}.mp4`;
    
    // FFmpeg コマンド構築
    const inputFiles = photos.map((_, i) => `file '${path.join(tempDir, `${i}.jpg`)}'`).join('\n');
    await fs.promises.writeFile(path.join(tempDir, 'input.txt'), inputFiles);
    
    let ffmpegCmd = `ffmpeg -y -f concat -safe 0 -i ${path.join(tempDir, 'input.txt')} -c:v libx264 -pix_fmt yuv420p -r 30 -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2"`;
    
    // 無料ユーザーはウォーターマーク追加
    if (!isCustom) {
      ffmpegCmd += ` -i gs://fitsnap-assets/watermark.png -filter_complex "overlay=W-w-20:H-h-20"`;
    }
    
    ffmpegCmd += ` ${path.join(tempDir, 'output.mp4')}`;
    
    // 動画生成
    await execAsync(ffmpegCmd);
    
    // 動画をアップロード
    await bucket.upload(path.join(tempDir, 'output.mp4'), {
      destination: outputPath,
      metadata: {
        contentType: 'video/mp4',
      },
    });
    
    // 一時ファイル削除
    await fs.promises.rm(tempDir, { recursive: true, force: true });
    
    res.json({ success: true, path: outputPath });
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
}); 