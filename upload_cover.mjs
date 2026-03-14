import { chromium } from 'playwright';
import path from 'path';

const BRAVE_PATH = '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser';
const USER_DATA_DIR = path.join(process.env.HOME, 'Library/Application Support/BraveSoftware/Brave-Browser');
const BANNER_PATH = '/Users/beachclaw/dev/GoldRush1849/builds/goldrush_banner.png';
const EDIT_URL = 'https://itch.io/game/edit/4360674';

async function waitForCloudflare(page) {
  // Wait up to 30s for Cloudflare challenge to clear
  const maxWait = 30000;
  const start = Date.now();
  while (Date.now() - start < maxWait) {
    const title = await page.title();
    if (!title.includes('Just a moment') && !title.includes('Checking')) {
      console.log('Cloudflare cleared. Page title:', title);
      return;
    }
    console.log('Waiting for Cloudflare challenge...');
    await page.waitForTimeout(2000);
  }
  throw new Error('Cloudflare challenge did not clear within 30s');
}

async function main() {
  const context = await chromium.launchPersistentContext(USER_DATA_DIR, {
    executablePath: BRAVE_PATH,
    headless: false,
    args: [
      '--disable-blink-features=AutomationControlled',
      '--profile-directory=Default',
    ],
    viewport: { width: 1280, height: 900 },
  });

  const page = context.pages()[0] || await context.newPage();

  console.log('Navigating to itch.io edit page...');
  await page.goto(EDIT_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });

  // Wait for Cloudflare to clear
  await waitForCloudflare(page);

  // Extra wait for page to fully render
  await page.waitForTimeout(3000);

  // Debug: list all file inputs
  const allFileInputs = await page.locator('input[type="file"]').all();
  console.log(`Found ${allFileInputs.length} file inputs on page`);
  for (let i = 0; i < allFileInputs.length; i++) {
    const name = await allFileInputs[i].getAttribute('name');
    const id = await allFileInputs[i].getAttribute('id');
    const accept = await allFileInputs[i].getAttribute('accept');
    console.log(`  Input ${i}: name="${name}" id="${id}" accept="${accept}"`);
  }

  // Upload cover image
  console.log('Uploading cover image...');
  let uploaded = false;

  const selectors = [
    'input[type="file"][name="game[cover_image]"]',
    'input[type="file"]#game_cover_image',
    '.cover_image_editor input[type="file"]',
    '.cover_uploader input[type="file"]',
    'input[type="file"][accept*="image"]',
  ];

  for (const sel of selectors) {
    const el = page.locator(sel).first();
    if (await el.count() > 0) {
      console.log(`Found input with selector: ${sel}`);
      await el.setInputFiles(BANNER_PATH);
      uploaded = true;
      break;
    }
  }

  if (!uploaded && allFileInputs.length > 0) {
    // Use the first file input as fallback
    console.log('Using first file input as fallback...');
    await allFileInputs[0].setInputFiles(BANNER_PATH);
    uploaded = true;
  }

  if (!uploaded) {
    console.error('Could not find file input!');
    await page.screenshot({ path: 'debug_screenshot.png' });
    await context.close();
    process.exit(1);
  }

  console.log('File selected, waiting for upload to process...');
  await page.waitForTimeout(5000);

  // Take screenshot to see state after upload
  await page.screenshot({ path: 'after_upload_screenshot.png' });

  // Scroll to bottom and click Save
  console.log('Scrolling to save button...');
  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await page.waitForTimeout(1000);

  // Find and click save - itch.io uses <button class="save_btn"> or similar
  const saveSelectors = [
    'button.save_btn',
    'input[type="submit"][value*="Save"]',
    'button:has-text("Save")',
    '.buttons button.button',
  ];

  let saved = false;
  for (const sel of saveSelectors) {
    const btn = page.locator(sel).first();
    if (await btn.count() > 0) {
      const text = await btn.textContent().catch(() => '') || await btn.getAttribute('value').catch(() => '');
      console.log(`Clicking save button (${sel}): "${text}"`);
      await btn.click();
      saved = true;
      break;
    }
  }

  if (!saved) {
    // Broad search
    const buttons = await page.locator('button, input[type="submit"]').all();
    for (const btn of buttons) {
      const text = (await btn.textContent().catch(() => '')) + (await btn.getAttribute('value').catch(() => '') || '');
      if (text.toLowerCase().includes('save')) {
        console.log(`Clicking button: "${text.trim()}"`);
        await btn.click();
        saved = true;
        break;
      }
    }
  }

  if (!saved) {
    console.log('Warning: Could not find save button');
  }

  console.log('Waiting for save to complete...');
  await page.waitForTimeout(5000);

  const pageUrl = page.url();
  console.log('Current URL after save:', pageUrl);

  await page.screenshot({ path: 'after_save_screenshot.png' });
  console.log('Saved verification screenshot');

  await context.close();
  console.log('Done!');
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
