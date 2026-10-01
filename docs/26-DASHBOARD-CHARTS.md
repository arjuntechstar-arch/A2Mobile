# Interactive dashboard charts

The staff dashboard shows four primary figures, three interactive charts, and an expandable section for the remaining dashboard totals.

## Collection trends

- Switch between the last 7, 30 or 90 calendar days, including today.
- Switch between captured contribution amounts and captured payment counts.
- Hover or tap a day, or focus the chart and use Left/Right, Home or End, to inspect contributions, payment count and gateway fees.
- Period totals and daily averages include zero-activity days.
- Refresh the chart independently. A failed refresh retains the previous chart and offers a local retry.

The chart uses `/admin/reports/collections?group=day`, which groups captured payments in the India calendar. Amounts remain in paise until formatting as INR. Figures show gross contributions before gateway fees. A missing reporting day becomes zero activity; a failed request displays an error rather than zero data.

## Enrollment activity

The donut compares current active and completed enrollments, with counts and percentages. Select a legend item or hover its arc to inspect that status. Other enrollment statuses are excluded from this comparison. Users with enrollment-read permission can open the enrollment table.

## Payments and follow-up

Selectable horizontal bars compare overdue installments, unpaid installments due today, and pending redemptions. Selecting a bar explains the work it represents. These counts are independent: due-today and overdue installments may overlap. Users with enrollment-read permission can open the overdue table.

These two charts use the existing `/admin/reports/summary` response. All chart data requires the existing report-read permission.

## Verification

The admin production build and all 6 tests passed. Tests cover India calendar boundaries, zero-activity dates, selected-period totals and paise arithmetic. Browser checks cover range/measure controls, keyboard inspection, selected statuses, refresh/retry, missing data, navigation, and layouts at 1440px, 390px and 320px. The existing Vite Node-version warning remains.

Local screenshots and the browser review script are excluded from Git under `artifacts/ui-review/`:

- [Desktop preview](../artifacts/ui-review/admin-charts-desktop.png)
- [Phone preview](../artifacts/ui-review/admin-charts-390.png)
- [Browser interaction checks](../artifacts/ui-review/chart_review.py)
