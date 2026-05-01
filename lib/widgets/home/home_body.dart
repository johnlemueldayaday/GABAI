import 'package:flutter/material.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/widgets/home/sections/budget_overview_section.dart';
import 'package:gabay/widgets/home/sections/empty_list_section.dart';
import 'package:gabay/widgets/home/sections/grocery_list_section.dart';
import 'package:gabay/widgets/home/sections/shopping_header_section.dart';

// Renders the animated scrollable content of the home screen.
class HomeBody extends StatelessWidget {
  final bool isInit;
  final String listName;
  final double budget;
  final double checkedTotal;
  final double plannedTotal;
  final double left;
  final double progress;
  final List<GroceryItem> allItems;
  final List<GroceryItem> toBuy;
  final List<GroceryItem> doneItems;
  final VoidCallback onEditListName;
  final VoidCallback onFinishList;
  final VoidCallback onClearAll;
  final VoidCallback onEditBudget;
  final void Function(GroceryItem item) onToggleItem;
  final void Function(GroceryItem item) onDeleteItem;
  final void Function(GroceryItem item, int delta) onChangeQty;
  final void Function(GroceryItem item) onEditPrice;
  final void Function(GroceryItem item) onEditUnit;
  final void Function(GroceryItem item) onEditItemName;

  const HomeBody({
    super.key,
    required this.isInit,
    required this.listName,
    required this.budget,
    required this.checkedTotal,
    required this.plannedTotal,
    required this.left,
    required this.progress,
    required this.allItems,
    required this.toBuy,
    required this.doneItems,
    required this.onEditListName,
    required this.onFinishList,
    required this.onClearAll,
    required this.onEditBudget,
    required this.onToggleItem,
    required this.onDeleteItem,
    required this.onChangeQty,
    required this.onEditPrice,
    required this.onEditUnit,
    required this.onEditItemName,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: isInit ? 1.0 : 0.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, isInit ? 0 : 20, 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShoppingHeaderSection(
                      listName: listName,
                      onEditListName: onEditListName,
                      onFinishList: onFinishList,
                      onClearAll: onClearAll,
                    ),
                    const SizedBox(height: 24),
                    BudgetOverviewSection(
                      budget: budget,
                      total: checkedTotal,
                      plannedTotal: plannedTotal,
                      left: left,
                      progress: progress,
                      onTap: onEditBudget,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              if (allItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: const EmptyListSection(),
                )
              else ...[
                if (toBuy.isNotEmpty)
                  GroceryListSection(
                    title: 'TO BUY',
                    items: toBuy,
                    titlePadding: const EdgeInsets.only(bottom: 12),
                    onToggle: onToggleItem,
                    onDelete: onDeleteItem,
                    onQtyChange: onChangeQty,
                    onPriceEdit: onEditPrice,
                    onUnitEdit: onEditUnit,
                    onNameEdit: onEditItemName,
                  ),
              ],
              if (doneItems.isNotEmpty)
                GroceryListSection(
                  title: 'DONE',
                  items: doneItems,
                  titlePadding: const EdgeInsets.only(top: 16, bottom: 12),
                  onToggle: onToggleItem,
                  onDelete: onDeleteItem,
                  onQtyChange: onChangeQty,
                  onPriceEdit: onEditPrice,
                  onUnitEdit: onEditUnit,
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}
