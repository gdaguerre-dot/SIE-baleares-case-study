// qa/test-select-illa.js
//
// Reproduces the exact user interaction reported as a bug: selecting each
// island in the dashboard's dropdown and checking that (a) no JS exceptions
// are thrown and (b) the resulting KPI values genuinely correspond to the
// selected island, not a stale one.
//
// Uses a local mock of Chart.js (mock_chart.js) so the test can run without
// network access and isolates bugs in *our* code from CDN loading issues.
//
// Run: node qa/test-select-illa.js

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const DASHBOARD_PATH = path.join(__dirname, '..', 'docs', 'dashboard.html');
const MOCK_CHART_PATH = path.join(__dirname, 'mock_chart.js');
const ISLANDS = ['Totes', 'Mallorca', 'Menorca', 'Eivissa', 'Formentera'];

// Expected total actuaciones per island, used to sanity-check that the
// displayed KPI actually matches the selected island (not a stale one).
const EXPECTED_TOTAL = {
  'Totes': 620, 'Mallorca': 426, 'Menorca': 74, 'Eivissa': 99, 'Formentera': 21
};

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  const jsErrors = [];
  page.on('pageerror', err => jsErrors.push(err.toString()));

  // Serve the local mock instead of hitting the real Chart.js CDN.
  await page.route('**/chart.umd.js', route => {
    route.fulfill({
      contentType: 'application/javascript',
      body: fs.readFileSync(MOCK_CHART_PATH, 'utf8'),
    });
  });

  await page.goto('file://' + DASHBOARD_PATH);
  await page.waitForTimeout(400);

  let failures = 0;

  for (const illa of ISLANDS) {
    jsErrors.length = 0;
    await page.selectOption('#illaSel', illa);
    await page.waitForTimeout(250);

    const kpiText = await page.locator('#kpis').innerText();
    const actualTotal = parseInt(kpiText.match(/Actuacions\s*([\d.]+)/)?.[1]?.replace(/\./g, '') || '-1', 10);
    const expected = EXPECTED_TOTAL[illa];
    const ok = actualTotal === expected && jsErrors.length === 0;

    console.log(`[${ok ? 'PASS' : 'FAIL'}] ${illa.padEnd(11)} total=${actualTotal} (expected ${expected})  errors=${jsErrors.length}`);
    if (!ok) {
      failures++;
      jsErrors.forEach(e => console.log('        ', e));
    }
  }

  await browser.close();

  if (failures > 0) {
    console.log(`\n${failures} of ${ISLANDS.length} scenarios failed.`);
    process.exit(1);
  } else {
    console.log(`\nAll ${ISLANDS.length} scenarios passed.`);
  }
})();
