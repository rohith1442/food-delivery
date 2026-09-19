import 'package:flutter/material.dart';

class StoreCard extends StatelessWidget {
  const StoreCard({
    super.key,
    required this.store,
    required this.currencySymbol,
    required this.onTap,
  });

  final Map<String, dynamic> store;
  final String currencySymbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = store['name']?.toString() ?? 'Store';
    final address = store['address']?.toString() ?? '';
    final imageUrl = store['imageUrl']?.toString();
    final isOpen = store['isOpen'] == true;
    final minimumOrder = _toNumber(store['minimumOrder']);
    final ratingAverage = store['ratingAverage'] is num
        ? (store['ratingAverage'] as num).toDouble()
        : 0.0;
    final ratingCount = store['ratingCount'] is num
        ? (store['ratingCount'] as num).toInt()
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: isOpen ? onTap : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 190,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _storePlaceholder(context),
                        )
                      : _storePlaceholder(context),
                  if (ratingCount > 0)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ratingAverage.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isOpen ? Colors.green.shade700 : Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isOpen ? 'Open' : 'Closed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                  if (minimumOrder > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Minimum order $currencySymbol${_formatAmount(minimumOrder)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storePlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.storefront_outlined, size: 48)),
    );
  }

  num _toNumber(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  String _formatAmount(num value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}
