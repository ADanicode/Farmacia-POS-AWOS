import 'package:equatable/equatable.dart';

/// Método de pago aplicado a una venta.
class PagoVenta extends Equatable {
  /// Tipo de pago aceptado por backend: efectivo o tarjeta.
  final String tipo;

  /// Monto asociado al método de pago.
  final double monto;

  /// Referencia opcional para pagos electrónicos.
  final String? referencia;

  /// Constructor principal del método de pago.
  const PagoVenta({required this.tipo, required this.monto, this.referencia});

  /// Serializa este pago al payload esperado por backend.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tipo': tipo,
      'monto': monto,
      if (referencia != null && referencia!.trim().isNotEmpty)
        'referencia': referencia,
    };
  }

  @override
  List<Object?> get props => <Object?>[tipo, monto, referencia];
}
