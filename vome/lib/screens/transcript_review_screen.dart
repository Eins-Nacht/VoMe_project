import 'package:flutter/material.dart';

import '../models/recording.dart';
import '../services/processing_service.dart';
import '../services/recording_repository.dart';
import '../services/audio_api_service.dart';

class TranscriptReviewScreen extends StatefulWidget {
  final Recording recording;
  final Future<void> Function(RemoteSummary summary) onSummaryReady;
  final VoidCallback? onBack;

  const TranscriptReviewScreen({
    super.key,
    required this.recording,
    required this.onSummaryReady,
    this.onBack,
  });

  @override
  State<TranscriptReviewScreen> createState() => _TranscriptReviewScreenState();
}

class _TranscriptReviewScreenState extends State<TranscriptReviewScreen> {
  RemoteSummary? _result;
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadTranscript();
  }

  Future<void> _loadTranscript() async {
    try {
      final result = await ProcessingService.instance.fetchResult(
        widget.recording,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
        _error = result == null ? 'Transcript is unavailable.' : null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _chooseRetention(bool retain) async {
    final result = _result;
    if (result == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final recording = await RecordingRepository.instance.getRecordingById(
        widget.recording.id,
      );
      if (recording == null) {
        throw StateError('The local recording is unavailable.');
      }
      if (retain) {
        await RecordingRepository.instance.retainLocalAudio(recording);
      } else {
        await RecordingRepository.instance.removeLocalAudio(recording);
      }
      await widget.onSummaryReady(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review transcript'),
        leading: BackButton(onPressed: widget.onBack),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : result == null
          ? Center(child: Text(_error ?? 'Transcript is unavailable.'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Transcript Preview',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Detected language: ${result.transcriptLanguage ?? 'Unknown'}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Text(result.transcriptText ?? ''),
                const SizedBox(height: 24),
                const Text(
                  'The original audio is still stored locally on this device.',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                if (_submitting)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _chooseRetention(false),
                          child: const Text('Delete Audio'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _chooseRetention(true),
                          child: const Text('Keep Audio'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
