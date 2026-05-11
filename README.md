# my-cv-project

A simple CV site with a serverless visitor counter and an architecture diagram.

## Contents

- `maffindi.html` — Main CV page. It displays a visitor counter fetched from an AWS Lambda Function URL.
- `architecture-react.html` — Static architecture diagram (SVG) derived from the React TSX component (no runtime required).
- `serverless-diagram-architecture.tsx` — React/TSX component that originally defined the SVG architecture diagram.
- `visitor_counter.py` — Lambda handler for the visitor counter (reads/writes DynamoDB, returns the count).
- `main.tf` — Terraform IaC definition (Lambda, DynamoDB, etc.).
- `.gitignore` — Ignores Terraform state, archives, OS/IDE artifacts, etc.

Note: There is no Mermaid usage in this repository. The architecture diagram is static SVG.

## Quick Start

You can open the files directly in a browser:

- Open `maffindi.html` to view the CV and live visitor count (requires the configured Lambda Function URL to be reachable).
- Open `architecture-react.html` to view the architecture diagram (pure static HTML).

## Visitor Counter (Serverless)

- The CV page calls an AWS Lambda Function URL in `ap-southeast-1`.
- The Lambda (Python) reads/writes a DynamoDB table and logs to CloudWatch.
- Terraform (`main.tf`) provisions the Lambda and DynamoDB resources.

Make sure the Lambda Function URL is set correctly in `maffindi.html`:

Update with your own Function URL as needed.

## Git and GitHub

Planned remote repository: `my-cv-project`

Local steps (already prepared/next to run):
1. Initialize git, add files, and commit:
   ```
   git init
   git branch -M main
   git add .
   git commit -m "Initial commit: CV site, architecture diagram (static), serverless Lambda + Terraform"
   ```
2. After you create the repo on GitHub, provide the remote URL (HTTPS or SSH). Then run:
   ```
   git remote add origin <YOUR_REMOTE_URL>
   git push -u origin main
   ```

## .gitignore

The repository ignores:
- Terraform: `.terraform/`, `terraform.tfstate`, `terraform.tfstate.backup`
- Archives: `*.zip`
- OS/IDE: `.DS_Store`, `Thumbs.db`, `.vscode/`
- Python cache: `__pycache__/`

`.terraform.lock.hcl` is intentionally kept (commonly committed).

## Notes

- If you prefer a React runtime for the diagram page, you can embed the `serverless-diagram-architecture.tsx` component in a React app. The current `architecture-react.html` is a static port of the TSX SVG for simplicity.
