import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../domain/entities/pago_venta.dart';
import '../../domain/entities/pos_item.dart';
import '../bloc/pos/pos_state.dart';

/// Diálogo de confirmación con previsualización de ticket térmico.
class TicketPreviewDialog extends StatefulWidget {
  /// Snapshot de datos del ticket recién generado.
  final PosTicketData ticketData;

  /// Nombre del cajero que procesó la venta.
  final String cajero;

  /// Rol del usuario operativo del ticket.
  final String rol;

  /// Callback al cerrar el flujo completo del preview.
  final VoidCallback onClose;

  /// Fecha de transacción para tickets históricos.
  final DateTime? fechaTransaccion;

  /// Constructor principal del diálogo de previsualización.
  const TicketPreviewDialog({
    super.key,
    required this.ticketData,
    required this.cajero,
    required this.rol,
    required this.onClose,
    this.fechaTransaccion,
  });

  @override
  State<TicketPreviewDialog> createState() => _TicketPreviewDialogState();
}

class _TicketPreviewDialogState extends State<TicketPreviewDialog> {
  bool _isPrinting = false;

  Future<void> _simularImpresion() async {
    if (_isPrinting) {
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 140,
                height: 140,
                child: Lottie.asset(
                  'assets/animations/Success.json',
                  repeat: false,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Impresión exitosa'),
            ],
          ),
        );
      },
    );

    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    widget.onClose();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Venta confirmada',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: _ThermalTicketPreview(
                    ticketData: widget.ticketData,
                    cajero: widget.cajero,
                    rol: widget.rol,
                    fechaTransaccion: widget.fechaTransaccion ?? DateTime.now(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onClose();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cerrar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isPrinting ? null : _simularImpresion,
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print),
                      label: _isPrinting
                          ? const Text('Imprimiendo...')
                          : const Text('Imprimir'),
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

/// Tarjeta de previsualización con textura térmica y recorte irregular.
class _ThermalTicketPreview extends StatelessWidget {
  final PosTicketData ticketData;
  final String cajero;
  final String rol;
  final DateTime fechaTransaccion;

  const _ThermalTicketPreview({
    required this.ticketData,
    required this.cajero,
    required this.rol,
    required this.fechaTransaccion,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle lineStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.3,
      color: Color(0xFF232323),
    );

    return ClipPath(
      clipper: _TicketZigZagClipper(),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F3E8),
          border: Border.all(color: const Color(0xFFD8CFBF), width: 1),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: CustomPaint(
          painter: const _ThermalTexturePainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Text(
                    'FARMACIA AWOS',
                    style: lineStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(child: Text('Ticket térmico 80mm', style: lineStyle)),
                const SizedBox(height: 8),
                Text('------------------------------', style: lineStyle),
                Text('Folio: ${ticketData.ventaId}', style: lineStyle),
                Text('Cajero: $cajero ($rol)', style: lineStyle),
                Text(
                  'Fecha: ${fechaTransaccion.toIso8601String()}',
                  style: lineStyle,
                ),
                Text('------------------------------', style: lineStyle),
                ...ticketData.items.map(
                  (PosItem item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${item.medicamento.nombre} x${item.cantidad}',
                          style: lineStyle,
                        ),
                        Text(
                          'Lote: ${item.loteSugerido?.isNotEmpty == true ? item.loteSugerido : 'N/D'}',
                          style: lineStyle,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '\$ ${item.subtotal.toStringAsFixed(2)} MXN',
                            style: lineStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text('------------------------------', style: lineStyle),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Subtotal: \$ ${ticketData.subtotal.toStringAsFixed(2)}',
                    style: lineStyle,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'IVA:      \$ ${ticketData.iva.toStringAsFixed(2)}',
                    style: lineStyle,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'TOTAL:    \$ ${ticketData.total.toStringAsFixed(2)}',
                    style: lineStyle.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 6),
                Text('------------------------------', style: lineStyle),
                Text(
                  'Método de Pago: ${_metodoPagoGeneral(ticketData)}',
                  style: lineStyle,
                ),
                ...ticketData.pagos.asMap().entries.map((
                  MapEntry<int, PagoVenta> entry,
                ) {
                  final String tipo = _capitalizar(entry.value.tipo);
                  final double monto = entry.value.monto;
                  return Text(
                    'Pago ${entry.key + 1}: $tipo \$ ${monto.toStringAsFixed(2)}',
                    style: lineStyle,
                  );
                }),
                Text(
                  'Monto Recibido: \$ ${_montoRecibido(ticketData).toStringAsFixed(2)}',
                  style: lineStyle,
                ),
                Text(
                  'Cambio: \$ ${ticketData.cambio.toStringAsFixed(2)}',
                  style: lineStyle,
                ),
                if (ticketData.cedulaMedico != null &&
                    ticketData.cedulaMedico!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text('------------------------------', style: lineStyle),
                  Text(
                    'AUDITORIA MEDICA',
                    style: lineStyle.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Cedula Medica: ${ticketData.cedulaMedico}',
                    style: lineStyle,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _montoRecibido(PosTicketData data) {
    return data.pagos.fold<double>(0, (double acum, pago) => acum + pago.monto);
  }

  String _metodoPagoGeneral(PosTicketData data) {
    if (data.pagos.length > 1) {
      return 'Mixto';
    }
    if (data.pagos.isEmpty) {
      return 'N/D';
    }
    return _capitalizar(data.pagos.first.tipo);
  }

  String _capitalizar(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}

/// Clipper para simular recorte térmico en zigzag.
class _TicketZigZagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path()..moveTo(0, 0);

    path.lineTo(0, size.height - 10);

    const double toothWidth = 10;
    const double toothHeight = 8;
    double x = 0;
    bool down = true;

    while (x < size.width) {
      final double nextX = (x + toothWidth).clamp(0, size.width);
      path.lineTo(nextX, size.height - (down ? 0 : toothHeight));
      down = !down;
      x = nextX;
    }

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false;
  }
}

/// Pintor de textura suave para emular papel térmico real.
class _ThermalTexturePainter extends CustomPainter {
  const _ThermalTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stripe = Paint()..color = const Color(0x08A48F6A);
    final Paint noise = Paint()..color = const Color(0x05FFFFFF);

    for (double y = 2; y < size.height; y += 6) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), stripe);
    }

    for (double y = 0; y < size.height; y += 18) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), noise);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
