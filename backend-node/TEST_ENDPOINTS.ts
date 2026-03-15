/**
 * @fileoverview Ejemplos de prueba de los endpoints
 * Cómo hacer requests contra la API usando curl o Postman
 */

// ============================================================================
// PRUEBAS DE ENDPOINTS CON CURL
// ============================================================================

/**
 * 1. HEALTH CHECK
 *
 * curl -X GET http://localhost:3000/health
 *
 * Respuesta:
 * {
 *   "status": "ok",
 *   "timestamp": "2026-03-13T19:45:00Z",
 *   "uptime": 123.456
 * }
 */

/**
 * 2. LOGIN CON GOOGLE
 *
 * Primero, necesitas obtener un idToken válido de Google desde el frontend
 *
 * curl -X POST http://localhost:3000/api/auth/login \
 *   -H "Content-Type: application/json" \
 *   -d '{"idToken":"eyJhbGciOiJSUzI1NiIs..."}'
 *
 * Respuesta exitosa (200):
 * {
 *   "success": true,
 *   "data": {
 *     "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6...",
 *     "permisos": ["crear_venta", "consultar_inventario", "descontar_stock"],
 *     "usuario": {
 *       "uid": "KfB8xA9p2L0...",
 *       "email": "cajero@farmacia.com",
 *       "nombre": "Juan García",
 *       "role": "cajero"
 *     },
 *     "expiresIn": 86400
 *   }
 * }
 *
 * Errores posibles:
 * 400: DTO inválido
 * 401: Token de Google inválido o expirado
 * 404: Usuario no tiene perfil en Firestore
 * 403: Usuario desactivado
 */

/**
 * 3. OBTENER DATOS DEL USUARIO AUTENTICADO
 *
 * curl -X GET http://localhost:3000/api/auth/me \
 *   -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6..."
 *
 * Respuesta exitosa (200):
 * {
 *   "success": true,
 *   "data": {
 *     "uid": "KfB8xA9p2L0...",
 *     "email": "cajero@farmacia.com",
 *     "nombre": "Juan García",
 *     "role": "cajero",
 *     "permisos": ["crear_venta", "consultar_inventario", "descontar_stock"]
 *   }
 * }
 *
 * Errores posibles:
 * 401: Sin Authorization header o token inválido
 */

/**
 * 4. LOGOUT
 *
 * curl -X POST http://localhost:3000/api/auth/logout \
 *   -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6..."
 *
 * Respuesta exitosa (200):
 * {
 *   "success": true,
 *   "message": "Logout exitoso. Elimina el token del cliente."
 * }
 */

// ============================================================================
// FLOW COMPLETO DE TESTING
// ============================================================================

/**
 * PASO 1: Verificar que el servidor está vivo
 *   GET /health
 *
 * PASO 2: Obtener idToken de Google (desde frontend, no desde curl)
 *   1. Abrir app Flutter/Web
 *   2. Click en "Login con Google"
 *   3. Copiar el idToken obtenido
 *
 * PASO 3: Hacer login
 *   POST /api/auth/login { idToken }
 *   → Obtener JWT
 *
 * PASO 4: Usar JWT en requests posteriores
 *   GET /api/auth/me
 *   Authorization: Bearer <JWT>
 *
 * PASO 5: Logout
 *   POST /api/auth/logout
 *   Authorization: Bearer <JWT>
 */

// ============================================================================
// TESTING CON POSTMAN
// ============================================================================

/**
 * Import este snippet en Postman:
 *
 * {
 *   "info": {
 *     "name": "Farmacia POS API",
 *     "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
 *   },
 *   "item": [
 *     {
 *       "name": "Health Check",
 *       "request": {
 *         "method": "GET",
 *         "url": "http://localhost:3000/health"
 *       }
 *     },
 *     {
 *       "name": "Login",
 *       "request": {
 *         "method": "POST",
 *         "url": "http://localhost:3000/api/auth/login",
 *         "header": {
 *           "Content-Type": "application/json"
 *         },
 *         "body": {
 *           "mode": "raw",
 *           "raw": "{\"idToken\":\"<PASTE_ID_TOKEN_HERE>\"}"
 *         }
 *       }
 *     },
 *     {
 *       "name": "Get Me",
 *       "request": {
 *         "method": "GET",
 *         "url": "http://localhost:3000/api/auth/me",
 *         "header": {
 *           "Authorization": "Bearer <PASTE_JWT_HERE>"
 *         }
 *       }
 *     }
 *   ]
 * }
 */

export const TEST_ENDPOINTS = {
  health: 'GET /health',
  login: 'POST /api/auth/login',
  me: 'GET /api/auth/me',
  logout: 'POST /api/auth/logout',
};
