import 'package:equatable/equatable.dart';

import '../../../domain/entities/pago_venta.dart';
import '../../../domain/entities/pos_item.dart';

/// Snapshot de ticket para impresión después de cobrar.
class PosTicketData extends Equatable {
  /// Folio de venta generado por backend.
  final String ventaId;

  /// Líneas vendidas en la operación.
  final List<PosItem> items;

  /// Subtotal vendido.
  final double subtotal;

  /// IVA vendido.
  final double iva;

  /// Total vendido.
  final double total;

  /// Pagos aplicados en la venta.
  final List<PagoVenta> pagos;

  /// Cambio devuelto por backend.
  final double cambio;

  /// Cédula médica registrada cuando aplica.
  final String? cedulaMedico;

  /// Fecha de la transacción mostrada en ticket.
  final DateTime fechaVenta;

  /// Constructor principal del snapshot de ticket.
  const PosTicketData({
    required this.ventaId,
    required this.items,
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.pagos,
    required this.cambio,
    required this.fechaVenta,
    this.cedulaMedico,
  });

  @override
  List<Object?> get props => <Object?>[
    ventaId,
    items,
    subtotal,
    iva,
    total,
    pagos,
    cambio,
    fechaVenta,
    cedulaMedico,
  ];
}

/// Estado inmutable del POS para carrito, totales y cobro.
class PosState extends Equatable {
  /// Líneas del carrito de compra actual.
  final List<PosItem> items;

  /// Cédula del médico para auditoría de controlados.
  final String cedulaMedico;

  /// Nombre del médico para auditoría de controlados.
  final String nombreMedico;

  /// Bandera de envío de venta en progreso.
  final bool isSubmitting;

  /// Mensaje de error de negocio o transporte.
  final String? errorMessage;

  /// Último identificador de venta procesada.
  final String? lastVentaId;

  /// Snapshot del ticket para impresión térmica.
  final PosTicketData? lastTicketData;

  /// Constructor principal del estado de POS.
  const PosState({
    required this.items,
    required this.cedulaMedico,
    required this.nombreMedico,
    required this.isSubmitting,
    this.errorMessage,
    this.lastVentaId,
    this.lastTicketData,
  });

  /// Crea el estado inicial del POS.
  factory PosState.initial() {
    return const PosState(
      items: <PosItem>[],
      cedulaMedico: '',
      nombreMedico: '',
      isSubmitting: false,
      errorMessage: null,
      lastVentaId: null,
      lastTicketData: null,
    );
  }

  /// Retorna el subtotal acumulado de líneas.
  double get subtotal => items.fold<double>(
    0,
    (double acum, PosItem item) => acum + item.subtotal,
  );

  /// Retorna el monto de IVA para el subtotal actual.
  double get iva => subtotal * 0.16;

  /// Retorna el total a cobrar con IVA incluido.
  double get total => subtotal + iva;

  /// Indica si el carrito contiene medicamentos controlados.
  bool get tieneControlados =>
      items.any((PosItem item) => item.medicamento.requiereReceta);

  /// Indica si el formulario de auditoría médica es válido.
  bool get auditoriaCompleta =>
      cedulaMedico.trim().isNotEmpty && nombreMedico.trim().isNotEmpty;

  /// Indica si el botón de cobro debe estar habilitado.
  bool get canCheckout =>
      items.isNotEmpty &&
      (!tieneControlados || auditoriaCompleta) &&
      !isSubmitting;

  /// Crea una copia del estado actual con cambios puntuales.
  PosState copyWith({
    List<PosItem>? items,
    String? cedulaMedico,
    String? nombreMedico,
    bool? isSubmitting,
    String? errorMessage,
    String? lastVentaId,
    PosTicketData? lastTicketData,
    bool clearErrorMessage = false,
    bool clearLastVentaId = false,
    bool clearLastTicketData = false,
  }) {
    return PosState(
      items: items ?? this.items,
      cedulaMedico: cedulaMedico ?? this.cedulaMedico,
      nombreMedico: nombreMedico ?? this.nombreMedico,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      lastVentaId: clearLastVentaId ? null : (lastVentaId ?? this.lastVentaId),
      lastTicketData: clearLastTicketData
          ? null
          : (lastTicketData ?? this.lastTicketData),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    items,
    cedulaMedico,
    nombreMedico,
    isSubmitting,
    errorMessage,
    lastVentaId,
    lastTicketData,
  ];
}
