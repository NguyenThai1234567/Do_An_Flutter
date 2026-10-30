import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';

class ServerSettingsDialog extends StatefulWidget {
  const ServerSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ServerSettingsDialog(),
    );
  }

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  late TextEditingController _emarketController;
  late TextEditingController _aiController;

  @override
  void initState() {
    super.initState();
    _emarketController = TextEditingController(text: AppConfig.emarketBaseUrl);
    _aiController = TextEditingController(text: AppConfig.aiBaseUrl);
  }

  @override
  void dispose() {
    _emarketController.dispose();
    _aiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await AppConfig.updateEmarketBaseUrl(_emarketController.text);
    await AppConfig.updateAiBaseUrl(_aiController.text);
    ApiClient().refreshBaseUrls();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật địa chỉ máy chủ thành công!')),
      );
    }
  }

  Future<void> _reset() async {
    await AppConfig.resetToDefaults();
    ApiClient().refreshBaseUrls();
    setState(() {
      _emarketController.text = AppConfig.emarketBaseUrl;
      _aiController.text = AppConfig.aiBaseUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBrand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cloud_done_rounded, color: AppColors.primaryBrand, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cấu hình Máy chủ Cloud',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'Điểm cuối kết nối EMarket Core API & AI Assistant',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 16, color: AppColors.border),
              const Text(
                'EMarket Core API Base URL',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emarketController,
                decoration: InputDecoration(
                  hintText: AppConfig.presetCustomDomain,
                  prefixIcon: const Icon(Icons.link_rounded, size: 18, color: AppColors.primaryBrand),
                  filled: true,
                  fillColor: AppColors.surfaceSubtle,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderStrong),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderStrong),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primaryBrand, width: 1.5),
                  ),
                ),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.verified_rounded, size: 14, color: AppColors.emerald),
                    label: const Text('Domain Chính (id.vn)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: AppColors.surfaceSubtle,
                    side: const BorderSide(color: AppColors.border),
                    onPressed: () => setState(() => _emarketController.text = AppConfig.presetCustomDomain),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.primaryBrand),
                    label: const Text('Azure Backup Cloud', style: TextStyle(fontSize: 11)),
                    backgroundColor: AppColors.surfaceSubtle,
                    side: const BorderSide(color: AppColors.border),
                    onPressed: () => setState(() => _emarketController.text = AppConfig.presetAzureLegacy),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.infoBorder),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 15, color: AppColors.infoText),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ứng dụng kết nối trực tiếp tới hạ tầng Cloud sản xuất bảo mật qua HTTPS. Mọi dữ liệu giao dịch được mã hóa chuẩn TLS.',
                        style: TextStyle(fontSize: 11, color: AppColors.infoText, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'AI Assistant Service URL',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _aiController,
                decoration: InputDecoration(
                  hintText: AppConfig.presetAiAzure,
                  prefixIcon: const Icon(Icons.smart_toy_outlined, size: 18, color: AppColors.primaryBrand),
                  filled: true,
                  fillColor: AppColors.surfaceSubtle,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderStrong),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderStrong),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primaryBrand, width: 1.5),
                  ),
                ),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.primaryBrand),
                    label: const Text('Azure AI Assistant (Cloud)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: AppColors.surfaceSubtle,
                    side: const BorderSide(color: AppColors.border),
                    onPressed: () => setState(() => _aiController.text = AppConfig.presetAiAzure),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _reset,
          child: const Text('Khôi phục mặc định', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
          label: const Text('Lưu cấu hình', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBrand,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
