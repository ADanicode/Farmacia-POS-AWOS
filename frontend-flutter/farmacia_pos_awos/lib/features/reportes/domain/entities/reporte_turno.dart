import 'package:equatable/equatable.dart';

import 'venta_reporte.dart';

/// Entidad agregada del reporte de turno.
class ReporteTurno extends Equatable {
  /// Total vendido acumulado.
  final double totalVendido;

  /// Cantidad total de tickets.
  final int totalTickets;

  /// Ventas del turno.
  final List<VentaReporte> ventas;

  /// Constructor principal de reporte de turno.
  const ReporteTurno({
    required this.totalVendido,
    required this.totalTickets,
    required this.ventas,
  });

  /// Reporte vacío por defecto.
  factory ReporteTurno.empty() {
    return const ReporteTurno(
      totalVendido: 0,
      totalTickets: 0,
      ventas: <VentaReporte>[],
    );
  }

  @override
  List<Object?> get props => <Object?>[totalVendido, totalTickets, ventas];
}
