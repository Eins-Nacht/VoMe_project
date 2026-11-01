import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../models/recording.dart';
import '../services/audio_api_service.dart';
import '../services/remote_summary_service.dart';
import '../services/recording_repository.dart';

class RecordingDetailScreen extends StatefulWidget {
  final RemoteSummary summary;
  final VoidCallback? onDeleted;
  final VoidCallback? onBack;

  const RecordingDetailScreen({
    super.key,
    required this.summary,
    this.onDeleted,
    this.onBack,
  });

  @override
  State<RecordingDetailScreen> createState() => _RecordingDetailScreenState();
}

class _RecordingDetailScreenState extends State<RecordingDetailScreen> {
  final AudioPlayer _player = AudioPlayer();
  late RemoteSummary _summary;
  bool _playing = false;
  bool _regenerating = false;
  bool _audioRetained = false;
  Recording? _localRecording;

  @override
  void initState() {
    super.initState();
    _summary = widget.summary;
    _loadLocalRecording();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
  }

  Future<void> _loadLocalRecording() async {
    final id = _summary.clientRecordingId;
    if (id == null) return;
    final recording = await RecordingRepository.instance.getRecordingById(id);
    if (!mounted) return;
    setState(() {
      _localRecording = recording;
      _audioRetained = recording?.audioRetained == true && recording != null;
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    try {
      if (_playing) {
        await _player.pause();
        return;
      }
      final recording = _localRecording;
      if (recording == null || !_audioRetained) {
        throw StateError('The original audio is not retained on this device.');
      }
      await _player.play(
        DeviceFileSource(
          RecordingRepository.instance.toAbsoluteAudioPath(recording.audioPath),
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _deleteLocalAudio() async {
    final recording = _localRecording;
    if (recording == null || !_audioRetained) return;
    try {
      await RecordingRepository.instance.removeLocalAudio(recording);
      if (mounted) {
        setState(() => _audioRetained = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Original audio deleted from device.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _deleteSummary() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete summary?'),
        content: Text('Delete the summary for "${_summary.eventTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RemoteSummaryService.instance.api!.deleteSummary(_summary.id);
      widget.onDeleted?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _editSummary() async {
    final transcriptController = TextEditingController(
      text:
          _summary.correctedTranscript ??
          _summary.rawTranscript ??
          _summary.transcriptText ??
          '',
    );
    final summaryController = TextEditingController(text: _summary.summary);
    final categoryController = TextEditingController(
      text: _summary.category ?? '',
    );
    try {
      final values =
          await showDialog<
            ({String transcript, String summary, String category})
          >(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Edit summary'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: transcriptController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Transcript',
                      ),
                    ),
                    TextField(
                      controller: summaryController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'AI Summary',
                      ),
                    ),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final transcript = transcriptController.text.trim();
                    final summary = summaryController.text.trim();
                    if (transcript.isEmpty || summary.isEmpty) return;
                    Navigator.pop(context, (
                      transcript: transcript,
                      summary: summary,
                      category: categoryController.text.trim(),
                    ));
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
      if (values == null) return;
      final updated = await RemoteSummaryService.instance.api!.updateSummary(
        _summary.id,
        transcriptText: values.transcript,
        summary: values.summary,
        category: values.category,
      );
      if (mounted) {
        setState(() => _summary = updated);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Summary updated.')));
      }
    } finally {
      transcriptController.dispose();
      summaryController.dispose();
      categoryController.dispose();
    }
  }

  Future<void> _regenerateSummary() async {
    setState(() => _regenerating = true);
    try {
      final updated = await RemoteSummaryService.instance.api!
          .regenerateSummary(_summary.id);
      if (mounted) {
        setState(() => _summary = updated);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Summary regenerated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  Future<void> _keepLocalAudio() async {
    final recording = _localRecording;
    if (recording == null || _audioRetained) return;
    try {
      await RecordingRepository.instance.retainLocalAudio(recording);
      if (mounted) {
        setState(() => _audioRetained = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Original audio kept on this device.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transcript =
        _summary.correctedTranscript ??
        _summary.rawTranscript ??
        _summary.transcriptText;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcript Detail'),
        leading: BackButton(onPressed: widget.onBack),
        actions: [
          IconButton(
            onPressed: _editSummary,
            tooltip: 'Edit summary',
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _deleteSummary,
            tooltip: 'Delete summary',
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            onPressed: transcript?.isNotEmpty == true
                ? () async {
                    await Clipboard.setData(ClipboardData(text: transcript!));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transcript copied.')),
                      );
                    }
                  }
                : null,
            tooltip: 'Copy transcript',
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _summary.eventTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _summary.audioFilename,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _audioRetained ? _play : null,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
            label: const Text('Play audio'),
          ),
          const SizedBox(height: 20),
          Text(
            _audioRetained
                ? 'Original audio is retained on this device.'
                : 'Original audio is not retained on this device.',
            style: const TextStyle(color: Colors.grey),
          ),
          if (_audioRetained)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _deleteLocalAudio,
                child: const Text('Delete original audio from device'),
              ),
            ),
          if (!_audioRetained && _localRecording != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _keepLocalAudio,
                child: const Text('Keep original audio on device'),
              ),
            ),
          if (transcript?.trim().isNotEmpty == true)
            _section('Transcript', transcript!)
          else
            _emptySection('Transcript', 'No transcript is available.'),
          if (_summary.transcriptLanguage != null)
            Text(
              'Detected language: ${_summary.transcriptLanguage}',
              style: const TextStyle(color: Colors.grey),
            ),
          if (_summary.summary.trim().isNotEmpty)
            _section('AI Summary', _summary.summary),
          if (_summary.keyPoints.isNotEmpty)
            _listSection('Key Points', _summary.keyPoints),
          if (_summary.actionItems.isNotEmpty)
            _listSection('Action Items', _summary.actionItems),
          if (_summary.keywords.isNotEmpty)
            _listSection('Main Topics', _summary.keywords),
          if (_summary.category != null)
            Text(
              'Category: ${_summary.category}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _regenerating ? null : _regenerateSummary,
              icon: _regenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                _regenerating ? 'Regenerating...' : 'Regenerate summary',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(value),
      const SizedBox(height: 18),
    ],
  );

  Widget _emptySection(String title, String message) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(message, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 18),
    ],
  );

  Widget _listSection(String title, List<String> values) =>
      _section(title, values.map((value) => '• $value').join('\n'));
}
