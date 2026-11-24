/*
 * poodlechat - UI overrides
 *
 * pup: index.html always loads this file, so it must exist.
 *
 * config.default.js sets `window.CONFIG = {...}` and is marked DO NOT EDIT.
 * This file loads immediately after it, so assigning individual properties
 * here overrides just those keys and leaves the rest at their defaults, and
 * updates to the defaults never need merging by hand.
 *
 * See config.default.js for every key and its default value.
 */

// set here, not in index.css: the inline style wins over .chat-window
CONFIG.style.background = 'rgba(0, 0, 0, 0.5)';
CONFIG.fadeTimeout = 500;                  // ms (default 7000); raise this if chat vanishes too fast

// CONFIG.suggestionLimit = 5;             // command suggestions shown at once
// CONFIG.style.width = '38%';             // chat box size
// CONFIG.style.height = '22%';
