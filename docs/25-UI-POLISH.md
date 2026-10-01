# UI refinement and review

The second UI pass completes the sidebar icons and form grouping from the first pass.

## Changes

- Every admin navigation item has its own outline icon within the existing menu groups.
- Customer, store, staff, notification, identity review, support, refund, redemption, content and banner dialogs have labeled sections. Scheme, customer, store and redemption fields use two desktop columns and one phone column.
- Admin dialogs have readable titles and accessible dialog names.
- Table rows expose direct action icons with tooltips and accessible names: View, Edit, and the relevant operational actions. Customer deactivation and scheme unpublishing retain confirmation prompts. The duplicate Settings “Edit published content” toolbar button is removed; use each content row's Edit icon. Existing banners likewise use the row Edit icon, while an empty banner page offers Add banner. Record deletion is not supported by the current API.
- Scheme and notification headings wrap beside their refresh buttons on narrow customer screens.
- Product cards show the monthly amount above a smaller “per month” label so the unit does not wrap through the amount.
- Banner uploads accept dropped files as well as the upload control. Existing file-type, size and image-count limits remain in effect.
- Banner previews show the customer text gradient, fitted images, message overlays and selectable slides. Removing a slide keeps the preview on a valid remaining image.
- The active-scheme card loads authenticated customer enrollments independently. Its refresh button updates only the card, preserves the selected enrollment and last loaded figures, and leaves banner position, shortcuts and page scroll unchanged. Refresh errors and retry stay within the card.

## Verification

- Admin production build and 3 existing tests passed.
- Customer web production build passed. Existing Node-version, optional WebAssembly and Cupertino-icon build warnings remain.
- Flutter analysis passed, and all 28 mobile tests passed, including catalog/inbox checks at 320px and 390px with 150% text scaling, card-only refresh with preserved selection/banner/scroll position, and local retry after a failed refresh.
- Headless Chrome checked all 21 navigation icons and 12 admin dialogs at 1440px and 390px. The review checked section labels, horizontal overflow, readable table dates, image upload, preview selection and removal.
- Customer browser review covers Home, Schemes, Profile and Notifications at phone widths, plus Home on desktop.

Admin browser checks use synthetic API responses and do not save records. Customer browser checks use the documented local demo customer account. Browser screenshots complement widget tests; they do not replace a native-device review.

## Local previews

Screenshots and the review scripts are in `artifacts/ui-review/`, which is excluded from Git. The scripts require Python Playwright and Chrome, with the local apps running on ports 5173 and 5174.

- [Admin dashboard](../artifacts/ui-review/admin-dashboard-desktop.png)
- [Grouped scheme form](../artifacts/ui-review/admin-create-draft-scheme-desktop.png)
- [Customer form on a phone](../artifacts/ui-review/admin-edit-customer-mobile.png)
- [Banner image preview](../artifacts/ui-review/admin-banner-image-preview.png)
- [Customer Home](../artifacts/ui-review/mobile-home.png)
- [Schemes at 320px](../artifacts/ui-review/mobile-schemes-320.png)
- [Notifications at 320px](../artifacts/ui-review/mobile-notifications-320.png)
- [Profile at 390px](../artifacts/ui-review/mobile-profile-390.png)
