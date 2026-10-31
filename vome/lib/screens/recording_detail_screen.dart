import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/audio_api_service.dart';
import '../services/remote_summary_service.dart';

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
  bool _saving = false;
  bool _deleting = false;
  Uint8List? _audioBytes;

  @override
  void initState() {
    super.initState();
    _summary = widget.summary;
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
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
      _audioBytes ??= await RemoteSummaryService.instance.api!.download(
        _summary.audioRecordId,
      );
      await _player.play(BytesSource(_audioBytes!));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _edit() async {
    final controller = TextEditingController(text: _summary.summary);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit summary'),
        content: TextField(controller: controller, maxLines: 5),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    setState(() => _saving = true);
    try {
      _summary = await RemoteSummaryService.instance.api!.updateSummary(
        _summary.id,
        summary: value,
      );
      if (mounted) setState(() => _saving = false);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete summary?'),
        content: const Text('This cannot be undone.'),
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
    setState(() => _deleting = true);
    try {
      await RemoteSummaryService.instance.api!.deleteSummary(_summary.id);
      widget.onDeleted?.call();
      widget.onBack?.call();
    } catch (error) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Summary Detail'),
      leading: BackButton(onPressed: widget.onBack),
      actions: [
        IconButton(
          onPressed: _saving ? null : _edit,
          icon: const Icon(Icons.edit),
        ),
        IconButton(
          onPressed: _deleting ? null : _delete,
          icon: const Icon(Icons.delete_outline),
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
          onPressed: _play,
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          label: const Text('Play audio'),
        ),
        const SizedBox(height: 20),
        _section('Summary', _summary.summary),
        _listSection('Key Points', _summary.keyPoints),
        _listSection('Action Items', _summary.actionItems),
        _listSection('Keywords', _summary.keywords),
        Wrap(
          spacing: 8,
          children: [
            if (_summary.category != null)
              Chip(label: Text(_summary.category!)),
            if (_summary.mood != null) Chip(label: Text(_summary.mood!)),
            if (_summary.actionStatus != null)
              Chip(label: Text(_summary.actionStatus!)),
          ],
        ),
      ],
    ),
  );

  Widget _section(String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(value),
      const SizedBox(height: 18),
    ],
  );

  Widget _listSection(String title, List<String> values) => _section(
    title,
    values.isEmpty ? 'None' : values.map((value) => '• $value').join('\n'),
  );
}
