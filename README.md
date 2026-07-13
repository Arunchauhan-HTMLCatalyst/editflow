# 🚀 EditFlow Developer & Agent Manual

> **Manage. Track. Grow.**  
> EditFlow is a modern project and client management application built for freelancers, video editors, content creators, and creative agencies. This documentation is written to serve as a comprehensive onboarding guide for both human developers and AI coding agents.

---

## 📂 Codebase Architecture & Directory Layout

The project follows a feature-first structure. Shared cross-cutting concerns (themes, services, widgets) live in root-level packages, while specific domains are isolated in `lib/features/`.

```
lib/
├── app.dart                                # Application Entry Widget
├── app_shell.dart                          # Layout Shell with Bottom Nav Bar & Haptic Taps
├── main.dart                               # Supabase / App Initializer
├── router.dart                             # GoRouter Mapping and Transition Configurations
├── core/
│   ├── constants/                          # System Constants (e.g. Supabase credentials)
│   └── theme/
│       ├── app_colors.dart                 # EditFlow Premium Dark/Light Palette Tokens
│       ├── app_spacing.dart                # Padding & Margin Tokens
│       ├── app_text_styles.dart            # Typography Configurations
│       └── app_transitions.dart            # Blur & Symmetric Pop Route Transitions
├── services/
│   └── supabase_service.dart               # Static Client & Auth User Accessors
├── shared/
│   ├── models/                             # Shared Data Models (e.g. Activity logs)
│   ├── providers/
│   │   └── computed_providers.dart         # Grouped Metrics, Calculations, Top Freelancers
│   ├── services/
│   │   └── activity_service.dart           # Local/Cloud Activity Logging
│   └── widgets/
│       ├── animated_list_item.dart         # Cascading Staggered Entrance Animations
│       ├── empty_state.dart                # Pulsing Ring & Scale Feedbacks
│       └── shimmer_card.dart               # Stop-sorting Assertion Proof Skeleton Loaders
└── features/
    ├── auth/                               # Sign-In, Registration, Splash Screens & Providers
    ├── calendar/                           # Deadline Visualizations & Filters
    ├── clients/                            # Client Records, Avatars, Profiles, Freelancers Screen
    ├── dashboard/                          # Stat Counters, Count-ups, Celebration Goal Rings
    ├── payments/                           # Invoices, UPI QR, Image/Text Sharing Sheets
    └── projects/                           # Project Pipelines, comments, and Voice Recording
```

---

## 🗄️ Database & Storage Architecture (Supabase)

EditFlow relies on Supabase (PostgreSQL) for authentication, tables, and storage buckets. Row-Level Security (RLS) is enabled globally to isolate data between freelancers and clients.

### 1. Database Schema
* **`public.profiles`**: Synchronized automatically with `auth.users` via a Postgres trigger.
  * `id` UUID PRIMARY KEY (references `auth.users(id)`)
  * `full_name` TEXT, `email` TEXT
* **`public.clients`**: Stores client organizations and maps them to client users.
  * `id` UUID PRIMARY KEY
  * `user_id` UUID (references `auth.users(id)`) -> Owning Freelancer
  * `client_user_id` UUID (references `auth.users(id)`) -> Mapped Client User (for Portal access)
  * `name` TEXT, `phone` TEXT, `email` TEXT, `company` TEXT, `notes` TEXT
* **`public.projects`**: Main entity for tracking creative jobs.
  * `id` UUID PRIMARY KEY
  * `user_id` UUID (references `auth.users(id)`) -> Owning Freelancer
  * `client_id` UUID (references `clients.id`)
  * `name` TEXT, `description` TEXT, `price` NUMERIC, `received_amount` NUMERIC, `deadline` TIMESTAMPTZ, `status` TEXT (yet_to_start, in_progress, revision_pending, completed, paid)
* **`public.comments`**: Project feed comments supporting audio attachments.
  * `id` UUID PRIMARY KEY
  * `project_id` UUID (references `projects.id` ON DELETE CASCADE)
  * `user_id` UUID (references `auth.users(id)`)
  * `user_name` TEXT, `content` TEXT
  * `voice_url` TEXT (nullable public storage link)
  * `voice_duration` INT (nullable duration in seconds)
