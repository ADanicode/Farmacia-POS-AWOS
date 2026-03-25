import 'package:equatable/equatable.dart';

/// Entidad de lote próximo a caducar para monitor de riesgos.
class LoteRiesgo extends Equatable {
  /// ID del lote.
  final int loteId;

  /// Número de lote.
  final String numeroLote;

  /// ID del medicamento.
  final int medicamentoId;

  /// Nombre del medicamento.
  final String medicamentoNombre;

  /// Código de barras del medicamento.
  final String codigoBarras;

  /// Fecha de caducidad en formato ISO.
  final String fechaCaducidad;

  /// Días restantes para caducar.
  final int diasRestantes;

  /// Stock disponible del lote.
  final int stockActual;

  /// Nivel de riesgo (CRITICO, URGENTE, ALERTA).
  final String nivelRiesgo;

  /// Constructor principal de lote en riesgo.
  const LoteRiesgo({
    required this.loteId,
    required this.numeroLote,
    required this.medicamentoId,
    required this.medicamentoNombre,
    required this.codigoBarras,
    required this.fechaCaducidad,
    required this.diasRestantes,
    required this.stockActual,
    required this.nivelRiesgo,
  });

  /// Crea entidad a partir de JSON del backend Python.
  factory LoteRiesgo.fromJson(Map<String, dynamic> json) {
    return LoteRiesgo(
      loteId: (json['lote_id'] as num?)?.toInt() ?? 0,
      numeroLote: (json['numero_lote'] as String?) ?? '',
      medicamentoId: (json['medicamento_id'] as num?)?.toInt() ?? 0,
      medicamentoNombre: (json['medicamento_nombre'] as String?) ?? '',
      codigoBarras: (json['codigo_barras'] as String?) ?? '',
      fechaCaducidad: (json['fecha_caducidad'] as String?) ?? '',
      diasRestantes: (json['dias_restantes'] as num?)?.toInt() ?? 0,
      stockActual: (json['stock_actual'] as num?)?.toInt() ?? 0,
      nivelRiesgo: ((json['nivel_riesgo'] as String?) ?? 'ALERTA')
          .toUpperCase(),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    loteId,
    numeroLote,
    medicamentoId,
    medicamentoNombre,
    codigoBarras,
    fechaCaducidad,
    diasRestantes,
    stockActual,
    nivelRiesgo,
  ];
}
