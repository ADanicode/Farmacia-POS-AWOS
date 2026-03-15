/**
 * @fileoverview Configuración centralizada de Firebase Admin SDK
 * Inicializa la conexión con Firestore y Authentication
 */

import * as admin from 'firebase-admin';

/**
 * Inicializa Firebase Admin con credenciales desde variables de entorno
 *
 * @returns Instancia configurada de Firebase Admin App
 * @throws {Error} Si faltan credenciales requeridas
 */
export function initializeFirebase(): admin.app.App {
  const requiredEnvVars = [
    'FIREBASE_PROJECT_ID',
    'FIREBASE_PRIVATE_KEY_ID',
    'FIREBASE_PRIVATE_KEY',
    'FIREBASE_CLIENT_EMAIL',
  ];

  for (const envVar of requiredEnvVars) {
    if (!process.env[envVar]) {
      throw new Error(`Falta variable de entorno: ${envVar}`);
    }
  }

  const serviceAccount = {
    projectId: process.env.FIREBASE_PROJECT_ID,
    privateKeyId: process.env.FIREBASE_PRIVATE_KEY_ID,
    privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    clientId: process.env.FIREBASE_CLIENT_ID || '',
    authUri: process.env.FIREBASE_AUTH_URI || 'https://accounts.google.com/o/oauth2/auth',
    tokenUri: process.env.FIREBASE_TOKEN_URI || 'https://oauth2.googleapis.com/token',
  };

  return admin.initializeApp({
    credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
    projectId: process.env.FIREBASE_PROJECT_ID,
  });
}

/**
 * Obtiene la instancia de Firestore inicializada
 * @returns Referencia a Firestore Firestore database
 */
export function getFirestore(): admin.firestore.Firestore {
  return admin.firestore();
}

/**
 * Obtiene la instancia de Authentication de Firebase
 * @returns Instancia de Firebase Auth
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
