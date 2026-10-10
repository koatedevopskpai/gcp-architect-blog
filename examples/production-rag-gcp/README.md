# production-rag-gcp

**Production RAG on GCP, under budget** — a Pydantic-validated **FastAPI** RAG
service on **Cloud Run** with **pgvector on Cloud SQL Postgres**. Deterministic-first:
the retrieval path is pure and testable; embeddings default to an offline
deterministic embedder and swap to **Vertex AI** with one env var.

```
client ─▶ Cloud Run (FastAPI)  /ingest  /query
              │  Cloud SQL connector (unix socket, IAM)
              ▼
        Cloud SQL Postgres 15  ── pgvector (HNSW, cosine)
              ▲
        embeddings: deterministic (default) | Vertex AI (prod)
```

## Run locally (60s)

```bash
pip install -e ".[dev]"
python -m pytest                      # 8 tests, ~84% coverage
uvicorn app.main:app --port 8080
curl localhost:8080/health
curl -X POST localhost:8080/ingest -H 'content-type: application/json' \
  -d '{"documents":["Cloud Run scales to zero when idle.","BigQuery stores analytics."]}'
curl -X POST localhost:8080/query -H 'content-type: application/json' \
  -d '{"question":"How does Cloud Run handle no traffic?","top_k":1}'
```

Locally it uses the **in-memory** store + deterministic embeddings — no cloud,
no keys.

## Deploy to GCP

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # if provided
terraform init && terraform apply
```

This creates Cloud SQL (Postgres 15, `db-f1-micro`, 10 GB SSD), pgvector, a
Secret Manager secret, the runtime SA, the Cloud Run service (mounted Cloud SQL
volume) and an availability SLO + burn alert.

## Cost

`db-f1-micro` ≈ **$0.0105/hour**; 10 GB SSD ≈ $0.17/GB/month. A deploy → test →
**destroy** cycle costs **pennies** (<$0.05). **Delete** (don't stop) the instance
afterwards to return to $0 — a stopped instance still bills storage.

## Switching to Vertex AI embeddings

```bash
EMBEDDING_PROVIDER=vertex VERTEX_EMBED_MODEL=text-embedding-004
```

Swaps the deterministic embedder for Vertex AI; the RAG + pgvector pipeline is
unchanged. (Grant the runtime SA `roles/aiplatform.user`.)

## Layout

```
app/
  embeddings.py   # deterministic (default) + Vertex AI
  store.py        # InMemory + PgVector (Cloud SQL)
  rag.py          # chunk -> embed -> store -> retrieve
  main.py         # FastAPI /health /ingest /query
infra/            # Cloud Run + Cloud SQL(pgvector) + Secret + SLO Terraform
tests/            # unit + API tests
```

## Licence

MIT — see [LICENSE](LICENSE). © 2026 Koate Kpai.
