import 'package:flutter/material.dart';

import '../../../../app/studio_theme.dart';

import '../../../../core/presentation/list_header.dart';
import '../../domain/entities/muse_account.dart';

/// Read-only account-list snapshot. Only the explicit Quota action probes Muse.
class AccountQuotaSection extends StatelessWidget {
  const AccountQuotaSection({super.key, required this.account});
  final MuseAccount account;

  static String _text(String? value) =>
      value == null || value.trim().isEmpty ? 'chưa có dữ liệu' : value;

  static String _percentage(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  static String _usage(String label, double? used, double? remaining) {
    final valid = MuseAccount.validPercentage(used);
    return valid == null || remaining == null
        ? '$label: chưa có dữ liệu'
        : '$label: đã dùng ${_percentage(valid)}% · còn ${_percentage(double.parse(remaining.toStringAsFixed(10)))}%';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(
            'Quota tài khoản',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Text(
          'Gói: ${_text(account.plan)}',
          style: const TextStyle(color: StudioColors.accent),
        ),
        Text(_usage('Tuần', account.weeklyUsed, account.weeklyRemaining)),
        if (account.weeklyRemaining != null)
          Semantics(
            label: 'Quota tuần còn lại',
            child: LinearProgressIndicator(
              value: account.weeklyRemaining! / 100,
              color: StudioColors.success,
              backgroundColor: StudioColors.raised,
              minHeight: 5,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 700 &&
                MediaQuery.textScalerOf(context).scale(14) <= 20;
            return Wrap(
              spacing: 24,
              runSpacing: 6,
              children: [
                for (final text in [
                  'Đặt lại tuần: ${_text(account.weeklyReset)}',
                  'Token bổ sung còn lại: ${_text(account.extraLeft)}',
                  _usage('Bổ sung', account.extraUsed, account.extraRemaining),
                  'Hết hạn bổ sung: ${_text(account.extraExpires)}',
                ])
                  SizedBox(
                    width: columns
                        ? (constraints.maxWidth - 24) / 2
                        : constraints.maxWidth,
                    child: Text(text),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 2),
        const Text('Dữ liệu lưu đệm · không tự làm mới'),
        Text('Quota cập nhật: ${formatDate(account.quotaCheckedAt)}'),
        if (account.quotaCheckedAt == null || account.weeklyRemaining == null)
          const Text('Chưa xác nhận lần đọc quota thành công'),
      ],
    ),
  );
}
