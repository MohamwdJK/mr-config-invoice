import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

class AppUtils {
  static final NumberFormat _currencyFormatter = NumberFormat('#,###');

  static String formatNumber(num value) {
    if (value == 0) return '۰';
    final formatted = _currencyFormatter.format(value.round());
    return toPersianDigits(formatted);
  }

  static String formatDecimal(double value) {
    if (value == value.roundToDouble()) {
      return toPersianDigits(value.round().toString());
    }
    return toPersianDigits(value.toStringAsFixed(2));
  }

  static String toPersianDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    String out = input;
    for (int i = 0; i < english.length; i++) {
      out = out.replaceAll(english[i], persian[i]);
    }
    return out;
  }

  static String toEnglishDigits(String input) {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String out = input;
    for (int i = 0; i < english.length; i++) {
      out = out.replaceAll(persian[i], english[i]);
      out = out.replaceAll(arabic[i], english[i]);
    }
    return out;
  }

  static double parseCurrency(String text) {
    final clean = toEnglishDigits(text).replaceAll(',', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  static String getCurrentShamsiDate() {
    final j = Jalali.now();
    final y = j.year.toString();
    final m = j.month.toString().padLeft(2, '0');
    final d = j.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  /// Converts any integer number into fluent Persian words (مبلغ به حروف)
  static String numberToPersianWords(int number) {
    if (number == 0) return 'صفر';
    if (number < 0) return 'منفی ${numberToPersianWords(-number)}';

    const ones = [
      '',
      'یک',
      'دو',
      'سه',
      'چهار',
      'پنج',
      'شش',
      'هفت',
      'هشت',
      'نه',
      'ده',
      'یازده',
      'دوازده',
      'سیزده',
      'چهارده',
      'پانزده',
      'شانزده',
      'هفده',
      'هجده',
      'نوزده'
    ];
    const tens = [
      '',
      '',
      'بیست',
      'سی',
      'چهل',
      'پنجاه',
      'شصت',
      'هفتاد',
      'هشتاد',
      'نود'
    ];
    const hundreds = [
      '',
      'صد',
      'دویست',
      'سیصد',
      'چهارصد',
      'پانصد',
      'ششصد',
      'هفتصد',
      'هشتصد',
      'نهصد'
    ];
    const scales = ['', 'هزار', 'میلیون', 'میلیارد', 'تریلیون'];

    String threeDigitsToWords(int n) {
      if (n == 0) return '';
      List<String> parts = [];
      int h = n ~/ 100;
      int rem = n % 100;
      if (h > 0) parts.add(hundreds[h]);
      if (rem > 0) {
        if (rem < 20) {
          parts.add(ones[rem]);
        } else {
          int t = rem ~/ 10;
          int u = rem % 10;
          parts.add(tens[t]);
          if (u > 0) parts.add(ones[u]);
        }
      }
      return parts.join(' و ');
    }

    List<String> groups = [];
    int scaleIndex = 0;
    int temp = number;

    while (temp > 0) {
      int chunk = temp % 1000;
      if (chunk > 0) {
        String chunkWords = threeDigitsToWords(chunk);
        String scale = scales[scaleIndex];
        groups.insert(0, scale.isEmpty ? chunkWords : '$chunkWords $scale');
      }
      temp ~/= 1000;
      scaleIndex++;
    }

    return groups.join(' و ');
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    String clean =
        AppUtils.toEnglishDigits(newValue.text).replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return const TextEditingValue(text: '');
    final number = int.tryParse(clean) ?? 0;
    final formatted = NumberFormat('#,###').format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
