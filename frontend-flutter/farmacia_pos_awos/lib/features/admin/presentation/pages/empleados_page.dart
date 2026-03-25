import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../data/repositories/empleados_repository.dart';
import '../../domain/entities/empleado_perfil.dart';

/// Pantalla de gestión de empleados en tiempo real con Firestore.
class EmpleadosPage extends StatefulWidget {
  /// Constructor por defecto.
  const EmpleadosPage({super.key});

  @override
  State<EmpleadosPage> createState() => _EmpleadosPageState();
}

class _EmpleadosPageState extends State<EmpleadosPage> {
  final EmpleadosRepository _empleadosRepository = sl<EmpleadosRepository>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Empleados')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o correo...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EmpleadoPerfil>>(
              stream: _empleadosRepository.streamEmpleados(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<EmpleadoPerfil>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final List<EmpleadoPerfil> todos =
                        snapshot.data ?? <EmpleadoPerfil>[];

                    final String searchLower = _searchController.text
                        .toLowerCase();
                    final List<EmpleadoPerfil> filtrados = todos
                        .where(
                          (EmpleadoPerfil e) =>
                              e.nombre.toLowerCase().contains(searchLower) ||
                              e.email.toLowerCase().contains(searchLower),
                        )
                        .toList(growable: false);

                    if (filtrados.isEmpty) {
                      return const Center(child: Text('No hay coincidencias.'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        final EmpleadoPerfil empleado = filtrados[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                CircleAvatar(
                                  child: Text(
                                    empleado.nombre.isNotEmpty
                                        ? empleado.nombre
                                              .substring(0, 1)
                                              .toUpperCase()
                                        : '?',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        empleado.nombre,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        empleado.email,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(height: 8),
                                      Chip(
                                        label: Text(
                                          empleado.role.toUpperCase(),
                                        ),
                                      ),
                                      if (empleado.estado == 'pendiente')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Chip(
                                            label: const Text('Pendiente'),
                                            backgroundColor:
                                                Colors.orange.shade100,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Switch(
                                      value: empleado.activo,
                                      onChanged: (bool value) =>
                                          _mostrarModalEdicion(empleado, value),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _confirmarEliminacion(empleado.uid),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarModalEdicion(
    EmpleadoPerfil empleado,
    bool nuevoEstadoActivo,
  ) async {
    String rolSeleccionado = empleado.role;
    bool activoSeleccionado = nuevoEstadoActivo;
    final Map<String, bool> permisosSeleccionados = permisosDisponibles
        .asMap()
        .map(
          (_, String permiso) => MapEntry<String, bool>(
            permiso,
            empleado.permisos.contains(permiso),
          ),
        );

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext modalContext, StateSetter setModalState) {
            return AlertDialog(
              title: const Text('Editar empleado'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        empleado.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        empleado.email,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: rolSeleccionado,
                        decoration: const InputDecoration(labelText: 'Rol'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                            value: 'sin_rol',
                            child: Text('Sin rol'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'vendedor',
                            child: Text('Vendedor'),
                          ),
                        ],
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }
                          setModalState(() {
                            rolSeleccionado = value;

                            // Presets automáticos por rol con edición manual posterior.
                            if (value == 'admin') {
                              for (final String permiso
                                  in permisosDisponibles) {
                                permisosSeleccionados[permiso] = true;
                              }
                            } else if (value == 'vendedor') {
                              for (final String permiso
                                  in permisosDisponibles) {
                                permisosSeleccionados[permiso] =
                                    permiso == 'crear_venta' ||
                                    permiso == 'ver_inventario';
                              }
                            } else {
                              for (final String permiso
                                  in permisosDisponibles) {
                                permisosSeleccionados[permiso] = false;
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Permisos:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ...permisosSeleccionados.entries.map((
                        MapEntry<String, bool> entry,
                      ) {
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_formatPermiso(entry.key)),
                          value: entry.value,
                          onChanged: (bool? value) {
                            if (value == null) {
                              return;
                            }
                            setModalState(() {
                              permisosSeleccionados[entry.key] = value;
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activo'),
                        value: activoSeleccionado,
                        onChanged: (bool value) {
                          setModalState(() {
                            activoSeleccionado = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final List<String> permisosActualizados =
                          permisosSeleccionados.entries
                              .where((MapEntry<String, bool> e) => e.value)
                              .map((MapEntry<String, bool> e) => e.key)
                              .toList(growable: false);

                      final NavigatorState nav = Navigator.of(dialogContext);
                      final ScaffoldMessengerState msg = ScaffoldMessenger.of(
                        context,
                      );

                      await _empleadosRepository.actualizarPerfil(
                        uid: empleado.uid,
                        role: rolSeleccionado,
                        permisos: permisosActualizados,
                        activo: activoSeleccionado,
                      );

                      if (!mounted) {
                        return;
                      }

                      nav.pop();
                      msg.showSnackBar(
                        const SnackBar(
                          content: Text('Empleado actualizado correctamente.'),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al actualizar: $e')),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarEliminacion(String uid) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar empleado'),
          content: const Text(
            '¿Estás seguro de que deseas eliminar este empleado? '
            'Esta acción no se puede deshacer.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      await _empleadosRepository.eliminarPerfil(uid: uid);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Empleado eliminado correctamente.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  String _formatPermiso(String permiso) {
    return permiso
        .replaceAll('_', ' ')
        .split(' ')
        .map((String word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
