import 'package:flutter/material.dart';

import 'custom_app_bar.dart';

/// Adaptador de barra superior del Dashboard que delega al componente único
/// [CustomAppBar] para garantizar consistencia visual en todas las pantallas.
class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.searchController,
    required this.onSearchSubmitted,
    required this.onLogout,
    this.transparent = false,
    this.showSearch = true,
    this.showUserActions = true,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onLogout;
  final bool transparent;
  final bool showSearch;
  final bool showUserActions;

  @override
  Widget build(BuildContext context) {
    return CustomAppBar(
      searchController: searchController,
      onSearchSubmitted: onSearchSubmitted,
      onLogout: onLogout,
      transparent: transparent,
      showSearch: showSearch,
      showUserActions: showUserActions,
    );
  }
}
