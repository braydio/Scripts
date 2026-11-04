# TLDR 

## Quickstart: Mercor One-Click Auto-Applier

1. Sign in to [Mercor](https://work.mercor.com/) and open the **Explore** page.
2. Open your browser's Developer Console using `Ctrl + Shift + J` (Windows/Linux) or `Cmd + Option + J` (Mac).
3. Open [One-Click-Applier.js](https://github.com/braydio/Scripts/blob/master/auto-tooling/One-Click-Applier.js), click **Raw**, and copy the entire script.
4. Paste the code into the Console and press **Enter**.
5. Leave the Mercor tab open.

**That's it!** The script automatically scans One-time and Project-based listings, submits eligible 1-click applications, and checks for confirmation. It rescans approximately every 90–180 seconds.

**To stop**, enter this in the Console:

```javascript
window.__mercorApplyWatcherStop = true
```

Or simply refresh the page.

**Note:** Applications are submitted automatically without individual approval. Only run the script if you're comfortable applying to all eligible opportunities. This is unofficial automation, so check Mercor's platform rules before using it.

# Not Too Long; Did Read

## Mercor One-Click Auto-Applier

This script automatically finds and submits applications to eligible **1-Click Apply** opportunities on Mercor. It continuously monitors both the **One-time** and **Project-based** sections for new opportunities.

### How to use

1. **Open Mercor.** Sign in to your Mercor account and navigate to the **Explore** page, where available opportunities are listed.

2. **Open Developer Tools.** Press `F12` or `Ctrl + Shift + J` (Windows/Linux), or `Cmd + Option + J` (Mac). Select the **Console** tab.

3. **Copy the script.** Open [One-Click-Applier.js on GitHub](https://github.com/braydio/Scripts/blob/master/auto-tooling/One-Click-Applier.js), click **Raw**, and copy the entire JavaScript file.

4. **Run the script.** Paste the code into the browser's Console and press **Enter**. If Chrome blocks pasting, follow its on-screen instructions to enable it.

5. **Leave Mercor open.** The script will begin scanning available listings, opening eligible opportunities, and automatically clicking the application submission buttons.

6. **Monitor progress.** Keep the Console open to see application attempts, successful submissions, errors, and completed scans.

### What happens automatically?

- Scans **One-time** opportunities first, followed by **Project-based** opportunities.
- Identifies listings labeled **1-click apply**.
- Opens each listing and submits the application, including any supported confirmation step.
- Checks whether Mercor displays an application-submitted confirmation.
- Moves through additional pages of opportunities.
- Repeats the scan approximately every **90–180 seconds**.
- Temporarily skips failed applications for 30 minutes and successful applications for 24 hours during the current session.
- Limits successful submissions to 50 per scan cycle.

### How to stop

To stop the script without closing Mercor, enter the following command in the Console:

```javascript
window.__mercorApplyWatcherStop = true
```

You can also refresh or close the browser tab to end the current script session.

### Important notes

**The script submits applications automatically without requesting approval for each position.** It does not evaluate your qualifications, pay preferences, availability, or employment requirements. Only use it if you're comfortable applying to every eligible 1-click opportunity it finds.

Keep the Mercor tab open while running it. Refreshing the page stops the script, and browser background-tab throttling may delay scans.

The script's application history is stored only in memory, so refreshing or restarting it resets its temporary tracking. Successful submission verification also depends on Mercor's current page layout.

This is an unofficial browser automation script, not a Mercor-supported feature. Review Mercor's automation policies before using it.

**Script:** [github.com/braydio/Scripts/auto-tooling/One-Click-Applier.js](https://github.com/braydio/Scripts/blob/master/auto-tooling/One-Click-Applier.js)
