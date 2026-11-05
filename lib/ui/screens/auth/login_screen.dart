import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/server_settings_dialog.dart';
import '../main_navigation_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'nhpthai.dev@gmail.com');
  final _passwordController = TextEditingController(text: 'adminpass');
  bool _obscurePassword = true;
  bool _rememberMe = true;

  late final AnimationController _entranceController;
  late final AnimationController _ambientController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOutSine),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillDemoAccount(String username, String password) {
    setState(() {
      _usernameController.text = username;
      _passwordController.text = password;
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<void> _handleGoogleSignIn() async {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux);

    if (isDesktop) {
      await _launchGoogleWebSignIn();
      return;
    }

    final auth = context.read<AuthProvider>();

    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();

      if (account == null) {
        return;
      }

      if (!mounted) return;

      final googleAuth = await account.authentication;
      final String? idToken = googleAuth.idToken;
      final String email = account.email;
      final String? displayName = account.displayName;

      final success = await auth.loginWithGoogle(
        email: email,
        fullName: displayName,
        idToken: idToken,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else {
        _showGoogleAuthErrorDialog(
          email,
          auth.errorMessage ?? 'Email Google này chưa được cấp quyền truy cập vào EMarket.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      await _launchGoogleWebSignIn();
    }
  }

  Future<void> _launchGoogleWebSignIn({String? nativeErrorReason}) async {
    if (!mounted) return;
    _showGoogleWebSyncDialog(nativeErrorReason: nativeErrorReason);
  }

  void _showGoogleWebSyncDialog({String? nativeErrorReason}) {
    final emailController = TextEditingController(text: 'admin@emarket.com');
    final formKey = GlobalKey<FormState>();
    final presetEmails = const <Map<String, String>>[
      {'label': 'Admin Tổng', 'email': 'admin@emarket.com'},
      {'label': 'Quản lý CN', 'email': 'manager@emarket.com'},
      {'label': 'Thu ngân POS', 'email': 'staff@emarket.com'},
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final auth = context.watch<AuthProvider>();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBrand.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.g_mobiledata_rounded, color: AppColors.primaryBrand, size: 28),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đăng nhập Google SSO',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Xác thực tài khoản Google liên kết EMarket',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.primaryBrand),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nhập địa chỉ Email Google đã đăng ký nhân sự trên hệ thống EMarket (tương thích cả iOS Sideloadly & Windows Desktop):',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Địa chỉ Email Google',
                        hintText: 'ví dụ: admin@emarket.com',
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryBrand),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập Email Google';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                          return 'Định dạng email không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Chọn nhanh tài khoản Google nội bộ:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: presetEmails.map((item) {
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.account_circle_outlined, size: 15, color: AppColors.primaryBrand),
                          label: Text(
                            '${item['label']} (${item['email']})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              emailController.text = item['email']!;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () {
                        final googleLoginUri = Uri.parse(
                          'https://accounts.google.com/signin/v2/identifier?prompt=select_account',
                        );
                        launchUrl(googleLoginUri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.open_in_new, size: 15),
                      label: const Text('Mở trình duyệt Google Accounts (Tùy chọn)', style: TextStyle(fontSize: 11.5)),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: auth.isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrand,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final email = emailController.text.trim();
                        final success = await auth.loginWithGoogle(
                          email: email,
                          fullName: email.split('@').first,
                        );

                        if (!mounted) return;
                        if (success) {
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.error,
                                content: Text(auth.errorMessage ?? 'Email này chưa được cấp quyền truy cập EMarket.'),
                              ),
                            );
                          }
                        }
                      },
                child: auth.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Xác nhận & Đăng nhập', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showGoogleAuthErrorDialog(String email, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.error, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Từ chối truy cập',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tài khoản Google:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              email,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Text(
                message,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBrand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Ultra-clean luxury porcelain slate
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 950;

          return Stack(
            children: [
              // 1. Ambient Pastel Aurora Glow Backdrops
              Positioned(
                top: -120,
                left: isDesktop ? 40 : -100,
                child: AnimatedBuilder(
                  animation: _breathingAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _breathingAnimation.value,
                      child: Container(
                        width: 480,
                        height: 480,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF6366F1).withValues(alpha: 0.10),
                              const Color(0xFF818CF8).withValues(alpha: 0.04),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: -80,
                right: isDesktop ? 60 : -80,
                child: Container(
                  width: 440,
                  height: 440,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF38BDF8).withValues(alpha: 0.10),
                        const Color(0xFF0EA5E9).withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Top Bar: Server Status & Quick Settings
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Server latency / connection badge
                        Flexible(
                          child: InkWell(
                            onTap: () => ServerSettingsDialog.show(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.borderStrong),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x060F172A),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.emerald,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x6610B981),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Cụm máy chủ: ${AppConfig.emarketBaseUrl.replaceAll('http://', '').replaceAll('https://', '')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Settings Gear Icon
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Color(0xFF475569), size: 20),
                          tooltip: 'Cấu hình Máy chủ',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.borderStrong),
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: () => ServerSettingsDialog.show(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Main Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 56),
                  child: Center(
                    child: isDesktop
                        ? _buildDesktopSplitLayout(auth)
                        : _buildMobileFluidLayout(auth),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // WINDOWS DESKTOP: SPLIT-SCREEN 55 : 45
  // ==========================================
  Widget _buildDesktopSplitLayout(AuthProvider auth) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Panel (55%): Brand Showcase & Floating KPI Tiles
                  Expanded(
                    flex: 11,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 44),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Tagline badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_outlined, color: Color(0xFF4F46E5), size: 14),
                                SizedBox(width: 8),
                                Text(
                                  'EMARKET SYSTEM',
                                  style: TextStyle(
                                    color: Color(0xFF4338CA),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Brand Headline
                          const Text(
                            'Kiến tạo hạ tầng bán lẻ\nChuẩn mực & Tinh tế.',
                            style: TextStyle(
                              fontSize: 40,
                              height: 1.18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Hệ thống quản trị chuỗi siêu thị đa kênh toàn diện. Đồng bộ kho bãi tức thì, thanh toán POS 0.12s và bảo mật phân quyền đa cấp.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // 3 Floating KPI Cards
                          Row(
                            children: [
                              _buildDesktopKpiTile(
                                icon: Icons.payments_outlined,
                                iconColor: const Color(0xFF059669),
                                value: '48.5M',
                                label: 'Doanh số hôm nay',
                                badge: '+14.2%',
                              ),
                              const SizedBox(width: 14),
                              _buildDesktopKpiTile(
                                icon: Icons.bolt_rounded,
                                iconColor: const Color(0xFF0284C7),
                                value: '0.12s',
                                label: 'Tốc độ POS quét',
                                badge: 'Real-time',
                              ),
                              const SizedBox(width: 14),
                              _buildDesktopKpiTile(
                                icon: Icons.hub_outlined,
                                iconColor: const Color(0xFF7C3AED),
                                value: '12',
                                label: 'Chi nhánh kết nối',
                                badge: '100% Sync',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right Panel (45%): Elegant Auth Form
                  Expanded(
                    flex: 9,
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: _buildAuthGlassCard(auth, isCompact: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopKpiTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String badge,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 4),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // iPHONE 16 PRO MAX / MOBILE: FLUID VERTICAL
  // ==========================================
  Widget _buildMobileFluidLayout(AuthProvider auth) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mobile Compact Brand Emblem
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(

                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'EMARKET SYSTEM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hệ thống Bán lẻ & Quản trị Siêu thị Đa chi nhánh',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Auth Card
                  _buildAuthGlassCard(auth, isCompact: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ELEGANT LIGHT AUTH FORM CONTAINER
  // ==========================================
  Widget _buildAuthGlassCard(AuthProvider auth, {required bool isCompact}) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header inside card
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lock_person_outlined,
                    color: Color(0xFF4F46E5),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đăng nhập tài khoản',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Nhập thông tin nhân viên hoặc quản lý',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Username / Email Field
            TextFormField(
              controller: _usernameController,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Tài khoản / Email',
                labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                hintText: 'Nhập tên đăng nhập hoặc email',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF4F46E5), size: 20),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderStrong),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vui lòng nhập tên tài khoản hoặc email';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
                hintText: 'Nhập mật khẩu',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF4F46E5), size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderStrong),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Vui lòng nhập mật khẩu';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),

            // Remember Me & Forgot Password
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: const Color(0xFF4F46E5),
                        checkColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) => setState(() => _rememberMe = val ?? true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Ghi nhớ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    );
                  },
                  child: const Text(
                    'Quên mật khẩu?',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4F46E5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            // Error alert box
            if (auth.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        auth.errorMessage!,
                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 18),

            // Submit Button
            Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4338CA), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x334338CA),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: auth.isLoading ? null : _handleLogin,
                child: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'ĐĂNG NHẬP HỆ THỐNG',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Divider
            const Row(
              children: [
                Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'HOẶC',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              ],
            ),
            const SizedBox(height: 14),

            // Google Sign In Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: Colors.white,
                elevation: 0,
              ),
              icon: Image.network(
                'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, color: Colors.red, size: 22),
              ),
              label: const Text(
                'Đăng nhập với Google',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: auth.isLoading ? null : _handleGoogleSignIn,
            ),
            const SizedBox(height: 20),

            // Quick-Fill Demo Chips (Admin, Kho, Thu ngân)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.touch_app_outlined, size: 12, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Tài khoản Demo thử nghiệm nhanh:',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildQuickDemoChip(
                      label: 'System Admin',
                      icon: Icons.admin_panel_settings_outlined,
                      color: const Color(0xFF4F46E5),
                      onTap: () => _fillDemoAccount('nhpthai.dev@gmail.com', 'adminpass'),
                    ),
                    _buildQuickDemoChip(
                      label: 'Nhà cung cấp',
                      icon: Icons.local_shipping_outlined,
                      color: const Color(0xFFD97706),
                      onTap: () => _fillDemoAccount('thai.dktech@gmail.com', 'adminpass'),
                    ),
                    _buildQuickDemoChip(
                      label: 'QL Bán hàng',
                      icon: Icons.point_of_sale_outlined,
                      color: const Color(0xFF059669),
                      onTap: () => _fillDemoAccount('ketoan@emarket.vn', 'adminpass'),
                    ),
                    _buildQuickDemoChip(
                      label: 'QL Nhân sự',
                      icon: Icons.badge_outlined,
                      color: const Color(0xFF7C3AED),
                      onTap: () => _fillDemoAccount('nguyenhaphuongthai.dev@gmail.com', 'adminpass'),
                    ),
                    _buildQuickDemoChip(
                      label: 'QL Kho',
                      icon: Icons.warehouse_outlined,
                      color: const Color(0xFF0284C7),
                      onTap: () => _fillDemoAccount('nguyenhaphuongthai2@gmail.com', 'adminpass'),
                    ),
                    _buildQuickDemoChip(
                      label: 'QL Công nợ',
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFFDC2626),
                      onTap: () => _fillDemoAccount('2324801030065@student.tdmu.edu.vn', 'adminpass'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDemoChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
