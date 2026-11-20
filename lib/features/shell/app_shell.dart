import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/brand.dart';
import '../auth/domain/models.dart';
import 'account_sheet.dart';
import 'nav_destinations.dart';

/// Navigation frame shared by all three roles.
/// Phone: bottom bar. Tablet: side rail. Desktop: full sidebar.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.role,
  });

  final StatefulNavigationShell navigationShell;
  final AppRole role;

  void _select(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = navFor(role);
    final index = navigationShell.currentIndex;
    final size = context.screenSize;
    final body = navigationShell;

    if (size == ScreenSize.compact) {
      return Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          backgroundColor: p.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 20,
          title: const BrandLockup(size: 30),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: AvatarButton(),
            ),
          ],
        ),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _select,
          backgroundColor: p.surface,
          indicatorColor: p.softBg,
          destinations: [
            for (final item in items)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon, color: p.softInk),
                label: item.label,
              ),
          ],
        ),
      );
    }

    if (size == ScreenSize.medium) {
      return Scaffold(
        backgroundColor: p.bg,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: _select,
              backgroundColor: p.surface,
              indicatorColor: p.softBg,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(0, 16, 0, 12),
                child: BrandMark(size: 36),
              ),
              trailing: const Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: AvatarButton(),
                  ),
                ),
              ),
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon, color: p.softInk),
                    label: Text(item.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: p.line),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: Row(
        children: [
          _Sidebar(
            items: items,
            selected: index,
            onSelect: _select,
            role: role,
          ),
          VerticalDivider(width: 1, color: p.line),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.role,
  });

  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 264,
      color: p.surface,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: BrandLockup(size: 34),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              roleLabel(role),
              style: TextStyle(color: p.ink2, fontSize: 13),
            ),
          ),
          const SizedBox(height: 26),
          for (var i = 0; i < items.length; i++)
            _SidebarTile(
              item: items[i],
              selected: i == selected,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          Divider(color: p.line),
          const SizedBox(height: 8),
          const Row(
            children: [
              AvatarButton(),
              SizedBox(width: 10),
              Text('Account'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? p.softBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: selected ? p.softInk : p.ink2,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? p.softInk : p.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
