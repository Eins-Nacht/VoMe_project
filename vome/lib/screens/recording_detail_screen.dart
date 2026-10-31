import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/recording.dart';
import '../services/audio_storage_service.dart';
import '../services/recording_repository.dart';
import '../services/processing_service.dart';
import 'summary_preview.dart';

class RecordingDetailScreen extends StatefulWidget {
  final Recording recording;
  final VoidCallback? onDeleted;
  final VoidCallback? onBack;

  const RecordingDetailScreen({
    super.key,
    required this.recording,
    this.onDeleted,
    this.onBack,
  });

  @override
  State<RecordingDetailScreen> createState() => _RecordingDetailScreenState();
}
class _RecordingDetailScreenState extends State<RecordingDetailScreen> {
  final AudioPlayer _player = AudioPlayer();
  late Recording _recording;

  bool _isPlaying = false;
  bool _isDeleting = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _recording = widget.recording;
    _totalDuration = Duration(milliseconds: _recording.durationMs);

    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _player.onDurationChanged.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() {
        _totalDuration = duration;
      });
    });

    _player.onPositionChanged.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() {
        _position = position;
      });
    });

    _player.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }

    final absolutePath = AudioStorageService.instance.absolutePath(
      _recording.audioPath,
    );

    await _player.play(DeviceFileSource(absolutePath));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: const Text(
          'This will permanently delete the audio file and its record. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE05A67)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);

    try {
      await _player.stop();
      await RecordingRepository.instance.deleteRecording(_recording.id);

      if (!mounted) {
        return;
      }

      widget.onDeleted?.call();

      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete recording: $e')),
      );
      setState(() => _isDeleting = false);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _editSummary() async {
    final source = _recording.summaryJson;
    if (source == null) return;
    final summary = Map<String, dynamic>.from(jsonDecode(source) as Map);
    final controller = TextEditingController(text: summary['overview'] as String? ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit summary overview'),
        content: TextField(controller: controller, minLines: 4, maxLines: 8),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    summary['overview'] = controller.text.trim();
    await RecordingRepository.instance.updateSummary(_recording.id, jsonEncode(summary));
    final updated = await RecordingRepository.instance.getRecordingById(_recording.id);
    if (updated != null && mounted) setState(() => _recording = updated);
  }

  Future<void> _deleteSummary() async {
    await RecordingRepository.instance.updateSummary(_recording.id, null);
    final updated = await RecordingRepository.instance.getRecordingById(_recording.id);
    if (updated != null && mounted) setState(() => _recording = updated);
  }

  Future<void> _retryProcessing() async {
    await ProcessingService.instance.retry(_recording);
    final updated = await RecordingRepository.instance.getRecordingById(_recording.id);
    if (updated != null && mounted) setState(() => _recording = updated);
  }

  @override
  Widget build(BuildContext context) {
    final recording = _recording;
    final progress = _totalDuration.inMilliseconds > 0
        ? _position.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack ?? () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E5EA)),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        size: 22,
                        color: Color(0xFF526071),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Recording Detail',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ),
                  if (_isDeleting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    if (recording.status == 'Failed' && recording.audioRetained)
                      IconButton(
                        onPressed: _retryProcessing,
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Retry processing',
                      ),
                    IconButton(
                      onPressed: _confirmDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFE05A67),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recording.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${recording.eventType} · ${recording.formattedDate}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recording.audioPath,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF98A2B3),
                      ),
                    ),
                    if (recording.summaryJson != null)
                      SummaryPreview(
                        summaryJson: recording.summaryJson!,
                        onEdit: _editSummary,
                        onDelete: _deleteSummary,
                      )
                    else if (recording.transcript != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          recording.transcript!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF526071)),
                        ),
                      )
                    else if (recording.processingError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          recording.processingError!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFE05A67)),
                        ),
                      ),
                    const Spacer(),
                    Center(
                      child: GestureDetector(
                        onTap: _isDeleting || !recording.audioRetained ? null : _togglePlayback,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6195F2),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6195F2).withValues(alpha: 0.20),
                                blurRadius: 0,
                                spreadRadius: 7,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: const Color(0xFFE9EDF3),
                        color: const Color(0xFF6195F2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF98A2B3),
                          ),
                        ),
                        Text(
                          _formatDuration(_totalDuration),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF98A2B3),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _DetailRow(label: 'Status', value: recording.status),
                    _DetailRow(label: 'Mood', value: recording.mood),
                    _DetailRow(label: 'Source', value: recording.source),
                    _DetailRow(label: 'Duration', value: recording.formattedDuration),
                    if (recording.fileSize != null)
                      _DetailRow(
                        label: 'File Size',
                        value: _formatFileSize(recording.fileSize!),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF101828),
            ),
          ),
        ],
      ),
    );
  }
}
