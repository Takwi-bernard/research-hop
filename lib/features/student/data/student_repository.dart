import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_exception.dart';
import '../../admin/data/admin_models.dart';
import '../../classroom/data/classroom_models.dart';
import 'student_models.dart';

List<Map<String, dynamic>> _list(Object? raw) {
  if (raw is! List) return const [];
  return [for (final item in raw) Map<String, dynamic>.from(item as Map)];
}

const _serviceDown = 'The payment service did not answer. Try again.';

class StudentRepository {
  StudentRepository(this._client);

  final SupabaseClient _client;

  Future<List<CatalogCourse>> catalog() async {
    final rows = await _client
        .from('courses')
        .select('id, title, description, category, level, duration_label, fee_xaf')
        .order('created_at', ascending: false);
    return [for (final r in _list(rows)) CatalogCourse.fromRow(r)];
  }

  Future<List<MyRegistration>> myRegistrations() async {
    final rows = await _client
        .from('registrations')
        .select(
          'id, course_id, status, fee_xaf, full_name, phone, city, '
          'created_at, rejection_reason, courses(title)',
        )
        .order('created_at', ascending: false);
    return [for (final r in _list(rows)) MyRegistration.fromRow(r)];
  }

  Future<List<ClassItem>> upcomingClasses() async {
    final since =
        DateTime.now().subtract(const Duration(hours: 6)).toUtc().toIso8601String();
    final rows = await _client
        .from('class_sessions')
        .select('id, course_id, title, scheduled_at, status, courses(title)')
        .inFilter('status', ['scheduled', 'live'])
        .gte('scheduled_at', since)
        .order('scheduled_at', ascending: true)
        .limit(30);
    return [for (final r in _list(rows)) ClassItem.fromRow(r)];
  }

  /// Classes of one course (not cancelled ones), newest first.
  Future<List<ClassSession>> courseClasses(String courseId) async {
    final rows = await _client
        .from('class_sessions')
        .select(
          'id, course_id, teacher_id, title, description, scheduled_at, status, '
          'chat_mode, students_can_send_media, started_at, ended_at, courses(title)',
        )
        .eq('course_id', courseId)
        .neq('status', 'cancelled')
        .order('scheduled_at', ascending: false)
        .limit(30);
    return [for (final r in _list(rows)) ClassSession.fromRow(r)];
  }

  Future<CourseContent> content(String courseId) async {
    final results = await Future.wait<dynamic>([
      _client
          .from('course_modules')
          .select('id, title, description, position')
          .eq('course_id', courseId)
          .order('position'),
      _client
          .from('course_materials')
          .select('id, module_id, title, storage_path, mime_type, size_bytes')
          .eq('course_id', courseId)
          .order('created_at'),
    ]);
    return CourseContent(
      notes: [for (final r in _list(results[0])) CourseNote.fromRow(r)],
      materials: [for (final r in _list(results[1])) CourseMaterial.fromRow(r)],
    );
  }

  Future<String> materialUrl(CourseMaterial material) {
    return _client.storage
        .from('course-materials')
        .createSignedUrl(material.storagePath, 3600);
  }

  /// Returns the new registration id.
  Future<String> register({
    required String courseId,
    required String fullName,
    required String phone,
    String? city,
  }) async {
    final id = await _client.rpc('create_registration', params: {
      'p_course': courseId,
      'p_full_name': fullName.trim(),
      'p_phone': phone.trim(),
      'p_city': (city == null || city.trim().isEmpty) ? null : city.trim(),
    });
    return id as String;
  }

  Future<void> cancelRegistration(String id) async {
    await _client.rpc('cancel_registration', params: {'p_registration': id});
  }

  Future<PaymentProgress?> payment(String paymentId) async {
    final row = await _client
        .from('payments')
        .select('id, status, failure_reason')
        .eq('id', paymentId)
        .maybeSingle();
    return row == null ? null : PaymentProgress.fromRow(row);
  }

  /// Asks the secure payment function to send a mobile money prompt.
  Future<PaymentStart> startPayment({
    required String registrationId,
    required String phone,
  }) async {
    // The first call can fail while the payment service is waking up. It is
    // safe to repeat: an open prompt for the same phone is reused.
    final body = {'registration_id': registrationId, 'phone': phone};
    Map<String, dynamic> data;
    try {
      data = await _call('campay-collect', body);
    } on AppException catch (error) {
      if (error.message != _serviceDown) rethrow;
      await Future<void>.delayed(const Duration(seconds: 2));
      data = await _call('campay-collect', body);
    }
    final id = data['payment_id'];
    if (id is! String) {
      throw const AppException('The payment could not be started. Try again.');
    }
    return PaymentStart(
      paymentId: id,
      ussdCode: data['ussd_code'] as String?,
      operator: data['operator'] as String?,
    );
  }

  /// Asks the payment function to double-check a payment with the operator.
  Future<void> checkPayment(String paymentId) async {
    await _call('campay-check', {'payment_id': paymentId});
  }

  Future<Map<String, dynamic>> _call(
    String function,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.functions.invoke(function, body: body);
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        throw AppException(details['error'] as String);
      }
      if (error.status == 404) {
        throw const AppException(
          'Online payment is not switched on yet. Please pay the '
          'administrator in cash, or try again later.',
        );
      }
      throw const AppException(_serviceDown);
    }
  }
}
