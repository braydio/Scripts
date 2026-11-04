(async () => {
  const CFG = {
    minDelay: 3000,
    maxDelay: 6000,
    shortDelayMin: 500,
    shortDelayMax: 1200,
    applyCooldownMin: 12000,
    applyCooldownMax: 22000,
    pageDelayMin: 3000,
    pageDelayMax: 6000,
    waitTimeout: 15000,
    submitVerifyTimeout: 20000,

    // Persistent watcher behavior.
    watchIdleMin: 90000,
    watchIdleMax: 180000,
    failedRetryMs: 30 * 60 * 1000,
    successRememberMs: 24 * 60 * 60 * 1000,
    maxApplicationsPerSweep: 50,
    maxPageHops: 100,

    // Sweep both Explore feeds. One-time goes first because those listings
    // can be short-lived and are frequently 1-click eligible.
    exploreSections: ["One-time", "Project-based"],
  };

  // Starting a new copy stops the older watcher cleanly.
  if (window.__mercorApplyWatcherController) {
    window.__mercorApplyWatcherController.stop = true;
  }

  const controller = {
    stop: false,
    id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
  };

  window.__mercorApplyWatcherController = controller;
  window.__mercorApplyWatcherStop = false;

  const attemptedUntil = new Map();
  let lifetimeApplied = 0;
  let sweepNumber = 0;

  const sleep = ms =>
    new Promise(resolve => setTimeout(resolve, ms));

  const rand = (min, max) =>
    Math.floor(min + Math.random() * (max - min + 1));

  const normalize = value =>
    String(value ?? "")
      .replace(/\s+/g, " ")
      .trim();

  const normalizeLower = value =>
    normalize(value).toLowerCase();

  function shouldStop() {
    return (
      window.__mercorApplyWatcherStop === true ||
      controller.stop === true ||
      window.__mercorApplyWatcherController !== controller
    );
  }

  async function pacedDelay(min, max) {
    const end = Date.now() + rand(min, max);

    while (Date.now() < end) {
      if (shouldStop()) return false;
      await sleep(Math.min(250, end - Date.now()));
    }

    return true;
  }

  async function waitFor(fn, timeout = CFG.waitTimeout, interval = 200) {
    const start = Date.now();

    while (Date.now() - start < timeout) {
      if (shouldStop()) return null;

      try {
        const result = fn();
        if (result) return result;
      } catch (err) {
        console.debug("waitFor probe error:", err);
      }

      await sleep(interval);
    }

    return null;
  }

  function isVisible(el) {
    if (!(el instanceof Element) || !el.isConnected) return false;

    const style = getComputedStyle(el);
    if (
      style.display === "none" ||
      style.visibility === "hidden" ||
      style.pointerEvents === "none" ||
      Number(style.opacity) === 0
    ) {
      return false;
    }

    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  function isEnabled(el) {
    return (
      isVisible(el) &&
      !el.disabled &&
      el.getAttribute("aria-disabled") !== "true"
    );
  }

  function elementLabel(el) {
    if (!el) return "";

    if (el instanceof HTMLInputElement) {
      return normalize(el.value || el.getAttribute("aria-label"));
    }

    return normalize(
      el.innerText ||
      el.textContent ||
      el.getAttribute("aria-label") ||
      el.getAttribute("title")
    );
  }

  function getClickableElements(root = document) {
    return [
      ...root.querySelectorAll(
        'button, [role="button"], input[type="button"], input[type="submit"]'
      ),
    ];
  }

  function findVisibleButtonByText(texts, root = document, exact = true) {
    const targets = (Array.isArray(texts) ? texts : [texts]).map(normalizeLower);

    return (
      getClickableElements(root).find(el => {
        if (!isEnabled(el)) return false;
        const label = normalizeLower(elementLabel(el));
        if (!label) return false;

        return targets.some(target =>
          exact ? label === target : label.includes(target)
        );
      }) || null
    );
  }

  function findExploreTab(label) {
    const target = normalizeLower(label);

    // Prefer Mercor's stable data-test hooks observed on the Explore page.
    const exactSelectors = {
      "project-based": '[data-test="explore-job-type-tab-project-based"]',
      "one-time": '[data-test="explore-job-type-tab-one-time"]',
      "talent network": '[data-test="explore-job-type-tab-evergreen"]',
    };

    const exactSelector = exactSelectors[target];
    if (exactSelector) {
      const exact = [
        ...document.querySelectorAll(exactSelector),
      ].find(isEnabled);

      if (exact) return exact;
    }

    // Fallback to visible tab text in case Mercor renames the test hooks.
    return (
      [
        ...document.querySelectorAll(
          'button, [role="tab"], a[href]'
        ),
      ].find(el => {
        if (!isEnabled(el)) return false;
        return normalizeLower(elementLabel(el)) === target;
      }) || null
    );
  }

  function isExploreTabActive(el) {
    if (!el) return false;

    return (
      el.getAttribute("aria-selected") === "true" ||
      el.getAttribute("data-state") === "active" ||
      el.getAttribute("aria-current") === "page"
    );
  }

  async function switchExploreSection(label) {
    const tab = await waitFor(
      () => findExploreTab(label),
      CFG.waitTimeout,
      200
    );

    if (!tab) {
      console.warn(`Could not find Explore tab: ${label}`);
      return false;
    }

    if (isExploreTabActive(tab)) {
      console.log(`Explore section already active: ${label}`);
      return true;
    }

    const beforeUrl = location.href;
    const beforeSignature = pageSignature();

    console.log(`Switching Explore section to: ${label}`);
    tab.scrollIntoView({ block: "center", behavior: "smooth" });
    await pacedDelay(CFG.shortDelayMin, CFG.shortDelayMax);
    tab.click();

    // Mercor may keep /explore unchanged when switching tabs. Prefer the
    // tab's active state, but also accept a listing or URL change.
    await waitFor(
      () =>
        isExploreTabActive(tab) ||
        location.href !== beforeUrl ||
        pageSignature() !== beforeSignature,
      6000,
      200
    );

    await pacedDelay(CFG.pageDelayMin, CFG.pageDelayMax);
    return true;
  }

  function firstEnabledSelector(selectors, root = document) {
    for (const selector of selectors) {
      const match = [...root.querySelectorAll(selector)].find(isEnabled);
      if (match) return match;
    }
    return null;
  }

  function findExactTextNodes(text) {
    const target = normalizeLower(text);
    const results = [];

    if (!document.body) return results;

    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_TEXT
    );

    let node;
    while ((node = walker.nextNode())) {
      if (
        normalizeLower(node.nodeValue) === target &&
        node.parentElement
      ) {
        results.push(node.parentElement);
      }
    }

    return results;
  }

  function getCardFromBadge(badge) {
    if (!badge) return null;

    const directClickable = badge.closest(
      'a[href], button, [role="button"]'
    );
    if (directClickable) return directClickable;

    let node = badge.parentElement;
    for (let depth = 0; node && depth < 8; depth++, node = node.parentElement) {
      const text = normalize(node.innerText);
      if (!text || text.length > 1800) continue;

      const jobishLink = node.querySelector(
        'a[href*="/job"], a[href*="/jobs"], a[href*="/project"], a[href*="/explore?"]'
      );
      if (jobishLink) return jobishLink;

      if (
        node.matches("li, .group") ||
        node.getAttribute("role") === "button"
      ) {
        return node;
      }
    }

    return badge.closest("li") || badge.closest(".group") || badge.closest("div");
  }

  function getJobHref(card) {
    if (!card) return "";

    return (
      card.getAttribute?.("href") ||
      card.querySelector?.('a[href*="/job"]')?.getAttribute("href") ||
      card.querySelector?.('a[href*="/jobs"]')?.getAttribute("href") ||
      card.querySelector?.('a[href*="/project"]')?.getAttribute("href") ||
      card.querySelector?.('a[href*="/explore?"]')?.getAttribute("href") ||
      card.querySelector?.("a[href]")?.getAttribute("href") ||
      ""
    );
  }

  function cleanCardText(text) {
    return normalize(text)
      .replace(/\b1-click apply\b/gi, "")
      .replace(/\bsubmitted on\b[^|•\n]*/gi, "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function getJobKey(card) {
    if (!card) return "";
    const href = getJobHref(card);
    const text = cleanCardText(
      card.innerText || card.textContent || ""
    ).slice(0, 260);
    return `${href}::${text}`;
  }

  function cleanupAttemptMemory() {
    const now = Date.now();
    for (const [key, until] of attemptedUntil.entries()) {
      if (until <= now) attemptedUntil.delete(key);
    }
  }

  function isTemporarilySuppressed(key) {
    return (attemptedUntil.get(key) || 0) > Date.now();
  }

  function getOneClickCards() {
    cleanupAttemptMemory();

    const badges = findExactTextNodes("1-click apply");
    const byKey = new Map();

    for (const badge of badges) {
      if (!isVisible(badge)) continue;

      const card = getCardFromBadge(badge);
      const key = getJobKey(card);

      if (!card || !key || isTemporarilySuppressed(key)) continue;

      if (!byKey.has(key)) {
        byKey.set(key, { badge, card, key });
      }
    }

    return [...byKey.values()];
  }

  function clickListing(item) {
    const { card } = item;
    if (!card) return false;

    const clickable =
      (card.matches?.('a[href], button, [role="button"]') ? card : null) ||
      card.querySelector?.(
        'a[href*="/job"], a[href*="/jobs"], a[href*="/project"], a[href*="/explore?"], a[href]'
      ) ||
      card;

    if (!clickable || typeof clickable.click !== "function") return false;
    clickable.click();
    return true;
  }

  function findInitialSubmitButton() {
    const exact = firstEnabledSelector([
      '[data-test="split-view-mobile-footer-apply-button"]',
      '[data-testid="split-view-mobile-footer-apply-button"]',
      '[data-test*="apply-button"]',
      '[data-testid*="apply-button"]',
    ]);

    return exact || findVisibleButtonByText([
      "Submit Application",
      "1-click apply",
    ]);
  }

  function visibleDialogs() {
    return [
      ...document.querySelectorAll('[role="dialog"], [aria-modal="true"]'),
    ].filter(isVisible);
  }

  function centerOfRect(rect) {
    return {
      x: rect.left + rect.width / 2,
      y: rect.top + rect.height / 2,
    };
  }

  function distanceBetweenRects(a, b) {
    const ca = centerOfRect(a);
    const cb = centerOfRect(b);
    return Math.hypot(ca.x - cb.x, ca.y - cb.y);
  }

  function findConfirmationButton({ buttonsBefore, firstRect }) {
    const explicit = firstEnabledSelector([
      '[data-test="start-application-button"]',
      '[data-testid="start-application-button"]',
    ]);
    if (explicit) return explicit;

    for (const dialog of visibleDialogs()) {
      const inDialog = findVisibleButtonByText(
        "Submit Application",
        dialog,
        true
      );
      if (inDialog) return inDialog;
    }

    const candidates = getClickableElements(document)
      .filter(isEnabled)
      .filter(el => normalizeLower(elementLabel(el)) === "submit application")
      .filter(el => !buttonsBefore.has(el));

    return (
      candidates.find(el => {
        try {
          return distanceBetweenRects(
            firstRect,
            el.getBoundingClientRect()
          ) > 40;
        } catch {
          return false;
        }
      }) || null
    );
  }

  function submissionMarkerCount() {
    const text = normalize(document.body?.innerText || "").toLowerCase();
    const submittedOn = text.match(/\bsubmitted on\b/g)?.length || 0;
    const applicationSubmitted =
      text.match(/\bapplication submitted\b/g)?.length || 0;
    return submittedOn + applicationSubmitted;
  }

  async function verifyNewSubmission(markerCountBefore) {
    return await waitFor(
      () => submissionMarkerCount() > markerCountBefore,
      CFG.submitVerifyTimeout,
      250
    );
  }

  function dumpVisibleButtons(label = "Visible buttons") {
    console.group(label);
    console.table(
      getClickableElements(document)
        .filter(isVisible)
        .map((el, i) => ({
          i,
          text: elementLabel(el),
          dataTest: el.getAttribute("data-test"),
          dataTestId: el.getAttribute("data-testid"),
          ariaLabel: el.getAttribute("aria-label"),
          disabled: !!el.disabled,
          ariaDisabled: el.getAttribute("aria-disabled"),
          role: el.getAttribute("role"),
        }))
    );
    console.groupEnd();
  }

  async function returnToList(listUrl) {
    if (shouldStop()) return;
    if (location.href === listUrl) return;

    console.log("Returning to previous Explore state...");
    history.back();

    const returned = await waitFor(
      () =>
        location.href === listUrl ||
        getOneClickCards().length > 0 ||
        location.pathname.includes("/explore"),
      CFG.waitTimeout,
      250
    );

    if (returned) {
      await pacedDelay(CFG.pageDelayMin, CFG.pageDelayMax);
      return;
    }

    const exploreLink = [
      ...document.querySelectorAll('a[href="/explore"]'),
    ].find(isVisible);

    if (exploreLink) {
      console.log("History did not restore Explore; using Explore link fallback.");
      exploreLink.click();
      await pacedDelay(CFG.pageDelayMin, CFG.pageDelayMax);
    }
  }

  async function submitApplication() {
    console.log("Waiting for the first application button...");

    const btn1 = await waitFor(
      () => findInitialSubmitButton(),
      CFG.waitTimeout,
      200
    );

    if (!btn1) {
      console.warn("Could not find an enabled application button.");
      dumpVisibleButtons();
      return false;
    }

    const firstRect = btn1.getBoundingClientRect();
    const buttonsBefore = new Set(getClickableElements(document));
    const markersBefore = submissionMarkerCount();

    console.log("Found first application button:", elementLabel(btn1));
    btn1.scrollIntoView({ block: "center", behavior: "smooth" });
    await pacedDelay(CFG.shortDelayMin, CFG.shortDelayMax);
    btn1.click();

    const directSubmit = await waitFor(
      () => submissionMarkerCount() > markersBefore,
      2500,
      150
    );

    if (directSubmit) {
      console.log("✓ Mercor confirmed submission after the first click.");
      return true;
    }

    const btn2 = await waitFor(
      () => findConfirmationButton({ buttonsBefore, firstRect }),
      CFG.waitTimeout,
      200
    );

    if (!btn2) {
      if (submissionMarkerCount() > markersBefore) {
        console.log("✓ Mercor confirmed submission while waiting for confirmation UI.");
        return true;
      }

      console.warn("Could not find a distinct confirmation button.");
      dumpVisibleButtons("Buttons after first click");
      return false;
    }

    console.log("Found confirmation button:", elementLabel(btn2));
    btn2.scrollIntoView({ block: "center", behavior: "smooth" });
    await pacedDelay(CFG.shortDelayMin, CFG.shortDelayMax);
    btn2.click();

    const submitted = await verifyNewSubmission(markersBefore);
    if (!submitted) {
      console.warn(
        "Clicked confirmation, but no new 'Submitted on' / 'Application submitted' state appeared."
      );
      dumpVisibleButtons("Buttons after confirmation click");
      return false;
    }

    console.log("✓ Mercor confirmed a new submission.");
    return true;
  }

  function pageSignature() {
    return getOneClickCards()
      .slice(0, 8)
      .map(item => item.key)
      .join("||");
  }

  function findPageButton(direction) {
    const label = direction === "next"
      ? "Go to next page"
      : "Go to previous page";

    return (
      [
        ...document.querySelectorAll(
          `a[aria-label="${label}"], button[aria-label="${label}"]`
        ),
      ].find(isEnabled) || null
    );
  }

  async function movePage(direction) {
    const button = findPageButton(direction);
    if (!button) return false;

    const beforeUrl = location.href;
    const beforeSignature = pageSignature();

    console.log(`Going to ${direction} page...`);
    button.click();

    await waitFor(
      () =>
        location.href !== beforeUrl ||
        pageSignature() !== beforeSignature,
      CFG.waitTimeout,
      250
    );

    await pacedDelay(CFG.pageDelayMin, CFG.pageDelayMax);
    return true;
  }

  async function goFirstPage() {
    let hops = 0;

    while (!shouldStop() && hops < CFG.maxPageHops) {
      const moved = await movePage("previous");
      if (!moved) break;
      hops++;
    }

    if (hops >= CFG.maxPageHops) {
      console.warn("Stopped paging backward at safety limit.");
    }
  }

  async function softRefreshListing() {
    // Avoid location.reload(): a hard navigation kills a console-injected script.
    // A page hop forces Mercor's SPA to request fresh list data when possible.
    const movedNext = await movePage("next");
    if (movedNext) {
      await movePage("previous");
    }
  }

  async function idleUntilNextSweep() {
    await goFirstPage();

    const waitMs = rand(CFG.watchIdleMin, CFG.watchIdleMax);
    console.log(
      `Watcher idle. Next sweep in ~${Math.round(waitMs / 1000)}s. ` +
      "Leave this tab open; background-tab throttling may make it later."
    );

    const completed = await pacedDelay(waitMs, waitMs);
    if (!completed || shouldStop()) return false;

    await softRefreshListing();
    return !shouldStop();
  }

  async function runSection(sectionLabel, applicationBudget) {
    let appliedInSection = 0;
    let pageNum = 1;

    const switched = await switchExploreSection(sectionLabel);
    if (!switched || shouldStop()) return 0;

    await goFirstPage();

    while (!shouldStop()) {
      if (appliedInSection >= applicationBudget) {
        console.log(
          `Section application budget reached for ${sectionLabel} (${applicationBudget}).`
        );
        break;
      }

      console.log(`--- ${sectionLabel} / Page ${pageNum} ---`);
      const items = getOneClickCards();
      console.log(
        `Found ${items.length} available 1-click job(s) in ${sectionLabel}.`
      );

      if (items.length === 0) {
        const moved = await movePage("next");
        if (!moved) {
          console.log(`Reached end of current ${sectionLabel} 1-click listings.`);
          break;
        }

        pageNum++;
        continue;
      }

      const item = items[0];

      // Suppress immediate re-clicks. Failures become eligible again later.
      attemptedUntil.set(item.key, Date.now() + CFG.failedRetryMs);

      item.card.scrollIntoView({ block: "center", behavior: "smooth" });
      await pacedDelay(CFG.shortDelayMin, CFG.shortDelayMax);

      const listUrl = location.href;
      console.log(`Opening ${sectionLabel} job:`, item.key);

      if (!clickListing(item)) {
        console.warn("Could not click this listing. Will retry after cooldown.");
        continue;
      }

      await pacedDelay(CFG.pageDelayMin, CFG.pageDelayMax);
      const success = await submitApplication();

      if (success) {
        appliedInSection++;
        lifetimeApplied++;
        attemptedUntil.set(item.key, Date.now() + CFG.successRememberMs);

        console.log(
          `✓ Submitted successfully. ${sectionLabel}: ${appliedInSection}; lifetime watcher: ${lifetimeApplied}`
        );

        await pacedDelay(CFG.applyCooldownMin, CFG.applyCooldownMax);
      } else {
        console.log(
          `✗ Attempt failed. Eligible to retry in ~${Math.round(CFG.failedRetryMs / 60000)} minutes.`
        );
      }

      await returnToList(listUrl);
      await pacedDelay(CFG.minDelay, CFG.maxDelay);
    }

    return appliedInSection;
  }

  async function runSweep() {
    sweepNumber++;
    let appliedThisSweep = 0;

    console.log(`=== Mercor watcher sweep ${sweepNumber} ===`);

    for (const sectionLabel of CFG.exploreSections) {
      if (shouldStop()) break;

      const remaining =
        CFG.maxApplicationsPerSweep - appliedThisSweep;

      if (remaining <= 0) {
        console.log(
          `Sweep safety limit reached (${CFG.maxApplicationsPerSweep}). Idling before another sweep.`
        );
        break;
      }

      const count = await runSection(sectionLabel, remaining);
      appliedThisSweep += count;
    }

    return appliedThisSweep;
  }

  async function run() {
    console.log("Mercor persistent 1-click watcher started.");
    console.log(
      `Watching Explore sections in priority order: ${CFG.exploreSections.join(" -> ")}`
    );
    console.log("Mercor's rendered submitted state remains the source of truth.");
    console.log("No hard page reloads are used, so console-injected runs survive.");
    console.log("To stop: window.__mercorApplyWatcherStop = true");

    while (!shouldStop()) {
      try {
        const count = await runSweep();
        console.log(`Sweep ${sweepNumber} complete: ${count} successful application(s).`);
      } catch (err) {
        console.error("Sweep error; watcher will idle and try again:", err);
      }

      if (shouldStop()) break;
      const keepGoing = await idleUntilNextSweep();
      if (!keepGoing) break;
    }

    console.log(
      `Watcher stopped. Successful applications this session: ${lifetimeApplied}`
    );
  }

  run().catch(err => {
    console.error("Mercor watcher crashed:", err);
  });
})();
