// Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

/**
 *
export interface Store {
  authenticate(email: string, password: string): Promise<Session | null>;
  resolveSession(token: string): Promise<User | null>;
  hasTenantAccess(user: User, organizationId: string): Promise<boolean>;
  tenantTasks(user: User, organizationId: string): Promise<Task[] | null>;
  requestPasswordReset(email: string): Promise<string | null>;
  resetPassword(token: string, encodedPassword: string): Promise<boolean>;
  createRecoveryCodes(userId: string): Promise<string[]>;
  recoverMfa(code: string): Promise<boolean>;
  audit(action: string, correlationId: string, userId?: string, organizationId?: string): Promise<void>;
  enqueue(type: string, payload: Record<string, unknown>): Promise<void>;
  auditCount(): Promise<number>;
  pendingOutboxCount(): Promise<number>;
  ready(): Promise<boolean>;
}

export class MemoryStore implements Store {
  readonly users = new Map<string, User>();
  readonly memberships: Membership[] = [];
  readonly tasks = new Map<string, Task>();
  readonly sessions = new Map<string, Session>();
  readonly passwordResets = new Map<string, PasswordReset>();
  readonly recoveryCodes = new Map<string, RecoveryCode>();
  readonly audits: AuditEvent[] = [];
  readonly outbox = new Map<string, OutboxEvent>();

  constructor() {
    const orgA = "00000000-0000-0000-0000-00000000000a";
    const orgB = "00000000-0000-0000-0000-00000000000b";
    const userA: User = {
      id: "10000000-0000-0000-0000-00000000000a",
      email: "admin-a@example.test",
      displayName: "NGO A Admin",
      role: "ORGANIZATION_ADMIN",
      passwordHash: passwordHash("Correct-Horse-2026!"),
      mfaEnabled: false
    };

    this.users.set(userA.id, userA);
    this.memberships.push({
      userId: userA.id,
      organizationId: orgA,
      role: "ORGANIZATION_ADMIN"
    });

    this.tasks.set("task-a", {
      id: "task-a",
      organizationId: orgA,
      title: "NGO A Task",
      status: "OPEN"
    });

    this.tasks.set("task-b", {
      id: "task-b",
      organizationId: orgB,
      title: "NGO B Task",
      status: "OPEN"
    });
  }

  async authenticate(email: string, password: string): Promise<Session | null> {
    const user = [...this.users.values()].find((candidate) => candidate.email === email.toLowerCase());
    if (!user || !verifyPassword(password, user.passwordHash)) return null;

    const token = secureToken(32);
    const session: Session = {
      token,
      userId: user.id,
      expiresAt: Date.now() + 15 * 60_000,
      revoked: false
    };
    this.sessions.set(token, session);
    return session;
  }

  async resolveSession(token: string): Promise<User | null> {
    const session = this.sessions.get(token);
    if (!session || session.revoked || session.expiresAt <= Date.now()) return null;
    return this.users.get(session.userId) ?? null;
  }

  async hasTenantAccess(user: User, organizationId: string): Promise<boolean> {
    if (user.role === "PLATFORM_ADMIN" || user.role === "SUPPORT") return true;
    return this.memberships.some(
      (membership) =>
        membership.userId === user.id &&
        membership.organizationId === organizationId
    );
  }

  async tenantTasks(user: User, organizationId: string): Promise<Task[] | null> {
    if (!(await this.hasTenantAccess(user, organizationId))) return null;
    return [...this.tasks.values()].filter((task) => task.organizationId === organizationId);
  }

  async requestPasswordReset(email: string): Promise<string | null> {
    const user = [...this.users.values()].find((candidate) => candidate.email === email.toLowerCase());
    if (!user) return null;

    const token = secureToken(48);
    this.passwordResets.set(hash(token), {
      hash: hash(token),
      userId: user.id,
      expiresAt: Date.now() + 30 * 60_000,
      used: false
    });
    return token;
  }

  async resetPassword(token: string, encodedPassword: string): Promise<boolean> {
    const reset = this.passwordResets.get(hash(token));
    if (!reset || reset.used || reset.expiresAt <= Date.now()) return false;

    const user = this.users.get(reset.userId);
    if (!user) return false;

    user.passwordHash = encodedPassword;
    reset.used = true;

    for (const session of this.sessions.values()) {
      if (session.userId === user.id) session.revoked = true;
    }
    return true;
  }

  async createRecoveryCodes(userId: string): Promise<string[]> {
    for (const [key, value] of this.recoveryCodes) {
      if (value.userId === userId) this.recoveryCodes.delete(key);
    }

    const codes = Array.from({ length: 10 }, () =>
      secureToken(9).replace(/[-_]/g, "").slice(0, 12).toUpperCase()
    );
    for (const code of codes) {
      this.recoveryCodes.set(hash(code), { hash: hash(code), userId, used: false });
    }
    return codes;
  }

  async recoverMfa(code: string): Promise<boolean> {
    const recovery = this.recoveryCodes.get(hash(code));
    if (!recovery || recovery.used) return false;

    const user = this.users.get(recovery.userId);
    if (!user) return false;

    recovery.used = true;
    user.mfaEnabled = false;

    for (const session of this.sessions.values()) {
      if (session.userId === user.id) session.revoked = true;
    }
    return true;
  }

  async audit(action: string, correlationId: string, userId?: string, organizationId?: string): Promise<void> {
    this.audits.push({
      id: randomUUID(),
      action,
      at: new Date().toISOString(),
      correlationId,
      ...(userId ? { userId } : {}),
      ...(organizationId ? { organizationId } : {})
    });
  }

  async enqueue(type: string, payload: Record<string, unknown>): Promise<void> {
    const id = randomUUID();
    this.outbox.set(id, {
      id,
      type,
      payload,
      attempts: 0,
      availableAt: Date.now(),
      processed: false
    });
  }

  async auditCount(): Promise<number> {
    return this.audits.length;
  }

  async pendingOutboxCount(): Promise<number> {
    return [...this.outbox.values()].filter((event) => !event.processed).length;
  }

  async ready(): Promise<boolean> {
    return true;
  }
}

export async function createStore(): Promise<Store> {
  const mode = process.env.DATABASE_MODE ?? "prisma";

  if (mode === "memory") {
    if (process.env.NODE_ENV === "production") {
      throw new Error("DATABASE_MODE=memory is forbidden in production.");
    }
    return new MemoryStore();
  }

  if (mode !== "prisma") {
    throw new Error(`Unsupported DATABASE_MODE: ${mode}`);
  }

  const { PrismaStore } = await import("./prisma-store.js");
  return PrismaStore.create();
}
