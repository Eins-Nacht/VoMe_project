import 'package:flutter/material.dart';

import '../models/recording.dart';

class ProcessingStatusCard extends StatelessWidget {
  final Recording recording;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  const ProcessingStatusCard({
    super.key,
    required this.recording,
    this.onTap,
    this.onRetry,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final failed = recording.status == 'Failed';
    final completed = recording.status == 'Completed';
    final outcome = _outcome(recording.processingError);
    final retryable = failed && outcome == null;
    final status = switch (recording.status) {
      'Pending' => 'Waiting to process',
      'Processing' => 'Processing audio',
      'Completed' => 'Summary ready',
      'Failed' => _statusText(outcome),
      _ => recording.status,
    };

    final active =
        recording.status == 'Pending' || recording.status == 'Processing';
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
        subtitle: Text(
          recording.processingMessage == null
              ? status
              : '$status\n${recording.processingMessage}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (retryable)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            if (onDelete != null)
              IconButton(
                tooltip: active ? 'Cancel and delete' : 'Delete',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: onDelete,
              )
            else
              const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  String? _outcome(String? error) {
    if (error == null) return null;
    final separator = error.indexOf('|');
    return separator > 0 ? error.substring(0, separator) : null;
  }

  String _statusText(String? outcome) => switch (outcome) {
    'no_speech' => 'No speech detected',
    'invalid_audio' => 'Invalid audio',
    'unclear_speech' => 'Speech unclear',
    _ => 'Processing failed',
  };
}
