import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/seguimiento_service.dart';
import '../widgets/collapsible_side_menu.dart';
import '../widgets/user_profile_header_action.dart';
import 'favoritos_screen.dart';
import 'sections/contratistas_section.dart';
import 'sections/contratos_section.dart';
import 'sections/entidades_section.dart';
import 'sections/equipo_juridico_section.dart';
import 'sections/inicio_section.dart';
import 'sections/oportunidades_paa_section.dart';
import 'sections/alertas_section.dart';
import 'sections/supervision_contratos_section.dart';
import '../tema/cristal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    final tieneLicitante = AuthService.hasActiveRole('empresa_licitante');
    final tieneSupervision = CollapsibleSideMenu.tieneSupervision;
    final tabs = <int>[
      if (tienePersona || (!tieneJuridico && !tieneSupervision)) ...const [
        0,
        2,
        3,
        4,
        CollapsibleSideMenu.indiceAlertas,
        7,
      ],
      if (tieneJuridico) 8,
      if (tieneLicitante) 9,
      if (tieneSupervision) CollapsibleSideMenu.indiceSupervision,
    ];
    return tabs;
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

  /// Las búsquedas viven en sus secciones (Contratos, Entidades y
  /// Contratistas): una búsqueda general lleva a Contratistas.
  void _handleUniversalSearch(String query) => _onItemTapped(4);

  Future<void> _cerrarSesion() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/portada', (route) => false);
  }

  /// Favoritos refleja lo que se marcó en otras secciones y Gestión tiene
  /// su propia sincronización periódica: se construyen de nuevo al entrar.
  /// Las demás conservan lo buscado y sus resultados (ver [SeccionesVivas]).
  static const Set<int> _seccionesQueSeRecrean = {7, 8};

  Widget _buildCurrentView(int activeIndex) {
    switch (activeIndex) {
      case 0:
        return InicioSection(
          searchController: _searchController,
          onSearchSubmitted: _handleUniversalSearch,
          onNavigateToSection: _onItemTapped,
          onLogout: _cerrarSesion,
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
      case CollapsibleSideMenu.indiceAlertas:
        return Expanded(child: AlertasSection(onIrASeccion: _onItemTapped));
      case 7:
        return Expanded(child: FavoritosScreen(onLogout: _cerrarSesion));
      case 8:
        return Expanded(child: EquipoJuridicoSection(onLogout: _cerrarSesion));
      case 9:
        return const Expanded(child: OportunidadesPaaSection());
      case CollapsibleSideMenu.indiceSupervision:
        return Expanded(
          child: SupervisionContratosSection(onLogout: _cerrarSesion),
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
        return BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded, color: Cristal.dorado),
          label: 'Inicio',
        );
      case 2:
        return BottomNavigationBarItem(
          icon: Icon(Icons.description_outlined),
          activeIcon: Icon(Icons.description_rounded, color: Cristal.dorado),
          label: 'Contratos',
        );
      case 3:
        return BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_outlined),
          activeIcon: Icon(
            Icons.account_balance_rounded,
            color: Cristal.dorado,
          ),
          label: 'Entidades',
        );
      case 4:
        return BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people_alt_rounded, color: Cristal.dorado),
          label: 'Contratistas',
        );
      case CollapsibleSideMenu.indiceAlertas:
        final nuevos = SeguimientoService.totalNuevos;
        return BottomNavigationBarItem(
          icon: Badge(
            isLabelVisible: nuevos > 0,
            label: Text(nuevos > 99 ? '99+' : '$nuevos'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
          activeIcon: Icon(Icons.notifications_rounded, color: Cristal.dorado),
          label: 'Alertas',
        );
      case 7:
        return BottomNavigationBarItem(
          icon: Icon(Icons.star_border_rounded),
          activeIcon: Icon(Icons.star_rounded, color: Cristal.dorado),
          label: 'Favoritos',
        );
      case 8:
        return BottomNavigationBarItem(
          icon: Icon(Icons.gavel_outlined),
          activeIcon: Icon(Icons.gavel_rounded, color: Cristal.dorado),
          label: 'Gestión',
        );
      case 9:
        return BottomNavigationBarItem(
          icon: Icon(Icons.event_note_outlined),
          activeIcon: Icon(Icons.event_note_rounded, color: Cristal.dorado),
          label: 'Proyección',
        );
      case CollapsibleSideMenu.indiceSupervision:
        return BottomNavigationBarItem(
          icon: Icon(Icons.assignment_turned_in_outlined),
          activeIcon: Icon(
            Icons.assignment_turned_in_rounded,
            color: Cristal.dorado,
          ),
          label: 'Supervisión',
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
      builder: (context, _, _) => ListenableBuilder(
        // El número de Alertas de la barra inferior.
        listenable: SeguimientoService.cambios,
        builder: (context, _) => _construir(context),
      ),
    );
  }

  Widget _construir(BuildContext context) {
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
        backgroundColor: Colors.transparent,
        drawer: null,
        drawerEnableOpenDragGesture: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Row(
            children: [
              Image.asset(
                Cristal.logo,
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
                  style: TextStyle(
                    color: Cristal.texto,
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
            child: Container(height: 1, color: Cristal.borde),
          ),
        ),
        body: SeccionesVivas(
          activa: activeIndex,
          construir: _buildCurrentView,
          recrear: _seccionesQueSeRecrean,
        ),
        bottomNavigationBar: mobileTabs.length >= 2
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: Cristal.vidrioSuave,
                  border: Border(top: BorderSide(color: Cristal.borde)),
                ),
                child: BottomNavigationBar(
                  currentIndex: activeBottomIdx,
                  onTap: (bottomIdx) {
                    if (bottomIdx >= 0 && bottomIdx < mobileTabs.length) {
                      _onItemTapped(mobileTabs[bottomIdx]);
                    }
                  },
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: Colors.transparent,
                  selectedItemColor: Cristal.dorado,
                  unselectedItemColor: Cristal.textoTenue,
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
                ),
              )
            : null,
      );
    } else {
      mainContent = Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
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
              child: SeccionesVivas(
                activa: activeIndex,
                construir: _buildCurrentView,
                recrear: _seccionesQueSeRecrean,
              ),
            ),
          ],
        ),
      );
    }

    return SelectionArea(child: mainContent);
  }
}
