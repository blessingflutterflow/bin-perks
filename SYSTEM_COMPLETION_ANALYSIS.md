# Bin Perks — What Does "Finished" Really Mean?

## The Business Model in Plain Terms

Bin Perks is a **B2B2C SaaS loyalty platform**:
- **Vendors pay you** a monthly subscription to run their loyalty programs
- **Customers use it free** to collect stamps and redeem rewards
- Your revenue only exists if vendors are active, paying, and their customers keep coming back

Every gap below is analyzed not as a missing feature, but as a broken link in that chain.

---

## TIER 1 — Platform Cannot Operate Without These

### 1. Subscription & Payment System
**Status: Entirely missing. Zero code exists.**

This is the most critical gap. There is no payment infrastructure anywhere in the codebase. A vendor can onboard, get approved, and operate forever for free.

**Complete dependent workflow:**

```
Vendor signs up
  → chooses subscription plan (e.g. Basic R299/mo, Pro R599/mo)
  → enters card via Stripe (or PayFast for South Africa)
  → 14-day free trial starts
  → Day 12: email reminder "trial ends in 2 days"
  → Day 14: first charge attempted
     ├─ SUCCESS → business stays live, invoice emailed
     └─ FAIL → 3-day grace period
                → Day 1–3: daily retry + email warnings to vendor
                → Day 3 fail → business status set to 'suspended'
                   → vendor's business disappears from customer discovery
                   → vendor sees "Payment Required" screen in app
                   → vendor updates card → immediate reactivation

Monthly billing cycle:
  → Charge on renewal date
  → Success → invoice emailed
  → Fail → same grace period loop
  → Vendor cancels → business stays live until end of billing period
     → then suspended, loyalty cards preserved for customers
```

**What the admin needs as a result:**
- Revenue dashboard: MRR, ARR, trial count, active subscribers, churned
- Ability to manually extend a trial or comp a month
- See every vendor's payment history and subscription status
- Get alerted when a payment fails

**What the vendor needs:**
- See their current plan, renewal date, and payment method in-app
- Upgrade/downgrade options
- Billing history with invoice download

---

### 2. Reward Redemption Flow
**Status: Broken. The core product mechanic is incomplete.**

Customers collect stamps and a `rewardCount` field increments in Firestore — but there is **no way to actually redeem a reward**. The loyalty loop has no closing mechanism.

**Complete dependent workflow:**

```
Customer's stampCount reaches stampGoal
  → card flips to "Reward Ready!" state (no such UI exists currently)
  → customer visits the business
  → customer shows a "Redeem" screen (separate from the QR stamp screen)
  → TWO OPTIONS for redemption:
     Option A (standard): Customer shows redemption QR → vendor scans it in scanner
     Option B (manual):   Vendor taps "Redeem Reward" button for that customer
                          in their dashboard

  On successful redemption:
  → loyalty doc: stampCount resets to 0, rewardCount stays (lifetime counter)
  → a new 'redemptions' collection doc is written (for audit trail)
  → customer sees "Reward Claimed!" confirmation
  → vendor's dashboard shows redemption in history

  Edge case — customer has 2 completed cards (rewardCount = 2):
  → they should be able to redeem one, keeping the second pending
```

Without this, you have a loyalty app that promises rewards but can never deliver them.

---

### 3. Vendor Suspension / Status Lifecycle
**Status: Partial. Approve/reject exists. Nothing else.**

Currently `status` can only move `pending → approved` or `pending → rejected`. There is no path for suspending an active vendor, reactivating them, or giving a rejected vendor a way forward.

**Full lifecycle that needs to work:**

```
pending   → approved   (admin approves)
pending   → rejected   (admin rejects + reason stored)

approved  → suspended  (non-payment OR admin policy action)
  → vendor sees "Account Suspended" screen with reason
  → business hidden from customer discovery
  → scanner blocked — vendor cannot stamp customers

suspended → approved   (payment resolved OR admin clears)

rejected  → pending    (vendor edits application and resubmits)
  → currently impossible — rejected vendors are stuck forever
```

The admin needs a single control panel to move any vendor through these states with a required reason field.

---

### 4. Firestore Security Rules
**Status: Completely open. `allow read, write: if true`**

This is a production blocker. Anyone with the Firebase config (which is in your public JavaScript bundle) can read every user's data, write arbitrary stamps to any loyalty card, or delete the entire database.

