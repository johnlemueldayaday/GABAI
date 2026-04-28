import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mobile_aismartwallet/pages/home.dart';
import 'package:mobile_aismartwallet/services/chat_storage.dart';

// ─── API Config ────────────────────────────────────────────────────────────────
const _kApiKey = 'AIzaSyA-jPMjkUqBwi7bCptujcmwkl3srH59FTA';

const _kSystemPrompt = '''
You are GroceryAI, a smart grocery budgeting and cooking assistant for Filipino households integrated into the Grocery Wallet app.

Your expertise:
1. Suggest what to cook based on available or bought ingredients
2. Give grocery budget advice using Philippine Peso (₱)
3. Share Filipino recipes (Adobo, Sinigang, Tinola, Kare-kare, Pinakbet, Nilaga, Mechado, Menudo, etc.)
4. List ingredients needed for specific dishes with estimated ₱ costs
5. Recommend healthy, affordable meal options
6. Suggest budget-friendly ingredient substitutions

Philippine market price reference:
- Rice ₱58/kg, Chicken ₱220/kg, Pork ₱320/kg, Beef ₱420/kg
- Bangus ₱180/kg, Tilapia ₱130/kg, Eggs ₱180/dozen, Tofu ₱40/pc
- Sardines ₱28/can, Canned Tuna ₱48/can, Instant Noodles ₱12/pack
- Garlic ₱120/kg, Onion ₱90/kg, Tomato ₱70/kg, Ginger ₱80/kg
- Soy Sauce ₱42/bottle, Vinegar ₱32/bottle, Fish Sauce ₱38/bottle
- Cooking Oil ₱90/L, Salt ₱20/pack, Pepper ₱50/pack

Rules:
- Be friendly, warm, and concise
- Use bullet points for lists
- Include ₱ cost estimates when relevant
- Use Filipino food terms naturally (patis, toyo, suka, sabaw)
- Reference user's current grocery list when giving advice
- When asked what to cook, check their list first before suggesting

IMPORTANT - Grocery List JSON:
Whenever you suggest a recipe or list ingredients to buy, you MUST include a JSON block at the very end of your response wrapped in these exact tags:
[GROCERY_LIST_JSON]
[{"name":"Item Name","qty":1,"unit":"pcs","price":0.0,"category":"Pantry"},{"name":"Another Item","qty":2,"unit":"can","price":28.0,"category":"Pantry"}]
[/GROCERY_LIST_JSON]

Rules for the JSON:
- "name": ingredient name (capitalized, e.g. "Sardines" not "sardines")
- "qty": number quantity (integer or decimal)
- "unit": one of: pcs, kg, g, L, mL, pack, box, can, bottle, dozen, bundle, loaf, jar, roll, sachet
- "price": estimated price per unit in Philippine Peso (number only, no ₱ symbol)
- "category": one of: Fridge, Pantry, Vegetables, Fruits, Spices, Snacks, Drinks, Household
- Always include this JSON when listing ingredients for a dish
- The JSON must be valid and parseable
''';

// ─── Quick Prompts ─────────────────────────────────────────────────────────────
const _kQuickPrompts = [
  (Icons.restaurant_menu_outlined, 'What can I cook?'),
  (Icons.account_balance_wallet_outlined, 'Am I over budget?'),
  (Icons.lightbulb_outline_rounded, 'Budget meal ideas'),
  (Icons.shopping_cart_outlined, 'Adobo ingredients'),
  (Icons.eco_outlined, 'Healthy options'),
  (Icons.calendar_month_outlined, 'Weekly meal plan'),
];

