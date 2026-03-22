import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/auth_session.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC para flujo de autenticación SSO con Google.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// Web Client ID de Firebase para Google Sign-In en Flutter Web.
  static const String firebaseWebClientId =
      '888412294693-vpqt8c0mhugv1ktra7qhhhi7ibsrcicf.apps.googleusercontent.com';

  /// Repositorio de autenticación que comunica con backend Node.
  final AuthRepository _authRepository;

  /// Cliente Google Sign-In oficial para autenticación nativa.
  final GoogleSignIn _googleSignIn;

  /// Constructor principal del AuthBloc.
  AuthBloc({required AuthRepository authRepository, GoogleSignIn? googleSignIn})
    : _authRepository = authRepository,
      _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            scopes: const <String>['openid', 'email', 'profile'],
            clientId: kIsWeb ? firebaseWebClientId : null,
          ),
      super(AuthState.initial()) {
    // CUMPLE HU-01: LOGIN SSO CON GOOGLE MEDIANTE AUTENTICACION NATIVA.
    // PATRON: BLOC - Orquesta estados de autenticación y side-effects externos.
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  /// Maneja el inicio de sesión SSO con Google e intercambio por JWT del backend.
  /// Implementa flujo JIT: si falla en backend, crea documento cascarón en Firestore.
  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.authenticating, clearError: true));

    try {
      String? idToken;
      String? uid;
      String? email;
      String? displayName;

      if (kIsWeb) {
        // CUMPLE HU-01: En Web se obtiene idToken usando Firebase Auth popup.
        final GoogleAuthProvider provider = GoogleAuthProvider();
        provider.addScope('openid');
        provider.addScope('email');
        provider.addScope('profile');

        final UserCredential credential = await FirebaseAuth.instance
            .signInWithPopup(provider);

        final User? user = credential.user;
        if (user == null) {
          throw Exception('No se pudo obtener usuario de Firebase Auth.');
        }

        uid = user.uid;
        email = user.email ?? '';
        displayName = user.displayName ?? '';
        idToken = await user.getIdToken();
      } else {
        final GoogleSignInAccount? account = await _googleSignIn.signIn();

        if (account == null) {
          emit(
            state.copyWith(
              status: AuthStatus.unauthenticated,
              errorMessage: 'Inicio de sesión cancelado por el usuario.',
            ),
          );
          return;
        }

        final GoogleSignInAuthentication authentication =
            await account.authentication;
        idToken = authentication.idToken;
        uid = account.id;
        email = account.email;
        displayName = account.displayName ?? '';
      }

      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'No se pudo obtener idToken de Google Sign-In. '
          'Verifica que Google esté habilitado en Firebase Authentication.',
        );
      }

      final ({AuthSession? session, bool isPending}) result =
          await _authRepository.loginConIdToken(
            idToken,
            uid: uid,
            email: email,
            displayName: displayName,
          );

      if (result.isPending) {
        emit(
          state.copyWith(
            status: AuthStatus.accessPending,
            session: result.session,
            clearError: true,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            session: result.session,
            clearError: true,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          session: null,
          errorMessage: e.toString(),
        ),
      );
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  /// Maneja cierre de sesión local y remoto.
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signOut();
      } else {
        await _googleSignIn.signOut();
      }
    } finally {
      await _authRepository.logout();
      emit(AuthState.initial());
    }
  }
}
