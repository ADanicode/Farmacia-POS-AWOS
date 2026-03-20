import 'package:flutter/material.dart';

/// Un widget de layout adaptable usado por el POS de farmacia.
///
/// Retorna `mobileBody` para pantallas de ancho menor a 800.
/// Retorna `desktopBody` para pantallas de ancho mayor o igual a 800.
class ResponsiveLayout extends StatelessWidget {
  /// Contenido que se muestra en pantallas móviles.
  final Widget mobileBody;

  /// Contenido que se muestra en pantallas de escritorio.
  final Widget desktopBody;

  /// Crea un ResponsiveLayout con cuerpos para móvil y escritorio.
  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    required this.desktopBody,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return mobileBody;
        }
        return desktopBody;
      },
    );
  }
}
