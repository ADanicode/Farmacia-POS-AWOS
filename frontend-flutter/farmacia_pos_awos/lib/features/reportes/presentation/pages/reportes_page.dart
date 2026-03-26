import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../pos/presentation/widgets/ticket_preview_dialog.dart';
import '../../data/repositories/reportes_repository.dart';
import '../../domain/entities/reporte_turno.dart';
import '../../domain/entities/venta_reporte.dart';
import '../utils/report_exporter.dart';

enum _PeriodoFiltro { hoy, semana, mes, anio, personalizado }

/// Pantalla de reportes y auditoría de ventas.
class ReportesPage extends StatefulWidget {
  /// Sesión del usuario actual para contexto de auditoría.
  final AuthSession session;

  /// Constructor principal de reportes.
  const ReportesPage({super.key, required this.session});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final ReportesRepository _reportesRepository = sl<ReportesRepository>();

  ReporteTurno _reporte = ReporteTurno.empty();
  bool _loading = true;
  String? _error;
  _PeriodoFiltro _periodo = _PeriodoFiltro.hoy;
  DateTimeRange? _customRange;
  int _touchedPieIndex = -1;

  List<VentaReporte> get _ventas => _reporte.ventas;

  @override
  void initState() {
    super.initState();
    _cargarReporte();
  }

