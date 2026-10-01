import { ButtonHTMLAttributes } from "react";

const icons = {
  view: "M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6",
  edit: "M16 3l5 5 M4 16L17 3a2 2 0 0 1 3 3L7 19l-4 1z",
  power: "M12 2v10 M6 5a9 9 0 1 0 12 0",
  access: "M12 3l8 4v6c0 5-8 9-8 9s-8-4-8-9V7z M9 12h6 M12 9v6",
  review: "M5 3h10l4 4v14H5z M14 3v5h5 M8 14l2 2 5-5",
  refresh: "M20 7V3 M20 3h-4 M20 3l-4 4a8 8 0 1 0 3 9",
  publish: "M12 16V3 M7 8l5-5 5 5 M4 15v6h16v-6",
  unpublish: "M12 3v13 M7 11l5 5 5-5 M4 15v6h16v-6",
  reply: "M9 5l-6 6 6 6 M3 11h10a7 7 0 0 1 7 7",
  refund: "M4 10V4 M4 4h6 M4 4l4 4a8 8 0 1 1-2 8 M12 10v6 M9 13h6",
  redeem: "M3 8h18v4H3z M5 12v9h14v-9 M12 8v13 M12 8H8a3 3 0 1 1 3-3z M12 8h4a3 3 0 1 0-3-3z",
};

type Props = Omit<ButtonHTMLAttributes<HTMLButtonElement>, "children"> & {
  label: string;
  icon: keyof typeof icons;
  tone?: "neutral" | "danger" | "success";
};

export function RowAction({ label, icon, tone = "neutral", ...props }: Props) {
  return <button {...props} type="button" className={`row-action ${tone}`} aria-label={label} title={label}>
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={icons[icon]} /></svg>
  </button>;
}
