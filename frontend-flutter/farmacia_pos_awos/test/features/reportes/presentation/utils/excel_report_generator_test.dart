import 'package:flutter_test/flutter_test.dart';
import 'package:farmacia_pos_awos/features/reportes/domain/entities/venta_reporte.dart';
import 'package:farmacia_pos_awos/features/reportes/presentation/utils/excel_report_generator.dart';

void main() {
  test('genera workbook xlsx multi-hoja sin lanzar excepciones', () async {
    final ExcelReportGenerator generator = ExcelReportGenerator();

    final List<VentaReporte> ventas = <VentaReporte>[
      VentaReporte(
        ventaId: '1',
        folio: 'F-001',
        fecha: DateTime(2026, 4, 8, 10, 30),
        cajero: 'Caja 1',
        metodoPago: 'Efectivo',
        total: 116,
        estado: 'procesada',
        subtotal: 100,
        iva: 16,
        cedulaMedico: 'ABC123',
      ),
      VentaReporte(
        ventaId: '2',
        folio: 'F-002',
        fecha: DateTime(2026, 4, 8, 11, 45),
        cajero: 'Caja 2',
        metodoPago: 'Tarjeta',
        total: 232,
        estado: 'procesada',
        subtotal: 200,
        iva: 32,
      ),
    ];

    final bytes = await generator.generateVentasXlsx(ventas: ventas);

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });
}
