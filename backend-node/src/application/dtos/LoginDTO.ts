/**
 * @fileoverview DTO y esquemas de validación para el módulo de Autenticación
 * Utiliza Zod para validación estricta de tipos en tiempo de ejecución
 */

import { z } from 'zod';

/**
 * Schema de validación para login con idToken de Google
 * El idToken viene del frontend después de autenticarse con Google
 */
export const LoginDTOSchema = z.object({
  idToken: z
    .string()
    .min(20, 'idToken debe ser válido')
    .describe('Token de identidad de Google'),
});

export type LoginDTO = z.infer<typeof LoginDTOSchema>;

/**
 * Schema de validación para el payload del JWT generado internamente
 */
export const JWTPayloadSchema = z.object({
  uid: z.string().describe('UID del usuario (Firebase)'),
  email: z.string().email().describe('Email del usuario'),
  nombre: z.string().optional().describe('Nombre completo'),
  role: z.string().describe('Role asignado'),
  permisos: z
    .array(z.string())
    .describe('Array de permisos (RBAC)'),
  iat: z.number().optional().describe('Emitido en (timestamp)'),
  exp: z.number().optional().describe('Expira en (timestamp)'),
  iss: z.literal('farmacia-pos').optional().describe('Emisor del token'),
});

export type JWTPayload = z.infer<typeof JWTPayloadSchema>;

/**
 * Validar un LoginDTO
 * @param data - Objeto a validar
 * @returns LoginDTO validado
 * @throws {ZodError} Si la validación falla
 */
export function validarLoginDTO(data: unknown): LoginDTO {
  return LoginDTOSchema.parse(data);
}

/**
 * Validar un JWTPayload
 * @param data - Objeto a validar
 * @returns JWTPayload validado
 * @throws {ZodError} Si la validación falla
 */
export function validarJWTPayload(data: unknown): JWTPayload {
  return JWTPayloadSchema.parse(data);
}
