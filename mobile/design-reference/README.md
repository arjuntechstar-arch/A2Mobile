# Selected A2Mobile design references

These ten original HTML/screenshot pairs were copied from `Template_mobile app`.
`DESIGN.md` preserves the supplied Kinetic Retail specification. Reference HTML
is a design artifact, not a runnable part of the Flutter application; its sample
prices, claims, external images and placeholder links are not application data.

| Template | Application use |
| --- | --- |
| Store home | Blue upgrade hero, coral benefit banner, rounded quick actions |
| Available schemes | Blue plan panels with real monthly amounts and benefits |
| Payments account | Contribution summary above existing transaction history |
| Account settings | Account heading and grouped account actions |
| Auth access | Login gradient header, pill navigation, lavender fields, white card and benefit strip; existing registration/reset routes preserved |
| Edit profile 1 | Reference retained for personal details forms |
| KYC verification | Reference retained for verification forms |
| Maturity / redemption | Reference retained for eligible redemption flow |
| Premature withdrawal | Reference retained for refund requests |
| Settlement receipt viewer | Reference retained for receipt presentation |

Implemented native components live in `lib/retail_design.dart`, integrated into
the dashboard, schemes, payments and profile in `lib/main.dart`. The app uses
the template's cobalt/coral palette and light lavender canvas. Typography uses
the installed Flutter font rather than fetching the template's web fonts.

`lib/login_design.dart` adapts the authentication layout for A2Mobile, with a
password visibility toggle and existing email/password sign-in. Sample social
login, biometrics, voucher, warranty and security claims are omitted because
they are not supported app capabilities.

Home banners link to the existing schemes tab. They advertise scheme discovery
without inventing discounts or changing published financial terms. Plan panels
read monthly amounts, installment counts and benefits from the existing API.
The payment summary covers only the recent records returned by the API.

Excluded: product catalog/search, shopping cart, delivery tracking, warranties,
trade-in offers, autopay mandates and concierge chat. These templates assume
capabilities or guarantees that the customer app does not currently provide.
Duplicate receipt, profile and refund-state mockups were also omitted.
