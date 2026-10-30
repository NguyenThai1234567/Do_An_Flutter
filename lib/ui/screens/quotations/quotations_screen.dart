import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/quotation_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/flat_card.dart';
import '../../widgets/modern_action_sheet.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/vnd_text.dart';
import 'create_quotation_dialog.dart';

class QuotationsScreen extends StatefulWidget {
  const QuotationsScreen({super.key});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> with SingleTickerProviderStateMixin {
  final _repository = DataRepository();
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;

  final List<String> _statuses = ['Tất cả', 'Draft', 'Sent', 'Accepted', 'Converted', 'Cancelled'];
  List<QuotationModel> _quotations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadQuotations();
      }
    });
    _loadQuotations();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadQuotations() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final branchId = auth.effectiveBranchId ?? auth.currentUser?.branchId ?? 1;

    final selectedStatus = _statuses[_tabController.index];
    final statusFilter = selectedStatus == 'Tất cả' ? null : selectedStatus;

    try {
      final list = await _repository.getQuotations(
        branchId: branchId,
        status: statusFilter,
      );
      if (mounted) {
        setState(() {
          _quotations = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return AppColors.textMuted;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return AppColors.success;
      case 'converted':
        return const Color(0xFF673AB7);
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Bản nháp';
      case 'sent':
        return 'Đã gửi';
      case 'accepted':
        return 'Đã đồng ý';
      case 'converted':
        return 'Đã tạo đơn';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Future<void> _changeStatus(QuotationModel q, String newStatus) async {
    final ok = await _repository.changeQuotationStatus(q.quotationId, newStatus);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật trạng thái: ${_getStatusLabel(newStatus)}'), backgroundColor: AppColors.success),
      );
      _loadQuotations();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể đổi trạng thái.'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _convertToOrder(QuotationModel q) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.userId ?? 1;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chuyển đổi thành Đơn hàng'),
        content: Text('Tạo ngay một đơn bán hàng chính thức (Order) từ bảng báo giá #${q.quotationCode}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chuyển đổi ngay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final orderId = await _repository.convertQuotationToOrder(q.quotationId, userId: userId);
    if (!mounted) return;

    if (orderId != null && orderId > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chuyển đổi thành công! Mã đơn bán hàng mới: #$orderId'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadQuotations();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chuyển đổi thành đơn hàng thất bại.'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showDetailModal(QuotationModel q) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollCtrl) {
            return FutureBuilder<QuotationModel?>(
              future: _repository.getQuotationDetail(q.quotationId),
              builder: (context, snapshot) {
                final detail = snapshot.data ?? q;
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: ListView(
                    controller: scrollCtrl,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(detail.quotationCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(
                                'Ngày lập: ${detail.issueDate.day}/${detail.issueDate.month}/${detail.issueDate.year}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(detail.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusLabel(detail.status),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(detail.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text('Khách hàng: ${detail.customerName ?? 'Khách vãng lai'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (detail.customerPhone != null && detail.customerPhone!.isNotEmpty)
                        Text('Số điện thoại: ${detail.customerPhone}', style: const TextStyle(color: AppColors.textMuted)),
                      if (detail.customerAddress != null && detail.customerAddress!.isNotEmpty)
                        Text('Địa chỉ: ${detail.customerAddress}', style: const TextStyle(color: AppColors.textMuted)),
                      if (detail.note != null && detail.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.note_alt_outlined, size: 18, color: Colors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ghi chú báo giá (Điều khoản, giao hàng):',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.brown),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      detail.note!,
                                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text('Chi tiết hàng hóa:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (snapshot.connectionState == ConnectionState.waiting && detail.details.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                        )
                      else if (detail.details.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Không có chi tiết mặt hàng nào', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                        )
                      else
                        ...detail.details.map((d) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text('${d.productName} (x${d.quantity})')),
                                      VndText(d.totalPrice, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  if (d.note != null && d.note!.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2, left: 8),
                                      child: Text('• ${d.note}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                                    ),
                                ],
                              ),
                            )),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tổng thanh toán:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          VndText(
                            detail.finalAmount,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.emerald),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (detail.status.toLowerCase() != 'converted' && detail.status.toLowerCase() != 'cancelled')
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                          label: const Text('Chuyển đổi thành Đơn hàng (POS)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _convertToOrder(detail);
                          },
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final branchId = auth.effectiveBranchId ?? auth.currentUser?.branchId ?? 1;

    final query = _searchCtrl.text.trim().toLowerCase();
    final displayedQuotations = query.isEmpty
        ? _quotations
        : _quotations.where((q) {
            final code = q.quotationCode.toLowerCase();
            final customer = (q.customerName ?? '').toLowerCase();
            final phone = (q.customerPhone ?? '').toLowerCase();
            return code.contains(query) || customer.contains(query) || phone.contains(query);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo giá (Quotations)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuotations,
            tooltip: 'Làm mới',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          tabs: [
            const Tab(icon: Icon(Icons.all_inbox_rounded, size: 18), text: 'Tất cả'),
            Tab(icon: Icon(Icons.edit_note_rounded, size: 18, color: _getStatusColor('draft')), text: 'Bản nháp'),
            Tab(icon: Icon(Icons.send_rounded, size: 18, color: _getStatusColor('sent')), text: 'Đã gửi'),
            Tab(icon: Icon(Icons.thumb_up_alt_rounded, size: 18, color: _getStatusColor('accepted')), text: 'Đã duyệt'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18, color: _getStatusColor('converted')), text: 'Đã lên đơn'),
            Tab(icon: Icon(Icons.cancel_outlined, size: 18, color: _getStatusColor('cancelled')), text: 'Đã hủy'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Lập báo giá', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final res = await showDialog<bool>(
            context: context,
            builder: (_) => CreateQuotationDialog(branchId: branchId),
          );
          if (res == true) _loadQuotations();
        },
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm theo mã báo giá, tên khách hàng...',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedQuotations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.request_quote_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(query.isEmpty ? 'Chưa có bảng báo giá nào' : 'Không tìm thấy báo giá phù hợp', style: const TextStyle(color: AppColors.textMuted)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadQuotations,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final contentWidth = constraints.maxWidth;
                            if (ResponsiveLayout.canShowDataTable(contentWidth)) {
                              return _buildQuotationsDataTable(displayedQuotations);
                            }
                            final gridCols = ResponsiveLayout.adaptiveGridColumns(
                              contentWidth,
                              minTileWidth: 340,
                              maxColumns: 2,
                            );
                            if (gridCols >= 2) {
                              return GridView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: 170,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: displayedQuotations.length,
                                itemBuilder: (context, index) => _buildQuotationCard(displayedQuotations[index]),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                              itemCount: displayedQuotations.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => _buildQuotationCard(displayedQuotations[index]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationsDataTable(List<QuotationModel> displayedQuotations) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('MÃ BÁO GIÁ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('KHÁCH HÀNG & LIÊN HỆ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('NGÀY LẬP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 2,
                  child: Center(child: Text('TRẠNG THÁI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4))),
                ),
                Expanded(
                  flex: 2,
                  child: Text('TỔNG THANH TOÁN', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('THAO TÁC', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: displayedQuotations.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final q = displayedQuotations[index];
                final st = q.status.toLowerCase();
                final canCreateOrder = st != 'converted' && st != 'cancelled';
                final canChangeStatus = st == 'draft' || st == 'sent';

                return InkWell(
                  onTap: () => _showDetailModal(q),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBrand.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.request_quote_rounded, size: 15, color: AppColors.primaryBrand),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  q.quotationCode,
                                  style: AppTheme.tabularStyle(const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                q.customerName ?? 'Khách vãng lai',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (q.customerPhone != null && q.customerPhone!.isNotEmpty)
                                Text(
                                  q.customerPhone!,
                                  style: AppTheme.tabularStyle(const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ),
                              if (q.note != null && q.note!.trim().isNotEmpty)
                                Text(
                                  'Ghi chú: ${q.note}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.amber),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            Formatters.formatDateTime(q.issueDate),
                            style: AppTheme.tabularStyle(const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(child: StatusBadge.fromStatus(q.status)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: VndText(
                              q.finalAmount,
                              style: AppTheme.tabularStyle(const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.emerald)),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (canCreateOrder)
                                TextButton.icon(
                                  icon: const Icon(Icons.shopping_bag_outlined, size: 15, color: AppColors.primaryBrand),
                                  label: const Text('Tạo đơn POS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBrand)),
                                  onPressed: () => _convertToOrder(q),
                                ),
                              if (canChangeStatus)
                                ModernActionSheet.button(
                                  compact: true,
                                  tooltip: 'Thao tác báo giá',
                                  title: q.quotationCode,
                                  subtitle: q.customerName ?? 'Khách vãng lai',
                                  headerIcon: Icons.request_quote_rounded,
                                  actions: [
                                    if (st == 'draft')
                                      ActionSheetItem(
                                        title: 'Đánh dấu: Đã gửi (Sent)',
                                        subtitle: 'Cập nhật trạng thái đã gửi báo giá cho khách',
                                        icon: Icons.send_rounded,
                                        color: AppColors.primaryBrand,
                                        onTap: () => _changeStatus(q, 'Sent'),
                                      ),
                                    ActionSheetItem(
                                      title: 'Đánh dấu: Đã duyệt (Accepted)',
                                      subtitle: 'Khách hàng đồng ý chốt báo giá này',
                                      icon: Icons.check_circle_outline_rounded,
                                      color: AppColors.emerald,
                                      onTap: () => _changeStatus(q, 'Accepted'),
                                    ),
                                    ActionSheetItem(
                                      title: 'Hủy báo giá',
                                      subtitle: 'Ngừng hiệu lực báo giá này',
                                      icon: Icons.cancel_outlined,
                                      isDestructive: true,
                                      onTap: () => _changeStatus(q, 'Cancelled'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationCard(QuotationModel q) {
    return FlatCard(
      onTap: () => _showDetailModal(q),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBrand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.request_quote_rounded, size: 16, color: AppColors.primaryBrand),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      q.quotationCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.tabularStyle(const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                  const Spacer(),
                  StatusBadge.fromStatus(q.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      q.customerName ?? 'Khách vãng lai',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (q.customerPhone != null && q.customerPhone!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(q.customerPhone!, style: AppTheme.tabularStyle(const TextStyle(fontSize: 11, color: AppColors.textMuted))),
                  ],
                ],
              ),
              if (q.note != null && q.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded, size: 13, color: Colors.amber),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        q.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        Formatters.formatDateTime(q.issueDate),
                        style: AppTheme.tabularStyle(const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ),
                    ],
                  ),
                  VndText(
                    q.finalAmount,
                    style: AppTheme.tabularStyle(const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.emerald)),
                  ),
                ],
              ),
            ],
          ),
          Builder(
            builder: (context) {
              final st = q.status.toLowerCase();
              final canCreateOrder = st != 'converted' && st != 'cancelled';
              final canChangeStatus = st == 'draft' || st == 'sent';

              if (!canCreateOrder && !canChangeStatus) {
                return const SizedBox.shrink();
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 8, color: AppColors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (canCreateOrder) ...[
                        TextButton.icon(
                          icon: const Icon(Icons.shopping_bag_outlined, size: 15, color: AppColors.primaryBrand),
                          label: const Text('Tạo đơn POS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBrand)),
                          onPressed: () => _convertToOrder(q),
                        ),
                      ],
                      if (canChangeStatus)
                        ModernActionSheet.button(
                          compact: true,
                          tooltip: 'Thao tác báo giá',
                          title: q.quotationCode,
                          subtitle: q.customerName ?? 'Khách vãng lai',
                          headerIcon: Icons.request_quote_rounded,
                          actions: [
                            if (st == 'draft')
                              ActionSheetItem(
                                title: 'Đánh dấu: Đã gửi (Sent)',
                                subtitle: 'Cập nhật trạng thái đã gửi báo giá cho khách',
                                icon: Icons.send_rounded,
                                color: AppColors.primaryBrand,
                                onTap: () => _changeStatus(q, 'Sent'),
                              ),
                            ActionSheetItem(
                              title: 'Đánh dấu: Đã duyệt (Accepted)',
                              subtitle: 'Khách hàng đồng ý chốt báo giá này',
                              icon: Icons.check_circle_outline_rounded,
                              color: AppColors.emerald,
                              onTap: () => _changeStatus(q, 'Accepted'),
                            ),
                            ActionSheetItem(
                              title: 'Hủy báo giá',
                              subtitle: 'Ngừng hiệu lực báo giá này',
                              icon: Icons.cancel_outlined,
                              isDestructive: true,
                              onTap: () => _changeStatus(q, 'Cancelled'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
