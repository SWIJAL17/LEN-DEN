# Multi-Tiered Micro-Lending Platform

A full-stack micro-lending web application that enables multiple lenders to fractionally co-fund a single borrower loan. Built with a database-first approach — critical financial logic lives at the PostgreSQL layer, not the application layer.

**Group ID:** 13

---

## Overview

Most lending platforms treat the database as a simple store. This platform pushes business logic down:

- **Loan fractionalization** is handled inside single atomic transaction blocks, so partial funding from multiple lenders either fully commits or fully rolls back — no half-states.
- **Every financial state change** is captured automatically by PostgreSQL triggers into an append-only shadow table, creating an immutable audit trail without any application-layer code.

---

## Tech Stack

| Layer      | Technology                        |
|------------|-----------------------------------|
| Frontend   | Next.js 14 (App Router), Tailwind CSS |
| Backend    | Node.js, NestJS                   |
| Database   | PostgreSQL 16, Prisma ORM         |
| Auth       | JWT, role-based guards            |

---

## Project Structure

```
microlend-platform/
├── frontend/
│   ├── app/
│   │   ├── (auth)/login/
│   │   ├── borrower/dashboard/
│   │   ├── lender/dashboard/
│   │   └── admin/panel/
│   └── components/
├── backend/
│   └── src/
│       ├── auth/
│       ├── loans/
│       ├── users/
│       └── ledger/
├── .gitignore
└── README.md
```

---

## Getting Started

### Prerequisites

- Node.js v18 or higher
- PostgreSQL 18
- npm

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/microlend-platform.git
cd microlend-platform
```

### 2. Configure and run the backend

```bash
cd backend
npm install
cp .env.example .env
# Edit .env and fill in your PostgreSQL credentials
npx prisma migrate dev
npm run start:dev
```

### 3. Configure and run the frontend

```bash
cd frontend
npm install
cp .env.local.example .env.local
# Set NEXT_PUBLIC_API_URL=http://localhost:3001
npm run dev
```

The app will be available at `http://localhost:3000`.

---

## Environment Variables

**Backend** — `backend/.env`

```
DATABASE_URL="postgresql://user:password@localhost:5432/microlend"
JWT_SECRET="your-secret-key"
PORT=3001
```

**Frontend** — `frontend/.env.local`

```
NEXT_PUBLIC_API_URL=http://localhost:3001
```

---

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable code only — no direct pushes |
| `feature/frontend-login` | Login and signup pages |
| `feature/frontend-dashboard` | Borrower and lender dashboards |
| `feature/backend-loans` | Loan lifecycle APIs |
| `feature/database-schema` | Prisma schema and migrations |
| `feature/audit-ledger` | Triggers and shadow tables |

---

## Contributing

```bash
# Pull latest before starting any work
git pull origin main

# Create a branch for your task
git checkout -b feature/your-name-task

# Commit your changes
git add .
git commit -m "feat: short description of change"

# Push and open a Pull Request on GitHub
git push origin feature/your-name-task
```

Do not push directly to `main`. All changes go through a Pull Request.

---

*Built as a  project for academic purposes.*