**Minimum rules needed:**
- Customers can only read/write their own loyalty docs
- Vendors can only write to their own business doc
- Only the stamp-award function (or authenticated vendor) can increment stamps
- Only an admin role can change `businesses.status`
- Stamp awards should use a server-side Cloud Function to prevent clients from self-awarding

---

### 5. Admin Vendor Detail Page
**Status: Missing. The approvals queue works, but post-approval visibility is zero.**

After a vendor is approved, there is no way to click into their account and understand their health. You need to be able to view any vendor and see:
- Current subscription status and full payment history
- Total enrolled customers, stamps issued this month, redemptions
- Their reviews and average rating
- A button to suspend/reactivate with a required reason
- Their business profile with all submitted details

Without this, you're flying blind on every vendor relationship.

---

## TIER 2 — Users Will Churn Without These

### 6. Push Notifications
**Status: Zero infrastructure. No FCM tokens stored anywhere.**

Without push notifications, customers forget about every business they've stamped with. The re-engagement loop is completely missing.

| Trigger | Recipient | Message |
|---|---|---|
| Stamp awarded | Customer | "Stamped at [Business]! X more until your reward" |
| Reward ready | Customer | "Your reward at [Business] is ready to claim!" |
| Near a business with an active card | Customer | "[Business] is nearby — you have X stamps" |
| New review received | Vendor | "You got a 5-star review!" |
| Subscription renewal in 3 days | Vendor | "Your plan renews on [date]" |
| New pending vendor | Admin | "New vendor waiting for approval" |

**Requires:** storing FCM tokens on user docs, Cloud Functions backend to send on Firestore triggers, and permission request handling in Flutter.

---

### 7. Email Notifications
**Status: Zero. Firebase Auth handles password reset only.**

**Minimum emails required before launch:**

| Email | Recipient | Trigger |
|---|---|---|
| Welcome / Approved | Vendor | Admin approves business |
| Rejection + reason | Vendor | Admin rejects business |
| Monthly invoice | Vendor | Successful payment |
| Payment failed | Vendor | Stripe charge failure |
| Suspension warning | Vendor | 24 hours before suspension |
| First stamp welcome | Customer | First stamp at any business |

---

### 8. Real Analytics Data (Vendor Dashboard & Admin)
**Status: Core metrics are live Firestore data. Growth charts are hardcoded/simulated.**

The admin dashboard growth chart explicitly contains `// Simulated data - in production you'd query by createdAt`. The vendor dashboard has no period-over-period comparisons.

**What needs to change:**
- Every Firestore document needs a `createdAt` timestamp at write time
- Admin growth chart must query real data grouped by month
- Vendor dashboard needs "this month vs last month" for stamps, new customers, redemptions
- Vendor needs to see time-of-day visit patterns (when do customers actually come in?)

---

### 9. Discovery Filters & Search
**Status: Map/list view exists. No filtering of any kind.**

A customer cannot currently filter by category, search by name, or sort the list. As the platform grows past 10 businesses, an unfiltered feed becomes unusable.

**Needed:**
- Filter by category (all 11 categories already exist as labels — just need a filter UI)
- Search by business name
- Sort by: nearest / newest / most popular
- Show "You have X stamps here" on cards where the customer already has a loyalty card
- "Open Now" indicator (depends on business hours being stored — see item 10)

---

### 10. Business Hours & Pause Capability
**Status: Not collected during onboarding. Not stored in Firestore.**

A vendor with limited hours or who closes temporarily has no way to communicate that. Customers show up, get confused, and blame the platform.

**Needed:**
- Business hours (per day) collected in onboarding or vendor profile
- "Temporarily Paused" toggle in vendor profile — hides business from discovery without requiring admin intervention or full suspension
- Discovery shows an "Open Now" indicator based on current time vs stored hours

---

## TIER 3 — Important for Scale and Professionalism

### 11. Vendor Onboarding: Plan Selection Step
The onboarding form collects all business info but never prompts for a subscription plan. The final step of onboarding should be plan selection and payment, so a vendor cannot become "approved and live" without entering billing details. Currently there is a gap between "admin approves" and "vendor pays."

