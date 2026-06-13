# 🚀 EditFlow

> Manage. Track. Grow.

EditFlow is a modern project and client management app built specifically for freelancers, video editors, content creators, and creative agencies.

Track projects, manage clients, monitor payments, organize deadlines, and stay on top of revisions — all from a single dashboard.

---

## ✨ Features

### 👥 Client Management
- Create and manage clients
- Store contact information
- Quick contact actions
- Revenue tracking per client
- Active project overview

### 📂 Project Tracking
- Create and manage projects
- Assign projects to clients
- Set budgets and deadlines
- Track project progress

### 🔄 Project Pipeline

Projects move through a structured workflow:

1. Yet To Start
2. In Progress
3. Revision Pending
4. Completed
5. Paid

---

### 💰 Payment Tracking

- Track total project value
- Record advance payments
- Monitor pending balances
- Overdue payment alerts
- Revenue insights
- Custom UPI payment QR codes (scan-to-pay via GPay, PhonePe, Paytm)
- Prefill-free compliant deep links for secure, universal bank scanning
- Quick text/image invoice sharing with automatic payment link attachment

---

### 📅 Calendar View

- Visual deadline tracking
- Upcoming project overview
- Monthly planning
- Due date indicators

---

### 📊 Analytics Dashboard

- Total earnings
- Paid revenue
- Pending revenue
- Overdue payments
- Monthly goals
- Top clients / top freelancers ranking lists
- Project status analytics

---

### 💬 Feedback System

- Real-time project comment streams powered by Supabase Postgres channels
- Instant client-freelancer feedback exchange
- Revision tracking and approval pipelines

---

### 🔒 Authentication & Client Mode

- Google Sign-In, Email Authentication, and Password Reset
- Cloud Data Sync (Supabase Auth & Database integration)
- Persisted "Client View Mode" toggles synced with user metadata
- Automatic UI lockdowns (hides creation/edit/delete triggers and data backup options)
- Dynamic bottom navigation tabs (auto-collapses to Dashboard & Freelancers)
- Live client-specific metric translation (Earnings → Expenses, Pending → Due)

---

### 🌙 Premium UI/UX & Transitions

- Beautiful dark mode and mobile-first design
- Curved count-up animations for all numeric stat dashboards
- Animated Monthly Goal trackers with interactive 100%+ scale-pulse celebrations
- Custom responsive skeleton shimmer loading layouts (light/dark mode compatible)
- Tactile physical selection haptic vibrations on navigation tab switching
- Page transition routes with Gaussian image blur animations and symmetric pop speeds

---

## 🛠 Tech Stack

### Frontend
- Flutter
- Dart

### Backend
- Supabase
- PostgreSQL

### Authentication
- Supabase Auth
- Google OAuth

### Database
- PostgreSQL
- Row Level Security (RLS)

---

## 🎯 Built For

- Freelance Video Editors
- Content Creators
- Motion Designers
- YouTubers
- Creative Agencies
- Social Media Managers
- Freelance Developers
- Graphic Designers

---

## 🚀 Getting Started

Clone the repository:

```bash
git clone https://github.com/Arunchauhan-HTMLCatalyst/editflow.git
```

Navigate into the project:

```bash
cd editflow
```

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

---

## 🔧 Environment Setup

Create a `.env` file:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_key
```

---

## 📈 Roadmap

### Current Version
- [x] Client Management
- [x] Project Tracking
- [x] Payment Tracking
- [x] Calendar View
- [x] Analytics Dashboard
- [x] Authentication System
- [x] Client Portal (Client Mode view & security restrictions)
- [x] Real-time Commenting & Feedback System
- [x] Custom UPI Payment QR Code & Sharing Integration
- [x] Premium Animations & Transition Polish

### Upcoming Features
- [ ] PDF Export / PDF Invoices
- [ ] Team Collaboration
- [ ] File Sharing
- [ ] Push Notifications
- [ ] Web Version
- [ ] AI-Powered Insights

---

## 🤝 Feedback

EditFlow is currently in active development.

Found a bug? Have a feature idea?

Feel free to open an issue or submit a pull request.

---

## 👨💻 Developer

**Arun Chauhan**

Freelance Video Editor & Developer

---

## ⭐ Support

If you like this project, please consider giving it a star.

It helps the project reach more freelancers and creators.

---

Built with ❤️ by a freelancer, for freelancers.
