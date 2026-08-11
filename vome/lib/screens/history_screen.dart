import 'package:flutter/material.dart';

class HistoryScreen extends StatefulWidget {
  /// กด Home จาก Bottom Navigation
  final VoidCallback? onHomeTap;

  /// กด History จาก Bottom Navigation
  final VoidCallback? onHistoryTap;

  /// กด Upload จาก Bottom Navigation
  final VoidCallback? onUploadTap;

  /// กด Profile จาก Bottom Navigation
  final VoidCallback? onProfileTap;

  /// กดรายการ Recording เพื่อไปหน้า Detail
  final void Function(RecordingItem recording)? onRecordingTap;

  /// Bottom Navigation index ปัจจุบัน
  final int currentIndex;

  const HistoryScreen({
    super.key,
    this.onHomeTap,
    this.onHistoryTap,
    this.onUploadTap,
    this.onProfileTap,
    this.onRecordingTap,
    this.currentIndex = 1,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // ============================================================
  // SEARCH
  // ============================================================

  final TextEditingController _searchController = TextEditingController();

  // ============================================================
  // FILTER
  // ============================================================

  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Meeting',
    'Lecture',
    'Interview',
    'Brainstorm',
    'Personal Note',
  ];

  // ============================================================
  // LOCAL RECORDINGS
  // ============================================================
  //
  // ตอนนี้ใช้ข้อมูลตัวอย่างก่อน
  //
  // ภายหลังสามารถเปลี่ยนตรงนี้เป็นข้อมูลจาก
  // SQLite / Hive / Isar / SharedPreferences ได้
  //
  // ============================================================

  final List<RecordingItem> _recordings = [
    RecordingItem(
      id: '1',
      title: 'Weekly Eng Sync',
      type: 'Meeting',
      category: 'Software Engineering',
      mood: 'Positive',
      status: 'Pending',
      date: '4 Aug 2026',
      duration: '48 min',
    ),

    RecordingItem(
      id: '2',
      title: 'ML Lecture — Transformers',
      type: 'Lecture',
      category: 'Machine Learning',
      mood: 'Neutral',
      status: 'No Action',
      date: '3 Aug 2026',
      duration: '1h 12min',
    ),

    RecordingItem(
      id: '3',
      title: 'Product Strategy Call',
      type: 'Meeting',
      category: 'Product',
      mood: 'Positive',
      status: 'Completed',
      date: '1 Aug 2026',
      duration: '35 min',
    ),

    RecordingItem(
      id: '4',
      title: 'Candidate Interview — UX',
      type: 'Interview',
      category: 'HR',
      mood: 'Positive',
      status: 'Pending',
      date: '30 Jul 2026',
      duration: '52 min',
    ),

    RecordingItem(
      id: '5',
      title: 'App Feature Brainstorm',
      type: 'Brainstorm',
      category: 'Product',
      mood: 'Positive',
      status: 'Completed',
      date: '29 Jul 2026',
      duration: '42 min',
    ),

    RecordingItem(
      id: '6',
      title: 'Personal Thoughts',
      type: 'Personal Note',
      category: 'Personal',
      mood: 'Neutral',
      status: 'No Action',
      date: '28 Jul 2026',
      duration: '18 min',
    ),
  ];

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // FILTER RECORDINGS
  // ============================================================

  List<RecordingItem> get _filteredRecordings {
    final searchText = _searchController.text.trim().toLowerCase();

    return _recordings.where((recording) {
      // Filter ประเภท
      final matchesType =
          _selectedFilter == 'All' || recording.type == _selectedFilter;

      // Search
      final matchesSearch =
          searchText.isEmpty ||
          recording.title.toLowerCase().contains(searchText) ||
          recording.category.toLowerCase().contains(searchText);

      return matchesType && matchesSearch;
    }).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final recordings = _filteredRecordings;

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        bottom: false,

        child: Column(
          children: [
            // ==================================================
            // MAIN CONTENT
            // ==================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // ==========================================
                  // TITLE
                  // ==========================================
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 0),

                    child: Text(
                      'History',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ==========================================
                  // SEARCH
                  // ==========================================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),

                    child: _SearchBar(
                      controller: _searchController,

                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ==========================================
                  // FILTER
                  // ==========================================
                  SizedBox(
                    height: 34,

                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),

                      scrollDirection: Axis.horizontal,

                      itemCount: _filters.length,

                      separatorBuilder: (_, __) => const SizedBox(width: 8),

                      itemBuilder: (context, index) {
                        final filter = _filters[index];

                        return _FilterChip(
                          label: filter,

                          selected: _selectedFilter == filter,

                          onTap: () {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==========================================
                  // RECORDING LIST
                  // ==========================================
                  Expanded(
                    child: recordings.isEmpty
                        ? const _EmptyHistory()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),

                            itemCount: recordings.length,

                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),

                            itemBuilder: (context, index) {
                              final recording = recordings[index];

                              return _HistoryCard(
                                recording: recording,

                                onTap: () {
                                  widget.onRecordingTap?.call(recording);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // BOTTOM NAVIGATION
            // ==================================================
            _BottomNavigation(
              currentIndex: widget.currentIndex,

              onTap: (index) {
                if (index == 0) {
                  widget.onHomeTap?.call();
                }

                if (index == 1) {
                  widget.onHistoryTap?.call();
                }

                if (index == 2) {
                  widget.onUploadTap?.call();
                }

                if (index == 3) {
                  widget.onProfileTap?.call();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SEARCH BAR
// ================================================================

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const _SearchBar({required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,

      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(10),
      ),

      child: TextField(
        controller: controller,
        onChanged: onChanged,

        style: const TextStyle(fontSize: 12, color: Color(0xFF344054)),

        decoration: const InputDecoration(
          border: InputBorder.none,

          prefixIcon: Icon(
            Icons.search_rounded,
            size: 16,
            color: Color(0xFF98A2B3),
          ),

          hintText: 'Search recordings...',

          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF98A2B3)),

          contentPadding: EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}

// ================================================================
// FILTER CHIP
// ================================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),

        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF2FF) : Colors.white,

          borderRadius: BorderRadius.circular(20),

          border: Border.all(
            color: selected ? const Color(0xFF6195F2) : const Color(0xFFE0E4EA),
          ),
        ),

        child: Text(
          label,

          style: TextStyle(
            fontSize: 11,

            color: selected ? const Color(0xFF4C7FF0) : const Color(0xFF526071),

            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// HISTORY CARD
// ================================================================

class _HistoryCard extends StatelessWidget {
  final RecordingItem recording;
  final VoidCallback? onTap;

  const _HistoryCard({required this.recording, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(14),

        child: Container(
          width: double.infinity,

          padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),

          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8ECF2)),

            borderRadius: BorderRadius.circular(14),
          ),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ================================================
              // FOLDER ICON
              // ================================================
              Container(
                width: 36,
                height: 36,

                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),

                child: const Center(
                  child: Text('📁', style: TextStyle(fontSize: 17)),
                ),
              ),

              const SizedBox(width: 11),

              // ================================================
              // CONTENT
              // ================================================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // Title
                    Text(
                      recording.title,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF101828),
                      ),
                    ),

                    const SizedBox(height: 7),

                    // Type + Category
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,

                      children: [
                        _SmallBadge(
                          icon: Icons.subdirectory_arrow_right_rounded,
                          text: recording.type,
                          color: const Color(0xFF4C7FF0),
                          background: const Color(0xFFEAF2FF),
                        ),

                        _SmallBadge(
                          icon: Icons.folder_open_rounded,
                          text: recording.category,
                          color: const Color(0xFF475467),
                          background: const Color(0xFFF1F3F5),
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    // Mood + Status
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,

                      children: [
                        _MoodBadge(mood: recording.mood),

                        _StatusBadge(status: recording.status),
                      ],
                    ),

                    const SizedBox(height: 7),

                    // Date
                    Text(
                      '${recording.date} · ${recording.duration}',

                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF98A2B3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SMALL BADGE
// ================================================================

class _SmallBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  const _SmallBadge({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),

      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, size: 8, color: color),

          const SizedBox(width: 3),

          Text(text, style: TextStyle(fontSize: 9, color: color)),
        ],
      ),
    );
  }
}

// ================================================================
// MOOD BADGE
// ================================================================

class _MoodBadge extends StatelessWidget {
  final String mood;

  const _MoodBadge({required this.mood});

  @override
  Widget build(BuildContext context) {
    final isPositive = mood.toLowerCase() == 'positive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),

      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFE8F8EF) : const Color(0xFFF2F3F5),

        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Container(
            width: 5,
            height: 5,

            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFF27AE68)
                  : const Color(0xFF98A2B3),

              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 4),

          Text(
            mood,

            style: TextStyle(
              fontSize: 9,

              color: isPositive
                  ? const Color(0xFF209557)
                  : const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// STATUS BADGE
// ================================================================

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isCompleted = status.toLowerCase() == 'completed';

    final isPending = status.toLowerCase() == 'pending';

    Color background;
    Color foreground;
    IconData icon;

    if (isCompleted) {
      background = const Color(0xFFE8F8EF);
      foreground = const Color(0xFF209557);
      icon = Icons.check_box_rounded;
    } else if (isPending) {
      background = const Color(0xFFFFF5DC);
      foreground = const Color(0xFFB47B16);
      icon = Icons.circle;
    } else {
      background = const Color(0xFFF1F2F4);
      foreground = const Color(0xFF667085);
      icon = Icons.square;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),

      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, size: 8, color: foreground),

          const SizedBox(width: 4),

          Text(status, style: TextStyle(fontSize: 9, color: foreground)),
        ],
      ),
    );
  }
}

// ================================================================
// EMPTY HISTORY
// ================================================================

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade300),

          const SizedBox(height: 12),

          const Text(
            'No recordings found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667085),
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Try another search or filter',
            style: TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// BOTTOM NAVIGATION
// ================================================================

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

        border: Border(top: BorderSide(color: Color(0xFFE9EDF3), width: 1)),
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,

        children: List.generate(items.length, (index) {
          final selected = currentIndex == index;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,

            onTap: () {
              onTap?.call(index);
            },

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

                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
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

// ================================================================
// RECORDING DATA MODEL
// ================================================================

class RecordingItem {
  final String id;
  final String title;
  final String type;
  final String category;
  final String mood;
  final String status;
  final String date;
  final String duration;

  const RecordingItem({
    required this.id,
    required this.title,
    required this.type,
    required this.category,
    required this.mood,
    required this.status,
    required this.date,
    required this.duration,
  });
}
