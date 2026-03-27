import 'package:equatable/equatable.dart';

import '../../../domain/entities/medicamento.dart';
import '../../../domain/entities/pago_venta.dart';

/// Eventos del PosBloc para la operación de caja.
sealed class PosEvent extends Equatable {
  /// Constructor base de eventos del POS.
  const PosEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// Evento para agregar un medicamento al carrito.
class PosItemAdded extends PosEvent {
  /// Medicamento seleccionado en catálogo.
  final Medicamento medicamento;

  /// Lote FEFO sugerido para trazabilidad.
  final String? loteSugerido;

  /// Constructor del evento de agregado al carrito.
  const PosItemAdded(this.medicamento, {this.loteSugerido});

  @override
  List<Object?> get props => <Object?>[medicamento, loteSugerido];
}

/// Evento para disminuir cantidad o eliminar línea.
class PosItemDecreased extends PosEvent {
  /// ID del medicamento a disminuir.
  final int medicamentoId;

  /// Constructor del evento de decremento.
  const PosItemDecreased(this.medicamentoId);

  @override
  List<Object?> get props => <Object?>[medicamentoId];
}

/// Evento para aumentar cantidad de una línea.
class PosItemIncreased extends PosEvent {
  /// ID del medicamento a incrementar.
  final int medicamentoId;

  /// Constructor del evento de incremento.
  const PosItemIncreased(this.medicamentoId);

  @override
  List<Object?> get props => <Object?>[medicamentoId];
}

/// Evento para definir manualmente la cantidad de una línea.
class PosUpdateItemQuantity extends PosEvent {
  /// ID del medicamento a actualizar.
  final int medicamentoId;

  /// Nueva cantidad deseada.
  final int newQuantity;

  /// Constructor del evento de actualización manual de cantidad.
  const PosUpdateItemQuantity(this.medicamentoId, this.newQuantity);

  @override
  List<Object?> get props => <Object?>[medicamentoId, newQuantity];
}

/// Evento para eliminar una línea completa del carrito.
class PosItemRemoved extends PosEvent {
  /// ID del medicamento a eliminar.
  final int medicamentoId;

  /// Constructor del evento de eliminación.
  const PosItemRemoved(this.medicamentoId);

  @override
  List<Object?> get props => <Object?>[medicamentoId];
}

/// Evento para actualizar cédula del médico.
class PosCedulaMedicoChanged extends PosEvent {
  /// Cédula actual ingresada en formulario.
  final String cedula;

  /// Constructor del evento de cédula.
  const PosCedulaMedicoChanged(this.cedula);

  @override
  List<Object?> get props => <Object?>[cedula];
}

/// Evento para actualizar nombre del médico.
class PosNombreMedicoChanged extends PosEvent {
  /// Nombre actual ingresado en formulario.
  final String nombre;

  /// Constructor del evento de nombre de médico.
  const PosNombreMedicoChanged(this.nombre);

  @override
  List<Object?> get props => <Object?>[nombre];
}

/// Evento para confirmar y cobrar la venta.
class PosCheckoutRequested extends PosEvent {
  /// Métodos de pago confirmados en el asistente de cobro.
  final List<PagoVenta> pagos;

  /// Monto total recibido por caja para calcular cambio real.
  final double montoRecibido;

  /// Constructor del evento de cobro.
  const PosCheckoutRequested(this.pagos, {required this.montoRecibido});

  @override
  List<Object?> get props => <Object?>[pagos, montoRecibido];
}

/// Evento para limpiar datos del ticket después de cerrar el preview.
class PosTicketPreviewCleared extends PosEvent {
  /// Constructor del evento de limpieza de preview de ticket.
  const PosTicketPreviewCleared();
}
