import 'dart:async';

import 'package:flutter/material.dart';

import '../models/recording.dart';
import '../services/microphone_service.dart';
import '../services/recording_repository.dart';
import '../services/backend_recording_service.dart';
import '../services/audio_storage_service.dart';

class RecordingScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final void Function(Recording recording)? onRecordingComplete;

  const RecordingScreen({super.key, this.onBack, this.onRecordingComplete});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final TextEditingController _titleController = TextEditingController();

  Timer? _timer;
  Duration _recordingDuration = Duration.zero;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isSaving = false;
  String _selectedEventType = 'Meeting';

  final List<String> _eventTypes = [
    'Lecture',
    'Meeting',
    'Interview',
    'Brainstorm',
    'Personal Note',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      await MicrophoneService.instance.startRecording();

      setState(() {
        _isRecording = true;
        _isPaused = false;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isPaused && mounted) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start recording: $e')));
    }
  }

  Future<void> _togglePause() async {
    if (_isPaused) {
      await MicrophoneService.instance.resumeRecording();
    } else {
      await MicrophoneService.instance.pauseRecording();
    }

    setState(() {
      _isPaused = !_isPaused;
    });
  }

  Future<void> _stopRecording() async {
    if (_recordingDuration.inSeconds < 1) {
      await MicrophoneService.instance.cancelRecording();
      _timer?.cancel();
      _timer = null;
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording too short. Please record again.'),
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    _timer?.cancel();
    _timer = null;

    try {
      final tempPath = await MicrophoneService.instance.stopRecording();

      if (tempPath == null) {
        throw Exception('No recording file was created');
      }

      final recording = await RecordingRepository.instance.saveRecordedAudio(
        tempFilePath: tempPath,
        title: _titleController.text.trim(),
        eventType: _selectedEventType,
        duration: _recordingDuration,
      );
      await BackendRecordingService.instance.uploadAndProcess(
        title: _titleController.text.trim().isEmpty
            ? 'Untitled Recording'
            : _titleController.text.trim(),
        category: _selectedEventType,
        filePath: AudioStorageService.instance.absolutePath(
          recording.audioPath,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isRecording = false;
        _isPaused = false;
        _isSaving = false;
      });

      widget.onRecordingComplete?.call(recording);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save recording: $e')));
    }
  }

  Future<void> _goBack() async {
    if (_isRecording) {
      await MicrophoneService.instance.cancelRecording();
    }
    _timer?.cancel();

    if (widget.onBack != null) {
      widget.onBack!();
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _getStatusText() {
    if (_isSaving) {
      return 'Saving recording...';
    }
    if (!_isRecording) {
      return 'Tap the microphone to start recording';
    }
    if (_isPaused) {
      return 'Recording paused';
    }
    return 'Recording in progress...';
  }

  @override
  Widget build(BuildContext context) {
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
                    onTap: _isSaving ? null : _goBack,
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
                  const Text(
                    'New Recording',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF101828),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Event Title',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF526071),
                      ),
                    ),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _titleController,
                      enabled: !_isRecording && !_isSaving,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'e.g. Weekly Engineering Sync',
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9BA3B1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFCFCFD),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E4EA),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E4EA),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF6195F2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Event Type',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF526071),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _eventTypes.map((type) {
                        return _EventTypeButton(
                          title: type,
                          selected: _selectedEventType == type,
                          enabled: !_isRecording && !_isSaving,
                          onTap: () {
                            setState(() => _selectedEventType = type);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 38),
                    Center(
                      child: _isSaving
                          ? const CircularProgressIndicator(
                              color: Color(0xFF6195F2),
                            )
                          : Text(
                              _formatDuration(_recordingDuration),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w300,
                                color: _isRecording
                                    ? const Color(0xFF6195F2)
                                    : const Color(0xFFD0D5DD),
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                    if (!_isRecording && !_isSaving)
                      _RecordButton(onTap: _startRecording)
                    else if (_isRecording)
                      _RecordingControls(
                        isPaused: _isPaused,
                        onPause: _togglePause,
                        onStop: _stopRecording,
                      ),
                    const SizedBox(height: 25),
                    Center(
                      child: Text(
                        _getStatusText(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9AA3B3),
                        ),
                      ),
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
}

class _EventTypeButton extends StatelessWidget {
  final String title;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _EventTypeButton({
    required this.title,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF6195F2) : const Color(0xFFE0E4EA),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: selected ? const Color(0xFF4D82EE) : const Color(0xFF526071),
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RecordButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
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
              BoxShadow(
                color: const Color(0xFF6195F2).withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.mic_none_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),
      ),
    );
  }
}

class _RecordingControls extends StatelessWidget {
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onStop;

  const _RecordingControls({
    required this.isPaused,
    required this.onPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onPause,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6195F2), width: 1.5),
            ),
            child: Icon(
              isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: const Color(0xFF6195F2),
              size: 29,
            ),
          ),
        ),
        const SizedBox(width: 25),
        GestureDetector(
          onTap: onStop,
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEEF0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stop_rounded,
              color: Color(0xFFE55A67),
              size: 31,
            ),
          ),
        ),
      ],
    );
  }
}