  DateTimeRange _resolverRango() {
    final DateTime now = DateTime.now();
    switch (_periodo) {
      case _PeriodoFiltro.hoy:
        final DateTime start = DateTime(now.year, now.month, now.day);
        final DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case _PeriodoFiltro.semana:
        final int delta = now.weekday - DateTime.monday;
        final DateTime start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: delta));
        final DateTime end = start.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );
        return DateTimeRange(start: start, end: end);
      case _PeriodoFiltro.mes:
        final DateTime start = DateTime(now.year, now.month, 1);
        final DateTime end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case _PeriodoFiltro.anio:
        final DateTime start = DateTime(now.year, 1, 1);
        final DateTime end = DateTime(now.year, 12, 31, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case _PeriodoFiltro.personalizado:
        final DateTimeRange? range = _customRange;
        if (range == null) {
          final DateTime start = DateTime(now.year, now.month, now.day);
          final DateTime end = DateTime(
            now.year,
            now.month,
            now.day,
            23,
            59,
            59,
          );
          return DateTimeRange(start: start, end: end);
        }
        return DateTimeRange(
          start: DateTime(range.start.year, range.start.month, range.start.day),
          end: DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
            23,
            59,
            59,
          ),
        );
    }
  }

  Future<void> _cargarReporte({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final DateTimeRange range = _resolverRango();
      final ReporteTurno reporte = await _reportesRepository
          .obtenerReporteTurno(fechaInicio: range.start, fechaFin: range.end);

      if (!mounted) {
        return;
      }

      setState(() {
        _reporte = reporte;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _seleccionarRangoPersonalizado() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _customRange = picked;
      _periodo = _PeriodoFiltro.personalizado;
    });
    await _cargarReporte();
  }

  Future<void> _onExportarReporte() async {
    if (_ventas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay ventas para exportar.')),
      );
      return;
    }

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String fileName = 'reporte_ventas_$timestamp';
    final String? filePath = await exportVentasCsv(
      ventas: _ventas,
      fileName: fileName,
    );

    if (!mounted) {
      return;
    }

    final String msg = filePath == null
        ? 'Reporte CSV descargado.'
        : 'Reporte CSV guardado en: $filePath';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  double _kFormatter(double value) {
    if (value >= 1000) {
      return value / 1000;
    }
    return value;
  }

  String _fmtYAxisMoney(double value) {
    if (value >= 1000) {
      return '\$ ${_kFormatter(value).toStringAsFixed(0)}k';
    }
    return '\$ ${value.toStringAsFixed(0)}';
  }

  String _fmtMoney(double value) => '\$ ${value.toStringAsFixed(2)} MXN';

  String _fmtDate(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }

  Widget _buildEstadoChip(String estado) {
    final String estadoLower = estado.toLowerCase();
    late final Color bgColor;
    late final Color textColor;

    if (estadoLower == 'pendiente') {
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade900;
    } else if (estadoLower == 'procesada' || estadoLower == 'completada') {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade900;
    } else if (estadoLower == 'anulada') {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade900;
    } else {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade900;
    }

    return Chip(
      backgroundColor: bgColor,
      label: Text(
        estado.toUpperCase(),
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  List<_TopProducto> _calcularTopProductos() {
    final Map<String, int> acumulado = <String, int>{};
    for (final VentaReporte venta in _ventas) {
      for (final linea in venta.lineas) {
        acumulado[linea.medicamento.nombre] =
            (acumulado[linea.medicamento.nombre] ?? 0) + linea.cantidad;
      }
    }

    final List<_TopProducto> ranking =
        acumulado.entries
            .map((MapEntry<String, int> e) => _TopProducto(e.key, e.value))
            .toList(growable: false)
          ..sort((a, b) => b.cantidad.compareTo(a.cantidad));

    return ranking.take(3).toList(growable: false);
  }

  bool _esTarjeta(String tipoPago) {
    final String normalized = tipoPago.trim().toLowerCase();
    return normalized.contains('tarjeta') ||
        normalized.contains('credito') ||
        normalized.contains('debito') ||
        normalized.contains('visa') ||
        normalized.contains('master');
  }

  Map<String, double> _calcularVentasPorMetodoPago() {
    double efectivo = 0;
    double tarjeta = 0;

    for (final VentaReporte venta in _ventas) {
      if (venta.pagos.isNotEmpty) {
        for (final pago in venta.pagos) {
          if (_esTarjeta(pago.tipo)) {
            tarjeta += pago.monto;
          } else {
            efectivo += pago.monto;
          }
        }
      } else {
        if (_esTarjeta(venta.metodoPago)) {
          tarjeta += venta.total;
        } else {
          efectivo += venta.total;
        }
      }
    }

    return <String, double>{'Efectivo': efectivo, 'Tarjeta': tarjeta};
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
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

  Widget _buildTopProductosCard() {
    final List<_TopProducto> top = _calcularTopProductos();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Top 3 Productos',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (top.isEmpty)
              const Text('Sin datos para el periodo seleccionado.')
            else
              ...top.map(
                (_TopProducto p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(p.nombre, overflow: TextOverflow.ellipsis),
                      ),
                      Text('${p.cantidad} uds'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroPeriodo() {
    final Map<_PeriodoFiltro, String> labels = <_PeriodoFiltro, String>{
      _PeriodoFiltro.hoy: 'Hoy',
      _PeriodoFiltro.semana: 'Esta Semana',
      _PeriodoFiltro.mes: 'Este Mes',
      _PeriodoFiltro.anio: 'Este Año',
      _PeriodoFiltro.personalizado: 'Rango Personalizado',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels.entries
          .map((MapEntry<_PeriodoFiltro, String> entry) {
            return ChoiceChip(
              label: Text(entry.value),
              selected: _periodo == entry.key,
              onSelected: (bool selected) async {
                if (!selected) {
                  return;
                }
                if (entry.key == _PeriodoFiltro.personalizado) {
                  await _seleccionarRangoPersonalizado();
                  return;
                }
                setState(() {
                  _periodo = entry.key;
                });
                await _cargarReporte();
              },
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildVentasPorTiempoChart() {
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (_ventas.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin datos para graficar.'),
        ),
      );
    }

    final Map<String, double> grouped = <String, double>{};
    for (final VentaReporte venta in _ventas) {
      final String key = _periodo == _PeriodoFiltro.hoy
          ? '${venta.fecha.hour.toString().padLeft(2, '0')}:00'
          : '${venta.fecha.day.toString().padLeft(2, '0')}/${venta.fecha.month.toString().padLeft(2, '0')}';
      grouped[key] = (grouped[key] ?? 0) + venta.total;
    }

    final List<MapEntry<String, double>> points = grouped.entries.toList(
      growable: false,
    )..sort((a, b) => a.key.compareTo(b.key));
    final double maxY = max<double>(
      1,
      points.fold<double>(0, (double maxVal, e) => max(maxVal, e.value)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Ventas por Tiempo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double progress, Widget? _) {
                  return BarChart(
                    BarChartData(
                      maxY: maxY * 1.2,
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem:
                              (
                                BarChartGroupData group,
                                int groupIndex,
                                BarChartRodData rod,
                                int rodIndex,
                              ) {
                                final String label =
                                    points[group.x.toInt()].key;
                                return BarTooltipItem(
                                  '$label\n${_fmtMoney(rod.toY)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 64,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              return Text(
                                _fmtYAxisMoney(value),
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final int idx = value.toInt();
                              if (idx < 0 || idx >= points.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  points[idx].key,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: points
                          .asMap()
                          .entries
                          .map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: <BarChartRodData>[
                                BarChartRodData(
                                  toY: entry.value.value * progress,
                                  width: 16,
                                  borderRadius: BorderRadius.circular(6),
                                  color: colors.primary,
                                ),
                              ],
                            );
                          })
                          .toList(growable: false),
                    ),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.linear,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVentasMetodoPagoChart() {
    final Map<String, double> data = _calcularVentasPorMetodoPago();
    final double efectivo = data['Efectivo'] ?? 0;
    final double tarjeta = data['Tarjeta'] ?? 0;
    final double total = efectivo + tarjeta;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (total <= 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin datos para metodos de pago.'),
        ),
      );
    }

    final List<_MetodoPagoSlice> slices = <_MetodoPagoSlice>[
      _MetodoPagoSlice('Efectivo', efectivo, Colors.green.shade500),
      _MetodoPagoSlice('Tarjeta', tarjeta, Colors.blue.shade500),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Ventas por Metodo de Pago',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutExpo,
                builder: (BuildContext context, double progress, Widget? _) {
                  return PieChart(
                    PieChartData(
                      centerSpaceRadius: 34,
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback:
                            (FlTouchEvent event, PieTouchResponse? response) {
                              if (event is FlPointerHoverEvent) {
                                if (!event.isInterestedForInteractions ||
                                    response == null ||
                                    response.touchedSection == null) {
                                  if (_touchedPieIndex != -1) {
                                    setState(() {
                                      _touchedPieIndex = -1;
                                    });
                                  }
                                  return;
                                }
                                final int newIndex = response
                                    .touchedSection!
                                    .touchedSectionIndex;
                                if (_touchedPieIndex != newIndex) {
                                  setState(() {
                                    _touchedPieIndex = newIndex;
                                  });
                                }
                              }
                            },
                      ),
                      sections: slices
                          .asMap()
                          .entries
                          .map((entry) {
                            final int index = entry.key;
                            final _MetodoPagoSlice slice = entry.value;
                            final bool isTouched = index == _touchedPieIndex;
                            final double percentage =
                                (slice.value / total) * 100;
                            return PieChartSectionData(
                              color: slice.color,
                              value: slice.value * progress,
                              radius: isTouched ? 68 : 58,
                              title: '${percentage.toStringAsFixed(1)}%',
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              badgeWidget: isTouched
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.inverseSurface,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${slice.label}: ${_fmtMoney(slice.value)}',
                                        style: TextStyle(
                                          color: colorScheme.onInverseSurface,
                                          fontSize: 11,
                                        ),
                                      ),
                                    )
                                  : null,
                            );
                          })
                          .toList(growable: false),
                    ),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: slices
                    .map((_MetodoPagoSlice slice) {
                      final double percentage = (slice.value / total) * 100;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: slice.color,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${slice.label}: ${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pedirMotivoAnulacion(VentaReporte venta) async {
    final TextEditingController controller = TextEditingController();
    String? errorText;

    final String? motivo = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                return AlertDialog(
                  title: const Text('Confirmación de seguridad'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '¿Seguro que deseas anular el folio ${venta.folio}? '
                        'Esta acción devolverá el inventario al almacén físico.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Motivo de la anulación',
                          hintText: 'Ej. Error de cobro',
                          errorText: errorText,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () {
                        final String motivo = controller.text.trim();
                        if (motivo.isEmpty) {
                          setDialogState(() {
                            errorText = 'El motivo es obligatorio';
                          });
                          return;
                        }
                        Navigator.of(dialogContext).pop(motivo);
                      },
                      icon: const Icon(Icons.cancel),
                      label: const Text('Anular folio'),
                    ),
                  ],
                );
              },
        );
      },
    );

    controller.dispose();
    return motivo;
  }

  Future<void> _onAnularVenta(VentaReporte venta) async {
    final List<String> permisosActuales =
        context.read<AuthBloc>().state.session?.permisos ??
        widget.session.permisos;
    if (!permisosActuales.contains('anular_venta')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para anular ventas.')),
      );
      return;
    }

    final String? motivo = await _pedirMotivoAnulacion(venta);
    if (motivo == null || motivo.trim().isEmpty) {
      return;
    }

    try {
      await _reportesRepository.anularVenta(venta.ventaId, motivo);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folio ${venta.folio} anulado correctamente.')),
      );
      await _cargarReporte(showLoader: false);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al anular folio: $e')));
    }
  }

  Future<void> _onVerTicket(VentaReporte venta) async {
    try {
      final ticketData = await _reportesRepository.obtenerTicketHistorico(
        venta,
      );
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return TicketPreviewDialog(
            ticketData: ticketData,
            cajero: venta.cajero.isNotEmpty
                ? venta.cajero
                : widget.session.nombre,
            rol: widget.session.role,
            fechaTransaccion: venta.fecha,
            onClose: () {},
          );
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo abrir ticket: $e')));
    }
  }

  Widget _buildVentaCard(VentaReporte venta, bool puedeAnularVenta) {
    final bool anulable = venta.estado != 'anulada' && puedeAnularVenta;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Folio: ${venta.folio}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _buildEstadoChip(venta.estado),
              ],
            ),
            const SizedBox(height: 6),
            Text('Fecha: ${_fmtDate(venta.fecha)}'),
            Text('Cajero: ${venta.cajero}'),
            Text('Método: ${venta.metodoPago}'),
            Text('Total: ${_fmtMoney(venta.total)}'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _onVerTicket(venta),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver ticket'),
                  ),
                  if (anulable) ...<Widget>[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => _onAnularVenta(venta),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Anular'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool puedeAnularVenta = context.select<AuthBloc, bool>((
      AuthBloc bloc,
    ) {
      final List<String> permisos =
          bloc.state.session?.permisos ?? widget.session.permisos;
      return permisos.contains('anular_venta');
    });

    final double total = _reporte.totalVendido;
    final int tickets = _reporte.totalTickets;
    final double promedio = tickets > 0 ? total / tickets : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes y Auditoría'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _onExportarReporte,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Exportar Reporte (CSV)'),
          ),
          IconButton(
            tooltip: 'Recargar',
            onPressed: () => _cargarReporte(showLoader: false),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _cargarReporte(showLoader: false),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('No se pudo cargar reporte: $_error'),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool esDesktop = constraints.maxWidth >= 980;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      _buildFiltroPeriodo(),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          SizedBox(
                            width: esDesktop
                                ? (constraints.maxWidth - 52) / 3
                                : constraints.maxWidth,
                            child: _buildKpiCard(
                              title: 'Ingresos Totales (Periodo)',
                              value: _fmtMoney(total),
                              icon: Icons.payments,
                            ),
                          ),
                          SizedBox(
                            width: esDesktop
                                ? (constraints.maxWidth - 52) / 3
                                : constraints.maxWidth,
                            child: _buildKpiCard(
                              title: 'Tickets Emitidos',
                              value: tickets.toString(),
                              icon: Icons.receipt_long,
                            ),
                          ),
                          SizedBox(
                            width: esDesktop
                                ? (constraints.maxWidth - 52) / 3
                                : constraints.maxWidth,
                            child: _buildKpiCard(
                              title: 'Ticket Promedio',
                              value: _fmtMoney(promedio),
                              icon: Icons.trending_up,
                            ),
                          ),
                          SizedBox(
                            width: esDesktop
                                ? (constraints.maxWidth - 52) / 3
                                : constraints.maxWidth,
                            child: _buildTopProductosCard(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (esDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: _buildVentasPorTiempoChart()),
                            const SizedBox(width: 12),
                            Expanded(child: _buildVentasMetodoPagoChart()),
                          ],
                        )
                      else ...<Widget>[
                        _buildVentasPorTiempoChart(),
                        const SizedBox(height: 12),
                        _buildVentasMetodoPagoChart(),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Historial de ventas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_ventas.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No hay ventas en el periodo seleccionado.',
                            ),
                          ),
                        )
                      else if (esDesktop)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                            ),
                            columns: const <DataColumn>[
                              DataColumn(label: Text('Folio')),
                              DataColumn(label: Text('Fecha')),
                              DataColumn(label: Text('Cajero')),
                              DataColumn(label: Text('Método de Pago')),
                              DataColumn(label: Text('Total')),
                              DataColumn(label: Text('Estado')),
                              DataColumn(label: Text('Acciones')),
                            ],
                            rows: _ventas
                                .map((VentaReporte venta) {
                                  final bool anulable =
                                      venta.estado != 'anulada' &&
                                      puedeAnularVenta;
                                  return DataRow(
                                    cells: <DataCell>[
                                      DataCell(Text(venta.folio)),
                                      DataCell(Text(_fmtDate(venta.fecha))),
                                      DataCell(Text(venta.cajero)),
                                      DataCell(Text(venta.metodoPago)),
                                      DataCell(Text(_fmtMoney(venta.total))),
                                      DataCell(_buildEstadoChip(venta.estado)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            IconButton(
                                              tooltip: 'Ver ticket',
                                              onPressed: () =>
                                                  _onVerTicket(venta),
                                              icon: const Icon(
                                                Icons.visibility_outlined,
                                              ),
                                            ),
                                            if (anulable)
                                              IconButton(
                                                color: Colors.red,
                                                tooltip: 'Anular ticket',
                                                onPressed: () =>
                                                    _onAnularVenta(venta),
                                                icon: const Icon(
                                                  Icons.cancel_outlined,
                                                ),
                                              )
                                            else
                                              const SizedBox.shrink(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                })
                                .toList(growable: false),
                          ),
                        )
                      else
                        ..._ventas.map(
                          (VentaReporte venta) =>
                              _buildVentaCard(venta, puedeAnularVenta),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _TopProducto {
  final String nombre;
  final int cantidad;

  const _TopProducto(this.nombre, this.cantidad);
}

class _MetodoPagoSlice {
  final String label;
  final double value;
  final Color color;

  const _MetodoPagoSlice(this.label, this.value, this.color);
}
