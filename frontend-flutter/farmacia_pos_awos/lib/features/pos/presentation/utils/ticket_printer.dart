import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/pos_item.dart';

/// Servicio de impresión para ticket térmico de 80mm.
class TicketPrinter {
  /// Genera e imprime el ticket térmico de la venta procesada.
  static Future<void> imprimirTicket({
    required String ventaId,
    required String cajero,
    required String rol,
    required List<PosItem> items,
    required double subtotal,
    required double iva,
    required double total,
    required double montoRecibido,
    required double cambio,
    String? cedulaMedica,
  }) async {
    final pw.Document doc = pw.Document();

    const double mm = PdfPageFormat.mm;
    final PdfPageFormat format = PdfPageFormat(
      80 * mm,
      double.infinity,
      marginAll: 4 * mm,
    );

    // CUMPLE HU-31 Y HU-32: ticket térmico 80mm con trazabilidad de lote.
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: pw.Font.courier()),
        build: (pw.Context context) {
          final List<pw.Widget> rows = <pw.Widget>[];

          for (final PosItem item in items) {
            rows.add(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text(
                    '${item.medicamento.nombre} x${item.cantidad}',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Lote: ${item.loteSugerido?.isNotEmpty == true ? item.loteSugerido : 'N/D'}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      '\$ ${(item.subtotal).toStringAsFixed(2)} MXN',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                ],
              ),
            );
          }

          return <pw.Widget>[
            pw.Center(
              child: pw.Text(
                'FARMACIA AWOS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                'Ticket térmico 80mm',
                style: pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('------------------------------'),
            pw.Text('Folio: $ventaId', style: pw.TextStyle(fontSize: 8)),
            pw.Text('Cajero: $cajero ($rol)', style: pw.TextStyle(fontSize: 8)),
            pw.Text(
              'Fecha: ${DateTime.now().toIso8601String()}',
              style: pw.TextStyle(fontSize: 8),
            ),
            pw.Text('------------------------------'),
            ...rows,
            pw.Text('------------------------------'),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Subtotal: \$ ${subtotal.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'IVA:      \$ ${iva.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'TOTAL:    \$ ${total.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'RECIBIDO: \$ ${montoRecibido.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'CAMBIO:   \$ ${cambio.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 9),
              ),
            ),
            if (cedulaMedica != null &&
                cedulaMedica.trim().isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 4),
              pw.Text('------------------------------'),
              pw.Text(
                'AUDITORIA MEDICA',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Cedula Medica: $cedulaMedica',
                style: pw.TextStyle(fontSize: 8),
              ),
            ],
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                'Gracias por su compra',
                style: pw.TextStyle(fontSize: 8),
              ),
            ),
          ];
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat _) async => _buildBytes(doc),
      );
    } catch (error, stackTrace) {
      debugPrint('[TicketPrinter] Error al imprimir ticket: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Serializa el documento PDF a bytes.
  static Future<Uint8List> _buildBytes(pw.Document doc) async {
    return doc.save();
  }
}
