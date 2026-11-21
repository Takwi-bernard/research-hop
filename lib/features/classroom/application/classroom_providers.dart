import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/providers.dart';
import '../data/classroom_repository.dart';

final classroomRepositoryProvider = Provider<ClassroomRepository>(
  (ref) => ClassroomRepository(ref.watch(supabaseClientProvider)),
);
