# MicroLend Platform 💸

> A multi-tiered micro-lending platform where multiple lenders can fractionally fund a single loan — built with enterprise-grade financial integrity.

![Next.js](https://img.shields.io/badge/Next.js-14-black?style=flat-square&logo=next.js)
![NestJS](https://img.shields.io/badge/NestJS-10-E0234E?style=flat-square&logo=nestjs)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?style=flat-square&logo=postgresql)
![Prisma](https://img.shields.io/badge/Prisma-ORM-2D3748?style=flat-square&logo=prisma)
![Tailwind CSS](https://img.shields.io/badge/Tailwind-CSS-38B2AC?style=flat-square&logo=tailwind-css)

---

## 🧠 What Makes This Unique

Unlike standard CRUD applications, this platform pushes critical financial business logic directly to the database layer:

- **Atomic Disbursal Engine** — Manages complex many-to-many loan fractionalization (multiple lenders funding a single loan) strictly within single PostgreSQL transaction blocks, preventing any data anomalies.
- **Immutable Audit Ledger** — PostgreSQL triggers and shadow tables automatically log every financial state change, simulating enterprise-grade regulatory compliance.
- **Role-Based Architecture** — Separate dashboards and API guards for Borrowers, Lenders, and Admins.

---

## 🏗️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Next.js 14 (App Router), Tailwind CSS |
| Backend | Node.js, NestJS |
| Database | PostgreSQL 16, Prisma ORM |
| Auth | JWT, Role-based guards |

---

## 📁 Project Structure

```
microlend-platform/
├── frontend/          # Next.js 14 app
│   ├── app/
│   │   ├── (auth)/
│   │   │   └── login/
│   │   ├── borrower/
│   │   │   └── dashboard/
│   │   ├── lender/
│   │   │   └── dashboard/
│   │   └── admin/
│   │       └── panel/
│   └── components/
├── backend/           # NestJS app
│   └── src/
│       ├── auth/
│       ├── loans/
│       ├── users/
│       └── ledger/
└── README.md
```

---

## ⚙️ Getting Started

### Prerequisites

- Node.js v18+
- PostgreSQL 16
- npm or yarn

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/microlend-platform.git
cd microlend-platform
```

### 2. Setup the backend

```bash
cd backend
npm install
cp .env.example .env
# Fill in your PostgreSQL credentials in .env
npx prisma migrate dev
npx prisma db seed
npm run start:dev
```

### 3. Setup the frontend

```bash
cd frontend
npm install
cp .env.local.example .env.local
# Set NEXT_PUBLIC_API_URL=http://localhost:3001
npm run dev
```

### 4. Open the app

Go to [http://localhost:3000](http://localhost:3000)

---

## 🌿 Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, working code only |
| `feature/frontend-login` | Login & signup page |
| `feature/frontend-dashboard` | Borrower & lender dashboards |
| `feature/backend-loans` | Loan lifecycle APIs |
| `feature/database-schema` | Prisma schema & migrations |
| `feature/audit-ledger` | Triggers & shadow tables |

---

## 🤝 Contributing (for team members)

```bash
# Step 1 — Always pull latest before starting
git pull origin main

# Step 2 — Create your own branch
git checkout -b feature/your-name-task

# Step 3 — Make changes, then commit
git add .
git commit -m "feat: describe what you did"

# Step 4 — Push your branch
git push origin feature/your-name-task

# Step 5 — Open a Pull Request on GitHub
# Go to github.com → your repo → "Compare & pull request"
```

> **Rule:** Never push directly to `main`. Always open a Pull Request.

---

## 🔑 Environment Variables

### Backend (`backend/.env`)

```env
DATABASE_URL="postgresql://user:password@localhost:5432/microlend"
JWT_SECRET="your-secret-key"
PORT=3001
```

### Frontend (`frontend/.env.local`)

```env
NEXT_PUBLIC_API_URL=http://localhost:3001
```

---

## 👥 Team

| Name | Role |
|------|------|
| — | Frontend (Next.js) |
| — | Backend (NestJS) |
| — | Database (PostgreSQL + Prisma) |
| — | UI/UX & Integration |

**Group ID:** 13

---

## 📄 License

This project is built for academic purposes.
