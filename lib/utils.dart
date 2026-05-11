import 'package:intl/intl.dart';

class Utils {
  static String formatCurrency(num amount) {
    return '${NumberFormat('#,###', 'vi_VN').format(amount)}đ';
  }

  static String removeDiacritics(String text) {
    const withDiacritics = [
      'àáâãäåāăąạảấầẩẫậắằẳẵặ',
      'èéêëēĕėęěẹẻẽếềểễệ',
      'ìíîïīĭįịỉĩ',
      'òóôõöōŏőọỏốồổỗộớờởỡợ',
      'ùúûüūŭůűųụủứừửữự',
      'ýÿỳỵỷỹ',
      'đ',
      'ÀÁÂÃÄÅĀĂĄẠẢẤẦẨẪẬẮẰẲẴẶ',
      'ÈÉÊËĒĔĖĘĚẸẺẼẾỀỂỄỆ',
      'ÌÍÎÏĪĬĮỊỈĨ',
      'ÒÓÔÕÖŌŎŐỌỎỐỒỔỖỘỚỜỞỠỢ',
      'ÙÚÛÜŪŬŮŰŲỤỦỨỪỬỮỰ',
      'ÝŸỲỴỶỸ',
      'Đ',
    ];
    const withoutDiacritics = [
      'a',
      'e',
      'i',
      'o',
      'u',
      'y',
      'd',
      'A',
      'E',
      'I',
      'O',
      'U',
      'Y',
      'D',
    ];

    String result = text;
    for (int i = 0; i < withDiacritics.length; i++) {
      for (final char in withDiacritics[i].split('')) {
        result = result.replaceAll(char, withoutDiacritics[i]);
      }
    }
    return result;
  }
}
