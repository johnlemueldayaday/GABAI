import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/data/grocery_database.dart';
import 'package:gabay/widgets/home/home_helpers.dart';
import 'package:gabay/widgets/home/sections/add_item_category_tabs.dart';
import 'package:gabay/widgets/home/sections/add_item_entry_controls.dart';
import 'package:gabay/widgets/home/sections/add_item_search_field.dart';
import 'package:gabay/widgets/home/sections/add_item_sheet_header.dart';
import 'package:gabay/widgets/home/sections/add_item_status_badges.dart';
import 'package:gabay/widgets/home/sections/add_item_submit_button.dart';
import 'package:gabay/widgets/home/sections/add_item_suggestions_section.dart';
import 'package:gabay/widgets/home/sections/numeric_keypad_sheet.dart';
import 'package:gabay/widgets/home/sections/sheet_handle.dart';
import 'package:gabay/widgets/home/sections/spring_curve.dart';

// Renders the add-item bottom sheet and receives saved item callbacks.
class AddItemSheet extends StatefulWidget {
  final void Function(GroceryItem) onAdd;
  final void Function(Map<String, dynamic>) onSaveCustom;
  final void Function(String name, double price) onRecordUsage;
  final List<Map<String, dynamic>> customItems;
  final List<String> recentItemNames;
  final Map<String, double> lastPrices;
  const AddItemSheet({
    super.key,
    required this.onAdd,
    required this.onSaveCustom,
    required this.onRecordUsage,
    required this.customItems,
    required this.recentItemNames,
    required this.lastPrices,
  });

  @override
  State<AddItemSheet> createState() => AddItemSheetState();
}

