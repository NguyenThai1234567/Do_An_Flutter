import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/ai_model.dart';
import '../../../data/repositories/data_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/branch_selector_widget.dart';
import '../../widgets/flat_card.dart';
import '../../widgets/status_badge.dart';

class AIAssistantScreen extends StatefulWidget {
  final DataRepository? repository;

  const AIAssistantScreen({super.key, this.repository});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen>
    with SingleTickerProviderStateMixin {
  late final DataRepository _repository = widget.repository ?? DataRepository();
  late TabController _tabController;

  // Chat tab state
  final _inputCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text':
          'Xin chào! Tôi là Trợ lý AI EMarket. Tôi có thể hỗ trợ bạn tra cứu doanh số, kiểm tra tồn kho, gợi ý nhập hàng và dự báo kinh doanh theo chi nhánh. Bạn cần phân tích dữ liệu gì hôm nay?',
    },
  ];
  bool _isSending = false;

  // Data tabs state
  List<AIReplenishmentModel> _replenishments = [];
  List<AIAnomalyModel> _anomalies = [];
  List<AIInsightModel> _insights = [];
  bool _isLoadingData = true;
  bool _isRunningAnalysis = false;
  int? _lastBranchId;

  final List<({String label, String prompt, IconData icon})> _quickPrompts =
      const [
    (
      label: 'Doanh số hôm nay',
      prompt: 'Hôm nay cửa hàng bán được bao nhiêu rồi?',
      icon: Icons.trending_up_rounded,
    ),
    (
      label: 'Cảnh báo sắp hết hàng',
      prompt: 'Sản phẩm nào sắp hết hàng cần nhập?',
      icon: Icons.warning_amber_rounded,
    ),
    (
      label: 'Dự báo tuần tới',
      prompt: 'Dự báo kinh doanh tuần tới như thế nào?',
      icon: Icons.auto_graph_rounded,
    ),
    (
      label: 'Top bán chạy',
      prompt: 'Mặt hàng nào đang bán chạy nhất?',
      icon: Icons.workspace_premium_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final branchId = auth.effectiveBranchId ?? auth.currentUser?.branchId ?? 1;
    if (_lastBranchId != branchId) {
      _lastBranchId = branchId;
      _loadAiData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAiData() async {
    setState(() => _isLoadingData = true);
    final auth = context.read<AuthProvider>();
    final branchId = auth.effectiveBranchId ?? auth.currentUser?.branchId ?? 1;

    try {
      final results = await Future.wait([
        _repository.getReplenishmentAdvice(branchId),
        _repository.getAnomalies(branchId),
        _repository.getProductInsights(branchId),
      ]);

      if (mounted) {
        setState(() {
          _replenishments = results[0] as List<AIReplenishmentModel>;
          _anomalies = results[1] as List<AIAnomalyModel>;
          _insights = results[2] as List<AIInsightModel>;
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _triggerRunAnalysis() async {
    if (_isRunningAnalysis) return;
    setState(() => _isRunningAnalysis = true);
    final auth = context.read<AuthProvider>();
    final branchId = auth.effectiveBranchId ?? auth.currentUser?.branchId ?? 1;

    final ok = await _repository.runAiAnalysis(
      mode: 'system',
      branchId: branchId,
    );
    if (!mounted) return;
    setState(() => _isRunningAnalysis = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật dữ liệu phân tích AI mới nhất'),
          backgroundColor: AppColors.emerald,
        ),
      );
      _loadAiData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đồng bộ dữ liệu phân tích hiện hành'),
        ),
      );
      _loadAiData();
    }
  }

  Future<void> _sendMessage(String query) async {
    final text = query.trim();
    if (text.isEmpty || _isSending) return;

    _inputCtrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isSending = true;
    });

    _scrollToBottom();

    final auth = context.read<AuthProvider>();
    final username = auth.currentUser?.username ?? 'admin';
    final response = await _repository.askAi(text, userName: username);
    if (!mounted) return;

    setState(() {
      _messages.add({'role': 'ai', 'text': response});
      _isSending = false;
    });

    _scrollToBottom();
  }

  void _clearChat() {
    setState(() {
      _messages
        ..clear()
        ..add({
          'role': 'ai',
          'text':
              'Đã làm mới phiên hội thoại. Bạn cần phân tích doanh số, tồn kho hay dự báo mặt hàng nào?',
        });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 640;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryBrand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: AppColors.primaryBrand,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Trợ lý AI & Dự báo Thông minh',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          const Center(
            child: BranchSelectorWidget(compact: true),
          ),
          const SizedBox(width: 6),
          if (!isCompact)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _isRunningAnalysis ? null : _triggerRunAnalysis,
                icon: _isRunningAnalysis
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt_rounded, size: 16),
                label: const Text(
                  'Phân tích lại',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Chạy phân tích AI',
              onPressed: _isRunningAnalysis ? null : _triggerRunAnalysis,
              icon: _isRunningAnalysis
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt_rounded, size: 20),
            ),
          IconButton(
            tooltip: 'Tải lại dữ liệu',
            onPressed: _loadAiData,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: TabBar(
              controller: _tabController,
              labelPadding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 16),
              labelColor: AppColors.primaryBrand,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primaryBrand,
              indicatorWeight: 2.5,
              labelStyle: TextStyle(
                fontSize: isCompact ? 12 : 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: isCompact ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                      SizedBox(width: isCompact ? 5 : 8),
                      const Flexible(
                        child: Text(
                          'Hỏi đáp AI',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_shopping_cart_rounded, size: 15),
                      SizedBox(width: isCompact ? 5 : 8),
                      const Flexible(
                        child: Text(
                          'Gợi ý Nhập',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_replenishments.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        _buildCountPill(
                          _replenishments.length,
                          color: AppColors.primaryBrand,
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insights_rounded, size: 15),
                      SizedBox(width: isCompact ? 5 : 8),
                      const Flexible(
                        child: Text(
                          'Bất thường & Insights',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_anomalies.isNotEmpty || _insights.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        _buildCountPill(
                          _anomalies.length + _insights.length,
                          color: AppColors.warning,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(),
          _buildReplenishmentTab(),
          _buildInsightsTab(),
        ],
      ),
    );
  }

  Widget _buildCountPill(int count, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: AppTheme.tabularStyle(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: HỎI ĐÁP AI (ENTERPRISE WORKSPACE CHAT)
  // ---------------------------------------------------------------------------
  Widget _buildChatTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        return Column(
          children: [
            // Thanh gợi ý câu hỏi nhanh + Nút xóa lịch sử
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tips_and_updates_outlined,
                          size: 16,
                          color: AppColors.primaryBrand,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _quickPrompts.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ActionChip(
                                    avatar: Icon(
                                      item.icon,
                                      size: 14,
                                      color: AppColors.primaryBrand,
                                    ),
                                    label: Text(
                                      item.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    backgroundColor: AppColors.surfaceSubtle,
                                    side: const BorderSide(
                                      color: AppColors.borderStrong,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _sendMessage(item.prompt),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        if (_messages.length > 1)
                          TextButton.icon(
                            onPressed: _clearChat,
                            icon: const Icon(
                              Icons.cleaning_services_outlined,
                              size: 14,
                            ),
                            label: const Text(
                              'Làm mới',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textMuted,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Khung hiển thị tin nhắn (giới hạn maxWidth 920dp trên màn hình rộng)
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: ListView.builder(
                    controller: _chatScrollCtrl,
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 24 : 14,
                      vertical: 16,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      final text = msg['text'] ?? '';
                      final isAlert = !isUser &&
                          (text.startsWith('⚠️') ||
                              text.startsWith('⏳') ||
                              text.startsWith('⏱️') ||
                              text.startsWith('🔌'));

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: BoxConstraints(
                            maxWidth: isWide
                                ? 680
                                : constraints.maxWidth * 0.86,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.primaryBrand
                                : (isAlert
                                    ? const Color(0xFFFFFBEB)
                                    : AppColors.surface),
                            borderRadius: BorderRadius.circular(12).copyWith(
                              bottomRight: isUser
                                  ? const Radius.circular(3)
                                  : const Radius.circular(12),
                              bottomLeft: !isUser
                                  ? const Radius.circular(3)
                                  : const Radius.circular(12),
                            ),
                            border: isUser
                                ? null
                                : Border.all(
                                    color: isAlert
                                        ? const Color(0xFFFDE68A)
                                        : AppColors.borderStrong,
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A)
                                    .withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isAlert
                                            ? const Color(0xFFFEF3C7)
                                            : AppColors.primaryBrand
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Icon(
                                        isAlert
                                            ? Icons.warning_amber_rounded
                                            : Icons.auto_awesome_rounded,
                                        size: 12,
                                        color: isAlert
                                            ? const Color(0xFFD97706)
                                            : AppColors.primaryBrand,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isAlert
                                          ? 'Thông báo hệ thống'
                                          : 'EMarket Copilot',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isAlert
                                            ? const Color(0xFFB45309)
                                            : AppColors.primaryBrand,
                                      ),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () {
                                        Clipboard.setData(
                                          ClipboardData(text: text),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Đã sao chép nội dung phản hồi',
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.copy_rounded,
                                          size: 13,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (isUser)
                                SelectableText(
                                  text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else if (isAlert) ...[
                                SelectableText(
                                  text,
                                  style: const TextStyle(
                                    color: Color(0xFF92400E),
                                    fontSize: 13.5,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (index == _messages.length - 1 &&
                                    _messages.length >= 2) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        final lastUserMsg = _messages.reversed
                                            .firstWhere(
                                          (m) => m['role'] == 'user',
                                          orElse: () => {},
                                        );
                                        final prompt = lastUserMsg['text'];
                                        if (prompt != null &&
                                            prompt.isNotEmpty) {
                                          _sendMessage(prompt);
                                        }
                                      },
                                      icon: const Icon(Icons.refresh_rounded,
                                          size: 14,
                                          color: Color(0xFFB45309)),
                                      label: const Text(
                                        'Gửi lại câu hỏi',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFB45309),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ),
                                ],
                              ] else
                                MarkdownBody(
                                  data: text,
                                  selectable: true,
                                  styleSheet: MarkdownStyleSheet.fromTheme(
                                          Theme.of(context))
                                      .copyWith(
                                    p: const TextStyle(
                                      fontSize: 13.5,
                                      height: 1.5,
                                      color: AppColors.textPrimary,
                                    ),
                                    strong: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    h1: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBrand,
                                      height: 1.4,
                                    ),
                                    h2: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBrand,
                                      height: 1.4,
                                    ),
                                    h3: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                      height: 1.4,
                                    ),
                                    listBullet: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBrand,
                                    ),
                                    tableHead: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                    tableBody: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF334155),
                                      height: 1.35,
                                    ),
                                    tableBorder: TableBorder.all(
                                      color: const Color(0xFFCBD5E1),
                                      width: 1,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    tableColumnWidth:
                                        const FlexColumnWidth(),
                                    tableCellsPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 7),
                                    tableCellsDecoration:
                                        const BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                    ),
                                    blockquote: const TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF475569),
                                    ),
                                    blockquoteDecoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: const Border(
                                        left: BorderSide(
                                            color: AppColors.primaryBrand,
                                            width: 3.5),
                                      ),
                                    ),
                                    code: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      backgroundColor: Color(0xFFF1F5F9),
                                      color: AppColors.primaryBrand,
                                    ),
                                    codeblockDecoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                  onTapLink: (text, href, title) {
                                    if (href != null) {
                                      url_launcher.launchUrl(
                                        Uri.parse(href),
                                        mode: url_launcher
                                            .LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            if (_isSending)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryBrand,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'EMarket Copilot đang truy vấn dữ liệu hệ thống...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Thanh nhập tin nhắn chuẩn Enterprise
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 24 : 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputCtrl,
                              textInputAction: TextInputAction.send,
                              style: const TextStyle(fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText:
                                    'Nhập câu hỏi về doanh thu, tồn kho, sản phẩm bán chạy...',
                                prefixIcon: const Icon(
                                  Icons.psychology_alt_outlined,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceSubtle,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderStrong,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderStrong,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.primaryBrand,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onSubmitted: _sendMessage,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 42,
                            child: FilledButton.icon(
                              onPressed: _isSending
                                  ? null
                                  : () => _sendMessage(_inputCtrl.text),
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: Text(isWide ? 'Gửi' : ''),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryBrand,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isWide ? 16 : 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: GỢI Ý NHẬP HÀNG (ADAPTIVE TABLE / GRID / LIST)
  // ---------------------------------------------------------------------------
  Widget _buildReplenishmentTab() {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_replenishments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 42,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tồn kho hiện tại đảm bảo ngưỡng an toàn',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chưa có mặt hàng nào cần nhập bổ sung khẩn cấp tại chi nhánh này.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final urgentCount = _replenishments
        .where((r) => r.suggestedQty > 50 || r.confidenceLevel == 'HIGH')
        .length;
    final totalSuggestedQty = _replenishments.fold<int>(
      0,
      (sum, r) => sum + r.suggestedQty,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        final canShowTable = ResponsiveLayout.canShowDataTable(contentWidth);
        final gridCols = contentWidth >= 640 ? 2 : 1;

        return Column(
          children: [
            // KPI Summary Strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _buildSummaryMetricChip(
                        icon: Icons.rule_folder_outlined,
                        label: 'Mã hàng đề xuất',
                        value: '${_replenishments.length}',
                        color: AppColors.primaryBrand,
                      ),
                      _buildSummaryMetricChip(
                        icon: Icons.priority_high_rounded,
                        label: 'Ưu tiên cao',
                        value: '$urgentCount',
                        color: AppColors.error,
                      ),
                      _buildSummaryMetricChip(
                        icon: Icons.add_box_outlined,
                        label: 'Tổng SL đề xuất',
                        value: '+$totalSuggestedQty',
                        color: AppColors.emerald,
                      ),
                    ],
                  ),
                  Text(
                    canShowTable
                        ? 'Chế độ bảng phân tích tồn kho'
                        : 'Danh sách khuyến nghị nhập hàng',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: canShowTable
                  ? _buildReplenishmentDataTable()
                  : gridCols == 2
                      ? GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 158,
                          ),
                          itemCount: _replenishments.length,
                          itemBuilder: (context, index) =>
                              _buildReplenishmentCard(_replenishments[index]),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _replenishments.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _buildReplenishmentCard(_replenishments[index]),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: AppTheme.tabularStyle(
              TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplenishmentDataTable() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FlatCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  border: Border(
                    bottom: BorderSide(color: AppColors.borderStrong),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'SẢN PHẨM / LÝ DO KHUYẾN NGHỊ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'TỒN HIỆN TẠI',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'DỰ BÁO CẦU',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'ĐỀ XUẤT NHẬP',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    SizedBox(
                      width: 130,
                      child: Text(
                        'MỨC ƯU TIÊN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _replenishments.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final r = _replenishments[index];
                    final isUrgent =
                        r.suggestedQty > 50 || r.confidenceLevel == 'HIGH';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (r.reason != null &&
                                    r.reason!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.lightbulb_outline_rounded,
                                        size: 13,
                                        color: AppColors.primaryBrand,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          r.reason!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${r.currentStock} ${r.unit ?? ""}',
                              textAlign: TextAlign.right,
                              style: AppTheme.tabularStyle(
                                const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${r.expectedDemand} ${r.unit ?? ""}',
                              textAlign: TextAlign.right,
                              style: AppTheme.tabularStyle(
                                const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '+${r.suggestedQty}',
                              textAlign: TextAlign.right,
                              style: AppTheme.tabularStyle(
                                TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isUrgent
                                      ? AppColors.error
                                      : AppColors.primaryBrand,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 130,
                            child: Center(
                              child: StatusBadge(
                                label: isUrgent ? 'Cần nhập gấp' : 'Khuyến nghị',
                                color: isUrgent
                                    ? AppColors.error
                                    : AppColors.emerald,
                                icon: isUrgent
                                    ? Icons.priority_high_rounded
                                    : Icons.check_circle_outline_rounded,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplenishmentCard(AIReplenishmentModel r) {
    final isUrgent = r.suggestedQty > 50 || r.confidenceLevel == 'HIGH';

    return FlatCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: isUrgent ? 'Cần nhập gấp' : 'Khuyến nghị',
                color: isUrgent ? AppColors.error : AppColors.emerald,
                icon: isUrgent
                    ? Icons.priority_high_rounded
                    : Icons.check_circle_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Tồn: ${r.currentStock} ${r.unit ?? ""}',
                  style: AppTheme.tabularStyle(
                    const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  'Cầu dự báo: ${r.expectedDemand}',
                  style: AppTheme.tabularStyle(
                    const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  'Đề xuất: +${r.suggestedQty}',
                  style: AppTheme.tabularStyle(
                    TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color:
                          isUrgent ? AppColors.error : AppColors.primaryBrand,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (r.reason != null && r.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primaryBrand.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryBrand.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: AppColors.primaryBrand,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.reason!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: BẤT THƯỜNG & INSIGHTS (ADAPTIVE 2-COLUMN SPLIT / 1-COLUMN)
  // ---------------------------------------------------------------------------
  Widget _buildInsightsTab() {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSplitView = ResponsiveLayout.canShowSplitView(
          constraints.maxWidth,
          minWidth: 840,
        );

        if (isSplitView) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildAnomaliesSection(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildProductInsightsSection(),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAnomaliesSection(),
            const SizedBox(height: 20),
            _buildProductInsightsSection(),
          ],
        );
      },
    );
  }

  Widget _buildAnomaliesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.radar_rounded,
                size: 16,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Bất thường Ngành hàng (Anomalies)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _buildCountPill(_anomalies.length, color: AppColors.warning),
          ],
        ),
        const SizedBox(height: 10),
        if (_anomalies.isEmpty)
          FlatCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 22,
                  color: AppColors.emerald.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Không phát hiện biến động bất thường nào trong chu kỳ hiện tại.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          ..._anomalies.map((a) {
            final isSpike = a.anomalyType.toLowerCase() == 'spike';
            final badgeColor = isSpike ? AppColors.emerald : AppColors.error;

            return FlatCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSpike
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 18,
                      color: badgeColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.categoryName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Thực tế: ${a.actualQty} • Dự báo: ${a.forecastQty}',
                          style: AppTheme.tabularStyle(
                            const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${isSpike ? "+" : ""}${a.deviationPercent.toStringAsFixed(1)}%',
                      style: AppTheme.tabularStyle(
                        TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildProductInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryBrand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                size: 16,
                color: AppColors.primaryBrand,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Xếp hạng & Xu hướng Sản phẩm',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _buildCountPill(_insights.length, color: AppColors.primaryBrand),
          ],
        ),
        const SizedBox(height: 10),
        if (_insights.isEmpty)
          const FlatCard(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 22,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chưa có báo cáo xếp hạng insight sản phẩm cho chi nhánh này.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          ..._insights.map((ins) {
            final levelLower = ins.insightLevel.toLowerCase();
            final isStar = levelLower == 'star';
            final isWarning = levelLower == 'warning';
            final tagColor = isStar
                ? AppColors.warning
                : isWarning
                    ? AppColors.error
                    : AppColors.primaryBrand;

            return FlatCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isStar
                          ? Icons.star_rounded
                          : isWarning
                              ? Icons.warning_amber_rounded
                              : Icons.trending_up_rounded,
                      size: 18,
                      color: tagColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ins.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tỷ trọng doanh thu: ${ins.contributionPercent.toStringAsFixed(1)}% • Tăng trưởng: ${ins.growthPercent >= 0 ? "+" : ""}${ins.growthPercent.toStringAsFixed(1)}%',
                          style: AppTheme.tabularStyle(
                            const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: ins.insightLevel.toUpperCase(),
                    color: tagColor,
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
