# Bin Perks: Platform Overview & Feature Guide

Bin Perks is a comprehensive, location-based digital loyalty and rewards platform. The system replaces traditional paper stamp cards with a modern, fast, and secure digital experience. 

The platform consists of three main components:
1. **Customer App** (Mobile App)
2. **Vendor App** (Mobile App - built into the same application)
3. **Admin Dashboard** (Web Panel)

Here is a complete breakdown of how the platform works and the features available.

---

## 📱 1. Customer Experience

The customer side of the mobile application is designed to help users discover local businesses and effortlessly collect loyalty stamps.

### Features:
*   **Location-Based Discovery:** 
    *   Customers open the app and instantly see curated businesses near their physical location.
    *   Interactive filtering allows users to sort businesses by category (e.g., Coffee Shops, Spas, Retail).
    *   Displays real-time distance and "Open/Closed" status based on the business's operating hours.
*   **Digital Loyalty Cards:**
    *   When a customer clicks on a business, they can view the business's "Stamp Goal" (e.g., *Buy 9 coffees, get the 10th free*).
    *   Customers can join the loyalty program with one tap, creating a digital card.
*   **The Personal QR Code:**
    *   Every customer has a unique, secure QR code in their app.
    *   To get a stamp, the customer simply shows this QR code to the vendor at the point of sale. 
    *   The QR code is also used to redeem earned rewards.
*   **Live Progress & Rewards:**
    *   Customers can track their stamp progress on the "Streaks" screen.
    *   Once a card is completed, a "Reward" is automatically generated and saved in their wallet for future use.
*   **Ratings & Reviews:**
    *   Customers can leave a rating and review for businesses they interact with, helping to build community trust.

---

## 🏪 2. Vendor (Business) Experience

Vendors use the exact same mobile app but unlock a powerful set of business tools once their account is approved by the platform administrators.

### Features:
*   **Onboarding & Approval Flow:**
    *   Business owners sign up and submit their business details. They are placed in a "Pending" state until an Admin reviews and approves them.
*   **The Secure Scanner:**
    *   The core of the vendor experience. Vendors use their phone's camera to scan a customer's QR code.
    *   **Smart Scanning:** The scanner automatically detects if it needs to award a stamp or redeem a reward.
    *   **Anti-Fraud Cooldowns:** Vendors can set a "Stamp Cooldown" (e.g., 60 minutes) to prevent customers from getting multiple stamps back-to-back in a single visit.
*   **Live Dashboard & Analytics:**
    *   Vendors have access to a real-time dashboard showing their performance.
    *   Metrics include: Total stamps issued today, unique customers this month, and rewards claimed.
    *   A live "Activity Feed" shows exactly who was scanned and when.
*   **Profile Management:**
    *   Vendors can update their profile picture, business address (using Google Places autocomplete), category, and description.
    *   **Operating Hours:** Detailed control over opening and closing times for each day of the week.
    *   **Pause Visibility:** A toggle to temporarily hide their business from the Discovery screen if they are fully booked or on holiday.
    *   **Customizable Goals:** Vendors control the rules—they decide how many stamps are needed and what the final reward is.
*   **Billing & Subscriptions (Yoco Integration):**
    *   Vendors must pay a subscription to keep their profile active.
    *   Integrated with Yoco payment links. If a subscription expires, the vendor receives warnings and risks having their profile hidden.

---

## 💻 3. Admin Dashboard (Web)

The Next.js Web Admin Panel gives the platform owners complete oversight and control over the ecosystem.

### Features:
*   **Global Dashboard:**
    *   High-level metrics showing total users, total businesses, active subscriptions, and overall platform engagement.
*   **Business Approvals:**
    *   A dedicated queue for reviewing newly registered businesses. 
    *   Admins can approve or reject applications to maintain the quality of the platform.
*   **Business Management:**
    *   Admins can view detailed profiles of every business on the platform.
    *   **Access Control:** Admins can manually add 30-day access extensions to a vendor's account or instantly revoke access.
    *   **Suspensions:** Admins can suspend a business (hiding them from the app) and must provide a reason, which the vendor will see on their screen.
*   **Content Moderation:**
    *   **Photos:** Admins can review all uploaded business profile photos and delete inappropriate ones.
    *   **Flagged Reviews:** If a vendor flags a customer review as spam or inappropriate, it enters the moderation queue. Admins can read the review and choose to either dismiss the flag or permanently delete the review.

---

## 🔒 Security & Architecture Notes
*   **Firebase Backend:** Real-time data sync across all apps.
*   **Role-Based Access Control:** Strict security rules ensure customers cannot award themselves stamps, and vendors can only edit their own data.
*   **Cloud Functions:** Secure execution of payment link generation to ensure API keys are never exposed on the mobile device.
