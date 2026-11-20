import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../navigation/app_routes.dart';
import '../models/finance_models.dart';
import '../services/gab_assistant.dart';
import '../widgets/app_drawer.dart';
import '../widgets/account_icon.dart';
import '../pages/cart.dart';

const _quickReplyStarterPhrases = {
  'Income': 'I received ',
  'Expense': 'I spent ',
  'Upcoming Bill': 'I have an upcoming ',
};

const _quickReplyIcons = {
  'Expense': 'assets/images/expense_logged.png',
  'Income': 'assets/images/income_logged.png',
  'Upcoming Bill': 'assets/images/events_logged.png',
};

class GabChatPage extends StatefulWidget {
  const GabChatPage({super.key});

  @override
  State<GabChatPage> createState() => _GabChatPageState();
}

class _GabChatMessage {
  final String text;
  final bool isUser;
  final String? highlightColor;
  const _GabChatMessage({
    required this.text,
    required this.isUser,
    this.highlightColor,
  });
}

class _GabChatPageState extends State<GabChatPage> {
  static final GabAssistant _assistant = GabAssistant();
  static final List<_GabChatMessage> _savedMessages = [];
  static List<String> _savedQuickReplies = [];
  static List<Account> _savedWalletChoices = [];

  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  bool _isTyping = false;
  bool _assistantCallInFlight = false;
  bool _isClearingChat = false;
  int _typingDots = 1;
  int _chatGeneration = 0;
  Timer? _replyTimer;
  Timer? _typingTimer;

  bool get _hasStartedChat => _savedMessages.any((message) => message.isUser);

  bool get _lastMessageIsIncomeConfirmation =>
      _savedMessages.isNotEmpty &&
      !_savedMessages.last.isUser &&
      _savedMessages.last.text.startsWith('💵 Income logged!');

  @override
  void initState() {
    super.initState();
    if (_savedMessages.isEmpty) {
      _loadGreeting();
    }
  }

