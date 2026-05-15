import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gabay/config/app_theme.dart';
import 'package:gabay/services/ramsey_cooking_assistant.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/widgets/app_drawer.dart';

class RamseyChatPage extends StatefulWidget {
  const RamseyChatPage({super.key});

  @override
  State<RamseyChatPage> createState() => _RamseyChatPageState();
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}

class _QuickQuestionItem {
  final IconData icon;
  final String label;

  const _QuickQuestionItem({required this.icon, required this.label});
}

class _RamseyChatPageState extends State<RamseyChatPage> {
  static RamseyCookingAssistant _assistant = RamseyCookingAssistant();
  static final List<_ChatMessage> _savedMessages = [];
  static List<String> _savedQuickReplies = [];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  bool _isTyping = false;
  int _typingDots = 1;
  Timer? _replyTimer;
  Timer? _typingTimer;

  List<_QuickQuestionItem> get _starterQuestions {
    final meal = RamseyCookingAssistant.detectMeal(DateTime.now()).toLowerCase();
    return [
      _QuickQuestionItem(
        icon: Icons.restaurant_menu_rounded,
        label: 'What can I cook for $meal?',
      ),
      const _QuickQuestionItem(
        icon: Icons.auto_awesome_rounded,
        label: 'Suggest a dish based on my budget.',
      ),
      const _QuickQuestionItem(
        icon: Icons.receipt_long_rounded,
        label: 'Do I have any upcoming bills?',
      ),
      const _QuickQuestionItem(
        icon: Icons.insights_rounded,
        label: 'Show my spending analytics.',
      ),
      const _QuickQuestionItem(
        icon: Icons.calendar_month_rounded,
        label: 'Generate a weekly meal plan.',
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _loadBills();
    if (mounted && _savedMessages.isEmpty) {
      final greeting = _assistant.greeting;
      setState(() {
        _savedMessages.add(_ChatMessage(text: greeting.text, isUser: false));
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

  Future<void> _loadBills() async {
    final bills = await BillStorage.loadBills();
    if (mounted) {
      _assistant.updateBills(bills);
    }
  }

  void _send([String? value]) {
    if (_isTyping) return;

    final text = (value ?? _controller.text).trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _savedMessages.add(_ChatMessage(text: text, isUser: true));
      _savedQuickReplies = [];
    });
    _scrollToBottom();
    _showReplyAfterDelay(_assistant.handle(text));
  }

  void _showReplyAfterDelay(RamseyReply reply) {
    _startTyping();
    final delay = Duration(milliseconds: _random.nextInt(2000) + 2000);
    _replyTimer?.cancel();
    _replyTimer = Timer(delay, () {
      if (!mounted) return;
      _stopTyping();
      setState(() {
        _savedMessages.add(_ChatMessage(text: reply.text, isUser: false));
        _savedQuickReplies = reply.quickReplies;
      });
      _scrollToBottom();
    });
  }

  void _clearChat() {
    _replyTimer?.cancel();
    _typingTimer?.cancel();
    _assistant = RamseyCookingAssistant();
    final greeting = _assistant.greeting;
    setState(() {
      _isTyping = false;
      _typingDots = 1;
      _savedMessages
        ..clear()
        ..add(_ChatMessage(text: greeting.text, isUser: false));
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
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const _RamseyHeader(),
        actions: [
          IconButton(
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear chat',
          ),
          const SizedBox(width: 6),
        ],
        elevation: 0,
        backgroundColor: kBackground,
        foregroundColor: kTextCharcoal,
        centerTitle: false,
      ),
      drawer: const AppDrawer(currentPage: 'Ramsey'),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: _savedMessages.length + 
                         (_isTyping ? 1 : 0) + 
                         ((!_isTyping && _savedMessages.length <= 1) ? 1 : 0) +
                         ((!_isTyping && _savedQuickReplies.isNotEmpty) ? 1 : 0),
              itemBuilder: (context, index) {
                // 1. Regular messages
                if (index < _savedMessages.length) {
                  return RepaintBoundary(child: _MessageBubble(message: _savedMessages[index]));
                }
                
                int remaining = index - _savedMessages.length;

                // 2. Typing Indicator
                if (_isTyping) {
                  if (remaining == 0) return RepaintBoundary(child: _TypingBubble(dots: _typingDots));
                  remaining--;
                }

                // 3. Starter Questions (only if 1 or fewer messages)
                if (!_isTyping && _savedMessages.length <= 1) {
                  if (remaining == 0) return _QuickQuestions(questions: _starterQuestions, onTap: _send);
                  remaining--;
                }

                // 4. Quick Replies
                if (!_isTyping && _savedQuickReplies.isNotEmpty) {
                  if (remaining == 0) return _QuickReplies(replies: _savedQuickReplies, onTap: _send);
                }

                return const SizedBox.shrink();
              },
            ),
          ),
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

class _RamseyHeader extends StatelessWidget {
  const _RamseyHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: AssetImage('assets/images/ramseychef.png'),
              fit: BoxFit.cover,
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
                'Ramsey',
                style: GoogleFonts.inter(
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
                      'Your Smart Assistant & Kitchen Buddy',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: kMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          'Ramsey is typing${List.filled(dots, '.').join()}',
          style: GoogleFonts.inter(
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
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
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
              margin: const EdgeInsets.only(bottom: 10, right: 8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage('assets/images/ramseychef.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: message.isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: message.isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                border: message.isUser ? null : Border.all(color: kBorder),
                boxShadow: message.isUser
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Text(
                message.text,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickQuestions extends StatelessWidget {
  final List<_QuickQuestionItem> questions;
  final ValueChanged<String> onTap;

  const _QuickQuestions({required this.questions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: Text(
              'QUICK QUESTIONS',
              style: GoogleFonts.inter(
                color: kMuted,
                fontSize: 11,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...questions.map(
            (question) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _QuestionPill(
                icon: question.icon,
                label: question.label,
                onTap: () => onTap(question.label),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: replies
            .map(
              (reply) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _QuestionPill(label: reply, onTap: () => onTap(reply)),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _QuestionPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  const _QuestionPill({this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCardBg,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42, maxWidth: 310),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: kCardBg,
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: kPrimary),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    color: kPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
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
                style: GoogleFonts.inter(
                  color: kTextCharcoal,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: isEnabled
                      ? 'Ask Ramsey what to cook...'
                      : 'Ramsey is typing...',
                  hintStyle: TextStyle(color: kMuted),
                  filled: true,
                  fillColor: kCardBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: kPrimary, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton.filled(
                onPressed: isEnabled ? onSend : null,
                icon: const Icon(Icons.send_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: kPrimary,
                  disabledBackgroundColor: kMutedBg,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: kMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
