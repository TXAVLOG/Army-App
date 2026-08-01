import 'package:flutter/material.dart';
import 'txa_language.dart';

class TetHolidayData {
  final int year;
  final DateTime date;
  final String nameVi;
  final String nameEn;

  TetHolidayData({
    required this.year,
    required this.date,
    required this.nameVi,
    required this.nameEn,
  });
}

class TXAFestivalManager {
  // Mảng list chứa các ngày tết tính theo dương lịch của các năm từ 2027 đến 2036
  static final List<TetHolidayData> _tetHolidays = [
    TetHolidayData(year: 2027, date: DateTime(2027, 2, 6), nameVi: 'Đinh Mùi 2027', nameEn: 'Dinh Mui 2027'),
    TetHolidayData(year: 2028, date: DateTime(2028, 1, 26), nameVi: 'Mậu Thân 2028', nameEn: 'Mau Than 2028'),
    TetHolidayData(year: 2029, date: DateTime(2029, 2, 13), nameVi: 'Kỷ Dậu 2029', nameEn: 'Ky Dau 2029'),
    TetHolidayData(year: 2030, date: DateTime(2030, 2, 3), nameVi: 'Canh Tuất 2030', nameEn: 'Canh Tuat 2030'),
    TetHolidayData(year: 2031, date: DateTime(2031, 1, 23), nameVi: 'Tân Hợi 2031', nameEn: 'Tan Hoi 2031'),
    TetHolidayData(year: 2032, date: DateTime(2032, 2, 11), nameVi: 'Nhâm Tý 2032', nameEn: 'Nham Ty 2032'),
    TetHolidayData(year: 2033, date: DateTime(2033, 1, 31), nameVi: 'Quý Sửu 2033', nameEn: 'Quy Suu 2033'),
    TetHolidayData(year: 2034, date: DateTime(2034, 2, 19), nameVi: 'Giáp Dần 2034', nameEn: 'Giap Dan 2034'),
    TetHolidayData(year: 2035, date: DateTime(2035, 2, 8), nameVi: 'Ất Mão 2035', nameEn: 'At Mao 2035'),
    TetHolidayData(year: 2036, date: DateTime(2036, 1, 28), nameVi: 'Bính Thìn 2036', nameEn: 'Binh Thin 2036'),
  ];

  /// Trả về mốc ngày tết dương lịch cho một năm cụ thể
  static DateTime getTetDateForYear(int year) {
    for (final holiday in _tetHolidays) {
      if (holiday.year == year) {
        return holiday.date;
      }
    }
    return DateTime(year, 2, 6); // fallback mặc định
  }

  /// Trả về tên Tết (ví dụ: "Đinh Mùi 2027") cho mốc ngày Tết tương ứng
  static String getTetNameForDate(DateTime tetDate, String langCode) {
    for (final holiday in _tetHolidays) {
      if (holiday.date.year == tetDate.year && holiday.date.month == tetDate.month && holiday.date.day == tetDate.day) {
        return langCode == 'vi' ? holiday.nameVi : holiday.nameEn;
      }
    }
    // Fallback tìm theo năm
    for (final holiday in _tetHolidays) {
      if (holiday.year == tetDate.year) {
        return langCode == 'vi' ? holiday.nameVi : holiday.nameEn;
      }
    }
    return 'Đinh Mùi 2027';
  }

  /// Lấy mốc ngày Tết Nguyên Đán (Mùng 1) hoạt động dựa trên ngày hiện tại
  static DateTime getActiveTetDate(DateTime date) {
    final currentYearTet = getTetDateForYear(date.year);
    final mung5Tet = DateTime(currentYearTet.year, currentYearTet.month, currentYearTet.day).add(const Duration(days: 4));

    if (date.isBefore(mung5Tet) || date.isAtSameMomentAs(mung5Tet)) {
      return currentYearTet;
    } else {
      final nextYearTet = getTetDateForYear(date.year + 1);
      final today = DateTime(date.year, date.month, date.day);
      final nextTetDay = DateTime(nextYearTet.year, nextYearTet.month, nextYearTet.day);
      final daysToNextTet = nextTetDay.difference(today).inDays;

      if (daysToNextTet >= 300) {
        return currentYearTet;
      }
      return nextYearTet;
    }
  }

