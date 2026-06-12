# EditFlow — Data Flow Report (Redesigned)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       UI Layer (Widgets)                         │
│  Dashboard, Client Detail, Project Detail, Settings, Calendar    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ ConsumerWidget / ConsumerStatefulWidget                   │  │
│  │   ref.watch(computedProvider) → auto-derived data         │  │
│  │   ref.read(provider.notifier).method() → mutate data      │  │
│  │   NEVER calls Supabase directly                           │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────────────┘
                       │ watch / read
┌──────────────────────▼──────────────────────────────────────────┐
│                  Computed Providers (derived)                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ dashboardMetricsProvider          (Provider)              │  │
│  │   - Derives from projectProvider + clientProvider         │  │
│  │   - Single source for ALL dashboard numbers               │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ dashboardPeriodMetricsProvider    (Provider.family)       │  │
│  │   - Period-filtered Earning/Paid/Pending/Overdue          │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ clientMetricsProvider             (Provider.family)       │  │
│  │   - Per-client Total/Revenue/Pending/ProjectCount         │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ clientListDataProvider            (Provider)              │  │
│  │   - Client + aggregated metrics for list view             │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ paymentOverviewProvider           (Provider)              │  │
│  │   - Total/Received/Remaining/Overdue/Paid lists            │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ calendarDeadlinesProvider         (Provider)              │  │
│  │   - Filtered projects with non-paid deadlines             │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ pipelineMapProvider               (Provider)              │  │
│  │   - Map<ProjectStatus, int> count per status              │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────────────┘
                       │ derive from
┌──────────────────────▼──────────────────────────────────────────┐
│                    Riverpod State Providers                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ ProjectProvider (AsyncNotifier<List<Project>>)            │  │
│  │   - build() → repo.getAll() + realtime subscription      │  │
│  │   - Realtime: .stream() updates state directly (no fetch) │  │
│  │   - OPTIMISTIC: update state first, rollback on error     │  │
│  │   - Mutations: addProject, updateProject, deleteProject,  │  │
│  │                updateStatus                                │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ ClientProvider (AsyncNotifier<List<Client>>)              │  │
│  │   - build() → repo.getAll() + realtime subscription      │  │
│  │   - Realtime: .stream() updates state directly            │  │
│  │   - OPTIMISTIC: update state first, rollback on error     │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ RecentActivityNotifier (AsyncNotifier<List<Activity>>)    │  │
│  │   - build() → fetch top 10 + realtime subscription       │  │
│  │   - Realtime: .stream() updates state directly            │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ SettingsProvider (StateNotifier)                          │  │
│  │   - Persists to SharedPreferences                        │  │
│  │   - Fields: currency, isDarkMode, monthlyGoal             │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────────────┘
                       │ create / update / delete
┌──────────────────────▼──────────────────────────────────────────┐
│                    Repository Layer                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ ProjectRepository                                         │  │
│  │   - getAll()       : GET projects JOIN clients WHERE user │  │
│  │   - create()       : POST insert project                  │  │
│  │   - update()       : PATCH update project                 │  │
│  │   - delete()       : DELETE project                       │  │
│  │   - logStatusChange: Uses shared ActivityService          │  │
│  │   Auto-logs: project_created on create                   │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ ClientRepository                                          │  │
│  │   - getAll()       : GET clients WHERE user               │  │
│  │   - create()       : POST insert client                   │  │
│  │   - update()       : PATCH update client                  │  │
│  │   - delete()       : DELETE client                        │  │
│  │   Auto-logs: client_created, client_updated (if renamed), │  │
│  │              client_deleted                                │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ ActivityService (shared)                                  │  │
│  │   - log()         : POST insert into activities table     │  │
│  │   - Used by both repositories + project provider          │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────────────┘
                       │ supabase.from().select() / .insert() / .update() / .delete()
