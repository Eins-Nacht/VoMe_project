import 'package:flutter/material.dart';

import '../models/recording.dart';
import '../widgets/processing_status_card.dart';

class ProcessingStatusScreen extends StatelessWidget {
  final List<Recording> recordings;
  final Future<void> Function(Recording recording)? onRetry;
  final Future<void> Function(Recording recording)? onCompletedTap;
  final Future<void> Function(Recording recording)? onDelete;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onBack;

  const ProcessingStatusScreen({
    super.key,
    required this.recordings,
    this.onRetry,
    this.onCompletedTap,
    this.onDelete,
    this.onRefresh,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing Status'),
        leading: BackButton(onPressed: onBack),
      ),
      body: recordings.isEmpty
          ? const Center(child: Text('No processing jobs'))
          : RefreshIndicator(
              onRefresh: onRefresh ?? () async {},
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Your audio processing jobs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...recordings.map(
                    (recording) => ProcessingStatusCard(
                      recording: recording,
                      onRetry: onRetry == null
                          ? null
                          : () => onRetry!(recording),
                      onTap:
                          recording.status == 'Completed' ||
                              recording.status == 'AwaitingDecision'
                          ? () => onCompletedTap?.call(recording)
                          : null,
                      onDelete: onDelete == null
                          ? null
                          : () => onDelete!(recording),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
