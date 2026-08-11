import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  // ============================================================
  // USER DATA
  // ============================================================

  final String username;

  // จำนวน recordings ในสัปดาห์นี้
  final int recordingsThisWeek;

  // เวลารวมที่บันทึกในสัปดาห์นี้
  final Duration totalRecordingTime;

  // Summary ล่าสุด
  final List<SummaryItem> recentSummaries;

  // ปุ่ม New Recording
  final VoidCallback? onNewRecording;

  // เมื่อกด Summary
  final void Function(SummaryItem summary)? onSummaryTap;

  // Bottom Navigation
  final int currentIndex;
  final void Function(int index)? onNavigationTap;

  const HomeScreen({
    super.key,

    required this.username,

    this.recordingsThisWeek = 3,

    this.totalRecordingTime = const Duration(
      hours: 3,
      minutes: 27,
    ),

    this.recentSummaries = const [
      SummaryItem(
        title: 'Weekly Eng Sync',
        type: 'Meeting',
        status: 'Pending',
        mood: 'Positive',
        date: '4 Aug 2026',
        duration: '48 min',
      ),
      SummaryItem(
        title: 'ML Lecture — Transformers',
        type: 'Lecture',
        status: 'No Action',
        mood: 'Neutral',
        date: '3 Aug 2026',
        duration: '1h 12min',
      ),
      SummaryItem(
        title: 'Product Strategy Call',
        type: 'Meeting',
        status: 'Completed',
        mood: 'Positive',
        date: '1 Aug 2026',
        duration: '35 min',
      ),
    ],

    this.onNewRecording,
    this.onSummaryTap,

    this.currentIndex = 0,
    this.onNavigationTap,
  });

  @override
  Widget build(BuildContext context) {
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
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ==========================================
                    // BLUE HEADER
                    // ==========================================

                    _Header(
                      username: username,
                    ),

                    // ==========================================
                    // CONTENT
                    // ==========================================

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

                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            18,
                            0,
                            18,
                            25,
                          ),

                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [
                              // ==================================
                              // NEW RECORDING
                              // ==================================

                              _NewRecordingCard(
                                onTap: onNewRecording,
                              ),

                              const SizedBox(height: 18),

                              // ==================================
                              // STATISTICS
                              // ==================================

                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      value:
                                          recordingsThisWeek
                                              .toString(),

                                      label: 'recordings',

                                      footer: 'This Week',
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: _StatCard(
                                      value:
                                          _formatDuration(
                                        totalRecordingTime,
                                      ),

                                      label: 'captured',

                                      footer: 'Total Time',
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 23),

                              // ==================================
                              // RECENT SUMMARIES TITLE
                              // ==================================

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,

                                children: [
                                  const Text(
                                    'Recent Summaries',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w600,
                                      color:
                                          Color(0xFF101828),
                                    ),
                                  ),

                                  GestureDetector(
                                    onTap: () {
                                      // TODO:
                                      // ไปหน้า History / All Summaries
                                    },

                                    child: const Text(
                                      'See all',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            Color(0xFF4C7FF0),
                                        fontWeight:
                                            FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // ==================================
                              // RECENT SUMMARIES
                              // ==================================

                              ...recentSummaries
                                  .take(3)
                                  .map(
                                    (summary) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets
                                                .only(
                                          bottom: 10,
                                        ),

                                        child:
                                            _SummaryCard(
                                          summary: summary,

                                          onTap: () {
                                            onSummaryTap
                                                ?.call(
                                              summary,
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // BOTTOM NAVIGATION
            // ==================================================

            _BottomNavigation(
              currentIndex: currentIndex,
              onTap: onNavigationTap,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORMAT DURATION
  // ============================================================

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }
}


// ================================================================
// HEADER
// ================================================================

class _Header extends StatelessWidget {
  final String username;

  const _Header({
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(
        22,
        18,
        22,
        34,
      ),

      decoration: const BoxDecoration(
        color: Color(0xFF6195F2),

        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // Good morning + notification
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,

            children: [
              const Text(
                'Good morning ☀️',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),

              Container(
                width: 32,
                height: 32,

                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons.notifications_rounded,
                  size: 17,
                  color: Color(0xFFFFD76A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          // Hello, username
          Text(
            'Hello, $username 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          // Saved summaries
          Text(
            'You have 4 saved summaries',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}


// ================================================================
// NEW RECORDING CARD
// ================================================================

class _NewRecordingCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _NewRecordingCard({
    this.onTap,
  });

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
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),

          child: Row(
            children: [
              // Microphone
              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color: const Color(0xFF6195F2),
                  borderRadius:
                      BorderRadius.circular(14),

                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6195F2)
                          .withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),

                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),

              const SizedBox(width: 15),

              // Text
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      'New Recording',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),

                    SizedBox(height: 4),

                    Text(
                      'Tap to start capturing audio',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9AA1AE),
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB8C0CD),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ================================================================
// STAT CARD
// ================================================================

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

      padding: const EdgeInsets.fromLTRB(
        14,
        10,
        10,
        9,
      ),

      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(12),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

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
            style: const TextStyle(
              color: Color(0xFF8893A5),
              fontSize: 10,
            ),
          ),

          const Spacer(),

          Text(
            footer,
            style: const TextStyle(
              color: Color(0xFF202938),
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}


// ================================================================
// SUMMARY CARD
// ================================================================

class _SummaryCard extends StatelessWidget {
  final SummaryItem summary;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.summary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(14),

        child: Container(
          width: double.infinity,

          padding: const EdgeInsets.fromLTRB(
            14,
            12,
            14,
            11,
          ),

          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFFE9EDF3),
              width: 1,
            ),

            borderRadius: BorderRadius.circular(14),
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // ================================================
              // TITLE + MOOD
              // ================================================

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center,

                children: [
                  const Text(
                    '📁',
                    style: TextStyle(
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(width: 7),

                  Expanded(
                    child: Text(
                      summary.title,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w600,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ),

                  const SizedBox(width: 5),

                  _MoodBadge(
                    mood: summary.mood,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ================================================
              // TYPE + STATUS
              // ================================================

              Row(
                children: [
                  _TypeBadge(
                    text: summary.type,
                  ),

                  const SizedBox(width: 7),

                  _StatusBadge(
                    text: summary.status,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ================================================
              // DATE + DURATION
              // ================================================

              Text(
                '${summary.date} · ${summary.duration}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF919AAA),
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
// MOOD BADGE
// ================================================================

class _MoodBadge extends StatelessWidget {
  final String mood;

  const _MoodBadge({
    required this.mood,
  });

  @override
  Widget build(BuildContext context) {
    final bool positive =
        mood.toLowerCase() == 'positive';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),

      decoration: BoxDecoration(
        color: positive
            ? const Color(0xFFE9FAF1)
            : const Color(0xFFF3F3F5),

        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Container(
            width: 5,
            height: 5,

            decoration: BoxDecoration(
              color: positive
                  ? const Color(0xFF35C77A)
                  : const Color(0xFF9AA0AA),

              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 4),

          Text(
            mood,
            style: TextStyle(
              fontSize: 9,
              color: positive
                  ? const Color(0xFF22965A)
                  : const Color(0xFF687080),
            ),
          ),
        ],
      ),
    );
  }
}


// ================================================================
// TYPE BADGE
// ================================================================

class _TypeBadge extends StatelessWidget {
  final String text;

  const _TypeBadge({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),

      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 9,
            color: Color(0xFF4C7FF0),
          ),

          const SizedBox(width: 3),

          Text(
            text,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF4C7FF0),
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
  final String text;

  const _StatusBadge({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final bool completed =
        text.toLowerCase() == 'completed';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),

      decoration: BoxDecoration(
        color: completed
            ? const Color(0xFFE8F8EF)
            : const Color(0xFFFFF7E2),

        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(
            completed
                ? Icons.check_box_outlined
                : Icons.circle,
            size: 9,

            color: completed
                ? const Color(0xFF25A765)
                : const Color(0xFFD69B26),
          ),

          const SizedBox(width: 3),

          Text(
            text,
            style: TextStyle(
              fontSize: 9,

              color: completed
                  ? const Color(0xFF22965A)
                  : const Color(0xFFB27A16),
            ),
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

  const _BottomNavigation({
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        icon: Icons.grid_view_rounded,
        label: 'Home',
      ),
      (
        icon: Icons.history_rounded,
        label: 'History',
      ),
      (
        icon: Icons.arrow_upward_rounded,
        label: 'Upload',
      ),
      (
        icon: Icons.person_outline_rounded,
        label: 'Profile',
      ),
    ];

    return Container(
      height: 68,

      decoration: const BoxDecoration(
        color: Colors.white,

        border: Border(
          top: BorderSide(
            color: Color(0xFFE9EDF3),
            width: 1,
          ),
        ),
      ),

      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround,

        children: List.generate(
          items.length,
          (index) {
            final selected =
                currentIndex == index;

            return GestureDetector(
              onTap: () {
                onTap?.call(index);
              },

              behavior:
                  HitTestBehavior.opaque,

              child: SizedBox(
                width: 65,

                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,

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

                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


// ================================================================
// DATA MODEL
// ================================================================

class SummaryItem {
  final String title;
  final String type;
  final String status;
  final String mood;
  final String date;
  final String duration;

  const SummaryItem({
    required this.title,
    required this.type,
    required this.status,
    required this.mood,
    required this.date,
    required this.duration,
  });
}