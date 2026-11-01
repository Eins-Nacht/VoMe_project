import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../models/recording.dart';
import '../services/audio_api_service.dart';
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Transcript Detail'),
      leading: BackButton(onPressed: widget.onBack),
      actions: [
        IconButton(
          onPressed: _summary.transcriptText?.isNotEmpty == true
              ? () async {
                  await Clipboard.setData(
                    ClipboardData(text: _summary.transcriptText!),
                  );
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
        if (_summary.transcriptText?.trim().isNotEmpty == true)
          _section('Transcript', _summary.transcriptText!)
        else
          _emptySection('Transcript', 'No transcript is available.'),
        if (_summary.transcriptLanguage != null)
          Text(
            'Detected language: ${_summary.transcriptLanguage}',
            style: const TextStyle(color: Colors.grey),
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

  Widget _emptySection(String title, String message) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(message, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 18),
    ],
  );
}
