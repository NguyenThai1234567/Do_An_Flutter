import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/services/cash_reconciliation_service.dart';
import '../../../providers/auth_provider.dart';

class CashReconciliationDialog extends StatefulWidget {
  final double expectedCash;

  const CashReconciliationDialog({super.key, this.expectedCash = 0});

  @override
  State<CashReconciliationDialog> createState() => _CashReconciliationDialogState();
}

class _CashReconciliationDialogState extends State<CashReconciliationDialog> {
  final _service = CashReconciliationService();
  final _notesCtrl = TextEditingController();

  final Map<int, int> _counts = {
    500000: 0,
    200000: 0,
    100000: 0,
    50000: 0,
    20000: 0,
    10000: 0,
    5000: 0,
    2000: 0,
    1000: 0,
  };

  late double _expectedCash;
  final _expectedCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _expectedCash = widget.expectedCash;
    if (_expectedCash > 0) {
      _expectedCtrl.text = Formatters.formatNumber(_expectedCash);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _expectedCtrl.dispose();
    super.dispose();
  }

  double get _actualTotal {
    double sum = 0;
    _counts.forEach((denom, count) {
      sum += denom * count;
    });
    return sum;
  }

  double get _discrepancy => _actualTotal - _expectedCash;

  void _updateCount(int denom, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      final current = _counts[denom] ?? 0;
      final next = current + delta;
      if (next >= 0) {
        _counts[denom] = next;
      }
    });
  }

  Future<void> _handleConfirm() async {
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();

    final record = CashReconciliationRecord(
      id: 'CR-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      staffName: auth.currentUser?.fullName ?? 'Nhân viên thu ngân',
      branchName: auth.selectedBranch?.branchName ?? 'Chi nhánh',
      expectedCash: _expectedCash,
      actualCash: _actualTotal,
      discrepancy: _discrepancy,
      denominations: Map.from(_counts),
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );

    await _service.saveRecord(record);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.emerald,
          content: Text('Đã lưu chốt két thành công! Thực tế: ${Formatters.formatVND(_actualTotal)}'),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _showHistoryModal() async {
    final history = await _service.getHistory();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lịch sử các ca chốt két', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: history.isEmpty
                    ? const Center(
                        child: Text('Chưa có lịch sử chốt két nào được lưu trên máy', style: TextStyle(color: AppColors.textMuted)),
                      )
                    : ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final rec = history[idx];
                          final diff = rec.discrepancy;
                          final isMatch = diff == 0;
                          final isMissing = diff < 0;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      rec.staffName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      '${rec.timestamp.day}/${rec.timestamp.month}/${rec.timestamp.year} ${rec.timestamp.hour.toString().padLeft(2, '0')}:${rec.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Thực tế: ${Formatters.formatVND(rec.actualCash)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isMatch
                                            ? AppColors.emerald.withValues(alpha: 0.15)
                                            : isMissing
                                                ? AppColors.error.withValues(alpha: 0.15)
                                                : Colors.blue.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isMatch
                                            ? 'Khớp 100%'
                                            : isMissing
                                                ? 'Thiếu: ${Formatters.formatVND(diff)}'
                                                : 'Thừa: +${Formatters.formatVND(diff)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isMatch
                                              ? AppColors.emerald
                                              : isMissing
                                                  ? AppColors.error
                                                  : Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (rec.notes != null) ...[
                                  const SizedBox(height: 4),
                                  Text('Ghi chú: ${rec.notes!}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final diff = _discrepancy;
    final auth = context.watch<AuthProvider>();

    Color statusColor = AppColors.emerald;
    String statusText = 'Khớp 100% (Không chênh lệch)';
    IconData statusIcon = Icons.check_circle_outline_rounded;

    if (diff < 0) {
      statusColor = AppColors.error;
      statusText = 'Thiếu tiền trong két: ${Formatters.formatVND(diff)}';
      statusIcon = Icons.warning_amber_rounded;
    } else if (diff > 0) {
      statusColor = Colors.blue;
      statusText = 'Thừa tiền trong két: +${Formatters.formatVND(diff)}';
      statusIcon = Icons.info_outline_rounded;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.point_of_sale_rounded, color: AppColors.emerald, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đối Soát & Chốt Két Tiền',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${auth.currentUser?.fullName ?? "Thu ngân"} • ${auth.selectedBranch?.branchName ?? "Chi nhánh"}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.history_rounded, color: AppColors.primaryBrand),
                    tooltip: 'Lịch sử chốt két',
                    onPressed: _showHistoryModal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // 2. Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Expected Cash Input
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calculate_outlined, color: AppColors.textSecondary, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Tiền dự kiến trong két (POS):',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            SizedBox(
                              width: 130,
                              child: TextField(
                                controller: _expectedCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [ThousandsSeparatorInputFormatter()],
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: InputDecoration(
                                  isDense: true,
                                  suffixText: ' ₫',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (v) {
                                  final val = Formatters.parseNumber(v);
                                  setState(() => _expectedCash = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Denomination List
                      const Text('Kiểm đếm số lượng từng mệnh giá:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      ..._counts.entries.map((entry) {
                        final denom = entry.key;
                        final count = entry.value;
                        final subTotal = denom * count;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: count > 0 ? AppColors.primaryBrand.withValues(alpha: 0.3) : AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 85,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  Formatters.formatVND(denom.toDouble()),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Counter Stepper
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: count > 0 ? () => _updateCount(denom, -1) : null,
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.remove_rounded, size: 16),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () => _updateCount(denom, 1),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.add_rounded, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                Formatters.formatVND(subTotal.toDouble()),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: subTotal > 0 ? AppColors.primaryBrand : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesCtrl,
                        decoration: InputDecoration(
                          labelText: 'Ghi chú chốt két giao ca',
                          hintText: 'VD: Ca sáng ngày 19/10, bàn giao cho ca chiều...',
                          prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 20),

              // 3. Status & Summary Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Thực tế trong két:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(
                          Formatters.formatVND(_actualTotal),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: statusColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: statusColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Xác nhận & Lưu Chốt Két', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _isSaving ? null : _handleConfirm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
