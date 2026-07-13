# Release Notes - EditFlow v1.2.0

We are excited to release **EditFlow v1.2.0**, introducing a persistent Android Foreground Service with WebSocket/polling synchronization fallback, two-way status notification portals, custom-branded landing website (hosted via GitHub Pages), default INR currency support, and simplified compliant UPI deep links.

---

## 🚀 What's New in v1.2.0

### 🔋 Persistent Android Foreground Service
* **Background Isolate & SharedPreferences Bridge**: Configured the service to run on a background isolate. Rewrote Supabase client creation using pure Dart `SupabaseClient` with credentials retrieved from `SharedPreferences` to bypass `WidgetsFlutterBinding` initialize crashes in release builds.
* **Dual Monitoring Stats**: Notification drawer dynamically updates to show active workspace metrics:
  - **Freelancer**: `Active: X Projects | Running in background`
  - **Client**: `Freelancers: X | Active Projects: Y` (reads unique creative collaborators count).
* **WS Stream & 30s Polling Fallback**: streams alerts in real-time, automatically falling back to secure HTTP polling every 30 seconds if the socket connection drops.
* **VM Protection**: Guarded task handler methods with `@pragma('vm:entry-point')` to prevent R8 optimizer from stripping background isolate routines in release APKs.

### 💵 Defaults and Custom Sharing
* **INR Default**: Swapped default currency token to **INR (₹)** for both Freelancer and Client Portal systems.
* **Simple UPI Links**: Simplified UPI deep links to `upi://pay?pa=upiId` without amount or note parameters, ensuring compatibility across all mobile banking apps.
* **Invoice Greeting Message**: Prepend custom greeting text block to shared invoices mentioning the client's name, project details, and a freelancer sign-off greeting dynamically.

### 🌐 GitHub Pages Deployment (/docs)
* **docs/ Landing Folder**: Relocated the marketing website files to the `/docs/` folder, allowing instant free static hosting via GitHub Pages.
* **Vector logo & Interactive Mockup**: Employs the programmatic **"ef" monogram logo** as an SVG vector (`logo.svg`) and a CSS phone notch frame that scrolls the viewport screenshot automatically on hover.

---

# Release Notes - EditFlow v1.1.0

We are excited to release **EditFlow v1.1.0**, featuring major visual upgrades, a client-facing view mode, real-time collaboration comment streams, and custom scan-to-pay UPI payment QR codes.

---

## 🚀 What's New

### 💳 UPI Payments & Custom QR Codes
* **Compliant UPI Deep Links**: Generates native `upi://pay?pa=...&pn=...` payment links synced with settings. Refactored link parameters to exclude prefilled amounts, notes, and currency, complying with updated Indian bank app security policies to ensure instant, valid scans.
* **Flawless Scanner Readability**: Set QR code generation to High Error Correction (`QrErrorCorrectLevel.H`), allowing scanners (Google Pay, PhonePe, Paytm) to decode data even with center-logo coverage.
* **Monogram Brand Branding**: Embedded the official teal-to-emerald gradient **"ef"** monogram launcher logo with a crisp 2px white border inside the center of the QR code.
* **Symmetrical Invoice Card**: Redesigned the visual invoice modal layout from an asymmetrical side-by-side view to a beautifully aligned vertical list with custom-highlighted balance details and no empty/wasted space.
* **Sticky Bottom Actions**: Locked "Share Image" and "Share Text" buttons to the bottom of the invoice preview sheet, allowing easy sharing without scrolling.

### 🔒 Client Portal & Read-Only Mode
* **Client View Switch**: Activated a switch in Settings to toggle Client Mode (persisted locally and synced with Supabase user metadata).
* **Interface Lockdown**: Automatically hides adding, editing, and deleting capabilities, data import/export backups, and call-to-actions when in Client Mode.
* **Bottom Navigation Adaptability**: Navigation dynamically changes to display only two tabs (Dashboard & Freelancers) instead of the freelancer's four tabs, scaling the floating indicator bar seamlessly.
* **Client Metrics & Freelancers List**: Translates metrics from business earnings to client expenditures (e.g., Total Expense, Total Due) and replaces client rankings with a "Top Freelancers" layout tracking active upcoming deadlines.
* **Read-Only Repositories**: Swaps the data repository layer to `ClientProjectRepository` at runtime to block write actions.

### 💬 Real-time Comments & Feedback
* **Supabase Real-Time Streams**: Enabled dynamic `.stream(primaryKey: ['id'])` listeners on a new `comments` table to instantly push comments and feedback.
* **Collaborative Detail View**: Added a comment feed section directly underneath project details, enabling live feedback communication between clients and freelancers.

### ✨ Premium UI/UX & Motion Design
* **Count-Up Stat Cards**: Numbers animate smoothly from zero to their target values using curved tween builders.
* **Fill Goal Ring**: The monthly revenue tracker ring animates progress on screen entry and triggers a scale-pulse celebration sequence when reaching 100%+.
* **Smooth Shimmer Card Loaders**: Replaced plain spinners with advanced, responsive skeleton shimmer loaders that prevent stop-sorting linear gradient glitches.
* **Polished Empty States**: Added entrance slide-up/fade animations, a soft glowing ring backdrop, scale-pulse loops, and click-scaling buttons.
* **Cascade Transitions**: Staggered list view entrances with capped animation delays.
* **Physical Click Haptics**: Added selection vibrations on floating navigation bar selections.
* **Dynamic Blur Transitions**: Re-implemented page transitions with customizable Gaussian image blur timelines and symmetric push/pop velocities.

---

## 🛠 Bug Fixes & Stability
* **Client Detail Screen Layout Crash**: Removed the `LayoutBuilder` wrapper from `ProjectCard` progress indicators to resolve Flutter's `LayoutBuilder does not support returning intrinsic dimensions` speculative-height assertion.
* **Project Detail Back Navigation**: Replaced the hardcoded client-profile back routing with a smart `context.canPop()` fallback, preventing route-not-found exceptions when accessing deep links.
* **Focus Node settings persistence**: Inputs (like UPI ID) now save on focus-lost or submission to eliminate cursor jumping.
* **ProGuard / R8 Exceptions**: Added explicit keep rules inside `proguard-rules.pro` to prevent compilation stripping of Supabase authentication session models in release builds.

---

## 📥 Getting Updated
To pull the latest changes, run the following commands in your terminal:
```bash
git checkout main
git pull origin main
flutter pub get
```
*Note: Since the router route schema has changed, a **Hot Restart** (or cold app restart) is required to re-initialize GoRouter settings.*
