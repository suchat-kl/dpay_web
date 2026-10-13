import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/debt.dart';
import '../services/api_service.dart';
import '../services/debt_api.dart';
import '../utils/money.dart';
import 'account_form.dart';
import 'screen_parts.dart';

/// หน้าต่างประวัติการแก้ไขของรายการหนี้หนึ่งแถว (`GET /api/debts/{id}/audit`) ใหม่สุดก่อน
class DebtAuditDialog extends StatefulWidget {
  final ApiService apiService;
  final DebtRow row;

  const DebtAuditDialog({
    super.key,
    required this.apiService,
    required this.row,
  });

  static const String emptyText = 'ยังไม่มีประวัติการแก้ไข';

  @override
  State<DebtAuditDialog> createState() => _DebtAuditDialogState();
}

class _DebtAuditDialogState extends State<DebtAuditDialog> {
  List<DebtAudit>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.apiService.getDebtAudit(widget.row.id);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Widget _entry(DebtAudit a) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip(a.actionName, AppTheme.primaryDark),
            Text(
              '${formatServerTime(a.at?.toIso8601String())} โดย ${a.by}',
              style: screenText(size: 13.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
        for (final c in a.changes.entries)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${DebtCodes.nameOf(c.key)}: '
              '${Money.format(c.value.$1)} → ${Money.format(c.value.$2)}',
              style: screenText(size: 14.5),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return AccountDialogShell(
      icon: Icons.history,
      title: 'ประวัติการแก้ไข',
      subtitle: widget.row.fullName,
      onClose: () => Navigator.of(context).pop(),
      child: _error != null
          ? AccountBanner.error(_error!)
          : items == null
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : items.isEmpty
          ? Text(DebtAuditDialog.emptyText, style: screenText())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppTheme.dividerColor),
                  _entry(items[i]),
                ],
              ],
            ),
    );
  }
}
