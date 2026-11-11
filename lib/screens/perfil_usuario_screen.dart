import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../utils/avatar_picker.dart';
import '../widgets/admin_verification_banner.dart';
import '../widgets/collapsible_side_menu.dart';
import '../widgets/route_security_guard.dart';
import 'home_screen.dart';
import '../tema/cristal.dart';

class PerfilUsuarioScreen extends StatefulWidget {
  const PerfilUsuarioScreen({super.key});

  @override
  State<PerfilUsuarioScreen> createState() => _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends State<PerfilUsuarioScreen> {
  static const List<int> _mobileTabIndices = <int>[0, 2, 3, 4, 7];

  static const List<String> _paisesDisponibles = <String>[
    'Colombia',
    'Argentina',
    'Chile',
    'Ecuador',
    'España',
    'Estados Unidos',
    'México',
    'Panamá',
    'Perú',
    'Otro',
  ];

  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _emailController = TextEditingController();
  final _documentoController = TextEditingController();
  final _telefonoController = TextEditingController();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _pais = 'Colombia';
  bool _isSidebarCollapsed = false;

  bool _isLoadingProfile = true;
  bool _isSavingProfile = false;
  bool _isChangingPassword = false;

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _documentoController.dispose();
    _telefonoController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    try {
      final data = await AuthService.getActiveUserProfile();
      if (!mounted) return;

      final loadedPais = (data['pais'] ?? 'Colombia').toString().trim();
      final documentoRaw = (data['documento'] ?? '').toString().trim();
      final emailRaw = (data['email'] ?? '').toString().trim();

      setState(() {
        _nombresController.text = (data['nombres'] ?? '').toString();
        _apellidosController.text = (data['apellidos'] ?? '').toString();
        _emailController.text = emailRaw.isNotEmpty
            ? emailRaw
            : 'Sin correo registrado';
        _documentoController.text = documentoRaw.isNotEmpty
            ? documentoRaw
            : 'No registrado';
        _telefonoController.text = (data['telefono'] ?? '').toString();
        _pais = _paisesDisponibles.contains(loadedPais)
            ? loadedPais
            : 'Colombia';
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
    }
  }

  void _regresar() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _navegarASeccion(int sectionIndex) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            RouteSecurityGuard(child: HomeScreen(initialIndex: sectionIndex)),
      ),
      (route) => false,
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

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: esError
              ? const Color(0xFFDC2626)
              : const Color(0xFF15803D),
          content: Row(
            children: [
              Icon(
                esError ? Icons.error_outline : Icons.check_circle_outline,
                color: Cristal.texto,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(mensaje)),
            ],
          ),
        ),
      );
  }

  Future<void> _guardarDatosPerfil() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _isSavingProfile = true);
    try {
      final sincronizado = await AuthService.updateActiveUserProfile(
        nombres: _nombresController.text,
        apellidos: _apellidosController.text,
        telefono: _telefonoController.text,
        pais: _pais,
      );
      _mostrarMensaje(
        sincronizado ? 'Información personal actualizada correctamente.' : 'Los cambios se guardaron solo en este dispositivo: no fue posible sincronizarlos. Inténtalo de nuevo con conexión.',
        esError: !sincronizado,
      );
      if (mounted) setState(() {});
    } catch (e) {
      _mostrarMensaje(
        e.toString().replaceFirst('Exception: ', ''),
        esError: true,
      );
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _cambiarContrasena() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isChangingPassword = true);
    try {
      await AuthService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _mostrarMensaje('Tu contraseña ha sido actualizada exitosamente.');
    } catch (e) {
      _mostrarMensaje(
        e.toString().replaceFirst('Exception: ', ''),
        esError: true,
      );
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _abrirDialogoEditarFoto() async {
    final resultMessage = await mostrarDialogoCristal<String>(
      context: context,
      builder: (_) => const _EditAvatarDialog(),
    );
    if (resultMessage != null && resultMessage.isNotEmpty) {
      _mostrarMensaje(resultMessage);
    }
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Cristal.vidrio,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Cristal.borde),
    );
  }

  InputDecoration _editableDecoration({
    required String hint,
    required IconData icon,
    Color iconColor = Cristal.textoMedio,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Cristal.textoTenue,
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, size: 19, color: iconColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Cristal.campo,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Cristal.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Cristal.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Cristal.acentoClaro, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Cristal.rojo),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Cristal.rojo, width: 1.4),
      ),
    );
  }

  InputDecoration _lockedDecoration({required IconData icon}) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 19, color: Cristal.textoMedio),
      suffixIcon: const Icon(
        Icons.lock_outline_rounded,
        size: 18,
        color: Cristal.textoSuave,
      ),
      filled: true,
      fillColor: Cristal.campo,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Cristal.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Cristal.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Cristal.borde),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Cristal.texto,
          fontSize: 12.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildHeroBanner(bool isMobile) {
    final double bannerHeight = isMobile ? 148 : 170;

    return SizedBox(
      height: bannerHeight,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const FotoAmbiente.cabecera(),
            Positioned(
              top: isMobile ? 16 : 24,
              left: isMobile ? 14 : 24,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      hoverDuration: Cristal.micro,
                      onTap: _regresar,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Cristal.texto,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Mi perfil',
                    style: TextStyle(
                      color: Cristal.texto,
                      fontSize: isMobile ? 21 : 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSummaryCard(bool isMobile) {
    return ValueListenableBuilder<int>(
      valueListenable: AuthService.authStateVersion,
      builder: (context, _, _) {
        final fullName = AuthService.getActiveUserDisplayName();
        final activeEmail = AuthService.getActiveUserEmail();
        final emailText = activeEmail.isNotEmpty
            ? activeEmail
            : _emailController.text;
        final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';
        final avatarProvider = AuthService.getActiveUserAvatarImageProvider();

        final editPhotoButton = Material(
          color: Cristal.vidrioSuave,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            hoverDuration: Cristal.micro,
            onTap: _abrirDialogoEditarFoto,
            borderRadius: BorderRadius.circular(22),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9.5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 15.5, color: Cristal.texto),
                  SizedBox(width: 7),
                  Text(
                    'Editar foto',
                    style: TextStyle(
                      color: Cristal.texto,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final avatarAndInfo = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: isMobile ? 34 : 44,
              backgroundColor: Cristal.avatar,
              foregroundColor: Cristal.texto,
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? Text(
                      initial,
                      style: TextStyle(
                        color: Cristal.texto,
                        fontSize: isMobile ? 28 : 36,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: isMobile ? 16 : 22),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: Cristal.dorado,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Cristal.texto,
                      fontSize: isMobile ? 21 : 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emailText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Cristal.textoMedio,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5.5,
                        ),
                        decoration: BoxDecoration(
                          color: Cristal.doradoVidrio,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              size: 15,
                              color: Cristal.texto,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Roles activos: ${AuthService.getActiveUserRoleDisplayLabel()}',
                                style: const TextStyle(
                                  color: Cristal.texto,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        hoverDuration: Cristal.micro,
                        onTap: () => Navigator.of(context).pushNamed('/planes'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 5.5,
                          ),
                          decoration: BoxDecoration(
                            color: Cristal.azulVidrio,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Cristal.acentoBorde),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_moderator_outlined,
                                size: 14,
                                color: Cristal.acentoClaro,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Acumular rol (+)',
                                style: TextStyle(
                                  color: Cristal.acentoClaro,
                                  fontSize: 11.8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 18 : 28,
            vertical: isMobile ? 18 : 20,
          ),
          decoration: _cardDecoration(),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatarAndInfo,
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: editPhotoButton,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: avatarAndInfo),
                    const SizedBox(width: 16),
                    editPhotoButton,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildPersonalInfoCard(bool isMobile) {
    final nombresField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Nombres'),
        TextFormField(
          controller: _nombresController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
            color: Cristal.texto,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: _editableDecoration(
            hint: 'Nombres',
            icon: Icons.person_outline_rounded,
          ),
          validator: (val) => (val == null || val.trim().isEmpty)
              ? 'Ingresa tus nombres.'
              : null,
        ),
      ],
    );

    final apellidosField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Apellidos'),
        TextFormField(
          controller: _apellidosController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
            color: Cristal.texto,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: _editableDecoration(
            hint: 'Apellidos',
            icon: Icons.person_outline_rounded,
          ),
        ),
      ],
    );

    final paisField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('País de residencia'),
        DropdownButtonFormField<String>(
          key: ValueKey<String>(_pais),
          initialValue: _pais,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Cristal.texto,
            size: 20,
          ),
          style: const TextStyle(
            color: Cristal.texto,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: _editableDecoration(
            hint: 'País de residencia',
            icon: Icons.public_rounded,
            iconColor: Cristal.texto,
          ),
          items: [
            for (final p in _paisesDisponibles)
              DropdownMenuItem<String>(value: p, child: Text(p)),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _pais = val);
          },
        ),
      ],
    );

    final telefonoField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Número de teléfono'),
        TextFormField(
          controller: _telefonoController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(
            color: Cristal.texto,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: _editableDecoration(
            hint: 'Número de teléfono (opcional)',
            icon: Icons.phone_outlined,
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: _cardDecoration(),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Cristal.vidrioSuave,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Cristal.acentoClaro,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Información personal',
                        style: TextStyle(
                          color: Cristal.texto,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Gestiona tu información básica.',
                        style: TextStyle(
                          color: Cristal.textoSuave,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Fila 1: Nombres | Apellidos
            if (isMobile) ...[
              nombresField,
              const SizedBox(height: 16),
              apellidosField,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: nombresField),
                  const SizedBox(width: 16),
                  Expanded(child: apellidosField),
                ],
              ),
            const SizedBox(height: 18),

            // Fila 2: Correo electrónico (Bloqueado con readOnly: true)
            _buildFieldLabel('Correo electrónico'),
            TextField(
              controller: _emailController,
              readOnly: true,
              mouseCursor: SystemMouseCursors.basic,
              style: const TextStyle(
                color: Cristal.textoSuave,
                fontSize: 13.8,
                fontWeight: FontWeight.w500,
              ),
              decoration: _lockedDecoration(icon: Icons.mail_outline_rounded),
            ),
            const SizedBox(height: 6),
            const Text(
              'El correo electrónico no se puede modificar.',
              style: TextStyle(color: Cristal.textoSuave, fontSize: 11.8),
            ),
            const SizedBox(height: 18),

            // Fila 3: País de residencia | Número de teléfono
            if (isMobile) ...[
              paisField,
              const SizedBox(height: 16),
              telefonoField,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: paisField),
                  const SizedBox(width: 16),
                  Expanded(child: telefonoField),
                ],
              ),
            const SizedBox(height: 18),

            // Fila 4: Número de documento / cédula (Bloqueado con readOnly: true)
            _buildFieldLabel('Número de documento / cédula'),
            TextField(
              controller: _documentoController,
              readOnly: true,
              mouseCursor: SystemMouseCursors.basic,
              style: const TextStyle(
                color: Cristal.textoSuave,
                fontSize: 13.8,
                fontWeight: FontWeight.w500,
              ),
              decoration: _lockedDecoration(icon: Icons.subtitles_outlined),
            ),
            const SizedBox(height: 6),
            const Text(
              'Para actualizar este dato, contacta al soporte de la plataforma.',
              style: TextStyle(color: Cristal.textoSuave, fontSize: 11.8),
            ),
            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _isSavingProfile ? null : _guardarDatosPerfil,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Cristal.acento,
                    foregroundColor: Cristal.texto,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: _isSavingProfile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Cristal.texto,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text(
                    'Guardar cambios',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: _cardDecoration(),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Cristal.vidrioSuave,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Cristal.acentoClaro,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cambio de contraseña',
                        style: TextStyle(
                          color: Cristal.texto,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Actualiza tu clave de acceso.',
                        style: TextStyle(
                          color: Cristal.textoSuave,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildFieldLabel('Contraseña actual'),
            TextFormField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              style: const TextStyle(color: Cristal.texto, fontSize: 14),
              decoration: _editableDecoration(
                hint: 'Ingresa tu contraseña actual',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  tooltip: _showCurrentPassword ? 'Ocultar' : 'Mostrar',
                  onPressed: () => setState(
                    () => _showCurrentPassword = !_showCurrentPassword,
                  ),
                  icon: Icon(
                    _showCurrentPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: Cristal.textoSuave,
                  ),
                ),
              ),
              validator: (val) => (val == null || val.isEmpty)
                  ? 'Ingresa tu contraseña actual.'
                  : null,
            ),
            const SizedBox(height: 18),

            _buildFieldLabel('Nueva contraseña'),
            TextFormField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              style: const TextStyle(color: Cristal.texto, fontSize: 14),
              decoration: _editableDecoration(
                hint: 'Mín. 8 caracteres, mayúscula y número',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  tooltip: _showNewPassword ? 'Ocultar' : 'Mostrar',
                  onPressed: () =>
                      setState(() => _showNewPassword = !_showNewPassword),
                  icon: Icon(
                    _showNewPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: Cristal.textoSuave,
                  ),
                ),
              ),
              validator: (val) {
                final policyError = SecurityService.validateStrongPassword(val);
                if (policyError != null) return policyError;
                if (val == _currentPasswordController.text) {
                  return 'Elige una clave distinta a la actual.';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            _buildFieldLabel('Confirmar nueva contraseña'),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              style: const TextStyle(color: Cristal.texto, fontSize: 14),
              decoration: _editableDecoration(
                hint: 'Repite la nueva contraseña',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  tooltip: _showConfirmPassword ? 'Ocultar' : 'Mostrar',
                  onPressed: () => setState(
                    () => _showConfirmPassword = !_showConfirmPassword,
                  ),
                  icon: Icon(
                    _showConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: Cristal.textoSuave,
                  ),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Confirma la nueva contraseña.';
                }
                if (val != _newPasswordController.text) {
                  return 'Las contraseñas no coinciden.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isChangingPassword ? null : _cambiarContrasena,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Cristal.acento,
                  foregroundColor: Cristal.texto,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: _isChangingPassword
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Cristal.texto,
                        ),
                      )
                    : const Icon(Icons.vpn_key_outlined, size: 18),
                label: const Text(
                  'Actualizar contraseña',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPane({required bool isMobile}) {
    if (_isLoadingProfile) {
      return const Center(
        child: CircularProgressIndicator(color: Cristal.acentoClaro),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double paneW = constraints.maxWidth;
        final bool twoColumns = paneW >= 860;
        final double horizontalPad = isMobile ? 16 : 26;

        return SingleChildScrollView(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: isMobile ? 148 : 170,
                child: _buildHeroBanner(isMobile),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  isMobile ? 84 : 102,
                  horizontalPad,
                  34,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1260),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AdminVerificationBanner(),
                        _buildUserSummaryCard(isMobile),
                        const SizedBox(height: 22),
                        if (twoColumns)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 59,
                                child: _buildPersonalInfoCard(false),
                              ),
                              const SizedBox(width: 22),
                              Expanded(
                                flex: 41,
                                child: _buildChangePasswordCard(false),
                              ),
                            ],
                          )
                        else ...[
                          _buildPersonalInfoCard(isMobile),
                          const SizedBox(height: 20),
                          _buildChangePasswordCard(isMobile),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.sizeOf(context).width < 768;

    return SelectionArea(
      child: isMobile
          ? Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(child: _buildMainPane(isMobile: true)),
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: 0,
                onTap: (bottomIdx) {
                  if (bottomIdx >= 0 && bottomIdx < _mobileTabIndices.length) {
                    _navegarASeccion(_mobileTabIndices[bottomIdx]);
                  }
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                selectedItemColor: Cristal.dorado,
                unselectedItemColor: Cristal.textoTenue,
                selectedLabelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    label: 'Inicio',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.description_outlined),
                    label: 'Contratos',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.account_balance_outlined),
                    label: 'Entidades',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.people_outline),
                    label: 'Contratistas',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.star_border_rounded),
                    label: 'Favoritos',
                  ),
                ],
              ),
            )
          : Scaffold(
              backgroundColor: Colors.transparent,
              body: Row(
                // El contenido ocupa todo el alto: si es corto queda arriba, no
                // centrado.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CollapsibleSideMenu(
                    selectedIndex: -1,
                    isCollapsed: _isSidebarCollapsed,
                    onItemSelected: _navegarASeccion,
                    onToggleCollapse: () => setState(
                      () => _isSidebarCollapsed = !_isSidebarCollapsed,
                    ),
                    onLogout: _cerrarSesion,
                  ),
                  Expanded(child: _buildMainPane(isMobile: false)),
                ],
              ),
            ),
    );
  }
}

