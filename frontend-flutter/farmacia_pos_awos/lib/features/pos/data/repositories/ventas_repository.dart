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

  /// Constructor del resultado de venta procesada.
  const VentaProcesadaResult({
    required this.ventaId,
    required this.total,
    required this.cambio,
  });
}

/// Repositorio de ventas para orquestación Saga en Node.js.
class VentasRepository {
  /// Endpoint de procesamiento de venta en backend Node.
  static const String _ventasEndpoint =
      'http://localhost:3000/api/ventas/procesar';

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
    return VentaProcesadaResult(
      ventaId: (data['ventaId'] as String?) ?? '',
      total: (data['total'] as num?)?.toDouble() ?? 0,
      cambio: (data['cambio'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Redondea un valor monetario a dos decimales.
  double _redondearMoneda(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
