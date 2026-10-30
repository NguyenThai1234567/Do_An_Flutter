import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

class ActionSheetItem {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final bool isDestructive;
  final VoidCallback onTap;

  const ActionSheetItem({
    required this.title,
    this.subtitle,
    required this.icon,
    this.color,
    this.isDestructive = false,
    required this.onTap,
  });
}

/// Enterprise Context Menu / Popover:
/// Hiển thị menu ngữ cảnh neo trực tiếp tại vị trí nút bấm (...) thay vì bật popup giữa màn hình,
/// đồng thời có thiết kế chuẩn Enterprise (header tóm tắt đối tượng, icon màu ngữ nghĩa, mô tả phụ, phân tách tác vụ nguy hiểm).
class ModernActionSheet {
  ModernActionSheet._();

  /// Tạo nút bấm (...) mở trực tiếp Enterprise Context Popover ngay bên dưới nút.
  static Widget button({
    String? title,
    String? subtitle,
    IconData? headerIcon,
    Color? headerIconColor,
    required List<ActionSheetItem> actions,
    IconData triggerIcon = Icons.more_horiz_rounded,
    String tooltip = 'Tác vụ',
    bool compact = false,
  }) {
    return _EnterpriseContextMenuButton(
      title: title,
      subtitle: subtitle,
      headerIcon: headerIcon,
      headerIconColor: headerIconColor,
      actions: actions,
      triggerIcon: triggerIcon,
      tooltip: tooltip,
      compact: compact,
    );
  }

