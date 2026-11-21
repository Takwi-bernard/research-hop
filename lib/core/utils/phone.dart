/// "23767..." (12 digits) from what the person typed, or null if invalid.
String? normalizeCameroonPhone(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 9 && digits.startsWith('6')) return '237$digits';
  if (digits.length == 12 && digits.startsWith('2376')) return digits;
  return null;
}

/// A friendly guess of the operator, only used as a hint on screen.
String? operatorHint(String phone12) {
  if (phone12.length != 12) return null;
  final prefix = phone12.substring(3, 6); // e.g. 677
  final two = prefix.substring(0, 2);
  final n = int.tryParse(prefix) ?? 0;
  if (two == '67' || (n >= 650 && n <= 654) || (n >= 680 && n <= 684)) {
    return 'MTN Mobile Money';
  }
  if (two == '69' || (n >= 655 && n <= 659)) return 'Orange Money';
  return null;
}