  /// Kiểm tra xem ngày có rơi vào khoảng thời gian Tết Nguyên Đán không (5 ngày trước Tết đến hết Mùng 5 Tết)
  static bool isTetPeriod(DateTime date) {
    final activeTet = getActiveTetDate(date);
    final start = activeTet.subtract(const Duration(days: 5));
    final end = activeTet.add(const Duration(days: 4));
    final checkDate = DateTime(date.year, date.month, date.day);
    return !checkDate.isBefore(start) && !checkDate.isAfter(end);
  }

  /// Kiểm tra xem ngày hiện tại có đúng là Mùng 1 đến Mùng 5 Tết âm lịch không
  static bool isMung1to5Tet(DateTime date) {
    final activeTet = getActiveTetDate(date);
    final start = activeTet;
    final end = activeTet.add(const Duration(days: 4));
    final checkDate = DateTime(date.year, date.month, date.day);
    return !checkDate.isBefore(start) && !checkDate.isAfter(end);
  }

  /// Kiểm tra xem ngày có rơi vào giai đoạn xuất hiện của Giải Phóng Miền Nam 30/4 & Quốc tế Lao động 1/5 không
  static bool isNationalDayPeriod(DateTime date) {
    final start = DateTime(date.year, 4, 27);
    final end = DateTime(date.year, 5, 1);
    final checkDate = DateTime(date.year, date.month, date.day);
    return !checkDate.isBefore(start) && !checkDate.isAfter(end);
  }

  /// Kiểm tra xem ngày có gần Quốc khánh 2/9 không
  static bool isNationalDay29Period(DateTime date) {
    final start = DateTime(date.year, 8, 30);
    final end = DateTime(date.year, 9, 2);
    final checkDate = DateTime(date.year, date.month, date.day);
    return !checkDate.isBefore(start) && !checkDate.isAfter(end);
  }

  /// Kiểm tra xem ngày có gần Ngày Nhà giáo Việt Nam 20/11 không
  static bool isTeachersDayPeriod(DateTime date) {
    final start = DateTime(date.year, 11, 17);
    final end = DateTime(date.year, 11, 20);
    final checkDate = DateTime(date.year, date.month, date.day);
    return !checkDate.isBefore(start) && !checkDate.isAfter(end);
  }

  /// Trả về theme đề xuất dựa theo ngày hiện tại
  static String getRecommendedThemeId(DateTime date) {
    if (isTetPeriod(date)) {
      return 'tet';
    }
    if (isNationalDayPeriod(date) || isNationalDay29Period(date)) {
      return 'national';
    }
    return 'classic';
  }

  /// Trả về số ngày còn lại đến mốc Tết âm lịch hoạt động (tính chính xác theo thời gian thực)
  static int getDaysToTet2027(DateTime date) {
    final target = getActiveTetDate(date);
    final diffSeconds = target.difference(date).inSeconds;
    if (diffSeconds <= 0) return 0;
    return (diffSeconds / 86400.0).ceil();
  }

  /// Trả về chuỗi hiển thị chữ đếm ngược Tết theo ngôn ngữ
  static String getTetCountdownText(String langCode, DateTime date) {
    final days = getDaysToTet2027(date);
    final txaLang = TXALanguage.instance;
    final activeTet = getActiveTetDate(date);
    final tetName = getTetNameForDate(activeTet, langCode);

    if (days > 0) {
      return txaLang.getText('tet_countdown_days')
          .replaceAll('%days%', '$days')
          .replaceAll('%name%', tetName);
    } else {
      return txaLang.getText('tet_new_year').replaceAll('%name%', tetName);
    }
  }

  /// Trả về caption lễ hội cho các ngày lễ lớn khác của Việt Nam
  static String getHolidayCaption(String key, String langCode) {
    final txaLang = TXALanguage.instance;
    if (key == '__holiday_30_4_1_5__') {
      return txaLang.getText('holiday_30_4_1_5');
    }
    if (key == '__holiday_2_9__') {
      return txaLang.getText('holiday_2_9');
    }
    if (key == '__holiday_20_11__') {
      return txaLang.getText('holiday_20_11');
    }
    return '';
  }

