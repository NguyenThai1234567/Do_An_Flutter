import 'package:flutter/material.dart';

/// Ba chế độ khung ứng dụng dựa trên chiều rộng logic của toàn cửa sổ (Window Width).
enum WindowLayoutMode {
  /// Cửa sổ hẹp hoặc điện thoại (< 720dp): BottomNavigationBar + AppDrawer
  compact,

  /// Cửa sổ chia đôi (Windows Snap 50/50) hoặc Tablet (720dp - 1199dp):
  /// Slim NavigationRail (72dp) + Nút mở AppDrawer
  compactDesktop,

  /// Cửa sổ Desktop rộng (>= 1200dp):
  /// Sidebar đầy đủ phân hệ (240dp, hỗ trợ thu gọn về 72dp)
  fullDesktop,
}

/// Hệ thống kiểm tra kích thước thực tế (Window Width vs Content Area Width).
class ResponsiveLayout {
  ResponsiveLayout._();

  // Ngưỡng cửa sổ (Window Breakpoints)
  static const double compactMaxWidth = 720.0;
  static const double fullDesktopMinWidth = 1200.0;

  // Ngưỡng vùng nội dung thực tế (Content Area Breakpoints - sau khi trừ Sidebar/Rail)
  /// Chiều rộng tối thiểu của vùng nội dung để hiển thị bảng dữ liệu nhiều cột (Enterprise Data Table)
  static const double tableMinContentWidth = 880.0;

  /// Chiều rộng tối thiểu của vùng nội dung để chia 2 cột POS (Sản phẩm | Giỏ hàng)
  static const double posSplitMinContentWidth = 740.0;

  /// Chiều rộng tối thiểu của vùng nội dung để chia 4 thẻ KPI trên 1 hàng
  static const double kpiFourColMinContentWidth = 820.0;

  /// Xác định chế độ khung điều hướng theo chiều rộng toàn cửa sổ
  static WindowLayoutMode getWindowMode(double windowWidth) {
    if (windowWidth < compactMaxWidth) {
      return WindowLayoutMode.compact;
    }
    if (windowWidth < fullDesktopMinWidth) {
      return WindowLayoutMode.compactDesktop;
    }
    return WindowLayoutMode.fullDesktop;
  }

  static WindowLayoutMode ofWindow(BuildContext context) {
    return getWindowMode(MediaQuery.sizeOf(context).width);
  }

  static bool isCompactWindow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactMaxWidth;

  static bool isFullDesktopWindow(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= fullDesktopMinWidth;

  /// Kiểm tra vùng nội dung thực tế (từ LayoutBuilder.constraints.maxWidth)
  /// có đủ rộng để hiển thị bảng dữ liệu nhiều cột mà không tràn ngang hay không.
  static bool canShowDataTable(double contentWidth) =>
      contentWidth >= tableMinContentWidth;

  /// Kiểm tra vùng nội dung có đủ rộng cho bố cục 2 cột (Master-Detail / Split View)
  static bool canShowSplitView(
    double contentWidth, {
    double minWidth = 760.0,
  }) => contentWidth >= minWidth;

  /// Tính số cột Grid thích ứng dựa trên chiều rộng vùng nội dung thực tế (contentWidth)
  static int adaptiveGridColumns(
    double contentWidth, {
    double minTileWidth = 280.0,
    int minColumns = 1,
    int maxColumns = 4,
  }) {
    if (contentWidth < 560) return minColumns;
    final cols = (contentWidth / minTileWidth).floor();
    return cols.clamp(minColumns, maxColumns);
  }

  /// Khoảng đệm ngang tiêu chuẩn theo chiều rộng nội dung thực tế
  static double horizontalPadding(double contentWidth) {
    if (contentWidth >= 1040) return 24.0;
    if (contentWidth >= 680) return 20.0;
    return 16.0;
  }
}
