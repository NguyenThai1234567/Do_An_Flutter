import 'package:flutter/foundation.dart';
import '../data/models/cart_item_model.dart';
import '../data/models/order_model.dart';
import '../data/models/product_model.dart';
import '../data/repositories/data_repository.dart';
import '../data/models/customer_model.dart';

enum AddToCartStatus {
  success,
  outOfStock,
  exceedsStock,
  notFound,
  error,
}

class AddToCartResult {
  final AddToCartStatus status;
  final String message;
  final int currentQty;
  final int maxStock;

  AddToCartResult({
    required this.status,
    required this.message,
    this.currentQty = 0,
    this.maxStock = 0,
  });

  bool get isSuccess => status == AddToCartStatus.success;
  bool get isOutOfStock => status == AddToCartStatus.outOfStock;
  bool get isExceedsStock => status == AddToCartStatus.exceedsStock;
  bool get isNotFound => status == AddToCartStatus.notFound;
}

class PosCartProvider with ChangeNotifier {
  final DataRepository _repository = DataRepository();

  final Map<int, CartItemModel> _items = {};
  double _orderDiscount = 0.0;
  String? _discountReason;
  String _paymentMethod = 'Cash'; // 'Cash' | 'VietQR'
  String? _note;
  int? _customerId;
  CustomerModel? _selectedCustomer;
  int _pointsUsed = 0;
  bool _isCheckingOut = false;
  String? _checkoutError;

  List<CartItemModel> get items => _items.values.toList();
  int get itemCount => _items.values.fold(0, (sum, i) => sum + i.quantity);
  double get orderDiscount => _orderDiscount;
  String? get discountReason => _discountReason;
  String get paymentMethod => _paymentMethod;
  String? get note => _note;
  int? get customerId => _customerId;
  CustomerModel? get selectedCustomer => _selectedCustomer;
  int get pointsUsed => _pointsUsed;
  bool get isCheckingOut => _isCheckingOut;
  String? get checkoutError => _checkoutError;

  double get subtotal => _items.values.fold(0.0, (sum, i) => sum + i.subtotal);
  double get pointsDiscount => (_pointsUsed * 1000).toDouble(); // 1 điểm = 1.000 VNĐ
  double get totalDiscount => _orderDiscount + pointsDiscount + _items.values.fold(0.0, (sum, i) => sum + i.discount);
  double get finalTotal => (subtotal - totalDiscount).clamp(0.0, double.infinity);

  bool get isEmpty => _items.isEmpty;

  /// Lấy số lượng của một sản phẩm hiện đang có trong giỏ hàng
  int getProductCartQuantity(int productId) => _items[productId]?.quantity ?? 0;

  void selectCustomer(CustomerModel? customer) {
    _selectedCustomer = customer;
    _customerId = customer?.customerId;
    _pointsUsed = 0;
    // Tự động áp dụng chiết khấu hạng thành viên nếu có
    if (customer != null && customer.discountRate > 0) {
      _orderDiscount = subtotal * customer.discountRate;
      _discountReason = 'Chiết khấu hạng ${customer.customerType} (${(customer.discountRate * 100).toInt()}%)';
    } else {
      _orderDiscount = 0.0;
      _discountReason = null;
    }
    notifyListeners();
  }

  void setPointsUsed(int points) {
    if (_selectedCustomer == null) return;
    _pointsUsed = points.clamp(0, _selectedCustomer!.pointBalance);
    notifyListeners();
  }

