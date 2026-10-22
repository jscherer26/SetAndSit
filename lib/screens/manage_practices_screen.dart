import 'package:flutter/material.dart';
import '../models/practice_config.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/practice_stepper_card.dart';

enum PracticeFilter { all, system, custom }

class ManagePracticesScreen extends StatefulWidget {
  final List<PracticeConfig> initialPractices;
  final String? initialSelectedPracticeId;
  final ValueChanged<List<PracticeConfig>> onPracticesUpdated;
  final VoidCallback? onBack;

  const ManagePracticesScreen({
    super.key,
    required this.initialPractices,
    this.initialSelectedPracticeId,
    required this.onPracticesUpdated,
    this.onBack,
  });

  @override
  State<ManagePracticesScreen> createState() => _ManagePracticesScreenState();
}

class _ManagePracticesScreenState extends State<ManagePracticesScreen> {
  late List<PracticeConfig> _practices;
  late String _selectedPracticeId;
  late TextEditingController _subtitleController;
  PracticeFilter _currentFilter = PracticeFilter.all;

  @override
  void initState() {
    super.initState();
    _practices = List<PracticeConfig>.from(widget.initialPractices);
    _selectedPracticeId = widget.initialSelectedPracticeId ??
        (_practices.isNotEmpty ? _practices.first.id : 'focused_calm');

    // Ensure selected practice exists
    if (!_practices.any((p) => p.id == _selectedPracticeId) && _practices.isNotEmpty) {
      _selectedPracticeId = _practices.first.id;
    }

    _subtitleController = TextEditingController(
      text: currentPractice?.subtitle ?? '',
    );
  }

  @override
  void dispose() {
    _subtitleController.dispose();
    super.dispose();
  }

  List<PracticeConfig> get filteredPractices {
    switch (_currentFilter) {
      case PracticeFilter.all:
        return _practices;
      case PracticeFilter.system:
        return _practices.where((p) => p.isSystem).toList();
      case PracticeFilter.custom:
        return _practices.where((p) => !p.isSystem).toList();
    }
  }

  PracticeConfig? get currentPractice {
    final list = filteredPractices;
    if (list.isEmpty) return null;
    return list.firstWhere(
      (p) => p.id == _selectedPracticeId,
      orElse: () => list.first,
    );
  }

  void _saveAndNotify() {
    PreferencesService.savePractices(_practices);
    widget.onPracticesUpdated(_practices);
  }

  void _selectPracticeByIndex(int index) {
    final list = filteredPractices;
    if (list.isEmpty) return;
    final validIndex = (index % list.length + list.length) % list.length;
    setState(() {
      _selectedPracticeId = list[validIndex].id;
      _subtitleController.text = currentPractice?.subtitle ?? '';
    });
  }

  void _stepPrevious() {
    final list = filteredPractices;
    if (list.isEmpty) return;
    final idx = list.indexWhere((p) => p.id == _selectedPracticeId);
    _selectPracticeByIndex(idx - 1);
  }

  void _stepNext() {
    final list = filteredPractices;
    if (list.isEmpty) return;
    final idx = list.indexWhere((p) => p.id == _selectedPracticeId);
    _selectPracticeByIndex(idx + 1);
  }

  void _toggleInclude(bool newValue) {
    final practice = currentPractice;
    if (practice == null) return;

    if (!newValue) {
      final includedCount = _practices.where((p) => p.isIncluded).length;
      if (includedCount <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'At least one practice must remain included on the Home Screen.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    setState(() {
      final idx = _practices.indexWhere((p) => p.id == practice.id);
      if (idx != -1) {
        _practices[idx] = practice.copyWith(isIncluded: newValue);
      }
    });
    _saveAndNotify();
  }

