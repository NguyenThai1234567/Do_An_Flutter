import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Bộ điều khiển số lượng tương tác cao (Interactive Quantity Stepper):
/// - Chạm trực tiếp vào số lượng để gõ bàn phím số tùy ý (không cần bấm + 100 lần).
/// - Nhấn giữ nút + hoặc - (Long Press) để tăng/giảm số lượng siêu tốc.
class InteractiveQuantityStepper extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;
  final int step;
  final String? unit;
  final bool compact;
  final Color? activeColor;

  const InteractiveQuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max,
    this.step = 1,
    this.unit,
    this.compact = false,
    this.activeColor,
  });

  @override
  State<InteractiveQuantityStepper> createState() => _InteractiveQuantityStepperState();
}

class _InteractiveQuantityStepperState extends State<InteractiveQuantityStepper> {
  Timer? _periodicTimer;

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  void _update(int delta) {
    int next = widget.value + delta;
    if (next < widget.min) next = widget.min;
    if (widget.max != null && next > widget.max!) next = widget.max!;
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }

  void _startContinuousUpdate(int delta) {
    _periodicTimer?.cancel();
    int intervalMs = 150;
    int count = 0;

    _periodicTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      _update(delta);
      count++;
      // Sau 5 lần lặp, tăng tốc độ phản hồi
      if (count == 5 && intervalMs > 60) {
        timer.cancel();
        _periodicTimer = Timer.periodic(const Duration(milliseconds: 60), (_) => _update(delta * 2));
      }
    });
  }

  void _stopContinuousUpdate() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<void> _showDirectInputDialog() async {
    final controller = TextEditingController(text: widget.value.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: widget.activeColor ?? AppColors.primary),
            const SizedBox(width: 8),
            const Text('Nhập số lượng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập trực tiếp số lượng bạn muốn khai báo:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                suffixText: widget.unit,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onFieldSubmitted: (val) {
                final parsed = int.tryParse(val.trim());
                Navigator.pop(ctx, parsed);
              },
            ),
            if (widget.max != null) ...[
              const SizedBox(height: 6),
              Text(
                'Tối đa: ${widget.max}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.activeColor ?? AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, parsed);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (result != null) {
      int next = result;
      if (next < widget.min) next = widget.min;
      if (widget.max != null && next > widget.max!) next = widget.max!;
      widget.onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canMinus = widget.value > widget.min;
    final canPlus = widget.max == null || widget.value < widget.max!;
    final color = widget.activeColor ?? AppColors.primary;

    final btnSize = widget.compact ? 24.0 : 28.0;
    final iconSize = widget.compact ? 14.0 : 16.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nút Trừ
          GestureDetector(
            onTap: canMinus ? () => _update(-widget.step) : null,
            onLongPressStart: canMinus ? (_) => _startContinuousUpdate(-widget.step) : null,
            onLongPressEnd: (_) => _stopContinuousUpdate(),
            child: Container(
              width: btnSize,
              height: btnSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: canMinus ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.remove_rounded,
                size: iconSize,
                color: canMinus ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),

          // Số hiển thị (Bấm vào để nhập bàn phím trực tiếp)
          InkWell(
            onTap: _showDirectInputDialog,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              constraints: BoxConstraints(minWidth: widget.compact ? 32 : 40),
              padding: EdgeInsets.symmetric(horizontal: widget.compact ? 6 : 8, vertical: 4),
              child: Tooltip(
                message: 'Chạm để gõ số lượng trực tiếp',
                child: Text(
                  '${widget.value}${widget.unit != null ? " ${widget.unit}" : ""}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.compact ? 12 : 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
                ),
              ),
            ),
          ),

          // Nút Cộng
          GestureDetector(
            onTap: canPlus ? () => _update(widget.step) : null,
            onLongPressStart: canPlus ? (_) => _startContinuousUpdate(widget.step) : null,
            onLongPressEnd: (_) => _stopContinuousUpdate(),
            child: Container(
              width: btnSize,
              height: btnSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: canPlus ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.add_rounded,
                size: iconSize,
                color: canPlus ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
