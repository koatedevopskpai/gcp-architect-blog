"""RAG engine: chunk → embed → store → retrieve (deterministic-first)."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass

from .embeddings import Embedder
from .store import VectorStore


@dataclass
class QueryResult:
    passages: list[dict]
    grounded: bool


class RagEngine:
    def __init__(self, embedder: Embedder, store: VectorStore, chunk_words: int = 120):
        self.embedder = embedder
        self.store = store
        self.chunk_words = chunk_words

    def add_documents(self, documents: list[str]) -> int:
        ids: list[str] = []
        chunks: list[str] = []
        for text in documents:
            for i, chunk in enumerate(self._chunk(text)):
                ids.append(self._id(text, i))
                chunks.append(chunk)
        vectors = self.embedder.embed(chunks)
        self.store.init_schema(self.embedder.dimensions)
        return self.store.upsert(ids, vectors, chunks)

    def query(self, question: str, top_k: int = 3) -> QueryResult:
        vector = self.embedder.embed([question])[0]
        hits = self.store.search(vector, top_k)
        passages = [
            {"id": doc_id, "text": text, "score": round(score, 4)}
            for doc_id, text, score in hits
        ]
        return QueryResult(passages=passages, grounded=bool(passages))

    def _chunk(self, text: str):
        words = text.split()
        if not words:
            return
        for i in range(0, len(words), self.chunk_words):
            yield " ".join(words[i : i + self.chunk_words])

    @staticmethod
    def _id(text: str, index: int) -> str:
        return hashlib.sha256(f"{text}:{index}".encode("utf-8")).hexdigest()[:16]
