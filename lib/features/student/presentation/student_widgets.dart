import 'package:flutter/material.dart';

import '../../../shared/widgets/status_chip.dart';
import '../../admin/data/admin_models.dart';

/// Small label showing where a student stands with a course.
class RegistrationChip extends StatelessWidget {
  const RegistrationChip(this.status, {super.key});

  final RegStatus? status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case RegStatus.approved:
        return const StatusChip('Enrolled', tone: ChipTone.good);
      case RegStatus.paid:
        return const StatusChip('Paid, awaiting approval', tone: ChipTone.warn);
      case RegStatus.awaitingPayment:
        return const StatusChip('Payment needed', tone: ChipTone.warn);
      case RegStatus.rejected:
        return const StatusChip('Not approved', tone: ChipTone.bad);
      case RegStatus.cancelled:
      case null:
        return const SizedBox.shrink();
    }
  }
}
