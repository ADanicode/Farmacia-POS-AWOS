import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/ventas_repository.dart';
import '../../../domain/entities/pago_venta.dart';
import '../../../domain/entities/pos_item.dart';
import 'pos_event.dart';
import 'pos_state.dart';

/// BLoC principal para manejo de carrito y cobro del POS.
class PosBloc extends Bloc<PosEvent, PosState> {
  /// Repositorio para procesar ventas en backend Node.
  final VentasRepository _ventasRepository;

  /// Usuario operativo de caja en la sesión actual.
  final String _usuarioId;

  /// Constructor principal del PosBloc.
  PosBloc({
    required VentasRepository ventasRepository,
    required String usuarioId,
  }) : _ventasRepository = ventasRepository,
       _usuarioId = usuarioId,
       super(PosState.initial()) {
    // PATRON: BLOC - Aísla reglas de estado y flujo de caja de la UI.
    on<PosItemAdded>(_onItemAdded);
    on<PosItemIncreased>(_onItemIncreased);
    on<PosItemDecreased>(_onItemDecreased);
    on<PosItemRemoved>(_onItemRemoved);
    on<PosCedulaMedicoChanged>(_onCedulaChanged);
    on<PosNombreMedicoChanged>(_onNombreChanged);
    on<PosCheckoutRequested>(_onCheckoutRequested);
    on<PosTicketPreviewCleared>(_onTicketPreviewCleared);
  }

  // CUMPLE HU-18 Y HU-19: GESTION DE CARRITO EN TIEMPO REAL.
  Future<void> _onItemAdded(PosItemAdded event, Emitter<PosState> emit) async {
    final List<PosItem> updated = List<PosItem>.from(state.items);
    final int existingIndex = updated.indexWhere(
      (PosItem item) => item.medicamento.id == event.medicamento.id,
    );

    if (existingIndex >= 0) {
      final PosItem current = updated[existingIndex];
      updated[existingIndex] = current.copyWith(cantidad: current.cantidad + 1);
    } else {
      updated.add(
        PosItem(
          medicamento: event.medicamento,
          cantidad: 1,
          loteSugerido: event.loteSugerido,
        ),
      );
    }

    emit(
      state.copyWith(
        items: updated,
        clearErrorMessage: true,
        clearLastVentaId: true,
      ),
    );
  }

  /// Incrementa en una unidad la cantidad de una línea existente.
  Future<void> _onItemIncreased(
    PosItemIncreased event,
    Emitter<PosState> emit,
  ) async {
    final List<PosItem> updated = state.items
        .map(
          (PosItem item) => item.medicamento.id == event.medicamentoId
              ? item.copyWith(cantidad: item.cantidad + 1)
              : item,
        )
        .toList(growable: false);

    emit(
      state.copyWith(
        items: updated,
        clearErrorMessage: true,
        clearLastVentaId: true,
      ),
    );
  }

  /// Disminuye una unidad o elimina la línea si llega a cero.
  Future<void> _onItemDecreased(
    PosItemDecreased event,
    Emitter<PosState> emit,
  ) async {
    final List<PosItem> updated = <PosItem>[];

    for (final PosItem item in state.items) {
      if (item.medicamento.id != event.medicamentoId) {
        updated.add(item);
      } else if (item.cantidad > 1) {
        updated.add(item.copyWith(cantidad: item.cantidad - 1));
      }
    }

    emit(
      state.copyWith(
        items: updated,
        clearErrorMessage: true,
        clearLastVentaId: true,
      ),
    );
  }

  /// Elimina una línea completa del carrito.
  Future<void> _onItemRemoved(
    PosItemRemoved event,
    Emitter<PosState> emit,
  ) async {
    final List<PosItem> updated = state.items
        .where((PosItem item) => item.medicamento.id != event.medicamentoId)
        .toList(growable: false);

    emit(
      state.copyWith(
        items: updated,
        clearErrorMessage: true,
        clearLastVentaId: true,
      ),
    );
  }

  /// Actualiza el dato de cédula para auditoría médica.
  Future<void> _onCedulaChanged(
    PosCedulaMedicoChanged event,
    Emitter<PosState> emit,
  ) async {
    emit(state.copyWith(cedulaMedico: event.cedula, clearErrorMessage: true));
  }

  /// Actualiza el nombre del médico para auditoría médica.
  Future<void> _onNombreChanged(
    PosNombreMedicoChanged event,
    Emitter<PosState> emit,
  ) async {
    emit(state.copyWith(nombreMedico: event.nombre, clearErrorMessage: true));
  }

  // CUMPLE HU-20 Y HU-21: CALCULO FINAL Y COBRO DE VENTA.
  // CUMPLE HU-22 Y HU-24: VALIDACION DE AUDITORIA PARA CONTROLADOS.
  Future<void> _onCheckoutRequested(
    PosCheckoutRequested event,
    Emitter<PosState> emit,
  ) async {
    if (!state.canCheckout) {
      return;
    }

    emit(
      state.copyWith(
        isSubmitting: true,
        clearErrorMessage: true,
        clearLastVentaId: true,
      ),
    );

    try {
      final double subtotal = state.subtotal;
      final double iva = state.iva;
      final double total = state.total;
      final List<PosItem> ticketItems = List<PosItem>.from(state.items);

      final VentaProcesadaResult result = await _ventasRepository.procesarVenta(
        usuarioId: _usuarioId,
        items: state.items,
        pagos: event.pagos,
        requiereAuditoria: state.tieneControlados,
        cedulaMedico: state.cedulaMedico.trim(),
        nombreMedico: state.nombreMedico.trim(),
      );

      emit(
        state.copyWith(
          items: const <PosItem>[],
          cedulaMedico: '',
          nombreMedico: '',
          isSubmitting: false,
          lastVentaId: result.ventaId,
          lastTicketData: PosTicketData(
            ventaId: result.ventaId,
            items: ticketItems,
            subtotal: subtotal,
            iva: iva,
            total: total,
            pagos: List<PagoVenta>.from(event.pagos),
            cambio: result.cambio,
            fechaVenta: result.fechaVenta,
            cedulaMedico: state.tieneControlados
                ? state.cedulaMedico.trim()
                : null,
          ),
          clearErrorMessage: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }

  /// Limpia el snapshot de ticket cuando el usuario cierra el modal.
  Future<void> _onTicketPreviewCleared(
    PosTicketPreviewCleared event,
    Emitter<PosState> emit,
  ) async {
    emit(state.copyWith(clearLastTicketData: true, clearLastVentaId: true));
  }
}
