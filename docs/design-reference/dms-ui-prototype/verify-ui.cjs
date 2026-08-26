const { chromium } = require("C:/Users/david/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright");
const { pathToFileURL } = require("url");
const path = require("path");

(async () => {
  const browser = await chromium.launch({
    executablePath: "C:/Program Files/Google/Chrome/Application/chrome.exe",
    headless: true,
  });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1050 }, deviceScaleFactor: 1 });
  const issues = [];
  page.on("console", (message) => {
    if (message.type() === "error") issues.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => issues.push(`page: ${error.message}`));

  await page.goto(pathToFileURL(path.join(__dirname, "index.html")).href);
  await page.waitForSelector(".trust-hero");
  await page.screenshot({ path: path.join(__dirname, "preview-user.png"), fullPage: true });

  const initialChecks = await page.evaluate(() => ({
    title: document.title,
    h1: document.querySelector("h1")?.textContent.trim(),
    landmarks: {
      main: document.querySelectorAll("main").length,
      nav: document.querySelectorAll("nav").length,
      aside: document.querySelectorAll("aside").length,
    },
    emptyButtons: [...document.querySelectorAll("button")].filter((el) => !el.textContent.trim() && !el.getAttribute("aria-label")).length,
    horizontalOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
  }));

  await page.click("#role-menu-button");
  await page.click('[data-role="team"]');
  await page.waitForSelector(".control-track");
  await page.screenshot({ path: path.join(__dirname, "preview-team.png"), fullPage: true });
  const teamHeading = await page.locator("h1").textContent();

  await page.click("#role-menu-button");
  await page.click('[data-role="platform"]');
  await page.waitForSelector(".control-matrix");
  await page.screenshot({ path: path.join(__dirname, "preview-platform.png"), fullPage: true });
  const platformHeading = await page.locator("h1").textContent();

  await page.click("#role-menu-button");
  await page.click('[data-role="user"]');
  await page.click('[data-page="library"]');
  await page.click('[data-open-document="SOP-OPS-014"]');
  const drawerVisible = await page.locator("#detail-drawer").getAttribute("aria-hidden");
  const drawerFocused = await page.evaluate(() => document.activeElement?.classList.contains("drawer-close"));
  await page.screenshot({ path: path.join(__dirname, "preview-drawer.png"), fullPage: false });
  await page.click('[data-action="close-drawer"]');

  await page.click('[data-open-document="WI-SEC-021"]');
  await page.click('[data-action="acknowledge"]');
  const confirmationVisible = await page.locator("#confirm-dialog").evaluate((el) => el.open);
  await page.click('#confirm-action');
  await page.click('[data-page="acknowledgements"]');
  const acknowledgementRecorded = (await page.locator("tbody tr").filter({ hasText: "WI-SEC-021" }).textContent()).includes("Complete");
  await page.click('[data-page="library"]');

  const viewChecks = [];
  const rolePages = {
    user: ["home", "library", "acknowledgements", "favourites", "recent"],
    team: ["control", "documents", "changes", "approvals", "calendar", "exceptions", "reports"],
    platform: ["platform", "sites", "automations", "retention", "integrations", "deployments", "recovery", "audit"],
  };
  for (const [role, pages] of Object.entries(rolePages)) {
    await page.click("#role-menu-button");
    await page.click(`[data-role="${role}"]`);
    for (const target of pages) {
      await page.click(`[data-page="${target}"]`);
      viewChecks.push({
        role,
        page: target,
        heading: (await page.locator("h1").textContent()).trim(),
        horizontalOverflow: await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth),
      });
    }
  }

  await page.click("#role-menu-button");
  await page.click('[data-role="team"]');
  await page.click('[data-page="approvals"]');
  const approvalsBefore = await page.locator("tbody tr").count();
  await page.locator('[data-action="approve"]').first().click();
  await page.click("#confirm-action");
  await page.waitForTimeout(250);
  const approvalsAfter = await page.locator("tbody tr").count();
  const approvalRecorded = approvalsAfter === approvalsBefore - 1;
  await page.click('[data-page="exceptions"]');
  const exceptionsBefore = await page.locator("tbody tr").count();
  await page.locator('[data-action="resolve"]').first().click();
  await page.click("#confirm-action");
  await page.waitForTimeout(250);
  const exceptionsAfter = await page.locator("tbody tr").count();
  const exceptionResolved = exceptionsAfter === exceptionsBefore - 1;

  await page.click("#role-menu-button");
  await page.click('[data-role="platform"]');
  await page.click('[data-page="integrations"]');
  const integrationToggle = page.locator('[data-action="toggle-integration"][data-id="4"]');
  await integrationToggle.click();
  await page.click("#confirm-action");
  await page.waitForTimeout(250);
  const integrationChangeRecorded = (await integrationToggle.getAttribute("aria-checked")) === "true";

  await page.click("#role-menu-button");
  await page.click('[data-role="user"]');
  await page.click('[data-page="library"]');

  await page.setViewportSize({ width: 390, height: 844 });
  await page.click("#mobile-menu-button");
  const mobileNavOpen = await page.locator("#sidebar").evaluate((el) => el.classList.contains("is-open"));
  await page.locator("#mobile-scrim").click({ position: { x: 380, y: 400 } });
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(__dirname, "preview-mobile.png"), fullPage: true });
  const mobileChecks = await page.evaluate(() => ({
    horizontalOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
    width: document.documentElement.scrollWidth,
    viewport: document.documentElement.clientWidth,
    sidebarTransform: getComputedStyle(document.querySelector("#sidebar")).transform,
  }));

  const report = {
    initialChecks,
    teamHeading: teamHeading.trim(),
    platformHeading: platformHeading.trim(),
    drawerVisible: drawerVisible === "false",
    drawerFocused,
    confirmationVisible,
    acknowledgementRecorded,
    approvalRecorded,
    approvalCounts: [approvalsBefore, approvalsAfter],
    exceptionResolved,
    exceptionCounts: [exceptionsBefore, exceptionsAfter],
    integrationChangeRecorded,
    viewsRendered: viewChecks.length,
    viewOverflows: viewChecks.filter((view) => view.horizontalOverflow),
    mobileNavOpen,
    mobileChecks,
    issues,
  };
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  await browser.close();
  if (issues.length || initialChecks.emptyButtons || initialChecks.horizontalOverflow || mobileChecks.horizontalOverflow || report.viewOverflows.length || !acknowledgementRecorded || !approvalRecorded || !exceptionResolved || !integrationChangeRecorded) process.exitCode = 1;
})();
