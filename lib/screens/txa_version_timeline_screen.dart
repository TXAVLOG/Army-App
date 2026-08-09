import 'package:flutter/material.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_version.dart';

class TXAVersionTimelineScreen extends StatefulWidget {
  const TXAVersionTimelineScreen({super.key});

  @override
  State<TXAVersionTimelineScreen> createState() => _TXAVersionTimelineScreenState();
}

class _TXAVersionTimelineScreenState extends State<TXAVersionTimelineScreen> {
  final Set<int> _expandedIndices = {0}; // Mặc định mở phiên bản mới nhất (index 0)

  void _toggleExpand(int index) {
    setState(() {
      if (_expandedIndices.contains(index)) {
        _expandedIndices.remove(index);
      } else {
        _expandedIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;
    final changelogList = TXAVersion.changelogData;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14), // Pitch Black Locket background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          txaLang.getText('version_timeline_title'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header Card: Phiên bản hiện tại ───
              _buildCurrentVersionHeader(txaLang),
              const SizedBox(height: 24),

              // ─── Tiêu đề Sơ đồ Timeline ───
              Row(
                children: [
                  const Icon(Icons.timeline_rounded, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    txaLang.getText('version_timeline_subtitle'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── Danh sách Timeline Node ───
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: changelogList.length,
                itemBuilder: (context, index) {
                  final item = changelogList[index];
                  final isLatest = index == 0;
                  final isExpanded = _expandedIndices.contains(index);
                  final isLast = index == changelogList.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Cột Timeline Node & Đường nối dọc
                        SizedBox(
                          width: 32,
                          child: Column(
                            children: [
                              // Nút Node tròn
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: isLatest ? 20 : 14,
                                height: isLatest ? 20 : 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isLatest ? const Color(0xFFFFD700) : Colors.white38,
                                  border: Border.all(
                                    color: isLatest ? Colors.amberAccent : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    if (isLatest)
                                      BoxShadow(
                                        color: const Color(0xFFFFD700).withAlpha(150),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                  ],
                                ),
                                child: isLatest
                                    ? Center(
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Colors.black,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              // Đường nối dọc giữa các node
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: isLatest
                                            ? [const Color(0xFFFFD700), Colors.white24]
                                            : [Colors.white24, Colors.white12],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 2. Nội dung Card Phiên bản
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _buildVersionCard(
                              context,
                              item: item,
                              index: index,
                              isLatest: isLatest,
                              isExpanded: isExpanded,
                              onTap: () => _toggleExpand(index),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentVersionHeader(TXALanguage txaLang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withAlpha(35),
            const Color(0xFF1E1E24),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD700).withAlpha(120),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withAlpha(40),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
            ),
            child: const Center(
              child: Text('🚀', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      TXAVersion.fullVersionString,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        txaLang.getText('version_timeline_latest_badge'),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  txaLang.getText('version_timeline_released_date').replaceAll('%date%', TXAVersion.releaseDate),
                  style: TextStyle(
                    color: TXATheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard(
    BuildContext context, {
    required Map<String, dynamic> item,
    required int index,
    required bool isLatest,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final features = (item['features'] as List<dynamic>?) ?? [];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLatest ? const Color(0xFF1E1E28) : const Color(0xFF16161D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLatest
                ? const Color(0xFFFFD700).withAlpha(100)
                : Colors.white.withAlpha(20),
            width: isLatest ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (isLatest)
              BoxShadow(
                color: const Color(0xFFFFD700).withAlpha(40),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header phiên bản ───
            Row(
              children: [
                // Badge loại phiên bản
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLatest ? const Color(0xFFFFD700) : Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item['badge'] ?? 'CẬP NHẬT',
                    style: TextStyle(
                      color: isLatest ? Colors.black : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Tag version
                Text(
                  item['version'] ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'ShareTechMono',
                  ),
                ),
                const Spacer(),

                // Ngày phát hành
                Text(
                  item['date'] ?? '',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white54,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ─── Tiêu đề & Mô tả ngắn ───
            Text(
              item['title'] ?? '',
              style: TextStyle(
                color: isLatest ? Colors.amberAccent : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item['subtitle'] ?? '',
              style: TextStyle(
                color: TXATheme.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),

            // ─── Chi tiết tính năng (Thu gọn / Mở rộng) ───
            if (isExpanded && features.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(color: Colors.white.withAlpha(20), height: 1),
              const SizedBox(height: 12),

              ...features.map((feat) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            feat['icon'] ?? '✨',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feat['title'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              feat['description'] ?? '',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}