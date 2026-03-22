import 'package:equatable/equatable.dart';

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
