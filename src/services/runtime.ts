import { createDemoServices } from "./demo";
import { createHttpServices } from "./http";
import type { DmsServices } from "./contracts";

export function createRuntimeServices(): DmsServices {
  if (import.meta.env.DEV && import.meta.env.VITE_SOL_DEMO_MODE === "true") {
    return createDemoServices();
  }
  const config = window.__SOL_DMS_CONFIG__;
  if (config?.mode === "http") return createHttpServices(config);
  return createHttpServices({ mode: "http", endpoints: {} });
}
