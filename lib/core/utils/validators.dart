class Validators {
  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your name.';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your email.';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    if (!ok) return 'That email does not look right.';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.length < 8) return 'At least 8 characters.';
    return null;
  }

  static String? cribName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Give your crib a name.';
    return null;
  }

  static String? percentages(List<double> shares) {
    final sum = shares.fold(0.0, (a, b) => a + b);
    if ((sum - 100).abs() > 0.01) {
      final missing = 100 - sum;
      return 'Percentages add up to ${sum.toStringAsFixed(0)}%. Add ${missing.toStringAsFixed(0)}% more.';
    }
    return null;
  }
}
