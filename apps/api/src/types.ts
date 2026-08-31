// Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

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