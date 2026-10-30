import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/ai_model.dart';

class AiApiService {
  final ApiClient _client = ApiClient();

  /// Chat với EMarket AIAssistantService (Azure Cloud / Semantic Kernel)
  Future<String> askAi(String prompt, {String? userName}) async {
    try {
      final res = await _client.aiDio.post(
        ApiEndpoints.aiChat,
        data: {
          'Prompt': prompt,
          'UserName': userName ?? 'admin',
        },
      );

      dynamic data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (data is Map<String, dynamic>) {
        final answer = data['answer'] ?? data['reply'] ?? data['response'] ?? data['message'];
        if (answer != null) {
          return _filterAiResponseText(answer.toString());
        }
      }

      return _filterAiResponseText(res.data?.toString() ?? 'Đã nhận phản hồi từ hệ thống.');
    } on DioException catch (dioErr) {
      return _mapDioErrorToFriendlyMessage(dioErr);
    } catch (e) {
      return _mapGenericErrorToFriendlyMessage(e.toString());
    }
  }

  /// Bộ lọc làm sạch văn bản phản hồi, phát hiện và chuẩn hóa các thông báo lỗi API bên thứ 3
  static String _filterAiResponseText(String text) {
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();

    // Lọc nếu chuỗi trả về thực chất là chuỗi lỗi JSON từ các API Gemini / Groq bên thứ 3
    if (lower.contains('resource_exhausted') || (lower.contains('quota') && lower.contains('429'))) {
      return '⚠️ Hệ thống AI đang có lượng người hỏi lớn hoặc chạm hạn ngạch tạm thời. Bạn vui lòng chờ khoảng 15-30 giây rồi hỏi lại nhé.';
    }
    if (lower.contains('api key') && (lower.contains('invalid') || lower.contains('not found') || lower.contains('chưa cấu hình'))) {
      return '⚠️ Cấu hình API Key của hệ thống AI cần được cập nhật. Vui lòng liên hệ quản trị viên để kiểm tra.';
    }
    if (lower.contains('bad gateway') || lower.contains('502 web server received')) {
      return '⚠️ Máy chủ AI đang khởi động hoặc chưa sẵn sàng (502 Bad Gateway). Vui lòng thử lại sau ít giây.';
    }
    return trimmed;
  }

  /// Ánh xạ các mã lỗi mạng/HTTP thành thông báo thân thiện, dễ hiểu cho người dùng
  static String _mapDioErrorToFriendlyMessage(DioException dioErr) {
    final statusCode = dioErr.response?.statusCode;
    final responseData = dioErr.response?.data?.toString().toLowerCase() ?? '';

    // Nếu backend có trả về message tùy biến trong response body
    if (dioErr.response?.data is Map) {
      final answer = (dioErr.response?.data as Map)['answer'] ?? (dioErr.response?.data as Map)['message'];
      if (answer != null && answer.toString().trim().isNotEmpty) {
        return _filterAiResponseText(answer.toString());
      }
    }

    if (statusCode == 401) {
      return '⚠️ Phiên làm việc của bạn đã hết hạn. Vui lòng đăng nhập lại để tiếp tục sử dụng Trợ lý AI.';
    }
    if (statusCode == 403) {
      return '⚠️ Tài khoản của bạn chưa được phân quyền sử dụng tính năng Trợ lý AI.';
    }
    if (statusCode == 429 || responseData.contains('rate limit') || responseData.contains('429')) {
      return '⏳ Bạn đang gửi yêu cầu quá nhanh hoặc hệ thống AI đang quá tải. Vui lòng đợi 15-20 giây trước khi tiếp tục.';
    }
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return '⚠️ Máy chủ AI Cloud tạm thời chưa phản hồi ($statusCode). Vui lòng kiểm tra lại sau ít phút.';
    }
    if (statusCode == 500) {
      return '⚠️ Đã xảy ra lỗi nội bộ trong quá trình tổng hợp số liệu. Bạn vui lòng thử lại với câu hỏi ngắn gọn hơn hoặc chọn chi nhánh cụ thể.';
    }
    if (dioErr.type == DioExceptionType.connectionTimeout ||
        dioErr.type == DioExceptionType.receiveTimeout ||
        dioErr.type == DioExceptionType.sendTimeout) {
      return '⏱️ Yêu cầu phân tích mất nhiều thời gian hơn thường lệ. Máy chủ đang bận, vui lòng thử lại sau giây lát.';
    }
    if (dioErr.type == DioExceptionType.connectionError) {
      return '🔌 Không thể kết nối tới máy chủ AI Cloud. Vui lòng kiểm tra kết nối mạng Internet hoặc cài đặt địa chỉ máy chủ.';
    }

    return '⚠️ Không thể gửi tin nhắn tới Trợ lý AI vào lúc này. Vui lòng kiểm tra kết nối mạng và thử lại.';
  }

  static String _mapGenericErrorToFriendlyMessage(String errorStr) {
    final lower = errorStr.toLowerCase();
    if (lower.contains('socket') || lower.contains('network') || lower.contains('failed host lookup')) {
      return '🔌 Thiết bị mất kết nối mạng Internet. Vui lòng kiểm tra kết nối Wifi/4G của bạn.';
    }
    return '⚠️ Đã xảy ra lỗi khi trao đổi cùng Trợ lý AI. Vui lòng thử lại sau.';
  }

  /// Lấy danh sách gợi ý nhập hàng thông minh (Replenishment Advice)
  Future<List<AIReplenishmentModel>> getReplenishmentAdvice(int branchId) async {
    try {
      final res = await _client.get('${ApiEndpoints.aiReplenishmentAdvice}/$branchId');
      if (res.data is List) {
        return (res.data as List).map((e) => AIReplenishmentModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Lấy danh sách bất thường ngành hàng do AI phát hiện (Spike / Dip)
  Future<List<AIAnomalyModel>> getAnomalies(int branchId) async {
    try {
      final res = await _client.get('${ApiEndpoints.aiAnomalies}/$branchId');
      if (res.data is List) {
        return (res.data as List).map((e) => AIAnomalyModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Lấy danh sách đánh giá insight sản phẩm (Star, Trending, Warning)
  Future<List<AIInsightModel>> getProductInsights(int branchId) async {
    try {
      final res = await _client.get('${ApiEndpoints.aiInsights}/$branchId');
      if (res.data is List) {
        return (res.data as List).map((e) => AIInsightModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Kích hoạt chạy phân tích (mode: 'system' hoặc 'ai')
  Future<bool> runAnalysis({required String mode, required int branchId}) async {
    try {
      final endpoint = mode == 'ai' ? ApiEndpoints.aiRunProphet : ApiEndpoints.aiRunAnalysis;
      final res = await _client.post(
        '$endpoint/$branchId',
        data: {'mode': mode, 'branchId': branchId},
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> runAiAnalysis({required String mode, required int branchId}) =>
      runAnalysis(mode: mode, branchId: branchId);
}
