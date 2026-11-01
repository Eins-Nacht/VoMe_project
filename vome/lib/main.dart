import 'dart:async';

import 'package:flutter/material.dart';

import 'models/recording.dart';
import 'services/audio_api_service.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/processing_status_screen.dart';
import 'screens/recording_detail_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/transcript_review_screen.dart';
import 'services/audio_storage_service.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/recording_repository.dart';
import 'services/remote_summary_service.dart';
import 'services/processing_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  await AudioStorageService.instance.init();
  await AuthService.instance.restoreSession();
  await ProcessingService.instance.resumePendingJobs();
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

enum _AppScreen { login, home, recording, processing, review, detail }

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  _AppScreen _screen = _AppScreen.login;

  int _navIndex = 0;
  int _recordingsThisWeek = 0;
  Duration _totalRecordingTime = Duration.zero;
  List<Recording> _allRecordings = [];
  List<RemoteSummary> _recentSummaries = [];
  String? _summaryLoadError;
  String? _localStatsLoadError;
  RemoteSummary? _selectedSummary;
  Recording? _selectedRecording;
  Key _historyRefreshKey = UniqueKey();
  int _dashboardLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (AuthService.instance.isAuthenticated) {
      _screen = _AppScreen.home;
    }
    _loadDashboardData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        AuthService.instance.isAuthenticated) {
      _refreshData();
      unawaited(ProcessingService.instance.resumePendingJobs());
    }
  }

  Future<void> _loadDashboardData() async {
    final generation = ++_dashboardLoadGeneration;
    try {
      final count = await RecordingRepository.instance
          .countRecordingsThisWeek();
      final totalDuration = await RecordingRepository.instance
          .totalDurationThisWeek();
      final allRecordings = await RecordingRepository.instance
          .getAllRecordings();
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

      if (mounted && generation == _dashboardLoadGeneration) {
        setState(() {
          _recordingsThisWeek = count;
          _totalRecordingTime = totalDuration;
          _allRecordings = allRecordings;
          _localStatsLoadError = null;
          _recentSummaries = summaries;
          _summaryLoadError = summaryError;
        });
      }
    } catch (error) {
      if (mounted && generation == _dashboardLoadGeneration) {
        setState(() => _localStatsLoadError = error.toString());
      }
    }
  }

  void _refreshData() {
    unawaited(_loadDashboardData());
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

  void _openProcessingStatus() {
    setState(() => _screen = _AppScreen.processing);
  }

  List<Recording> get _processingRecordings => _allRecordings
      .where((recording) => recording.processingJobId != null)
      .toList();

  List<Recording> get _activeProcessingRecordings => _processingRecordings
      .where((recording) => recording.status != 'Completed')
      .toList();

  Future<void> _retryProcessing(Recording recording) async {
    await ProcessingService.instance.retry(recording);
    _refreshData();
  }

  Future<void> _deleteProcessing(Recording recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          recording.status == 'Pending' || recording.status == 'Processing'
              ? 'Cancel processing?'
              : 'Delete recording?',
        ),
        content: const Text(
          'This recording and its processing data will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
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
      await ProcessingService.instance.cancelAndDelete(recording);
      _refreshData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _openCompletedProcessing(Recording recording) async {
    try {
      final summary = await ProcessingService.instance.fetchResult(recording);
      if (summary != null && mounted) {
        if (recording.status == 'AwaitingDecision') {
          setState(() {
            _selectedRecording = recording;
            _screen = _AppScreen.review;
          });
        } else {
          _openRecordingDetail(summary);
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  void _closeRecording() {
    setState(() => _screen = _AppScreen.home);
    _refreshData();
  }

  void _onNavigationTap(int index) {
    setState(() => _navIndex = index);
    if (index == 0) {
      _refreshData();
    }
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
      _selectedRecording = null;
      _screen = _AppScreen.detail;
    });
  }

  void _closeRecordingDetail() {
    setState(() {
      _selectedSummary = null;
      _selectedRecording = null;
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
        _AppScreen.processing => ProcessingStatusScreen(
          recordings: _processingRecordings,
          onRefresh: () async {
            _refreshData();
          },
          onBack: () {
            setState(() => _screen = _AppScreen.home);
            _refreshData();
          },
          onRetry: _retryProcessing,
          onDelete: _deleteProcessing,
          onCompletedTap: _openCompletedProcessing,
        ),
        _AppScreen.review when _selectedRecording != null =>
          TranscriptReviewScreen(
            recording: _selectedRecording!,
            onBack: _closeRecordingDetail,
            onSummaryReady: (summary) async {
              _openRecordingDetail(summary);
              _refreshData();
            },
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
            processingRecordings: _activeProcessingRecordings,
            onProcessingTap: (_) => _openProcessingStatus(),
            onRetryProcessing: _retryProcessing,
            onDeleteProcessing: _deleteProcessing,
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
            localStatsLoadError: _localStatsLoadError,
            recentSummaries: _recentSummaries,
            summaryLoadError: _summaryLoadError,
            currentIndex: _navIndex,
            onNewRecording: _openRecording,
            onSeeAll: () => _onNavigationTap(1),
            onSummaryTap: _openRecordingDetail,
            processingRecordings: _activeProcessingRecordings,
            onProcessingTap: (_) => _openProcessingStatus(),
            onRetryProcessing: _retryProcessing,
            onDeleteProcessing: _deleteProcessing,
            onNavigationTap: _onNavigationTap,
          ),
        },
        _ => HomeScreen(
          recordingsThisWeek: _recordingsThisWeek,
          totalRecordingTime: _totalRecordingTime,
          localStatsLoadError: _localStatsLoadError,
          recentSummaries: _recentSummaries,
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
