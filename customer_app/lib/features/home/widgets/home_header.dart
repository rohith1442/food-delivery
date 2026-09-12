import 'package:flutter/material.dart';

import '../../../core/config/app_branding.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.address,
    required this.loadingAddress,
    required this.onLocationTap,
    required this.onNotificationTap,
    required this.onLogoutTap,
  });

  final String address;
  final bool loadingAddress;
  final VoidCallback onLocationTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    final branding = AppBrandingController.instance.branding;

    return Row(
      children: [
        if (branding.logoUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              branding.logoUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return _BrandFallback(name: branding.shortName);
              },
            ),
          )
        else
          _BrandFallback(name: branding.shortName),

        const SizedBox(width: 12),

        Expanded(
          child: InkWell(
            onTap: onLocationTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deliver to',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          loadingAddress ? 'Loading location...' : address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        IconButton(
          onPressed: onNotificationTap,
          icon: const Icon(Icons.notifications_none),
        ),

        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              onLogoutTap();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'logout', child: Text('Logout')),
          ],
          icon: const Icon(Icons.more_vert),
        ),
      ],
    );
  }
}

class _BrandFallback extends StatelessWidget {
  const _BrandFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final letter = name.trim().isEmpty ? 'F' : name.trim()[0].toUpperCase();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
