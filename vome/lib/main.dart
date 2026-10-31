import 'package:flutter/material.dart';

import 'models/recording.dart';
import 'services/audio_api_service.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/recording_detail_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/upload_screen.dart';
import 'services/audio_storage_service.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/recording_repository.dart';
import 'services/remote_summary_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  await AudioStorageService.instance.init();
  await AuthService.instance.restoreSession();
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

class AudiaryScope extends InheritedWidget {
  const AudiaryScope({super.key, required this.signIn, required super.child});

  final void Function({String? username}) signIn;

  static AudiaryScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AudiaryScope>();
    assert(scope != null, 'AudiaryScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AudiaryScope oldWidget) => false;
}

enum _AppScreen { login, home, recording, detail }

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  _AppScreen _screen = _AppScreen.login;

  int _navIndex = 0;
  int _recordingsThisWeek = 0;
  Duration _totalRecordingTime = Duration.zero;
  List<Recording> _recentRecordings = [];
  List<RemoteSummary> _recentSummaries = [];
  String? _summaryLoadError;
  RemoteSummary? _selectedSummary;
  Key _historyRefreshKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (AuthService.instance.isAuthenticated) {
      _screen = _AppScreen.home;
    }
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final count = await RecordingRepository.instance
          .countRecordingsThisWeek();
      final totalDuration = await RecordingRepository.instance
          .totalDurationThisWeek();
      final recent = await RecordingRepository.instance.getRecentRecordings(
        limit: 10,
      );
      List<RemoteSummary> summaries = [];
      String? summaryError;
      final api = RemoteSummaryService.instance.api;
      if (api != null) {
        try {
          summaries = await api.listSummaries(limit: 3);
        } catch (_) {
          summaryError = 'unavailable';
        }
      }

      if (mounted) {
        setState(() {
          _recordingsThisWeek = count;
          _totalRecordingTime = totalDuration;
          _recentRecordings = recent;
          _recentSummaries = summaries;
          _summaryLoadError = summaryError;
        });
      }
    } catch (_) {
      // Local storage can be unavailable in the first frame or a new platform.
    }
  }

  void _refreshData() {
    _loadDashboardData();
    setState(() {
      _historyRefreshKey = UniqueKey();
    });
  }

  void _signIn({String? username}) {
    setState(() {
      _screen = _AppScreen.home;
    });
    _loadDashboardData();
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

  Future<void> _signOut() async {
    await AuthService.instance.logout();
    if (mounted) {
      setState(() {
        _screen = _AppScreen.login;
        _navIndex = 0;
      });
    }
  }

  void _openRecordingDetail(RemoteSummary summary) {
    setState(() {
      _selectedSummary = summary;
      _screen = _AppScreen.detail;
    });
  }

  void _closeRecordingDetail() {
    setState(() {
      _selectedSummary = null;
      _screen = _AppScreen.home;
    });
    _refreshData();
  }

  void _onRecordingComplete(Recording recording) {
    _refreshData();
    setState(() => _screen = _AppScreen.home);
  }

  void _onUploadComplete(Recording recording) {
    _refreshData();
    setState(() => _navIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    return AudiaryScope(
      signIn: _signIn,
      child: switch (_screen) {
        _AppScreen.login => LoginScreen(onAuthenticated: _signIn),
        _AppScreen.recording => RecordingScreen(
          onBack: _closeRecording,
          onRecordingComplete: _onRecordingComplete,
        ),
        _AppScreen.detail when _selectedSummary != null =>
          RecordingDetailScreen(
            summary: _selectedSummary!,
            onBack: _closeRecordingDetail,
            onDeleted: _closeRecordingDetail,
          ),
        _AppScreen.home => switch (_navIndex) {
          1 => HistoryScreen(
            key: _historyRefreshKey,
            refreshKey: _historyRefreshKey,
            currentIndex: _navIndex,
            onHomeTap: () => _onNavigationTap(0),
            onHistoryTap: () => _onNavigationTap(1),
            onUploadTap: () => _onNavigationTap(2),
            onProfileTap: () => _onNavigationTap(3),
            onSummaryTap: _openRecordingDetail,
          ),
          2 => UploadScreen(
            onHomeTap: () => _onNavigationTap(0),
            onHistoryTap: () => _onNavigationTap(1),
            onUploadTap: () => _onNavigationTap(2),
            onProfileTap: () => _onNavigationTap(3),
            onUploadComplete: _onUploadComplete,
          ),
          3 => _ProfileTab(
            currentIndex: _navIndex,
            onNavigationTap: _onNavigationTap,
            onLogout: _signOut,
          ),
          _ => HomeScreen(
            recordingsThisWeek: _recordingsThisWeek,
            totalRecordingTime: _totalRecordingTime,
            recentSummaries: _recentSummaries,
            processingRecordings: _recentRecordings
                .where(
                  (recording) =>
                      recording.status != 'Completed' &&
                      recording.status != 'Failed',
                )
                .toList(),
            summaryLoadError: _summaryLoadError,
            currentIndex: _navIndex,
            onNewRecording: _openRecording,
            onSeeAll: () => _onNavigationTap(1),
            onSummaryTap: _openRecordingDetail,
            onNavigationTap: _onNavigationTap,
          ),
        },
        _ => HomeScreen(
          recordingsThisWeek: _recordingsThisWeek,
          totalRecordingTime: _totalRecordingTime,
          recentSummaries: _recentSummaries,
          processingRecordings: _recentRecordings
              .where(
                (recording) =>
                    recording.status != 'Completed' &&
                    recording.status != 'Failed',
              )
              .toList(),
          summaryLoadError: _summaryLoadError,
          currentIndex: _navIndex,
          onNewRecording: _openRecording,
          onSeeAll: () => _onNavigationTap(1),
          onSummaryTap: _openRecordingDetail,
          onNavigationTap: _onNavigationTap,
        ),
      },
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.currentIndex,
    required this.onNavigationTap,
    required this.onLogout,
  });

  final int currentIndex;
  final void Function(int index) onNavigationTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF101828),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ],
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
  const _AppBottomNavigation({required this.currentIndex, required this.onTap});

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
