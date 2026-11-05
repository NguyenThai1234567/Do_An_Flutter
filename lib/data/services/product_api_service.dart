import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/product_model.dart';

class ProductApiService {
  final ApiClient _client = ApiClient();

  /// Get Products with Pagination and Filters (supports supplierId)
  Future<ProductPagedResponse> getProductsPaged({
    int start = 0,
    int length = 20,
    String? keyword,
    int? categoryId,
    int? branchId,
    int? warehouseId,
    int? supplierId,
  }) async {
    final queryParams = <String, dynamic>{
      'start': start,
      'length': length,
      if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      if (categoryId != null && categoryId > 0) 'categoryId': categoryId,
      if (branchId != null && branchId > 0) 'branchId': branchId,
      if (warehouseId != null && warehouseId > 0) 'warehouseId': warehouseId,
      if (supplierId != null && supplierId > 0) 'supplierId': supplierId,
    };

    // 1. Query standard pagedProducts endpoint
    try {
      final res = await _client.get(
        ApiEndpoints.pagedProducts,
        queryParameters: queryParams,
      );

      final paged = ProductPagedResponse.fromJson(res.data);
      if (paged.data.isNotEmpty) {
        return paged;
      }
    } catch (_) {}

    // 2. Fallback to /Admin/Product/GetAllProduct (or api/admin/product/GetAllProduct)
    try {
      final fallback = await _client.get(
        'Admin/Product/GetAllProduct',
        queryParameters: {
          if (keyword != null && keyword.trim().isNotEmpty) 'keyWord': keyword.trim(),
          if (supplierId != null && supplierId > 0) 'supplierId': supplierId,
          if (branchId != null && branchId > 0) 'branchId': branchId,
          if (categoryId != null && categoryId > 0) 'categoryId': categoryId,
        },
      );
      final paged = ProductPagedResponse.fromJson(fallback.data);
      if (paged.data.isNotEmpty) {
        return paged;
      }
    } catch (_) {}

    return ProductPagedResponse(total: 0, filtered: 0, data: []);
  }

  /// Search products by barcode or text (supports scanner, camera & manual typing)
  Future<List<ProductModel>> searchByBarcode(String barcode, {int? branchId}) async {
    final query = barcode.trim();
    if (query.isEmpty) return [];

    final queryParams = <String, dynamic>{
      'barcode': query,
      'keyword': query,
      if (branchId != null && branchId > 0) 'branchId': branchId,
    };

    // 1. Try search-simple (supports both product name and barcode)
    try {
      final res = await _client.get(
        ApiEndpoints.searchProductsSimple,
        queryParameters: queryParams,
      );

      dynamic rawList = res.data;
      if (res.data is Map<String, dynamic>) {
        rawList = res.data['data'] ?? res.data['Data'] ?? res.data['items'];
      }

      if (rawList is List && rawList.isNotEmpty) {
        return rawList.map((e) => ProductModel.fromJson(e)).toList();
      }
    } catch (_) {}

    // 2. Fallback to by-barcode
    try {
      final res = await _client.get(
        '${ApiEndpoints.allProducts}/by-barcode',
        queryParameters: queryParams,
      );

      dynamic rawList = res.data;
      if (res.data is Map<String, dynamic>) {
        rawList = res.data['data'] ?? res.data['Data'] ?? res.data['items'];
      }

      if (rawList is List) {
        return rawList.map((e) => ProductModel.fromJson(e)).toList();
      } else if (rawList is Map<String, dynamic>) {
        return [ProductModel.fromJson(rawList)];
      }
    } catch (_) {}
    return [];
  }