  Future<void> _loadGreeting() async {
    final g = await _assistant.getAsyncGreeting();
    if (!mounted) return;
    setState(() {
      _savedMessages.add(_GabChatMessage(text: g.text, isUser: false));
      if (g.extraTexts != null) {
        for (var t in g.extraTexts!) {
          _savedMessages.add(_GabChatMessage(text: t, isUser: false));
        }
      }
      _savedQuickReplies = g.quickReplies;
      _savedWalletChoices = g.walletChoices;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _replyTimer?.cancel();
    _typingTimer?.cancel();
    _controller.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQuickReplyTapped(String reply) {
    final starterPhrase = _quickReplyStarterPhrases[reply];
    if (starterPhrase == null) {
      _send(reply);
      return;
    }

    _controller.value = TextEditingValue(
      text: starterPhrase,
      selection: TextSelection.collapsed(offset: starterPhrase.length),
    );
    _inputFocusNode.requestFocus();
  }

  Future<void> _send([String? value]) async {
    if (_isTyping || _assistantCallInFlight || _isClearingChat) return;
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty) return;
    final generation = _chatGeneration;

    _controller.clear();
    setState(() {
      _savedMessages.add(_GabChatMessage(text: text, isUser: true));
      _savedQuickReplies = [];
      _savedWalletChoices = [];
    });
    _scrollToBottom();
    _startTyping();

    _assistantCallInFlight = true;
    setState(() {});
    late final GabReply reply;
    try {
      reply = await _assistant.handle(text);
    } finally {
      _assistantCallInFlight = false;
      if (mounted) setState(() {});
    }
    if (!mounted || generation != _chatGeneration) return;

    final delay = Duration(milliseconds: _random.nextInt(1200) + 1200);
    _replyTimer?.cancel();
    _replyTimer = Timer(delay, () {
      if (!mounted || generation != _chatGeneration) return;
      _stopTyping();
      setState(() {
        _savedMessages.add(
          _GabChatMessage(
            text: reply.text,
            isUser: false,
            highlightColor: reply.highlightColor,
          ),
        );
        if (reply.extraTexts != null) {
          for (var t in reply.extraTexts!) {
            _savedMessages.add(_GabChatMessage(text: t, isUser: false));
          }
        }
        _savedQuickReplies = reply.quickReplies;
        _savedWalletChoices = reply.walletChoices;
      });
      _scrollToBottom();

      if (reply.navigateTo == 'cart_detail' && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: kCartDetailRouteName),
            builder: (_) => const CartDetailPage(),
          ),
        );
      }
    });
  }

  Future<void> _clearChat() async {
    if (_assistantCallInFlight || _isClearingChat) return;
    setState(() => _isClearingChat = true);
    _chatGeneration++;
    _replyTimer?.cancel();
    _typingTimer?.cancel();
    _isTyping = false;
    _assistant.resetConversation();
    try {
      final g = await _assistant.getAsyncGreeting();
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _typingDots = 1;
        _savedMessages.clear();
        _savedMessages.add(_GabChatMessage(text: g.text, isUser: false));
        if (g.extraTexts != null) {
          for (var t in g.extraTexts!) {
            _savedMessages.add(_GabChatMessage(text: t, isUser: false));
          }
        }
        _savedQuickReplies = g.quickReplies;
        _savedWalletChoices = g.walletChoices;
      });
      _scrollToBottom();
    } finally {
      _isClearingChat = false;
      if (mounted) setState(() {});
    }
  }

  void _startTyping() {
    _typingTimer?.cancel();
    setState(() {
      _isTyping = true;
      _typingDots = 1;
    });
    _scrollToBottom();
    _typingTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() => _typingDots = _typingDots == 3 ? 1 : _typingDots + 1);
      _scrollToBottom();
    });
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    _typingTimer = null;
    _isTyping = false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletNames = _savedWalletChoices
        .map((wallet) => wallet.name)
        .toSet();
    final actionQuickReplies = _savedQuickReplies
        .where((reply) => !walletNames.contains(reply))
        .toList();

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        toolbarHeight: 72,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal, size: 28),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset('assets/images/gab.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GAB',
                    style: GoogleFonts.plusJakartaSans(
                      color: kTextCharcoal,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Chat Assistant',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: kMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(
              Icons.keyboard_double_arrow_down_rounded,
              color: kTextCharcoal,
            ),
            tooltip: 'Minimize to bubble',
          ),
          IconButton(
            onPressed: (_assistantCallInFlight || _isClearingChat)
                ? null
                : _clearChat,
            icon: Icon(Icons.delete_sweep_outlined, color: kTextCharcoal),
            tooltip: 'Clear Chat',
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: kBackground,
        foregroundColor: kTextCharcoal,
        centerTitle: false,
      ),
      drawer: const AppDrawer(currentPage: 'GAB'),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _savedMessages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _savedMessages.length) {
                  return _BubbleWidget(message: _savedMessages[index]);
                }
                if (_isTyping) {
                  return _TypingWidget(dots: _typingDots);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          if (!_isTyping && _savedWalletChoices.isNotEmpty)
            WalletQuickRepliesWidget(
              wallets: _savedWalletChoices,
              onTap: _send,
            ),
          if (!_isTyping &&
              actionQuickReplies.isNotEmpty &&
              (!_hasStartedChat ||
                  _savedWalletChoices.isNotEmpty ||
                  _lastMessageIsIncomeConfirmation))
            _QuickRepliesWidget(
              replies: actionQuickReplies,
              onTap: _onQuickReplyTapped,
            ),
          const SizedBox(height: 8),
          _ComposerWidget(
            controller: _controller,
            focusNode: _inputFocusNode,
            isEnabled: !_isTyping,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ═══ WIDGETS ═══

class _TypingWidget extends StatelessWidget {
  final int dots;
  const _TypingWidget({required this.dots});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
          boxShadow: [kShadowSoft],
        ),
        child: Text(
          'GAB is thinking${List.filled(dots, '.').join()}',
          style: GoogleFonts.plusJakartaSans(
            color: kMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class WalletQuickRepliesWidget extends StatelessWidget {
  final List<Account> wallets;
  final ValueChanged<String> onTap;

  const WalletQuickRepliesWidget({
    super.key,
    required this.wallets,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,##0.00', 'en_US');

    return SizedBox(
      height: 66,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: wallets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final wallet = wallets[index];
          final balance = formatter.format(wallet.balance);
          return Semantics(
            button: true,
            label: 'Choose ${wallet.name}, balance ₱$balance',
            child: Material(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => onTap(wallet.name),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder),
                    boxShadow: [kShadowSoft],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AccountIconImage(
                        name: wallet.name,
                        icon: wallet.icon,
                        size: 28,
                      ),
                      const SizedBox(width: 9),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wallet.name,
                            style: GoogleFonts.plusJakartaSans(
                              color: kMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₱$balance',
                            style: GoogleFonts.plusJakartaSans(
                              color: kTextCharcoal,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BubbleWidget extends StatelessWidget {
  final _GabChatMessage message;
  const _BubbleWidget({required this.message});

  // Pattern for inline icon tokens: {{icon:assets/images/gcash.png}}
  static final _iconTokenPattern = RegExp(r'\{\{icon:([^}]+)\}\}');

  /// Splits a line into a list of InlineSpan (TextSpan + WidgetSpan for icons).
  List<InlineSpan> _parseLineWithIcons(String line, TextStyle style) {
    final List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (final match in _iconTokenPattern.allMatches(line)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(text: line.substring(lastEnd, match.start), style: style),
        );
      }
      final assetPath = match.group(1)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Image.asset(
              assetPath,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < line.length) {
      spans.add(TextSpan(text: line.substring(lastEnd), style: style));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: line, style: style));
    }

    return spans;
  }

  Widget _buildRichText(String text, bool isUser) {
    if (isUser) {
      return Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final lines = text.split('\n');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      TextStyle lineStyle;

      if (line.contains('Expense logged!') || line.contains('Paid Bill!')) {
        lineStyle = GoogleFonts.plusJakartaSans(
          color: Colors.redAccent,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        );
      } else if (line.contains('Income logged!') ||
          line.contains('Income Received!') ||
          line.contains('Received Income!')) {
        lineStyle = GoogleFonts.plusJakartaSans(
          color: const Color(0xFF10B981),
          fontWeight: FontWeight.w800,
          fontSize: 15,
        );
      } else if (line.contains('Transfer Logged!')) {
        lineStyle = GoogleFonts.plusJakartaSans(
          color: const Color(0xFF3B82F6),
          fontWeight: FontWeight.w800,
          fontSize: 15,
        );
      } else if (line.trim().startsWith('-')) {
        lineStyle = GoogleFonts.plusJakartaSans(
          color: Colors.redAccent,
          fontWeight: FontWeight.w600,
        );
      } else if (line.trim().startsWith('+')) {
        lineStyle = GoogleFonts.plusJakartaSans(
          color: const Color(0xFF10B981),
          fontWeight: FontWeight.w600,
        );
      } else {
        lineStyle = GoogleFonts.plusJakartaSans(
          color: kTextCharcoal,
          fontWeight: FontWeight.w500,
        );
      }

      if (_iconTokenPattern.hasMatch(line)) {
        spans.addAll(_parseLineWithIcons(line, lineStyle));
      } else {
        spans.add(TextSpan(text: line, style: lineStyle));
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.45),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    // Determine border color based on highlightColor
    Color? borderColor;
    if (!isUser && message.highlightColor != null) {
      if (message.highlightColor == 'red') {
        borderColor = Colors.red;
      } else if (message.highlightColor == 'green') {
        borderColor = Colors.green;
      }
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(bottom: 12, right: 8),
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset('assets/images/gab.png', fit: BoxFit.cover),
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? kPrimary : kCardBg,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: borderColor ?? kBorder,
                        width: borderColor != null ? 2.5 : 1,
                      ),
                boxShadow: isUser ? [] : [kShadowSoft],
              ),
              child: _buildRichText(message.text, isUser),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickRepliesWidget extends StatelessWidget {
  final List<String> replies;
  final ValueChanged<String> onTap;
  const _QuickRepliesWidget({required this.replies, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: replies
            .map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  button: true,
                  label: r,
                  child: Material(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => onTap(r),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: kCardBg,
                          border: Border.all(color: kBorder),
                          boxShadow: [kShadowSoft],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_quickReplyIcons[r] case final icon?) ...[
                              Image.asset(icon, width: 22, height: 22),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              r,
                              style: GoogleFonts.plusJakartaSans(
                                color: kPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ComposerWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isEnabled;
  final VoidCallback onSend;
  const _ComposerWidget({
    required this.controller,
    required this.focusNode,
    required this.isEnabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: kBackground,
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: isEnabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: GoogleFonts.plusJakartaSans(
                  color: kTextCharcoal,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: isEnabled
                      ? 'Ask GAB anything...'
                      : 'GAB is thinking...',
                  hintStyle: TextStyle(color: kMuted),
                  filled: true,
                  fillColor: kCardBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kPrimary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 46,
              height: 46,
              child: IconButton.filled(
                onPressed: isEnabled ? onSend : null,
                icon: const Icon(Icons.send_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: kPrimary,
                  disabledBackgroundColor: kMutedBg,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: kMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
