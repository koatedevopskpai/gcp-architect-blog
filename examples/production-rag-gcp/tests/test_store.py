import math

from app.embeddings import DeterministicEmbedder
from app.store import InMemoryVectorStore


def test_embedding_dimensions_and_normalised():
    embedder = DeterministicEmbedder(64)
    (vec,) = embedder.embed(["hello world"])
    assert len(vec) == 64
    assert math.isclose(sum(v * v for v in vec), 1.0, rel_tol=1e-6)


def test_inmemory_store_ranks_by_cosine():
    store = InMemoryVectorStore()
    store.init_schema(2)
    store.upsert(
        ["a", "b"],
        [[1.0, 0.0], [0.0, 1.0]],
        ["python and rag", "gardening tips"],
    )
    results = store.search([1.0, 0.0], top_k=1)
    assert results[0][0] == "a"
    assert results[0][2] > 0.99