class _EditAvatarDialog extends StatefulWidget {
  const _EditAvatarDialog();

  @override
  State<_EditAvatarDialog> createState() => _EditAvatarDialogState();
}

class _EditAvatarDialogState extends State<_EditAvatarDialog> {
  late final TextEditingController _urlController;
  late final String _currentSource;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentSource = AuthService.getActiveUserPhotoSource() ?? '';
    _urlController = TextEditingController(
      text: _currentSource.startsWith('http') ? _currentSource : '',
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _subirDesdeEquipo() async {
    setState(() {
      _errorText = null;
      _isSaving = true;
    });
    try {
      final pickedDataUrl = await pickImageAsDataUrl();
      if (pickedDataUrl == null || pickedDataUrl.isEmpty) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
      if (pickedDataUrl == '__INVALID_IMAGE_SECURITY__') {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
          _errorText =
              'Solo se permiten imágenes PNG, JPG o WEBP menores a 1.5 MB.';
        });
        return;
      }
      await AuthService.updateActiveUserPhoto(pickedDataUrl);
      if (!mounted) return;
      Navigator.of(context).pop('Foto de perfil actualizada.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = SecurityService.sanitizeErrorMessage(
          error.toString().replaceFirst('Exception: ', ''),
          fallback: 'No se pudo validar la imagen seleccionada.',
        );
      });
    }
  }

  Future<void> _guardarUrl() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isNotEmpty &&
        SecurityService.validateSafeExternalImageUrl(rawUrl) == null) {
      setState(() {
        _errorText =
            'Ingresa un enlace público seguro con https:// (PNG, JPG o WEBP).';
      });
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });
    try {
      await AuthService.updateActiveUserPhoto(rawUrl.isEmpty ? null : rawUrl);
      if (!mounted) return;
      Navigator.of(context).pop('Foto de perfil actualizada.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = SecurityService.sanitizeErrorMessage(
          error.toString().replaceFirst('Exception: ', ''),
        );
      });
    }
  }

  Future<void> _quitarFoto() async {
    setState(() {
      _errorText = null;
      _isSaving = true;
    });
    await AuthService.updateActiveUserPhoto(null);
    if (!mounted) return;
    Navigator.of(context).pop('Se restauró el avatar inicial.');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Cristal.flotante,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Cristal.bordeFuerte),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Cristal.vidrioSuave,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Cristal.acentoClaro,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editar foto de perfil',
                          style: TextStyle(
                            color: Cristal.texto,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Sube una imagen o ingresa un enlace directo.',
                          style: TextStyle(
                            color: Cristal.textoSuave,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Cristal.textoSuave,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (supportsDeviceImagePicker) ...[
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _subirDesdeEquipo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Cristal.texto,
                    backgroundColor: Cristal.vidrioSuave,
                    side: const BorderSide(color: Cristal.borde),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 19),
                  label: const Text(
                    'Seleccionar imagen desde mi equipo',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'O pega la URL de una imagen',
                style: TextStyle(
                  color: Cristal.texto,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                style: const TextStyle(color: Cristal.texto, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'https://ejemplo.com/mi-foto.jpg',
                  hintStyle: const TextStyle(
                    color: Cristal.textoTenue,
                    fontSize: 13.5,
                  ),
                  errorText: _errorText,
                  prefixIcon: const Icon(
                    Icons.link_rounded,
                    size: 19,
                    color: Cristal.textoMedio,
                  ),
                  filled: true,
                  fillColor: Cristal.campo,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Cristal.borde),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Cristal.borde),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Cristal.acentoClaro,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_currentSource.isNotEmpty)
                    TextButton(
                      onPressed: _isSaving ? null : _quitarFoto,
                      style: TextButton.styleFrom(
                        foregroundColor: Cristal.rojo,
                      ),
                      child: const Text(
                        'Quitar foto',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Cristal.textoSuave,
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _guardarUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Cristal.acento,
                      foregroundColor: Cristal.texto,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Text(
                      'Guardar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
