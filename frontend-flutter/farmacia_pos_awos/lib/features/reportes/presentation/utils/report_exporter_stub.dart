import '../../domain/entities/venta_reporte.dart';
import 'dart:typed_data';

Future<String?> exportVentasCsv({
  required List<VentaReporte> ventas,
  required String fileName,
}) async {
  return null;
}

Future<String?> saveReportFile({
  required Uint8List bytes,
  required String fileName,
  required String extension,
  required String mimeType,
}) async {
  return null;
}
