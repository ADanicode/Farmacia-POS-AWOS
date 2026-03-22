import 'package:equatable/equatable.dart';

import 'medicamento.dart';

/// Entidad de línea de carrito para el flujo de venta POS.
class PosItem extends Equatable {
  /// Medicamento asociado a la línea.
  final Medicamento medicamento;

  /// Cantidad seleccionada del medicamento.
  final int cantidad;

  /// Lote sugerido FEFO para trazabilidad en ticket.
  final String? loteSugerido;

  /// Constructor principal de la línea de carrito.
  const PosItem({
    required this.medicamento,
    required this.cantidad,
    this.loteSugerido,
  });

  /// Retorna el subtotal sin IVA de la línea.
  double get subtotal => medicamento.precio * cantidad;

  /// Retorna una copia con la cantidad actualizada.
  PosItem copyWith({int? cantidad, String? loteSugerido}) {
    return PosItem(
      medicamento: medicamento,
      cantidad: cantidad ?? this.cantidad,
      loteSugerido: loteSugerido ?? this.loteSugerido,
    );
  }

  @override
  List<Object?> get props => <Object?>[medicamento, cantidad, loteSugerido];
}
