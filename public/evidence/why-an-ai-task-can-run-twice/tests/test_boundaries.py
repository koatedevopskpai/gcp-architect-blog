import asyncio

import pytest

from src.api.main import create_app
from src.common.models import Envelope
from tests.conftest import make_due, submit


async def test_task_and_initial_intent_roll_back_together(repo):
    original = repo.intent

    async def fail(*args, **kwargs):
        raise OSError("intent insert failed")

    repo.intent = fail
    with pytest.raises(OSError):
        await repo.submit("tenant-a", "rollback", {"text": "x"}, {})
    repo.intent = original
    async with repo.db.pool.acquire() as conn:
        assert await conn.fetchval("SELECT count(*) FROM tasks") == 0


async def test_publisher_ack_failure_duplicates_notification_not_result(
    repo, publisher, worker, queue, ai
):
    task = await repo.submit("tenant-a", "publisher-crash", {"text": "x"}, {})
    original = repo.published

    async def fail(*args):
        raise OSError("queue accepted, dispatch mark lost")

    repo.published = fail
    await publisher.one()
    repo.published = original
    await make_due(repo)
    await publisher.one()
    assert len(queue.visible) == 2
    await worker.one()
    await worker.one()
    assert ai.calls == 1
    assert (await repo.get("tenant-a", task["id"]))["status"] == "completed"


async def test_expired_owner_cannot_complete_over_new_owner(repo, publisher, queue):
    task = await submit(repo, publisher)
    envelope = Envelope.model_validate_json(queue.visible[0].content)
    _, old = await repo.claim(envelope)
    async with repo.db.transaction() as conn:
        await conn.execute("UPDATE tasks SET claim_until=now()-interval '1 s'")
    _, new = await repo.claim(envelope)
    assert old["claim_token"] != new["claim_token"]
    assert not await repo.finish(old, "completed", {"summary": "stale"})
    assert await repo.finish(new, "completed", {"summary": "current"})
    assert (await repo.get("tenant-a", task["id"]))["result"]["summary"] == "current"


async def test_cancel_completion_race_has_one_terminal_winner(repo, publisher, queue):
    task = await submit(repo, publisher)
    _, owned = await repo.claim(Envelope.model_validate_json(queue.visible[0].content))
    await asyncio.gather(
        repo.finish(owned, "completed", {"summary": "done"}),
        repo.cancel("tenant-a", task["id"]),
    )
    row = await repo.get("tenant-a", task["id"])
    assert row["status"] in {"completed", "cancelled"}
    assert (row["result"] is not None) == (row["status"] == "completed")


async def test_poison_ack_failure_deduplicates_durable_intent(repo, worker, queue):
    await queue.send("invalid")
    queue.fail_complete = True
    with pytest.raises(OSError):
        await worker.one()
    queue.redeliver()
    await worker.one()
    assert (await repo.metrics())["pending"] == 1


async def test_stop_arriving_during_receive_does_not_claim(
    repo, publisher, worker, queue
):
    task = await submit(repo, publisher)
    original = queue.receive

    async def stop_on_receive():
        result = await original()
        worker.stop.set()
        return result

    queue.receive = stop_on_receive
    await worker.one()
    assert (await repo.get("tenant-a", task["id"]))["execution_attempts"] == 0


async def test_readiness_outage_keeps_liveness(client, repo):
    async def down():
        raise OSError("database unavailable")

    repo.db.ready = down
    assert (await client.get("/health/live")).status_code == 200
    assert (await client.get("/health/ready")).status_code == 503


async def test_result_byte_limit_creates_failure(repo, publisher, worker):
    async def large(_):
        return {"summary": "€" * 7000}

    worker.ai.process = large
    task = await submit(repo, publisher)
    await worker.one()
    assert (await repo.get("tenant-a", task["id"]))["status"] == "failed"
    assert (await repo.metrics())["pending"] == 1


async def test_snapshot_timeout_requests_reconnect(repo, settings):
    import httpx

    settings.sse_max_duration_seconds = 0.05
    task = await repo.submit("tenant-a", "reconnect", {"text": "x"}, {})
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=create_app(settings, repo)),
        base_url="http://test",
        headers={"X-Test-Tenant": "tenant-a"},
    ) as client:
        response = await client.get(f"/tasks/{task['id']}/events")
        assert "event: reconnect" in response.text
    assert (await repo.get("tenant-a", task["id"]))["status"] == "pending"
