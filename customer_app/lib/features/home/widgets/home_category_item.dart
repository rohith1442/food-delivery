import 'package:flutter/material.dart';

class HomeCategoryItem extends StatelessWidget {
  const HomeCategoryItem({
    super.key,
    required this.category,
    required this.onTap,
  });

  final Map<String, dynamic> category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = category['name']?.toString() ?? 'Category';
    final moduleId = category['moduleId']?.toString() ?? 'food';
    final storeCount = category['storeCount'] ?? 0;
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 88,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(_getIcon(name, moduleId), color: primary, size: 30),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (storeCount is num && storeCount > 1)
                Text(
                  '$storeCount stores',
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String name, String moduleId) {
    final value = name.toLowerCase();

    if (moduleId == 'grocery') {
      if (value.contains('fruit') || value.contains('vegetable')) {
        return Icons.eco_outlined;
      }

      if (value.contains('dairy') || value.contains('milk')) {
        return Icons.local_drink_outlined;
      }

      if (value.contains('snack')) {
        return Icons.cookie_outlined;
      }

      return Icons.shopping_basket_outlined;
    }

    if (value.contains('pizza')) {
      return Icons.local_pizza_outlined;
    }

    if (value.contains('burger')) {
      return Icons.lunch_dining_outlined;
    }

    if (value.contains('biryani') || value.contains('rice')) {
      return Icons.rice_bowl_outlined;
    }

    if (value.contains('dessert') || value.contains('ice')) {
      return Icons.icecream_outlined;
    }

    if (value.contains('drink') || value.contains('beverage')) {
      return Icons.local_cafe_outlined;
    }

    return Icons.restaurant_menu;
  }
}
