import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';
import '../services/tarsi_assistant.dart';
import '../widgets/app_drawer.dart';

class TarsiChatPage extends StatefulWidget {
  const TarsiChatPage({super.key});

  @override
  State<TarsiChatPage> createState() => _TarsiChatPageState();
}

class _TarsiChatMessage {
  final String text;
  final bool isUser;

  const _TarsiChatMessage({required this.text, required this.isUser});
}

class _TarsiChatPageState extends State<TarsiChatPage> {
  static final TarsiAssistant _assistant = TarsiAssistant();
  static final List<_TarsiChatMessage> _savedMessages = [];
  static List<String> _savedQuickReplies = [];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  bool _isTyping = false;
  int _typingDots = 1;
  Timer? _replyTimer;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    if (_savedMessages.isEmpty) {
      final greeting = _assistant.greeting;
      setState(() {
        _savedMessages.add(_TarsiChatMessage(text: greeting.text, isUser: false));
        if (greeting.extraTexts != null) {
          for (var t in greeting.extraTexts!) {
            _savedMessages.add(_TarsiChatMessage(text: t, isUser: false));
          }
        }
        _savedQuickReplies = greeting.quickReplies;
      });
      _scrollToBottom();
    }
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
      _savedMessages.add(_TarsiChatMessage(text: text, isUser: true));
      _savedQuickReplies = [];
    });
    _scrollToBottom();

    _startTyping();
    
    // Process NLP locally
    final reply = await _assistant.handle(text);
    
    final delay = Duration(milliseconds: _random.nextInt(1000) + 1000);
    _replyTimer?.cancel();
    _replyTimer = Timer(delay, () {
      if (!mounted) return;
      _stopTyping();
      setState(() {
        _savedMessages.add(_TarsiChatMessage(text: reply.text, isUser: false));
        if (reply.extraTexts != null) {
          for (var t in reply.extraTexts!) {
            _savedMessages.add(_TarsiChatMessage(text: t, isUser: false));
          }
        }
        _savedQuickReplies = reply.quickReplies;
      });
      _scrollToBottom();
    });
  }

  void _clearChat() {
    _replyTimer?.cancel();
    _typingTimer?.cancel();
    final greeting = _assistant.greeting;
    setState(() {
      _isTyping = false;
      _typingDots = 1;
      _savedMessages.clear();
      _savedMessages.add(_TarsiChatMessage(text: greeting.text, isUser: false));
      if (greeting.extraTexts != null) {
        for (var t in greeting.extraTexts!) {
          _savedMessages.add(_TarsiChatMessage(text: t, isUser: false));
        }
      }
      _savedQuickReplies = greeting.quickReplies;
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
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('🦉', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tarsi',
                    style: GoogleFonts.plusJakartaSans(
                      color: kTextCharcoal,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
                          'Your Smart Financial Assistant',
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
      drawer: const AppDrawer(currentPage: 'Tarsi'),
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
                  return _MessageBubble(message: _savedMessages[index]);
                }
                if (_isTyping) {
                  return _TypingBubble(dots: _typingDots);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          if (!_isTyping && _savedQuickReplies.isNotEmpty)
            _QuickReplies(replies: _savedQuickReplies, onTap: _send),
          const SizedBox(height: 8),
          _Composer(
            controller: _controller,
            isEnabled: !_isTyping,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  final int dots;

  const _TypingBubble({required this.dots});

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
          'Tarsi is thinking${List.filled(dots, '.').join()}',
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

class _MessageBubble extends StatelessWidget {
  final _TarsiChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.isUser ? kPrimary : kCardBg;
    final textColor = message.isUser ? Colors.white : kTextCharcoal;

    return Align(
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(bottom: 12, right: 8),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('🦉', style: TextStyle(fontSize: 18)),
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
                color: color,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: message.isUser ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: message.isUser ? const Radius.circular(4) : const Radius.circular(20),
                ),
                border: message.isUser ? null : Border.all(color: kBorder),
                boxShadow: message.isUser ? [] : [kShadowSoft],
              ),
              child: Text(
                message.text,
                style: GoogleFonts.plusJakartaSans(
                  color: textColor,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickReplies extends StatelessWidget {
  final List<String> replies;
  final ValueChanged<String> onTap;

  const _QuickReplies({required this.replies, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: replies
            .map(
              (reply) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => onTap(reply),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: kCardBg,
                        border: Border.all(color: kBorder),
                        boxShadow: [kShadowSoft],
                      ),
                      child: Text(
                        reply,
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

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isEnabled;
  final VoidCallback onSend;

  const _Composer({
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
                  hintText: isEnabled ? 'Tell Tarsi what to log or check...' : 'Tarsi is thinking...',
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
