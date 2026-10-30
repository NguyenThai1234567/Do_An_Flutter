import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

/// Tiện ích gọi điện thoại (`tel:`), nhắn tin SMS (`sms:`) và gửi Email (`mailto:`)
/// Tương thích đa nền tảng (iOS, Android, Windows Desktop).
/// Trên thiết bị không hỗ trợ trình gọi điện/SMS (như Windows hoặc Simulator),
/// hệ thống tự động sao chép số điện thoại vào Clipboard và thông báo rõ ràng.
class DeviceLauncherHelper {
  DeviceLauncherHelper._();

  /// Chuẩn hóa số điện thoại (loại bỏ khoảng trắng, dấu gạch ngang, dấu chấm)
  static String sanitizePhone(String rawPhone) {
    final trimmed = rawPhone.trim();
    final hasPlus = trimmed.startsWith('+');
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';
    return hasPlus ? '+$digitsOnly' : digitsOnly;
  }

  /// Thực hiện cuộc gọi điện thoại
  static Future<void> callPhone(
    BuildContext context,
    String? rawPhone, {
    String? contactName,
  }) async {
    final cleanPhone = rawPhone != null ? sanitizePhone(rawPhone) : '';
    if (cleanPhone.isEmpty) {
      _showSnack(
        context,
        'Chưa có số điện thoại hợp lệ để thực hiện cuộc gọi.',
        isError: true,
      );
      return;
    }

    final telUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      final canLaunch = await canLaunchUrl(telUri);
      if (canLaunch) {
        final launched = await launchUrl(
          telUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }
    } catch (_) {
      // Fallback bên dưới
    }

    if (!context.mounted) return;
    await Clipboard.setData(ClipboardData(text: cleanPhone));
    if (!context.mounted) return;
    final targetLabel = (contactName != null && contactName.trim().isNotEmpty)
        ? '$contactName ($cleanPhone)'
        : cleanPhone;
    _showSnack(
      context,
      'Thiết bị hiện tại không hỗ trợ trình gọi điện. Đã sao chép SĐT $targetLabel vào bộ nhớ tạm!',
    );
  }

  /// Mở ứng dụng Nhắn tin SMS với nội dung tùy chọn
  static Future<void> sendSms(
    BuildContext context,
    String? rawPhone, {
    String? body,
    String? contactName,
  }) async {
    final cleanPhone = rawPhone != null ? sanitizePhone(rawPhone) : '';
    if (cleanPhone.isEmpty) {
      _showSnack(
        context,
        'Chưa có số điện thoại hợp lệ để gửi tin nhắn SMS.',
        isError: true,
      );
      return;
    }

    Uri smsUri;
    if (body != null && body.trim().isNotEmpty) {
      // Bắt buộc dùng '%20' thay vì '+' để trình nhắn tin iOS (Apple Messages) không bị lỗi hiển thị chữ nối dấu cộng '+'
      final encodedBody = Uri.encodeComponent(body.trim()).replaceAll('+', '%20');
      // Trên iOS và Android, định dạng chuẩn RFC với %20 là sms:<phone>?body=<encodedBody>
      smsUri = Uri.parse('sms:$cleanPhone?body=$encodedBody');
    } else {
      smsUri = Uri.parse('sms:$cleanPhone');
    }

    try {
      final canLaunch = await canLaunchUrl(smsUri);
      if (canLaunch) {
        final launched = await launchUrl(
          smsUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }

      // Fallback delimiter '&' cho một số phiên bản iOS cũ
      if (body != null && body.trim().isNotEmpty) {
        final encodedBody = Uri.encodeComponent(body.trim()).replaceAll('+', '%20');
        final iosAltUri = Uri.parse('sms:$cleanPhone&body=$encodedBody');
        if (await canLaunchUrl(iosAltUri)) {
          final launched = await launchUrl(
            iosAltUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return;
        }
      }
    } catch (_) {
      // Fallback bên dưới
    }

    if (!context.mounted) return;
    await Clipboard.setData(ClipboardData(text: cleanPhone));
    if (!context.mounted) return;
    final targetLabel = (contactName != null && contactName.trim().isNotEmpty)
        ? '$contactName ($cleanPhone)'
        : cleanPhone;
    _showSnack(
      context,
      'Thiết bị hiện tại không hỗ trợ gửi SMS trực tiếp. Đã sao chép SĐT $targetLabel vào bộ nhớ tạm!',
    );
  }

  /// Mở ứng dụng gửi Email
  static Future<void> sendEmail(
    BuildContext context,
    String? rawEmail, {
    String? subject,
    String? body,
  }) async {
    final cleanEmail = rawEmail?.trim() ?? '';
    if (cleanEmail.isEmpty) {
      _showSnack(
        context,
        'Chưa có địa chỉ email hợp lệ.',
        isError: true,
      );
      return;
    }

    final queryParts = <String>[];
    if (subject != null && subject.trim().isNotEmpty) {
      queryParts.add('subject=${Uri.encodeComponent(subject.trim()).replaceAll('+', '%20')}');
    }
    if (body != null && body.trim().isNotEmpty) {
      queryParts.add('body=${Uri.encodeComponent(body.trim()).replaceAll('+', '%20')}');
    }
    final mailUri = queryParts.isNotEmpty
        ? Uri.parse('mailto:$cleanEmail?${queryParts.join('&')}')
        : Uri.parse('mailto:$cleanEmail');

    try {
      final canLaunch = await canLaunchUrl(mailUri);
      if (canLaunch) {
        final launched = await launchUrl(
          mailUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }
    } catch (_) {}

    if (!context.mounted) return;
    await Clipboard.setData(ClipboardData(text: cleanEmail));
    if (!context.mounted) return;
    _showSnack(
      context,
      'Đã sao chép địa chỉ email $cleanEmail vào bộ nhớ tạm!',
    );
  }

  static void _showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppColors.error : AppColors.primaryBrand,
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.content_copy_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

