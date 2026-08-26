import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import pixelmatch from "pixelmatch";
import { chromium } from "playwright";
import { PNG } from "pngjs";
import { createServer } from "vite";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const output = join(root, "test-results", "visual");
const reference = join(root, "docs", "design-reference", "dms-ui-prototype");
mkdirSync(output, { recursive: true });

function executablePath() {
  const candidates = [
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
  ];
  const found = candidates.find(existsSync);
  if (!found) throw new Error("Chrome or Edge is required for responsive verification.");
  return found;
}

function crop(source, width, height) {
  const result = new PNG({ width, height });
  for (let y = 0; y < height; y += 1) {
    source.data.copy(result.data, y * width * 4, y * source.width * 4, (y * source.width + width) * 4);
  }
  return result;
}

function compareImages(actualPath, referencePath, diffPath) {
  const actual = PNG.sync.read(readFileSync(actualPath));
  const expected = PNG.sync.read(readFileSync(referencePath));
  const width = Math.min(actual.width, expected.width);
  const height = Math.min(actual.height, expected.height);
  const actualCrop = crop(actual, width, height);
  const expectedCrop = crop(expected, width, height);
  const diff = new PNG({ width, height });
  const changed = pixelmatch(actualCrop.data, expectedCrop.data, diff.data, width, height, { threshold: 0.2, includeAA: false });
  writeFileSync(diffPath, PNG.sync.write(diff));
  return {
    actual: `${actual.width}x${actual.height}`,
    reference: `${expected.width}x${expected.height}`,
    compared: `${width}x${height}`,
    pixelDifferenceRatio: Number((changed / (width * height)).toFixed(4)),
  };
}

const server = await createServer({ root, mode: "development", logLevel: "error", server: { host: "127.0.0.1", port: 4178, strictPort: true } });
await server.listen();

const browser = await chromium.launch({ executablePath: executablePath(), headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1050 }, deviceScaleFactor: 1, reducedMotion: "reduce" });
const issues = [];
page.on("console", (message) => { if (message.type() === "error") issues.push(`console: ${message.text()}`); });
page.on("pageerror", (error) => issues.push(`page: ${error.message}`));

async function switchRole(role) {
  await page.locator(".role-context > button").click();
  await page.locator(`[data-role="${role}"]`).click();
  await page.locator("main h1").waitFor();
}

async function navigate(target) {
  await page.locator(`[data-page="${target}"]`).click();
  await page.locator("main h1").waitFor();
}

async function screenshot(name, fullPage = true) {
  const path = join(output, `production-${name}.png`);
  await page.screenshot({ path, fullPage });
  return path;
}

function invariant(condition, message) {
  if (!condition) issues.push(message);
}

