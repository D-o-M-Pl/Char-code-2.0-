// Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

import type { IncomingMessage, ServerResponse } from "node:http";
import { randomUUID } from "node:crypto";

export interface JsonRequest<T = unknown> {
  body: T;
  correlationId: string;
}

export function json(res: ServerResponse, status: number, body: unknown): void {
  res.statusCode = status;
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.setHeader("cache-control", "no-store");
  res.setHeader("x-content-type-options", "nosniff");
  res.setHeader("x-frame-options", "DENY");
  res.end(JSON.stringify(body));
}

export async function readJson<T>(req: IncomingMessage): Promise<JsonRequest<T>> {
  const chunks: Uint8Array[] = [];
  let size = 0;

  for await (const chunk of req) {
    size += chunk.byteLength;
    if (size > 1_048_576) throw new Error("BODY_TOO_LARGE");
    chunks.push(chunk);
  }

  const correlationHeader = req.headers["x-correlation-id"];
  const correlationId =
    typeof correlationHeader === "string" && correlationHeader.length <= 128
      ? correlationHeader
      : randomUUID();

  const text = chunks.length > 0
    ? chunks.map((chunk) => new TextDecoder().decode(chunk)).join("")
    : "{}";

  return {
    body: JSON.parse(text) as T,
    correlationId
  };
}

export function bearer(req: IncomingMessage): string | null {
  const raw = req.headers.authorization;
  if (typeof raw !== "string" || !raw.startsWith("Bearer ")) return null;
  return raw.slice("Bearer ".length);
}

export function tenant(req: IncomingMessage): string | null {
  const raw = req.headers["x-organization-id"];
  return typeof raw === "string" && raw.length > 0 ? raw : null;
}