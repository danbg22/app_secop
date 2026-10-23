import 'package:flutter/material.dart';

import '../services/auth_service.dart';
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
  static const Color _azulOscuro = Color(0xFF1A2B4C);
  static const Color _dorado = Color(0xFFF5B82E);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  late int _selectedIndex;
  bool _isSidebarCollapsed = false;

  static const List<int> _mobileTabIndices = [0, 2, 3, 4, 7];

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
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
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
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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
        return ContratistasSection(onLogout: _cerrarSesion);
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

  int get _activeMobileBottomIndex {
    final idx = _mobileTabIndices.indexOf(_selectedIndex);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: _crema,
        drawer: Drawer(
          width: 256,
          backgroundColor: const Color(0xFFFFFDF8),
          child: SafeArea(
            child: CollapsibleSideMenu(
              selectedIndex: _selectedIndex,
              isCollapsed: false,
              onItemSelected: _onItemTapped,
              onToggleCollapse: () => Navigator.of(context).pop(),
              onLogout: _cerrarSesion,
            ),
          ),
        ),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFDF8),
          elevation: 0,
          scrolledUnderElevation: 1,
          leading: IconButton(
            tooltip: 'Abrir menú',
            icon: const Icon(Icons.menu_rounded, color: _azulOscuro),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 36,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  CollapsibleSideMenu.opcionesMenu[_selectedIndex].titulo,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _azulOscuro,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: const Color(0xFFEDE6D6),
            ),
          ),
        ),
        body: Column(
          children: [
            if (_selectedIndex != 0 &&
                _selectedIndex != 2 &&
                _selectedIndex != 3 &&
                _selectedIndex != 4)
              DashboardTopBar(
                searchController: _searchController,
                onSearchSubmitted: _handleUniversalSearch,
                onLogout: _cerrarSesion,
              ),
            _buildCurrentView(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _activeMobileBottomIndex,
          onTap: (bottomIdx) {
            if (bottomIdx >= 0 && bottomIdx < _mobileTabIndices.length) {
              _onItemTapped(_mobileTabIndices[bottomIdx]);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: _azulOscuro,
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded, color: _dorado),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              activeIcon: Icon(Icons.description_rounded, color: _dorado),
              label: 'Contratos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_outlined),
              activeIcon: Icon(Icons.account_balance_rounded, color: _dorado),
              label: 'Entidades',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people_alt_rounded, color: _dorado),
              label: 'Contratistas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star_border_rounded),
              activeIcon: Icon(Icons.star_rounded, color: _dorado),
              label: 'Favoritos',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
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
                    _selectedIndex == 3 ||
                    _selectedIndex == 4)
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
