class TXABadWord {
  static const List<String> forbiddenWords = [
    // Vietnamese - Tục tĩu / chửi thề chính
    'đụ', 'đù', 'đm', 'đmm', 'đcm', 'đkm', 'vcl', 'vkl', 'vcc', 'vl', 'vloz', 'vailon', 'vailz',
    'clm', 'cml', 'clgt', 'cmm', 'clgv',
    'địt', 'đjt', 'djt', 'đít', 'đĩ', 'đái', 'ỉa', 'cặc', 'cac', 'lồn', 'lon', 'lol', 'lz',
    'buồi', 'buoi', 'bòi',

    // Vietnamese - Hành vi tình dục / thô tục
    'chịch', 'xoạc', 'nện', 'hãm', 'hãm lồn', 'bú lồn', 'bú lz', 'liếm lồn', 'bú cu', 'cu to',
    'vú to', 'bóp vú', 'quay tay', 'dâm ô', 'dâm dục', 'dâm dật', 'biến thái',
    'hiếp dâm', 'cưỡng hiếp', 'khiêu dâm', 'phim sex', 'ảnh sex', 'mại dâm', 'bán dâm',
    'gái gọi', 'trai bao', 'phá trinh', 'bím', 'âm hộ', 'dương vật', 'thủ dâm',

    // Vietnamese - Chửi rủa / xúc phạm
    'mẹ kiếp', 'bố láo', 'láo lồn', 'chó đẻ', 'chó má', 'đồ chó', 'súc vật',
    'ngu lồn', 'ngu vcl', 'thằng điên', 'con điên', 'đồ điên', 'tâm thần',
    'óc chó', 'óc lợn', 'óc bò', 'thằng ngu', 'con ngu', 'đồ ngu', 'ngu học', 'ngu si',
    'đầu bò', 'ngu như bò', 'mặt lồn', 'mặt cặc', 'mặt thớt',
    'đồ khùng', 'thằng khùng', 'con khùng',
    'bán dâm', 'lừa đảo', 'đồ hèn', 'tiện nhân', 'khốn nạn', 'mất dạy', 'vô học',
    'con đĩ', 'thằng cặc', 'thằng chó', 'con chó', 'xạo lồn', 'xạo chó',
    'nói phét', 'bốc phét', 'xỉa xói', 'bắt nạt', 'dọa giết', 'chửi thề',
    'con mẹ nó', 'đụ mẹ', 'đụ má', 'địt mẹ', 'địt má', 'cái lồn', 'cái cặc',
    'con lợn', 'đồ heo', 'thằng heo',

    // English - Profanities chính
    'fuck', 'fucking', 'fucker', 'fuk', 'fck', 'f*ck',
    'shit', 'sh*t', 'bullshit', 'bitch', 'b*tch', 'asshole', 'a**hole', 'bastard',
    'cunt', 'dick', 'cock', 'pussy', 'whore', 'slut', 'motherfucker', 'prick', 'twat', 'wanker',

    // English - Xúc phạm trí tuệ/nhân phẩm
    'retard', 'idiot', 'moron', 'dumbass', 'dipshit', 'jackass',

    // English - Kỳ thị / thù ghét
    'nigger', 'nigga', 'faggot', 'chink', 'spic', 'nazi', 'hitler',

    // English - Tình dục / khiêu dâm
    'piss', 'nude', 'nsfw', 'porn', 'sex', 'xxx', 'hentai', 'boobs', 'tits',
    'dildo', 'orgasm', 'masturbate', 'cumshot', 'rape',

    // English - Chửi thề viết tắt/né lọc
    'wtf', 'stfu', 'omfg', 'ffs',
  ];

  /// Chuẩn hóa chuỗi: lowercase, bỏ ký tự đặc biệt/số chèn giữa, bỏ khoảng trắng thừa
  /// Giúp bắt các biến thể né lọc kiểu "đ.m", "d-m", "l0n", "Đ M M"
  static String _normalize(String text) {
    var result = text.toLowerCase();

    // Thay số/ký tự thường bị dùng để né lọc về chữ cái tương ứng
    const leetMap = {
      '0': 'o',
      '1': 'i',
      '3': 'e',
      '4': 'a',
      '5': 's',
      '7': 't',
      '8': 'b',
      '@': 'a',
      r'$': 's',
    };
    leetMap.forEach((k, v) {
      result = result.replaceAll(k, v);
    });

    // Bỏ mọi ký tự không phải chữ cái (kể cả có dấu tiếng Việt) hoặc khoảng trắng thường dùng để né lọc
    result = result.replaceAll(
      RegExp(
        r'[^a-z\sàáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]',
      ),
      '',
    );

    // Gộp nhiều khoảng trắng / bỏ khoảng trắng chèn giữa để bắt "đ m m" -> "đmm"
    result = result.replaceAll(RegExp(r'\s+'), '');

    return result;
  }

  /// Kiểm tra chuỗi có chứa từ cấm không (đã chuẩn hóa để bắt biến thể né lọc)
  static bool containsBadWord(String text) {
    if (text.trim().isEmpty) return false;
    final normalizedText = _normalize(text);

    for (var word in forbiddenWords) {
      final normalizedWord = _normalize(word);
      if (normalizedWord.isNotEmpty && normalizedText.contains(normalizedWord)) {
        return true;
      }
    }
    return false;
  }

  /// Tìm từ cấm đầu tiên phát hiện được (để báo lỗi)
  static String? findFirstBadWord(String text) {
    if (text.trim().isEmpty) return null;
    final normalizedText = _normalize(text);

    for (var word in forbiddenWords) {
      final normalizedWord = _normalize(word);
      if (normalizedWord.isNotEmpty && normalizedText.contains(normalizedWord)) {
        return word;
      }
    }
    return null;
  }
}