  /// Get Product Categories
  Future<List<ProductCategoryModel>> getCategories() async {
    try {
      final res = await _client.get(ApiEndpoints.productCategories);
      if (res.data is List) {
        return (res.data as List).map((e) => ProductCategoryModel.fromJson(e)).toList();
      }
      if (res.data is Map<String, dynamic>) {
        final list = res.data['data'] ?? res.data['Data'] ?? res.data['categories'];
        if (list is List) {
          return list.map((e) => ProductCategoryModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Get Lots for a specific product (FEFO Tracking)
  Future<List<ProductLotModel>> getProductLots(int productId) async {
    try {
      final res = await _client.get('${ApiEndpoints.productLots}/$productId');
      if (res.data is List) {
        return (res.data as List).map((e) => ProductLotModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get Low Stock Alerts
  Future<List<ProductModel>> getLowStockAlerts({int top = 20}) async {
    try {
      final res = await _client.get(
        ApiEndpoints.lowStockAlerts,
        queryParameters: {'top': top},
      );
      if (res.data is List) {
        return (res.data as List).map((e) => ProductModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get Suppliers list
  Future<List<SupplierModel>> getSuppliers({String? keyword}) async {
    try {
      final res = await _client.get(
        ApiEndpoints.suppliers,
        queryParameters: {
          if (keyword != null && keyword.trim().isNotEmpty) 'name': keyword.trim(),
        },
      );
      if (res.data is List) {
        return (res.data as List).map((e) => SupplierModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get Supplier by ID
  Future<SupplierModel?> getSupplierById(int id) async {
    try {
      final res = await _client.get('${ApiEndpoints.suppliers}/$id');
      if (res.data is Map<String, dynamic>) {
        return SupplierModel.fromJson(res.data);
      }
    } catch (_) {}
    return null;
  }

  /// Create new supplier
  Future<bool> createSupplier(Map<String, dynamic> data) async {
    try {
      final res = await _client.post(ApiEndpoints.suppliers, data: data);
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Update existing supplier
  Future<bool> updateSupplier(Map<String, dynamic> data) async {
    try {
      final res = await _client.put(ApiEndpoints.suppliers, data: data);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Delete supplier
  Future<bool> deleteSupplier(int supplierId) async {
    try {
      final res = await _client.delete('${ApiEndpoints.suppliers}/$supplierId');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get supplier debts
  Future<List<SupplierDebtModel>> getSupplierDebts({int? supplierId, String? status, String? keyword}) async {
    // 1. Nếu có supplierId cụ thể, ưu tiên gọi endpoint debt/paged có bộ lọc trực tiếp từ backend
    if (supplierId != null && supplierId > 0) {
      try {
        final queryParams = <String, dynamic>{
          'start': 0,
          'length': 500,
          'supplierId': supplierId,
          if (status != null && status.isNotEmpty && status != 'ALL') 'status': status,
          if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        };
        final res = await _client.get(ApiEndpoints.supplierDebtsPaged, queryParameters: queryParams);
        dynamic raw = res.data;
        if (raw is Map<String, dynamic>) {
          raw = raw['data'] ?? raw['Data'];
        }
        if (raw is List) {
          return raw.map((e) => SupplierDebtModel.fromJson(e)).toList();
        }
      } catch (_) {}
    }

    // 2. Gọi api/admin/inventory/debt/all (Toàn bộ công nợ đã được backend JOIN và lọc chuẩn)
    try {
      final res = await _client.get(ApiEndpoints.supplierDebtsAll);
      dynamic raw = res.data;
      if (raw is Map<String, dynamic>) {
        raw = raw['data'] ?? raw['Data'];
      }
      if (raw is List) {
        var list = raw.map((e) => SupplierDebtModel.fromJson(e)).toList();
        if (supplierId != null && supplierId > 0) {
          list = list.where((d) => d.supplierId == supplierId).toList();
        }
        if (status != null && status.isNotEmpty && status != 'ALL') {
          list = list.where((d) => d.status.toLowerCase() == status.toLowerCase()).toList();
        }
        if (keyword != null && keyword.trim().isNotEmpty) {
          final kw = keyword.trim().toLowerCase();
          list = list.where((d) => d.supplierName.toLowerCase().contains(kw) || d.debtId.toString().contains(kw)).toList();
        }
        return list;
      }
    } catch (_) {}

    return [];
  }

  /// Get supplier debt summary KPI
  Future<SupplierDebtSummaryModel> getSupplierDebtSummary({int? supplierId}) async {
    try {
      final res = await _client.get(
        ApiEndpoints.supplierDebtSummary,
        queryParameters: {
          if (supplierId != null && supplierId > 0) 'supplierId': supplierId,
        },
      );
      if (res.data is Map<String, dynamic>) {
        return SupplierDebtSummaryModel.fromJson(res.data);
      }
    } catch (_) {}
    return SupplierDebtSummaryModel();
  }

  /// Make payment for supplier debt
  Future<bool> paySupplierDebt({
    required int debtId,
    required double amount,
    String paymentMethod = 'Tiền mặt',
    String? proof,
  }) async {
    try {
      final res = await _client.post(
        ApiEndpoints.supplierDebtPayment,
        data: {
          'DebtId': debtId,
          'Amount': amount,
          'PaymentMethod': paymentMethod,
          'PaymentProof': proof,
          'PaymentDate': DateTime.now().toIso8601String(),
        },
      );
      if (res.data is Map<String, dynamic>) {
        return res.data['success'] ?? res.data['Success'] ?? true;
      }
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Fetch payment history of a specific supplier debt record (`GET api/admin/inventory/debt/{debtId}/payments`)
  Future<List<SupplierPaymentModel>> getSupplierDebtPayments(int debtId) async {
    try {
      final res = await _client.get('${ApiEndpoints.supplierDebts}/$debtId/payments');
      final rawData = res.data;
      List<dynamic> list = const [];
      if (rawData is List) {
        list = rawData;
      } else if (rawData is Map<String, dynamic>) {
        final inner = rawData['data'] ?? rawData['Data'] ?? rawData['payments'] ?? rawData['Payments'];
        if (inner is List) list = inner;
      }
      final payments = list
          .map((item) => SupplierPaymentModel.fromJson(item))
          .toList();
      payments.sort((a, b) {
        final da = a.paymentDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.paymentDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final cmp = db.compareTo(da);
        if (cmp != 0) return cmp;
        return b.paymentId.compareTo(a.paymentId);
      });
      return payments;
    } catch (_) {
      return [];
    }
  }

  /// Create new product and return new productId
  Future<int?> createProduct(Map<String, dynamic> productData) async {
    try {
      final res = await _client.post(
        ApiEndpoints.createProduct,
        data: productData,
      );
      if (res.data is Map<String, dynamic>) {
        final success = res.data['success'] ?? res.data['Success'] ?? true;
        if (success == false) {
          throw Exception(res.data['message'] ?? res.data['Message'] ?? 'Không thể tạo sản phẩm.');
        }
        final pId = res.data['productId'] ?? res.data['ProductId'] ?? res.data['id'];
        if (pId != null) return int.tryParse(pId.toString());
        return 1;
      }
      return (res.statusCode == 200 || res.statusCode == 201) ? 1 : null;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Lỗi tạo sản phẩm: $e');
    }
  }

  /// Update existing product
  Future<bool> updateProduct(Map<String, dynamic> productData) async {
    try {
      final res = await _client.post(
        ApiEndpoints.updateProduct,
        data: productData,
      );
      if (res.data is Map<String, dynamic>) {
        final success = res.data['success'] ?? res.data['Success'] ?? true;
        if (success == false) {
          throw Exception(res.data['message'] ?? res.data['Message'] ?? 'Không thể cập nhật sản phẩm.');
        }
        return true;
      }
      return res.statusCode == 200;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Lỗi cập nhật sản phẩm: $e');
    }
  }

  /// Delete product
  Future<bool> deleteProduct(int productId) async {
    try {
      final res = await _client.post('${ApiEndpoints.deleteProduct}/$productId');
      if (res.data is Map<String, dynamic>) {
        return res.data['success'] ?? res.data['Success'] ?? true;
      }
      return res.statusCode == 200;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Lỗi xóa sản phẩm: $e');
    }
  }

  /// Upload product image file via multipart form
  Future<String?> uploadProductImage({required String filePath, String? fileName, int? productId}) async {
    try {
      final formData = FormData();
      formData.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(filePath, filename: fileName ?? 'product.jpg'),
      ));
      if (productId != null && productId > 0) {
        formData.fields.add(MapEntry('productId', productId.toString()));
      }

      final res = await _client.post(
        ApiEndpoints.uploadProductImage,
        data: formData,
      );

      if (res.data is Map<String, dynamic>) {
        final url = res.data['url'] ?? res.data['Image'] ?? res.data['data'];
        if (url != null) return url.toString();
      }
      return null;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Lỗi tải ảnh sản phẩm: $e');
    }
  }

  /// Upload supplier debt payment proof image (Hóa đơn / Ủy nhiệm chi / Biên nhận chuyển khoản)
  Future<String?> uploadDebtPaymentProof({
    required String filePath,
    String? fileName,
    int? debtId,
  }) async {
    try {
      final formData = FormData();
      formData.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(filePath, filename: fileName ?? 'proof.jpg'),
      ));
      if (debtId != null && debtId > 0) {
        formData.fields.add(MapEntry('debtId', debtId.toString()));
      }

      // Thử endpoint chuyên biệt cho chứng từ công nợ NCC trước
      try {
        final res = await _client.post(
          ApiEndpoints.uploadDebtProof,
          data: formData,
        );
        if (res.data is Map<String, dynamic>) {
          final url = res.data['url'] ?? res.data['fileUrl'] ?? res.data['Image'];
          if (url != null) return url.toString();
        }
      } catch (_) {
        // Fallback sang endpoint upload chung nếu backend ASP.NET chưa cập nhật route mới
        final res = await _client.post(
          ApiEndpoints.uploadProductImage,
          data: formData,
        );
        if (res.data is Map<String, dynamic>) {
          final url = res.data['url'] ?? res.data['Image'] ?? res.data['data'];
          if (url != null) return url.toString();
        }
      }
      return null;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Lỗi tải ảnh chứng từ thanh toán: $e');
    }
  }
}