  void _toggleSegment(String code, bool? newValue) {
    final practice = currentPractice;
    if (practice == null || practice.isSystem) return;

    if (kMandatorySegmentIds.contains(code)) return;

    final currentSegs = List<String>.from(practice.segmentIds);

    if (newValue == false) {
      // Check safeguard: at least one segment between S03 and S11
      if (code.compareTo('S03') >= 0 && code.compareTo('S11') <= 0) {
        final coreCount = currentSegs
            .where((s) => s.compareTo('S03') >= 0 && s.compareTo('S11') <= 0)
            .length;
        if (coreCount <= 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A practice must include at least one settling or core segment (S03–S11).',
              ),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }
      currentSegs.remove(code);
    } else if (newValue == true) {
      if (!currentSegs.contains(code)) {
        currentSegs.add(code);
      }
    }

    // Keep sorted in ascending numerical order
    currentSegs.sort((a, b) => a.compareTo(b));

    setState(() {
      final idx = _practices.indexWhere((p) => p.id == practice.id);
      if (idx != -1) {
        _practices[idx] = practice.copyWith(segmentIds: currentSegs);
      }
    });
    _saveAndNotify();
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final subtitleController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Add Custom Practice',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Practice Name',
                  hintText: 'e.g., Evening Wind-Down',
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: subtitleController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Clinical Intention / Subtitle',
                  hintText: 'e.g., Gentle down-regulation before sleep.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkOlive,
                foregroundColor: AppColors.buttonTextLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(() {
                    errorText = 'Name cannot be empty';
                  });
                  return;
                }

                final exists = _practices.any(
                  (p) => p.name.trim().toLowerCase() == name.toLowerCase(),
                );
                if (exists) {
                  setDialogState(() {
                    errorText = 'A practice with this name already exists';
                  });
                  return;
                }

                final newPractice = PracticeConfig(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  subtitle: subtitleController.text.trim().isEmpty
                      ? 'Custom meditation practice.'
                      : subtitleController.text.trim(),
                  isSystem: false,
                  isIncluded: true,
                  segmentIds: [
                    'S01',
                    'S02',
                    'S03',
                    'S08',
                    'S12',
                    'S13',
                    'S15',
                    'S16',
                  ],
                );

                setState(() {
                  _practices.add(newPractice);
                  _selectedPracticeId = newPractice.id;
                  if (_currentFilter == PracticeFilter.system) {
                    _currentFilter = PracticeFilter.custom;
                  }
                  _subtitleController.text = newPractice.subtitle;
                });
                _saveAndNotify();
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCopyDialog() {
    final practice = currentPractice;
    if (practice == null) return;

    // Generate unique copy name
    String copyName = '${practice.name} (Copy)';
    int copyNum = 2;
    while (_practices.any((p) => p.name.trim().toLowerCase() == copyName.toLowerCase())) {
      copyName = '${practice.name} (Copy $copyNum)';
      copyNum++;
    }

    final nameController = TextEditingController(text: copyName);
    final subtitleController = TextEditingController(text: practice.subtitle);
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Copy Practice',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Practice Name',
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: subtitleController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Clinical Intention / Subtitle',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkOlive,
                foregroundColor: AppColors.buttonTextLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(() {
                    errorText = 'Name cannot be empty';
                  });
                  return;
                }

                final exists = _practices.any(
                  (p) => p.name.trim().toLowerCase() == name.toLowerCase(),
                );
                if (exists) {
                  setDialogState(() {
                    errorText = 'A practice with this name already exists';
                  });
                  return;
                }

                final newPractice = PracticeConfig(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  subtitle: subtitleController.text.trim().isEmpty
                      ? practice.subtitle
                      : subtitleController.text.trim(),
                  isSystem: false,
                  isIncluded: true,
                  segmentIds: List<String>.from(practice.segmentIds),
                );

