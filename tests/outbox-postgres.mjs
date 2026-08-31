// Copyright (c) 2026 D-o-M-Pl. All Rights Reserved.

import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { PrismaClient } from "@prisma/client";
const url=process.env.DATABASE_URL;if(!url)throw new Error("DATABASE_URL required");
const a=new PrismaClient({datasources:{db:{url}}}),b=new PrismaClient({datasources:{db:{url}}});
async function claim(db,token,limit){return db.$queryRawUnsafe(
`WITH c AS (SELECT id FROM outbox_events WHERE processed=false AND available_at<=now() AND (claim_expires_at IS NULL OR claim_expires_at<=now()) ORDER BY available_at,id FOR UPDATE SKIP LOCKED LIMIT $1)
 UPDATE outbox_events e SET claimed_at=now(),claim_expires_at=now()+interval '5 minutes',claim_token=$2 FROM c WHERE e.id=c.id RETURNING e.id`,limit,token);}
const marker=`atomic-${randomUUID()}`;const ids=[];
try{
 await a.$connect();await b.$connect();
 for(let i=0;i<20;i++){const r=await a.outboxEvent.create({data:{eventType:"AtomicTest",payload:{marker,i}},select:{id:true}});ids.push(r.id);}
 const [x,y]=await Promise.all([claim(a,randomUUID(),10),claim(b,randomUUID(),10)]);
 const xa=x.map(r=>r.id).filter(id=>ids.includes(id)),ya=y.map(r=>r.id).filter(id=>ids.includes(id));
 assert.equal(xa.filter(id=>ya.includes(id)).length,0);
 assert.equal(new Set([...xa,...ya]).size,20);
 const id=ids[0];
 await Promise.all([a.$queryRawUnsafe(
   `INSERT INTO notification (outbox_event_id, recipient, subject, body) VALUES ($1, $2, $3, $4) ON CONFLICT (outbox_event_id) DO NOTHING`,
   id,"x@example.test","x","x"),
  b.$queryRawUnsafe(
   `INSERT INTO notification (outbox_event_id, recipient, subject, body) VALUES ($1, $2, $3, $4) ON CONFLICT (outbox_event_id) DO NOTHING`,
   id,"x@example.test","x","x")]);
 assert.equal(await a.notification.count({where:{outboxEventId:id}}),1);
 console.log("OUTBOX PASS");
}finally{await a.notification.deleteMany({where:{outboxEventId:{in:ids}}}).catch(()=>{});await a.outboxEvent.deleteMany({where:{id:{in:ids}}}).catch(()=>{});await a.$disconnect();await b.$disconnect();}