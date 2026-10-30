# 📱 EMarket Mobile App

> **Hệ thống Quản lý Bán hàng, Kho & Trợ lý Doanh nghiệp Thông minh trên nền tảng Flutter**

---

## 📖 Giới thiệu tổng quan

**EMarket Mobile** là ứng dụng di động đa nền tảng (Android & iOS) được xây dựng bằng **Flutter**, đóng vai trò là giao diện quản trị di động toàn diện cho hệ sinh thái thương mại **EMarket**. Ứng dụng cung cấp đầy đủ các công cụ quản lý vận hành bán hàng, tồn kho, thu chi tài chính, báo giá đơn hàng và tích hợp **Trợ lý ảo AI** hỗ trợ phân tích và tra cứu dữ liệu thời gian thực.

---

## ✨ Tính năng nổi bật

### 1. 🛒 Bán hàng & Điểm bán (POS)
- Giao diện bán hàng trực quan, hỗ trợ tìm kiếm sản phẩm nhanh, thêm giỏ hàng và áp dụng khuyến mãi.
- Tích hợp quét mã vạch / QR Code trực tiếp qua camera để lên đơn siêu tốc.
- Quản lý danh sách đơn hàng, xem chi tiết và cập nhật trạng thái đơn (Chờ xử lý, Đã giao, Hủy...).

### 2. 📦 Quản lý Kho & Nhập hàng
- **Tồn kho (Inventory)**: Theo dõi số lượng tồn, lịch sử nhập/xuất/điều chỉnh kho, cảnh báo hàng sắp hết.
- **Đơn đặt hàng nhập (Purchase Orders)**: Lập và quản lý đơn đặt hàng từ nhà cung cấp, theo dõi tiến độ nhập kho và thanh toán công nợ.
- **Báo giá (Quotations)**: Tạo và xuất bảng báo giá nhanh chóng cho khách hàng và đối tác.

### 3. 👥 Quản lý Đối tác & Khách hàng
- Danh bạ đối tác: Quản lý chi tiết danh sách Khách hàng (Customers) và Nhà cung cấp (Suppliers).
- Theo dõi lịch sử giao dịch, công nợ và thông tin liên hệ.

### 4. 💰 Quản lý Tài chính & Thu chi
- Ghi nhận và phân loại các khoản chi phí phát sinh trong vận hành doanh nghiệp.
- Quản lý hóa đơn, đính kèm biên lai / ảnh chụp chứng từ thanh toán.

### 5. 📊 Báo cáo & Thống kê thông minh
- Dashboard trực quan với biểu đồ doanh thu, lợi nhuận, đơn hàng theo thời gian thực (hỗ trợ bởi `fl_chart`).
- Thống kê top sản phẩm bán chạy, khách hàng tiềm năng và tỷ lệ chuyển đổi.

### 6. 🤖 Trợ lý ảo AI Doanh nghiệp
- Tích hợp Chatbot AI thông minh giải đáp thông tin số liệu bán hàng, tra cứu tồn kho và phân tích hiệu suất kinh doanh qua ngôn ngữ tự nhiên.

### 7. 🔐 Bảo mật & Xác thực
- Hỗ trợ đăng nhập bằng tài khoản nội bộ và **Đăng nhập một chạm bằng Google (Google Sign-In)**.
- Quản lý phiên làm việc bảo mật với Cookie Jar và Persistent Storage.

---

## 🛠️ Công nghệ & Thư viện sử dụng

