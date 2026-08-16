import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../services/txa_language.dart';

class TXANetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error, StackTrace? stackTrace)? errorBuilder;

  const TXANetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.loadingBuilder,
    this.errorBuilder,
  });

  // Cache tĩnh trong bộ nhớ RAM để truy cập tức thì 0ms
  static final Map<String, Uint8List> _memoryCache = {};

  // Xóa cache RAM khi cần
  static void clearCache() {
    _memoryCache.clear();
  }

  @override
  State<TXANetworkImage> createState() => _TXANetworkImageState();
}

class _TXANetworkImageState extends State<TXANetworkImage> {
  Uint8List? _imageBytes;
  Object? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(TXANetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadImage();
    }
  }

  String _getCacheKey(String url) {
    return md5.convert(utf8.encode(url)).toString();
  }

  Future<File?> _getCacheFile(String cacheKey) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/txa_img_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      return File('${cacheDir.path}/$cacheKey.bin');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadImage() async {
    final cleanUrl = widget.url.trim();
    if (cleanUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _error = 'Empty URL';
          _isLoading = false;
        });
      }
      return;
    }

    // 1. Kiểm tra RAM Cache trước (0ms load)
    if (TXANetworkImage._memoryCache.containsKey(cleanUrl)) {
      if (mounted) {
        setState(() {
          _imageBytes = TXANetworkImage._memoryCache[cleanUrl];
          _error = null;
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _imageBytes = null;
      });
    }

    // 2. Kiểm tra Disk Cache (đã lưu trên bộ nhớ thiết bị)
    final cacheKey = _getCacheKey(cleanUrl);
    final cacheFile = await _getCacheFile(cacheKey);

    if (cacheFile != null && await cacheFile.exists()) {
      try {
        final bytes = await cacheFile.readAsBytes();
        if (bytes.isNotEmpty) {
          TXANetworkImage._memoryCache[cleanUrl] = bytes;
          if (mounted) {
            setState(() {
              _imageBytes = bytes;
              _error = null;
              _isLoading = false;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint('Read disk cache error ($cleanUrl): $e');
      }
    }

    // 3. Tải từ mạng với timeout tối ưu 6s và cơ chế retry 1 lần khi mạng yếu
    int attempts = 0;
    while (attempts < 2) {
      attempts++;
      try {
        final response = await http.get(Uri.parse(cleanUrl)).timeout(
          const Duration(seconds: 6),
        );

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          TXANetworkImage._memoryCache[cleanUrl] = bytes;

          // Lưu xuống Disk Cache ở background (không block UI)
          if (cacheFile != null) {
            cacheFile.writeAsBytes(bytes).catchError((e) {
              debugPrint('Write disk cache error: $e');
              return cacheFile;
            });
          }

          if (mounted) {
            setState(() {
              _imageBytes = bytes;
              _error = null;
              _isLoading = false;
            });
          }
          return;
        }
      } catch (e) {
        if (attempts >= 2) {
          debugPrint('❌ TXANetworkImage load error ($cleanUrl): $e');
          if (mounted) {
            setState(() {
              _error = e;
              _isLoading = false;
            });
          }
          return;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txaLang = TXALanguage.instance;

    if (_imageBytes != null) {
      return Image.memory(
        _imageBytes!,
        fit: widget.fit,
        cacheWidth: 800, // Tối ưu RAM và GPU khi render feed
        errorBuilder: (ctx, err, st) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(ctx, err, st);
          }
          return const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 40),
          );
        },
      );
    }

    if (_isLoading) {
      if (widget.loadingBuilder != null) {
        return widget.loadingBuilder!(context);
      }
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF42A5F5), strokeWidth: 2),
      );
    }

    if (_error != null) {
      return GestureDetector(
        onTap: _loadImage,
        behavior: HitTestBehavior.opaque,
        child: widget.errorBuilder != null
            ? widget.errorBuilder!(context, _error!, null)
            : Container(
                color: const Color(0xFF1E1E24),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.signal_wifi_off_rounded,
                          color: Color(0xFF42A5F5),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        txaLang.getText('image_load_failed'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded, color: Colors.black, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              txaLang.getText('retry_image_load'),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
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

    return const SizedBox.shrink();
  }
}
