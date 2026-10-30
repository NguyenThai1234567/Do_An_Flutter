import 'package:flutter/material.dart';

/// Provider điều phối chuyển đổi Tab chính trên toàn ứng dụng.
/// Cho phép Hamburger Drawer, Quick Action Hub hoặc bất kỳ màn hình con nào
/// có thể chuyển tab một cách mượt mà và đồng bộ.
class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}
