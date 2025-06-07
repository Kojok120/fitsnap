import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HighlightsScreen extends ConsumerStatefulWidget {
  const HighlightsScreen({super.key});

  @override
  ConsumerState<HighlightsScreen> createState() => _HighlightsScreenState();
}

class _HighlightsScreenState extends ConsumerState<HighlightsScreen> {
  DateTimeRange? _selectedDateRange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ハイライト'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final DateTimeRange? picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                initialDateRange: _selectedDateRange,
              );
              if (picked != null) {
                setState(() {
                  _selectedDateRange = picked;
                });
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 12, // TODO: 実際の月次ハイライト数
        itemBuilder: (context, index) {
          final date = DateTime.now().subtract(Duration(days: 30 * index));
          return ListTile(
            title: Text('${date.year}年${date.month}月のハイライト'),
            subtitle: const Text('タップして再生'),
            trailing: const Icon(Icons.play_circle_outline),
            onTap: () {
              // TODO: 動画再生処理
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: カスタムハイライト生成処理
        },
        child: const Icon(Icons.add),
      ),
    );
  }
} 