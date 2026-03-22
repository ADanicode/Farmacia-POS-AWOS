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

  /// Constructor del evento de cobro.
  const PosCheckoutRequested(this.pagos);

  @override
  List<Object?> get props => <Object?>[pagos];
}

/// Evento para limpiar datos del ticket después de cerrar el preview.
class PosTicketPreviewCleared extends PosEvent {
  /// Constructor del evento de limpieza de preview de ticket.
  const PosTicketPreviewCleared();
}
