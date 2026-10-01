---
name: Kinetic Retail
colors:
  surface: '#faf8ff'
  surface-dim: '#d2d9f4'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f3ff'
  surface-container: '#eaedff'
  surface-container-high: '#e2e7ff'
  surface-container-highest: '#dae2fd'
  on-surface: '#131b2e'
  on-surface-variant: '#434655'
  inverse-surface: '#283044'
  inverse-on-surface: '#eef0ff'
  outline: '#737686'
  outline-variant: '#c3c6d7'
  surface-tint: '#0053db'
  primary: '#004ac6'
  on-primary: '#ffffff'
  primary-container: '#2563eb'
  on-primary-container: '#eeefff'
  inverse-primary: '#b4c5ff'
  secondary: '#b02f00'
  on-secondary: '#ffffff'
  secondary-container: '#fe5824'
  on-secondary-container: '#531100'
  tertiary: '#006242'
  on-tertiary: '#ffffff'
  tertiary-container: '#007d55'
  on-tertiary-container: '#bdffdb'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174b'
  on-primary-fixed-variant: '#003ea8'
  secondary-fixed: '#ffdbd1'
  secondary-fixed-dim: '#ffb5a0'
  on-secondary-fixed: '#3b0900'
  on-secondary-fixed-variant: '#862200'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#faf8ff'
  on-background: '#131b2e'
  surface-variant: '#dae2fd'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '800'
    lineHeight: 44px
  headline-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '800'
    lineHeight: 36px
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 30px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 28px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 10px
    fontWeight: '800'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system crafts an energetic, premium, yet accessible consumer electronics and home appliance marketplace. The identity balances high-velocity commerce with trust, technical clarity, and joyful discovery. The target audience comprises modern consumers purchasing flagship smartphones, high-efficiency appliances, and smart home ecosystems—users who prioritize specs, speed, competitive pricing, and seamless financing.

The aesthetic fuses **Modern Vivid Retail** with subtle **Frosted Glass Elements**. It relies on crisp, luminous surfaces, generous touch affordances, bold color blocking, and fluid micro-elevations. The experience evokes confidence and excitement, avoiding visual clutter through structured hierarchy, tactile cards, and luminous promotional triggers.

## Colors

The palette leverages an electric cobalt blue anchor paired with high-impact energetic coral, amber financing markers, and crisp mint reassurance badges.

- **Primary (`#2563EB` Electric Cobalt):** Conveys digital authority, technical competence, and clarity. Used for primary conversion actions, active states, key specs, and core branding elements.
- **Secondary (`#FF5925` Vivid Coral):** Commands immediate urgency and delight. Applied exclusively to high-conversion catalysts: deal tickers, flash sale banners, price drops, and "Add to Cart" checkout accelerators.
- **Tertiary (`#10B981` Mint Emerald):** Signals instant reassurance, successful stock availability, environmental efficiency ratings, and "In Stock / Express Delivery" triggers.
- **Accent Amber (`#F59E0B`):** Reserved for flexible payment badges, "0% No-Cost EMI", loyalty coin awards, and customer rating stars.
- **Surface & Backgrounds:** The base canvas operates on soft bright ivory (`#F8FAFC` to `#FFFFFF`), preserving eye comfort during extensive product comparisons while keeping elevated cards crisp and distinct.
- **Text & Neutral (`#0F172A` Deep Slate):** Delivers superior contrast and optical clarity without the harshness of pure black. Secondary copy uses `#64748B`.

## Typography

The type system pairs **Plus Jakarta Sans** for headlines, display marketing copy, and prominent product badges with **Inter** for dense specs, descriptions, checkout details, and pricing tables.

- **Headlines & Display:** Expressive, rounded geometry communicates youthfulness and high energy while retaining robust legibility at small sizes.
- **Body & Specs:** Inter delivers uncompromised neutrality and precision across multi-line technical comparisons (RAM, processor speed, capacity, dimensions).
- **Labels & Badges:** Tracked tightly with heavy weights (`700` and `800`) to guarantee legibility on high-density mobile screens inside promo badges and discount pills.

## Layout & Spacing

A mobile-first 4-column layout on standard hand-held viewports expands to an 8-column layout on tablets and 12 columns on desktop viewports. 

- **Outer Margins:** Fixed at `1rem` (16px) on mobile viewports (`<640px`) to maximize horizontal screen real estate for two-column product grids. Shifts to `1.5rem` on tablets and `2rem` on wide screens.
- **Horizontal Carousels:** Bleed to device edges using negative outer margins with `1rem` interior padding, allowing promotional banners and product cards to hint at scrollability cleanly.
- **Grid Rhythms:** Product listings use a 2-column layout on mobile with `0.75rem` to `1rem` gaps, stepping up to 3 columns on tablet and 4-5 columns on desktop setups.

