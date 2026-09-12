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

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isOpen ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 96,
                  height: 96,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.storefront_outlined,
                              size: 36,
                            );
                          },
                        )
                      : const Icon(Icons.storefront_outlined, size: 36),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: isOpen ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOpen ? 'Open' : 'Closed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOpen ? Colors.green : Colors.red,
                          ),
                        ),
                        if (minimumOrder > 0) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Min $currencySymbol${_formatAmount(minimumOrder)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  num _toNumber(dynamic value) {
    if (value is num) {
      return value;
    }

    if (value is String) {
      return num.tryParse(value) ?? 0;
    }

    return 0;
  }

  String _formatAmount(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}
