import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../pos/domain/entities/pago_venta.dart';
import '../../../pos/presentation/bloc/pos/pos_state.dart';
import '../../domain/entities/reporte_turno.dart';
import '../../domain/entities/venta_reporte.dart';

/// Repositorio de reportes y auditoría contra Node.js.
class ReportesRepository {
  /// Endpoint para obtener detalle de ticket histórico.
  static const String _obtenerVentaEndpoint =
      'http://localhost:3000/api/ventas';

  /// Endpoint del backend Python para reintegrar inventario al anular.
  static const String _reintegrarInventarioEndpoint =
      'http://localhost:8000/api/v1/inventario/reintegrar';

  /// Cliente HTTP compartido.
  final ApiClient _apiClient;

  /// Constructor principal del repositorio de reportes.
  const ReportesRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  /// Obtiene reporte de ventas con filtro temporal para escalabilidad.
  Future<ReporteTurno> obtenerReporteTurno({
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('tickets_ventas')
        .where(
          'fechaVenta',
          isGreaterThanOrEqualTo: Timestamp.fromDate(fechaInicio),
        )
        .where('fechaVenta', isLessThanOrEqualTo: Timestamp.fromDate(fechaFin))
        .orderBy('fechaVenta', descending: true);

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

    final List<Map<String, dynamic>> ventasRaw = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = doc.data();
          final Map<String, dynamic> normalizado = _normalizarFechasFirestore(
            data,
          );

          return <String, dynamic>{
            'ventaId': data['ventaId'] ?? doc.id,
            ...normalizado,
          };
        })
        .toList(growable: false);

    // Obtener nombres reales de empleados desde Firestore
    final Map<String, String> nombresEmpleados = await _obtenerNombresEmpleados(
      ventasRaw,
    );

    // Mapear ventas con nombres reales del perfil
    final List<VentaReporte> ventas = ventasRaw
        .map((Map<String, dynamic> json) {
          final String usuarioId = json['usuarioId']?.toString() ?? '';
          if (usuarioId.isNotEmpty && nombresEmpleados.containsKey(usuarioId)) {
            json['cajero'] = nombresEmpleados[usuarioId];
          }
          return VentaReporte.fromJson(json);
        })
        .toList(growable: false);

    final double totalVendido = ventas.fold<double>(
      0,
      (double acc, VentaReporte v) => acc + v.total,
    );
    final int totalTickets = ventas.length;