┌──────────────────────▼──────────────────────────────────────────┐
│                     SupabaseService                             │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Supabase.initialize(url, anonKey, pkce)                   │  │
│  │   - Auth: PKCE flow (AuthFlowType.pkce)                   │  │
│  │   - Client: Supabase.instance.client                      │  │
│  │   - userId: SAFE getter (throws if null instead of crash) │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
┌─────────────────┐ ┌──────────┐ ┌──────────────┐
│  Supabase Auth  │ │ REST API │ │  Realtime    │
│  (PKCE)         │ │ /rest/v1 │ │  WebSocket   │
└─────────────────┘ └──────────┘ └──────────────┘
```

---

## Realtime Strategy

```
Supabase Realtime (PostgreSQL WAL)
  │
  ├─ projects table changes (INSERT / UPDATE / DELETE)
  │    │
  │    └─ WebSocket push → SupabaseStreamBuilder maintains in-memory copy
  │         │
  │         └─ .stream(primaryKey: ['id']) emits FULL list on every change
  │              │
  │              ├─ Provider ALREADY HAS the data: directly sets state
  │              │  state = AsyncData(rows.map(Project.fromJson))
  │              │
  │              └─ NO network call needed — stream payload IS the data
  │
  └─ clients table changes (same pattern)
```

**Key improvement**: The old architecture used `ref.invalidateSelf()` which triggered a full `repo.getAll()` network call on every change. The new architecture receives the complete data list via the stream and sets state directly — zero network overhead.

## Optimistic Update Flow

```
User marks project as "Paid"
  │
  ├─ Update state IMMEDIATELY (optimistic)
  │  state = AsyncData(projects.map(p → p.id == id ? updated : p))
  │
  ├─ Fire repo.update(project) asynchronously
  │    │
  │    ├─ SUCCESS: Replace optimistic update with confirmed server data
  │    │  state = current.map(p → p.id == confirmed.id ? confirmed : p)
  │    │
  │    └─ FAILURE: Rollback to previous state
  │       state = AsyncData(previousState)
  │       state = AsyncError(e, st)
  │
  └─ On success: log activity via repo.logStatusChange()
```

This pattern is used for ALL mutations:
- `addProject`: Optimistically prepend temp object, replace with server response
- `updateProject`: Optimistically replace, confirm with server
- `deleteProject`: Optimistically remove, restore on error
- `addClient / updateClient / deleteClient`: Same pattern
- `updateStatus`: Optimistically update status (and receivedAmount if to/from Paid), confirm with server

## Activity System

| Mutation | Activity Type | Logged By |
|---|---|---|
| Client created | `client_created` | `ClientRepository.create()` |
| Client renamed | `client_updated` | `ClientRepository.update()` |
| Client deleted | `client_deleted` | `ClientRepository.delete()` |
| Project created | `project_created` | `ProjectRepository.create()` |
| Project deleted | `project_deleted` | `ProjectProvider.deleteProject()` |
| Status changed | `status_changed` | `ProjectProvider.updateStatus()` |
| Payment received | `payment_received` | `ProjectProvider.updateStatus()` → Paid |

## Computed Providers (Eliminating Duplicated Logic)

All duplicated fold/reduce logic has been consolidated into `lib/shared/providers/computed_providers.dart`:

| Provider | What it provides | Previously duplicated across |
|---|---|---|
| `dashboardMetricsProvider` | All dashboard numbers (revenue, received, pending, overdue, active clients, charts, pipeline, top clients) | dashboard_screen.dart (_DashboardData.compute + _computePeriodMetrics) |
| `dashboardPeriodMetricsProvider` | Period-filtered Earning/Paid/Pending/Overdue | dashboard_screen.dart |
| `clientMetricsProvider` | Per-client Total/Revenue/Pending/ProjectCount | clients_screen.dart, client_detail_screen.dart |
| `clientListDataProvider` | Client + aggregates for list rendering | clients_screen.dart |
| `paymentOverviewProvider` | Total/Received/Remaining/Overdue/Paid lists | payments_screen.dart |
| `calendarDeadlinesProvider` | Non-paid deadlines | calendar_screen.dart |
| `pipelineMapProvider` | Count per status | dashboard_screen.dart |
| `isProjectOverdue()` | Reusable overdue check | project_card.dart (×3), dashboard, payments, calendar |
| `statusColor()` | Single status→color mapping | status_badge.dart, pipeline_card.dart, project_status_section.dart |

## Data Ownership Rules

```
Project owns:                  Client owns:
  price                          name
  received_amount                phone
  status                         email
  deadline                       company
  description                    notes

