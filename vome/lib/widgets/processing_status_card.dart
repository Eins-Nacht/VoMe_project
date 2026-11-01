import 'package:flutter/material.dart';

import '../models/recording.dart';

class ProcessingStatusCard extends StatelessWidget {
  final Recording recording;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const ProcessingStatusCard({
    super.key,
    required this.recording,
    this.onTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final failed = recording.status == 'Failed';
    final completed = recording.status == 'Completed';
    final status = switch (recording.status) {
      'Pending' => 'Waiting to process',
      'Processing' => 'Processing audio',
      'Completed' => 'Summary ready',
      'Failed' => 'Processing failed',
      _ => recording.status,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          failed
              ? Icons.error_outline
              : completed
              ? Icons.check_circle_outline
              : Icons.sync,
          color: failed
              ? Colors.redAccent
              : completed
              ? Colors.green
              : const Color(0xFF4C7FF0),
        ),
        title: Text(
          recording.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(status),
        trailing: failed
            ? TextButton(onPressed: onRetry, child: const Text('Retry'))
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
