import 'package:equatable/equatable.dart';

import '../../../pos/domain/entities/medicamento.dart';
import '../../../pos/domain/entities/pago_venta.dart';
import '../../../pos/domain/entities/pos_item.dart';

/// Entidad de una venta dentro del reporte de turno.
class VentaReporte extends Equatable {
  static final RegExp _timestampStringRegExp = RegExp(
    r'^Timestamp\(seconds=(\d+),\s*nanoseconds=(\d+)\)$',
  );

  /// Identificador interno de la venta.
  final String ventaId;

  /// Folio comercial mostrado al cajero.
  final String folio;

  /// Fecha de creación de la venta.
  final DateTime fecha;

  /// Nombre del cajero.
  final String cajero;

  /// Método de pago principal.
  final String metodoPago;

  /// Total final de la venta.
  final double total;

  /// Estado actual de la venta (procesada, anulada, etc.).
  final String estado;

  /// Líneas históricas de la venta cuando el backend las incluye.
  final List<PosItem> lineas;

  /// Métodos de pago históricos cuando el backend los incluye.
  final List<PagoVenta> pagos;

  /// Subtotal histórico del ticket.
  final double subtotal;

  /// IVA histórico del ticket.
  final double iva;

  /// Cambio histórico del ticket.
  final double cambio;

  /// Monto recibido histórico del ticket.
  final double montoRecibido;

  /// Cédula médica si la venta tuvo auditoría.
  final String? cedulaMedico;

  /// Constructor principal de venta en reporte.
  const VentaReporte({
    required this.ventaId,
    required this.folio,
    required this.fecha,
    required this.cajero,
    required this.metodoPago,
    required this.total,
    required this.estado,
    this.lineas = const <PosItem>[],
    this.pagos = const <PagoVenta>[],
    this.subtotal = 0,
    this.iva = 0,
    this.cambio = 0,
    this.montoRecibido = 0,
    this.cedulaMedico,
  });

  /// Crea entidad desde JSON de Node.js.
  factory VentaReporte.fromJson(Map<String, dynamic> json) {
    final DateTime fecha = parseBackendDate(
      json['fechaVenta'] ??
          json['fecha'] ??
          json['createdAt'] ??
          json['fechaHora'] ??
          json['fechaCreacion'],
      ventaId: (json['ventaId'] ?? json['id'] ?? json['_id'] ?? '').toString(),
    );

    final List<PosItem> lineas = _parseLineas(
      (json['lineas'] as List<dynamic>?) ??
          (json['items'] as List<dynamic>?) ??
          (json['productos'] as List<dynamic>?) ??
          <dynamic>[],
    );
    final List<PagoVenta> pagos = _parsePagos(
      (json['pagos'] as List<dynamic>?) ?? <dynamic>[],
    );
    final double subtotal =
        (json['subtotal'] as num?)?.toDouble() ??
        lineas.fold<double>(
          0,
          (double acc, PosItem item) => acc + item.subtotal,
        );
    final double iva =
        (json['iva'] as num?)?.toDouble() ??
        (json['impuesto'] as num?)?.toDouble() ??
        0;
    final double total =
        (json['total'] as num?)?.toDouble() ?? (subtotal + iva);

    final String ventaId = (json['ventaId'] ?? json['id'] ?? json['_id'] ?? '')
        .toString();
    final String folio = (json['folio'] ?? json['ventaId'] ?? json['id'] ?? '')
        .toString();
    final String metodoPago = _resolverMetodoPago(json['metodoPago'], pagos);

    return VentaReporte(
      ventaId: ventaId,
      folio: folio,
      fecha: fecha,
      cajero:
          (json['cajero'] ?? json['usuarioNombre'] ?? json['usuarioId'] ?? '')
              .toString(),
      metodoPago: metodoPago,
      total: total,
      estado: ((json['estado'] ?? 'procesada').toString()).toLowerCase(),
      lineas: lineas,
      pagos: pagos,
      subtotal: subtotal,
      iva: iva,
      montoRecibido:
          (json['montoRecibido'] as num?)?.toDouble() ??
          (((json['total'] as num?)?.toDouble() ?? total) +
              ((json['cambio'] as num?)?.toDouble() ?? 0)),
      cambio: (json['cambio'] as num?)?.toDouble() ?? 0,
      cedulaMedico: json['datosReceta'] is Map<String, dynamic>
          ? json['datosReceta']['ciMedico']?.toString()
          : null,
    );
  }

