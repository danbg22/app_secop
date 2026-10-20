import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/collapsible_side_menu.dart';
import '../widgets/dashboard_top_bar.dart';
import 'favoritos_screen.dart';
import 'resultados_busqueda_screen.dart';
import 'sections/contratistas_section.dart';
import 'sections/contratos_section.dart';
import 'sections/entidades_section.dart';
import 'sections/estadisticas_section.dart';
import 'sections/explorar_section.dart';
import 'sections/inicio_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _crema = Color(0xFFFFF8EE);

  final TextEditingController _searchController = TextEditingController();
  late int _selectedIndex;
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _toggleSidebar() {
    setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
  }

  void _handleUniversalSearch(String query) {
    final searchQuery = query.trim();
    if (searchQuery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe algo para buscar.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadosBusquedaScreen(query: searchQuery),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('usuarioActivo');
    await prefs.remove('userEmail');
  }

  Widget _buildCurrentView() {
    switch (_selectedIndex) {
      case 0:
        return InicioSection(
          searchController: _searchController,
          onSearchSubmitted: _handleUniversalSearch,
          onNavigateToSection: _onItemTapped,
          onLogout: _cerrarSesion,
        );
      case 1:
        return ExplorarSection(
          searchController: _searchController,
          onSearchSubmitted: _handleUniversalSearch,
          onNavigateToSection: _onItemTapped,
        );
      case 2:
        return ContratosSection(
          topSearchController: _searchController,
          onTopSearchSubmitted: _handleUniversalSearch,
          onLogout: _cerrarSesion,
        );
      case 3:
        return const EntidadesSection();
      case 4:
        return const ContratistasSection();
      case 5:
        return const EstadisticasSection();
      case 7:
        return const Expanded(child: FavoritosScreen());
      default:
        return Expanded(
          child: Center(
            child: Text(
              'Pantalla ${CollapsibleSideMenu.opcionesMenu[_selectedIndex].titulo}',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _crema,
      body: Row(
        children: [
          CollapsibleSideMenu(
            selectedIndex: _selectedIndex,
            isCollapsed: _isSidebarCollapsed,
            onItemSelected: _onItemTapped,
            onToggleCollapse: _toggleSidebar,
            onLogout: _cerrarSesion,
          ),
          Expanded(
            child: Column(
              children: [
                if (_selectedIndex == 0 ||
                    _selectedIndex == 2 ||
                    _selectedIndex == 3)
                  _buildCurrentView()
                else ...[
                  DashboardTopBar(
                    searchController: _searchController,
                    onSearchSubmitted: _handleUniversalSearch,
                    onLogout: _cerrarSesion,
                  ),
                  _buildCurrentView(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
