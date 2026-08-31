// Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

import { randomUUID } from "node:crypto";
import { PrismaClient } from "@prisma/client";

const db = new PrismaClient();
const MAX_ATTEMPTS = 8;
const LEASE_SECONDS = 300;

async function claimBatch(limit = 25) {
  const token = randomUUID();
  return db.$queryRawUnsafe(
    `WITH candidates AS (
       SELECT id FROM outbox_events
       WHERE processed=false
         AND available_at<=now()
         AND (claim_expires_at IS NULL OR claim_expires_at<=now())
       ORDER BY available_at,id
       FOR UPDATE SKIP LOCKED
       LIMIT $1
     )
     UPDATE outbox_events e
     SET claimed_at=now(),
         claim_expires_at=now()+($2*interval '1 second'),
         claim_token=$3
     FROM candidates c
     WHERE e.id=c.id
     RETURNING e.id,e.event_type AS "eventType",e.payload,e.attempts,e.claim_token AS "claimToken"`,
    limit, LEASE_SECONDS, token,
  );
}

async function dispatch(event: any) {
  if (event.eventType !== "PasswordResetRequested") {
    throw new Error(`Unsupported outbox event: ${event.eventType}`);
  }
  const payload = event.payload as {email?:string;token?:string;userId?:string};
  if (!payload.email || !payload.token) throw new Error("Invalid reset payload.");

  await db.notification.upsert({
    where: { outboxEventId: event.id },
    create: {
      outboxEventId: event.id,
      userId: payload.userId ?? null,
      recipient: payload.email,
      subject: "Char-code â€” reset hasĹ‚a",
      body: `Token resetu: ${payload.token}`,
      status: "PENDING",
    },
    update: {},
  });
}

async function complete(event:any) {
  const r=await db.outboxEvent.updateMany({
    where:{id:event.id,claimToken:event.claimToken,processed:false},
    data:{processed:true,processedAt:new Date(),claimedAt:null,claimExpiresAt:null,claimToken:null,lastError:null},
  });
  if(r.count!==1) throw new Error(`Lost lease ${event.id}`);
}

async function fail(event:any,error:unknown) {
  const attempts=Number(event.attempts)+1;
  const message=(error instanceof Error?error.message:"Unknown error").slice(0,2000);
  if(attempts>=MAX_ATTEMPTS){
    await db.$transaction(async(tx:any)=>{
      const owned=await tx.outboxEvent.findFirst({where:{id:event.id,claimToken:event.claimToken,processed:false}});
      if(!owned)return;
      await tx.deadLetterEvent.create({data:{outboxId:event.id,eventType:event.eventType,payload:event.payload,error:message,attempts}});
      await tx.outboxEvent.update({where:{id:event.id},data:{processed:true,processedAt:new Date(),attempts,claimedAt:null,claimExpiresAt:null,claimToken:null,lastError:message}});
    });
    return;
  }
  const delay=Math.min(60000,500*2**Math.max(0,attempts-1))+Math.floor(Math.random()*250);
  await db.outboxEvent.updateMany({
    where:{id:event.id,claimToken:event.claimToken,processed:false},
    data:{attempts,availableAt:new Date(Date.now()+delay),claimedAt:null,claimExpiresAt:null,claimToken:null,lastError:message},
  });
}

async function main(){
  await db.$connect();
  while(true){
    const events:any[]=await claimBatch();
    for(const event of events){
      try{await dispatch(event);await complete(event);}catch(error){await fail(event,error);}
    }
    if(events.length===0) await new Promise(r=>setTimeout(r,1000));
  }
}
main().catch(e=>{console.error("Fatal outbox worker error",e);process.exitCode=1;}).finally(()=>db.$disconnect());
