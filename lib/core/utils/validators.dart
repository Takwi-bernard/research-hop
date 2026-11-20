String? validateName(String? value) {
  if ((value ?? '').trim().length < 2) return 'Please enter your full name';
  return null;
}

String? validateEmail(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Please enter your email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
    return 'That email does not look right';
  }
  return null;
}

String? validateNewPassword(String? value) {
  if ((value ?? '').length < 8) return 'Use at least 8 characters';
  return null;
}

String? validatePasswordRequired(String? value) {
  if ((value ?? '').isEmpty) return 'Please enter your password';
  return null;
}

String? validatePhone(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 8) return 'Enter a phone number we can reach you on';
  return null;
}

String? Function(String?) validateMinLength(int min, String message) {
  return (value) => (value ?? '').trim().length < min ? message : null;
}
