# CLAUDE.md — Contract Review Copilot

> This project follows the Everything Claude Code (ECC) development conventions.

## Project Overview

- **Type**: Task-Oriented Agentic UI (任务导向型智能体交互界面)
- **Purpose**: AI-powered review of rental/consumer contracts for unfair clauses
- **Status**: Production-ready with full AI pipeline

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | React 18 + Vite 5 + TypeScript |
| Backend | FastAPI + Python 3.11 |
| AI Orchestration | LangGraph StateGraph |
| LLM | ZhipuAI GLM-5 (primary) + GLM-4.7-Flash (fallback) |
| Embeddings | ZhipuAI text-embedding-v4 (1024-dim) |
| Vector Search | PostgreSQL + pgvector |
| Web Search | DuckDuckGo (free, no API key) |
| Caching | Redis |
| Auth | JWT + Email verification code |
| Containerization | Docker Compose (PostgreSQL + Backend + Frontend) |

## Key Conventions

### Naming
- TypeScript/JS: `camelCase` for files and functions
- Python: `snake_case` for files and functions
- Components: `PascalCase`

### Testing
- Frontend: Vitest (`*.test.ts`, `*.test.tsx`)
- Backend: pytest (`test_*.py`)
- E2E: Playwright (root `package.json`)
- Target: 80%+ coverage

### Commit Format (Conventional Commits)
```
feat: add entity extraction agent
fix: resolve SSE chunk boundary bug
docs: update API documentation
test: add breakpoint confirmation test
```

## Development Commands

```bash
# Frontend
cd frontend
npm install
npm run dev          # Dev server on :3000
npm run build        # Production build
npm run test         # Vitest unit tests

# Backend
cd backend
pip install -e .     # Install dependencies
uvicorn src.main:app --reload --port 8000

# Docker (full stack)
docker compose up --build

# Generate sample contracts
python generate_samples.py
```

## Architecture

### Agent Pipeline (LangGraph StateGraph)

```
contract_text
    ↓
[entity_extraction] → extracted_entities (LLM or regex fallback)
    ↓
[routing] → routing_decision (pgvector vs DuckDuckGo)
    ↓
[logic_review] → logic_review_results (risk issues per clause)
    ↓
[breakpoint] → needs_human_review (pause for confirmation)
    ↓
[PAUSE — waiting for user confirmation via /api/review/confirm/{session_id}]
    ↓
[aggregation] → final_report (SSE streamed)
```

### SSE Event Types

| Event | Direction | Purpose |
|-------|-----------|---------|
| `review_started` | → Frontend | Review began |
| `entity_extraction` | → Frontend | Variables extracted |
| `routing` | → Frontend | Search strategy decided |
| `logic_review` | → Frontend | Per-clause risk found |
| `rag_retrieval` | → Frontend | Legal documents retrieved |
| `breakpoint` | → Frontend | Awaiting human confirmation |
| `stream_resume` | → Frontend | User confirmed, resume |
| `final_report` | → Frontend | Streaming report paragraphs |
| `review_complete` | → Frontend | Done |
| `error` | → Frontend | Error occurred |

### API Endpoints

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/health` | GET | No | Health check |
| `/api/auth/send-code` | POST | No | Send 6-digit verification code |
| `/api/auth/login` | POST | No | Verify code, return JWT |
| `/api/auth/me` | GET | Yes | Get current user info |
| `/api/review` | POST | Yes | Start contract review (SSE stream) |
| `/api/review/confirm/{session_id}` | POST | Yes | Resume paused review |
| `/api/autofix` | POST | Yes | Generate clause revision |

## Files Quick Reference

```
backend/src/
├── main.py              # FastAPI app + SSE endpoints
├── schemas.py           # Pydantic request/response models
├── config.py            # Environment settings (pydantic-settings)
├── auth.py              # JWT + email verification code auth
├── startup.py           # Container startup helper
├── agents/
│   ├── entity_extraction.py  # LLM-powered variable extraction
│   ├── routing.py            # LLM-powered search strategy routing
│   ├── logic_review.py       # LLM-powered risk analysis
│   ├── breakpoint.py         # Human confirmation decision
│   └── aggregation.py        # LLM-powered final report
├── graph/
│   ├── state.py              # ReviewState TypedDict
│   └── review_graph.py        # LangGraph StateGraph
├── vectorstore/
│   ├── connection.py         # PostgreSQL connection pool
│   ├── store.py              # Chunk storage + similarity retrieval
│   ├── embeddings.py         # ZhipuAI text-embedding-v4
│   ├── bootstrap.py          # Container startup seeding
│   ├── builtin_seed.py       # Built-in legal knowledge
│   └── document_loader.py     # Contract document loading
├── search/
│   └── duckduckgo.py         # Free web search
└── cache/
    └── redis_cache.py        # Redis caching layer

frontend/src/
├── App.tsx                  # Main app + routing
├── main.tsx                 # Entry point
├── contexts/
│   └── AuthContext.tsx       # JWT + user state
├── hooks/
│   └── useStreamingReview.ts # SSE client hook
├── lib/
│   └── sseClient.ts          # SSE fetch utility
├── pages/
│   └── LoginPage.tsx         # Email code login
├── components/
│   ├── ContractInput.tsx     # Textarea + file upload
│   ├── AgentCard.tsx         # Agent result card
│   ├── BreakpointCard.tsx    # Human confirmation card
│   ├── FinalReport.tsx       # Streaming report
│   ├── ReviewStream.tsx      # Review flow container
│   ├── ChatPanel.tsx         # Chat interface + risk cards
│   ├── DocPanel.tsx         # Document display
│   ├── SideNav.tsx           # Navigation sidebar
│   └── TopNav.tsx            # Top navigation
└── tests/                   # Vitest tests
```

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `OPENAI_API_KEY` | - | ZhipuAI API key |
| `OPENAI_MODEL` | `glm-5` | Primary LLM |
| `OPENAI_BASE_URL` | `https://coding.dashscope.aliyuncs.com/v1` | Primary API |
| `LLM_FALLBACK_*` | - | Fallback LLM (GLM-4.7-Flash) |
| `EMBEDDING_API_KEY` | same as OPENAI_API_KEY | Embedding key |
| `DATABASE_URL` | `postgresql://...` | PostgreSQL connection |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis connection |
| `JWT_SECRET` | `contract-review-copilot-secret-2024` | JWT signing |
| `SMTP_*` | - | Email sending config |

## Key Features

1. **Contract Review**: Analyzes rental/consumer contracts for unfair clauses
2. **Entity Extraction**: Extracts parties, rent, deposit, term, penalties via LLM
3. **Risk Detection**: 4 severity levels (critical/high/medium/low)
4. **Legal RAG**: pgvector semantic search + DuckDuckGo web search
5. **Interactive Chat**: Ask questions about risks
6. **Auto-fix**: Generate suggested clause revisions
7. **Report Export**: Downloadable "Avoid Pitfalls Guide"
8. **Email Auth**: 6-digit code login (dev mode returns code directly)
9. **Session History**: Stored in sessionStorage
