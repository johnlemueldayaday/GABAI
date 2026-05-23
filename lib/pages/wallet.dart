import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../models/finance_models.dart';
import '../services/finance_storage.dart';
import '../services/settings_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  List<Account> _accounts = [];
  List<FinanceTransaction> _transactions = [];
  bool _isLoading = true;
  final String _currency = SettingsService().currency;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final accounts = await FinanceStorage.loadAccounts();

    _accounts = accounts;

    _transactions = await FinanceStorage.loadTransactions();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddAccountSheet() {
    final nameCtrl = TextEditingController();
    String selectedType = accountTypes.first;
    String selectedIcon = '💰';
    int selectedColorValue = 0xFF10B981;

    final icons = ['💰', '💵', '🏦', '💳', '📱', '📈', '🐷', '🛍️'];
    final colors = [
      0xFF10B981,
      0xFF6366F1,
      0xFF06B6D4,
      0xFFF59E0B,
      0xFFEC4899,
      0xFF84CC16,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Account',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kTextCharcoal,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: kMuted),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: kTextCharcoal),
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  labelStyle: TextStyle(color: kMuted),
                  hintText: 'e.g., Cash, BPI Bank, GCash',
                  hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                dropdownColor: kCardBg,
                style: TextStyle(color: kTextCharcoal, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Account Type',
                  labelStyle: TextStyle(color: kMuted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kPrimary),
                  ),
                ),
                items: accountTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedType = v!),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Icon',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: kMuted,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: icons.length,
                  itemBuilder: (context, index) {
                    final isSel = selectedIcon == icons[index];
                    return GestureDetector(
                      onTap: () =>
                          setSheetState(() => selectedIcon = icons[index]),
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? kPrimary.withValues(alpha: 0.12)
                              : kBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: isSel
                              ? Border.all(color: kPrimary, width: 2)
                              : Border.all(color: kBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          icons[index],
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Color',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: kMuted,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: colors.length,
                  itemBuilder: (context, index) {
                    final colorVal = colors[index];
                    final isSel = selectedColorValue == colorVal;
                    return GestureDetector(
                      onTap: () =>
                          setSheetState(() => selectedColorValue = colorVal),
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: isSel
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      final acc = Account(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        type: selectedType,
                        balance: 0.0,
                        icon: selectedIcon,
                        colorValue: selectedColorValue,
                      );
                      await FinanceStorage.addAccount(acc);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _loadData();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Create Account',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      drawer: const AppDrawer(currentPage: 'Account'),
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Account',
          style: GoogleFonts.plusJakartaSans(
            color: kTextCharcoal,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add_card_rounded, color: kPrimary),
            onPressed: _showAddAccountSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Accounts',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kTextCharcoal,
                        ),
                      ),
                      TextButton(
                        onPressed: _showAddAccountSheet,
                        child: Text(
                          '+ Add New',
                          style: TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.4,
                        ),
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) {
                      final acc = _accounts[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kBorder),
                          boxShadow: [kShadowSoft],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(
                                      acc.colorValue,
                                    ).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    acc.icon,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kBackground,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    acc.type,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: kMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  acc.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: kTextCharcoal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_currency${acc.balance.toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(acc.colorValue),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Recent Transactions',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kTextCharcoal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: kMuted.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No transactions logged yet.',
                              style: GoogleFonts.plusJakartaSans(
                                color: kMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _transactions.length > 5
                          ? 5
                          : _transactions.length,
                      itemBuilder: (context, index) {
                        final txn =
                            _transactions[_transactions.length - 1 - index];
                        final isExpense = txn.isExpense;
                        final color = isExpense ? Colors.red : kPrimary;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: kCardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kBorder),
                            boxShadow: [kShadowSoft],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isExpense
                                      ? Icons.arrow_outward_rounded
                                      : Icons.south_west_rounded,
                                  color: color,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      txn.description.isNotEmpty
                                          ? txn.description
                                          : txn.category,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        color: kTextCharcoal,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          txn.accountName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: kMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 3,
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: kMuted,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat(
                                            'MMM d, h:mm a',
                                          ).format(txn.date),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: kMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isExpense ? "-" : "+"}$_currency${txn.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