Dashboard owns nothing — only aggregates project data.

All derived values (remainingAmount, client totals, 
payment overviews) are computed on the fly.
NO derived values are ever stored in Supabase.
```

---

## Data Flow: Write (Creating / Updating Data)

```
User taps "Mark as Paid" in Status Pipeline
  │
  ├─ _StatusPipeline.GestureDetector.onTap()
  │    │
  │    └─ _changeStatus(project, ProjectStatus.paid)
  │         │
  │         ├─ Show confirmation dialog
  │         │
  │         └─ ref.read(projectProvider.notifier).updateStatus(id, paid)
  │              │
  │              ├─ project.copyWith(status: paid, receivedAmount: price)
  │              │    [If reversing: copyWith(status: newStatus, receivedAmount: 0)]
  │              │
  │              ├─ updateProject(updatedProject)
  │              │    │
  │              │    ├─ repo.update(project)
  │              │    │    │
  │              │    │    ├─ project.toJson()..remove('client_name')
  │              │    │    │
  │              │    │    └─ SupabaseService.instance
  │              │    │         .from('projects')
  │              │    │         .update(data)
  │              │    │         .eq('id', project.id)
  │              │    │         .select()
  │              │    │         .single()
  │              │    │
  │              │    │    └─ Returns updated row from DB
  │              │    │         → Project.fromJson(response)
  │              │    │
  │              │    └─ state = AsyncData(updatedList)
  │              │         [Replaces project in list in-memory]
  │              │
  │              ├─ repo.logActivity('payment_received', ...)
  │              │    │
  │              │    └─ SupabaseService.instance
  │              │         .from('activities')
  │              │         .insert({ user_id, type, description, reference_id, reference_type })
  │              │
  │              └─ [on error] state = AsyncError(e, st)
  │
  └─ Widget rebuilds:
     │
     ├─ Riverpod detects state change (AsyncData with updated list)
     ├─ All widgets watching projectProvider rebuild
     ├─ Dashboard recalculates _DashboardData.compute()
     ├─ Client Detail recalculates health chips
     └─ Pipeline rerenders with new status
```

---

## Data Flow: Realtime Updates (Other Devices)

```
Supabase Realtime (PostgreSQL WAL)
  │
  ├─ projects table changes (INSERT / UPDATE / DELETE)
  │    │
  │    └─ WebSocket push to all connected clients
  │         │
  │         └─ SupabaseService.instance
  │              .from('projects')
  │              .stream(primaryKey: ['id'])
  │              .listen((_) => ref.invalidateSelf())
  │                   │
  │                   └─ ref.invalidateSelf()
  │                        │
  │                        ├─ Riverpod marks provider as "stale"
  │                        ├─ Provider rebuilds: repo.getAll()
  │                        │
  │                        └─ Widgets rebuild with new data
  │
  └─ clients table changes (same pattern)
