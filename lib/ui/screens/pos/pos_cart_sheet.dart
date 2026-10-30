import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/cart_item_model.dart';
import '../../../providers/pos_cart_provider.dart';
import '../../widgets/vnd_text.dart';

/// Bottom Sheet xem và chỉnh sửa giỏ hàng POS chi tiết
class PosCartSheet extends StatelessWidget {
  final VoidCallback onProceedToCheckout;
  final VoidCallback onOpenCustomerSelector;

  const PosCartSheet({
    super.key,
    required this.onProceedToCheckout,
    required this.onOpenCustomerSelector,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onProceedToCheckout,
    required VoidCallback onOpenCustomerSelector,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PosCartSheet(
        onProceedToCheckout: onProceedToCheckout,
        onOpenCustomerSelector: onOpenCustomerSelector,
      ),
    );
  }

  void _showQuantityDialog(BuildContext context, PosCartProvider cart, CartItemModel item) {
    final stock = item.product.stockQuantity;
    final ctrl = TextEditingController(text: '${item.quantity}');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Số lượng: ${item.product.name}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kho chi nhánh hiện còn: $stock ${item.product.unit ?? "sản phẩm"}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Nhập số lượng *',
                  hintText: '1 -> $stock',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Vui lòng nhập số lượng';
                  final qty = int.tryParse(val.trim());
                  if (qty == null || qty <= 0) return 'Số lượng phải lớn hơn 0';
                  if (qty > stock) return 'Số lượng vượt quá tồn kho ($stock)';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBrand,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final qty = int.parse(ctrl.text.trim());
              final res = cart.setQuantity(item.product.productId, qty);
              Navigator.pop(dialogCtx);
              if (!res.isSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.message),
                    backgroundColor: AppColors.warning,
                  ),
                );
              }
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, PosCartProvider cart) {
    String type = 'amount'; // 'amount' | 'percent'
    final valCtrl = TextEditingController(
      text: cart.orderDiscount > 0 ? cart.orderDiscount.toStringAsFixed(0) : '',
    );
    final reasonCtrl = TextEditingController(text: cart.discountReason ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.discount_outlined, color: AppColors.emerald),
              SizedBox(width: 8),
              Text('Giảm giá đơn hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tổng tiền hàng: ${Formatters.formatVND(cart.subtotal)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),

                  // Loại giảm giá
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Theo tiền (VNĐ)'),
                          selected: type == 'amount',
                          selectedColor: AppColors.primaryBrand,
                          labelStyle: TextStyle(
                            color: type == 'amount' ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setDialogState(() => type = 'amount'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Theo % tỷ lệ'),
                          selected: type == 'percent',
                          selectedColor: AppColors.primaryBrand,
                          labelStyle: TextStyle(
                            color: type == 'percent' ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setDialogState(() => type = 'percent'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: valCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      if (type == 'amount') ThousandsSeparatorInputFormatter() else FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: type == 'amount' ? 'Số tiền giảm (VNĐ) *' : 'Phần trăm giảm (1% - 100%) *',
                      prefixIcon: Icon(type == 'amount' ? Icons.attach_money : Icons.percent, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập giá trị giảm';
                      final val = Formatters.parseNumber(v);
                      if (val <= 0) return 'Giá trị phải lớn hơn 0';
                      if (type == 'amount' && val > cart.subtotal) {
                        return 'Không thể giảm nhiều hơn tổng tiền hàng';
                      }
                      if (type == 'percent' && val > 100) {
                        return 'Tỷ lệ giảm tối đa là 100%';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: reasonCtrl,
                    decoration: InputDecoration(
                      labelText: 'Lý do giảm giá',
                      hintText: 'VD: Khách quen, Hàng cận date...',
                      prefixIcon: const Icon(Icons.notes, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (cart.orderDiscount > 0)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () {
                  cart.applyDiscount(0.0);
                  Navigator.pop(dialogCtx);
                },
                child: const Text('Bỏ giảm giá'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final val = Formatters.parseNumber(valCtrl.text);
                final reason = reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();

                if (type == 'amount') {
                  cart.applyDiscount(val, reason: reason);
                } else {
                  cart.applyDiscountPercent(val, reason: reason);
                }
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã áp dụng giảm giá đơn hàng thành công!'),
                    backgroundColor: AppColors.emerald,
                  ),
                );
              },
              child: const Text('Áp dụng'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PosCartProvider>();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart_outlined, color: AppColors.primaryBrand, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Giỏ hàng (${cart.itemCount} sản phẩm)',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                if (!cart.isEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Xóa giỏ', style: TextStyle(fontSize: 13)),
                    onPressed: () {
                      cart.clearCart();
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Customer Selector Strip
          _buildCustomerStrip(context, cart),

          // Items list
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_shopping_cart_outlined, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text('Giỏ hàng đang trống', style: TextStyle(color: AppColors.textSecondary)),
                        SizedBox(height: 4),
                        Text('Vui lòng chọn hoặc quét sản phẩm để thêm vào giỏ', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final p = item.product;
                      final stock = p.stockQuantity;
                      final isMaxStock = item.quantity >= stock;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 52,
                                height: 52,
                                color: AppColors.surfaceVariant,
                                child: p.fullImageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: p.fullImageUrl!,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 160,
                                        memCacheHeight: 160,
                                      )
                                    : const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      VndText(
                                        item.price,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.primaryBrand,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isMaxStock ? Colors.orange.shade50 : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isMaxStock ? 'Tối đa: $stock' : 'Kho: $stock',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isMaxStock ? Colors.orange.shade800 : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Quantity Stepper & Tap-to-edit
                            Row(
                              children: [
                                _StepperButton(
                                  icon: Icons.remove,
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    cart.updateQuantity(p.productId, -1);
                                  },
                                ),
                                InkWell(
                                  onTap: () => _showQuantityDialog(context, cart, item),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 40),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.transparent),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '${item.quantity}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isMaxStock ? Colors.orange.shade900 : AppColors.textPrimary,
                                          ),
                                        ),
                                        const Text('Sửa', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                ),
                                _StepperButton(
                                  icon: Icons.add,
                                  isDisabled: isMaxStock,
                                  onPressed: () {
                                    if (isMaxStock) {
                                      HapticFeedback.vibrate();
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Kho chỉ còn $stock sản phẩm "${p.name}".'),
                                          duration: const Duration(seconds: 1),
                                          backgroundColor: AppColors.warning,
                                        ),
                                      );
                                      return;
                                    }
                                    HapticFeedback.lightImpact();
                                    cart.updateQuantity(p.productId, 1);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Summary & Checkout Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Subtotal row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng tiền hàng:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    VndText(cart.subtotal, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),

                // Discount row with Edit button
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Chiết khấu / Giảm giá:', style: TextStyle(color: AppColors.emerald, fontSize: 13)),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: cart.isEmpty ? null : () => _showDiscountDialog(context, cart),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.edit, size: 11, color: AppColors.emerald),
                                SizedBox(width: 2),
                                Text('Sửa', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.emerald)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    VndText(
                      cart.totalDiscount,
                      prefix: '-',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.emerald),
                    ),
                  ],
                ),
                if (cart.discountReason != null && cart.discountReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          '(${cart.discountReason})',
                          style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Final Total Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TỔNG THANH TOÁN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    VndText(
                      cart.finalTotal,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.emerald),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Checkout CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: cart.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context);
                            onProceedToCheckout();
                          },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'TIẾN HÀNH THANH TOÁN',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerStrip(BuildContext context, PosCartProvider cart) {
    final customer = cart.selectedCustomer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  customer != null ? Icons.person : Icons.person_outline,
                  size: 18,
                  color: customer != null ? AppColors.primaryBrand : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customer != null ? customer.name : 'Khách vãng lai (Chưa tích điểm)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: customer != null ? FontWeight.bold : FontWeight.normal,
                      color: customer != null ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () {
              Navigator.pop(context);
              onOpenCustomerSelector();
            },
            child: Text(
              customer != null ? 'Đổi khách' : 'Chọn khách',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDisabled;

  const _StepperButton({
    required this.icon,
    required this.onPressed,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey.shade200 : AppColors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16, color: isDisabled ? Colors.grey.shade400 : AppColors.textPrimary),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onPressed,
      ),
    );
  }
}