## Elevation & Depth

Visual hierarchy uses clean multi-layered depth, combining soft ambient color-tinted drop shadows with crystalline frosted glass headers and overlays.

- **Level 0 (Flat Canvas):** `#F8FAFC`. Zero elevation, base canvas for grouping segments.
- **Level 1 (Card & Containers):** `#FFFFFF` fill with `box-shadow: 0 4px 16px -2px rgba(37, 99, 235, 0.06), 0 2px 6px -1px rgba(15, 23, 42, 0.04)`. Creates separation without heavy boundary lines.
- **Level 2 (Active Elements & Hover/Touch):** `box-shadow: 0 10px 25px -4px rgba(37, 99, 235, 0.12), 0 4px 10px -2px rgba(15, 23, 42, 0.05)`. Used on active product cards, floating filter buttons, and quick-add actions.
- **Level 3 (Sticky Bottom Bars & Modals):** `box-shadow: 0 -8px 30px rgba(15, 23, 42, 0.08)`. Anchors sticky checkout actions and EMI option sheets.
- **Retail Badges & Floaters (Glassmorphism):** Translucent overlays use `background: rgba(255, 255, 255, 0.82)`, `backdrop-filter: blur(12px)`, and a subtle 1px border `rgba(255, 255, 255, 0.6)`. Gives deal tags and specs a light, floating appearance over imagery.

## Shapes

The design system incorporates generous, smooth curvature throughout, maintaining a tactile and approachable feel.

- **Standard Surfaces & Cards:** Styled with `1rem` (16px) to `1.25rem` (20px) radius for product tiles, modal sheets, and promo blocks.
- **Hero & Promotional Units:** Styled with `1.5rem` (24px) radius for featured banners, category spotlight clusters, and interactive trade-in containers.
- **Interactive Controls & Badges:** Primary buttons, search bars, tag chips, and promotional pills utilize full pill shapes (`rounded-full` / `9999px`) to create an inviting, tap-friendly UI.

## Components

### Buttons
- **Primary Action (Cobalt):** Full pill shape, `#2563EB` solid background, white text, bold weight (`Plus Jakarta Sans`), subtle blue glow on press (`0 6px 16px rgba(37, 99, 235, 0.35)`).
- **Secondary Conversion (Coral):** High-urgency trigger for "Buy Now" and "Flash Deal". Solid `#FF5925`, white text.
- **Ghost & Spec Buttons:** White background with a 1.5px border of `#E2E8F0`, dark slate text, transitioning to `#EFF6FF` on press.

### Retail Badges & Chips
- **0% EMI Scheme Badges:** Translucent amber tint (`#FEF3C7`), text and border in `#D97706`. Displays upfront monthly calculation (e.g., "$49/mo at 0% APR").
- **Offer & Deal Tags:** Pill badges with saturated coral fills (`#FF5925`) and bold white typography. Glassmorphic variant uses `rgba(255, 89, 37, 0.15)` with `#FF5925` text for non-intrusive on-image overlays.
- **Category Filter Chips:** Horizontal pill chips, height 36px. Unselected state is white with subtle border `#E2E8F0`; selected state is bold Electric Cobalt `#2563EB` with pure white text and an ambient blue shadow.

### Product Cards
- **Structure:** Clean white background, 16px padding, 20px corner radius, containing an unboxing-style product render on a neutral slate-50 circular backdrop.
- **Badging Area:** Top-left stacked glassmorphic badges (e.g., "Save 25%", "0% EMI"); top-right floating wishlist toggle.
- **Details:** High-contrast price with strike-through MRP, headline title capped at 2 lines, star rating chip with `#F59E0B` icon, and an instant-add circular button.

### Form Inputs & Search Bar
- **App Bar Search:** Pill-shaped, 48px height, `#F1F5F9` background, `#64748B` placeholder, inset search icon, and a mic/barcode scan icon on the right trailing edge.
- **Prequalification & Detail Inputs:** 12px corner radius, clean 1.5px border transitioning from `#CBD5E1` to active `#2563EB` focus ring with a 3px diffused outer halo.

### Checkboxes & Radio Controls
- Radio controls for specification pickers (e.g., storage capacity, colorways) are designed as rectangular interactive chips with 12px rounded corners, showing immediate price differences per tier.