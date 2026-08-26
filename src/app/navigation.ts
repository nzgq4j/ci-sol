import type { Role } from "../domain/types";

export type PageId =
  | "home"
  | "library"
  | "acknowledgements"
  | "favourites"
  | "recent"
  | "control"
  | "documents"
  | "changes"
  | "approvals"
  | "calendar"
  | "exceptions"
  | "reports"
  | "platform"
  | "sites"
  | "automations"
  | "retention"
  | "integrations"
  | "deployments"
  | "recovery"
  | "audit";

export interface RoleDefinition {
  label: string;
  caption: string;
  glyph: string;
  start: PageId;
  navigation: Array<{ page: PageId; label: string; icon: string; countKey?: "acknowledgements" | "approvals" | "exceptions" | "changes" }>;
}

export const roleDefinitions: Record<Role, RoleDefinition> = {
  endUser: {
    label: "End user",
    caption: "Find and follow current guidance",
    glyph: "EU",
    start: "home",
    navigation: [
      { page: "home", label: "Home", icon: "home" },
      { page: "library", label: "Controlled library", icon: "library" },
      { page: "acknowledgements", label: "My acknowledgements", icon: "check", countKey: "acknowledgements" },
      { page: "favourites", label: "Favourites", icon: "star" },
      { page: "recent", label: "Recently viewed", icon: "clock" },
    ],
  },
  teamAdmin: {
    label: "Team administrator",
    caption: "Operate the document lifecycle",
    glyph: "TA",
    start: "control",
    navigation: [
      { page: "control", label: "Control desk", icon: "desk" },
      { page: "documents", label: "Documents", icon: "document" },
      { page: "changes", label: "Change requests", icon: "change", countKey: "changes" },
      { page: "approvals", label: "Approvals", icon: "approval", countKey: "approvals" },
      { page: "calendar", label: "Review calendar", icon: "calendar" },
      { page: "exceptions", label: "Exceptions", icon: "alert", countKey: "exceptions" },
      { page: "reports", label: "Reports", icon: "report" },
    ],
  },
  platformAdmin: {
    label: "Platform administrator",
    caption: "Assure the M365 control plane",
    glyph: "PA",
    start: "platform",
    navigation: [
      { page: "platform", label: "Platform overview", icon: "platform" },
      { page: "sites", label: "Sites & access", icon: "sites" },
      { page: "automations", label: "Automations", icon: "automation" },
      { page: "retention", label: "Records & retention", icon: "records" },
      { page: "integrations", label: "Integrations", icon: "integration" },
      { page: "deployments", label: "Deployments", icon: "deploy" },
      { page: "recovery", label: "Recovery", icon: "recovery" },
      { page: "audit", label: "Audit", icon: "audit" },
    ],
  },
};
