import 'package:equatable/equatable.dart';

import '../../../domain/entities/pos_item.dart';

/// Eventos del SearchBloc para búsqueda de catálogo.
sealed class SearchEvent extends Equatable {
  /// Constructor base de eventos de búsqueda.
  const SearchEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// Evento para notificar cambio en el texto de búsqueda.
class SearchQueryChanged extends SearchEvent {
  /// Texto ingresado por el usuario.
  final String query;

  /// Constructor del evento de cambio de texto.
  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => <Object?>[query];
}

/// Evento para sincronizar catálogo silenciosamente en segundo plano.
class SearchCatalogSyncRequested extends SearchEvent {
  /// Fuerza recarga remota del catálogo y stock visible.
  final bool forceRefresh;

  /// Constructor del evento de sincronización.
  const SearchCatalogSyncRequested({this.forceRefresh = true});

  @override
  List<Object?> get props => <Object?>[forceRefresh];
}

/// Evento para aplicar descuento local de stock tras una venta exitosa.
class SearchStockDiscountApplied extends SearchEvent {
  /// Ítems vendidos en la última operación exitosa.
  final List<PosItem> vendidos;

  /// Constructor del evento de descuento local.
  const SearchStockDiscountApplied(this.vendidos);

  @override
  List<Object?> get props => <Object?>[vendidos];
}