### 12. Content Moderation
- Business profile photos are uploaded directly to Firebase Storage with zero review
- Customer reviews are written directly to Firestore with no moderation layer
- A bad actor can upload inappropriate images that appear in customer discovery immediately

**Minimum needed:** a flag/report system on reviews, and a photo review queue visible in the admin app.

### 13. Customer Profile Completeness
A customer currently cannot edit their name or profile photo. They also have no history of redeemed rewards — only currently active stamp cards. Missing:
- Edit name / upload avatar
- Full reward redemption history
- Notification preferences toggle
- Delete account (a legal requirement in most jurisdictions)

### 14. Rejected Vendor Re-submission Path
A rejected vendor is stuck on the waiting screen forever with no explanation and no way forward. They need to:
- See the rejection reason (stored on the business doc by admin at time of rejection)
- Be able to edit their application and resubmit, returning the status to `pending`

### 15. Terms of Service & Privacy Policy
No legal agreements are shown or accepted anywhere during signup. Before collecting payment from anyone, this is non-negotiable. A checkbox + stored `agreedToTermsAt` timestamp is the minimum.

### 16. Admin Audit Log
There is currently no record of who approved what, when, or who changed a vendor's status. Before this platform handles real money, every admin action must be logged to a Firestore `auditLogs` collection: `{ adminId, action, targetId, reason, timestamp }`.

### 17. Multi-location Support (Future)
Currently one vendor account = one business doc. As chain vendors or franchises come on board, a single account will need multiple locations that share one subscription but appear as separate pins on the customer discovery map. This doesn't need to exist at launch but the data model should not make it impossible.

---

## The 3 Things That Define "Finished"

Compressed to the minimum for a confident "this system works":

**1. Money flows correctly**
Vendors pay, subscriptions are enforced, non-payers are blocked, and you can see your revenue in the admin dashboard. Without this you have a charity, not a business.

**2. The loyalty loop closes**
Customers can actually redeem rewards, not just collect stamps into a void. This is the core value proposition of the entire product. Right now the loop is permanently open.

**3. You can intervene**
As the platform owner, you can suspend a bad actor, reactivate someone who paid, see every vendor's account health, and know what every admin action was and when. Right now you are a passive observer with no real levers.

Everything else matters and builds on top of these three.

---

## Implementation Priority Order

| # | Feature | Tier | Touches |
|---|---|---|---|
| ~~1~~ | ~~Reward redemption flow~~ | ~~1~~ | ~~Flutter (both sides) + Firestore~~ |
| ~~2~~ | ~~Vendor status lifecycle (suspend/reactivate/resubmit)~~ | ~~1~~ | ~~Flutter + Admin~~ |
| ~~3~~ | ~~Subscription & payment system (Yoco)~~ | ~~1~~ | ~~Flutter + Admin~~ |
| ~~4~~ | ~~Business hours + pause toggle~~ | ~~2~~ | ~~Flutter (vendor + discovery)~~ |
| ~~5~~ | ~~Discovery filters & search~~ | ~~2~~ | ~~Flutter (customer)~~ |
| ~~6~~ | ~~Rejected vendor re-submission~~ | ~~3~~ | ~~Flutter (vendor)~~ |
| ~~7~~ | ~~Real analytics data (createdAt + queries)~~ | ~~2~~ | ~~Flutter + Admin~~ |
| ~~8~~ | ~~Admin vendor detail page~~ | ~~1~~ | ~~Admin (Next.js)~~ |
| ~~9~~ | ~~Customer write-a-review flow~~ | ~~2~~ | ~~Flutter (customer)~~ |
| ~~10~~ | ~~Customer profile edit + reward history~~ | ~~3~~ | ~~Flutter (customer)~~ |
| ~~11~~ | ~~Push notifications (FCM)~~ | ~~2~~ | ~~Flutter + Cloud Functions~~ |
| 12 | Email notifications | 2 | Cloud Functions + SendGrid/Resend — *deferred until first paying clients* |
| ~~13~~ | ~~Terms of service acceptance~~ | ~~3~~ | ~~Flutter (both)~~ |
| ~~14~~ | ~~Content moderation queue~~ | ~~3~~ | ~~Admin (Next.js)~~ |
| 15 | Admin audit log | 3 | Admin + Cloud Functions |
| ~~16~~ | ~~Firestore security rules~~ | ~~1~~ | ~~Firebase — do last, after dev is complete~~ |