  /// Parsea fechas de backend de forma estricta y sin fallback silencioso.
  static DateTime parseBackendDate(dynamic raw, {required String ventaId}) {
    final dynamic fechaRaw = raw;
    if (fechaRaw == null) {
      throw FormatException(
        'CRITICO: La fecha viene nula desde el backend para el ticket $ventaId',
      );
    }

    try {
      DateTime fechaParseada;

      if (fechaRaw is DateTime) {
        fechaParseada = fechaRaw;
      } else if (fechaRaw is Map && fechaRaw.containsKey('_seconds')) {
        final int? seconds = int.tryParse(fechaRaw['_seconds'].toString());
        if (seconds == null) {
          throw FormatException('Formato de fecha desconocido: $fechaRaw');
        }
        fechaParseada = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      } else if (fechaRaw is String) {
        final RegExpMatch? tsMatch = _timestampStringRegExp.firstMatch(
          fechaRaw,
        );
        if (tsMatch != null) {
          final int seconds = int.parse(tsMatch.group(1)!);
          final int nanoseconds = int.parse(tsMatch.group(2)!);
          final int millis = (seconds * 1000) + (nanoseconds ~/ 1000000);
          fechaParseada = DateTime.fromMillisecondsSinceEpoch(millis);
        } else {
          fechaParseada = DateTime.parse(fechaRaw);
        }
      } else if (fechaRaw is int) {
        final int millis = fechaRaw > 9999999999 ? fechaRaw : fechaRaw * 1000;
        fechaParseada = DateTime.fromMillisecondsSinceEpoch(millis);
      } else if (fechaRaw is num) {
        final int rawInt = fechaRaw.toInt();
        final int millis = rawInt > 9999999999 ? rawInt : rawInt * 1000;
        fechaParseada = DateTime.fromMillisecondsSinceEpoch(millis);
      } else {
        throw FormatException('Formato de fecha desconocido: $fechaRaw');
      }

      return fechaParseada.toLocal();
    } catch (e) {
      // ignore: avoid_print
      print('ERROR CRITICO AL PARSEAR FECHA: $fechaRaw. Venta ID: $ventaId');
      rethrow;
    }
  }

  static List<PosItem> _parseLineas(List<dynamic> rawLineas) {
    return rawLineas
        .whereType<Map<String, dynamic>>()
        .toList(growable: false)
        .asMap()
        .entries
        .map((MapEntry<int, Map<String, dynamic>> entry) {
          final int index = entry.key;
          final Map<String, dynamic> linea = entry.value;
          final dynamic idRaw =
              linea['medicamentoId'] ??
              linea['id'] ??
              linea['codigoProducto'] ??
              (index + 1);

          final Medicamento medicamento = Medicamento(
            id: int.tryParse(idRaw.toString()) ?? (index + 1),
            nombre: (linea['nombreProducto'] ?? linea['nombre'] ?? 'Producto')
                .toString(),
            codigoBarras: (linea['codigoProducto'] ?? linea['codigo'] ?? '')
                .toString(),
            precio:
                (linea['precioUnitario'] as num?)?.toDouble() ??
                (linea['precio'] as num?)?.toDouble() ??
                0,
            requiereReceta: (linea['esControlado'] as bool?) ?? false,
            categoria: 'Historico',
            proveedor: 'Historico',
          );

          return PosItem(
            medicamento: medicamento,
            cantidad: (linea['cantidad'] as num?)?.toInt() ?? 1,
            loteSugerido: linea['lote']?.toString(),
          );
        })
        .toList(growable: false);
  }

  static List<PagoVenta> _parsePagos(List<dynamic> rawPagos) {
    return rawPagos
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> pago) {
          return PagoVenta(
            tipo: (pago['tipo'] ?? 'efectivo').toString(),
            monto: (pago['monto'] as num?)?.toDouble() ?? 0,
            referencia: pago['referencia']?.toString(),
          );
        })
        .where((PagoVenta pago) => pago.monto > 0)
        .toList(growable: false);
  }

  bool get tieneDetalleTicket => lineas.isNotEmpty;

  /// Resuelve el método de pago desde el campo directo o desde los pagos.
  static String _resolverMetodoPago(
    dynamic metodoPagoRaw,
    List<PagoVenta> pagos,
  ) {
    final String? directo = metodoPagoRaw?.toString().trim();
    if (directo != null && directo.isNotEmpty && directo != 'N/D') {
      return directo;
    }

    if (pagos.isEmpty) {
      return 'N/D';
    }

    if (pagos.length == 1) {
      return _normalizarTipoPago(pagos.first.tipo);
    }

    return 'Mixto';
  }

  static String _normalizarTipoPago(String tipo) {
    final String normalized = tipo.trim().toLowerCase();
    if (normalized.contains('efectivo') || normalized.contains('cash')) {
      return 'Efectivo';
    }
    if (normalized.contains('tarjeta') ||
        normalized.contains('credito') ||
        normalized.contains('debito') ||
        normalized.contains('visa') ||
        normalized.contains('mastercard')) {
      return 'Tarjeta';
    }
    return tipo;
  }

  @override
  List<Object?> get props => <Object?>[
    ventaId,
    folio,
    fecha,
    cajero,
    metodoPago,
    total,
    estado,
    lineas,
    pagos,
    subtotal,
    iva,
    montoRecibido,
    cambio,
    cedulaMedico,
  ];
}
