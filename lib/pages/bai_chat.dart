import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';
import '../services/bai_assistant.dart';
import '../widgets/app_drawer.dart';
import '../pages/cart.dart';

class BaiChatPage extends StatefulWidget {
  const BaiChatPage({super.key});

  @override
  State<BaiChatPage> createState() => _BaiChatPageState();
}

class _BaiChatMessage {
  final String text;
  final bool isUser;
  final String? highlightColor;
  const _BaiChatMessage({
    required this.text,
    required this.isUser,
    this.highlightColor,
  });
}

class _BaiChatPageState extends State<BaiChatPage> {
  static final BaiAssistant _assistant = BaiAssistant();
  static final List<_BaiChatMessage> _savedMessages = [];
  static List<String> _savedQuickReplies = [];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  bool _isTyping = false;
  int _typingDots = 1;
  Timer? _replyTimer;
  Timer? _typingTimer;

  bool get _hasStartedChat => _savedMessages.any((message) => message.isUser);

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
      _savedMessages.add(_BaiChatMessage(text: g.text, isUser: false));
      if (g.extraTexts != null) {
        for (var t in g.extraTexts!) {
          _savedMessages.add(_BaiChatMessage(text: t, isUser: false));
        }
      }
      _savedQuickReplies = g.quickReplies;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _replyTimer?.cancel();
    _typingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? value]) async {
    if (_isTyping) return;
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _savedMessages.add(_BaiChatMessage(text: text, isUser: true));
      _savedQuickReplies = [];
    });
    _scrollToBottom();
    _startTyping();

    final reply = await _assistant.handle(text);

    final delay = Duration(milliseconds: _random.nextInt(1200) + 1200);
    _replyTimer?.cancel();
    _replyTimer = Timer(delay, () {
      if (!mounted) return;
      _stopTyping();
      setState(() {
        _savedMessages.add(
          _BaiChatMessage(
            text: reply.text,
            isUser: false,
            highlightColor: reply.highlightColor,
          ),
        );
        if (reply.extraTexts != null) {
          for (var t in reply.extraTexts!) {
            _savedMessages.add(_BaiChatMessage(text: t, isUser: false));
          }
        }
        _savedQuickReplies = reply.quickReplies;
      });
      _scrollToBottom();

      if (reply.navigateTo == 'cart_detail' && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartDetailPage()),
        );
      }
    });
  }

  void _clearChat() {
    _replyTimer?.cancel();
    _typingTimer?.cancel();
    final g = _assistant.greeting;
    setState(() {
      _isTyping = false;
      _typingDots = 1;
      _savedMessages.clear();
      _savedMessages.add(_BaiChatMessage(text: g.text, isUser: false));
      if (g.extraTexts != null) {
        for (var t in g.extraTexts!) {
          _savedMessages.add(_BaiChatMessage(text: t, isUser: false));
        }
      }
      _savedQuickReplies = g.quickReplies;
    });
    _scrollToBottom();
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
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [kPrimary, kPrimaryLight]),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                'BAI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BAI',
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
                          'Brother AI • Your Smart Assistant',
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
            onPressed: _clearChat,
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
      drawer: const AppDrawer(currentPage: 'BAI'),
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
          if (!_isTyping && !_hasStartedChat && _savedQuickReplies.isNotEmpty)
            _QuickRepliesWidget(replies: _savedQuickReplies, onTap: _send),
          const SizedBox(height: 8),
          _ComposerWidget(
            controller: _controller,
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
          'BAI is thinking${List.filled(dots, '.').join()}',
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

class _BubbleWidget extends StatelessWidget {
  final _BaiChatMessage message;
  const _BubbleWidget({required this.message});

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
    final List<TextSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('Expense logged!')) {
        spans.add(
          TextSpan(
            text: line,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.redAccent,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        );
      } else if (line.contains('Income logged!')) {
        spans.add(
          TextSpan(
            text: line,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF10B981), // Premium emerald green
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        );
      } else if (line.trim().startsWith('-')) {
        // Highlight logged negative amount line in red
        spans.add(
          TextSpan(
            text: line,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else if (line.trim().startsWith('+')) {
        // Highlight logged positive amount line in green
        spans.add(
          TextSpan(
            text: line,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF10B981),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: line,
            style: GoogleFonts.plusJakartaSans(
              color: kTextCharcoal,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          height: 1.45,
        ),
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
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [kPrimary, kPrimaryLight]),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                'B',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
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
                child: Material(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => onTap(r),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
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
                      child: Text(
                        r,
                        style: GoogleFonts.plusJakartaSans(
                          color: kPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
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
  final bool isEnabled;
  final VoidCallback onSend;
  const _ComposerWidget({
    required this.controller,
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
                      ? 'Ask BAI anything...'
                      : 'BAI is thinking...',
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