try {
  await page.goto("http://127.0.0.1:4178", { waitUntil: "networkidle" });
  await page.locator(".trust-hero").waitFor();

  const initial = await page.evaluate(() => ({
    title: document.title,
    h1: document.querySelector("h1")?.textContent?.trim(),
    main: document.querySelectorAll("main").length,
    nav: document.querySelectorAll("nav").length,
    emptyButtons: [...document.querySelectorAll("button")].filter((button) => !button.textContent?.trim() && !button.getAttribute("aria-label")).length,
    overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
    focusOutline: getComputedStyle(document.documentElement).getPropertyValue("--focus-ring").trim(),
  }));
  invariant(initial.main === 1 && initial.nav === 1, "Semantic main/navigation landmarks are missing or duplicated.");
  invariant(initial.emptyButtons === 0, `${initial.emptyButtons} buttons have no accessible name.`);
  invariant(!initial.overflow, "The end-user home view overflows at desktop width.");
  const userShot = await screenshot("user");

  await switchRole("teamAdmin");
  invariant((await page.locator("h1").innerText()).includes("Document control desk"), "Team administrator start page is incorrect.");
  const teamShot = await screenshot("team");

  await switchRole("platformAdmin");
  invariant((await page.locator("h1").innerText()).includes("Platform assurance"), "Platform administrator start page is incorrect.");
  const platformShot = await screenshot("platform");

  const rolePages = {
    endUser: ["home", "library", "acknowledgements", "favourites", "recent"],
    teamAdmin: ["control", "documents", "changes", "approvals", "calendar", "exceptions", "reports"],
    platformAdmin: ["platform", "sites", "automations", "retention", "integrations", "deployments", "recovery", "audit"],
  };
  const viewResults = [];
  for (const [role, targets] of Object.entries(rolePages)) {
    await switchRole(role);
    for (const target of targets) {
      await navigate(target);
      const result = await page.evaluate(({ roleName, pageName }) => ({
        role: roleName,
        page: pageName,
        heading: document.querySelector("main h1")?.textContent?.trim(),
        overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
      }), { roleName: role, pageName: target });
      viewResults.push(result);
      invariant(Boolean(result.heading), `${role}/${target} rendered without a primary heading.`);
      invariant(!result.overflow, `${role}/${target} overflows at desktop width.`);
    }
  }

  await switchRole("endUser");
  await navigate("library");
  await page.locator("#global-search").fill("security incident");
  await page.locator("#global-search").press("Enter");
  await page.locator('[data-document-id="WI-SEC-021"]').waitFor();
  invariant(await page.locator(".document-row").count() === 1, "Authoritative search did not filter to the matching controlled document.");

  const documentTrigger = page.locator('[data-document-id="WI-SEC-021"]');
  await documentTrigger.click();
  await page.locator(".detail-drawer[aria-hidden=false]").waitFor();
  invariant(await page.locator(".detail-drawer .lifecycle-spine").count() === 1, "Document detail does not include the lifecycle spine.");
  await page.waitForFunction(() => Boolean(document.activeElement?.closest(".detail-drawer")));
  invariant(await page.evaluate(() => Boolean(document.activeElement?.closest(".detail-drawer"))), "Opening the detail drawer did not move focus inside the drawer.");
  const drawerShot = await screenshot("drawer", false);
  await page.keyboard.press("Shift+Tab");
  invariant(await page.evaluate(() => Boolean(document.activeElement?.closest(".detail-drawer"))), "Drawer focus escaped on reverse tab.");
  await page.keyboard.press("Escape");
  await page.locator(".detail-drawer[aria-hidden=true]").waitFor();
  await page.waitForFunction(() => document.activeElement?.getAttribute("data-document-id") === "WI-SEC-021");
  invariant(await documentTrigger.evaluate((element) => element === document.activeElement), "Closing the drawer did not restore focus to its trigger.");

  await documentTrigger.click();
  await page.getByRole("button", { name: /^Acknowledge v3\.0$/ }).click();
  const acknowledgementDialog = page.getByRole("alertdialog");
  await acknowledgementDialog.waitFor();
  invariant((await acknowledgementDialog.innerText()).includes("ETag"), "Acknowledgement confirmation omits version-integrity evidence.");
  await page.getByRole("button", { name: "Record acknowledgement" }).click();
  await page.getByText("Acknowledgement recorded", { exact: true }).waitFor();
  await navigate("acknowledgements");
  const acknowledgementRow = page.locator("tbody tr").filter({ hasText: "WI-SEC-021" });
  await acknowledgementRow.getByText("Completed", { exact: true }).waitFor();
  invariant(await acknowledgementRow.getByText("Completed", { exact: true }).count() === 1, "Acknowledgement evidence was not reflected in the assigned register.");

  await switchRole("teamAdmin");
  await navigate("approvals");
  const approvalsBefore = await page.locator("tbody tr").count();
  await page.getByRole("button", { name: "Approve", exact: true }).first().click();
  const approvalDialog = page.getByRole("alertdialog");
  invariant((await approvalDialog.innerText()).includes("ETag"), "Approval confirmation omits its exact ETag.");
  await page.getByRole("button", { name: "Approve release" }).click();
  await page.getByText("Approval recorded", { exact: true }).waitFor();
  invariant(await page.locator("tbody tr").count() === approvalsBefore - 1, "Approval evidence did not remove the completed assignment.");

  await navigate("exceptions");
  const exceptionsBefore = await page.locator("tbody tr").count();
  await page.getByRole("button", { name: "Resolve", exact: true }).first().click();
  await page.getByRole("button", { name: "Record resolution" }).click();
  await page.getByText("Exception resolved", { exact: true }).waitFor();
  invariant(await page.locator("tbody tr").count() === exceptionsBefore - 1, "Resolved exception remained in the open register.");

  await switchRole("platformAdmin");
  await navigate("integrations");
  const integration = page.getByRole("switch", { name: "Enable Electronic signature" });
  await integration.click();
  await page.getByRole("button", { name: "Record proposed change" }).click();
  await page.getByText("Integration change recorded", { exact: true }).waitFor();
  invariant(await page.getByRole("switch", { name: "Disable Electronic signature" }).isChecked(), "Integration change evidence did not refresh the configured state.");

  await switchRole("endUser");
  await navigate("library");
  const dismissNotifications = page.getByRole("button", { name: "Dismiss notification" });
  while (await dismissNotifications.count()) await dismissNotifications.first().click();
  await page.setViewportSize({ width: 390, height: 844 });
  const mobileMenu = page.getByRole("button", { name: "Open navigation" });
  await mobileMenu.click();
  await page.waitForFunction(() => document.querySelector("#primary-sidebar")?.getAttribute("aria-hidden") === "false");
  invariant(await page.locator("#primary-sidebar").getAttribute("aria-hidden") === "false", "Mobile navigation did not become available to assistive technology when opened.");
  await page.getByRole("button", { name: "Close navigation" }).click({ position: { x: 360, y: 420 } });
  await page.waitForTimeout(50);
  const mobile = await page.evaluate(() => ({
    width: document.documentElement.scrollWidth,
    viewport: document.documentElement.clientWidth,
    overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
    sidebarHidden: document.querySelector("#primary-sidebar")?.getAttribute("aria-hidden"),
    sidebarInert: document.querySelector("#primary-sidebar")?.inert,
  }));
  invariant(!mobile.overflow, `The 390px view overflows (${mobile.width}px content in ${mobile.viewport}px viewport).`);
  invariant(mobile.sidebarHidden === "true" && mobile.sidebarInert === true, "Closed off-canvas navigation is not hidden and inert.");
  const mobileShot = await screenshot("mobile");

  const screenshots = {
    user: [userShot, "preview-user.png"],
    team: [teamShot, "preview-team.png"],
    platform: [platformShot, "preview-platform.png"],
    drawer: [drawerShot, "preview-drawer.png"],
    mobile: [mobileShot, "preview-mobile.png"],
  };
  const visualComparison = Object.fromEntries(Object.entries(screenshots).map(([name, [actual, expected]]) => [name, compareImages(actual, join(reference, expected), join(output, `diff-${name}.png`))]));
  const report = {
    generatedAt: new Date().toISOString(),
    initial,
    viewsRendered: viewResults.length,
    viewResults,
    acknowledgementRecorded: true,
    approvalRecorded: true,
    exceptionResolved: true,
    integrationChangeRecorded: true,
    mobile,
    visualComparison,
    issues,
  };
  writeFileSync(join(output, "verification-report.json"), `${JSON.stringify(report, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify({ viewsRendered: report.viewsRendered, mobile: report.mobile, visualComparison: report.visualComparison, issues }, null, 2)}\n`);
  if (issues.length) process.exitCode = 1;
} finally {
  await page.close();
  await browser.close();
  await server.close();
}
