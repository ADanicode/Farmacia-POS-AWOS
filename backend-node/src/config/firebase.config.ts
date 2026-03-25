/**
 * @fileoverview Configuración centralizada de Firebase Admin SDK
 * Inicializa la conexión con Firestore y Authentication
 *
 * Firebase initialization is optional. When credentials are absent the module
 * exports null values and `isFirebaseInitialized()` returns false, allowing the
 * application to start in limited mode and serve health-check requests.
 */

import * as admin from 'firebase-admin';

/** Required environment variables for Firebase to be considered configured. */
const FIREBASE_REQUIRED_VARS = [
  'FIREBASE_PROJECT_ID',
  'FIREBASE_PRIVATE_KEY_ID',
  'FIREBASE_PRIVATE_KEY',
  'FIREBASE_CLIENT_EMAIL',
] as const;

/**
 * Returns true when all Firebase credential environment variables are present.
 */
export function isFirebaseConfigured(): boolean {
  return FIREBASE_REQUIRED_VARS.every((v) => Boolean(process.env[v]));
}

/** Tracks whether Firebase was successfully initialized at startup. */
let _firebaseInitialized = false;

/**
 * Returns true after `tryInitializeFirebase` has completed successfully.
 */
export function isFirebaseInitialized(): boolean {
  return _firebaseInitialized;
}

/**
 * Attempts to initialize Firebase Admin SDK using environment variables.
 * Returns the App instance on success, or null when credentials are missing.
 * Safe to call multiple times — returns the existing app if already initialized.
 *
 * @returns Configured Firebase Admin App, or null if credentials are absent.
 */
export function tryInitializeFirebase(): admin.app.App | null {
  if (!isFirebaseConfigured()) {
    console.warn(
      '⚠️  Firebase credentials not found. Running in limited mode — ' +
        'Firebase-dependent endpoints will return 503.',
    );
    return null;
  }

  // Return existing default app if already initialized
  try {
    const existing = admin.app();
    _firebaseInitialized = true;
    return existing;
  } catch {
    // No app initialized yet — proceed with initialization
  }

  const serviceAccount = {
    projectId: process.env.FIREBASE_PROJECT_ID,
    privateKeyId: process.env.FIREBASE_PRIVATE_KEY_ID,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    clientId: process.env.FIREBASE_CLIENT_ID || '',
    authUri:
      process.env.FIREBASE_AUTH_URI ||
      'https://accounts.google.com/o/oauth2/auth',
    tokenUri:
      process.env.FIREBASE_TOKEN_URI ||
      'https://oauth2.googleapis.com/token',
  };

  const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
    projectId: process.env.FIREBASE_PROJECT_ID,
  });

  _firebaseInitialized = true;
  return app;
}

/**
 * Initializes Firebase Admin with credentials from environment variables.
 *
 * @returns Configured Firebase Admin App instance.
 * @throws {Error} If any required credential variable is missing.
 * @deprecated Prefer `tryInitializeFirebase` for graceful degradation.
 */
export function initializeFirebase(): admin.app.App {
  if (!isFirebaseConfigured()) {
    const missing = FIREBASE_REQUIRED_VARS.filter((v) => !process.env[v]);
    throw new Error(
      `Missing Firebase environment variables: ${missing.join(', ')}`,
    );
  }
  const app = tryInitializeFirebase();
  if (!app) throw new Error('Firebase initialization failed unexpectedly.');
  return app;
}

/**
 * Obtiene la instancia de Firestore inicializada.
 * @returns Referencia a Firestore database.
 */
export function getFirestore(): admin.firestore.Firestore {
  return admin.firestore();
}

/**
 * Obtiene la instancia de Authentication de Firebase.
 * @returns Instancia de Firebase Auth.
 */
export function getAuth(): admin.auth.Auth {
  return admin.auth();
}

/**
 * Nombres de colecciones de Firestore
 */
export const FIRESTORE_COLLECTIONS = {
  PERFILES: process.env.FIRESTORE_PERFILES_COLLECTION || 'perfiles_seguridad',
  TICKETS: process.env.FIRESTORE_TICKETS_COLLECTION || 'tickets_ventas',
  AUDITORIA: process.env.FIRESTORE_AUDITORIA_COLLECTION || 'auditoria_recetas',
} as const;
