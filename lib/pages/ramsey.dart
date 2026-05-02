import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gabay/config/ai_config.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/services/chat_storage.dart';
import 'package:gabay/services/chat_ai_service.dart';
import 'package:gabay/services/gemini_http_service.dart';
import 'package:gabay/services/local_openai_chat_service.dart';
import 'package:gabay/widgets/app_drawer.dart';
import 'package:gabay/services/grocery_storage.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/models/bill_models.dart';

const _kSystemPromptBase = '''
You are Ramsey, a smart grocery budgeting and cooking assistant for Filipino households integrated into the GABAY app.

Your expertise:
1. Suggest what to cook based on available or bought ingredients
2. Give grocery budget advice using Philippine Peso (₱)
3. Share Filipino recipes (Adobo, Sinigang, Tinola, Kare-kare, Pinakbet, Nilaga, Mechado, Menudo, etc.)
4. List ingredients needed for specific dishes with estimated ₱ costs
5. Recommend healthy, affordable meal options
6. Suggest budget-friendly ingredient substitutions
7. Answer questions about current bills and overdue payments from the Bills Tracker.

Philippine market price reference:
- Rice ₱58/kg, Chicken ₱220/kg, Pork ₱320/kg, Beef ₱420/kg
- Bangus ₱180/kg, Tilapia ₱130/kg, Eggs ₱180/dozen, Tofu ₱40/pc
- Sardines ₱28/can, Canned Tuna ₱48/can, Instant Noodles ₱12/pack
- Garlic ₱120/kg, Onion ₱90/kg, Tomato ₱70/kg, Ginger ₱80/kg
- Soy Sauce ₱42/bottle, Vinegar ₱32/bottle, Fish Sauce ₱38/bottle
- Cooking Oil ₱90/L, Salt ₱20/pack, Pepper ₱50/pack

Rules:
- Be friendly, warm, and concise
- Use numbered lists for dish suggestions (1., 2., 3...) so the user can easily select one by just typing the number.
- Use bullet points (•) for ingredients or other general lists. NEVER use asterisks (*) for bullet points.
- Include ₱ cost estimates when relevant
- Use Filipino food terms naturally (patis, toyo, suka, sabaw)
- ALWAYS base your cooking suggestions on the user's current grocery list or pantry ingredients.
- If the user asks "what can I cook?" DO NOT just decide a random dish for them. Instead, ask follow-up questions like "What are you craving today?" or "What ingredients do you currently have?" to gather more context.
- Never arbitrarily pick a dish and list its ingredients unless the user specifically asks for that recipe or agrees to your suggestion.
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
- When the user asks "Suggest me a dish to cook", provide exactly 5 random examples in this format:
  1. [Dish Name] - Brief info/description
  2. [Dish Name] - Brief info/description
  (and so on up to 5)
  Do NOT list ingredients or recipes yet. Wait for the user to pick one by number or name.
- The JSON must be valid and parseable
- VERY IMPORTANT: When you suggest a recipe or ingredients, DO NOT say you automatically added them.
- VERY IMPORTANT: Do NOT ask whether to add ingredients to the shopping list. The app will ask that as a separate follow-up message.
''';

// Quick prompts are now generated dynamically in _AIChatPageState

// ─── RamseyPage ────────────────────────────────────────────────────────────────
class RamseyPage extends StatefulWidget {
  const RamseyPage({super.key});

  @override
  State<RamseyPage> createState() => _RamseyPageState();
}

class _RamseyPageState extends State<RamseyPage> {
  final _messages = <ChatMessage>[];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  ChatAiService? _aiService;
  bool _isTyping = false;
  bool _isLoading = true;

  // Items waiting for user confirmation before adding
  List<Map<String, dynamic>> _pendingGroceryItems = [];
  String? _currentRecipeName;
  List<Bill> _allBills = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final chatAvailable =
        AIConfig.useLocalAi ? AIConfig.hasLocalAiConfig : AIConfig.hasGeminiApiKey;

    if (!chatAvailable) {
      _aiService = null;
      await _loadMessages();
      return;
    }

