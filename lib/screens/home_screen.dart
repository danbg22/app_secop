import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/collapsible_side_menu.dart';
import '../widgets/user_profile_header_action.dart';
import 'favoritos_screen.dart';
import 'resultados_busqueda_screen.dart';
import 'sections/contratistas_section.dart';
import 'sections/contratos_section.dart';
import 'sections/entidades_section.dart';
import 'sections/equipo_juridico_section.dart';
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

  List<int> _resolverIndicesPermitidos() {
    return CollapsibleSideMenu.obtenerIndicesVisiblesPorRol();
  }

  List<int> _resolverMobileTabIndices() {
    final tienePersona = AuthService.hasActiveRole('persona');
    final tieneJuridico = AuthService.hasActiveRole('equipo_juridico');
    if (tienePersona && tieneJuridico) {
      return const <int>[0, 2, 3, 4, 7, 8];
    }
    if (tieneJuridico) {
      return const <int>[8];
    }
    return const <int>[0, 2, 3, 4, 7];
  }

  int _effectiveSelectedIndex() {
    final permitidos = _resolverIndicesPermitidos();
    if (permitidos.contains(_selectedIndex)) {
      return _selectedIndex;
    }
    return permitidos.first;
  }

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
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/portada', (route) => false);
  }

  Widget _buildCurrentView(int activeIndex) {
    switch (activeIndex) {
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
        return Expanded(child: FavoritosScreen(onLogout: _cerrarSesion));
      case 8:
        return Expanded(
          child: EquipoJuridicoSection(onLogout: _cerrarSesion),
        );
      default:
        return Expanded(
          child: Center(
            child: Text(
              'Pantalla ${CollapsibleSideMenu.opcionesMenu[activeIndex].titulo}',
            ),
          ),
        );
    }
  }

  BottomNavigationBarItem _buildMobileNavItem(int sectionIdx) {
    switch (sectionIdx) {
      case 0:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded, color: _dorado),
          label: 'Inicio',
        );
      case 2:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.description_outlined),
          activeIcon: Icon(Icons.description_rounded, color: _dorado),
          label: 'Contratos',
        );
      case 3:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_outlined),
          activeIcon: Icon(Icons.account_balance_rounded, color: _dorado),
          label: 'Entidades',
        );
      case 4:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people_alt_rounded, color: _dorado),
          label: 'Contratistas',
        );
      case 7:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.star_border_rounded),
          activeIcon: Icon(Icons.star_rounded, color: _dorado),
          label: 'Favoritos',
        );
      case 8:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.gavel_outlined),
          activeIcon: Icon(Icons.gavel_rounded, color: _dorado),
          label: 'Gestión',
        );
      default:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.circle_outlined),
          label: 'Sección',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AuthService.authStateVersion,
      builder: (context, _, _) {
        final isMobile = MediaQuery.sizeOf(context).width < 768;
        final activeIndex = _effectiveSelectedIndex();
        final mobileTabs = _resolverMobileTabIndices();
        final int activeBottomIdx = () {
          final found = mobileTabs.indexOf(activeIndex);
          return found >= 0 ? found : 0;
        }();

        Widget mainContent;
        if (isMobile) {
          mainContent = Scaffold(
            key: _scaffoldKey,
            backgroundColor: _crema,
            drawer: null,
            drawerEnableOpenDragGesture: false,
            appBar: AppBar(
              backgroundColor: const Color(0xFFFFFDF8),
              elevation: 0,
              scrolledUnderElevation: 1,
              automaticallyImplyLeading: false,
              titleSpacing: 16,
              title: Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 34,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      CollapsibleSideMenu.opcionesMenu[activeIndex].titulo,
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
              actions: [
                UserProfileHeaderAction(onLogout: _cerrarSesion),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: const Color(0xFFEDE6D6),
                ),
              ),
            ),
            body: Column(
              children: [_buildCurrentView(activeIndex)],
            ),
            bottomNavigationBar: mobileTabs.length >= 2
                ? BottomNavigationBar(
                    currentIndex: activeBottomIdx,
                    onTap: (bottomIdx) {
                      if (bottomIdx >= 0 && bottomIdx < mobileTabs.length) {
                        _onItemTapped(mobileTabs[bottomIdx]);
                      }
                    },
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: Colors.white,
                    selectedItemColor: _azulOscuro,
                    unselectedItemColor: const Color(0xFF64748B),
                    selectedLabelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                    items: [
                      for (final idx in mobileTabs) _buildMobileNavItem(idx),
                    ],
                  )
                : null,
          );
        } else {
          mainContent = Scaffold(
            key: _scaffoldKey,
            backgroundColor: _crema,
            body: Row(
              children: [
                CollapsibleSideMenu(
                  selectedIndex: activeIndex,
                  isCollapsed: _isSidebarCollapsed,
                  onItemSelected: _onItemTapped,
                  onToggleCollapse: _toggleSidebar,
                  onLogout: _cerrarSesion,
                ),
                Expanded(
                  child: Column(
                    children: [_buildCurrentView(activeIndex)],
                  ),
                ),
              ],
            ),
          );
        }

        return SelectionArea(child: mainContent);
      },
    );
  }
}