```

**Note:** Realtime does NOT auto-push the changed data — it sends a "something changed" signal, then the provider re-fetches ALL data via `getAll()`. This ensures consistency but means N+1 fetches for every update.

---

## Data Flow: Status Pipeline (Complete Cycle)

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Status Pipeline Widget                         │
│  Container                                                          │
│  ├─ "Progress" section label                                        │
│  └─ List of 5 steps:                                                │
│       Yet to Start   (gray)         ── tap ──┐                      │
│       In Progress    (purple)        ── tap ──┤                      │
│       Revision Pending (orange)      ── tap ──┤                      │
│       Completed      (blue)          ── tap ──┤  → Confirmation     │
│       Paid           (green)         ── tap ──┘    Dialog           │
│                                                       │             │
│  Each step: InkWell with ripple, chevron hint          │             │
│  - Completed steps: green checkmark                    │             │
│  - Current step: "Current" badge + edit icon           │             │
│  - Future steps: gray, subtle chevron                  │             │
└───────────────────────────────────────────────────────┬─────────────┘
                                                        │
                                                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    _changeStatus(project, newStatus)                 │
│  AlertDialog: "Move 'Project X' to 'Paid'?"                        │
│    [Cancel]  [Confirm]                                               │
│         │         │                                                  │
│         └─────────┤                                                  │
│                   ▼                                                  │
│  ref.read(projectProvider.notifier).updateStatus(id, newStatus)      │
│                   │                                                  │
│                   ▼                                                  │
┌─────────────────────────────────────────────────────────────────────┐
│                    ProjectProvider.updateStatus()                     │
│                                                                      │
│  ┌─ TO paid:                                                        │
│  │  project.copyWith(status: paid, receivedAmount: price)           │
│  │  → updateProject() → Supabase PATCH                             │
│  │  → logActivity('payment_received')                               │
│  │                                                                   │
│  ├─ FROM paid to other:                                              │
│  │  project.copyWith(status: newStatus, receivedAmount: 0)          │
│  │  → updateProject() → Supabase PATCH                             │
│  │                                                                   │
│  └─ Any other transition:                                            │
│     project.copyWith(status: newStatus)                              │
│     → updateProject() → Supabase PATCH                              │
│                    │                                                  │
│                    ▼                                                  │
│  state = AsyncData(updatedList)  ← in-memory update                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Data Models (JSON ← → Dart)

### Project (`projects` table)

| JSON Key | Dart Field | Type | Notes |
|---|---|---|---|
| `id` | `id` | `String` | UUID, `gen_random_uuid()` default |
| `user_id` | `userId` | `String` | FK to `auth.users` |
| `client_id` | `clientId` | `String` | FK to `clients(id)`, CASCADE delete |
| `name` | `name` | `String` | |
| `description` | `description` | `String?` | |
| `price` | `price` | `double` | `NUMERIC`, default 0 |
| `received_amount` | `receivedAmount` | `double` | `NUMERIC`, default 0 |
| `deadline` | `deadline` | `DateTime?` | `TIMESTAMPTZ` |
| `status` | `status` | `ProjectStatus` | `TEXT`, default `yet_to_start`, CHECK constraint |
| `created_at` | `createdAt` | `DateTime` | `TIMESTAMPTZ`, default `now()` |
| `updated_at` | `updatedAt` | `DateTime` | `TIMESTAMPTZ`, default `now()`, auto-updated by trigger |

**Computed:** `remainingAmount = price - receivedAmount` (Dart getter, not in DB)

**Status CHECK values:** `yet_to_start`, `in_progress`, `revision_pending`, `completed`, `paid`

### Client (`clients` table)

| JSON Key | Dart Field | Type | Notes |
|---|---|---|---|
| `id` | `id` | `String` | UUID, `gen_random_uuid()` default |
| `user_id` | `userId` | `String` | FK to `auth.users` |
| `name` | `name` | `String` | |
| `phone` | `phone` | `String?` | |
| `email` | `email` | `String?` | |
| `company` | `company` | `String?` | |
| `notes` | `notes` | `String?` | |
| `created_at` | `createdAt` | `DateTime` | `TIMESTAMPTZ`, default `now()` |
| `updated_at` | `updatedAt` | `DateTime` | `TIMESTAMPTZ`, default `now()`, auto-updated by trigger |

### Activity (`activities` table)

| JSON Key | Dart Field | Type | Notes |
|---|---|---|---|
| `id` | `id` | `String` | UUID |
| `user_id` | `userId` | `String` | FK to `auth.users` |
| `type` | `type` | `String` | e.g. `project_created`, `payment_received` |
| `description` | `description` | `String` | Human-readable text |
| `reference_id` | `referenceId` | `String?` | UUID of related entity |
| `reference_type` | `referenceType` | `String?` | e.g. `project` |
| `created_at` | `createdAt` | `DateTime` | `TIMESTAMPTZ`, default `now()` |

---

## Riverpod Provider Graph

```
                        ┌──────────────────┐
                        │  SharedPreferences│
                        └────────┬─────────┘
                                 │
                        ┌────────▼─────────┐
                        │  SettingsProvider │
                        │  StateNotifier    │
                        │  {currency,       │
                        │   isDarkMode,     │
                        │   monthlyGoal}    │
                        └──┬──────────┬────┘
                           │          │
                  ┌────────▼──┐  ┌────▼──────────┐
                  │currency   │  │  AppTheme     │
                  │Provider   │  │  (ThemeMode)  │
                  └───────────┘  └───────────────┘

        ┌───────────────────────┐
        │  Supabase Realtime    │
        │  WebSocket            │
        └──┬───────────────┬────┘
           │               │
    ┌──────▼──────┐  ┌─────▼──────┐
    │ ClientPro-  │  │ ProjectPro- │
    │ vider       │  │ vider       │
    │ AsyncNotif- │  │ AsyncNotif- │
    │ ier         │  │ ier         │
    │ List<Client>│  │ List<Project│
    └──────┬──────┘  └──────┬──────┘
           │                │
    ┌──────▼──────┐  ┌──────▼──────────┐
    │ ClientRepos │  │ ProjectRepo     │
    │ -ory        │  │ -sitory         │
    └──────┬──────┘  └──────┬──────────┘
           │                │
           └────┬───────────┘
                │
         ┌──────▼──────────┐
         │ SupabaseService │
         │ .from() queries │
         └─────────────────┘
