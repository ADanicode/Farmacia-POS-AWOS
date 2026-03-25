import '../../domain/entities/venta_reporte.dart';
import 'report_exporter_stub.dart'
    if (dart.library.html) 'report_exporter_web.dart'
    if (dart.library.io) 'report_exporter_io.dart'
    as impl;

Future<String?> exportVentasCsv({
  required List<VentaReporte> ventas,
  required String fileName,
}) {
  return impl.exportVentasCsv(ventas: ventas, fileName: fileName);
}
