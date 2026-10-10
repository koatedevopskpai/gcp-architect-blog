"""Vector stores: in-memory (tests/local) + pgvector on Cloud SQL (prod)."""

from __future__ import annotations

import math
import os
from typing import Protocol


class VectorStore(Protocol):
    def init_schema(self, dimensions: int) -> None: ...
    def upsert(self, ids: list[str], vectors: list[list[float]], texts: list[str]) -> int: ...
    def search(self, vector: list[float], top_k: int) -> list[tuple[str, str, float]]: ...


def _cosine(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a)) or 1.0
    nb = math.sqrt(sum(y * y for y in b)) or 1.0
    return dot / (na * nb)


class InMemoryVectorStore:
    """Deterministic, dependency-free store for tests and local runs."""

    def __init__(self) -> None:
        self._rows: dict[str, tuple[list[float], str]] = {}

    def init_schema(self, dimensions: int) -> None:
        self.dimensions = dimensions

    def upsert(self, ids: list[str], vectors: list[list[float]], texts: list[str]) -> int:
        for i, v, t in zip(ids, vectors, texts):
            self._rows[i] = (v, t)
        return len(ids)

    def search(self, vector: list[float], top_k: int) -> list[tuple[str, str, float]]:
        scored = [(i, t, _cosine(vector, v)) for i, (v, t) in self._rows.items()]
        scored.sort(key=lambda r: r[2], reverse=True)
        return scored[:top_k]


class PgVectorStore:
    """pgvector on Cloud SQL (or any Postgres with the `vector` extension).

    Connects over the Cloud Run Unix socket (`/cloudsql/<INSTANCE_CONNECTION_NAME>`)
    or a standard `DATABASE_URL`.
    """

    def __init__(self) -> None:
        import psycopg  # lazy: only needed when this store is selected

        conninfo = os.getenv("DATABASE_URL")
        if not conninfo:
            instance = os.environ["CLOUD_SQL_CONNECTION_NAME"]
            conninfo = (
                f"host=/cloudsql/{instance} dbname={os.getenv('DB_NAME','rag')} "
                f"user={os.getenv('DB_USER','rag')} password={os.environ['DB_PASSWORD']}"
            )
        self._conn = psycopg.connect(conninfo, autocommit=True)

    def init_schema(self, dimensions: int) -> None:
        with self._conn.cursor() as cur:
            cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
            cur.execute(
                f"CREATE TABLE IF NOT EXISTS documents ("
                f"id text PRIMARY KEY, text text NOT NULL, embedding vector({dimensions}))"
            )
            cur.execute("CREATE INDEX IF NOT EXISTS documents_embedding_idx "
                        "ON documents USING hnsw (embedding vector_cosine_ops)")

    def upsert(self, ids: list[str], vectors: list[list[float]], texts: list[str]) -> int:
        with self._conn.cursor() as cur:
            for i, v, t in zip(ids, vectors, texts):
                cur.execute(
                    "INSERT INTO documents (id, text, embedding) VALUES (%s, %s, %s::vector) "
                    "ON CONFLICT (id) DO UPDATE SET text=EXCLUDED.text, embedding=EXCLUDED.embedding",
                    (i, t, _as_vector(v)),
                )
        return len(ids)

    def search(self, vector: list[float], top_k: int) -> list[tuple[str, str, float]]:
        with self._conn.cursor() as cur:
            cur.execute(
                "SELECT id, text, 1 - (embedding <=> %s::vector) AS score "
                "FROM documents ORDER BY embedding <=> %s::vector LIMIT %s",
                (_as_vector(vector), _as_vector(vector), top_k),
            )
            return [(r[0], r[1], float(r[2])) for r in cur.fetchall()]


def _as_vector(v: list[float]) -> str:
    return "[" + ",".join(f"{x:.6f}" for x in v) + "]"


def build_store() -> VectorStore:
    backend = os.getenv("VECTOR_BACKEND", "memory").strip().lower()
    if backend in ("pgvector", "cloudsql", "postgres"):
        return PgVectorStore()
    return InMemoryVectorStore()
