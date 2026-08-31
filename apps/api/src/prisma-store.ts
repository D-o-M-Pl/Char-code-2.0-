// Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

/**
 *
interface PrismaUserShape {
  id: string;
  email: string;
  displayName: string;
  role: User["role"];
  passwordHash: string;
  mfaEnabled: boolean;
}

function userShape(user: PrismaUserShape): User {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    role: user.role,
    passwordHash: user.passwordHash,
    mfaEnabled: user.mfaEnabled,
  };
}

export class PrismaStore implements Store {
  private constructor(private readonly db: PrismaClient) {}

  static async create(): Promise<PrismaStore> {
    const db = new PrismaClient();
    await db.$connect();
    await db.$queryRaw`SELECT 1`;
    return new PrismaStore(db);
  }

  async authenticate(email: string, password: string): Promise<Session | null> {
    const user = await this.db.user.findUnique({
      where: { email: email.toLowerCase() },
    });

    if (!user || !verifyPassword(password, user.passwordHash)) return null;

    const token = secureToken(32);
    const expiresAt = new Date(Date.now() + 15 * 60_000);

    await this.db.session.create({
      data: {
        userId: user.id,
        tokenHash: hash(token),
        expiresAt,
      },
    });

    return {
      token,
      userId: user.id,
      expiresAt: expiresAt.getTime(),
      revoked: false,
    };
  }

  async resolveSession(token: string): Promise<User | null> {
    const session = await this.db.session.findUnique({
      where: { tokenHash: hash(token) },
      include: { user: true },
    });

    if (
      !session ||
      session.revokedAt ||
      session.expiresAt.getTime() <= Date.now()
    ) {
      return null;
    }

    return userShape(session.user);
  }

  async hasTenantAccess(
    user: User,
    organizationId: string,
  ): Promise<boolean> {
    if (user.role === "PLATFORM_ADMIN" || user.role === "SUPPORT") return true;

    return this.db.$transaction(async (tx: PrismaClient) => {
      await tx.$executeRaw`
        SELECT set_config('app.tenant_id', ${organizationId}, true)
      `;
      await tx.$executeRaw`
        SELECT set_config('app.is_platform_admin', 'false', true)
      `;

      const membership = await tx.organizationMembership.findUnique({
        where: {
          organizationId_userId: {
            organizationId,
            userId: user.id,
          },
        },
        select: { id: true },
      });

      return membership !== null;
    });
  }

  async tenantTasks(
    user: User,
    organizationId: string,
  ): Promise<Task[] | null> {
    const isPlatformAdmin =
      user.role === "PLATFORM_ADMIN" || user.role === "SUPPORT";

    return this.db.$transaction(
      async (tx: PrismaClient) => {
        await tx.$executeRaw`
          SELECT set_config('app.tenant_id', ${organizationId}, true)
        `;
        await tx.$executeRaw`
          SELECT set_config(
            'app.is_platform_admin',
            ${String(isPlatformAdmin)},
            true
          )
        `;

        if (!isPlatformAdmin) {
          const membership = await tx.organizationMembership.findUnique({
            where: {
              organizationId_userId: {
                organizationId,
                userId: user.id,
              },
            },
            select: { id: true },
          });

          if (!membership) return null;
        }

        // Intentionally no organizationId WHERE clause.
        // PostgreSQL RLS is the final tenant boundary for this query.
        const rows = await tx.task.findMany({
          select: {
            id: true,
            organizationId: true,
            title: true,
            status: true,
          },
          orderBy: { id: "asc" },
        });

        return rows as Task[];
      },
      {
        isolationLevel: "ReadCommitted",
        maxWait: 5_000,
        timeout: 10_000,
      },
    );
  }

  async requestPasswordReset(email: string): Promise<string | null> {
    const user = await this.db.user.findUnique({
      where: { email: email.toLowerCase() },
      select: { id: true },
    });

    if (!user) return null;

    const token = secureToken(48);

    await this.db.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash: hash(token),
        expiresAt: new Date(Date.now() + 30 * 60_000),
      },
    });

    return token;
  }

  async resetPassword(
    token: string,
    encodedPassword: string,
  ): Promise<boolean> {
    const tokenHash = hash(token);

    return this.db.$transaction(async (tx: PrismaClient) => {
      const reset = await tx.passwordResetToken.findUnique({
        where: { tokenHash },
      });

      if (
        !reset ||
        reset.usedAt ||
        reset.expiresAt.getTime() <= Date.now()
      ) {
        return false;
      }

      const claimed = await tx.passwordResetToken.updateMany({
        where: {
          id: reset.id,
          usedAt: null,
          expiresAt: { gt: new Date() },
        },
        data: { usedAt: new Date() },
      });

      if (claimed.count !== 1) return false;

      await tx.user.update({
        where: { id: reset.userId },
        data: { passwordHash: encodedPassword },
      });

      await tx.session.updateMany({
        where: { userId: reset.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });

      return true;
    });
  }

  async createRecoveryCodes(userId: string): Promise<string[]> {
    const codes = Array.from({ length: 10 }, () =>
      secureToken(9).replace(/[-_]/g, "").slice(0, 12).toUpperCase(),
    );

    await this.db.$transaction([
      this.db.mfaRecoveryCode.deleteMany({ where: { userId } }),
      this.db.mfaRecoveryCode.createMany({
        data: codes.map((code) => ({
          userId,
          codeHash: hash(code),
        })),
      }),
    ]);

    return codes;
  }

  async recoverMfa(code: string): Promise<boolean> {
    const codeHash = hash(code);

    return this.db.$transaction(async (tx: PrismaClient) => {
      const recovery = await tx.mfaRecoveryCode.findUnique({
        where: { codeHash },
      });

      if (!recovery || recovery.usedAt) return false;

      const claimed = await tx.mfaRecoveryCode.updateMany({
        where: {
          id: recovery.id,
          usedAt: null,
        },
        data: { usedAt: new Date() },
      });

      if (claimed.count !== 1) return false;

      await tx.user.update({
        where: { id: recovery.userId },
        data: { mfaEnabled: false },
      });

      await tx.session.updateMany({
        where: { userId: recovery.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });

      return true;
    });
  }

  async audit(
    action: string,
    correlationId: string,
    userId?: string,
    organizationId?: string,
  ): Promise<void> {
    await this.db.auditLog.create({
      data: {
        action,
        correlationId,
        ...(userId ? { actorUserId: userId } : {}),
        ...(organizationId ? { organizationId } : {}),
      },
    });
  }

  async enqueue(
    type: string,
    payload: Record<string, unknown>,
  ): Promise<void> {
    await this.db.outboxEvent.create({
      data: {
        eventType: type,
        payload,
      },
    });
  }

  async auditCount(): Promise<number> {
    return this.db.auditLog.count();
  }

  async pendingOutboxCount(): Promise<number> {
    return this.db.outboxEvent.count({
      where: { processed: false },
    });
  }

  async ready(): Promise<boolean> {
    try {
      await this.db.$queryRaw`SELECT 1`;
      return true;
    } catch {
      return false;
    }
  }
}
