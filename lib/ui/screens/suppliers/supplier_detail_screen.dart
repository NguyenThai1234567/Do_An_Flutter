import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/device_launcher_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../main_navigation_screen.dart';
import 'add_edit_supplier_dialog.dart';
import 'pay_supplier_debt_dialog.dart';
import 'supplier_debt_payment_history_dialog.dart';

class SupplierDetailScreen extends StatefulWidget {
  final SupplierModel supplier;

  const SupplierDetailScreen({
    super.key,
    required this.supplier,
  });

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  late SupplierModel _currentSupplier;
  final _repo = DataRepository();
  bool _isLoading = true;
  bool _hasChanged = false;
  List<SupplierDebtModel> _debts = [];
  SupplierDebtSummaryModel _summary = SupplierDebtSummaryModel();

  @override
  void initState() {
    super.initState();
    _currentSupplier = widget.supplier;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.getSupplierDebts(supplierId: _currentSupplier.supplierId),
        _repo.getSupplierDebtSummary(supplierId: _currentSupplier.supplierId),
        _repo.getSupplierById(_currentSupplier.supplierId),
      ]);
      if (mounted) {
        final debts = results[0] as List<SupplierDebtModel>;
        var summary = results[1] as SupplierDebtSummaryModel;
        final freshSupplier = results[2] as SupplierModel?;

        final totalUnpaidFromDebts = debts.fold(0.0, (sum, d) => sum + d.remainingAmount);
        final totalPaidFromDebts = debts.fold(0.0, (sum, d) => sum + d.paidAmount);
        final totalPurchaseFromDebts = debts.fold(0.0, (sum, d) => sum + d.totalAmount);

        summary = SupplierDebtSummaryModel(
          totalDebt: totalPurchaseFromDebts > 0 ? totalPurchaseFromDebts : summary.totalDebt,
          totalPaid: totalPaidFromDebts > 0 ? totalPaidFromDebts : summary.totalPaid,
          totalRemaining: totalUnpaidFromDebts,
          payRate: totalPurchaseFromDebts > 0 ? ((totalPaidFromDebts / totalPurchaseFromDebts) * 100) : summary.payRate,
          nearDueCount: summary.nearDueCount,
          overdueCount: summary.overdueCount,
          totalRecords: debts.length,
        );

        setState(() {
          if (freshSupplier != null) {
            _currentSupplier = freshSupplier;
          }
          _debts = debts;
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _callPhone(String phone) async {
    await DeviceLauncherHelper.callPhone(
      context,
      phone,
      contactName: _currentSupplier.name,
    );
  }

  Future<void> _sendSms(String phone) async {
    await DeviceLauncherHelper.sendSms(
      context,
      phone,
      contactName: _currentSupplier.name,
    );
  }

  Future<void> _sendEmail(String email) async {
    await DeviceLauncherHelper.sendEmail(
      context,
      email,
      subject: 'Liên hệ đối tác NCC - ${_currentSupplier.name}',
    );
  }

  String? _extractCleanMapUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Nếu chứa thẻ <iframe>, bóc tách src="..." hoặc src='...'
    if (trimmed.toLowerCase().contains('<iframe')) {
      final regExp = RegExp(r'src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false);
      final match = regExp.firstMatch(trimmed);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }
    return trimmed;
  }

  Future<void> _openMap() async {
    final raw = _currentSupplier.addressUrl?.trim();
    final cleanUrl = _extractCleanMapUrl(raw);

    Uri uri;
    // Nếu là link embed Google Maps, không bao giờ được launch trực tiếp vì Google sẽ báo:
    // "The Google Maps Embed API must be used in an iframe."
    // Thay vào đó, chuyển sang Google Maps Universal Search URL để mở bản đồ chính thức
    final isEmbed = cleanUrl != null && (cleanUrl.contains('/maps/embed') || cleanUrl.contains('output=embed'));

    if (cleanUrl != null && cleanUrl.isNotEmpty && !isEmbed && (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://'))) {
      uri = Uri.parse(cleanUrl);
    } else {
      final query = Uri.encodeComponent('${_currentSupplier.name} ${_currentSupplier.address ?? ''}'.trim());
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Không thể mở ứng dụng bản đồ!'),
          ),
        );
      }
    }
  }

  void _copyAddress() {
    final raw = _currentSupplier.addressUrl?.trim();
    final cleanUrl = _extractCleanMapUrl(raw);
    final isEmbed = cleanUrl != null && (cleanUrl.contains('/maps/embed') || cleanUrl.contains('output=embed'));

    String textToCopy;
    if (cleanUrl != null && cleanUrl.isNotEmpty && !isEmbed) {
      textToCopy = cleanUrl;
    } else if (_currentSupplier.address != null && _currentSupplier.address!.trim().isNotEmpty) {
      textToCopy = _currentSupplier.address!.trim();
    } else {
      final query = Uri.encodeComponent('${_currentSupplier.name} ${_currentSupplier.address ?? ''}'.trim());
      textToCopy = 'https://www.google.com/maps/search/?api=1&query=$query';
    }

    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.success,
        content: Text('Đã sao chép liên kết bản đồ / địa chỉ vào bộ nhớ đệm!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _hasChanged);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context, _hasChanged),
                )
              : MainNavigationScreen.buildLeadingMenuButton(context),
          title: Text(
            _currentSupplier.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (context.watch<AuthProvider>().currentUser?.isSupplier != true)
              IconButton(
                tooltip: 'Chỉnh sửa NCC',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  AddEditSupplierDialog.show(
                    context,
                    supplier: _currentSupplier,
                    onSaved: () {
                      _hasChanged = true;
                      _loadData();
                    },
                  );
                },
              ),
            IconButton(
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
            IconButton(
              tooltip: 'Danh mục phân hệ',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => MainNavigationScreen.openDrawer(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Supplier Info Card
                      _buildSupplierCard(),
                      const SizedBox(height: 16),

                      // Debt Summary KPIs (3 Tiles chuẩn kế toán)
                      _buildDebtSummaryCards(),
                      const SizedBox(height: 20),

                      // Debt List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Text(
                              'Lịch sử Công nợ / Đơn nhập',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_debts.length}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Debt items
                    if (_debts.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.success),
                            SizedBox(height: 10),
                            Text(
                              'Không có ghi nhận công nợ nào!',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Nhà cung cấp này hiện không có công nợ tồn đọng.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _debts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final debt = _debts[index];
                          return _buildDebtCard(debt);
                        },
                      ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildSupplierCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxInsets.cardShadow,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentSupplier.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    if (_currentSupplier.contactName != null && _currentSupplier.contactName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Liên hệ: ${_currentSupplier.contactName}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (_currentSupplier.phone != null && _currentSupplier.phone!.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _callPhone(_currentSupplier.phone!),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            _currentSupplier.phone!,
                            style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Text('Gọi ngay', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _sendSms(_currentSupplier.phone!),
                  icon: const Icon(Icons.sms_outlined, size: 14, color: AppColors.secondary),
                  label: const Text('Nhắn SMS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.secondary)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
          if (_currentSupplier.email != null && _currentSupplier.email!.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _sendEmail(_currentSupplier.email!),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      _currentSupplier.email!,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if ((_currentSupplier.address != null && _currentSupplier.address!.trim().isNotEmpty) ||
              (_currentSupplier.addressUrl != null && _currentSupplier.addressUrl!.trim().isNotEmpty)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentSupplier.address != null && _currentSupplier.address!.trim().isNotEmpty
                              ? _currentSupplier.address!
                              : 'Vị trí nhà cung cấp',
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openMap,
                          icon: const Icon(Icons.map_rounded, size: 15),
                          label: const Text('Mở Google Maps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A73E8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyAddress,
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text('Sao chép địa chỉ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebtSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Tổng chi phí nhập',
            amount: _summary.totalDebt,
            color: AppColors.info,
            icon: Icons.receipt_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Đã trả NCC',
            amount: _summary.totalPaid,
            color: AppColors.success,
            icon: Icons.check_circle_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Còn nợ phải trả',
            amount: _summary.totalRemaining,
            color: AppColors.error,
            icon: Icons.warning_amber_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            Formatters.formatVND(amount),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(SupplierDebtModel debt) {
    final isPaid = debt.status.toUpperCase() == 'PAID' || debt.remainingAmount <= 0.01;
    final hasDue = !isPaid;

    Color statusColor;
    String statusText;
    if (isPaid) {
      statusColor = AppColors.success;
      statusText = 'ĐÃ TRẢ HẾT';
    } else {
      switch (debt.status.toUpperCase()) {
        case 'PARTIAL':
          statusColor = AppColors.warning;
          statusText = 'TRẢ MỘT PHẦN';
          break;
        case 'OVERDUE':
          statusColor = AppColors.error;
          statusText = 'QUÁ HẠN';
          break;
        default:
          statusColor = AppColors.error;
          statusText = 'CHƯA TRẢ';
          break;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        SupplierDebtPaymentHistoryDialog.show(
          context,
          debt: debt,
          onPaymentAdded: () {
            _hasChanged = true;
            _loadData();
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hasDue ? AppColors.warning.withValues(alpha: 0.3) : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Phiếu nợ #${debt.debtId}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    if (debt.purchaseOrderId != null && debt.purchaseOrderId! > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'PO #${debt.purchaseOrderId}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            if (debt.createdDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Ngày tạo: ${Formatters.formatDateTime(debt.createdDate)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tổng nợ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text(Formatters.formatVND(debt.totalDebtAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Đã trả', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text(Formatters.formatVND(debt.paidAmount), style: const TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Còn lại', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text(
                      Formatters.formatVND(debt.remainingAmount),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: hasDue ? AppColors.error : AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    SupplierDebtPaymentHistoryDialog.show(
                      context,
                      debt: debt,
                      onPaymentAdded: () {
                        _hasChanged = true;
                        _loadData();
                      },
                    );
                  },
                  icon: const Icon(Icons.history_edu_rounded, size: 15, color: AppColors.primaryBrand),
                  label: const Text(
                    'Lịch sử trả nợ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryBrand),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: BorderSide(color: AppColors.primaryBrand.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (hasDue && context.read<AuthProvider>().currentUser?.isSupplier != true) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      PaySupplierDebtDialog.show(
                        context,
                        debt: debt,
                        onPaid: () {
                          _hasChanged = true;
                          _loadData();
                        },
                      );
                    },
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: const Text('Thanh toán'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class BoxInsets {
  static BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );
}