* **`public.activities`**: Audit trail of freelancer operations.

### 2. Row Level Security (RLS) Policies
* **`profiles`**: Users can select profiles belonging to themselves, their assigned clients, or their owning freelancer.
* **`clients`**: Freelancers can read/write their own client records. Client users can only read their matching client row.
* **`projects`**: Freelancers can read/write their own projects. Clients can only select projects whose `client_id` matches their client record.
* **`comments`**: Readable and writeable by anyone authenticated who has access to the parent project record.

### 3. Database Sync Trigger (SQL)
Run this script inside the Supabase SQL editor to install triggers and syncher:
```sql
CREATE OR REPLACE FUNCTION public.handle_user_sync()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (new.id, COALESCE(new.raw_user_meta_data->>'full_name', 'User'), new.email)
  ON CONFLICT (id) DO UPDATE
  SET full_name = EXCLUDED.full_name, email = EXCLUDED.email;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_changed
  AFTER INSERT OR UPDATE OF email, raw_user_meta_data ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_user_sync();
```

---

## ⚡ State Management & Riverpod Data Flow

The application relies heavily on Riverpod `AsyncNotifier` and `StreamProvider` variables.

```
       ┌────────────────────────┐
       │   authProvider         │
       └───────────┬────────────┘
                   ▼
       ┌────────────────────────┐
       │   settingsProvider     │
       └───────────┬────────────┘
                   ▼
 ┌─────────────────┴─────────────────┐
 ▼                                   ▼
[Freelancer Mode]              [Client Mode]
- ProjectRepository            - ClientProjectRepository
- Swaps stream queries         - Blocks writes (throws errors)
- Show all metrics             - Translates label metrics
- Full bottom navigation tabs  - Collapses bottom tabs to 2
```

### Cache Invalidation Mechanism
When toggling `isClientMode` inside `settingsProvider`, the local memory caches flags (`_hasLoadedOnce` and `_lastValidData`) inside `projectProvider` and `clientProvider` are automatically cleared. This ensures that switching profiles pulls fresh data from Supabase instead of displaying stale, cached queries.

---

## 🔒 Client View Mode (Client Portal) Details

When a client signs in, they are placed in a read-only portal:
* **Write Lockdowns**: Any edits, creations, deletions, or data imports/exports are hidden in UI. The repository layer switches to `ClientProjectRepository` which explicitly throws `UnsupportedError` on database modifications.
* **Navigation Collapsing**: Floating app shell bottom bar collapses from 4 tabs down to 2 (Dashboard & Freelancers screen).
* **Metric Conversions**: Business earnings are translated to client expenditures:
  * "Total Earnings" -> **Total Expense**
  * "Pending Revenue" -> **Total Due**
  * "Top Clients" -> **Top Freelancers** (ordered by upcoming deadline urgency).

---

## 💳 UPI QR Code & Invoice Receipt Flow

The payments screen displays visual invoice receipts and handles QR generating logic.

* **Indian Bank Security Compliance**: Prefilled parameters such as amount (`am`), note (`tn`), and currency (`cu`) are deliberately omitted from native UPI deep links (`upi://pay?pa=...&pn=...`). This guarantees that banking applications (like Paytm, PhonePe, GPay, and Kotak 811) resolve VPAs successfully without hitting security flags.
* **Error Correction Level (`QrErrorCorrectLevel.H`)**: Set to High to handle center-embedded logo coverage (up to 30%). This prevents "invalid QR code" errors when scanning.
* **Launcher Monogram Design**: The center of the QR embeds EditFlow's official flowing **"ef" monogam** launcher logo, featuring a 2px white border margin frame.
* **Invoice Layout**: Centered vertical cards with dedicated "UPI PAYMENT" divider lines. Sticky "Share Image" and "Share Text" actions are anchored to the bottom of the sheet, preventing scrolling fatigue.

---

## 🎙️ Compressed Voice Notes & Auto-cleanup Pipeline

EditFlow features compressed voice notes for project feedback to stay well within Supabase's 1GB Free Tier limits.