  /// Thêm sản phẩm vào giỏ hàng với đầy đủ kiểm tra ràng buộc tồn kho
  AddToCartResult addToCart(ProductModel product, {int quantity = 1}) {
    final stock = product.stockQuantity;

    // 1. Kiểm tra tồn kho lần đầu
    if (stock <= 0) {
      return AddToCartResult(
        status: AddToCartStatus.outOfStock,
        message: 'Sản phẩm "${product.name}" đã hết hàng tại chi nhánh.',
        currentQty: 0,
        maxStock: 0,
      );
    }

    final currentQty = _items[product.productId]?.quantity ?? 0;

    // 2. Kiểm tra nếu số lượng yêu cầu vượt quá tồn kho còn lại
    if (currentQty + quantity > stock) {
      return AddToCartResult(
        status: AddToCartStatus.exceedsStock,
        message: 'Kho chỉ còn $stock sản phẩm (trong giỏ đã có $currentQty).',
        currentQty: currentQty,
        maxStock: stock,
      );
    }

    // 3. Hợp lệ -> Thêm vào giỏ
    if (_items.containsKey(product.productId)) {
      _items[product.productId]!.increment(quantity);
    } else {
      _items[product.productId] = CartItemModel(
        product: product,
        quantity: quantity,
      );
    }

    // Tự động tính lại chiết khấu khách hàng nếu có
    if (_selectedCustomer != null && _selectedCustomer!.discountRate > 0) {
      _orderDiscount = subtotal * _selectedCustomer!.discountRate;
    }

    notifyListeners();
    return AddToCartResult(
      status: AddToCartStatus.success,
      message: 'Đã thêm "${product.name}" vào giỏ hàng.',
      currentQty: currentQty + quantity,
      maxStock: stock,
    );
  }

  /// Cập nhật số lượng (+/- delta) với kiểm tra tồn kho
  AddToCartResult updateQuantity(int productId, int delta) {
    if (!_items.containsKey(productId)) {
      return AddToCartResult(
        status: AddToCartStatus.error,
        message: 'Sản phẩm không có trong giỏ hàng.',
      );
    }

    final item = _items[productId]!;
    final stock = item.product.stockQuantity;

    if (delta > 0) {
      if (item.quantity + delta > stock) {
        return AddToCartResult(
          status: AddToCartStatus.exceedsStock,
          message: 'Kho chỉ còn $stock sản phẩm.',
          currentQty: item.quantity,
          maxStock: stock,
        );
      }
      item.increment(delta);
    } else if (delta < 0) {
      if (item.quantity <= 1) {
        removeFromCart(productId);
        return AddToCartResult(
          status: AddToCartStatus.success,
          message: 'Đã xóa sản phẩm khỏi giỏ hàng.',
          currentQty: 0,
          maxStock: stock,
        );
      }
      item.decrement(-delta);
    }

    if (_selectedCustomer != null && _selectedCustomer!.discountRate > 0) {
      _orderDiscount = subtotal * _selectedCustomer!.discountRate;
    }

    notifyListeners();
    return AddToCartResult(
      status: AddToCartStatus.success,
      message: 'Đã cập nhật số lượng.',
      currentQty: item.quantity,
      maxStock: stock,
    );
  }

  /// Nhập tay trực tiếp số lượng cụ thể
  AddToCartResult setQuantity(int productId, int newQuantity) {
    if (!_items.containsKey(productId)) {
      return AddToCartResult(
        status: AddToCartStatus.error,
        message: 'Sản phẩm không có trong giỏ.',
      );
    }

    final item = _items[productId]!;
    final stock = item.product.stockQuantity;

    if (newQuantity <= 0) {
      removeFromCart(productId);
      return AddToCartResult(
        status: AddToCartStatus.success,
        message: 'Đã xóa sản phẩm khỏi giỏ hàng.',
        currentQty: 0,
        maxStock: stock,
      );
    }

    if (newQuantity > stock) {
      item.quantity = stock;
      if (_selectedCustomer != null && _selectedCustomer!.discountRate > 0) {
        _orderDiscount = subtotal * _selectedCustomer!.discountRate;
      }
      notifyListeners();
      return AddToCartResult(
        status: AddToCartStatus.exceedsStock,
        message: 'Kho chỉ còn $stock sản phẩm. Đã điều chỉnh về tồn kho tối đa.',
        currentQty: stock,
        maxStock: stock,
      );
    }

    item.quantity = newQuantity;
    if (_selectedCustomer != null && _selectedCustomer!.discountRate > 0) {
      _orderDiscount = subtotal * _selectedCustomer!.discountRate;
    }
    notifyListeners();
    return AddToCartResult(
      status: AddToCartStatus.success,
      message: 'Đã cập nhật số lượng thành $newQuantity.',
      currentQty: newQuantity,
      maxStock: stock,
    );
  }

