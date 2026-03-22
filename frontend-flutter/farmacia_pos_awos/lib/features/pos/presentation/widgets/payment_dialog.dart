import 'package:flutter/material.dart';

import '../../domain/entities/pago_venta.dart';

/// Modal de cobro para seleccionar método de pago y validar montos.
class PaymentDialog extends StatefulWidget {
  /// Total final que debe cuadrar con la suma de pagos.
  final double total;

  /// Constructor del asistente de cobro.
  const PaymentDialog({super.key, required this.total});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

enum _PaymentMethod { efectivo, tarjeta, mixto }

class _PaymentDialogState extends State<PaymentDialog> {
  final TextEditingController _montoRecibidoController =
      TextEditingController();
  final TextEditingController _montoEfectivoMixtoController =
      TextEditingController();
  final TextEditingController _montoTarjetaMixtoController =
      TextEditingController();

  _PaymentMethod _method = _PaymentMethod.efectivo;

  @override
  void dispose() {
    _montoRecibidoController.dispose();
    _montoEfectivoMixtoController.dispose();
    _montoTarjetaMixtoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double total = widget.total;
    final double montoRecibido = _parse(_montoRecibidoController.text);
    final double mixtoEfectivo = _parse(_montoEfectivoMixtoController.text);
    final double mixtoTarjeta = _parse(_montoTarjetaMixtoController.text);

    final double cambio = _roundMoney(montoRecibido - total);
    final double sumaMixta = _roundMoney(mixtoEfectivo + mixtoTarjeta);

    final bool efectivoValido = montoRecibido >= total;
    final bool mixtoValido =
        mixtoEfectivo > 0 &&
        mixtoTarjeta > 0 &&
        (sumaMixta - total).abs() <= 0.01;

    final bool canConfirm = switch (_method) {
      _PaymentMethod.efectivo => efectivoValido,
      _PaymentMethod.tarjeta => true,
      _PaymentMethod.mixto => mixtoValido,
    };

    return AlertDialog(
      title: const Text('Asistente de cobro'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Total a cobrar: \$ ${total.toStringAsFixed(2)} MXN',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              RadioGroup<_PaymentMethod>(
                groupValue: _method,
                onChanged: _onMethodChanged,
                child: Column(
                  children: <Widget>[
                    RadioListTile<_PaymentMethod>(
                      value: _PaymentMethod.efectivo,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Efectivo'),
                    ),
                    RadioListTile<_PaymentMethod>(
                      value: _PaymentMethod.tarjeta,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tarjeta'),
                    ),
                    RadioListTile<_PaymentMethod>(
                      value: _PaymentMethod.mixto,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mixto'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_method == _PaymentMethod.efectivo) ...<Widget>[
                TextField(
                  controller: _montoRecibidoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Monto recibido',
                    border: const OutlineInputBorder(),
                    errorText: montoRecibido > 0 && !efectivoValido
                        ? 'El monto recibido debe cubrir el total'
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cambio: \$ ${(cambio > 0 ? cambio : 0).toStringAsFixed(2)} MXN',
                ),
              ],
              if (_method == _PaymentMethod.tarjeta)
                const Text('Cobro exacto por tarjeta.'),
              if (_method == _PaymentMethod.mixto) ...<Widget>[
                TextField(
                  controller: _montoEfectivoMixtoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Monto efectivo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _montoTarjetaMixtoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Monto tarjeta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Suma: \$ ${sumaMixta.toStringAsFixed(2)} MXN'),
                if (!mixtoValido && (mixtoEfectivo > 0 || mixtoTarjeta > 0))
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'La suma de efectivo y tarjeta debe ser exacta al total.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: canConfirm
              ? () {
                  Navigator.of(context).pop(_buildPagos(total));
                }
              : null,
          child: const Text('Confirmar pago'),
        ),
      ],
    );
  }

  void _onMethodChanged(_PaymentMethod? value) {
    if (value == null) {
      return;
    }
    setState(() {
      _method = value;
    });
  }

  List<PagoVenta> _buildPagos(double total) {
    switch (_method) {
      case _PaymentMethod.efectivo:
        return <PagoVenta>[
          PagoVenta(tipo: 'efectivo', monto: _roundMoney(total)),
        ];
      case _PaymentMethod.tarjeta:
        return <PagoVenta>[
          PagoVenta(tipo: 'tarjeta', monto: _roundMoney(total)),
        ];
      case _PaymentMethod.mixto:
        final double efectivo = _roundMoney(
          _parse(_montoEfectivoMixtoController.text),
        );
        final double tarjeta = _roundMoney(
          _parse(_montoTarjetaMixtoController.text),
        );
        return <PagoVenta>[
          PagoVenta(tipo: 'efectivo', monto: efectivo),
          PagoVenta(tipo: 'tarjeta', monto: tarjeta),
        ];
    }
  }

  double _parse(String value) {
    final String normalized = value.replaceAll(',', '.').trim();
    return double.tryParse(normalized) ?? 0;
  }

  double _roundMoney(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
