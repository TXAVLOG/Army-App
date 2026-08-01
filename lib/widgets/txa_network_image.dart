import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  // Cache tĩnh trong bộ nhớ để lưu trữ các bytes ảnh đã tải thành công
  static final Map<String, Uint8List> _memoryCache = {};

  // Xóa cache khi cần
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

    // Kiểm tra cache trước
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

    try {
      // Tải ảnh qua http client của Dart (ổn định hơn Image.network trên Windows)
      final response = await http.get(Uri.parse(cleanUrl)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        TXANetworkImage._memoryCache[cleanUrl] = bytes;
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
            _error = null;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('HTTP error code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ TXANetworkImage load error ($cleanUrl): $e');
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageBytes != null) {
      return Image.memory(
        _imageBytes!,
        fit: widget.fit,
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
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error!, null);
      }
      return const Center(
        child: Icon(Icons.broken_image_outlined, color: Color(0xFF42A5F5), size: 40),
      );
    }

    return const SizedBox.shrink();
  }
}
