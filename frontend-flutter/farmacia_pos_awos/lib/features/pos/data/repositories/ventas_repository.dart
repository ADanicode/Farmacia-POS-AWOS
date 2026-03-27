import '../../../../core/network/app_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/pago_venta.dart';
import '../../domain/entities/pos_item.dart';

/// Resultado simplificado de la venta procesada por backend Node.
class VentaProcesadaResult {
  /// Identificador único de la venta.
  final String ventaId;

  /// Total final de la venta.
  final double total;

  /// Cambio calculado y devuelto por backend.
  final double cambio;

  /// Monto recibido real en caja reportado por backend.
  final double montoRecibido;

  /// Fecha real de la venta entregada por backend.
  final DateTime fechaVenta;

  /// Constructor del resultado de venta procesada.
  const VentaProcesadaResult({
    required this.ventaId,
    required this.total,
    required this.montoRecibido,
    required this.cambio,
    required this.fechaVenta,
  });
}

/// Repositorio de ventas para orquestación Saga en Node.js.
class VentasRepository {
  static final RegExp _timestampStringRegExp = RegExp(
    r'^Timestamp\(seconds=(\d+),\s*nanoseconds=(\d+)\)$',
  );

  /// Endpoint de procesamiento de venta en backend Node.
  static String get _ventasEndpoint =>
      '${AppEndpoints.nodeApi}/ventas/procesar';

  /// Porcentaje de IVA esperado por backend Node.
  static const double _ivaPorcentaje = 16;

  /// Cliente HTTP compartido por toda la aplicación.
  final ApiClient _apiClient;

  /// Constructor principal del repositorio de ventas.
  const VentasRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  // PATRON: REPOSITORY - Encapsula mapeo DTO de venta y transporte HTTP.
  // CUMPLE HU-18, HU-19, HU-20 Y HU-21: ORQUESTACION Y COBRO DE VENTA EN CAJA.
  // CUMPLE HU-22 Y HU-24: ENVIO DE DATOS DE RECETA SI HAY CONTROLADOS.
  /// Procesa una venta completa con sus líneas y datos de auditoría opcionales.
  Future<VentaProcesadaResult> procesarVenta({
    required String usuarioId,
    required List<PosItem> items,
    required List<PagoVenta> pagos,
    required double montoRecibido,
    required bool requiereAuditoria,
    String? cedulaMedico,
    String? nombreMedico,
  }) async {
    final double subtotalRaw = items.fold<double>(
      0,
      (double acum, PosItem item) => acum + item.subtotal,
    );
    final double subtotal = _redondearMoneda(subtotalRaw);
    final double total = _redondearMoneda(
      subtotal + (subtotal * (_ivaPorcentaje / 100)),
    );
    final Map<String, dynamic> payload = <String, dynamic>{
      'usuarioId': usuarioId,
      'lineas': items
          .map((PosItem item) {
            final Map<String, dynamic> linea = <String, dynamic>{
              // INVENTARIO PYTHON ESPERA EL ID NUMERICO DEL MEDICAMENTO.
              'codigoProducto': item.medicamento.id.toString(),
              'nombreProducto': item.medicamento.nombre,
              'cantidad': item.cantidad,
              'precioUnitario': item.medicamento.precio,
              'esControlado': item.medicamento.requiereReceta,
            };

            if (item.loteSugerido != null && item.loteSugerido!.isNotEmpty) {
              linea['lote'] = item.loteSugerido;
            }

            return linea;
          })
          .toList(growable: false),
      'pagos': pagos
          .map((PagoVenta pago) => pago.toJson())
          .toList(growable: false),
      'montoRecibido': _redondearMoneda(montoRecibido),
      'ivaPercentaje': _ivaPorcentaje,
      'subtotal': subtotal,
      'total': total,
    };

    if (requiereAuditoria) {
      payload['datosReceta'] = <String, dynamic>{
        'ciMedico': cedulaMedico,
        'nombreMedico': nombreMedico,
        'fechaReceta': DateTime.now().toIso8601String(),
      };
    }

    final response = await _apiClient.post(_ventasEndpoint, data: payload);

    final Map<String, dynamic> body = response.data as Map<String, dynamic>;
    final bool success = (body['success'] as bool?) ?? false;

    if (!success) {
      throw Exception(
        (body['error'] as String?) ?? 'No se pudo procesar la venta',
      );
    }

    final Map<String, dynamic> data = body['data'] as Map<String, dynamic>;
    final DateTime fechaVenta = _parseFechaVenta(data);

    return VentaProcesadaResult(
      ventaId: (data['ventaId'] as String?) ?? '',
      total: (data['total'] as num?)?.toDouble() ?? 0,
      montoRecibido:
          (data['montoRecibido'] as num?)?.toDouble() ??
          _redondearMoneda(montoRecibido),
      cambio: (data['cambio'] as num?)?.toDouble() ?? 0,
      fechaVenta: fechaVenta,
    );
  }

  /// Redondea un valor monetario a dos decimales.
  double _redondearMoneda(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  /// Parsea fecha de backend de forma estricta para evitar Epoch silencioso.
  DateTime _parseFechaVenta(Map<String, dynamic> json) {
    final String ventaId = (json['ventaId'] ?? json['id'] ?? '').toString();
    final dynamic fechaRaw = json['fechaVenta'] ?? json['fechaCreacion'];

    if (fechaRaw == null) {
      throw FormatException(
        'CRITICO: La fecha viene nula desde el backend para el ticket $ventaId',
      );
    }

    try {
      DateTime fechaParseada;

      if (fechaRaw is Map && fechaRaw.containsKey('_seconds')) {
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
}
