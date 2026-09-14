import 'package:flutter/material.dart';

class OrderLifecycle extends StatelessWidget {
  const OrderLifecycle({super.key, required this.status, this.compact = false});
  final String status;
  final bool compact;
  static const _steps = [
    ('VENDOR_PENDING', 'Order Placed', Icons.receipt_long_outlined),
    ('ACCEPTED', 'Accepted', Icons.check_circle_outline),
    ('PREPARING', 'Preparing', Icons.restaurant_outlined),
    ('READY', 'Ready', Icons.inventory_2_outlined),
    ('RIDER_ASSIGNED', 'Rider Assigned', Icons.person_pin_circle_outlined),
    ('PICKED_UP', 'Picked Up', Icons.shopping_bag_outlined),
    ('ON_THE_WAY', 'On The Way', Icons.delivery_dining_outlined),
    ('DELIVERED', 'Delivered', Icons.home_outlined),
  ];
  @override
  Widget build(BuildContext context) {
    if (status == 'REJECTED' || status == 'CANCELLED') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          status == 'REJECTED'
              ? 'Order rejected by restaurant'
              : 'Order cancelled',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    final current = _steps
        .indexWhere((step) => step.$1 == status)
        .clamp(0, _steps.length - 1);
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: (current + 1) / _steps.length,
            minHeight: 6,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 7),
          Text(
            _steps[current].$2,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          _TimelineStep(
            title: _steps[i].$2,
            icon: _steps[i].$3,
            completed: i <= current,
            current: i == current,
          ),
          if (i != _steps.length - 1)
            _TimelineConnector(completed: i < current),
        ],
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.icon,
    required this.completed,
    required this.current,
  });
  final String title;
  final IconData icon;
  final bool completed, current;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed
                ? primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Icon(
            completed ? Icons.check : icon,
            size: 20,
            color: completed
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: current ? FontWeight.bold : FontWeight.w500,
              color: completed
                  ? null
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (current)
          Text(
            'Current',
            style: TextStyle(
              fontSize: 12,
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector({required this.completed});
  final bool completed;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(left: 18),
      width: 2,
      height: 22,
      color: completed
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}
