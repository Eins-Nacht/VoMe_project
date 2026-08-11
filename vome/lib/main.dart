import 'package:flutter/material.dart';

import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/upload_screen.dart';

void main() {
  runApp(const AudiaryApp());
}

class AudiaryApp extends StatelessWidget {
  const AudiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vome',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6F95EB),
          primary: const Color(0xFF6F95EB),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const AppRoot(),
    );
  }
}

/// Call from [LoginScreen] after auth succeeds:
/// `AudiaryScope.of(context).signIn(username: email);`
class AudiaryScope extends InheritedWidget {
  const AudiaryScope({
    super.key,
    required this.signIn,
    required super.child,
  });

  final void Function({String? username}) signIn;

  static AudiaryScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AudiaryScope>();
    assert(scope != null, 'AudiaryScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AudiaryScope oldWidget) => false;
}

enum _AppScreen { login, home, recording }

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  _AppScreen _screen = _AppScreen.login;

  int _navIndex = 0;
  String _username = 'Alex';

  int _recordingsThisWeek = 3;
  Duration _totalRecordingTime = const Duration(hours: 3, minutes: 27);

  List<SummaryItem> _recentSummaries = const [
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
  ];

  void _signIn({String? username}) {
    setState(() {
      if (username != null && username.isNotEmpty) {
        final localPart = username.split('@').first;
        _username = localPart.isEmpty ? _username : localPart;
      }
      _screen = _AppScreen.home;
    });
  }

  void _openRecording() {
    setState(() => _screen = _AppScreen.recording);
  }

  void _closeRecording() {
    setState(() => _screen = _AppScreen.home);
  }

  void _onNavigationTap(int index) {
    setState(() => _navIndex = index);
  }

  void _onRecordingComplete({
    required String title,
    required String eventType,
    required Duration duration,
  }) {
    setState(() {
      _recordingsThisWeek += 1;
      _totalRecordingTime += duration;

      _recentSummaries = [
        SummaryItem(
          title: title.isEmpty ? 'Untitled Recording' : title,
          type: eventType,
          status: 'Pending',
          mood: 'Neutral',
          date: _formatDate(DateTime.now()),
          duration: _formatRecordingDuration(duration),
        ),
        ..._recentSummaries,
      ];

      _screen = _AppScreen.home;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AudiaryScope(
      signIn: _signIn,
      child: switch (_screen) {
        _AppScreen.login => const _LoginPage(),
        _AppScreen.recording => RecordingScreen(
            onBack: _closeRecording,
            onRecordingComplete: _onRecordingComplete,
          ),
        _AppScreen.home => switch (_navIndex) {
            1 => HistoryScreen(
                currentIndex: _navIndex,
                onHomeTap: () => _onNavigationTap(0),
                onHistoryTap: () => _onNavigationTap(1),
                onUploadTap: () => _onNavigationTap(2),
                onProfileTap: () => _onNavigationTap(3),
                onRecordingTap: (_) {
                  // TODO: open summary detail
                },
              ),
            2 => UploadScreen(
                onHomeTap: () => _onNavigationTap(0),
                onHistoryTap: () => _onNavigationTap(1),
                onUploadTap: () => _onNavigationTap(2),
                onProfileTap: () => _onNavigationTap(3),
              ),
            3 => _ProfileTab(
                currentIndex: _navIndex,
                onNavigationTap: _onNavigationTap,
              ),
            _ => HomeScreen(
                username: _username,
                recordingsThisWeek: _recordingsThisWeek,
                totalRecordingTime: _totalRecordingTime,
                recentSummaries: _recentSummaries,
                currentIndex: _navIndex,
                onNewRecording: _openRecording,
                onSummaryTap: (_) {
                  // TODO: open summary detail
                },
                onNavigationTap: _onNavigationTap,
              ),
          },
      },
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _formatRecordingDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }

    return '${minutes} min';
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.currentIndex,
    required this.onNavigationTap,
  });

  final int currentIndex;
  final void Function(int index) onNavigationTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: const SafeArea(
        child: Center(
          child: Text(
            'Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF101828),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _AppBottomNavigation(
        currentIndex: currentIndex,
        onTap: onNavigationTap,
      ),
    );
  }
}

class _AppBottomNavigation extends StatelessWidget {
  const _AppBottomNavigation({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final void Function(int index) onTap;

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
            onTap: () => onTap(index),
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
                      fontWeight:
                          selected ? FontWeight.w500 : FontWeight.w400,
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

/// Bridges [LoginScreen] to [AppRoot] until login_screen exposes an onSignIn callback.
class _LoginPage extends StatelessWidget {
  const _LoginPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const LoginScreen(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 282),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => AudiaryScope.of(context).signIn(),
                  child: const SizedBox(
                    width: double.infinity,
                    height: 72,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
