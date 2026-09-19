import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_branding.dart';
import '../cart_page.dart';
import '../cart_provider.dart';

class CartFloatingBar extends ConsumerWidget {
  const CartFloatingBar({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 12),
  });

  final EdgeInsets margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart.isEmpty) return const SizedBox.shrink();

    final cartNotifier = ref.read(cartProvider.notifier);
    final branding = AppBrandingController.instance.branding;
    final currency = branding.currencySymbol;
    final itemCount = cartNotifier.itemCount;
    final total = cartNotifier.total;

    return SafeArea(
      top: false,
      minimum: margin,
      child: Material(
        color: branding.primary,
        borderRadius: BorderRadius.circular(16),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CartPage()));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$currency$total',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'VIEW CART',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