    return ReporteTurno(
      totalVendido: totalVendido,
      totalTickets: totalTickets,
      ventas: ventas,
    );
  }

  /// Realiza un JOIN con Firestore para obtener nombres reales de empleados.
  Future<Map<String, String>> _obtenerNombresEmpleados(
    List<dynamic> ventasRaw,
  ) async {
    // Extraer usuarioIds únicos de las ventas
    final Set<String> usuarioIds = <String>{};
    for (final dynamic v in ventasRaw) {
      if (v is Map<String, dynamic>) {
        final String? id = v['usuarioId']?.toString();
        if (id != null && id.isNotEmpty) {
          usuarioIds.add(id);
        }
      }
    }

    if (usuarioIds.isEmpty) {
      return <String, String>{};
    }

    try {
      // Query a Firestore para obtener perfiles_seguridad
      final Map<String, String> resultados = <String, String>{};

      // Firestore whereIn permite maximo 10 ids por consulta.
      final List<String> ids = usuarioIds.toList(growable: false);
      for (int i = 0; i < ids.length; i += 10) {
        final int end = (i + 10) > ids.length ? ids.length : (i + 10);
        final List<String> chunk = ids.sublist(i, end);

        final QuerySnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection('perfiles_seguridad')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          final Map<String, dynamic> perfil = doc.data();
          resultados[doc.id] =
              (perfil['nombre'] ?? perfil['displayName'] ?? doc.id).toString();
        }
      }

      return resultados;
    } catch (e) {
      // Si Firestore falla, retorna mapa vacío (usa los IDs crudos)
      return <String, String>{};
    }
  }

  /// Convierte Timestamp de Firestore a mapa estandar para parseo estricto.
  Map<String, dynamic> _normalizarFechasFirestore(Map<String, dynamic> source) {
    final Map<String, dynamic> result = <String, dynamic>{};

    source.forEach((String key, dynamic value) {
      if (value is Timestamp) {
        result[key] = <String, dynamic>{
          '_seconds': value.seconds,
          '_nanoseconds': value.nanoseconds,
        };
      } else if (value is Map<String, dynamic>) {
        result[key] = _normalizarFechasFirestore(value);
      } else if (value is List) {
        result[key] = value.map(_normalizarColeccionFirestore).toList();
      } else {
        result[key] = value;
      }
    });

    return result;
  }

  dynamic _normalizarColeccionFirestore(dynamic value) {
    if (value is Timestamp) {
      return <String, dynamic>{
        '_seconds': value.seconds,
        '_nanoseconds': value.nanoseconds,
      };
    }

    if (value is Map<String, dynamic>) {
      return _normalizarFechasFirestore(value);
    }

    if (value is List) {
      return value.map(_normalizarColeccionFirestore).toList();
    }

    return value;
  }

  /// Solicita anulación de venta e inicio de rollback Saga.
  Future<void> anularVenta(String ventaId, String motivo) async {
    await FirebaseFirestore.instance
        .collection('tickets_ventas')
        .doc(ventaId)
        .update(<String, dynamic>{
          'estado': 'anulada',
          'razonAnulacion': motivo,
          'fechaAnulacion': FieldValue.serverTimestamp(),
          'fechaActualizacion': FieldValue.serverTimestamp(),
        });

    await _apiClient.post(
      _reintegrarInventarioEndpoint,
      requiresAuth: false,
      data: <String, dynamic>{'ventaId': ventaId, 'motivo': motivo},
    );
  }

  /// Obtiene el snapshot de ticket para ver/reimprimir una venta historica.
  Future<PosTicketData> obtenerTicketHistorico(VentaReporte venta) async {
    if (venta.tieneDetalleTicket) {
      final List<PagoVenta> pagos = venta.pagos.isNotEmpty
          ? venta.pagos
          : <PagoVenta>[
              PagoVenta(
                tipo: venta.metodoPago.isNotEmpty
                    ? venta.metodoPago
                    : 'efectivo',
                monto: venta.total,
              ),
            ];

      return PosTicketData(
        ventaId: venta.ventaId,
        items: venta.lineas,
        subtotal: venta.subtotal,
        iva: venta.iva,
        total: venta.total,
        pagos: pagos,
        cambio: venta.cambio,
        cedulaMedico: venta.cedulaMedico,
        fechaVenta: venta.fecha,
      );
    }

    final Response<dynamic> response = await _apiClient.get(
      '$_obtenerVentaEndpoint/${venta.ventaId}',
      requiresAuth: true,
    );

    final dynamic payload = response.data;
    final Map<String, dynamic> root = payload is Map<String, dynamic>
        ? payload
        : <String, dynamic>{};
    final Map<String, dynamic> data =
        (root['data'] as Map<String, dynamic>?) ?? root;

    final VentaReporte ventaDetallada = VentaReporte.fromJson(data);
    final List<PagoVenta> pagosFinales = ventaDetallada.pagos.isNotEmpty
        ? ventaDetallada.pagos
        : <PagoVenta>[
            PagoVenta(
              tipo: venta.metodoPago.isNotEmpty ? venta.metodoPago : 'efectivo',
              monto: ventaDetallada.total,
            ),
          ];

    return PosTicketData(
      ventaId: ventaDetallada.ventaId,
      items: ventaDetallada.lineas,
      subtotal: ventaDetallada.subtotal,
      iva: ventaDetallada.iva,
      total: ventaDetallada.total,
      pagos: pagosFinales,
      cambio: ventaDetallada.cambio,
      cedulaMedico: ventaDetallada.cedulaMedico,
      fechaVenta: ventaDetallada.fecha,
    );
  }
}
