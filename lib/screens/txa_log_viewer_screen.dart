import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/txa_theme.dart';
import '../services/txa_logger.dart';
import '../widgets/txa_toast.dart';
import '../services/txa_language.dart';
import '../utils/txa_device_info.dart';

class TXALogEntry {
  final String timestamp;
  final String type;
  final String message;
  final String rawLine;

  TXALogEntry({
    required this.timestamp,
    required this.type,
    required this.message,
    required this.rawLine,
  });
}

class TXALogViewerScreen extends StatefulWidget {
  const TXALogViewerScreen({super.key});

  @override
  State<TXALogViewerScreen> createState() => _TXALogViewerScreenState();
}

class _TXALogViewerScreenState extends State<TXALogViewerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _logTypes = ['all', 'app', 'api', 'crash'];
  List<TXALogEntry> _parsedEntries = [];
  bool _isLoading = false;
  final Set<int> _expandedIndices = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _logTypes.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadLogs();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _loadLogs();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _expandedIndices.clear();
    });
    final activeType = _logTypes[_tabController.index];
    final content = await TXALogger.readLogs(activeType);

    final entries = await compute(_parseLogsIsolate, content);

    if (mounted) {
      setState(() {
        _parsedEntries = entries;
        _isLoading = false;
      });
    }
  }

  static List<TXALogEntry> _parseLogsIsolate(String content) {
    if (content.trim().isEmpty) return [];
    final List<TXALogEntry> list = [];
    final lines = content.split('\n');
    final headerRegExp = RegExp(r'^\[(\d{2}:\d{2}:\d{2}\.\d{3})\]\s+\[([A-Z_]+)\]\s+(.*)$');

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = headerRegExp.firstMatch(trimmed);
      if (match != null) {
        final timestamp = match.group(1)!;
        final type = match.group(2)!;
        final message = match.group(3)!;

        list.add(TXALogEntry(
          timestamp: timestamp,
          type: type,
          message: message,
          rawLine: trimmed,
        ));
      } else {
        if (list.isNotEmpty) {
          final lastEntry = list.last;
          final updatedMessage = lastEntry.message.length > 15000
              ? lastEntry.message
              : '${lastEntry.message}\n$trimmed';
          final updatedRaw = lastEntry.rawLine.length > 15000
              ? lastEntry.rawLine
              : '${lastEntry.rawLine}\n$trimmed';

          list[list.length - 1] = TXALogEntry(
            timestamp: lastEntry.timestamp,
            type: lastEntry.type,
            message: updatedMessage,
            rawLine: updatedRaw,
          );
        } else {
          list.add(TXALogEntry(
            timestamp: '--:--:--',
            type: 'APP',
            message: trimmed,
            rawLine: trimmed,
          ));
        }
      }
    }
    return list.reversed.toList();
  }

  Color _getTypeColor(String type) {
    final upper = type.toUpperCase();
    if (upper.contains('CRASH') || upper.contains('ERROR')) {
      return const Color(0xFFFF5252);
    } else if (upper.contains('API')) {
      return const Color(0xFF00E5FF);
    } else {
      return const Color(0xFFFFD700);
    }
  }

  Widget _buildLogItem(TXALogEntry entry, int index) {
    final isExpanded = _expandedIndices.contains(index);
    final typeColor = _getTypeColor(entry.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF191820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: typeColor.withAlpha(isExpanded ? 180 : 50),
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: typeColor.withAlpha(40),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedIndices.remove(index);
            } else {
              _expandedIndices.add(index);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Badge & Timestamp column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withAlpha(35),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: typeColor.withAlpha(120), width: 1),
                    ),
                    child: Text(
                      entry.type,
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.timestamp,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Message Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedCrossFade(
                      firstChild: Text(
                        entry.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      secondChild: SelectableText(
                        entry.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.4,
                          fontFamily: 'monospace',
                        ),
                      ),
                      crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Interactive Copy Button
              _TXACopyButton(entry: entry),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final activeType = _logTypes[_tabController.index];

    final tabLabels = [
      txaLang.getText('tab_all'),
      txaLang.getText('tab_app'),
      txaLang.getText('tab_api'),
      txaLang.getText('tab_crash'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14131A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          txaLang.getText('system_logs_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
            onPressed: _loadLogs,
          ),
          IconButton(
            tooltip: 'Chia sẻ log',
            icon: const Icon(Icons.share_rounded, color: Color(0xFFFFD700), size: 20),
            onPressed: () async {
              TXAToast.show(context, txaLang.getText('log_sharing_prep'));
              await TXALogger.shareLogs(activeType);
            },
          ),
          IconButton(
            tooltip: 'Xóa toàn bộ log',
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
            onPressed: () async {
              await TXALogger.clearLogs();
              await _loadLogs();
              if (!mounted) return;
              TXAToast.show(this.context, txaLang.getText('log_cleared'), icon: Icons.check_circle_rounded);
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD700),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: tabLabels.map((name) => Tab(text: name)).toList(),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                ),
              )
            : _parsedEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 54, color: Colors.white.withAlpha(40)),
                        const SizedBox(height: 12),
                        Text(
                          txaLang.getText('log_empty'),
                          style: TextStyle(color: TXATheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    itemCount: _parsedEntries.length,
                    itemBuilder: (context, index) {
                      return _buildLogItem(_parsedEntries[index], index);
                    },
                  ),
      ),
    );
  }
}

class _TXACopyButton extends StatefulWidget {
  final TXALogEntry entry;
  const _TXACopyButton({required this.entry});

  @override
  State<_TXACopyButton> createState() => _TXACopyButtonState();
}

class _TXACopyButtonState extends State<_TXACopyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    final txaLang = TXALanguage.instance;
    _animController.forward(from: 0.0);
    setState(() {
      _isCopied = true;
    });

    final header = await TXADeviceInfo.getFormattedHeader(
      logType: widget.entry.type,
      timestamp: widget.entry.timestamp,
      status: 'SUCCESS',
    );

    final clipboardText = '''
$header
${txaLang.getText('log_details_label')}
${widget.entry.message}

${txaLang.getText('log_raw_label')}
${widget.entry.rawLine}
=========================================
''';

    try {
      await Clipboard.setData(ClipboardData(text: clipboardText));
      HapticFeedback.mediumImpact();
      if (mounted) {
        TXAToast.show(context, txaLang.getText('log_copied'), icon: Icons.check_circle_rounded);
      }
    } catch (e) {
      if (mounted) {
        TXAToast.show(
          context,
          txaLang.getText('log_copy_failed').replaceAll('%error%', e.toString()),
          icon: Icons.error_outline_rounded,
        );
      }
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isCopied = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut),
      ),
      child: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: _isCopied
              ? const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF00E676),
                  key: ValueKey('copied'),
                  size: 20,
                )
              : const Icon(
                  Icons.copy_rounded,
                  color: Colors.white54,
                  key: ValueKey('copy'),
                  size: 18,
                ),
        ),
        onPressed: _handleCopy,
      ),
    );
  }
}
