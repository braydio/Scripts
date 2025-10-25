import os
import time
import traceback
from pathlib import Path
from dotenv import load_dotenv
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.common.exceptions import (
    StaleElementReferenceException,
    TimeoutException,
)
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from webdriver_manager.chrome import ChromeDriverManager

# ==============================
# CONFIG
# ==============================
load_dotenv()
GITHUB_USER = os.getenv("GITHUB_USER", "braydio")
GITHUB_PASS = os.getenv("GITHUB_PASS", "Remington0323")

REPO = "braydio/pyNance"
PR_LIST_URL = f"https://github.com/{REPO}/pulls"
RESTART_FLAG = Path("restart.flag")

# ==============================
# DRIVER SETUP
# ==============================
options = webdriver.ChromeOptions()
options.add_argument("--start-maximized")
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()), options=options
)
WAIT = WebDriverWait(driver, 15)


# ==============================
# FUNCTIONS
# ==============================
def github_login():
    driver.get("https://github.com/login")
    time.sleep(2)
    user_box = driver.find_element(By.NAME, "login")
    pass_box = driver.find_element(By.NAME, "password")
    user_box.clear()
    user_box.send_keys(GITHUB_USER)
    pass_box.clear()
    pass_box.send_keys(GITHUB_PASS)
    pass_box.send_keys(Keys.RETURN)
    print(">>> Logged in to GitHub")
    time.sleep(5)


def get_latest_pr_url():
    driver.get(PR_LIST_URL)
    time.sleep(3)
    links = driver.find_elements(By.CSS_SELECTOR, ".js-issue-row a.Link--primary")
    if not links:
        raise RuntimeError("No PRs found for repo")
    pr_url = links[0].get_attribute("href")
    print(f">>> Latest PR: {pr_url}")
    return pr_url


def merge_latest_pr(pr_url):
    driver.get(pr_url)
    time.sleep(4)

    try:
        print(f">>> PR page title: {driver.title}")
        print(f">>> PR page URL: {driver.current_url}")

        def log_candidates(elements, label):
            print(f">>> {label}: count={len(elements)} (url={driver.current_url})")
            for idx, element in enumerate(elements):
                try:
                    text = element.text.strip().replace("\n", " ")
                    tag = element.tag_name
                    classes = element.get_attribute("class") or ""
                    aria_disabled = element.get_attribute("aria-disabled")
                    outer = element.get_attribute("outerHTML") or ""
                    preview = " ".join(outer.split())
                    if len(preview) > 160:
                        preview = preview[:160] + "..."
                    print(
                        f"    [{idx}] tag={tag} text='{text}' class='{classes}' aria-disabled={aria_disabled}"
                    )
                    print(f"        outerHTML≈ {preview}")
                    try:
                        parent_button = element.find_element(
                            By.XPATH, "./ancestor::button[1]"
                        )
                        parent_class = parent_button.get_attribute("class") or ""
                        parent_disabled = parent_button.get_attribute("aria-disabled")
                        print(
                            f"        parent button class='{parent_class}' aria-disabled={parent_disabled}"
                        )
                    except Exception as parent_err:
                        print(
                            f"        parent button lookup failed: {type(parent_err).__name__}"
                        )
                except StaleElementReferenceException:
                    print(f"    [{idx}] element became stale during logging")

        def find_clickable_button(span_texts, context_label):
            for span_text in span_texts:
                span_locator = (
                    By.XPATH,
                    f"//span[normalize-space()='{span_text}']",
                )
                button_locator = (
                    By.XPATH,
                    f"//span[normalize-space()='{span_text}']/ancestor::button[1]",
                )

                try:
                    WAIT.until(EC.presence_of_element_located(span_locator))
                except TimeoutException:
                    print(
                        f"[!] {context_label}: span '{span_text}' not present within timeout"
                    )
                    continue

                spans = driver.find_elements(*span_locator)
                log_candidates(spans, f"{context_label} spans matching '{span_text}'")

                try:
                    button = WAIT.until(EC.element_to_be_clickable(button_locator))
                except TimeoutException:
                    print(
                        f"[!] {context_label}: button for '{span_text}' not clickable within timeout"
                    )
                    continue

                try:
                    label = button.text.strip().replace("\n", " ")
                except StaleElementReferenceException:
                    print(
                        f"[!] {context_label}: button text stale for '{span_text}', retrying"
                    )
                    continue

                print(
                    f">>> {context_label}: using span '{span_text}' (button label='{label}')"
                )
                return button, label, span_text

            return None, None, None

        # Step 1: Find and click the merge button
        merge_button, merge_label, merge_source = find_clickable_button(
            ["Squash and merge", "Merge pull request"],
            "Merge button",
        )

        if not merge_button:
            raise RuntimeError("No merge button found")

        merge_button.click()
        print(
            f">>> Clicked merge button via '{merge_source}' span (label before click='{merge_label}')"
        )
        time.sleep(2)

        # Step 2: After the DOM refresh, re-find the confirm button
        confirm_clicked = False
        for attempt in range(1, 4):
            confirm_button, confirm_label, confirm_source = find_clickable_button(
                [
                    "Confirm squash and merge",
                    "Confirm merge",
                    "Confirm",
                ],
                f"Confirm button (attempt {attempt})",
            )

            if not confirm_button:
                print(
                    f"[!] Confirm button not ready on attempt {attempt}, waiting briefly"
                )
                time.sleep(2)
                continue

            try:
                confirm_button.click()
                print(
                    f">>> Clicked confirm on attempt {attempt} via '{confirm_source}' span (label before click='{confirm_label}')"
                )
                confirm_clicked = True
                break
            except StaleElementReferenceException:
                print(
                    f"[!] Confirm button became stale on attempt {attempt}; retrying after short wait"
                )
                time.sleep(2)

        if not confirm_clicked:
            print("[!] Unable to click confirm button after multiple attempts")

        time.sleep(5)
        print(">>> Merge flow complete")

    except Exception as e:
        print(f"[!] Could not merge PR: {e}")
        print(traceback.format_exc())
        try:
            print(f">>> Failure URL: {driver.current_url}")
            print(f">>> Failure title: {driver.title}")
        except Exception:
            pass


