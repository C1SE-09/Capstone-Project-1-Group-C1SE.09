# Capstone-Project-1-Group-C1SE.09
 # KinderLog

  Voice-driven daily reports for Vietnamese kindergartens. A teacher speaks a short
  summary of a child's day; the system transcribes it, extracts structured
  information, and delivers a report to the parent.

  **Stack** — Flutter (Android) · FastAPI · PostgreSQL · Redis · Celery · PhoWhisper (STT) · Gemini (extraction)

  ## Repository layout

  ```
  Doc/        Product backlog, sprint plan, user stories
  project/    Application code
    backend/  FastAPI + Celery
  ```

  ## Prerequisites

  - [Docker Desktop](https://www.docker.com/products/docker-desktop/) — must be **running**
  - [Git](https://git-scm.com/download/win)

  No local Python needed. The API container ships its own Python 3.11.

  ## Setup

  ```powershell
  git clone <repo-url>
  cd Capstone\project

  # Create your local env file from the template
  Copy-Item .env.example .env

  # Build and start all four services
  docker compose up -d --build
  ```

  First build takes 3–6 minutes (downloading Python, ffmpeg, dependencies).
  Later starts take a couple of seconds.

  ## Verify

  ```powershell
  docker compose ps
  ```

  Four containers `Up`; `db` and `redis` show `(healthy)`.

  ```powershell
  # API
  Invoke-RestMethod http://localhost:8000/api/health     # → status: healthy

  # Database
  docker compose exec db pg_isready -U kinderlog          # → accepting connections

  # Redis
  docker compose exec redis redis-cli ping                # → PONG

  # Full round-trip: api → redis → worker → back
  docker compose exec api python -c "from app.tasks.celery_app import ping; print(ping.delay().get(timeout=10))"
  # → pong
  ```

  Interactive API docs: <http://localhost:8000/docs>

  ## Services

  | Service | Purpose | Host address |
  |---------|---------|--------------|
  | `api` | FastAPI HTTP server | http://localhost:8000 |
  | `worker` | Celery background jobs (STT, AI extraction) | — |
  | `db` | PostgreSQL 16 | localhost:5433 |
  | `redis` | Job queue + result store | localhost:6379 |

  PostgreSQL is on host port **5433** to avoid clashing with a locally installed
  PostgreSQL on 5432. Inside the Docker network it is still `db:5432`.

  ## Common commands

  Run all of these from `project/`.

  ```powershell
  docker compose up -d              # start
  docker compose up -d --build      # start, rebuilding images
  docker compose ps                 # status
  docker compose logs -f api        # follow one service's logs
  docker compose restart api        # restart one service
  docker compose exec api bash      # shell inside the api container
  docker compose down               # stop, KEEP database data
  docker compose down -v            # stop, DELETE database data
  docker compose config             # validate compose file + .env
  ```

  Code changes in `backend/` reload automatically — no rebuild.
  Changes to `requirements.txt` or the `Dockerfile` require `--build`.

  ## Troubleshooting

  | Symptom | Fix |
  |---------|-----|
  | `error during connect` | Docker Desktop is not running |
  | `variable is not set` warnings | Missing `.env` — copy it from `.env.example`, in `project/` |
  | `port is already allocated` | Find the owner: `netstat -ano \| findstr :8000` |
  | `database "kinderlog" does not exist` | Volume was built with other credentials: `docker compose down -v` then `up` |
  | Worker runs but tasks never finish | On Windows, Celery needs `--pool=solo` |
  | Everything broken | `docker compose down -v` then `docker compose up --build` |

## Bug reporting

KinderLog has a built-in **bug reporting** feature that lets teachers, parents, and admins
submit bug reports from inside the app, and lets admins triage them in a dashboard.

### Quick start

1. **From the app** — go to **Settings → Help & Support → Report a bug**.
2. **From the admin dashboard** — log in as admin → **Bug Reports** menu.

See the [User Guide](docs/bug-report-user-guide.md) for end-user instructions and the
[Admin Guide](docs/bug-report-admin-guide.md) for handling workflow.

### API

REST API is documented in [docs/bug-report-api.md](docs/bug-report-api.md).
A ready-to-use **Postman collection** is at
`postman/collections/🏫 KinderLog API/🐛 Bug Reports/` — import it into Postman v10+.

7 endpoints under `/api/bug-reports`:

| Method | Endpoint | Role |
|---|---|---|
| `POST` | `/api/bug-reports` | teacher / parent / admin |
| `GET` | `/api/bug-reports/me` | teacher / parent / admin |
| `GET` | `/api/bug-reports/me/{id}` | teacher / parent / admin |
| `GET` | `/api/bug-reports` | admin |
| `GET` | `/api/bug-reports/{id}` | admin |
| `PATCH` | `/api/bug-reports/{id}` | admin |
| `POST` | `/api/bug-reports/{id}/attachments` | author / admin |

Interactive Swagger UI: <http://localhost:8000/docs#tag/bug-reports>

### Database

3 new tables (created by Alembic migration `c1c17a05262a_add_bug_report_tables`):

- `bug_report` — main table
- `bug_report_attachment` — 1:N from `bug_report` (screenshots, logs)
- `bug_report_history` — 1:N from `bug_report` (audit trail of status changes)

### Testing

```powershell
cd backend
pytest tests/test_bug_reports.py tests/test_bug_report_notifications.py -v
```

72 tests · coverage 91% on bug-report modules.

### Seed data

Run `backend/seed.sql` (after `alembic upgrade head`) to get:

- 1 admin user (`admin` / `123456`)
- 5 sample bug reports covering all 5 statuses (open / in_progress / resolved / closed / wont_fix)
- 12 history entries (audit trail examples)

### Configuration

| Env var | Default | Description |
|---|---|---|
| `BUG_REPORT_NOTIFY_EMAIL` | `""` | Comma-separated admin emails. Empty = auto-detect all admins. |
| `MAX_ATTACHMENT_SIZE_MB` | `5` | Max size per attachment. |
| `MAX_ATTACHMENTS_PER_REPORT` | `5` | Max attachments per report. |
| `RATE_LIMIT_REPORTS_PER_HOUR` | `10` | Rate limit per user. |