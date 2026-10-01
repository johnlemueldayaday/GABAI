import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/account_icon.dart';
import '../models/finance_models.dart';
import '../services/finance_storage.dart';
import '../services/settings_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletChoiceButton extends StatelessWidget {
  final WalletOption wallet;
  final bool isAdded;
  final VoidCallback? onTap;

  const _WalletChoiceButton({
    required this.wallet,
    required this.isAdded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isAdded ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: kBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAdded ? kBorder : Color(wallet.colorValue),
              width: isAdded ? 1 : 1.5,
            ),
          ),
          child: Row(
            children: [
              AccountIconImage(
                name: wallet.name,
                icon: wallet.assetPath,
                size: 36,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  wallet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isAdded ? kMuted : kTextCharcoal,
                  ),
                ),
              ),
              if (isAdded)
                Text(
                  'Added',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletPageState extends State<WalletPage> {
  List<Account> _accounts = [];
  List<FinanceTransaction> _transactions = [];
  bool _isLoading = true;
  bool _showMyAccounts = false;
  final String _currency = SettingsService().currency;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    var accounts = await FinanceStorage.loadAccounts();

    if (!accounts.any((account) => account.name.toLowerCase() == 'cash')) {
      final cash = walletOptionByName('Cash');
      accounts = await FinanceStorage.addAccount(
        Account(
          id: '${DateTime.now().microsecondsSinceEpoch}Cash',
          name: cash.name,
          type: cash.category,
          balance: 0.0,
          icon: cash.assetPath,
          colorValue: cash.colorValue,
        ),
      );
    }

    _accounts = accounts;

    _transactions = await FinanceStorage.loadTransactions();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveWalletBalance(WalletOption wallet, double balance) async {
    Account? existingAccount;
    for (final account in _accounts) {
      if (account.name.toLowerCase() == wallet.name.toLowerCase()) {
        existingAccount = account;
        break;
      }
    }

    final previousBalance = existingAccount?.balance ?? 0;
    if (existingAccount == null) {
      existingAccount = Account(
        id: '${DateTime.now().microsecondsSinceEpoch}${wallet.name}',
        name: wallet.name,
        type: wallet.category,
        balance: 0,
        icon: wallet.assetPath,
        colorValue: wallet.colorValue,
      );
      await FinanceStorage.addAccount(existingAccount);
    }

    if (balance > previousBalance) {
      await FinanceStorage.addTransaction(
        FinanceTransaction(
          id: '${DateTime.now().microsecondsSinceEpoch}_wallet_top_up',
          amount: balance - previousBalance,
          accountId: existingAccount.id,
          accountName: existingAccount.name,
          type: 'INCOME',
          category: 'Wallet Top-up',
          description: 'Added money to ${existingAccount.name}',
        ),
      );
    } else if (balance != previousBalance) {
      await FinanceStorage.updateAccount(
        existingAccount.copyWith(balance: balance),
      );
    }

    await _loadData();
  }

  Future<void> _showAddWalletSheet() async {
    final selectableWallets =
        walletOptions
            .where((wallet) => wallet.name.toLowerCase() != 'cash')
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    final balanceCtrl = TextEditingController();
    WalletOption? selectedWallet;
    var showingBalance = false;
    var isSaving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add Wallet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: kTextCharcoal,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: kMuted),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose the wallet you want to add.',
                    style: GoogleFonts.plusJakartaSans(
                      color: kMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!showingBalance) ...[
                    const SizedBox(height: 18),
                    ...selectableWallets.map((wallet) {
                      final isAdded = _accounts.any(
                        (account) =>
                            account.name.toLowerCase() ==
                            wallet.name.toLowerCase(),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _WalletChoiceButton(
                          wallet: wallet,
                          isAdded: isAdded,
                          onTap: () {
                            selectedWallet = wallet;
                            final existing = _accounts.where(
                              (account) =>
                                  account.name.toLowerCase() ==
                                  wallet.name.toLowerCase(),
                            );
                            final account = existing.isEmpty
                                ? null
                                : existing.first;
                            balanceCtrl.text =
                                account == null || account.balance == 0
                                ? ''
                                : account.balance.toStringAsFixed(2);
                            setSheetState(() => showingBalance = true);
                          },
                        ),
                      );
                    }),
                  ] else ...[
                    const SizedBox(height: 18),
                    Text(
                      'How much money is in your ${selectedWallet!.name}?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kTextCharcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the starting balance for this wallet.',
                      style: GoogleFonts.plusJakartaSans(
                        color: kMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: balanceCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kTextCharcoal,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          color: kMuted.withValues(alpha: 0.5),
                        ),
                        prefixText: '₱',
                        prefixStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: kTextCharcoal,
                        ),
                        filled: true,
                        fillColor: kBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: kPrimary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final value = double.tryParse(
                                  balanceCtrl.text.replaceAll(',', ''),
                                );
                                if (value == null || value < 0) return;
                                setSheetState(() => isSaving = true);
                                await _saveWalletBalance(
                                  selectedWallet!,
                                  value,
                                );
                                if (sheetContext.mounted) {
                                  setSheetState(() {
                                    isSaving = false;
                                    showingBalance = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: kPrimary.withValues(
                            alpha: 0.6,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Confirm',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
    balanceCtrl.dispose();
  }

  Future<void> _undoTransaction(FinanceTransaction transaction) async {
    final deleted = await FinanceStorage.deleteTransaction(transaction.id);
    if (!mounted) return;

    if (deleted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction was already removed.')),
      );
      await _loadData();
      return;
    }

    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Undid ${transaction.description.isNotEmpty ? transaction.description : transaction.category}.',
        ),
      ),
    );
  }

  Future<bool> _confirmUndoTransaction(FinanceTransaction transaction) async {
    final title = transaction.description.isNotEmpty
        ? transaction.description
        : transaction.category;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Undo transaction?'),
            content: Text('This will remove "$title" and restore the balance.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Undo'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _swipeUndoBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.22)),
      ),
      alignment: Alignment.centerRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.undo_rounded, color: Colors.red, size: 20),
          const SizedBox(height: 2),
          Text(
            'Undo',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
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
    final addedWallets = _accounts.where((account) {
      return walletOptions.any(
        (wallet) =>
            wallet.name.toLowerCase() == account.name.toLowerCase() &&
            wallet.name.toLowerCase() != 'cash',
      );
    }).toList();

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
            icon: Icon(
              _showMyAccounts
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: kPrimary,
            ),
            onPressed: () {
              setState(() {
                _showMyAccounts = !_showMyAccounts;
              });
            },
            tooltip: _showMyAccounts ? 'Hide accounts' : 'Show accounts',
          ),
          IconButton(
            icon: Icon(Icons.add_card_rounded, color: kPrimary),
            onPressed: _showAddWalletSheet,
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
                  if (_showMyAccounts) ...[
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Color(
                                        acc.colorValue,
                                      ).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: AccountIconImage(
                                      name: acc.name,
                                      icon: acc.icon,
                                      size: 22,
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
                  ],
                  if (addedWallets.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: addedWallets.map((account) {
                          return Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: kCardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AccountIconImage(
                                  name: account.name,
                                  icon: account.icon,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$_currency${account.balance.toStringAsFixed(2)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                        final account = _accounts.firstWhere(
                          (account) => account.id == txn.accountId,
                          orElse: () => Account(
                            id: txn.accountId,
                            name: txn.accountName,
                            type: '',
                          ),
                        );
                        final title = txn.description.isNotEmpty
                            ? txn.description
                            : txn.category;
                        final previousBalance = txn.previousBalance;

                        return Dismissible(
                          key: ValueKey('wallet_transaction_undo_${txn.id}'),
                          direction: DismissDirection.endToStart,
                          background: _swipeUndoBackground(),
                          confirmDismiss: (_) async {
                            final confirmed = await _confirmUndoTransaction(
                              txn,
                            );
                            if (confirmed) {
                              await _undoTransaction(txn);
                            }
                            return false;
                          },
                          child: Container(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          color: kTextCharcoal,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat(
                                          'MMM d, yyyy',
                                        ).format(txn.date),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: kMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isExpense ? "-" : "+"}$_currency${NumberFormat('#,##0').format(txn.amount)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (previousBalance != null) ...[
                                          Text(
                                            '$_currency${NumberFormat('#,##0').format(previousBalance)}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              color: kMuted,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        AccountIconImage(
                                          name: account.name,
                                          icon: account.icon,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