                setState(() {
                  _practices.add(newPractice);
                  _selectedPracticeId = newPractice.id;
                  if (_currentFilter == PracticeFilter.system) {
                    _currentFilter = PracticeFilter.custom;
                  }
                  _subtitleController.text = newPractice.subtitle;
                });
                _saveAndNotify();
                Navigator.pop(ctx);
              },
              child: const Text('Copy'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog() {
    final practice = currentPractice;
    if (practice == null || practice.isSystem) return;

    final nameController = TextEditingController(text: practice.name);
    final subtitleController = TextEditingController(text: practice.subtitle);
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Rename Practice',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Practice Name',
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: subtitleController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Clinical Intention / Subtitle',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkOlive,
                foregroundColor: AppColors.buttonTextLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(() {
                    errorText = 'Name cannot be empty';
                  });
                  return;
                }

                final exists = _practices.any(
                  (p) => p.id != practice.id && p.name.trim().toLowerCase() == name.toLowerCase(),
                );
                if (exists) {
                  setDialogState(() {
                    errorText = 'A practice with this name already exists';
                  });
                  return;
                }

                final updatedSubtitle = subtitleController.text.trim();
                setState(() {
                  final idx = _practices.indexWhere((p) => p.id == practice.id);
                  if (idx != -1) {
                    _practices[idx] = practice.copyWith(
                      name: name,
                      subtitle: updatedSubtitle,
                    );
                  }
                  _subtitleController.text = updatedSubtitle;
                });
                _saveAndNotify();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    final practice = currentPractice;
    if (practice == null || practice.isSystem) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Practice',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textBlack,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${practice.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              setState(() {
                _practices.removeWhere((p) => p.id == practice.id);

                // Safeguard: If deleting the last isIncluded practice, auto-enable Focused Calm
                final remainingIncluded = _practices.where((p) => p.isIncluded).toList();
                if (remainingIncluded.isEmpty) {
                  final fcIdx = _practices.indexWhere((p) => p.id == 'focused_calm');
                  if (fcIdx != -1) {
                    _practices[fcIdx] = _practices[fcIdx].copyWith(isIncluded: true);
                  } else if (_practices.isNotEmpty) {
                    _practices[0] = _practices[0].copyWith(isIncluded: true);
                  }
                }

                // Pick an available practice in the current filter
                final filtered = filteredPractices;
                if (filtered.isNotEmpty) {
                  _selectedPracticeId = filtered.first.id;
                } else if (_practices.isNotEmpty) {
                  _selectedPracticeId = _practices.first.id;
                }
                _subtitleController.text = currentPractice?.subtitle ?? '';
              });
              _saveAndNotify();
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSegmentDetail(String code) {
    final meta = kSegmentMetadata[code];
    if (meta == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Phase Header
              Text(
                meta['phase'] ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkOlive,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),

              // Segment Code & Name
              Text(
                '$code • ${meta['title']}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.cardBorder, height: 1),
              const SizedBox(height: 16),

              // Clinical Rationale & Function
              const Text(
                'Clinical Rationale & Function',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                meta['rationale'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textBlack,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Example Guidance Script
              const Text(
                'Example Guidance Script',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSand,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: AppColors.darkOlive, width: 3),
                  ),
                ),
                child: Text(
                  meta['example'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textBlack,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.pillUnselected,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _buildFilterOption(
            filter: PracticeFilter.all,
            title: 'All',
            activeColor: AppColors.darkOlive,
            inactiveColor: AppColors.textBlack,
          ),
          _buildFilterOption(
            filter: PracticeFilter.system,
            title: 'System',
            activeColor: AppColors.systemBlue,
            inactiveColor: AppColors.systemBlue,
          ),
          _buildFilterOption(
            filter: PracticeFilter.custom,
            title: 'Custom',
            activeColor: AppColors.customGreen,
            inactiveColor: AppColors.customGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption({
    required PracticeFilter filter,
    required String title,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final isSelected = _currentFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentFilter = filter;
            final filtered = filteredPractices;
            if (filtered.isNotEmpty && !filtered.any((p) => p.id == _selectedPracticeId)) {
              _selectedPracticeId = filtered.first.id;
              _subtitleController.text = currentPractice?.subtitle ?? '';
            }
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.buttonTextLight : inactiveColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isDestructive = false,
  }) {
    final isEnabled = onPressed != null;
    final color = !isEnabled
        ? AppColors.textSubtle.withValues(alpha: 0.4)
        : (isDestructive ? AppColors.errorRed : AppColors.darkOlive);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isEnabled ? AppColors.white : AppColors.backgroundSand.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: !isEnabled
                ? AppColors.cardBorder.withValues(alpha: 0.3)
                : (isDestructive
                    ? AppColors.errorRed.withValues(alpha: 0.4)
                    : AppColors.cardBorder),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final practice = currentPractice;
    final hasPractices = practice != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textBlack),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage Practices',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textBlack,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Filter Segmented Control
              _buildFilterPill(),
              const SizedBox(height: 18),

              // 2. Empty-state card if Custom filter is empty
              if (!hasPractices && _currentFilter == PracticeFilter.custom) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.cardBorder.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.self_improvement_outlined,
                        size: 48,
                        color: AppColors.customGreen,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Custom Practices Yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBlack,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create a custom practice from scratch or copy an existing system practice to customize segments.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.customGreen,
                              foregroundColor: AppColors.buttonTextLight,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _showAddDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Practice'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.systemBlue,
                              side: const BorderSide(color: AppColors.systemBlue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _currentFilter = PracticeFilter.system;
                              });
                            },
                            child: const Text('View System'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else if (hasPractices) ...[
                // 2. Practice Stepper (Practice Name colored: Blue for System, Green for Custom)
                PracticeStepperCard(
                  practice: practice,
                  titleColor: practice.isSystem ? AppColors.systemBlue : AppColors.customGreen,
                  onPrevious: filteredPractices.length > 1 ? _stepPrevious : null,
                  onNext: filteredPractices.length > 1 ? _stepNext : null,
                ),
                const SizedBox(height: 12),

                // Clinical Intention / Subtitle for ALL practices with blue and green styling
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (practice.isSystem ? AppColors.systemBlue : AppColors.customGreen)
                          .withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _subtitleController,
                    readOnly: practice.isSystem,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textBlack,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Clinical Intention / Subtitle',
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: practice.isSystem ? AppColors.systemBlue : AppColors.customGreen,
                        fontWeight: FontWeight.w600,
                      ),
                      hintText: 'Enter clinical intention or description...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSubtle,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      final current = currentPractice;
                      if (current == null || current.isSystem) return;
                      final idx = _practices.indexWhere((p) => p.id == current.id);
                      if (idx != -1) {
                        _practices[idx] = current.copyWith(subtitle: val);
                        _saveAndNotify();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Include/Exclude Toggle & Action Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.cardBorder.withValues(alpha: 0.6),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Include on Home Screen',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textBlack,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              practice.isIncluded
                                  ? 'Active in Home Screen Practice selector'
                                  : 'Hidden from Home Screen Practice selector',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: practice.isIncluded,
                        activeTrackColor: AppColors.darkOlive,
                        activeThumbColor: AppColors.white,
                        onChanged: _toggleInclude,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Action Buttons Row: Add | Copy | Rename | Delete
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.add,
                        label: 'Add',
                        onPressed: _showAddDialog,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.copy,
                        label: 'Copy',
                        onPressed: _showCopyDialog,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.edit_outlined,
                        label: 'Rename',
                        onPressed: practice.isSystem ? null : _showRenameDialog,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        isDestructive: true,
                        onPressed: practice.isSystem ? null : _showDeleteDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 4. Grouped 16-Segment Checklist (S01–S16)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Clinical Arc Segments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textBlack,
                      ),
                    ),
                    if (practice.isSystem)
                      const Text(
                        'Read-Only System Practice',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.systemBlue,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                ...kPhaseSegments.entries.map((entry) {
                  final phaseTitle = entry.key;
                  final segmentCodes = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.cardBorder.withValues(alpha: 0.6),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Phase Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Text(
                            phaseTitle,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkOlive,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const Divider(color: AppColors.cardBorder, height: 1),

                        // Segment Rows
                        ...segmentCodes.map((code) {
                          final meta = kSegmentMetadata[code];
                          final isRequired = kMandatorySegmentIds.contains(code);
                          final isChecked = isRequired || practice.segmentIds.contains(code);
                          final isInteractive = !practice.isSystem && !isRequired;

                          return InkWell(
                            onTap: () => _showSegmentDetail(code),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  // Checkbox
                                  Checkbox(
                                    value: isChecked,
                                    activeColor: AppColors.darkOlive,
                                    onChanged: isInteractive
                                        ? (val) => _toggleSegment(code, val)
                                        : null,
                                  ),

                                  // Code & Title (clean - no required bubbles)
                                  Expanded(
                                    child: Text(
                                      '$code • ${meta?['title'] ?? code}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isChecked
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isChecked
                                            ? AppColors.textBlack
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ),

                                  // Info Icon
                                  IconButton(
                                    icon: const Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: AppColors.darkOlive,
                                    ),
                                    onPressed: () => _showSegmentDetail(code),
                                    splashRadius: 18,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
