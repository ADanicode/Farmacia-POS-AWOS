/**
 * @fileoverview Configuración centralizada de JWT
 * Define constantes y validaciones para generación y verificación de tokens
 */

/**
 * Interfaz para configuración de JWT
 */
export interface IJWTConfig {
  secret: string;
  expiresIn: string | number;
  issuer: string;
  audience: string;
}

/**
 * Obtiene la configuración de JWT desde variables de entorno
 * @returns Configuración lista para usar en jwt.sign/verify
 * @throws {Error} Si faltan variables requeridas
 */
export function getJWTConfig(): IJWTConfig {
  const secret = process.env.JWT_SECRET;
  const expiresIn = process.env.JWT_EXPIRATION || '24h';

  if (!secret || secret.length < 32) {
    throw new Error(
      'JWT_SECRET debe tener mínimo 32 caracteres. Configúralo en .env',
    );
  }

  return {
    secret,
    expiresIn,
    issuer: 'farmacia-pos',
    audience: 'farmacia-pos-users',
  };
}

/**
 * Tiempos de expiración predeterminados
 */
export const JWT_EXPIRY_TIMES = {
  SHORT: '15m',
  STANDARD: '24h',
  EXTENDED: '7d',
  REFRESH: '30d',
} as const;

/**
 * Validar si un string es un tiempo de expiración válido
 * @param time - Tiempo a validar (ej: "24h", "7d", 3600)
 * @returns true si es válido
 */
export function isValidExpiryTime(time: string | number): boolean {
  if (typeof time === 'number' && time > 0) return true;
  if (typeof time === 'string' && /^\d+[smhd]$/.test(time)) return true;
  return false;
}
