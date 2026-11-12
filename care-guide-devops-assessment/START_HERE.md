# Start Here

This is a sample DevOps project. Read this file first, then use README.md for the full details.

## 1. What is included?

- `app/` – small Python API
- `tests/` – basic automated tests
- `Dockerfile` and `docker-compose.yml` – run the app with Docker
- `.github/workflows/` – GitHub Actions CI/CD examples
- `k8s/` – Kubernetes example files
- `terraform/` – AWS infrastructure examples
- `monitoring/` – Prometheus, Grafana and Loki examples
- `scripts/` – Linux health-check script

## 2. Run the app on Windows PowerShell

Open PowerShell in this project folder and run:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
pytest -v
uvicorn app.main:app --reload
```

Then open `http://127.0.0.1:8000/health` in your browser.

## 3. Run with Docker

After installing and starting Docker Desktop:

```powershell
docker build -t care-guide-api .
docker run --rm -p 8000:8000 care-guide-api
```

Open `http://localhost:8000/health`.

## 4. Before submitting

- Run the tests yourself and keep the real output.
- Do not claim AWS, Kubernetes, or CI/CD deployment succeeded unless you actually ran it.
- Replace example values only with your own values.
- Never upload passwords, API keys, `.env` files, cloud credentials, or Terraform state.
- Read `README.md` for optional cloud, Kubernetes, monitoring, and CI/CD steps.

This project is a starting implementation. Review it and make sure you can explain the parts you submit.
