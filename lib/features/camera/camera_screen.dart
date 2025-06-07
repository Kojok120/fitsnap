import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart';

final cameraProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return await availableCameras();
});

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      minFaceSize: 0.15,
    ),
  );
  bool _isProcessing = false;
  int _currentPoseIndex = 0;
  final List<String> _poseGuides = [
    'assets/poses/pose1.png',
    'assets/poses/pose2.png',
    'assets/poses/pose3.png',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      debugPrint('写真を撮影中...');
      final XFile photo = await _controller!.takePicture();
      final File imageFile = File(photo.path);
      debugPrint('写真を保存しました: ${photo.path}');
      
      // 顔検出とぼかし処理
      debugPrint('顔検出を開始...');
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);
      debugPrint('検出された顔の数: ${faces.length}');
      
      if (faces.isNotEmpty) {
        debugPrint('画像処理を開始...');
        final bytes = await imageFile.readAsBytes();
        final image = img.decodeImage(bytes);
        if (image != null) {
          var processedImage = image;
          for (final face in faces) {
            final rect = face.boundingBox;
            debugPrint('顔の位置: ${rect.toString()}');
            
            try {
              // 顔の部分を切り出し
              final faceImage = img.copyCrop(
                processedImage,
                x: rect.left.toInt(),
                y: rect.top.toInt(),
                width: rect.width.toInt(),
                height: rect.height.toInt(),
              );
              debugPrint('顔の部分を切り出しました');
              
              // 切り出した顔の部分にぼかし処理を適用
              final blurredFace = img.gaussianBlur(faceImage, radius: 18);
              debugPrint('ぼかし処理を適用しました');
              
              // ぼかした顔の部分を元の画像に合成
              processedImage = img.compositeImage(
                processedImage,
                blurredFace,
                dstX: rect.left.toInt(),
                dstY: rect.top.toInt(),
              );
              debugPrint('画像を合成しました');
            } catch (e) {
              debugPrint('画像処理中にエラーが発生: $e');
              rethrow;
            }
          }
          
          // ぼかし処理後の画像を保存
          debugPrint('処理済み画像を保存中...');
          final tempDir = await getTemporaryDirectory();
          final blurredPath = '${tempDir.path}/blurred_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await File(blurredPath).writeAsBytes(img.encodeJpg(processedImage));
          debugPrint('処理済み画像を保存しました: $blurredPath');
          
          // Firebase Storageにアップロード
          debugPrint('Firebase Storageにアップロード中...');
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('photos/${ref.read(authProvider).currentUser?.uid}/${DateTime.now().toString().split(' ')[0]}.jpg');
          
          await storageRef.putFile(File(blurredPath));
          final downloadUrl = await storageRef.getDownloadURL();
          debugPrint('Firebase Storageにアップロード完了: $downloadUrl');
          
          // Firestoreに保存
          debugPrint('Firestoreに保存中...');
          await FirebaseFirestore.instance
              .collection('photos')
              .doc(ref.read(authProvider).currentUser?.uid)
              .collection(DateTime.now().toString().split(' ')[0])
              .add({
            'takenAt': FieldValue.serverTimestamp(),
            'storagePath': storageRef.fullPath,
          });
          debugPrint('Firestoreに保存完了');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('写真を保存しました')),
            );
            Navigator.pop(context);
          }
        } else {
          throw Exception('画像のデコードに失敗しました');
        }
      } else {
        debugPrint('顔が検出されませんでした');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('顔が検出されませんでした')),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('エラーが発生しました: $e');
      debugPrint('スタックトレース: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameras = ref.watch(cameraProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('写真を撮る'),
      ),
      body: cameras.when(
        data: (cameras) {
          if (_controller == null || !_controller!.value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return Stack(
            children: [
              // カメラプレビュー
              CameraPreview(_controller!),
              
              // ポーズガイド
              GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    setState(() {
                      _currentPoseIndex = (_currentPoseIndex - 1) % _poseGuides.length;
                    });
                  } else {
                    setState(() {
                      _currentPoseIndex = (_currentPoseIndex + 1) % _poseGuides.length;
                    });
                  }
                },
                child: Center(
                  child: Opacity(
                    opacity: 0.3,
                    child: Image.asset(_poseGuides[_currentPoseIndex]),
                  ),
                ),
              ),
              
              // シャッターボタン
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton(
                    onPressed: _isProcessing ? null : _takePicture,
                    child: _isProcessing
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.camera),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('エラー: $error')),
      ),
    );
  }
} 