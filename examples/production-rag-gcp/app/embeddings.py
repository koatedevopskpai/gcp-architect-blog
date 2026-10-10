"""Embeddings: deterministic (offline, default) + optional Vertex AI.

Deterministic-first: the demo runs with zero model calls and reproducible
vectors. Swap `EMBEDDING_PROVIDER=vertex` for real Vertex AI embeddings in
production — the RAG pipeline and pgvector store are unchanged.
"""

from __future__ import annotations

import hashlib
import math
import os
from typing import Protocol


class Embedder(Protocol):
    dimensions: int
    provider: str

    def embed(self, texts: list[str]) -> list[list[float]]: ...


class DeterministicEmbedder:
    """Hashing bag-of-words → fixed-dim L2-normalised vector. Fully offline."""

    provider = "deterministic"

    def __init__(self, dimensions: int = 256):
        self.dimensions = dimensions

    def _vector(self, text: str) -> list[float]:
        vec = [0.0] * self.dimensions
        for token in text.lower().split():
            digest = hashlib.sha256(token.encode("utf-8")).digest()
            idx = int.from_bytes(digest[:4], "big") % self.dimensions
            sign = 1.0 if digest[4] % 2 == 0 else -1.0
            vec[idx] += sign
        norm = math.sqrt(sum(v * v for v in vec)) or 1.0
        return [v / norm for v in vec]

    def embed(self, texts: list[str]) -> list[list[float]]:
        return [self._vector(t) for t in texts]


class VertexEmbedder:
    """Vertex AI text embeddings.

    Requests ``output_dimensionality`` so the 256-dim pgvector schema stands.
    Auth is ADC/IAM — no API keys. Requires ``google-genai`` + aiplatform API.
    """

    provider = "vertex"

    def __init__(self, model: str | None = None, dimensions: int | None = None):
        self.model = model or os.getenv("VERTEX_EMBED_MODEL", "text-embedding-004")
        self.dimensions = dimensions or int(os.getenv("VERTEX_EMBED_DIM", "256"))

    def embed(self, texts: list[str]) -> list[list[float]]:
        from google import genai  # imported lazily so the demo runs without it

        # NOTE: bare genai.Client() targets the Gemini Developer API (API key
        # required). vertexai=True routes through Vertex AI with ADC/IAM.
        client = genai.Client(
            vertexai=True,
            project=os.getenv("GOOGLE_CLOUD_PROJECT"),
            location=os.getenv("VERTEX_LOCATION", "us-central1"),
        )
        result = client.models.embed_content(
            model=self.model,
            contents=texts,
            config={"output_dimensionality": self.dimensions},
        )
        return [list(e.values) for e in result.embeddings]


def build_embedder() -> Embedder:
    provider = os.getenv("EMBEDDING_PROVIDER", "").strip().lower()
    if provider == "vertex":
        return VertexEmbedder()
    return DeterministicEmbedder()
