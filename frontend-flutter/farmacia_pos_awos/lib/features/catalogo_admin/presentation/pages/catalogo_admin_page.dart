import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../domain/entities/categoria_catalogo.dart';
import '../../domain/entities/medicamento_catalogo.dart';
import '../../domain/entities/proveedor_catalogo.dart';
import '../cubit/catalogo_admin_cubit.dart';
import '../cubit/catalogo_admin_state.dart';

/// Pantalla de administración del catálogo de medicamentos.
///
/// Accesible únicamente para el rol Administrador; verificado por [RouteGuards]
/// en [AppRouter] antes de construir esta pantalla.
/// Organiza la gestión de [Medicamentos], [Categorías] y [Proveedores]
/// en tres pestañas independientes conectadas al microservicio Python.
class CatalogoAdminPage extends StatelessWidget {
  /// Constructor por defecto.
  const CatalogoAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CatalogoAdminCubit>(
      create: (_) => sl<CatalogoAdminCubit>()..cargarTodo(),
      child: const _CatalogoView(),
    );
  }
}

// ── Vista principal con TabController ────────────────────────────────────────

class _CatalogoView extends StatefulWidget {
  const _CatalogoView();

  @override
  State<_CatalogoView> createState() => _CatalogoViewState();
}

class _CatalogoViewState extends State<_CatalogoView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<String> _fabLabels = <String>[
    'Nuevo Medicamento',
    'Nueva Categoría',
    'Nuevo Proveedor',
  ];

  static const List<IconData> _fabIcons = <IconData>[
    Icons.medication,
    Icons.category,
    Icons.business,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  // ── FAB dispatcher ───────────────────────────────────────────────────────

  void _onFabPressed(BuildContext ctx) {
    switch (_tabController.index) {
      case 0:
        _abrirDialogoMedicamento(ctx);
      case 1:
        _abrirDialogoCategoria(ctx);
      case 2:
        _abrirDialogoProveedor(ctx);
    }
  }

  // ── Dialog: Nuevo Medicamento ────────────────────────────────────────────

  void _abrirDialogoMedicamento(BuildContext context) {
    final CatalogoAdminCubit cubit = context.read<CatalogoAdminCubit>();
    final CatalogoAdminState estadoActual = cubit.state;

    if (estadoActual.categorias.isEmpty || estadoActual.proveedores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registra al menos una categoría y un proveedor antes de agregar medicamentos.',
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogCtx) {
        return BlocProvider<CatalogoAdminCubit>.value(
          value: cubit,
          child: _MedicamentoDialog(
            categorias: estadoActual.categorias,
            proveedores: estadoActual.proveedores,
          ),
        );
      },
    );
  }

  // ── Dialog: Nueva Categoría ──────────────────────────────────────────────

  void _abrirDialogoCategoria(BuildContext context) {
    final CatalogoAdminCubit cubit = context.read<CatalogoAdminCubit>();

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogCtx) {
        return BlocProvider<CatalogoAdminCubit>.value(
          value: cubit,
          child: const _CategoriaDialog(),
        );
      },
    );
  }

  // ── Dialog: Nuevo Proveedor ──────────────────────────────────────────────

  void _abrirDialogoProveedor(BuildContext context) {
    final CatalogoAdminCubit cubit = context.read<CatalogoAdminCubit>();

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogCtx) {
        return BlocProvider<CatalogoAdminCubit>.value(
          value: cubit,
          child: const _ProveedorDialog(),
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<CatalogoAdminCubit, CatalogoAdminState>(
      listener: (BuildContext ctx, CatalogoAdminState state) {
        if (state.status == CatalogoAdminStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración de Catálogo'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const <Widget>[
              Tab(icon: Icon(Icons.medication), text: 'Medicamentos'),
              Tab(icon: Icon(Icons.category), text: 'Categorías'),
              Tab(icon: Icon(Icons.business), text: 'Proveedores'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const <Widget>[
            _MedicamentosTab(),
            _CategoriasTab(),
            _ProveedoresTab(),
          ],
        ),
        floatingActionButton:
            BlocBuilder<CatalogoAdminCubit, CatalogoAdminState>(
              builder: (BuildContext ctx, CatalogoAdminState state) {
                final bool saving = state.status == CatalogoAdminStatus.saving;
                final int i = _tabController.index;
                return FloatingActionButton.extended(
                  onPressed: saving ? null : () => _onFabPressed(ctx),
                  icon: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Icon(_fabIcons[i]),
                  label: Text(_fabLabels[i]),
                );
              },
            ),
      ),
    );
  }
}

// ── Tab: Medicamentos ─────────────────────────────────────────────────────────

class _MedicamentosTab extends StatelessWidget {
  const _MedicamentosTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogoAdminCubit, CatalogoAdminState>(
      builder: (BuildContext context, CatalogoAdminState state) {
        if (state.status == CatalogoAdminStatus.loading ||
            state.status == CatalogoAdminStatus.initial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.medicamentos.isEmpty) {
          return const Center(
            child: Text(
              'No hay medicamentos registrados.\nUsa el botón + para agregar uno.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              columns: const <DataColumn>[
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Nombre')),
                DataColumn(label: Text('Código')),
                DataColumn(label: Text('Precio'), numeric: true),
                DataColumn(label: Text('Categoría')),
                DataColumn(label: Text('Proveedor')),
                DataColumn(label: Text('Receta')),
                DataColumn(label: Text('Baja')),
              ],
              rows: state.medicamentos
                  .map(
                    (MedicamentoCatalogo m) => DataRow(
                      cells: <DataCell>[
                        DataCell(Text('${m.id}')),
                        DataCell(
                          Text(
                            m.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(Text(m.codigoBarras)),
                        DataCell(Text('\$${m.precio.toStringAsFixed(2)}')),
                        DataCell(Text(m.categoria ?? '-')),
                        DataCell(Text(m.proveedor ?? '-')),
                        DataCell(
                          Icon(
                            m.requiereReceta ? Icons.check : Icons.close,
                            color: m.requiereReceta
                                ? Colors.green
                                : Colors.grey,
                            size: 18,
                          ),
                        ),
                        DataCell(
                          IconButton(
                            tooltip: 'Dar de baja',
                            icon: const Icon(
                              Icons.block,
                              color: Colors.red,
                              size: 18,
                            ),
                            onPressed: () => _confirmarBaja(context, m),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        );
      },
    );
  }

  void _confirmarBaja(BuildContext context, MedicamentoCatalogo med) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogCtx) => AlertDialog(
        title: const Text('Confirmar Baja'),
        content: Text(
          '¿Dar de baja "${med.nombre}"?\n\n'
          'El medicamento ya no aparecerá en el catálogo del POS.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<CatalogoAdminCubit>().darDeBajaMedicamento(med.id);
            },
            child: const Text('Dar de Baja'),
          ),
        ],
      ),
    );
  }
}

class _MedicamentoDialog extends StatefulWidget {
  final List<CategoriaCatalogo> categorias;
  final List<ProveedorCatalogo> proveedores;

  const _MedicamentoDialog({
    required this.categorias,
    required this.proveedores,
  });

  @override
  State<_MedicamentoDialog> createState() => _MedicamentoDialogState();
}

class _MedicamentoDialogState extends State<_MedicamentoDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _codigoCtrl = TextEditingController();
  final TextEditingController _precioCtrl = TextEditingController();

  late int _selectedCategoriaId;
  late int _selectedProveedorId;
  bool _requiereReceta = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoriaId = widget.categorias.first.id;
    _selectedProveedorId = widget.proveedores.first.id;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || _formKey.currentState?.validate() != true) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);

    setState(() {
      _guardando = true;
    });

    try {
      await context.read<CatalogoAdminCubit>().crearMedicamento(
        nombre: _nombreCtrl.text.trim(),
        codigoBarras: _codigoCtrl.text.trim(),
        precio: double.parse(_precioCtrl.text.trim()),
        requiereReceta: _requiereReceta,
        categoriaId: _selectedCategoriaId,
        proveedorId: _selectedProveedorId,
      );
      if (!mounted) {
        return;
      }
      navigator.pop();
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Medicamento'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _nombreCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Campo requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _codigoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código de Barras *',
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Campo requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _precioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio *',
                    prefixText: '\$',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Campo requerido';
                    }
                    final double? parsed = double.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Ingresa un precio válido mayor a 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Requiere Receta Médica'),
                  value: _requiereReceta,
                  onChanged: _guardando
                      ? null
                      : (bool value) {
                          setState(() {
                            _requiereReceta = value;
                          });
                        },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _selectedCategoriaId,
                  decoration: const InputDecoration(labelText: 'Categoría *'),
                  items: widget.categorias
                      .map(
                        (CategoriaCatalogo categoria) => DropdownMenuItem<int>(
                          value: categoria.id,
                          child: Text(categoria.nombre),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _guardando
                      ? null
                      : (int? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedCategoriaId = value;
                          });
                        },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _selectedProveedorId,
                  decoration: const InputDecoration(labelText: 'Proveedor *'),
                  items: widget.proveedores
                      .map(
                        (ProveedorCatalogo proveedor) => DropdownMenuItem<int>(
                          value: proveedor.id,
                          child: Text(proveedor.nombre),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _guardando
                      ? null
                      : (int? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedProveedorId = value;
                          });
                        },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _CategoriaDialog extends StatefulWidget {
  const _CategoriaDialog();

  @override
  State<_CategoriaDialog> createState() => _CategoriaDialogState();
}

class _CategoriaDialogState extends State<_CategoriaDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || _formKey.currentState?.validate() != true) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);

    setState(() {
      _guardando = true;
    });

    try {
      await context.read<CatalogoAdminCubit>().crearCategoria(
        _nombreCtrl.text.trim(),
      );
      if (!mounted) {
        return;
      }
      navigator.pop();
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Categoría'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nombreCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría *',
          ),
          validator: (String? value) {
            if (value == null || value.trim().isEmpty) {
              return 'Campo requerido';
            }
            return null;
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _ProveedorDialog extends StatefulWidget {
  const _ProveedorDialog();

  @override
  State<_ProveedorDialog> createState() => _ProveedorDialogState();
}

class _ProveedorDialogState extends State<_ProveedorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _contactoCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _contactoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || _formKey.currentState?.validate() != true) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);

    setState(() {
      _guardando = true;
    });

    try {
      await context.read<CatalogoAdminCubit>().crearProveedor(
        _nombreCtrl.text.trim(),
        contacto: _contactoCtrl.text.trim().isEmpty
            ? null
            : _contactoCtrl.text.trim(),
      );
      if (!mounted) {
        return;
      }
      navigator.pop();
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Proveedor'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nombreCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre del proveedor *',
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contactoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contacto (opcional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ── Tab: Categorías ───────────────────────────────────────────────────────────

class _CategoriasTab extends StatelessWidget {
  const _CategoriasTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogoAdminCubit, CatalogoAdminState>(
      builder: (BuildContext context, CatalogoAdminState state) {
        if (state.status == CatalogoAdminStatus.loading ||
            state.status == CatalogoAdminStatus.initial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.categorias.isEmpty) {
          return const Center(
            child: Text(
              'No hay categorías registradas.\nUsa el botón + para agregar una.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.categorias.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (BuildContext ctx, int index) {
            final CategoriaCatalogo cat = state.categorias[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  cat.nombre.isNotEmpty
                      ? cat.nombre.substring(0, 1).toUpperCase()
                      : '?',
                ),
              ),
              title: Text(cat.nombre),
              trailing: Text(
                '#${cat.id}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tab: Proveedores ──────────────────────────────────────────────────────────

class _ProveedoresTab extends StatelessWidget {
  const _ProveedoresTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogoAdminCubit, CatalogoAdminState>(
      builder: (BuildContext context, CatalogoAdminState state) {
        if (state.status == CatalogoAdminStatus.loading ||
            state.status == CatalogoAdminStatus.initial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.proveedores.isEmpty) {
          return const Center(
            child: Text(
              'No hay proveedores registrados.\nUsa el botón + para agregar uno.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.proveedores.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (BuildContext ctx, int index) {
            final ProveedorCatalogo prov = state.proveedores[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  prov.nombre.isNotEmpty
                      ? prov.nombre.substring(0, 1).toUpperCase()
                      : '?',
                ),
              ),
              title: Text(prov.nombre),
              subtitle: prov.contacto != null && prov.contacto!.isNotEmpty
                  ? Text('Contacto: ${prov.contacto}')
                  : null,
              trailing: Text(
                '#${prov.id}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            );
          },
        );
      },
    );
  }
}
