import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/data_repository.dart';

class VietQrDialog extends StatefulWidget {
  final double amount;
  final String orderCode;

  const VietQrDialog({
    super.key,
    required this.amount,
    required this.orderCode,
  });

  static Future<bool?> show(
    BuildContext context, {
    required double amount,
    required String orderCode,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VietQrDialog(
        amount: amount,
        orderCode: orderCode,
      ),
    );
  }

  @override
  State<VietQrDialog> createState() => _VietQrDialogState();
}

class _VietQrDialogState extends State<VietQrDialog> {
  final DataRepository _repository = DataRepository();
  bool _isLoading = true;
  String? _errorMessage;
  String? _qrCodeData;
  String? _checkoutUrl;
  int? _payOsOrderCode;
  Timer? _initialDelayTimer;
  Timer? _statusPollingTimer;
  bool _isPaid = false;

  @override
  void initState() {
    super.initState();
    _initializePayOsQr();
  }

  @override
  void dispose() {
    _initialDelayTimer?.cancel();
    _statusPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializePayOsQr() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final req = CreateQrRequest(
        amount: widget.amount.round(),
        description: 'Chuyen khoan POS',
      );

      final res = await _repository.createPayOsLink(req);
      if (!mounted) return;

      if (res.success && res.qrCode != null && res.qrCode!.isNotEmpty) {
        setState(() {
          _qrCodeData = res.qrCode;
          _checkoutUrl = res.checkoutUrl;
          _payOsOrderCode = res.orderCode;
          _isLoading = false;
        });

        // Polling trạng thái thanh toán từ PayOS
        if (_payOsOrderCode != null && _payOsOrderCode! > 0) {
          _startPollingStatus(_payOsOrderCode!);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res.message ?? 'Máy chủ PayOS không thể khởi tạo mã QR.';
          _qrCodeData = 'EMARKET_PAY_${widget.amount.round()}_${widget.orderCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi kết nối cổng thanh toán: ${e.toString().replaceFirst("Exception: ", "")}';
        _qrCodeData = 'EMARKET_PAY_${widget.amount.round()}_${widget.orderCode}';
      });
    }
  }

  void _startPollingStatus(int orderCode) {
    int checkCount = 0;
    // Delay 5s lần đầu để người dùng quét mã xong, sau đó mới thăm dò định kỳ 3s/lần
    _initialDelayTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _isPaid) return;
      _statusPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        checkCount++;
        if (checkCount > 80 || _isPaid) {
          timer.cancel();
          return;
        }

        try {
          final statusRes = await _repository.checkPayOsStatus(orderCode);
          if (!mounted) return;

          if (statusRes.success && statusRes.isPaid) {
            timer.cancel();
            setState(() {
              _isPaid = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Xác nhận: Đã nhận tiền thành công từ PayOS!'),
                backgroundColor: AppColors.success,
              ),
            );
            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) Navigator.pop(context, true);
          }
        } catch (_) {
          // Tiếp tục lắng nghe nếu mạng chập chờn
        }
      });
    });
  }

  Future<void> _openPayOsCheckout() async {
    if (_checkoutUrl == null || _checkoutUrl!.isEmpty) return;
    final uri = Uri.parse(_checkoutUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyQrData() {
    if (_qrCodeData == null) return;
    Clipboard.setData(ClipboardData(text: _qrCodeData!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép chuỗi mã VietQR vào khay nhớ tạm!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildQrWidget() {
    final qrData = _qrCodeData ?? widget.orderCode;

    // 1. Trường hợp là link hình ảnh trực tiếp
    if (qrData.startsWith('http://') || qrData.startsWith('https://')) {
      return Image.network(
        qrData,
        width: 200,
        height: 200,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildLocalQr(qrData),
      );
    }

    // 2. Trường hợp là ảnh Base64
    if (qrData.startsWith('data:image')) {
      try {
        final base64String = qrData.split(',').last;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        );
      } catch (_) {}
    }

    // 3. Chuỗi VietQR (EMVCo) từ PayOS
    // Sử dụng URL QR Generator chuẩn như giao diện Web POSEMarket để chống sập canvas và đảm bảo quét nhạy 100%
    final qrServerUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&margin=8&data=${Uri.encodeComponent(qrData)}';

    return Image.network(
      qrServerUrl,
      width: 200,
      height: 200,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          width: 200,
          height: 200,
          child: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _buildLocalQr(qrData),
    );
  }

  Widget _buildLocalQr(String data) {
    return SizedBox(
      width: 200,
      height: 200,
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
        size: 200.0,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: AppColors.primary,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppColors.textPrimary,
        ),
        errorStateBuilder: (cxt, err) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_2_rounded, size: 48, color: AppColors.primaryBrand),
                const SizedBox(height: 8),
                Text(
                  'Mã: #$_payOsOrderCode',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: AppColors.primaryBrand),
              SizedBox(width: 8),
              Text('Thanh toán VietQR / PayOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              _statusPollingTimer?.cancel();
              Navigator.pop(context, false);
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Amount Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBrand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text('Tổng tiền cần thanh toán', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.formatVND(widget.amount),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBrand,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // QR Box / Loading
              if (_isLoading)
                Container(
                  height: 220,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(height: 12),
                      Text('Đang tạo mã PayOS từ máy chủ...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: _buildQrWidget(),
                ),
                const SizedBox(height: 12),

                if (_payOsOrderCode != null)
                  Text(
                    'Mã giao dịch PayOS: #$_payOsOrderCode',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 11, color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: _isPaid ? AppColors.success : AppColors.primaryBrand,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isPaid
                          ? 'Đã nhận thanh toán thành công!'
                          : 'Đang tự động lắng nghe thanh toán...',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: _isPaid ? AppColors.success : AppColors.textMuted,
                        fontWeight: _isPaid ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Tiện ích bổ sung: Mở trang PayOS hoặc Copy QR
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_checkoutUrl != null && _checkoutUrl!.isNotEmpty) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                        label: const Text('Mở PayOS Web', style: TextStyle(fontSize: 11)),
                        onPressed: _openPayOsCheckout,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.primaryBrand,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('Sao chép mã', style: TextStyle(fontSize: 11)),
                      onPressed: _copyQrData,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('HỦY THANH TOÁN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              _statusPollingTimer?.cancel();
              Navigator.pop(context, false);
            },
          ),
        ),
      ],
    );
  }
}
