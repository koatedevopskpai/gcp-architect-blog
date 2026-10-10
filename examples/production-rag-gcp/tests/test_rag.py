from app.embeddings import DeterministicEmbedder
from app.rag import RagEngine
from app.store import InMemoryVectorStore


def _engine() -> RagEngine:
    return RagEngine(DeterministicEmbedder(128), InMemoryVectorStore())


def test_ingest_then_query_finds_relevant():
    engine = _engine()
    chunks = engine.add_documents(
        [
            "Red pandas eat bamboo and live in the Himalayas.",
            "Cloud Run scales to zero when there is no traffic.",
        ]
    )
    assert chunks >= 2
    result = engine.query("pandas bamboo habitat", top_k=1)
    assert result.grounded is True
    assert "pandas" in result.passages[0]["text"]


def test_query_with_no_documents_is_not_grounded():
    result = _engine().query("anything at all", top_k=3)
    assert result.grounded is False
    assert result.passages == []


def test_ingest_is_idempotent_by_content():
    engine = _engine()
    first = engine.add_documents(["Cloud Run scales to zero."])
    second = engine.add_documents(["Cloud Run scales to zero."])
    assert first == second == 1