// ─── AIChatPage ────────────────────────────────────────────────────────────────
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final _messages = <ChatMessage>[];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late GenerativeModel _model;
  late GenerativeModel _fallbackModel;
  ChatSession? _session;
  ChatSession? _fallbackSession;
  bool _isTyping = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _kApiKey,
      systemInstruction: Content.system(_kSystemPrompt),
    );
    _fallbackModel = GenerativeModel(
      model: 'gemini-2.0-flash-lite',
      apiKey: _kApiKey,
      systemInstruction: Content.system(_kSystemPrompt),
    );
    _init();
  }

  Future<void> _init() async {
    final saved = await ChatStorage.load();
    final history = <Content>[];
    for (final m in saved) {
      if (m.isUser) {
        history.add(Content.text(m.text));
      } else {
        history.add(Content('model', [TextPart(m.text)]));
      }
    }
    _session = _model.startChat(history: history);
    _fallbackSession = _fallbackModel.startChat(history: history);
    setState(() {
      _messages.addAll(saved);
      _isLoading = false;
    });
    if (_messages.isEmpty) _addWelcome();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _addWelcome() {
    final welcome = ChatMessage(
      text:
          'Hi! I am GroceryAI, your smart grocery and cooking assistant.\n\n'
          'I can help you plan meals from your ingredients, manage your budget, '
          'find recipes, or tell you what to buy for any dish.\n\n'
          'What would you like help with today?',
      isUser: false,
      timestamp: DateTime.now(),
    );
    setState(() => _messages.add(welcome));
    ChatStorage.save(_messages);
  }

  String _buildContext() {
    final list = AppState.currentList;
    if (list == null || list.items.isEmpty) return '';
    final sb = StringBuffer('[Current Grocery List]\n');
    sb.writeln('Name: ${list.name} | Budget: ₱${list.budget.toStringAsFixed(2)}');
    double total = 0;
    for (final item in list.items) {
      total += item.price * item.qty;
      sb.writeln('- ${item.name} x${item.qty} ${item.unit} @ ₱${item.price}');
    }
    sb.writeln(
        'Total: ₱${total.toStringAsFixed(2)} | Remaining: ₱${(list.budget - total).toStringAsFixed(2)}');
    return sb.toString();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping || _session == null) return;
    _controller.clear();

    final ctx = _buildContext();
    final fullText = ctx.isNotEmpty ? '$ctx\nUser question: $trimmed' : trimmed;

    setState(() {
      _messages.add(ChatMessage(text: trimmed, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      // Try primary model first, fall back on 503/overload errors
      String reply;
      try {
        final response = await _session!.sendMessage(Content.text(fullText));
        reply = response.text ?? 'Sorry, I could not generate a response.';
      } catch (primaryError) {
        final errStr = primaryError.toString();
        if (errStr.contains('503') || errStr.contains('UNAVAILABLE') || errStr.contains('overloaded')) {
          debugPrint('⚠️ Primary model busy, trying fallback...');
          // Wait a moment then try fallback model
          await Future.delayed(const Duration(seconds: 2));
          _fallbackSession ??= _fallbackModel.startChat(history: []);
          final fallbackResponse = await _fallbackSession!.sendMessage(Content.text(fullText));
          reply = fallbackResponse.text ?? 'Sorry, I could not generate a response.';
        } else {
          rethrow;
        }
      }

      // Check if the reply contains grocery list JSON and extract items
      final parsed = _parseGroceryJson(reply);
      final displayText = parsed.displayText;
      final groceryItems = parsed.items;

      setState(() {
        _messages.add(ChatMessage(text: displayText, isUser: false, timestamp: DateTime.now()));
        _isTyping = false;
      });

      await ChatStorage.save(_messages);

      // Ask for confirmation before adding ingredients to shopping list
      if (groceryItems.isNotEmpty && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Add Ingredients?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
              content: Text(
                'The AI suggested ${groceryItems.length} ingredient${groceryItems.length > 1 ? 's' : ''}. Would you like to add them to your shopping list?',
                style: GoogleFonts.plusJakartaSans(color: kMuted, fontWeight: FontWeight.w500),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(foregroundColor: kMuted),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: kPrimary),
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        );

        if (confirm == true) {
          _addItemsToShoppingList(groceryItems);
        }
      }
    } catch (e) {
      debugPrint('🔴 AI Chat Error: $e');
      final errStr = e.toString();
      String userMessage;
      if (errStr.contains('503') || errStr.contains('UNAVAILABLE')) {
        userMessage = '🔄 The AI is experiencing high demand right now. Please wait a moment and try again.';
      } else if (errStr.contains('429') || errStr.contains('quota')) {
        userMessage = '⏳ API quota exceeded. Please wait a minute before trying again.';
      } else {
        userMessage = '⚠️ Something went wrong. Please check your connection and try again.';
      }
      setState(() {
        _messages.add(ChatMessage(
          text: userMessage,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  // ─── Parse grocery JSON from AI response ──────────────────────────────────
  ({String displayText, List<Map<String, dynamic>> items}) _parseGroceryJson(String text) {
    final regex = RegExp(r'\[GROCERY_LIST_JSON\]\s*(.+?)\s*\[/GROCERY_LIST_JSON\]', dotAll: true);
    final match = regex.firstMatch(text);
    if (match == null) return (displayText: text, items: []);

    final jsonStr = match.group(1)!.trim();
    final displayText = text.substring(0, match.start).trim();

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final items = list.map((e) => e as Map<String, dynamic>).toList();
      return (displayText: displayText, items: items);
    } catch (e) {
      debugPrint('🔴 Failed to parse grocery JSON: $e');
      return (displayText: displayText, items: []);
    }
  }

  // ─── Add parsed items to the shopping list ────────────────────────────────
  void _addItemsToShoppingList(List<Map<String, dynamic>> items) {
    // Create a new list if none exists
    if (AppState.currentList == null) {
      final newList = GroceryList('AI Recipe List');
      AppState.lists.add(newList);
      AppState.activeIndex = AppState.lists.length - 1;
    }

    int addedCount = 0;
    for (final item in items) {
      final name = (item['name'] as String?) ?? 'Unknown';
      final qty = (item['qty'] is num) ? (item['qty'] as num).toDouble() : 1.0;
      final unit = (item['unit'] as String?) ?? 'pcs';
      final price = (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;
      final category = (item['category'] as String?) ?? 'Pantry';

      // Check for duplicates by name (case-insensitive)
      final alreadyExists = AppState.currentList!.items.any(
        (existing) => existing.name.toLowerCase() == name.toLowerCase(),
      );
      if (alreadyExists) continue;

      AppState.currentList!.items.add(GroceryItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${name.hashCode}',
        name: name,
        qty: qty,
        unit: unit,
        price: price,
        category: category,
      ));
      addedCount++;
    }

    if (addedCount > 0) {
      setState(() {
        _messages.add(ChatMessage(
          text: '✅ Added $addedCount ingredient${addedCount > 1 ? 's' : ''} to your shopping list!\n\nGo back to Shopping to see them.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      ChatStorage.save(_messages);

      // Show a snackbar confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🛒 $addedCount item${addedCount > 1 ? 's' : ''} added to shopping list',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: kPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'VIEW LIST',
              textColor: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        );
      }
    } else {
      setState(() {
        _messages.add(ChatMessage(
          text: 'ℹ️ All ingredients are already in your shopping list!',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      ChatStorage.save(_messages);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Chat', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(
          'This will delete your entire chat history.',
          style: GoogleFonts.plusJakartaSans(color: kMuted, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: kMuted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ChatStorage.clear();
              _session = _model.startChat(history: []);
              setState(() => _messages.clear());
              _addWelcome();
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: kTextCharcoal, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: kPrimary, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: GoogleFonts.plusJakartaSans(
                    color: kTextCharcoal,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Grocery · Cooking · Budget',
                  style: GoogleFonts.plusJakartaSans(
                    color: kMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: kMuted, size: 22),
            onPressed: _clearChat,
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildContextBanner(),
          if (_messages.length <= 1) _buildQuickPrompts(),
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildContextBanner() {
    final list = AppState.currentList;
    if (list == null || list.items.isEmpty) return const SizedBox.shrink();
    final total = list.items.fold(0.0, (s, i) => s + i.price * i.qty);
    final isOver = total > list.budget && list.budget > 0;
    final Color bannerColor = isOver ? Colors.red : kPrimary;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isOver
            ? Colors.red.withValues(alpha: 0.06)
            : kPrimarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isOver ? Icons.warning_rounded : Icons.shopping_cart_outlined,
            size: 16,
            color: bannerColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${list.name}  ·  ${list.items.length} items  ·  ₱${total.toStringAsFixed(0)} / ₱${list.budget.toStringAsFixed(0)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: bannerColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isOver
                ? 'Over budget'
                : '₱${(list.budget - total).toStringAsFixed(0)} left',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isOver ? Colors.red : kPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK QUESTIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: kMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kQuickPrompts.length,
              separatorBuilder: (context, i) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (icon, label) = _kQuickPrompts[i];
                return GestureDetector(
                  onTap: () => _send(label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kPrimarySoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kPrimary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 13, color: kPrimary),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            color: kPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (_, i) {
        if (_isTyping && i == _messages.length) return const _TypingBubble();
        return _MessageBubble(message: _messages[i]);
      },
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: TextField(
                  controller: _controller,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kTextCharcoal,
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  decoration: InputDecoration(
                    hintText: 'Ask me anything about groceries...',
                    hintStyle: TextStyle(color: kMuted, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _SendButton(onTap: () => _send(_controller.text)),
          ],
        ),
      ),
    );
  }
}

// ─── Send Button (matches BouncingFAB style) ───────────────────────────────────
class _SendButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) {
        setState(() => _isDown = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isDown = false),
      child: AnimatedScale(
        scale: _isDown ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuad,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [kPrimary, kPrimaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withValues(alpha: 0.3),
                offset: const Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ─── Message Bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: kPrimary, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_outlined, size: 14, color: Colors.white),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [kPrimary, kPrimaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [kShadowSoft],
              ),
              child: _buildText(message.text, isUser),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildText(String text, bool isUser) {
    // Simple **bold** parser
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(fontWeight: i.isOdd ? FontWeight.w700 : FontWeight.w500),
      ));
    }
    return RichText(
      text: TextSpan(
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          color: isUser ? Colors.white : kTextCharcoal,
          height: 1.55,
        ),
        children: spans,
      ),
    );
  }
}

// ─── Typing Indicator ──────────────────────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 450)),
    );
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0, end: -5).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();
    _startLoop();
  }

  void _startLoop() async {
    while (mounted) {
      for (int i = 0; i < 3; i++) {
        if (!mounted) return;
        _controllers[i].forward();
        await Future.delayed(const Duration(milliseconds: 140));
      }
      await Future.delayed(const Duration(milliseconds: 280));
      for (final c in _controllers) {
        c.reverse();
      }
      await Future.delayed(const Duration(milliseconds: 380));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: kPrimary, shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined, size: 14, color: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [kShadowSoft],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => AnimatedBuilder(
                  animation: _anims[i],
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _anims[i].value),
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                      decoration: BoxDecoration(
                        color: kPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AI Chat FAB (matches app's BouncingFAB style) ────────────────────────────
class AIChatFab extends StatefulWidget {
  const AIChatFab({super.key});

  @override
  State<AIChatFab> createState() => _AIChatFabState();
}

class _AIChatFabState extends State<AIChatFab> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) {
        setState(() => _isDown = false);
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, b) => const AIChatPage(),
            transitionsBuilder: (_, a, b, child) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.08), end: Offset.zero)
                    .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
                child: child,
              ),
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      onTapCancel: () => setState(() => _isDown = false),
      child: AnimatedScale(
        scale: _isDown ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuad,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withValues(alpha: 0.18),
                offset: const Offset(0, 6),
                blurRadius: 14,
              ),
            ],
          ),
          child: Icon(Icons.smart_toy_outlined, color: kPrimary, size: 24),
        ),
      ),
    );
  }
}
