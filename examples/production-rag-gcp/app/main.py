"""FastAPI RAG service for Cloud Run + pgvector.

Endpoints: GET /health · POST /ingest · POST /query
Backends are env-driven (VECTOR_BACKEND, EMBEDDING_PROVIDER) so the same image
runs locally (in-memory + deterministic) and on Cloud Run (pgvector + Vertex AI).
"""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from pydantic import BaseModel, Field

from .embeddings import build_embedder
from .rag import RagEngine
from .store import build_store


class IngestRequest(BaseModel):
    documents: list[str] = Field(min_length=1)


class IngestResponse(BaseModel):
    chunks: int


class QueryRequest(BaseModel):
    question: str = Field(min_length=1, max_length=2000)
    top_k: int = Field(default=3, ge=1, le=20)


class Passage(BaseModel):
    id: str
    text: str
    score: float


class QueryResponse(BaseModel):
    passages: list[Passage]
    grounded: bool


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.engine = RagEngine(build_embedder(), build_store())
    yield


app = FastAPI(title="production-rag-gcp", version="0.1.0", lifespan=lifespan)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/ingest", response_model=IngestResponse)
def ingest(req: IngestRequest) -> IngestResponse:
    chunks = app.state.engine.add_documents(req.documents)
    return IngestResponse(chunks=chunks)


@app.post("/query", response_model=QueryResponse)
def query(req: QueryRequest) -> QueryResponse:
    result = app.state.engine.query(req.question, req.top_k)
    return QueryResponse(passages=[Passage(**p) for p in result.passages], grounded=result.grounded)
