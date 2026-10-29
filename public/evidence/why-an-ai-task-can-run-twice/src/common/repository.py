import math
from datetime import timedelta
from uuid import NAMESPACE_URL, uuid4, uuid5

from src.common.models import TERMINAL, payload_hash


class KeyConflict(Exception):
    pass


class Repository:
    """All ownership and terminal transitions serialize on the task row."""

    def __init__(self, database, settings):
        self.db, self.settings = database, settings

    async def intent(self, conn, task, kind="work", body=None, delay=0, event_id=None):
        await conn.execute(
            """INSERT INTO intents
               (id,task_id,tenant_id,kind,body,trace,available_at)
               VALUES ($1,$2,$3,$4,$5,$6,now()+$7::interval)
               ON CONFLICT (id) DO NOTHING""",
            event_id or uuid4(),
            task["id"] if task else None,
            task["tenant_id"] if task else "quarantine",
            kind,
            body or {},
            task["trace"] if task else {},
            timedelta(seconds=delay),
        )

    async def submit(self, tenant, key, payload, trace):
        digest = payload_hash(payload)
        async with self.db.transaction() as conn:
            row = await conn.fetchrow(
                """INSERT INTO tasks
                   (id,tenant_id,idempotency_key,payload_hash,payload,trace)
                   VALUES ($1,$2,$3,$4,$5,$6)
                   ON CONFLICT (tenant_id,idempotency_key) DO NOTHING
                   RETURNING *""",
                uuid4(),
                tenant,
                key,
                digest,
                payload,
                trace,
            )
            if row:
                await self.intent(conn, row)
                return dict(row)
            row = await conn.fetchrow(
                "SELECT * FROM tasks WHERE tenant_id=$1 AND idempotency_key=$2",
                tenant,
                key,
            )
            if row["payload_hash"] != digest:
                raise KeyConflict
            return dict(row)

    async def get(self, tenant, task_id):
        async with self.db.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM tasks WHERE id=$1 AND tenant_id=$2",
                task_id,
                tenant,
            )
            return dict(row) if row else None

    async def cancel(self, tenant, task_id):
        async with self.db.transaction() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM tasks WHERE id=$1 AND tenant_id=$2 FOR UPDATE",
                task_id,
                tenant,
            )
            if row is None:
                return None
            if row["status"] not in TERMINAL:
                row = await conn.fetchrow(
                    """UPDATE tasks SET status='cancelled',claim_token=NULL,
                       claim_until=NULL,updated_at=now()
                       WHERE id=$1 RETURNING *""",
                    task_id,
                )
            return dict(row)

    async def claim(self, envelope):
        async with self.db.transaction() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM tasks WHERE id=$1 AND tenant_id=$2 FOR UPDATE",
                envelope.task_id,
                envelope.tenant_id,
            )
            if row is None:
                return "missing", None
            if row["status"] in TERMINAL:
                return "terminal", dict(row)
            now = await conn.fetchval("SELECT clock_timestamp()")
            wait_until = max(row["available_at"], row["claim_until"] or now)
            if wait_until > now:
                return "defer", math.ceil((wait_until - now).total_seconds()) + 1
            if row["execution_attempts"] >= self.settings.max_execution_attempts:
                row = await conn.fetchrow(
                    """UPDATE tasks SET status='failed',reason='attempt_cap',
                       claim_token=NULL,claim_until=NULL,updated_at=now()
                       WHERE id=$1 RETURNING *""",
                    row["id"],
                )
                await self.intent(conn, row, "dlq", {"reason": "attempt_cap"})
                return "terminal", dict(row)
            row = await conn.fetchrow(
                """UPDATE tasks SET status='running',execution_attempts=
                   execution_attempts+1,claim_token=$2,claim_until=
                   clock_timestamp()+$3::interval,updated_at=now()
                   WHERE id=$1 RETURNING *""",
                row["id"],
                uuid4(),
                timedelta(seconds=self.settings.db_claim_seconds),
            )
            return "owned", dict(row)

    async def finish(self, task, status, result=None, reason=None, delay=0):
        async with self.db.transaction() as conn:
            row = await conn.fetchrow(
                """UPDATE tasks SET status=$3,result=$4,reason=$5,
                   claim_token=NULL,claim_until=NULL,updated_at=now(),
                   available_at=now()+$6::interval
                   WHERE id=$1 AND claim_token=$2 AND status='running'
                   AND claim_until>clock_timestamp() RETURNING *""",
                task["id"],
                task["claim_token"],
                status,
                result,
                reason,
                timedelta(seconds=delay),
            )
            if not row:
                return False
            if status in {"failed", "timed_out"}:
                await self.intent(conn, row, "dlq", {"reason": reason})
            elif status == "retry_wait":
                await self.intent(conn, row, delay=delay)
            return True

    async def release(self, task):
        # A started claim consumes one attempt, including interrupted work.
        return await self.finish(task, "retry_wait", reason="shutdown")

    async def lease_intent(self):
        async with self.db.transaction() as conn:
            row = await conn.fetchrow(
                """UPDATE intents SET owner=$1,lease_until=now()+interval '30 s',
                   publish_attempts=publish_attempts+1
                   WHERE id=(SELECT id FROM intents WHERE dispatched_at IS NULL
                     AND available_at<=now() AND
                     (lease_until IS NULL OR lease_until<now())
                     ORDER BY available_at FOR UPDATE SKIP LOCKED LIMIT 1)
                   RETURNING *""",
                uuid4(),
            )
            return dict(row) if row else None

    async def published(self, event):
        async with self.db.transaction() as conn:
            await conn.execute(
                """UPDATE intents SET dispatched_at=now(),owner=NULL,
                   lease_until=NULL WHERE id=$1 AND owner=$2""",
                event["id"],
                event["owner"],
            )

    async def publication_failed(self, event):
        delay = min(60, 2 ** min(event["publish_attempts"], 6))
        async with self.db.transaction() as conn:
            await conn.execute(
                """UPDATE intents SET owner=NULL,lease_until=NULL,
                   available_at=now()+$3::interval WHERE id=$1 AND owner=$2""",
                event["id"],
                event["owner"],
                timedelta(seconds=delay),
            )

    async def quarantine(self, body):
        async with self.db.transaction() as conn:
            await self.intent(
                conn,
                None,
                "quarantine",
                body,
                event_id=uuid5(NAMESPACE_URL, "quarantine:" + body["message_id"]),
            )

    async def reconcile(self):
        # Repair expired notifications, not terminal task states.
        async with self.db.transaction() as conn:
            rows = await conn.fetch(
                """SELECT * FROM tasks t WHERE status NOT IN
                   ('completed','failed','timed_out','cancelled')
                   AND available_at<=now() AND
                   (claim_until IS NULL OR claim_until<now())
                   AND notified_at<now()-interval '420 s'
                   AND NOT EXISTS (SELECT 1 FROM intents i WHERE i.task_id=t.id
                     AND i.kind='work' AND i.dispatched_at IS NULL)
                   FOR UPDATE SKIP LOCKED LIMIT 20""",
            )
            for row in rows:
                await self.intent(conn, row)
                await conn.execute(
                    "UPDATE tasks SET notified_at=now() WHERE id=$1",
                    row["id"],
                )

    async def metrics(self):
        async with self.db.pool.acquire() as conn:
            return dict(
                await conn.fetchrow(
                    """SELECT count(*) AS pending,
                   coalesce(max(extract(epoch FROM now()-created_at)),0)
                   AS oldest_seconds FROM intents WHERE dispatched_at IS NULL""",
                )
            )
