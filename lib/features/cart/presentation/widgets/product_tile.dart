import 'package:flutter/material.dart';

import 'package:kasirku/core/database/app_database.dart';
import 'package:kasirku/core/theme/app_colors.dart';
import 'package:kasirku/core/utils/format.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.stock,
    required this.qtyInCart,
    required this.onTap,
    required this.onLongPress,
  });

  final Product product;
  final int stock;
  final int qtyInCart;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final soldOut = stock <= 0;
    final low = !soldOut && product.minStock > 0 && stock <= product.minStock;
    final selected = qtyInCart > 0;

    return Opacity(
      opacity: soldOut ? 0.5 : 1,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: soldOut ? null : onTap,
          onLongPress: selected ? onLongPress : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 72,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        initials(product.name),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            '$qtyInCart',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        rupiah(product.sellPrice),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                      ),
                    ),
                    Text(
                      soldOut ? 'Habis' : 'Stok $stock',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: soldOut || low ? AppColors.danger : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}