  /// Mở Context Menu neo theo vị trí RenderBox của `anchorContext` (nếu có),
  /// hoặc hiển thị Popover căn góc phải trên Desktop / BottomSheet gọn trên Mobile.
  static Future<void> show(
    BuildContext anchorContext, {
    required String title,
    String? subtitle,
    IconData? headerIcon,
    Color? headerIconColor,
    required List<ActionSheetItem> actions,
    Offset? tapPosition,
  }) async {
    HapticFeedback.lightImpact();

    final overlay = Overlay.maybeOf(anchorContext)?.context.findRenderObject() as RenderBox?;
    final box = anchorContext.findRenderObject() as RenderBox?;

    // Nếu anchorContext là nút bấm nhỏ hoặc có tapPosition -> mở Popover neo ngay tại nút
    if (overlay != null && (tapPosition != null || (box != null && box.hasSize && box.size.width < 220 && box.size.height < 120))) {
      final RelativeRect position;
      if (tapPosition != null) {
        position = RelativeRect.fromRect(
          Rect.fromPoints(tapPosition, tapPosition),
          Offset.zero & overlay.size,
        );
      } else {
        final targetTopLeft = box!.localToGlobal(Offset.zero, ancestor: overlay);
        final targetBottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);
        position = RelativeRect.fromRect(
          Rect.fromPoints(targetTopLeft, targetBottomRight).shift(const Offset(0, 4)),
          Offset.zero & overlay.size,
        );
      }

      final selectedIndex = await showMenu<int>(
        context: anchorContext,
        position: position,
        elevation: 12,
        shadowColor: const Color(0x280F172A),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderStrong, width: 1),
        ),
        items: _buildPopupEntries(
          title: title,
          subtitle: subtitle,
          headerIcon: headerIcon,
          headerIconColor: headerIconColor,
          actions: actions,
        ),
      );

      if (selectedIndex != null && selectedIndex >= 0 && selectedIndex < actions.length) {
        HapticFeedback.lightImpact();
        actions[selectedIndex].onTap();
      }
      return;
    }

    // Fallback cho trường hợp gọi với context của cả màn hình
    await showModalBottomSheet(
      context: anchorContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CompactBottomActionSheet(
        title: title,
        subtitle: subtitle,
        headerIcon: headerIcon,
        headerIconColor: headerIconColor,
        actions: actions,
      ),
    );
  }

  static List<PopupMenuEntry<int>> _buildPopupEntries({
    String? title,
    String? subtitle,
    IconData? headerIcon,
    Color? headerIconColor,
    required List<ActionSheetItem> actions,
  }) {
    final entries = <PopupMenuEntry<int>>[];

    if (title != null && title.trim().isNotEmpty) {
      final accent = headerIconColor ?? AppColors.primaryBrand;
      entries.add(
        PopupMenuItem<int>(
          enabled: false,
          height: 48,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Row(
            children: [
              if (headerIcon != null) ...[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(headerIcon, color: accent, size: 16),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      entries.add(const PopupMenuDivider(height: 6));
    }

    for (var i = 0; i < actions.length; i++) {
      final act = actions[i];
      if (act.isDestructive && i > 0 && !actions[i - 1].isDestructive) {
        entries.add(const PopupMenuDivider(height: 8));
      }

      final itemColor = act.isDestructive
          ? AppColors.error
          : (act.color ?? AppColors.primaryBrand);
      final titleColor = act.isDestructive
          ? AppColors.error
          : AppColors.textPrimary;

      entries.add(
        PopupMenuItem<int>(
          value: i,
          height: act.subtitle != null ? 50 : 40,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: itemColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(act.icon, color: itemColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      act.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (act.subtitle != null && act.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        act.subtitle!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return entries;
  }
}

class _EnterpriseContextMenuButton extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final IconData? headerIcon;
  final Color? headerIconColor;
  final List<ActionSheetItem> actions;
  final IconData triggerIcon;
  final String tooltip;
  final bool compact;

  const _EnterpriseContextMenuButton({
    this.title,
    this.subtitle,
    this.headerIcon,
    this.headerIconColor,
    required this.actions,
    required this.triggerIcon,
    required this.tooltip,
    required this.compact,
  });

  @override
  State<_EnterpriseContextMenuButton> createState() => _EnterpriseContextMenuButtonState();
}

class _EnterpriseContextMenuButtonState extends State<_EnterpriseContextMenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final btnSize = widget.compact ? 30.0 : 34.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: PopupMenuButton<int>(
        tooltip: widget.tooltip,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 4),
        elevation: 12,
        shadowColor: const Color(0x280F172A),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderStrong, width: 1),
        ),
        onSelected: (index) {
          if (index >= 0 && index < widget.actions.length) {
            HapticFeedback.lightImpact();
            widget.actions[index].onTap();
          }
        },
        itemBuilder: (_) => ModernActionSheet._buildPopupEntries(
          title: widget.title,
          subtitle: widget.subtitle,
          headerIcon: widget.headerIcon,
          headerIconColor: widget.headerIconColor,
          actions: widget.actions,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: btnSize,
          height: btnSize,
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.surfaceSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered ? AppColors.borderStrong : AppColors.border,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.triggerIcon,
            size: widget.compact ? 17 : 19,
            color: _isHovered ? AppColors.primaryBrand : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CompactBottomActionSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? headerIcon;
  final Color? headerIconColor;
  final List<ActionSheetItem> actions;

  const _CompactBottomActionSheet({
    required this.title,
    this.subtitle,
    this.headerIcon,
    this.headerIconColor,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final accent = headerIconColor ?? AppColors.primaryBrand;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (headerIcon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(headerIcon, color: accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),
                ...actions.map((act) {
                  final itemColor = act.isDestructive
                      ? AppColors.error
                      : (act.color ?? AppColors.primaryBrand);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
                      ),
                      tileColor: act.isDestructive
                          ? AppColors.error.withValues(alpha: 0.04)
                          : AppColors.surfaceSubtle,
                      leading: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: itemColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(act.icon, color: itemColor, size: 18),
                      ),
                      title: Text(
                        act.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: act.isDestructive ? AppColors.error : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: act.subtitle != null
                          ? Text(act.subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))
                          : null,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        act.onTap();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
