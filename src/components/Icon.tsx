import React from "react";

const paths: Record<string, React.ReactNode> = {
  home: <><path d="M3 11.5 12 4l9 7.5"/><path d="M5.5 10.5V20h13v-9.5M9.5 20v-6h5v6"/></>,
  library: <><path d="M5 4h12a2 2 0 0 1 2 2v14H7a2 2 0 0 1-2-2Z"/><path d="M5 18a2 2 0 0 1 2-2h12M9 8h6"/></>,
  check: <path d="m5 12 4 4L19 6"/>,
  star: <path d="m12 3 2.7 5.5 6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1-4.4-4.3 6.1-.9Z"/>,
  clock: <><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>,
  desk: <><path d="M4 5h16v12H4zM8 21h8M12 17v4"/><path d="m8 11 2.3 2.3L16 8"/></>,
  document: <><path d="M6 3h8l4 4v14H6z"/><path d="M14 3v5h5M9 13h6M9 17h6"/></>,
  change: <><path d="M4 7h11M12 4l3 3-3 3M20 17H9M12 14l-3 3 3 3"/></>,
  approval: <><path d="M12 3 4 6v5c0 5.2 3.4 8.6 8 10 4.6-1.4 8-4.8 8-10V6Z"/><path d="m8.5 12 2.2 2.2 4.8-5"/></>,
  calendar: <><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4M17 3v4M3 10h18M8 14h.01M12 14h.01M16 14h.01M8 18h.01M12 18h.01"/></>,
  alert: <><path d="M12 3 2.8 20h18.4Z"/><path d="M12 9v5M12 17h.01"/></>,
  report: <path d="M5 20V10M12 20V4M19 20v-7"/>,
  platform: <><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></>,
  sites: <><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.2 2.4 3.3 5.4 3.3 9S14.2 18.6 12 21M12 3C9.8 5.4 8.7 8.4 8.7 12S9.8 18.6 12 21"/></>,
  automation: <><path d="M4 7h8M16 7h4M14 5v4M4 17h4M12 17h8M10 15v4"/></>,
  records: <><path d="M5 4h14v16H5zM8 8h8M8 12h8M8 16h5"/></>,
  integration: <><path d="M8 12H3M21 12h-5"/><path d="M8 12a4 4 0 1 0 8 0 4 4 0 1 0-8 0Z"/></>,
  deploy: <><path d="m12 3 7 4-7 4-7-4Z"/><path d="m5 12 7 4 7-4M5 17l7 4 7-4"/></>,
  recovery: <><path d="M4 12a8 8 0 1 0 2.3-5.7L4 8"/><path d="M4 4v4h4"/></>,
  audit: <><path d="M6 3h12v18H6zM9 8h6M9 12h6M9 16h3"/></>,
  search: <><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></>,
  arrow: <path d="m9 5 7 7-7 7"/>,
  close: <path d="m6 6 12 12M18 6 6 18"/>,
  download: <><path d="M12 3v12M7 10l5 5 5-5M5 21h14"/></>,
  external: <><path d="M14 4h6v6M20 4l-9 9"/><path d="M18 13v7H4V6h7"/></>,
  plus: <path d="M12 5v14M5 12h14"/>,
  menu: <path d="M4 7h16M4 12h16M4 17h16"/>,
  bell: <><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9"/><path d="M10 21h4"/></>,
  help: <><circle cx="12" cy="12" r="9"/><path d="M9.7 9a2.5 2.5 0 1 1 3.8 2.1c-.9.5-1.5 1-1.5 2.1M12 17h.01"/></>,
};

export function Icon({ name, className = "" }: { name: string; className?: string }) {
  return <svg className={`icon ${className}`} viewBox="0 0 24 24" aria-hidden="true">{paths[name] ?? paths.document}</svg>;
}
