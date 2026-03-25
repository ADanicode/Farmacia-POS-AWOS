import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farmacia_pos_awos/core/di/injection_container.dart';
import 'package:farmacia_pos_awos/core/router/app_router.dart';
import 'package:farmacia_pos_awos/core/router/route_guards.dart';
import 'package:farmacia_pos_awos/features/auth/domain/entities/auth_session.dart';
import 'package:farmacia_pos_awos/features/pos/data/repositories/ventas_repository.dart';
import 'package:farmacia_pos_awos/features/pos/domain/entities/medicamento_stock.dart';
import 'package:farmacia_pos_awos/features/pos/domain/entities/pago_venta.dart';
import 'package:farmacia_pos_awos/features/pos/presentation/widgets/payment_dialog.dart';
import 'package:farmacia_pos_awos/features/pos/presentation/widgets/ticket_preview_dialog.dart';
import 'package:lottie/lottie.dart';

import '../../domain/entities/medicamento.dart';
import '../bloc/pos/pos_bloc.dart';
import '../bloc/pos/pos_event.dart';
import '../bloc/pos/pos_state.dart';
import '../bloc/search/search_bloc.dart';
import '../bloc/search/search_event.dart';
import '../bloc/search/search_state.dart';

/// Pantalla principal del Punto de Venta de farmacia.
class PosPage extends StatefulWidget {
  /// Sesión autenticada del usuario operativo del POS.
  final AuthSession session;

  /// Callback de cierre de sesión.
  final VoidCallback onLogout;

  /// Callback para alternar tema claro/oscuro.
  final VoidCallback onToggleTheme;

  /// Estado actual del tema activo.
  final bool isDarkMode;

  /// Constructor por defecto de PosPage.
  const PosPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<PosPage> createState() => _PosPageState();
}

/// Estado interno de la pantalla POS con controladores de formularios.
class _PosPageState extends State<PosPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();
  final TextEditingController _medicoController = TextEditingController();
  late final SearchBloc _searchBloc;
  late final PosBloc _posBloc;
  Timer? _backgroundSyncTimer;

  @override
  void initState() {
    super.initState();
    _searchBloc = sl<SearchBloc>()..add(const SearchQueryChanged(''));
    _posBloc = PosBloc(
      ventasRepository: sl<VentasRepository>(),
      usuarioId: widget.session.uid,
    );
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _searchBloc.add(const SearchCatalogSyncRequested(forceRefresh: true));
    });
  }

  @override
  void dispose() {
    _backgroundSyncTimer?.cancel();
    _searchController.dispose();
    _cedulaController.dispose();
    _medicoController.dispose();
    _searchBloc.close();
    _posBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PATRON: BLOC + REPOSITORY - Separación total entre UI y datos remotos.
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<SearchBloc>.value(value: _searchBloc),
        BlocProvider<PosBloc>.value(value: _posBloc),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text('Farmacia AWOS - POS | ${widget.session.nombre}'),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Chip(
                  label: Text(widget.session.role.toUpperCase()),
                  avatar: const Icon(Icons.verified_user, size: 16),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Cambiar tema',
              onPressed: widget.onToggleTheme,
              icon: Icon(
                widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              ),
            ),
            if (_esAdmin())
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.empleados);
                },
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Gestión de Empleados'),
              ),
            if (_esAdmin())
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.almacen);
                },
                icon: const Icon(Icons.inventory),
                label: const Text('Recepción de Lotes'),
              ),
            if (_esAdmin())
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.catalogo);
                },
                icon: const Icon(Icons.medication_liquid),
                label: const Text('Catálogo'),
              ),
            if (_puedeVerReportes())
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppRoutes.reportes);
                },
                icon: const Icon(Icons.bar_chart),
                label: const Text('Reportes'),
              ),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.maxWidth < 800) {
              return _MobilePosLayout(
                searchController: _searchController,
                cedulaController: _cedulaController,
                medicoController: _medicoController,
                session: widget.session,
                onManualRefresh: () {
                  _searchBloc.add(
                    const SearchCatalogSyncRequested(forceRefresh: true),
                  );
                },
              );
            }

            return _DesktopPosLayout(
              searchController: _searchController,
              cedulaController: _cedulaController,
              medicoController: _medicoController,
              session: widget.session,
              onManualRefresh: () {
                _searchBloc.add(
                  const SearchCatalogSyncRequested(forceRefresh: true),
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool _esAdmin() => RouteGuards.esAdmin(widget.session);

  // CUMPLE HU-03: solo admin o permiso explícito ver_reportes_globales.
  // Cajeros y vendedores NO acceden a reportes financieros globales.
  bool _puedeVerReportes() => RouteGuards.puedeVerReportes(widget.session);
}

/// Layout móvil del POS con catálogo y carrito en columna.
class _MobilePosLayout extends StatelessWidget {
  final TextEditingController searchController;
  final TextEditingController cedulaController;
  final TextEditingController medicoController;
  final AuthSession session;
  final VoidCallback onManualRefresh;

  /// Constructor del layout móvil del POS.
  const _MobilePosLayout({
    required this.searchController,
    required this.cedulaController,
    required this.medicoController,
    required this.session,
    required this.onManualRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: _CatalogoPanel(
            searchController: searchController,
            onManualRefresh: onManualRefresh,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _CarritoPanel(
            cedulaController: cedulaController,
            medicoController: medicoController,
            session: session,
          ),
        ),
      ],
    );
  }
}

/// Layout escritorio/web del POS dividido en dos columnas.
class _DesktopPosLayout extends StatelessWidget {
  final TextEditingController searchController;
  final TextEditingController cedulaController;
  final TextEditingController medicoController;
  final AuthSession session;
  final VoidCallback onManualRefresh;

  /// Constructor del layout de escritorio del POS.
  const _DesktopPosLayout({
    required this.searchController,
    required this.cedulaController,
    required this.medicoController,
    required this.session,
    required this.onManualRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: _CatalogoPanel(
            searchController: searchController,
            onManualRefresh: onManualRefresh,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: _CarritoPanel(
            cedulaController: cedulaController,
            medicoController: medicoController,
            session: session,
          ),
        ),
      ],
    );
  }
}

