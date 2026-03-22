import 'package:equatable/equatable.dart';

/// Entidad de stock consolidado por medicamento.
class MedicamentoStock extends Equatable {
  /// ID del medicamento.
  final int medicamentoId;

  /// Stock total disponible en lotes vigentes.
  final int stockTotal;

  /// Lote FEFO principal sugerido para despacho.
  final String? lotePrincipal;

  /// Constructor principal de stock por medicamento.
  const MedicamentoStock({
    required this.medicamentoId,
    required this.stockTotal,
    this.lotePrincipal,
  });

  @override
  List<Object?> get props => <Object?>[
    medicamentoId,
    stockTotal,
    lotePrincipal,
  ];
}
