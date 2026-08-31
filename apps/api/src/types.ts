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
export type Role = "VOLUNTEER" | "ORGANIZATION_ADMIN" | "PLATFORM_ADMIN" | "SUPPORT";

export interface User {
  id: string;
  email: string;
  displayName: string;
  role: Role;
  passwordHash: string;
  mfaEnabled: boolean;
}

export interface Membership {
  userId: string;
  organizationId: string;
  role: Role;
}

export interface Task {
  id: string;
  organizationId: string;
  title: string;
  status: "DRAFT" | "OPEN" | "IN_PROGRESS" | "COMPLETED" | "CANCELLED";
}

export interface Session {
  token: string;
  userId: string;
  expiresAt: number;
  revoked: boolean;
}

export interface PasswordReset {
  hash: string;
  userId: string;
  expiresAt: number;
  used: boolean;
}

export interface RecoveryCode {
  hash: string;
  userId: string;
  used: boolean;
}

export interface AuditEvent {
  id: string;
  userId?: string;
  organizationId?: string;
  action: string;
  at: string;
  correlationId: string;
}

export interface OutboxEvent {
  id: string;
  type: string;
  payload: Record<string, unknown>;
  attempts: number;
  availableAt: number;
  processed: boolean;
}