// Manages add-item search, speech, category, quantity, unit, and price state.
class AddItemSheetState extends State<AddItemSheet>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  double _qty = 1.0;
  String _unit = 'pcs';
  String _selectedCategory = 'All';
  bool _speechAvailable = false;
  bool _isListening = false;
  String? _speechErrorText;
  late AnimationController _sheetAnimCtrl;
  late AnimationController _micPulseCtrl;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _micPulseScale;

  static const _categories = [
    'All',
    'Fridge',
    'Pantry',
    'Vegetables',
    'Fruits',
    'Spices',
    'Snacks',
    'Drinks',
    'Household',
    'Custom',
  ];
  static const _units = [
    'pcs',
    'kg',
    'g',
    'L',
    'mL',
    'pack',
    'box',
    'can',
    'bottle',
    'dozen',
    'bundle',
    'loaf',
    'jar',
    'roll',
    'sachet',
  ];

  @override
  void initState() {
    super.initState();
    _sheetAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _sheetAnimCtrl,
            // Spring-like curve in Flutter: use Curves.elasticOut or a custom SpringSimulation
            curve: const SpringCurve(damping: 30, stiffness: 300),
          ),
        );
    _micPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _micPulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _micPulseCtrl, curve: Curves.easeInOut),
    );
    _sheetAnimCtrl.forward();
    _initSpeech();
  }

  @override
  void dispose() {
    if (_speech.isListening) {
      _speech.stop();
    }
    _micPulseCtrl.dispose();
    _sheetAnimCtrl.dispose();
    _searchCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );

    if (!mounted) return;

    setState(() {
      _speechAvailable = available;
      if (!available) {
        _speechErrorText = 'Voice input is unavailable on this device.';
      }
    });
  }

  Future<void> _toggleListening() async {
    FocusScope.of(context).unfocus();

    if (_isListening) {
      await _stopListening();
      return;
    }

    if (!_speechAvailable) {
      setState(() {
        _speechErrorText = 'Voice input is unavailable right now.';
      });
      return;
    }

    final started = await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
    );

    if (!mounted) return;

    setState(() {
      _isListening = started;
      _speechErrorText = started
          ? null
          : 'Could not start voice input. Please try again.';
    });

    if (started) {
      _micPulseCtrl.repeat(reverse: true);
    }
  }

  Future<void> _stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }

    if (!mounted) return;

    _micPulseCtrl.stop();
    _micPulseCtrl.value = 0;

    setState(() {
      _isListening = false;
    });
  }

  void _onSpeechStatus(String status) {
    final stillListening = status == 'listening';
    if (!mounted) return;

    if (!stillListening && _isListening) {
      _micPulseCtrl.stop();
      _micPulseCtrl.value = 0;
    }

    setState(() {
      _isListening = stillListening;
    });
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;

    _micPulseCtrl.stop();
    _micPulseCtrl.value = 0;

    setState(() {
      _isListening = false;
      _speechErrorText = error.errorMsg.isEmpty
          ? 'Voice input failed. Please try again.'
          : error.errorMsg;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final transcript = result.recognizedWords.trim();
    if (!mounted || transcript.isEmpty) return;

    _searchCtrl.value = TextEditingValue(
      text: transcript,
      selection: TextSelection.collapsed(offset: transcript.length),
    );

    setState(() {
      _speechErrorText = null;
    });
  }

  List<Map<String, dynamic>> get _allDatabase => [
    ...GroceryDatabase.items,
    ...widget.customItems,
  ];

  List<Map<String, dynamic>> get _filteredSuggestions {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _allDatabase.where((item) {
      final matchesCategory =
          _selectedCategory == 'All' || item['category'] == _selectedCategory;
      final matchesSearch =
          query.isEmpty ||
          item['name'].toString().toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    // Sort so most recently added items appear first
    final recentNames = widget.recentItemNames;
    filtered.sort((a, b) {
      final aName = a['name'].toString();
      final bName = b['name'].toString();
      final aIndex = recentNames.indexOf(aName);
      final bIndex = recentNames.indexOf(bName);
      // Both recent: lower index = more recent = should come first
      if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
      // Only one is recent: it goes first
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      // Neither recent: keep original order
      return 0;
    });

    return filtered;
  }

  bool get _isCustomItem {
    final name = _searchCtrl.text.trim().toLowerCase();
    if (name.isEmpty) return false;
    return !_allDatabase.any(
      (item) => item['name'].toString().toLowerCase() == name,
    );
  }

  void _addToList() {
    final name = _searchCtrl.text.trim();
    if (name.isEmpty) return;
    final price = double.tryParse(_priceCtrl.text) ?? 0;

    if (_isListening) {
      _stopListening();
    }

    // Save custom item for future use
    if (_isCustomItem) {
      widget.onSaveCustom({
        'name': name,
        'price': price,
        'unit': _unit,
        'category': 'Custom',
      });
    }

    // Record this item as most recently used and remember its price
    widget.onRecordUsage(name, price);

    widget.onAdd(
      GroceryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        qty: _qty,
        unit: _unit,
        price: price,
        category: _selectedCategory == 'All' ? 'Custom' : _selectedCategory,
      ),
    );
    Navigator.pop(context);
  }

  void _onSuggestionTap(Map<String, dynamic> item) {
    if (_isListening) {
      _stopListening();
    }

    setState(() {
      final name = item['name'].toString();
      _searchCtrl.text = name;
      // Use the last remembered price if available, otherwise fall back to DB
      final rememberedPrice = widget.lastPrices[name];
      _priceCtrl.text = rememberedPrice != null
          ? rememberedPrice.toStringAsFixed(2)
          : item['price'].toString();
      _unit = item['unit'];
      if (item['category'] != 'Custom') {
        _selectedCategory = item['category'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final hasText = _searchCtrl.text.trim().isNotEmpty;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                AddItemSheetHeader(onClose: () => Navigator.pop(context)),
                AddItemSearchField(
                  controller: _searchCtrl,
                  onChanged: (_) {
                    setState(() {
                      _speechErrorText = null;
                    });
                  },
                  onToggleListening: _toggleListening,
                  isListening: _isListening,
                  micPulseScale: _micPulseScale,
                ),
                SpeechStatusIndicator(
                  isListening: _isListening,
                  errorText: _speechErrorText,
                ),
                CustomItemBadge(isVisible: _isCustomItem),
                const SizedBox(height: 16),
                AddItemCategoryTabs(
                  categories: _categories,
                  selectedCategory: _selectedCategory,
                  onSelected: (cat) => setState(() => _selectedCategory = cat),
                ),
                const SizedBox(height: 20),
                AddItemSuggestionsSection(
                  suggestions: _filteredSuggestions,
                  onSuggestionTap: _onSuggestionTap,
                ),
                const SizedBox(height: 30),
                AddItemEntryControls(
                  qty: _qty,
                  unit: _unit,
                  priceText: _priceCtrl.text,
                  units: _units,
                  onDecreaseQty: () => setState(
                    () => _qty = stepQty(_qty, -1, _unit),
                  ),
                  onIncreaseQty: () => setState(
                    () => _qty = stepQty(_qty, 1, _unit),
                  ),
                  onUnitChanged: (unit) {
                    setState(() {
                      _unit = unit;
                      if (_unit != 'kg') {
                        _qty = _qty.truncateToDouble();
                        if (_qty < 1.0) _qty = 1.0;
                      }
                    });
                  },
                  onPriceTap: () async {
                    FocusScope.of(context).unfocus();
                    final double currentPrice =
                        double.tryParse(_priceCtrl.text) ?? 0.0;
                    final itemName = _searchCtrl.text.trim();
                    final result = await showModalBottomSheet<double>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => NumericKeypadSheet(
                        initialValue: currentPrice,
                        itemName: itemName.isEmpty ? 'New Item' : itemName,
                      ),
                    );
                    if (result != null) {
                      setState(
                        () => _priceCtrl.text = result.toStringAsFixed(2),
                      );
                    }
                  },
                ),
                const SizedBox(height: 30),
                AddItemSubmitButton(hasText: hasText, onTap: _addToList),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
