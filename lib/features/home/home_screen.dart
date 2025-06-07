import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FitSnap'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TODO: ストリーク表示ウィジェット
            const Text('現在のストリーク: 0日'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.push('/camera'),
              child: const Text('写真を撮る'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => context.push('/highlights'),
              child: const Text('ハイライトを見る'),
            ),
          ],
        ),
      ),
    );
  }
} 