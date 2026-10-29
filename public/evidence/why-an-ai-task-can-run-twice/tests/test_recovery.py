import asyncio
import json

import pytest

from tests.conftest import make_due, submit


async def test_broker_outage_preserves_outbox(repo, publisher, queue):
    queue.fail_send = True
    task = await submit(repo, publisher)
    assert task["status"] == "pending"
    assert not queue.visible
    assert (await repo.metrics())["pending"] == 1
    queue.fail_send = False
    await make_due(repo)
    await publisher.one()
    assert len(queue.visible) == 1


async def test_post_commit_ack_failure_skips_second_ai(
    repo, publisher, worker, queue, ai
):
    task = await submit(repo, publisher)
    queue.fail_complete = True
    with pytest.raises(OSError):
        await worker.one()
    assert (await repo.get("tenant-a", task["id"]))["status"] == "completed"
    queue.redeliver()
    await worker.one()
    assert ai.calls == 1


async def test_stop_releases_owned_work(repo, publisher, worker, queue, ai):
    ai.delay = 2
    task = await submit(repo, publisher)
    pending = asyncio.create_task(worker.one())
    await ai.started.wait()
    worker.stop.set()
    await asyncio.wait_for(pending, 2)
    row = await repo.get("tenant-a", task["id"])
    assert row["status"] == "retry_wait"
    assert row["claim_token"] is None
    assert len(queue.visible) == 1


async def test_stop_before_receive(worker, queue):
    worker.stop.set()
    assert not await worker.one()
    assert not queue.received


async def test_running_cancel_prevents_result(repo, publisher, worker, ai):
    ai.delay = 2
    task = await submit(repo, publisher)
    processing = asyncio.create_task(worker.one())
    await ai.started.wait()
    await repo.cancel("tenant-a", task["id"])
    await processing
    row = await repo.get("tenant-a", task["id"])
    assert row["status"] == "cancelled" and row["result"] is None


async def test_timeout_is_terminal(repo, publisher, worker, ai, settings):
    ai.delay = 2
    settings.task_timeout_seconds = 0.1
    task = await submit(repo, publisher)
    await worker.one()
    row = await repo.get("tenant-a", task["id"])
    assert row["status"] == "timed_out"
    assert (await repo.metrics())["pending"] == 1


async def test_retry_then_success(repo, publisher, worker, ai):
    ai.fail_first = 1
    task = await submit(repo, publisher)
    await worker.one()
    await make_due(repo)
    await publisher.one()
    await worker.one()
    row = await repo.get("tenant-a", task["id"])
    assert row["status"] == "completed"
    assert row["execution_attempts"] == 2


async def test_retry_cap_and_durable_dlq(repo, publisher, worker, ai, queue):
    ai.fail_first = 100
    task = await submit(repo, publisher)
    for attempt in range(3):
        await worker.one()
        await make_due(repo)
        if attempt < 2:
            await publisher.one()
    assert (await repo.get("tenant-a", task["id"]))["status"] == "failed"
    queue.fail_send = True
    await publisher.one()
    assert (await repo.metrics())["pending"] == 1
    queue.redeliver()
    await worker.one()  # Terminal shortcut must not remove the DLQ intent.
    assert ai.calls == 3
    queue.fail_send = False
    await make_due(repo)
    await publisher.one()
    assert json.loads(queue.dlq[0])["kind"] == "dlq"


async def test_invalid_envelope_quarantined(repo, publisher, worker, queue):
    await queue.send("not-json")
    await worker.one()
    await publisher.one()
    value = json.loads(queue.dlq[0])
    assert value["kind"] == "quarantine"
    assert "body_sha256" in value["details"]
    assert "not-json" not in queue.dlq[0]


async def test_provider_response_before_commit_can_repeat(
    repo, publisher, worker, queue, ai
):
    task = await submit(repo, publisher)
    original = repo.finish

    async def crash(*args, **kwargs):
        raise OSError("crash between provider response and commit")

    repo.finish = crash
    with pytest.raises(OSError):
        await worker.one()
    repo.finish = original
    async with repo.db.transaction() as conn:
        await conn.execute(
            "UPDATE tasks SET claim_until=now()-interval '1 s' WHERE id=$1",
            task["id"],
        )
    queue.redeliver()
    await worker.one()
    assert ai.calls == 2  # Deliberate exactly-once limitation, not hidden.
    assert (await repo.get("tenant-a", task["id"]))["status"] == "completed"


async def test_completed_task_dlq_not_recreated(repo, publisher, worker, queue):
    await submit(repo, publisher)
    await worker.one()
    queue.redeliver()
    await worker.one()
    assert (await repo.metrics())["pending"] == 0


async def test_reconciler_repairs_stale_notification(repo, publisher, queue):
    task = await submit(repo, publisher)
    queue.visible.clear()  # Simulate a missing notification after its retention.
    async with repo.db.transaction() as conn:
        await conn.execute(
            "UPDATE tasks SET notified_at=now()-interval '500 s' WHERE id=$1",
            task["id"],
        )
    await repo.reconcile()
    await publisher.one()
    assert len(queue.visible) == 1
