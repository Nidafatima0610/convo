import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calls/presentation/providers/call_providers.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/extensions.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Global listener for incoming calls across any of the 5 tabs
    ref.listen(incomingCallStreamProvider, (prev, next) {
      final call = next.asData?.value;
      final activeCall = ref.read(activeCallControllerProvider);
      if (call != null && call.isRinging && !activeCall.isInCall) {
        context.push('/call/incoming', extra: call);
      }
    });

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _ConvoBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onDestinationSelected,
      ),
    );
  }
}

class _ConvoBottomNavBar extends StatelessWidget {
  const _ConvoBottomNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItemData> _items = [
    _NavItemData(
      label: AppStrings.navChats,
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
    ),
    _NavItemData(
      label: AppStrings.navNearby,
      icon: Icons.radar_rounded,
      activeIcon: Icons.radar_rounded,
      isSpecial: true,
    ),
    _NavItemData(
      label: AppStrings.navCalls,
      icon: Icons.phone_outlined,
      activeIcon: Icons.phone_rounded,
    ),
    _NavItemData(
      label: AppStrings.navDiscover,
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
    ),
    _NavItemData(
      label: AppStrings.navProfile,
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = context.viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        border: Border(
          top: BorderSide(color: context.convoColors.cardBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: bottomPadding > 0 ? bottomPadding : AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final isSelected = index == currentIndex;

          return Expanded(
            child: _NavBarItem(
              data: item,
              isSelected: isSelected,
              onTap: () => onTap(index),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.isSpecial = false,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isSpecial;
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = data.isSpecial
        ? AppColors.accent
        : context.colorScheme.primary;
    final inactiveColor = context.convoColors.textTertiary;

    return Semantics(
      label: data.label,
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderMd,
        splashColor: activeColor.withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? AppSpacing.md : AppSpacing.xs,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: AppRadius.borderPill,
                ),
                child: Icon(
                  isSelected ? data.activeIcon : data.icon,
                  size: 22,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTypography.labelSmall.copyWith(
                  color: isSelected
                      ? (context.isDark && data.isSpecial
                            ? AppColors.accentLight
                            : activeColor)
                      : inactiveColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11,
                ),
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
