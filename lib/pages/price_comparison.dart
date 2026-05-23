import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/models/price_history.dart';
import 'package:gabay/services/price_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PriceComparisonPage extends StatelessWidget {
  const PriceComparisonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final history = PriceStorage.history;
    
    // Find items that have prices recorded at multiple stores
    final itemsWithMultipleStores = <String>[];
    for (final name in history.allItemNames) {
      if (history.getStoresForItem(name).length > 1) {
        itemsWithMultipleStores.add(name);
      }
    }

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(
          'Price Comparison',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: kTextCharcoal,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: itemsWithMultipleStores.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.compare_arrows_rounded, size: 64, color: kMuted.withValues(alpha: 0.3)),
                    const SizedBox(height: 24),
                    Text(
                      'No Comparisons Yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: kTextCharcoal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Shop at different stores to start comparing prices and saving money!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              physics: const BouncingScrollPhysics(),
              itemCount: itemsWithMultipleStores.length,
              itemBuilder: (context, index) {
                final itemName = itemsWithMultipleStores[index];
                return _ComparisonCard(itemName: itemName, history: history);
              },
            ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final String itemName;
  final PriceHistory history;

  const _ComparisonCard({
    required this.itemName,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    // Get unique stores
    final stores = history.getStoresForItem(itemName);
    
    // Get the latest price for each store
    final List<Map<String, dynamic>> storePrices = [];
    double lowestPrice = double.infinity;
    
    for (final store in stores) {
      final records = history.getHistory(itemName)
          .where((r) => r.store.toLowerCase() == store.toLowerCase())
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
        
      if (records.isNotEmpty) {
        final latest = records.first;
        if (latest.price < lowestPrice) {
          lowestPrice = latest.price;
        }
        storePrices.add({
          'store': store,
          'price': latest.price,
          'date': latest.date,
          'unit': latest.unit,
        });
      }
    }
    
    // Sort so lowest price is first
    storePrices.sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: kBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Item Name
          Row(
            children: [
              Expanded(
                child: Text(
                  itemName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kTextCharcoal,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Best ₱${lowestPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          // Store Prices List
          ...storePrices.map((sp) {
            final isBest = sp['price'] == lowestPrice;
            final dateStr = DateFormat('MMM d').format(sp['date'] as DateTime);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    isBest ? Icons.storefront_rounded : Icons.store_outlined,
                    size: 20,
                    color: isBest ? kPrimary : kMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sp['store'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: isBest ? FontWeight.w600 : FontWeight.w500,
                            color: isBest ? kTextCharcoal : kTextCharcoal.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₱${(sp['price'] as double).toStringAsFixed(2)} / ${sp['unit']} • $dateStr',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: kMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isBest)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'BEST',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: kPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
