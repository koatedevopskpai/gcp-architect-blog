import asyncio
import hashlib
import logging
import random

from opentelemetry import trace
from pydantic import ValidationError

from src.common.models import Envelope, validate_result
from src.common.telemetry import worker_span
from src.infra.local_ai_client import TransientAIError

log = logging.getLogger(__name__)


class Worker:
    def __init__(self, repository, queue, ai, settings, stop=None):
        self.repo, self.queue, self.ai = repository, queue, ai
        self.settings = settings
        self.stop = stop or asyncio.Event()

    async def stop_ai(self, call):
        call.cancel()
        done, _ = await asyncio.wait({call}, timeout=1)
        if done:
            await asyncio.gather(call, return_exceptions=True)
        else:
            # Shutdown of a non-cooperative SDK needs the process grace limit.
            call.add_done_callback(self.consume_exception)
            log.error("AI cancellation exceeded local cleanup budget")

    @staticmethod
    def consume_exception(task):
        if not task.cancelled():
            task.exception()

    async def one(self):
        if self.stop.is_set():
            return False
        delivery = await self.queue.receive()
        if not delivery:
            return False
        if self.stop.is_set():
            await self.queue.nack(delivery)
            return True
        try:
            envelope = Envelope.model_validate_json(delivery.content)
        except ValidationError, ValueError:
            await self.repo.quarantine(
                {
                    "reason": "invalid_envelope",
                    "message_id": delivery.id,
                    "body_sha256": hashlib.sha256(
                        delivery.content.encode()
                    ).hexdigest(),
                }
            )
            await self.queue.complete(delivery)
            return True
        with worker_span(envelope) as span:
            span.set_attribute("queue.delivery_count", delivery.count)
            mode, task = await self.repo.claim(envelope)
            if mode == "defer":
                await self.queue.nack(delivery, task)
                return True
            if mode == "missing":
                await self.repo.quarantine(
                    {
                        "reason": "missing_or_foreign_task",
                        "message_id": delivery.id,
                    }
                )
            if mode != "owned":
                await self.queue.complete(delivery)
                return True
            span.set_attribute("execution.attempt", task["execution_attempts"])
            await self.execute(task, delivery)
        return True

    async def invoke(self, task):
        with trace.get_tracer("ai-ops-lab.model").start_as_current_span(
            "model.invoke",
            attributes={"task.id": str(task["id"]), "ai.mode": self.settings.ai_mode},
        ):
            return await self.ai.process(task["payload"])

    async def ownership_changed(self, task):
        while True:
            current = await self.repo.get(task["tenant_id"], task["id"])
            if (
                not current
                or current["claim_token"] != task["claim_token"]
                or current["status"] != "running"
            ):
                return
            await asyncio.sleep(0.1)

    async def commit_outcome(self, task, status, result=None, reason=None, delay=0):
        changed = await self.repo.finish(task, status, result, reason, delay)
        if changed and status in {"completed", "failed", "timed_out"}:
            row = await self.repo.get(task["tenant_id"], task["id"])
            elapsed = (row["updated_at"] - row["created_at"]).total_seconds()
            trace.get_current_span().set_attribute("task.elapsed_seconds", elapsed)
            trace.get_current_span().set_attribute("task.status", status)
            log.info(
                "task_terminal task_id=%s status=%s elapsed_seconds=%s",
                task["id"],
                status,
                elapsed,
            )

    async def execute(self, task, delivery):
        call = asyncio.create_task(self.invoke(task))
        stopped = asyncio.create_task(self.stop.wait())
        changed = asyncio.create_task(self.ownership_changed(task))
        try:
            done, _ = await asyncio.wait(
                {call, stopped, changed},
                timeout=self.settings.task_timeout_seconds,
                return_when=asyncio.FIRST_COMPLETED,
            )
            if call not in done:
                await self.stop_ai(call)
                async with asyncio.timeout(self.settings.finalize_budget_seconds):
                    if self.stop.is_set():
                        if await self.repo.release(task):
                            await self.queue.nack(delivery, 0)
                        return
                    if changed in done:
                        changed.result()  # A monitor error leaves durable recovery.
                        await self.queue.complete(delivery)
                        return
                    await self.commit_outcome(task, "timed_out", reason="deadline")
                    await self.queue.complete(delivery)
                return
            try:
                result = validate_result(call.result())
                status, reason, delay = "completed", None, 0.0
            except TransientAIError:
                if task["execution_attempts"] < self.settings.max_execution_attempts:
                    status, reason = "retry_wait", "transient_ai"
                else:
                    status, reason = "failed", "attempt_cap"
                delay = random.uniform(1, min(60, 2 ** task["execution_attempts"]))
                result = None
            except Exception as exc:
                status, reason, delay, result = "failed", type(exc).__name__, 0.0, None
            async with asyncio.timeout(self.settings.finalize_budget_seconds):
                await self.commit_outcome(task, status, result, reason, delay)
                await self.queue.complete(delivery)
        finally:
            if not call.done():
                await self.stop_ai(call)
            for watcher in (stopped, changed):
                watcher.cancel()
            await asyncio.gather(stopped, changed, return_exceptions=True)

    async def run(self):
        while not self.stop.is_set():
            try:
                if await self.one():
                    continue
            except Exception:
                # No acknowledgement: visibility and durable ownership recover.
                log.exception("worker iteration failed")
            try:
                await asyncio.wait_for(self.stop.wait(), 0.5)
            except TimeoutError:
                pass
