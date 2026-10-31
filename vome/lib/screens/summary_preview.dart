import 'dart:convert';

import 'package:flutter/material.dart';

class SummaryPreview extends StatelessWidget {
  const SummaryPreview({
    super.key,
    required this.summaryJson,
    required this.onEdit,
    required this.onDelete,
  });

  final String summaryJson;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final summary = Map<String, dynamic>.from(jsonDecode(summaryJson) as Map);
    final overview = summary['overview'] as String? ?? '';
    final points = (summary['key_points'] as List? ?? const []).cast<String>();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('AI Summary', style: TextStyle(fontWeight: FontWeight.w700))),
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18)),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18)),
              ],
            ),
            Text(overview, maxLines: 3, overflow: TextOverflow.ellipsis),
            if (points.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...points.take(3).map((point) => Text('• $point', maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ],
        ),
      ),
    );
  }
}
