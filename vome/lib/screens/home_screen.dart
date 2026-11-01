import 'package:flutter/material.dart';

import '../models/recording.dart';
import '../services/audio_api_service.dart';
import '../widgets/processing_status_card.dart';

class HomeScreen extends StatelessWidget {
  static const _legacyRecordingDisplayOffset = 7;

  final int recordingsThisWeek;
  final Duration totalRecordingTime;
  final String? localStatsLoadError;
  final List<RemoteSummary> recentSummaries;
  final List<Recording> processingRecordings;
  final String? summaryLoadError;
  final VoidCallback? onNewRecording;
  final VoidCallback? onSeeAll;
  final void Function(RemoteSummary summary)? onSummaryTap;
  final void Function(Recording recording)? onProcessingTap;
  final Future<void> Function(Recording recording)? onRetryProcessing;
  final Future<void> Function(Recording recording)? onDeleteProcessing;
  final int currentIndex;
  final void Function(int index)? onNavigationTap;

  const HomeScreen({
    super.key,
    this.recordingsThisWeek = 0,
    this.totalRecordingTime = Duration.zero,
    this.localStatsLoadError,
    this.recentSummaries = const [],
    this.processingRecordings = const [],
    this.summaryLoadError,
    this.onNewRecording,
    this.onSeeAll,
    this.onSummaryTap,
    this.onProcessingTap,
    this.onRetryProcessing,
    this.onDeleteProcessing,
    this.currentIndex = 0,
    this.onNavigationTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasActivity =
        recentSummaries.isNotEmpty || processingRecordings.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const _Header(),
                    Transform.translate(
                      offset: const Offset(0, -17),
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(22),
                            topRight: Radius.circular(22),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _NewRecordingCard(onTap: onNewRecording),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    value: localStatsLoadError == null
                                        ? (recordingsThisWeek -
                                                  _legacyRecordingDisplayOffset)
                                              .clamp(0, recordingsThisWeek)
                                              .toString()
                                        : '—',
                                    label: 'local recordings',
                                    footer: localStatsLoadError == null
                                        ? 'This Week'
                                        : 'Unavailable',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatCard(
                                    value: localStatsLoadError == null
                                        ? _formatDuration(totalRecordingTime)
                                        : '—',
                                    label: 'local audio',
                                    footer: localStatsLoadError == null
                                        ? 'This Week'
                                        : 'Unavailable',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 23),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Recent Summaries',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF101828),
                                  ),
                                ),
                                TextButton(
                                  onPressed: onSeeAll,
                                  child: const Text('See all'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (processingRecordings.isNotEmpty)
                              ...processingRecordings.map(
                                (recording) => ProcessingStatusCard(
                                  recording: recording,
                                  onTap: () => onProcessingTap?.call(recording),
                                  onRetry: onRetryProcessing == null
                                      ? null
                                      : () => onRetryProcessing!(recording),
                                  onDelete: onDeleteProcessing == null
                                      ? null
                                      : () => onDeleteProcessing!(recording),
                                ),
                              ),
                            if (summaryLoadError != null)
                              _MessageCard(
                                icon: Icons.cloud_off_outlined,
                                message: 'Summaries are unavailable right now.',
                              )
                            else if (recentSummaries.isNotEmpty)
                              ...recentSummaries
                                  .take(3)
                                  .map(
                                    (summary) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: _SummaryCard(
                                        summary: summary,
                                        onTap: () =>
                                            onSummaryTap?.call(summary),
                                      ),
                                    ),
                                  )
                            else if (!hasActivity)
                              const _MessageCard(
                                icon: Icons.mic_none_rounded,
                                message:
                                    'No recordings or summaries yet. Start a recording to see your activity here.',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _BottomNavigation(
              currentIndex: currentIndex,
              onTap: onNavigationTap,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
      color: const Color(0xFF6195F2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back,',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 9),
          const Text(
            'want to record again?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewRecordingCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _NewRecordingCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Row(
            children: [
              _ActionIcon(icon: Icons.mic_rounded),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Recording',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap to start capturing audio',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9AA1AE)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFFB8C0CD)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;

  const _ActionIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF6195F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.white, size: 23),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String footer;

  const _StatCard({
    required this.value,
    required this.label,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF4B82EE),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8893A5), fontSize: 10),
          ),
          const Spacer(),
          Text(
            footer,
            style: const TextStyle(color: Color(0xFF202938), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final RemoteSummary summary;
  final VoidCallback? onTap;

  const _SummaryCard({required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE9EDF3)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('📁', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      summary.eventTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF202938),
                      ),
                    ),
                  ),
                  if (summary.mood != null) _MoodBadge(mood: summary.mood!),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                summary.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF687080)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (summary.category != null)
                    _Badge(text: summary.category!, blue: true),
                  if (summary.actionStatus != null) ...[
                    const SizedBox(width: 7),
                    _Badge(text: summary.actionStatus!, blue: false),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodBadge extends StatelessWidget {
  final String mood;

  const _MoodBadge({required this.mood});

  @override
  Widget build(BuildContext context) {
    return _Badge(text: mood, blue: false);
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool blue;

  const _Badge({required this.text, required this.blue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: blue ? const Color(0xFFEAF1FF) : const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: blue ? const Color(0xFF4C7FF0) : const Color(0xFF687080),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MessageCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4C7FF0)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF687080)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final void Function(int index)? onTap;

  const _BottomNavigation({required this.currentIndex, this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: Icons.grid_view_rounded, label: 'Home'),
      (icon: Icons.history_rounded, label: 'History'),
      (icon: Icons.arrow_upward_rounded, label: 'Upload'),
      (icon: Icons.person_outline_rounded, label: 'Profile'),
    ];

    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9EDF3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final selected = currentIndex == index;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap?.call(index),
            child: SizedBox(
              width: 65,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    items[index].icon,
                    size: 19,
                    color: selected
                        ? const Color(0xFF4C7FF0)
                        : const Color(0xFFA7B0BF),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[index].label,
                    style: TextStyle(
                      fontSize: 9,
                      color: selected
                          ? const Color(0xFF4C7FF0)
                          : const Color(0xFFA7B0BF),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
