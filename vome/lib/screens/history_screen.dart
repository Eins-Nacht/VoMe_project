import 'dart:async';

import 'package:flutter/material.dart';

import '../services/audio_api_service.dart';
import '../services/remote_summary_service.dart';
import '../services/recording_repository.dart';
import '../models/recording.dart';
import '../widgets/processing_status_card.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onHomeTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onUploadTap;
  final VoidCallback? onProfileTap;
  final void Function(RemoteSummary summary)? onSummaryTap;
  final int currentIndex;
  final Key? refreshKey;
  final List<Recording> processingRecordings;
  final void Function(Recording recording)? onProcessingTap;
  final Future<void> Function(Recording recording)? onRetryProcessing;

  const HistoryScreen({
    super.key,
    this.onHomeTap,
    this.onHistoryTap,
    this.onUploadTap,
    this.onProfileTap,
    this.onSummaryTap,
    this.currentIndex = 1,
    this.refreshKey,
    this.processingRecordings = const [],
    this.onProcessingTap,
    this.onRetryProcessing,
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

  Future<void> _delete(RemoteSummary item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete summary?'),
        content: Text('Delete the summary for "${item.eventTitle}"?'),
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
      await RemoteSummaryService.instance.api!.deleteSummary(item.id);
      await RecordingRepository.instance.deleteByClientRecordingId(
        item.clientRecordingId,
      );
      if (item.clientRecordingId == null) {
        await RecordingRepository.instance.deleteByAudioFilename(
          item.audioFilename,
        );
      }
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
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
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 14),
              child: Text(
                'History',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Search summaries...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _load,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
                            child: ListTile(
                              onTap: () => widget.onSummaryTap?.call(item),
                              title: Text(item.eventTitle),
                              subtitle: Text(
                                item.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _delete(item),
                              ),
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
  Widget build(BuildContext context) => BottomNavigationBar(
    currentIndex: index,
    onTap: onTap,
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
      BottomNavigationBarItem(icon: Icon(Icons.upload), label: 'Upload'),
      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    ],
  );
}
