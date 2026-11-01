import 'dart:async';

import 'package:flutter/material.dart';

import '../services/audio_api_service.dart';
import '../services/remote_summary_service.dart';
import '../models/recording.dart';
import '../widgets/processing_status_card.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onHomeTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onUploadTap;
  final VoidCallback? onProfileTap;
  final void Function(RemoteSummary summary)? onSummaryTap;
  final List<Recording> completedRecordings;
  final void Function(Recording recording)? onRecordingTap;
  final int currentIndex;
  final Key? refreshKey;
  final List<Recording> processingRecordings;
  final void Function(Recording recording)? onProcessingTap;
  final Future<void> Function(Recording recording)? onRetryProcessing;
  final Future<void> Function(Recording recording)? onDeleteProcessing;

  const HistoryScreen({
    super.key,
    this.onHomeTap,
    this.onHistoryTap,
    this.onUploadTap,
    this.onProfileTap,
    this.onSummaryTap,
    this.completedRecordings = const [],
    this.onRecordingTap,
    this.currentIndex = 1,
    this.refreshKey,
    this.processingRecordings = const [],
    this.onProcessingTap,
    this.onRetryProcessing,
    this.onDeleteProcessing,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();
  List<RemoteSummary> _items = [];
  bool _loading = true;
  String? _error;
  String? _mood;
  String? _actionStatus;
  int _offset = 0;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  Future<void> _load({bool append = false}) async {
    final api = RemoteSummaryService.instance.api;
    if (api == null) return;
    if (!append)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final page = await api.listSummaries(
        search: _search.text,
        category: null,
        mood: _mood,
        actionStatus: _actionStatus,
        offset: append ? _offset : 0,
      );
      if (!mounted) return;
      setState(() {
        _items = append ? [..._items, ...page] : page;
        _offset = _items.length;
        _hasMore = page.length == 20;
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.toString();
        });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE0EBFF)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 22,
                    color: Color(0xFF4C7FF0),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'History',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Search summaries...',
                  filled: true,
                  fillColor: const Color(0xFFF9FBFF),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _load,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDCE8FF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF8DAFFF),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _filter(
                    'All moods',
                    null,
                    (value) => setState(() {
                      _mood = value;
                      _load();
                    }),
                  ),
                  _filter(
                    'Positive',
                    'Positive',
                    (value) => setState(() {
                      _mood = value;
                      _load();
                    }),
                  ),
                  _filter(
                    'Neutral',
                    'Neutral',
                    (value) => setState(() {
                      _mood = value;
                      _load();
                    }),
                  ),
                  _filter(
                    'Negative',
                    'Negative',
                    (value) => setState(() {
                      _mood = value;
                      _load();
                    }),
                  ),
                  _filter(
                    'Pending',
                    'Pending',
                    (value) => setState(() {
                      _actionStatus = value;
                      _load();
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (widget.processingRecordings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Processing',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...widget.processingRecordings
                        .take(3)
                        .map(
                          (recording) => ProcessingStatusCard(
                            recording: recording,
                            onTap: () =>
                                widget.onProcessingTap?.call(recording),
                            onRetry: widget.onRetryProcessing == null
                                ? null
                                : () => widget.onRetryProcessing!(recording),
                            onDelete: widget.onDeleteProcessing == null
                                ? null
                                : () => widget.onDeleteProcessing!(recording),
                          ),
                        ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _items.isEmpty
                  ? const Center(child: Text('No summaries found'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        itemCount: _items.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _items.length) {
                            unawaited(_load(append: true));
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final item = _items[index];
                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE4EDFF)),
                            ),
                            child: ListTile(
                              onTap: () => widget.onSummaryTap?.call(item),
                              title: Text(
                                item.eventTitle,
                                style: const TextStyle(
                                  color: Color(0xFF376FD9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                item.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _NavigationBar(
        index: widget.currentIndex,
        onTap: (index) {
          if (index == 0) widget.onHomeTap?.call();
          if (index == 1) widget.onHistoryTap?.call();
          if (index == 2) widget.onUploadTap?.call();
          if (index == 3) widget.onProfileTap?.call();
        },
      ),
    );
  }

  Widget _filter(String label, String? value, ValueChanged<String?> onTap) {
    final selected = value == _mood || value == _actionStatus;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: const Color(0xFFEAF2FF),
        labelStyle: TextStyle(
          color: selected ? const Color(0xFF376FD9) : const Color(0xFF526071),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(
          color: selected ? const Color(0xFFBFD4FF) : const Color(0xFFE5EAF2),
        ),
        onSelected: (_) => onTap(value),
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _NavigationBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: Icons.grid_view_rounded, label: 'Home'),
      (icon: Icons.history_rounded, label: 'History'),
      (icon: Icons.arrow_upward_rounded, label: 'Upload'),
      (icon: Icons.person_outline_rounded, label: 'Profile'),
    ];

    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9EDF3))),
      ),
      child: Row(
        children: List.generate(items.length, (itemIndex) {
          final selected = index == itemIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(itemIndex),
              child: SizedBox(
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      items[itemIndex].icon,
                      size: 19,
                      color: selected
                          ? const Color(0xFF4C7FF0)
                          : const Color(0xFF667085),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[itemIndex].label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? const Color(0xFF4C7FF0)
                            : const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
