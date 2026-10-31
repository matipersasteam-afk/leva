# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

(The shipping product is a Flutter app for iOS and Android plus Flutter Web public routes (`/tv/{eventId}`, live bracket link). The current artifact is an HTML prototype. Confirmed: the UI is identical on iOS and Android, 100% LEVA identity, only unavoidable native details (back gesture, safe areas, keyboard) follow the OS.)

## Stack

Prototype: single self-contained HTML file (CSS/JS inline, Google Fonts allowed), opens with double click. Product: Flutter + Firebase (Auth, Firestore, Cloud Functions, Storage, FCM). State management: to be chosen in PLAN.md.

## Users

- **Jugador**: amateur/competitive padel player in Guadalajara who registers with a partner, pays, checks in at the venue and follows their match times, court and live score from the phone, often standing at the club between matches.
- **Organizador/admin de LEVA**: creates events, tracks paid/pending registrations, generates the draw and schedule, handles delays on tournament day.
- **Juez/staff**: loads results from the phone at court side, point by point or final score.
- **Público en la sede**: watches the club TV (`/tv/{eventId}`) and the public live bracket link without an account.

## Product Purpose

The official tournament app of LEVA (Guadalajara, México; @leva.padel; "Gente · Pádel · Experiencias"). It runs LEVA tournaments end to end: registration in pairs, payment, draw, schedule, results, push notifications, QR check-in and the club TV. Success: a real LEVA tournament runs on it from registration to final.

## Positioning

Functional reference is Courtbit, but this is single-organizer and must feel like LEVA's own brand (their Instagram flyers), not a generic multi-club platform.

## Operating Context

Tournament days at the venue: players check phones between matches in bright or night club lighting; staff work court side with one hand; a TV in the club rotates bracket, live matches, upcoming matches and sponsors and calls pairs to court. Payments for physical events go through Mercado Pago (México) or Stripe, outside Apple in-app purchase.

## Capabilities and Constraints

MVP: auth + player profile (photo, name, nickname, category 3ra/4ta/5ta/6ta/Suma 9, club, hand, drive/revés, LEVA history); event creation with categories, slots, price, venue, dates; pair registration (invite by link/user, accept), availability, waitlist; payment + admin paid/pending; draw formats (groups + knockout, single elimination, americano, relámpago), ranking seeding, same-club avoidance in round one, manual adjust; auto schedule by courts with availability and minimum rest, drag-and-drop editing, delay recalculation with notices; padel scoring (sets, games, golden point or advantage, optional super tie-break), loaded by judge or players with rival confirmation; public live bracket; push notifications; QR check-in; TV screen. Future (data model only): circuit ranking and badges, ambassadors, Instagram plate generator, broadcast overlay, YouTube player, sponsors, replay highlights. All UI copy in Spanish (México).

## Brand Commitments

Binding, from the brief (approximate values, to be replaced by official ones):
- Ground: deep black / very dark navy (~#0A0D14 / ~#0E1626). Secondary: shield navy (~#1B2A4A).
- Accent: metallic gold always as a gradient (~#8C6A2E → #D4AF5A → #F3DC9A), never flat yellow.
- Text white and light gray.
- Display type: condensed, extra bold, italic (player names, titles, "¡VAMOS A ROMPERLA!"). Support type: thin sans, wide tracking, uppercase ("BIENVENIDO", "GENTE · PÁDEL · EXPERIENCIAS").
- Tone: epic, aspirational, premium sports poster. Phrases: "Talento | Disciplina | Futuro", "¡Vamos a romperla!".
- Logo: navy shield with gold border, paddle with a ball in orbit.
- Must feel like their Instagram flyers: cut-out player photos, high contrast, gold as protagonist.

## Evidence on Hand

No official logo, photos, sponsor logos or brand values yet. The prototype uses labeled placeholders (approximate SVG shield, typographic portrait plates, "Logo sponsor" slots). Sample data (players Julia Gasparini, Marvin, Becker, César "Chispita" de Anda and invented others, venues, prices, dates) is illustrative and must not be read as real.

## Product Principles

1. Match day first: what the player needs at the venue (court, time, score) is reachable in one tap.
2. LEVA's poster identity everywhere, but never at the cost of reading a time, a court or a score.
3. One organizer, no multi-tenant configuration; brand tokens centralized.
4. Scoring, draw and schedule logic are separate from UI and tested.
5. Uncertain facts (payments, store rules) are stated, never assumed.
