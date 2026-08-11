import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class UploadScreen extends StatefulWidget {
  // Bottom navigation callbacks
  final VoidCallback? onHomeTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onUploadTap;
  final VoidCallback? onProfileTap;

  const UploadScreen({
    super.key,
    this.onHomeTap,
    this.onHistoryTap,
    this.onUploadTap,
    this.onProfileTap,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  // ============================================================
  // TEXT CONTROLLER
  // ============================================================

  final TextEditingController _titleController = TextEditingController();

  // ============================================================
  // SELECTED FILE
  // ============================================================

  PlatformFile? _selectedFile;

  // ============================================================
  // EVENT TYPE
  // ============================================================

  String? _selectedType;

  final List<String> _eventTypes = [
    'Lecture',
    'Meeting',
    'Interview',
    'Brainstorm',
    'Personal Note',
    'Other',
  ];

  // ============================================================
  // STATE
  // ============================================================

  bool _isPickingFile = false;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ============================================================
  // PICK AUDIO FILE
  // ============================================================
  Future<void> _pickAudioFile() async {
    if (_isPickingFile) {
      return;
    }

    // ----------------------------------------------------------
    // SHOW OUR OWN CONFIRMATION DIALOG
    // ----------------------------------------------------------

    final bool? allowed = await _showFileAccessDialog();

    if (allowed != true) {
      return;
    }

    // ----------------------------------------------------------
    // START PICKING
    // ----------------------------------------------------------

    setState(() {
      _isPickingFile = true;
    });

    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav'],
        allowMultiple: false,
        withData: false,
      );

      // User cancelled
      if (result == null) {
        return;
      }

      if (result.files.isEmpty) {
        return;
      }

      final PlatformFile file = result.files.first;

      // --------------------------------------------------------
      // SAVE FILE
      // --------------------------------------------------------

      setState(() {
        _selectedFile = file;
      });

      // Debug
      debugPrint('Selected file: ${file.name}');
      debugPrint('File path: ${file.path}');
      debugPrint('File size: ${file.size}');
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to select audio file: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  // ============================================================
  // CUSTOM PERMISSION / ACCESS DIALOG
  // ============================================================

  Future<bool?> _showFileAccessDialog() {
    return showDialog<bool>(
      context: context,

      barrierDismissible: false,

      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),

          content: const Text(
            'Audiary needs access to files on your '
            'device to select an audio recording.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },

              child: const Text('Cancel'),
            ),

            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },

              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // REMOVE SELECTED FILE
  // ============================================================

  void _removeFile() {
    setState(() {
      _selectedFile = null;
    });
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool get _canCreateSummary {
    return _selectedFile != null &&
        _titleController.text.trim().isNotEmpty &&
        _selectedType != null;
  }

  // ============================================================
  // CREATE SUMMARY
  // ============================================================

  void _createSummary() {
    if (!_canCreateSummary) {
      return;
    }

    final String title = _titleController.text.trim();

    final String eventType = _selectedType!;

    final PlatformFile file = _selectedFile!;

    // ----------------------------------------------------------
    // TODO:
    //
    // ตรงนี้เอาไว้เชื่อม FastAPI ในภายหลัง
    //
    // file.path
    // title
    // eventType
    //
    // ----------------------------------------------------------

    debugPrint('================================');

    debugPrint('CREATE SUMMARY');

    debugPrint('Title: $title');

    debugPrint('Event Type: $eventType');

    debugPrint('File Name: ${file.name}');

    debugPrint('File Path: ${file.path}');

    debugPrint('File Size: ${file.size}');

    debugPrint('================================');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audio is ready to be processed.')),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

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
                physics: const BouncingScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ==========================================
                    // PAGE TITLE
                    // ==========================================
                    const Text(
                      'Upload Audio',

                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101828),
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Have an existing recording? Upload it and let AI turn\n'
                      'it into a structured summary.',

                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF667085),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // UPLOAD AREA
                    // ==========================================
                    GestureDetector(
                      onTap: _isPickingFile ? null : _pickAudioFile,

                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),

                        width: double.infinity,

                        height: 213,

                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),

                          borderRadius: BorderRadius.circular(17),

                          border: Border.all(
                            color: const Color(0xFFA7C5FF),

                            width: 1,
                          ),
                        ),

                        child: _buildUploadArea(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==========================================
                    // DIVIDER
                    // ==========================================
                    const Divider(height: 1, color: Color(0xFFE8ECF2)),

                    const SizedBox(height: 18),

                    // ==========================================
                    // EVENT TITLE
                    // ==========================================
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

                      onChanged: (_) {
                        setState(() {});
                      },

                      textInputAction: TextInputAction.done,

                      decoration: InputDecoration(
                        hintText: 'Enter event title',

                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF98A2B3),
                        ),

                        filled: true,

                        fillColor: const Color(0xFFFCFCFD),

                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),

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

                            width: 1.2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // EVENT TYPE
                    // ==========================================
                    const Text(
                      'Event Type',

                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF526071),
                      ),
                    ),

                    const SizedBox(height: 9),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,

                      children: _eventTypes.map((String type) {
                        return _EventTypeChip(
                          label: type,

                          selected: _selectedType == type,

                          onTap: () {
                            setState(() {
                              _selectedType = type;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 22),

                    // ==========================================
                    // CREATE SUMMARY BUTTON
                    // ==========================================
                    SizedBox(
                      width: double.infinity,

                      height: 38,

                      child: ElevatedButton(
                        onPressed: _canCreateSummary ? _createSummary : null,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6195F2),

                          disabledBackgroundColor: const Color(0xFFE1E4E9),

                          disabledForegroundColor: const Color(0xFF98A2B3),

                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),

                        child: const Text(
                          'Create Summary',

                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
              currentIndex: 2,

              onHomeTap: widget.onHomeTap,

              onHistoryTap: widget.onHistoryTap,

              onUploadTap: widget.onUploadTap,

              onProfileTap: widget.onProfileTap,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // UPLOAD AREA UI
  // ============================================================

  Widget _buildUploadArea() {
    // ----------------------------------------------------------
    // NO FILE SELECTED
    // ----------------------------------------------------------

    if (_selectedFile == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Container(
            width: 58,
            height: 58,

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(16),

              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6195F2).withValues(alpha: 0.12),

                  blurRadius: 15,

                  offset: const Offset(0, 5),
                ),
              ],
            ),

            child: _isPickingFile
                ? const Padding(
                    padding: EdgeInsets.all(17),

                    child: CircularProgressIndicator(
                      strokeWidth: 2,

                      color: Color(0xFF6195F2),
                    ),
                  )
                : const Icon(
                    Icons.file_upload_outlined,

                    color: Color(0xFF4F8BF5),

                    size: 28,
                  ),
          ),

          const SizedBox(height: 14),

          Text(
            _isPickingFile ? 'Opening Files...' : 'Upload Audio File',

            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF101828),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Choose an audio file from your device',

            style: TextStyle(fontSize: 11, color: Color(0xFF667085)),
          ),

          const SizedBox(height: 8),

          const Text(
            'Supports MP3, M4A, WAV',

            style: TextStyle(fontSize: 10, color: Color(0xFF98A2B3)),
          ),
        ],
      );
    }

    // ----------------------------------------------------------
    // FILE SELECTED
    // ----------------------------------------------------------

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,

      children: [
        Container(
          width: 58,
          height: 58,

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(16),

            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6195F2).withValues(alpha: 0.12),

                blurRadius: 15,

                offset: const Offset(0, 5),
              ),
            ],
          ),

          child: const Icon(
            Icons.audio_file_outlined,

            color: Color(0xFF4F8BF5),

            size: 28,
          ),
        ),

        const SizedBox(height: 14),

        const Text(
          'Audio File Selected',

          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF101828),
          ),
        ),

        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),

          child: Text(
            _selectedFile!.name,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            textAlign: TextAlign.center,

            style: const TextStyle(fontSize: 11, color: Color(0xFF4C7FF0)),
          ),
        ),

        const SizedBox(height: 8),

        GestureDetector(
          onTap: _removeFile,

          child: const Text(
            'Remove file',

            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFFE05A67),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// EVENT TYPE CHIP
// ================================================================

class _EventTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _EventTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),

        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),

        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF2FF) : Colors.white,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(
            color: selected ? const Color(0xFF6195F2) : const Color(0xFFE0E4EA),

            width: 1,
          ),
        ),

        child: Text(
          label,

          style: TextStyle(
            fontSize: 10,

            color: selected ? const Color(0xFF4C7FF0) : const Color(0xFF526071),

            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// BOTTOM NAVIGATION
// ================================================================

class _BottomNavigation extends StatelessWidget {
  final int currentIndex;

  final VoidCallback? onHomeTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onUploadTap;
  final VoidCallback? onProfileTap;

  const _BottomNavigation({
    required this.currentIndex,

    this.onHomeTap,
    this.onHistoryTap,
    this.onUploadTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<_NavItem> items = [
      const _NavItem(icon: Icons.grid_view_rounded, label: 'Home'),

      const _NavItem(icon: Icons.history_rounded, label: 'History'),

      const _NavItem(icon: Icons.arrow_upward_rounded, label: 'Upload'),

      const _NavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
    ];

    return Container(
      height: 68,

      decoration: const BoxDecoration(
        color: Colors.white,

        border: Border(top: BorderSide(color: Color(0xFFE8ECF2), width: 1)),
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,

        children: List.generate(items.length, (int index) {
          final bool selected = currentIndex == index;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,

              onTap: () {
                switch (index) {
                  case 0:
                    onHomeTap?.call();
                    break;

                  case 1:
                    onHistoryTap?.call();
                    break;

                  case 2:
                    onUploadTap?.call();
                    break;

                  case 3:
                    onProfileTap?.call();
                    break;
                }
              },

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
// NAV ITEM MODEL
// ================================================================

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
