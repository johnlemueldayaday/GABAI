import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/account_icon.dart';
import '../widgets/gab_picker_sheet.dart';
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
  static const _hiddenBalancesKey = 'wallet_hidden_balance_account_ids';

  List<Account> _accounts = [];
  List<FinanceTransaction> _transactions = [];
  bool _isLoading = true;
  Set<String> _hiddenAccountIds = {};
  final String _currency = SettingsService().currency;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _hiddenAccountIds = prefs.getStringList(_hiddenBalancesKey)?.toSet() ?? {};
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

    accounts = [
      ...accounts.where(
        (account) => account.name.trim().toLowerCase() == 'cash',
      ),
      ...accounts.where(
        (account) => account.name.trim().toLowerCase() != 'cash',
      ),
    ];
    _accounts = accounts;

    _transactions = await FinanceStorage.loadTransactions();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBalanceVisibility(String accountId) async {
    final hiddenAccountIds = Set<String>.from(_hiddenAccountIds);
    if (!hiddenAccountIds.add(accountId)) {
      hiddenAccountIds.remove(accountId);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenBalancesKey, hiddenAccountIds.toList());
    if (!mounted) return;
    setState(() {
      _hiddenAccountIds = hiddenAccountIds;
    });
  }

  Future<void> _showTransferSheet() async {
    if (_accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least two accounts to transfer.')),
      );
      return;
    }

    final amountCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: '10.00');
    String? fromAccountId = _accounts.first.id;
    String? toAccountId = _accounts[1].id;
    String? errorMessage;
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transfer Funds',
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
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('wallet_transfer_amount'),
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(color: kTextCharcoal),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        labelStyle: TextStyle(color: kMuted),
                        prefixText: '$_currency ',
                        prefixStyle: TextStyle(
                          color: kTextCharcoal,
                          fontWeight: FontWeight.bold,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: kPrimary),
                        ),
                      ),
                      onChanged: (_) {
                        if (errorMessage != null) {
                          setSheetState(() => errorMessage = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('wallet_transfer_fee'),
                      controller: feeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(color: kTextCharcoal),
                      decoration: InputDecoration(
                        labelText: 'Transaction Fee',
                        labelStyle: TextStyle(color: kMuted),
                        prefixText: '$_currency ',
                        prefixStyle: TextStyle(
                          color: kTextCharcoal,
                          fontWeight: FontWeight.bold,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: kPrimary),
                        ),
                      ),
                      onChanged: (_) {
                        if (errorMessage != null) {
                          setSheetState(() => errorMessage = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _WalletPickerTile(
                      label: 'From Account',
                      account: fromAccountId != null
                          ? _accounts.firstWhere(
                              (a) => a.id == fromAccountId,
                              orElse: () => _accounts.first)
                          : null,
                      onTap: () async {
                        final picked = await showGabPicker<String>(
                          context: context,
                          title: 'From Account',
                          selectedValue: fromAccountId,
                          items: _accounts
                              .map((a) => GabPickerItem<String>(
                                    value: a.id,
                                    label: a.name,
                                    leading: AccountIconImage(
                                        name: a.name,
                                        icon: a.icon,
                                        size: 24),
                                  ))
                              .toList(),
                        );
                        if (picked != null) {
                          setSheetState(() {
                            fromAccountId = picked.value;
                            if (fromAccountId == toAccountId) {
                              toAccountId = _accounts
                                  .firstWhere(
                                      (a) => a.id != fromAccountId)
                                  .id;
                            }
                            errorMessage = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _WalletPickerTile(
                      label: 'To Account',
                      account: toAccountId != null
                          ? _accounts.firstWhere(
                              (a) => a.id == toAccountId,
                              orElse: () => _accounts
                                  .firstWhere(
                                      (a) => a.id != fromAccountId))
                          : null,
                      onTap: () async {
                        final picked = await showGabPicker<String>(
                          context: context,
                          title: 'To Account',
                          selectedValue: toAccountId,
                          items: _accounts
                              .where((a) => a.id != fromAccountId)
                              .map((a) => GabPickerItem<String>(
                                    value: a.id,
                                    label: a.name,
                                    leading: AccountIconImage(
                                        name: a.name,
                                        icon: a.icon,
                                        size: 24),
                                  ))
                              .toList(),
                        );
                        if (picked != null) {
                          setSheetState(() {
                            toAccountId = picked.value;
                            errorMessage = null;
                          });
                        }
                      },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final amount = double.tryParse(
                                  amountCtrl.text.trim(),
                                );
                                final fee = double.tryParse(
                                  feeCtrl.text.trim(),
                                );
                                if (amount == null ||
                                    !amount.isFinite ||
                                    amount <= 0) {
                                  setSheetState(
                                    () => errorMessage =
                                        'Enter a valid transfer amount.',
                                  );
                                  return;
                                }
                                if (fee == null || !fee.isFinite || fee < 0) {
                                  setSheetState(
                                    () => errorMessage =
                                        'Enter a valid transaction fee (0 or more).',
                                  );
                                  return;
                                }
                                if (fromAccountId == null ||
                                    toAccountId == null) {
                                  setSheetState(
                                    () => errorMessage =
                                        'Select both accounts for the transfer.',
                                  );
                                  return;
                                }

                                final from = _accounts.firstWhere(
                                  (account) => account.id == fromAccountId,
                                );
                                final to = _accounts.firstWhere(
                                  (account) => account.id == toAccountId,
                                );
                                setSheetState(() {
                                  isSaving = true;
                                  errorMessage = null;
                                });
                                try {
                                  await FinanceStorage.transferMoney(
                                    fromAccount: from,
                                    toAccount: to,
                                    amount: amount,
                                    fee: fee,
                                    requireSourceBalance: true,
                                  );
                                  if (!sheetContext.mounted) return;
                                  Navigator.pop(sheetContext);
                                  await _loadData();
                                } catch (error) {
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() {
                                    isSaving = false;
                                    errorMessage = error
                                        .toString()
                                        .replaceFirst('Exception: ', '');
                                  });
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
                          'Transfer Funds',
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
          ),
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    amountCtrl.dispose();
    feeCtrl.dispose();
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
              _WalletPickerTile(
                label: 'Account Type',
                valueLabel: selectedType,
                onTap: () async {
                  final picked = await showGabPicker<String>(
                    context: context,
                    title: 'Account Type',
                    selectedValue: selectedType,
                    items: accountTypes
                        .map((t) =>
                            GabPickerItem<String>(value: t, label: t))
                        .toList(),
                  );
                  if (picked != null) {
                    setSheetState(() => selectedType = picked.value);
                  }
                },
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
    final recentTransactions = _transactions
        .where(
          (transaction) =>
              !(transaction.isTransfer &&
                  transaction.type == 'INCOME' &&
                  transaction.destinationAccountId == null),
        )
        .toList();

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
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: 'Transfer',
            icon: Icon(Icons.swap_horiz_rounded, color: kPrimary),
            onPressed: _showTransferSheet,
          ),
          const SizedBox(width: 4),
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: 'Add wallet',
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
                  Text(
                    'My Accounts',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kTextCharcoal,
                    ),
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
                      final accountColor = Color(acc.colorValue);
                      final isBalanceHidden = _hiddenAccountIds.contains(
                        acc.id,
                      );
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              kCardBg,
                              Color.lerp(kCardBg, kBackground, 0.55)!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.8),
                              offset: const Offset(-4, -4),
                              blurRadius: 9,
                            ),
                            BoxShadow(
                              color: kTextCharcoal.withValues(alpha: 0.12),
                              offset: const Offset(6, 8),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        accountColor.withValues(alpha: 0.2),
                                        accountColor.withValues(alpha: 0.08),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        offset: const Offset(-2, -2),
                                        blurRadius: 5,
                                      ),
                                      BoxShadow(
                                        color: accountColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        offset: const Offset(3, 4),
                                        blurRadius: 7,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: kCardBg.withValues(alpha: 0.9),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: accountColor.withValues(
                                              alpha: 0.16,
                                            ),
                                            offset: const Offset(2, 2),
                                            blurRadius: 4,
                                          ),
                                          BoxShadow(
                                            color: Colors.white.withValues(
                                              alpha: 0.95,
                                            ),
                                            offset: const Offset(-2, -2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: AccountIconImage(
                                        name: acc.name,
                                        icon: acc.icon,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [kCardBg, kBackground],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        offset: const Offset(-1, -1),
                                        blurRadius: 3,
                                      ),
                                      BoxShadow(
                                        color: kTextCharcoal.withValues(
                                          alpha: 0.08,
                                        ),
                                        offset: const Offset(2, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        isBalanceHidden
                                            ? '*****'
                                            : '$_currency${NumberFormat('#,##0.00').format(acc.balance)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: accountColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey(
                                    'wallet_balance_visibility_${acc.id}',
                                  ),
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  tooltip: isBalanceHidden
                                      ? 'Show ${acc.name} balance'
                                      : 'Hide ${acc.name} balance',
                                  onPressed: () =>
                                      _toggleBalanceVisibility(acc.id),
                                  icon: Icon(
                                    isBalanceHidden
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 22,
                                    color: kPrimary,
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
                  if (recentTransactions.isEmpty)
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
                      itemCount: recentTransactions.length > 5
                          ? 5
                          : recentTransactions.length,
                      itemBuilder: (context, index) {
                        final txn =
                            recentTransactions[recentTransactions.length -
                                1 -
                                index];
                        final isExpense = txn.isExpense;
                        final isTransfer = txn.isTransfer;
                        final color = isTransfer
                            ? const Color(0xFF3B82F6)
                            : isExpense
                            ? Colors.red
                            : kPrimary;
                        final account = _accounts.firstWhere(
                          (account) => account.id == txn.accountId,
                          orElse: () => Account(
                            id: txn.accountId,
                            name: txn.accountName,
                            type: '',
                          ),
                        );
                        final destinationName =
                            txn.destinationAccountName ??
                            txn.description
                                .replaceFirst(
                                  RegExp(
                                    r'^(?:transfer|transmitted) to\s+',
                                    caseSensitive: false,
                                  ),
                                  '',
                                )
                                .trim();
                        final destinationAccount = _accounts.firstWhere(
                          (candidate) =>
                              candidate.id == txn.destinationAccountId ||
                              candidate.name.toLowerCase().trim() ==
                                  destinationName.toLowerCase(),
                          orElse: () => Account(
                            id: txn.destinationAccountId ?? '',
                            name: destinationName,
                            type: '',
                          ),
                        );
                        final title = isTransfer
                            ? 'Transmitted to $destinationName'
                            : txn.description.isNotEmpty
                            ? txn.description
                            : txn.category;
                        final previousBalance = txn.previousBalance;
                        final formattedAmount = isTransfer
                            ? NumberFormat('#,##0.00').format(txn.amount)
                            : NumberFormat('#,##0').format(txn.amount);

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
                                Image.asset(
                                  isTransfer
                                      ? 'assets/images/transfer_logged.png'
                                      : isExpense
                                      ? 'assets/images/expense_logged.png'
                                      : 'assets/images/income_logged.png',
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.contain,
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
                                      if (isTransfer) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'from ${account.name}',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 10,
                                                    color: kMuted,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(width: 4),
                                            AccountIconImage(
                                              name: account.name,
                                              icon: account.icon,
                                              size: 15,
                                            ),
                                          ],
                                        ),
                                      ],
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
                                      '${isExpense
                                          ? "-"
                                          : isTransfer
                                          ? ""
                                          : "+"}$_currency$formattedAmount',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (isTransfer) ...[
                                      const SizedBox(height: 6),
                                      AccountIconImage(
                                        key: ValueKey(
                                          'transfer_destination_icon_${txn.id}',
                                        ),
                                        name: destinationAccount.name,
                                        icon: destinationAccount.icon,
                                        size: 16,
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (previousBalance != null) ...[
                                            Text(
                                              '$_currency${NumberFormat('#,##0').format(previousBalance)}',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
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


/// Tappable picker tile for wallet.dart sheets — mirrors [_GabPickerTile] in dashboard.dart.
/// Accepts either an [Account] with icon or just a [valueLabel] string.
class _WalletPickerTile extends StatelessWidget {
  final String label;
  final Account? account;
  final String? valueLabel;
  final VoidCallback onTap;

  const _WalletPickerTile({
    required this.label,
    required this.onTap,
    this.account,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = account?.name ?? valueLabel;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            if (account != null) ...[
              AccountIconImage(name: account!.name, icon: account!.icon, size: 22),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: kMuted,
                    ),
                  ),
                  if (displayValue != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      displayValue,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kTextCharcoal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: kMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