/// Panel izquierdo de catálogo y búsqueda.
class _CatalogoPanel extends StatelessWidget {
  final TextEditingController searchController;
  final VoidCallback onManualRefresh;

  /// Constructor del panel de catálogo.
  const _CatalogoPanel({
    required this.searchController,
    required this.onManualRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Catálogo',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // CUMPLE HU-17: BUSQUEDA EN MOSTRADOR (ALTA VELOCIDAD).
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (String value) {
                    context.read<SearchBloc>().add(SearchQueryChanged(value));
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar medicamento por nombre',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Sincronizar catálogo',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Sincronizando catálogo con el almacén central...',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  onManualRefresh();
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BlocBuilder<SearchBloc, SearchState>(
              builder: (BuildContext context, SearchState state) {
                if (state.status == SearchStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == SearchStatus.failure) {
                  return Center(
                    child: Text(state.errorMessage ?? 'Error de búsqueda'),
                  );
                }
                if (state.resultados.isEmpty) {
                  return const Center(
                    child: Text('No hay medicamentos para mostrar'),
                  );
                }

                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final int crossAxisCount = constraints.maxWidth > 1100
                        ? 3
                        : (constraints.maxWidth > 700 ? 2 : 1);
                    return GridView.builder(
                      itemCount: state.resultados.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.4,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final Medicamento medicamento = state.resultados[index];
                        final MedicamentoStock? stock =
                            state.stockPorMedicamento[medicamento.id];
                        return _MedicamentoCard(
                          medicamento: medicamento,
                          stock: stock,
                        );
                      },
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
}

/// Tarjeta individual de medicamento en la grilla del catálogo.
class _MedicamentoCard extends StatefulWidget {
  final Medicamento medicamento;
  final MedicamentoStock? stock;

  /// Constructor de tarjeta de medicamento.
  const _MedicamentoCard({required this.medicamento, required this.stock});

  @override
  State<_MedicamentoCard> createState() => _MedicamentoCardState();
}

class _MedicamentoCardState extends State<_MedicamentoCard> {
  double _buttonScale = 1;

  void _onAgregarPressed() {
    setState(() {
      _buttonScale = 0.94;
    });

    context.read<PosBloc>().add(
      PosItemAdded(
        widget.medicamento,
        loteSugerido: widget.stock?.lotePrincipal,
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _buttonScale = 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: const Color(0x1A0D3B66),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6EFEC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.medicamento.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Código: ${widget.medicamento.codigoBarras}'),
            Text(
              'Precio: \$ ${widget.medicamento.precio.toStringAsFixed(2)} MXN',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  widget.stock == null
                      ? 'Stock: -- · Lote: --'
                      : 'Stock: ${widget.stock!.stockTotal} · Lote: ${widget.stock!.lotePrincipal ?? 'N/D'}',
                  style: const TextStyle(fontSize: 11),
                ),
                avatar: const Icon(Icons.inventory_2, size: 14),
              ),
            ),
            if (widget.medicamento.requiereReceta)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB4332E),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Controlado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: AnimatedScale(
                scale: _buttonScale,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutBack,
                child: FilledButton.icon(
                  onPressed: _onAgregarPressed,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Agregar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel derecho del carrito con totales y acción de cobro.
class _CarritoPanel extends StatelessWidget {
  final TextEditingController cedulaController;
  final TextEditingController medicoController;
  final AuthSession session;

  /// Constructor del panel de carrito.
  const _CarritoPanel({
    required this.cedulaController,
    required this.medicoController,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: BlocConsumer<PosBloc, PosState>(
        listenWhen: (PosState previous, PosState current) =>
            previous.lastVentaId != current.lastVentaId ||
            previous.errorMessage != current.errorMessage ||
            previous.lastTicketData != current.lastTicketData,
        listener: (BuildContext context, PosState state) {
          if (state.lastVentaId != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Venta procesada: ${state.lastVentaId}')),
            );
            cedulaController.clear();
            medicoController.clear();
          }
          if (state.lastTicketData != null) {
            context.read<SearchBloc>().add(
              SearchStockDiscountApplied(state.lastTicketData!.items),
            );
            showDialog<void>(
              context: context,
              builder: (BuildContext dialogContext) => TicketPreviewDialog(
                ticketData: state.lastTicketData!,
                cajero: session.nombre,
                rol: session.role,
                onClose: () {
                  context.read<PosBloc>().add(const PosTicketPreviewCleared());
                },
              ),
            );
          }
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (BuildContext context, PosState state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Carrito',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: state.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            SizedBox(
                              width: 170,
                              height: 170,
                              child: Lottie.asset(
                                'assets/animations/empty_cart.json',
                                repeat: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text('Tu carrito está listo para comenzar'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.items.length,
                        itemBuilder: (BuildContext context, int index) {
                          final item = state.items[index];
                          return Column(
                            children: <Widget>[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.medicamento.nombre),
                                subtitle: Text(
                                  '\$ ${item.medicamento.precio.toStringAsFixed(2)} MXN x ${item.cantidad}',
                                ),
                                leading: item.loteSugerido != null
                                    ? Tooltip(
                                        message:
                                            'Lote sugerido: ${item.loteSugerido}',
                                        child: const Icon(
                                          Icons.local_shipping_outlined,
                                        ),
                                      )
                                    : null,
                                trailing: Wrap(
                                  spacing: 4,
                                  children: <Widget>[
                                    IconButton(
                                      onPressed: () {
                                        context.read<PosBloc>().add(
                                          PosItemDecreased(item.medicamento.id),
                                        );
                                      },
                                      icon: const Icon(Icons.remove),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        context.read<PosBloc>().add(
                                          PosItemIncreased(item.medicamento.id),
                                        );
                                      },
                                      icon: const Icon(Icons.add),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        context.read<PosBloc>().add(
                                          PosItemRemoved(item.medicamento.id),
                                        );
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              // CUMPLE HU-20 Y HU-21: VISUALIZACION DE SUBTOTAL, IVA Y TOTAL.
              _TotalRow(label: 'Subtotal', value: state.subtotal),
              _TotalRow(label: 'IVA (16%)', value: state.iva),
              const Divider(),
              _TotalRow(label: 'Total', value: state.total, isBold: true),
              const SizedBox(height: 12),
              // CUMPLE HU-22 Y HU-24: AUDITORIA MEDICA PARA CONTROLADOS.
              if (state.tieneControlados)
                Column(
                  children: <Widget>[
                    TextField(
                      controller: cedulaController,
                      onChanged: (String value) {
                        context.read<PosBloc>().add(
                          PosCedulaMedicoChanged(value),
                        );
                      },
                      decoration: const InputDecoration(
                        labelText: 'Cédula del médico',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: medicoController,
                      onChanged: (String value) {
                        context.read<PosBloc>().add(
                          PosNombreMedicoChanged(value),
                        );
                      },
                      decoration: const InputDecoration(
                        labelText: 'Nombre del médico',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              SizedBox(
                width: double.infinity,
                // CUMPLE HU-24: BOTON COBRAR SE BLOQUEA SI CARRITO VACIO O AUDITORIA INCOMPLETA.
                child: FilledButton(
                  onPressed: state.canCheckout
                      ? () async {
                          final List<PagoVenta>? pagos =
                              await showDialog<List<PagoVenta>>(
                                context: context,
                                builder: (BuildContext dialogContext) {
                                  return PaymentDialog(total: state.total);
                                },
                              );

                          if (!context.mounted ||
                              pagos == null ||
                              pagos.isEmpty) {
                            return;
                          }

                          context.read<PosBloc>().add(
                            PosCheckoutRequested(pagos),
                          );
                        }
                      : null,
                  child: state.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cobrar'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Fila de resumen para montos de subtotal, IVA y total.
class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;

  /// Constructor de fila de total.
  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = TextStyle(
      fontSize: isBold ? 18 : 14,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: textStyle),
          Text('\$ ${value.toStringAsFixed(2)} MXN', style: textStyle),
        ],
      ),
    );
  }
}