| Công nghệ / Thư viện | Mục đích sử dụng |
| :--- | :--- |
| **Flutter & Dart** | Khung phát triển ứng dụng di động đa nền tảng (SDK ^3.13.1) |
| **Provider** | Quản lý trạng thái (State Management) hiệu quả, dễ mở rộng |
| **Dio & CookieJar** | Xử lý mạng (HTTP Client), quản lý interceptors, session cookie & token |
| **Mobile Scanner & QR Flutter** | Quét và tạo mã QR/Barcode sản phẩm và hóa đơn |
| **FL Chart** | Vẽ biểu đồ thống kê tài chính & doanh thu đa dạng |
| **Google Sign In** | Xác thực người dùng qua dịch vụ Google OAuth |
| **Cached Network Image** | Tối ưu hóa tải và lưu bộ nhớ đệm hình ảnh sản phẩm |
| **Shared Preferences** | Lưu trữ cấu hình cục bộ, session và theme |
| **Image Picker** | Chụp ảnh và tải ảnh chứng từ, biên lai thanh toán từ thư viện máy |

---

## 📂 Cấu trúc thư mục dự án

```text
lib/
├── core/                  # Các cấu hình dùng chung, theme, hằng số, interceptors, utils
│   ├── constants/         # URL API, màu sắc, font chữ, storage keys
│   └── network/           # Cấu hình Dio client, base response, error handling
├── data/                  # Tầng dữ liệu (Data Layer)
│   ├── models/            # Data models (Product, Order, Inventory, Customer...)
│   └── services/          # Các API service gọi về máy chủ backend
├── providers/             # Quản lý State (ChangeNotifier Providers)
│   ├── auth_provider.dart
│   ├── cart_provider.dart
│   ├── inventory_provider.dart
│   └── ...
├── ui/                    # Tầng giao diện người dùng (Presentation Layer)
│   ├── screens/           # Các màn hình theo từng phân hệ chức năng
│   │   ├── auth/          # Đăng nhập, xác thực
│   │   ├── dashboard/     # Trang chủ thống kê
│   │   ├── pos/           # Điểm bán hàng nhanh
│   │   ├── orders/        # Danh sách đơn hàng
│   │   ├── inventory/     # Quản lý kho hàng
│   │   ├── purchases/     # Quản lý đơn nhập hàng
│   │   ├── quotations/    # Quản lý báo giá
│   │   ├── customers/     # Danh sách khách hàng
│   │   ├── suppliers/     # Quản lý nhà cung cấp
│   │   ├── expenses/      # Quản lý thu chi
│   │   └── ai/            # Trợ lý ảo AI Chatbot
│   └── widgets/           # Các thành phần giao diện tái sử dụng (Button, Card, Dialog...)
└── main.dart              # Entry point khởi tạo ứng dụng
```

---

## 🚀 Hướng dẫn cài đặt & Khởi chạy

### 1. Yêu cầu hệ thống
- **Flutter SDK**: `>= 3.13.1`
- **Dart SDK**: Tương ứng theo phiên bản Flutter
- **Android Studio** (với Android SDK) hoặc **Xcode** (nếu chạy trên macOS/iOS)

### 2. Cài đặt Dependencies
Mở terminal tại thư mục `do_an_flutter` và chạy:
```bash
flutter pub get
```

### 3. Cấu hình Endpoint Backend
Kiểm tra cấu hình địa chỉ IP máy chủ API Backend trong thư mục `lib/core/` (hoặc constants) để đảm bảo ứng dụng kết nối đúng với server `EMarket Web API`.

### 4. Khởi chạy ứng dụng (Debug Mode)
```bash
# Xem danh sách thiết bị/máy ảo đang kết nối
flutter devices

# Chạy ứng dụng trên thiết bị mục tiêu
flutter run
```

---

## 📦 Đóng gói & Phát hành (Build Release)

### Android APK:
```bash
flutter build apk --release
```
*File xuất ra tại: `build/app/outputs/flutter-apk/app-release.apk`*

### iOS (Unsigned IPA qua CI/CD hoặc Xcode):
```bash
flutter build ios --release --no-codesign
```

---

## 📝 Giấy phép (License)
Dự án được phát triển phục vụ mục đích nghiên cứu, học tập và triển khai giải pháp quản trị doanh nghiệp. Mọi quyền được bảo lưu.