  /// Trích xuất thông tin cung hoàng đạo theo từ khóa key
  static ZodiacInfo? getZodiacInfoByKey(String key) {
    if (key == 'aries') {
      return ZodiacInfo(
        key: 'aries',
        emoji: '♈',
        baseColor: const Color(0xFFFF1744),
        gradient: [const Color(0xFFFF1744), const Color(0xFFFF9100)],
      );
    }
    if (key == 'taurus') {
      return ZodiacInfo(
        key: 'taurus',
        emoji: '♉',
        baseColor: const Color(0xFF00E676),
        gradient: [const Color(0xFF00E676), const Color(0xFF2E7D32)],
      );
    }
    if (key == 'gemini') {
      return ZodiacInfo(
        key: 'gemini',
        emoji: '♊',
        baseColor: const Color(0xFFFFEA00),
        gradient: [const Color(0xFFFFEA00), const Color(0xFFFF9100)],
      );
    }
    if (key == 'cancer') {
      return ZodiacInfo(
        key: 'cancer',
        emoji: '♋',
        baseColor: const Color(0xFFEC407A),
        gradient: [const Color(0xFFEC407A), const Color(0xFF0288D1)],
      );
    }
    if (key == 'leo') {
      return ZodiacInfo(
        key: 'leo',
        emoji: '♌',
        baseColor: const Color(0xFFFFAB00),
        gradient: [const Color(0xFFFFAB00), const Color(0xFFDD2C00)],
      );
    }
    if (key == 'virgo') {
      return ZodiacInfo(
        key: 'virgo',
        emoji: '♍',
        baseColor: const Color(0xFF8D6E63),
        gradient: [const Color(0xFF8D6E63), const Color(0xFF4E342E)],
      );
    }
    if (key == 'libra') {
      return ZodiacInfo(
        key: 'libra',
        emoji: '♎',
        baseColor: const Color(0xFFF48FB1),
        gradient: [const Color(0xFFF48FB1), const Color(0xFF90CAF9)],
      );
    }
    if (key == 'scorpio') {
      return ZodiacInfo(
        key: 'scorpio',
        emoji: '♏',
        baseColor: const Color(0xFF880E4F),
        gradient: [const Color(0xFF880E4F), const Color(0xFF212121)],
      );
    }
    if (key == 'sagittarius') {
      return ZodiacInfo(
        key: 'sagittarius',
        emoji: '♐',
        baseColor: const Color(0xFFD500F9),
        gradient: [const Color(0xFFD500F9), const Color(0xFF3F51B5)],
      );
    }
    if (key == 'capricorn') {
      return ZodiacInfo(
        key: 'capricorn',
        emoji: '♑',
        baseColor: const Color(0xFF455A64),
        gradient: [const Color(0xFF455A64), const Color(0xFF37474F)],
      );
    }
    if (key == 'aquarius') {
      return ZodiacInfo(
        key: 'aquarius',
        emoji: '♒',
        baseColor: const Color(0xFF00E5FF),
        gradient: [const Color(0xFF00E5FF), const Color(0xFF2979FF)],
      );
    }
    if (key == 'pisces') {
      return ZodiacInfo(
        key: 'pisces',
        emoji: '♓',
        baseColor: const Color(0xFF1DE9B6),
        gradient: [const Color(0xFF1DE9B6), const Color(0xFF00B0FF)],
      );
    }
    return null;
  }

  /// Tính toán cung hoàng đạo từ chuỗi ngày sinh (dob dạng DD/MM/YYYY)
  static ZodiacInfo getZodiacInfo(String dob) {
    int day = 1;
    int month = 1;
    try {
      final parts = dob.split('/');
      if (parts.length >= 2) {
        day = int.parse(parts[0]);
        month = int.parse(parts[1]);
      }
    } catch (_) {}

    String key = 'pisces';
    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) {
      key = 'aries';
    } else if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) {
      key = 'taurus';
    } else if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) {
      key = 'gemini';
    } else if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) {
      key = 'cancer';
    } else if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) {
      key = 'leo';
    } else if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) {
      key = 'virgo';
    } else if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) {
      key = 'libra';
    } else if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) {
      key = 'scorpio';
    } else if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) {
      key = 'sagittarius';
    } else if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) {
      key = 'capricorn';
    } else if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) {
      key = 'aquarius';
    }

    return getZodiacInfoByKey(key)!;
  }
}

class ZodiacInfo {
  final String key;
  final String emoji;
  final Color baseColor;
  final List<Color> gradient;

  ZodiacInfo({
    required this.key,
    required this.emoji,
    required this.baseColor,
    required this.gradient,
  });
}