    if (chatAvailable) {
      _allBills = await BillStorage.loadBills();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final nextWeek = today.add(const Duration(days: 7));

      final overdueBills =
          _allBills.where((b) => b.dueDate.isBefore(today) && !b.isPaid).toList();
      final upcomingBills = _allBills
          .where(
            (b) =>
                (b.dueDate.isAtSameMomentAs(today) ||
                    (b.dueDate.isAfter(today) && b.dueDate.isBefore(nextWeek))) &&
                !b.isPaid,
          )
          .toList();
      final monthlyBills = _allBills
          .where((b) => b.dueDate.year == now.year && b.dueDate.month == now.month)
          .toList();

      final overdueTotal = overdueBills.fold(0.0, (sum, b) => sum + b.amount);
      final upcomingTotal = upcomingBills.fold(0.0, (sum, b) => sum + b.amount);
      final monthlyTotal = monthlyBills.fold(0.0, (sum, b) => sum + b.amount);

      // Analyze shopping insights
      int greenCount = 0;
      int unhealthyCount = 0;
      for (var list in AppState.recentLists) {
        for (var item in list.items) {
          final cat = item.category.toLowerCase();
          if (cat == 'vegetables' || cat == 'fruits') greenCount++;
          if (cat == 'snacks' || cat == 'drinks') unhealthyCount++;
        }
      }

      String context = "\n\n--- APP CONTEXT ---\n";

      context += "BILLS TRACKER:\n";
      context += "- Overdue: ${overdueBills.length} bills (Total ₱${overdueTotal.toStringAsFixed(2)})\n";
      context += "- Upcoming (Next 7 days): ${upcomingBills.length} bills (Total ₱${upcomingTotal.toStringAsFixed(2)})\n";
      context += "- Current Month Total: ₱${monthlyTotal.toStringAsFixed(2)}\n";

      context += "\nSHOPPING INSIGHTS:\n";
      context += "- Healthy Items (Vegetables/Fruits) bought recently: $greenCount\n";
      context += "- Less Healthy Items (Snacks/Drinks) bought recently: $unhealthyCount\n";
      if (unhealthyCount > greenCount && unhealthyCount > 0) {
        context += "NOTE: The user has been buying more snacks than greens recently. Gently suggest adding more vegetables or fruits to their list.\n";
      } else if (greenCount > 0) {
        context += "NOTE: The user is doing great with their healthy choices! Encourage them.\n";
      }

      final fullPrompt = _kSystemPromptBase + context;

      _aiService = AIConfig.useLocalAi ? LocalOpenAIChatService() : GeminiHttpService();
      _aiService!.initWithSystemPrompt(fullPrompt);
      await _loadMessages();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMessages() async {
    final saved = await ChatStorage.load();
    // Load saved messages into HTTP service history
    if (_aiService != null) {
      final historyMaps = saved.map((m) => <String, String>{
        'role': m.isUser ? 'user' : 'model',
        'text': m.text,
      }).toList();
      _aiService!.loadHistory(historyMaps);
    }
    setState(() {
      _messages.addAll(saved);
      _isLoading = false;
    });
    if (_messages.isEmpty) {
      if (_aiService != null) {
        _addWelcome();
      } else {
        _addMissingAiMessage();
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _addWelcome() {
    final welcome = ChatMessage(
      text: "Hi! I'm Ramsey, your cooking assistant.",
      isUser: false,
      timestamp: DateTime.now(),
    );
    setState(() => _messages.add(welcome));
    ChatStorage.save(_messages);
  }

  String _getMealType() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) return 'breakfast';
    if (hour >= 10 && hour < 15) return 'lunch';
    if (hour >= 15 && hour < 18) return 'snack';
    if (hour >= 18 && hour < 22) return 'dinner';
    return 'midnight snack';
  }

  List<(IconData, String)> _getDynamicQuickPrompts() {
    final meal = _getMealType();
    return [
      (Icons.restaurant_menu_outlined, 'What can I cook for $meal?'),
      (Icons.account_balance_wallet_outlined, 'How much did I spend this week?'),
      (Icons.receipt_long_rounded, 'How much for my overdue bills?'),
      (Icons.eco_outlined, 'Healthy options'),
      (Icons.calendar_month_outlined, 'Weekly meal plan'),
    ];
  }

  void _addMissingAiMessage() {
    final text = AIConfig.useLocalAi
        ? 'Local AI is not configured yet.\n\n'
            'Install Ollama, run `ollama pull ${AIConfig.localAiModel}`, then start the app again. '
            'For Android emulator, run with `--dart-define=LOCAL_AI_BASE_URL=http://10.0.2.2:11434/v1`.'
        : 'AI Assistant is not configured yet.\n\n'
            'Add `GEMINI_API_KEY` to your local `.env`, then run the app with '
            '`./scripts/flutter_with_env.sh run` or `.\\scripts\\flutter_with_env.ps1 run` so the key stays out of the frontend source.';
    final message = ChatMessage(
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
    setState(() => _messages.add(message));
    ChatStorage.save(_messages);
  }

  String _buildContext() {
    final list = AppState.currentList;
    final recent = AppState.recentLists;
    final sb = StringBuffer();

    if (recent.isNotEmpty) {
      sb.writeln('[Recent Shopping History]');
      for (var i = 0; i < recent.length && i < 10; i++) {
        final r = recent[i];
        double rTotal = r.items.fold(0.0, (sum, item) => sum + (item.price * item.qty));
        sb.writeln('- ${r.name}: ₱${rTotal.toStringAsFixed(2)}');
      }
      sb.writeln('');
    }

    if (list != null && list.items.isNotEmpty) {
      sb.writeln('[Current Grocery List]');
      sb.writeln('Name: ${list.name} | Budget: ₱${list.budget.toStringAsFixed(2)}');
      double total = 0;
      for (final item in list.items) {
        total += item.price * item.qty;
        sb.writeln('- ${item.name} x${item.qty} ${item.unit} @ ₱${item.price}');
      }
      sb.writeln(
          'Total: ₱${total.toStringAsFixed(2)} | Remaining: ₱${(list.budget - total).toStringAsFixed(2)}');
    }
    return sb.toString();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping || _aiService == null) return;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(text: trimmed, isUser: true, timestamp: DateTime.now()));
    });
    _scrollToBottom();

