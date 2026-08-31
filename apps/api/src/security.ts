/**
 * Copyright 2026 D-o-M-Pl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import { createHash, randomBytes, scryptSync, timingSafeEqual } from "node:crypto";

export function hash(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export function secureToken(bytes = 32): string {
  return randomBytes(bytes).toString("base64url");
}

export function verifyOpaqueToken(value: string, expectedHash: string): boolean {
  const actual = Buffer.from(hash(value), "hex");
  const expected = Buffer.from(expectedHash, "hex");
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

export function validatePassword(password: string): string | null {
  if (password.length < 14) return "Password must contain at least 14 characters.";
  if (password.length > 200) return "Password is too long.";

  const classes = [
    /[a-z]/.test(password),
    /[A-Z]/.test(password),
    /\d/.test(password),
    /[^A-Za-z0-9]/.test(password)
  ].filter(Boolean).length;

  if (classes < 3) return "Password must use at least three character classes.";
  return null;
}

const SCRYPT_N = 131072;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const SCRYPT_MAXMEM = 256 * 1024 * 1024;

export function passwordHash(password: string): string {
  const salt = randomBytes(16).toString("hex");
  const derived = scryptSync(password, salt, 32, { N: SCRYPT_N, r: SCRYPT_R, p: SCRYPT_P, maxmem: SCRYPT_MAXMEM });
  return `$scrypt$${SCRYPT_N}$${SCRYPT_R}$${SCRYPT_P}$${salt}$${Buffer.from(derived).toString("hex")}`;
}

export function verifyPassword(password: string, encoded: string): boolean {
  const parts = encoded.split("$");
  if (parts.length !== 7 || parts[1] !== "scrypt") return false;

  const n = Number(parts[2]);
  const r = Number(parts[3]);
  const p = Number(parts[4]);
  const salt = parts[5];
  const expectedHex = parts[6];

  if (!salt || !expectedHex || !Number.isFinite(n) || !Number.isFinite(r) || !Number.isFinite(p)) return false;

  const actual = scryptSync(password, salt, 32, { N: n, r, p, maxmem: Math.max(SCRYPT_MAXMEM, 128 * n * r + 1024 * 1024) });
  const expected = Buffer.from(expectedHex, "hex");

  return actual.length === expected.length && timingSafeEqual(actual, expected);
}
