import 'package:flutter/material.dart';

import '../models/recording.dart';
import '../services/audio_api_service.dart';
import '../services/processing_service.dart';
import '../widgets/processing_status_card.dart';

class ProcessingStatusScreen extends StatefulWidget {
  final Recording? recording;
  final List<Recording> recordings;
  final Future<void> Function(RemoteSummary summary)? onSummaryReady;
  final Future<void> Function(Recording recording)? onRetry;
  final Future<void> Function(Recording recording)? onCompletedTap;
  final Future<void> Function(Recording recording)? onDelete;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onBack;

  const ProcessingStatusScreen({
    super.key,
    this.recording,
    this.recordings = const [],
    this.onSummaryReady,
    this.onRetry,
    this.onCompletedTap,
    this.onDelete,
    this.onRefresh,
    this.onBack,
  });

  @override
  State<ProcessingStatusScreen> createState() => _ProcessingStatusScreenState();
}

class _ProcessingStatusScreenState extends State<ProcessingStatusScreen> {
  String _stage = 'Uploading audio...';
  String? _error;
  bool _started = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    if (widget.recording != null) {
      _startFocusedProcessing();
    }
  }

  Future<void> _startFocusedProcessing() async {
    if (_started && !_retrying) return;
    final recording = widget.recording;
    if (recording == null) return;
    _started = true;
    setState(() {
      _error = null;
      _retrying = false;
    });
    try {
      final summary = await ProcessingService.instance.processToSummary(
        recording,
        onStage: (stage) {
          if (mounted) setState(() => _stage = stage);
        },
      );
      if (mounted) await widget.onSummaryReady?.call(summary);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Bad state: ', '');
          _retrying = false;
        });
      }
    }
  }

  void _retryFocusedProcessing() {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _started = false;
      _stage = 'Transcribing audio...';
    });
    _startFocusedProcessing();
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.recording;
    if (focused != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Processing'),
          leading: BackButton(onPressed: widget.onBack),
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _error == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 92,
                        height: 92,
                        child: CircularProgressIndicator(
                          strokeWidth: 7,
                          color: Color(0xFF4F8EF7),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        focused.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _stage,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F8EF7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your audio is being processed. This may take a moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF667085)),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFD92D20),
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Processing failed',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _retryFocusedProcessing,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing Status'),
        leading: BackButton(onPressed: widget.onBack),
      ),
      body: widget.recordings.isEmpty
          ? const Center(child: Text('No processing jobs'))
          : RefreshIndicator(
              onRefresh: widget.onRefresh ?? () async {},
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Your audio processing jobs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...widget.recordings.map(
                    (recording) => ProcessingStatusCard(
                      recording: recording,
                      onRetry: widget.onRetry == null
                          ? null
                          : () => widget.onRetry!(recording),
                      onTap:
                          recording.status == 'Completed' ||
                              recording.status == 'AwaitingDecision'
                          ? () => widget.onCompletedTap?.call(recording)
                          : null,
                      onDelete: widget.onDelete == null
                          ? null
                          : () => widget.onDelete!(recording),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