```

---

## Provider Graph (Riverpod)

```
                        ┌──────────────────┐
                        │  SharedPrefs     │
                        └────────┬─────────┘
                                 │
                        ┌────────▼─────────┐
                        │  SettingsProvider │
                        │  StateNotifier    │
                        └──┬──────────┬────┘
                           │          │
                  ┌────────▼──┐  ┌────▼──────────┐
                  │currency   │  │  AppTheme     │
                  │Provider   │  │  (ThemeMode)  │
                  └───────────┘  └───────────────┘

 Supabase Realtime WebSocket
  │              │              │
  ▼              ▼              ▼
┌────────┐ ┌──────────┐ ┌──────────────┐
│Project │ │ Client   │ │  Activity    │
│Provider│ │ Provider │ │  Notifier    │
│AsyncNot│ │ AsyncNot │ │  AsyncNot    │
│ -ifier │ │ -ifier   │ │  -ifier      │
└───┬────┘ └────┬─────┘ └──────┬───────┘
    │           │               │
    └───────┬───┘               │
            │                   │
   ┌────────▼────────┐         │
   │ Computed        │         │
   │ Providers       │         │
   │ (derived from   │         │
   │  project +      │         │
   │  client lists)  │         │
   │                 │         │
   │ • dashboardMetr │         │
   │ • clientMetrics │         │
   │ • paymentOverv  │         │
   │ • calendarDeadl │         │
   │ • pipelineMap   │         │
   └────────┬────────┘         │
            │                  │
   ┌────────▼────────┐         │
   │ UI Widgets      │◄────────┘
   │ (read computed  │
   │  providers,     │
   │  never fold)    │
   └─────────────────┘
```

## Key Data Transformations

### Period-filtered Metrics (Dashboard `_computePeriodMetrics`)

```
Projects list
  │
  ├─ Filter by period (month/year/all)
  │    · month: updatedAt after month start
  │    · year:  updatedAt after year start
  │    · all:   no filter
  │
  ├─ earning  = ∑ filtered    .price
  ├─ paid     = ∑ filtered    .receivedAmount
  ├─ pending  = ∑ filtered    .remainingAmount
  └─ overdue  = ∑ (all past deadline AND not paid) .remainingAmount
```

### Client Detail Health Chips

```
Client's projects
  │
  ├─ Total     = ∑ .price              (sum of all project prices)
  ├─ Revenue   = ∑ .receivedAmount     (sum of all payments received)
  ├─ Pending   = ∑ .remainingAmount    (sum of all remaining balances)
  └─ Projects  = count                 (total project count)
```

### Status Pipeline Visual State

```
currentIndex = orderIndex of project.status (0-4)

For each step i:
  isCompleted = i < currentIndex    → green dot + checkmark
  isCurrent   = i == currentIndex   → blue dot + "Current" badge + edit icon
  isFuture    = i > currentIndex    → gray dot + chevron hint

Timeline: dots connected by vertical lines
  · completed steps: solid green line
  · future steps: muted gray line
```