def get_deepsource_link(pr_url):
    driver.get(pr_url)
    time.sleep(3)
    links = driver.find_elements(By.CSS_SELECTOR, ".js-timeline-item a")
    for link in links:
        href = link.get_attribute("href")
        if href and "deepsource.com" in href:
            print(f">>> DeepSource link: {href}")
            return href
    raise RuntimeError("No DeepSource link found in PR comments")


def go_to_deepsource_issues(ds_url):
    driver.get(ds_url)
    time.sleep(5)
    try:
        issues_tab = driver.find_element(By.LINK_TEXT, "Issues")
        issues_tab.click()
        time.sleep(5)
        print(">>> Navigated to Issues tab")
    except:
        print(">>> Could not locate Issues tab")


def scrape_first_issue():
    try:
        # Open first issue
        first_issue = driver.find_element(By.CSS_SELECTOR, "a[href*='/issue/']")
        issue_url = first_issue.get_attribute("href")
        full_url = (
            issue_url
            if issue_url.startswith("http")
            else "https://app.deepsource.com" + issue_url
        )
        driver.get(full_url)
        time.sleep(3)

        # Issue name
        try:
            issue_name = driver.find_element(
                By.CSS_SELECTOR, "span.pr-2.font-bold.text-vanilla-100"
            ).text.strip()
        except:
            issue_name = "Unknown issue name"

        # Issue code (robust fallback)
        try:
            issue_code = driver.find_element(
                By.XPATH,
                "//span[contains(text(), '-') and contains(@class,'text-vanilla-400')]",
            ).text.strip()
        except:
            try:
                candidates = driver.find_elements(
                    By.CSS_SELECTOR, "span.text-vanilla-400"
                )
                issue_code = next(
                    (c.text.strip() for c in candidates if "-" in c.text.strip()),
                    "unknown-code",
                )
            except:
                issue_code = "unknown-code"

        # File path
        try:
            file_path = driver.find_element(
                By.CSS_SELECTOR,
                "div.space-y-1 a > span.flex.max-w-lg.flex-wrap.items-baseline",
            ).text.strip()
        except:
            file_path = "Unknown path"

        # Gather code snippets
        snippets = []
        for idx, pre in enumerate(
            driver.find_elements(By.CSS_SELECTOR, "pre"), start=1
        ):
            snippet = " ".join(
                span.text
                for span in pre.find_elements(By.CSS_SELECTOR, "span")
                if "ln" not in (span.get_attribute("class") or "")
            )
            if snippet:
                snippets.append(f"--- Code Block {idx} ---\n{snippet.strip()}")

        snippets_text = (
            "\n\n".join(snippets) if snippets else "(no code snippets found)"
        )

        # Write to file
        text = f"""# DeepSource Issue Report

Issue Code: {issue_code}
Issue Name: {issue_name}
File: {file_path}
DeepSource URL: {full_url}

Relevant Code:
{snippets_text}

Task for Codex:
1. Fix or refactor the issue.
2. Implement changes to bring in line with best practices.
3. Update documentation/tests if needed.
"""
        with open("issue.txt", "w", encoding="utf-8") as f:
            f.write(text)

        print(">>> Saved issue.txt for Codex handoff")
    except Exception as e:
        print(f"[!] Failed to scrape issue: {e}")


def wait_for_restart():
    print(">>> Waiting for restart.flag...")
    while not RESTART_FLAG.exists():
        time.sleep(2)
    RESTART_FLAG.unlink()
    print(">>> Restart flag detected")


# ==============================
# MAIN LOOP
# ==============================
if __name__ == "__main__":
    try:
        github_login()
        while True:
            wait_for_restart()
            pr_url = get_latest_pr_url()
            merge_latest_pr(pr_url)
            ds_link = get_deepsource_link(pr_url)
            go_to_deepsource_issues(ds_link)
            scrape_first_issue()
    finally:
        driver.quit()