  void removeFromCart(int productId) {
    _items.remove(productId);
    if (_selectedCustomer != null && _selectedCustomer!.discountRate > 0) {
      _orderDiscount = subtotal * _selectedCustomer!.discountRate;
    } else if (_orderDiscount > subtotal) {
      _orderDiscount = subtotal;
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _orderDiscount = 0.0;
    _discountReason = null;
    _note = null;
    _customerId = null;
    _selectedCustomer = null;
    _pointsUsed = 0;
    _checkoutError = null;
    notifyListeners();
  }

  /// Áp dụng giảm giá thủ công trực tiếp bằng số tiền
  void applyDiscount(double amount, {String? reason}) {
    _orderDiscount = amount.clamp(0.0, subtotal);
    _discountReason = reason ?? 'Giảm giá trực tiếp';
    notifyListeners();
  }

  /// Áp dụng giảm giá theo phần trăm (%)
  void applyDiscountPercent(double percent, {String? reason}) {
    final validPercent = percent.clamp(0.0, 100.0);
    _orderDiscount = (subtotal * (validPercent / 100.0)).clamp(0.0, subtotal);
    _discountReason = reason ?? 'Giảm giá ${validPercent.toStringAsFixed(0)}%';
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setNote(String? noteText) {
    _note = noteText;
  }

  void setCustomer(int? id) {
    _customerId = id;
    notifyListeners();
  }

  /// Thêm sản phẩm qua Barcode có kiểm tra tồn kho
  AddToCartResult addByBarcode(String barcode, List<ProductModel> catalog) {
    final cleanBarcode = barcode.trim().toLowerCase();
    for (final prod in catalog) {
      if (prod.sku.toLowerCase() == cleanBarcode) {
        return addToCart(prod);
      }
    }
    return AddToCartResult(
      status: AddToCartStatus.notFound,
      message: 'Không tìm thấy sản phẩm có mã "$barcode" trong danh mục.',
    );
  }

  /// Tạo link thanh toán PayOS QR qua backend
  Future<CreateQrResponse> createPayOsPayment(int amount, {String? description}) async {
    final desc = description ?? 'Thanh toan POS';
    return await _repository.createPayOsLink(CreateQrRequest(amount: amount, description: desc));
  }

  /// Kiểm tra trạng thái thanh toán PayOS
  Future<PayOsStatusResponse> checkPayOsStatus(int orderCode) async {
    return await _repository.checkPayOsStatus(orderCode);
  }

  /// Thực hiện Checkout và lập đơn hàng
  Future<CheckoutResult?> checkout({
    int? branchId,
    int? userId,
    String? connectionId,
  }) async {
    if (isEmpty) {
      _checkoutError = 'Giỏ hàng đang trống. Vui lòng thêm sản phẩm trước khi thanh toán.';
      notifyListeners();
      return null;
    }

    _isCheckingOut = true;
    _checkoutError = null;
    notifyListeners();

    try {
      final calculatedPointsEarned = (finalTotal / 1000).floor();

      final request = CheckoutRequest(
        userId: userId,
        branchId: branchId,
        customerId: (_customerId != null && _customerId! > 0) ? _customerId : 1,
        pointsUsed: _pointsUsed,
        pointsEarned: calculatedPointsEarned,
        totalAmount: finalTotal,
        manualDiscount: _orderDiscount + pointsDiscount,
        manualDiscountReason: _discountReason ?? _note,
        status: 'Completed',
        paymentMethod: _paymentMethod,
        connectionId: connectionId,
        items: _items.values.map((i) {
          return CheckoutItemRequest(
            productId: i.product.productId,
            quantity: i.quantity,
            price: i.price,
            discount: i.discount,
          );
        }).toList(),
      );

      final result = await _repository.checkout(request);
      if (result.success) {
        clearCart();
      } else {
        _checkoutError = result.message ?? 'Tạo đơn hàng không thành công.';
      }
      _isCheckingOut = false;
      notifyListeners();
      return result;
    } catch (e) {
      _checkoutError = e.toString().replaceFirst('Exception: ', '');
      _isCheckingOut = false;
      notifyListeners();
      return null;
    }
  }
}