    if (_handlePendingIngredientReply(trimmed)) {
      await ChatStorage.save(_messages);
      _scrollToBottom();
      return;
    }

    final ctx = _buildContext();
    final fullText = ctx.isNotEmpty ? '$ctx\nUser question: $trimmed' : trimmed;

    setState(() {
      _isTyping = true;
    });

    try {
      final reply = await _aiService!.sendMessage(fullText);

      // Check if the reply contains grocery list JSON and extract items
      final parsed = _parseGroceryJson(reply);
      final groceryItems = parsed.items;
      final displayText = groceryItems.isEmpty
          ? parsed.displayText
          : _stripAddToListQuestion(parsed.displayText);

      // Try to extract recipe name from the display text (e.g. "**Spicy Adobo**")
      final nameMatch = RegExp(r'\*\*(.+?)\*\*').firstMatch(displayText);
      if (nameMatch != null) {
        _currentRecipeName = nameMatch.group(1);
      } else {
        // Fallback: look for lines starting with "1. Adobo"
        final numberedMatch = RegExp(r'^\d+\.\s+([^\-]+)', multiLine: true).firstMatch(displayText);
        if (numberedMatch != null) {
          _currentRecipeName = numberedMatch.group(1)?.trim();
        }
      }

      setState(() {
        if (displayText.isNotEmpty) {
          _messages.add(ChatMessage(text: displayText, isUser: false, timestamp: DateTime.now()));
        }
        if (groceryItems.isNotEmpty) {
          _messages.add(ChatMessage(
            text: 'Do you want me to add these ingredients to your shopping list?',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        }
        _isTyping = false;
      });

      await ChatStorage.save(_messages);
      _pendingGroceryItems = groceryItems;
    } catch (e) {
      debugPrint('🔴 AI Chat Error: $e');
      final errStr = e.toString();
      String userMessage;
      if (errStr.contains('503') || errStr.contains('UNAVAILABLE')) {
        userMessage = '🔄 The AI is experiencing high demand right now. Please wait a moment and try again.';
      } else if (errStr.contains('429') || errStr.contains('quota')) {
        userMessage = '⏳ API quota exceeded. Please wait a minute before trying again.';
      } else if (errStr.contains('API key not valid')) {
        userMessage = '🔑 The API key is invalid. Please check your configuration.';
      } else if (AIConfig.useLocalAi &&
          (errStr.contains('Connection refused') ||
              errStr.contains('SocketException') ||
              errStr.contains('Local AI server'))) {
        userMessage = 'Local AI is not reachable. Make sure Ollama or llama.cpp server is running at ${AIConfig.localAiBaseUrl} with model `${AIConfig.localAiModel}`.';
      } else {
        userMessage = '⚠️ Something went wrong: ${e.toString().split(':').last.trim()}';
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

  bool _handlePendingIngredientReply(String userReply) {
    if (_pendingGroceryItems.isEmpty) return false;

    if (_isAffirmative(userReply)) {
      final itemsToAdd = List<Map<String, dynamic>>.from(_pendingGroceryItems);
      _pendingGroceryItems.clear();

      if (!mounted) return true;

      showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: kCardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Add Ingredients?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: kTextCharcoal)),
            content: Text(
              'Would you like to add these ${itemsToAdd.length} ingredients to your shopping list?',
              style: GoogleFonts.plusJakartaSans(color: kTextCharcoal.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
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
      ).then((confirm) {
        if (confirm == true && mounted) {
          _addItemsToShoppingList(itemsToAdd);
        }
      });
      return true;
    }

    if (_isNegative(userReply)) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'No problem. I will leave the recipe as-is and not add anything to your shopping list.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _pendingGroceryItems.clear();
      return true;
    }

    return false;
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

  String _stripAddToListQuestion(String text) {
    return text
        .replaceAll(
          RegExp(
            r'\s*(do you want me to add (these )?ingredients to your shopping (list|cart)\??)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  bool _isAffirmative(String text) {
    return RegExp(
      r'^(yes|yeah|yep|sure|ok|okay|add|please|add it|yes please|sure add it|go ahead)[!\.]?$',
      caseSensitive: false,
    ).hasMatch(text.trim());
  }

  bool _isNegative(String text) {
    return RegExp(
      r"^(no|nope|not now|maybe later|don't add|do not add)[!\.]?$",
      caseSensitive: false,
    ).hasMatch(text.trim());
  }

  // ─── Add parsed items to the shopping list ────────────────────────────────
  void _addItemsToShoppingList(List<Map<String, dynamic>> items) {
    // Create a new list if none exists
    if (AppState.currentList == null) {
      final listTitle = _currentRecipeName ?? 'AI Recipe List';
      final newList = GroceryList(listTitle);
      AppState.lists.add(newList);
      AppState.activeIndex = AppState.lists.length - 1;
    } else if (AppState.currentList!.items.isEmpty && _currentRecipeName != null) {
      // If current list is empty and generic, rename it to the recipe
      if (AppState.currentList!.name == 'New List' || AppState.currentList!.name == 'AI Recipe List') {
        AppState.currentList!.name = _currentRecipeName!;
      }
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
      GroceryStorage.saveAll();

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
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Chat', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: kTextCharcoal)),
        content: Text(
          'This will delete your entire chat history.',
          style: GoogleFonts.plusJakartaSans(color: kTextCharcoal.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
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
              _aiService?.clearHistory();
              // Re-init with system prompt
              await _init();
              setState(() => _messages.clear());
              if (_aiService != null) {
                _addWelcome();
              } else {
                _addMissingAiMessage();
              }
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
      drawer: const AppDrawer(currentPage: 'Ramsey'),
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
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
                  'Ramsey',
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
          Expanded(child: _buildMessageList()),
          if (_messages.length <= 1) _buildQuickPrompts(),
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
    final prompts = _getDynamicQuickPrompts();
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'QUICK QUESTIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: kMuted,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ...List.generate(prompts.length, (index) {
            final (icon, label) = prompts[index];
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + (index * 100)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _send(label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withValues(alpha: 0.08),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: kPrimary),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: GoogleFonts.plusJakartaSans(
                            color: kPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
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
          color: kCardBg,
          border: Border(top: BorderSide(color: kBorder)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
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
                color: isUser ? null : kCardBg,
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
      if (!mounted) return;
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
              color: kCardBg,
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

// ─── Ramsey FAB (matches app's BouncingFAB style) ────────────────────────────
class RamseyFab extends StatefulWidget {
  const RamseyFab({super.key});

  @override
  State<RamseyFab> createState() => _RamseyFabState();
}

class _RamseyFabState extends State<RamseyFab> {
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
            pageBuilder: (_, a, b) => const RamseyPage(),
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
            color: kCardBg,
            shape: BoxShape.circle,
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
