class StatFormatters {
  static String wholeNumber(int value) {
    final sign = value < 0 ? '-' : '';
    final digits = value.abs().toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      final reverseIndex = digits.length - index;
      buffer.write(digits[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }

    return '$sign$buffer';
  }

  static String compactCount(int value) {
    final absValue = value.abs();
    if (absValue >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(absValue >= 10000000 ? 0 : 1)}M';
    }
    if (absValue >= 1000) {
      return '${(value / 1000).toStringAsFixed(absValue >= 10000 ? 0 : 1)}k';
    }
    return wholeNumber(value);
  }

  static String distanceKm(double kilometers, {int fractionDigits = 2}) {
    return '${kilometers.toStringAsFixed(fractionDigits)} km';
  }

  static String percent(double value, {int fractionDigits = 6}) {
    return '${value.toStringAsFixed(fractionDigits)}%';
  }
}