```
[Audio Recording] -> Low Bitrate AAC/M4A (16kHz, 24kbps) -> File Size ~180KB/min
        │
        ▼ (Uploads to Bucket)
[Supabase Storage] -> Bucket: "voice-notes" / Path: "projects/{project_id}/{fileName}.m4a"
        │
        ▼ (Dashboard Initialization / Refresh)
[Background Cleanup] -> Selects records > 14 days old -> Deletes files & Nullifies URLs
```

* **Codec Settings**: Encoded using `AudioEncoder.aacLc` with a 16kHz sample rate and 24kbps bitrate, capping files at exactly **60 seconds** (approx. 180 KB total).
* **14-day Auto-cleanup**: Whenever the dashboard completes initialization, `CommentRepository.cleanupOldVoiceNotes()` queries the database for feedback rows older than 14 days. It deletes corresponding files from the `voice-notes` bucket and nullifies the database columns `voice_url` and `voice_duration`. This maintains a very low storage footprint.

---

---

## 🔋 Android Foreground Service & Background Synchronization

EditFlow runs a persistent Android Foreground Service isolating notifications and metrics synchronization:
* **Background Isolate Thread**: Uses `flutter_foreground_task` to query updates directly on a background isolate thread context, avoiding app sleep suspensions.
* **SharedPreferences Auth Bridge**: Since UI-heavy `Supabase.initialize` fails in background isolates during release builds, the isolate queries user credentials (ID & Session JWT token) stored safely inside `SharedPreferences` by the main thread on login/refresh. It instantiates a pure Dart `SupabaseClient` with `Authorization: Bearer <token>` headers to bypass UI storage dependencies.
* **Dual Monitoring Modes**: 
  - **Freelancer Mode**: Persistently shows active project count: `Active: X Projects | Running in background`.
  - **Client Mode**: Persistently shows total assigned creative collaborators: `Freelancers: X | Active Projects: Y`.
* **Robust WebSockets & Polling Fallback**: streams data in real-time using Supabase database subscriptions. If the background socket connection drops, it automatically falls back to secure REST HTTP polling every 30 seconds.
* **VM Entry-point Protection**: Callback entrypoints and handling classes/methods are guarded with `@pragma('vm:entry-point')` to prevent the R8 compiler from stripping or obfuscating background isolate routines in release builds.

---

## 🌐 Marketing Website & GitHub Pages Deployment

The `/docs/` folder contains a responsive marketing landing page optimized to deploy directly via **GitHub Pages**:
* **Assets and Mono-Logo**: Employs the custom-designed programmatic **"ef" vector monogram** (`logo.svg`) and holds the compiled production APK (`editflow.apk`) for direct user downloads.
* **Custom Mobile Mockup**: An interactive CSS frame notch holds the real dashboard screenshot. Configured with a smooth transition scrolling the viewport on hover.
* **Features Grid**: Details dedicated value propositions for Freelancer Workspace and Client Portal systems.

---

## 🚀 Getting Started & Agent Commands

### 1. Environment Setup
Create a `.env` file at the root:
```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 2. Default System Configurations
* **Currency**: Defaults to **INR (₹)** for all projects, pipelines, and dashboard counters on both portals.
* **Theme**: Defaults to **Dark Mode** on initial launch and clear-data startups.

### 3. Standard Development Tasks
* **Fetch Dependencies**: `flutter pub get`
* **Static Analysis**: `flutter analyze` (ensure `lib/` directory remains with 0 issues).
* **Run Tests**: `flutter test` (all 10 unit/widget tests must pass).
* **Build Android APK**: `flutter build apk --release` (generates release binaries inside `build/app/outputs/flutter-apk/app-release.apk` and copies to `docs/editflow.apk` for the site).

### 4. ProGuard / R8 Release Build Exceptions
Release compilations optimize binary code using R8. Add the following rules to `android/app/proguard-rules.pro` to prevent stripping of Supabase authentication session models and isolate task callbacks:
```proguard
-keep class com.supabase.** { *; }
-keep class io.supabase.** { *; }

# Keep background service task handler entrypoints
-keep class * extends com.pravera.flutter_foreground_task.models.TaskHandler { *; }
-keepclassmembers class * {
    @kotlin.jvm.JvmStatic <methods>;
}
```
