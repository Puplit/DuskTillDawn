/* pup: MOVABLE HUD.
   A layout is { key: {dx, dy} } in PIXELS, written straight onto CSS custom
   properties. An absent or zero entry leaves the element exactly where the
   stock stylesheet puts it, so a missing layout is not a broken HUD. */
var HUD_KEYS = {
    hunger:   '#varHunger',
    thirst:   '#varThirst',
    temp:     '#varTemp',
    recovery: '#varRecovery',
    eco:      '#varEco',
    heist:    '#varHeist',
    alarm:    '#varAlarm'
};

/* The gauges carry `transform: scale(1.2)` from `.c100.small`, and writing a
   translate on top of that has to REPLACE the whole transform - so the scale is
   restated here or they would silently shrink.

   Written as an inline style rather than a CSS variable on purpose: inline beats
   every stylesheet rule, so nothing in a 30KB stylesheet full of `transform`
   declarations can quietly out-specify it. */
var HUD_SCALE = { hunger: 1.2, thirst: 1.2, temp: 1.2, recovery: 1.2, eco: 1.2, heist: 1.2, alarm: 1.2 };

/* ---------- CONFIG ----------
   config/main.lua + config/locale.lua, handed over by hudmove.lua: the page asks
   for it with the 'hudConfig' NUI callback as soon as it loads, and Lua pushes a
   'hudConfig' message again when it applies the saved layout. Until it arrives the
   values below are used - they are the shipped defaults, so nothing jumps. */
var LOCALE           = {};
var FADE_MS          = 500;
var RECOVERY_TICK_MS = 500;
var HEIST_ALARM_MAX  = 4;
var HEIST_LINGER_MS  = 4000;
var currentLayout    = null;   // last layout from Lua, re-applied when the scale changes

function L(key, fallback) {
    var v = LOCALE[key];
    return (typeof v === 'string') ? v : fallback;
}
function capitalise(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

function setText(selector, text) {
    var el = document.querySelector(selector);
    if (el) el.textContent = text;
}

function applyNuiConfig(cfg) {
    if (!cfg || typeof cfg !== 'object') return;
    if (cfg.locale && typeof cfg.locale === 'object') LOCALE = cfg.locale;

    var g = cfg.gauges || {};
    var root = document.documentElement.style;
    if (g.anchorBottom) root.setProperty('--hud-bottom', g.anchorBottom);
    if (g.anchorLeft)   root.setProperty('--hud-left', g.anchorLeft);
    if (typeof g.scale === 'number') {
        root.setProperty('--hud-scale', String(g.scale));
        for (var k in HUD_SCALE) HUD_SCALE[k] = g.scale;
    }
    if (typeof g.fadeMs === 'number') FADE_MS = g.fadeMs;
    var c = g.colours || {};
    if (c.ring)       root.setProperty('--hud-ring', c.ring);
    if (c.goldRing)   root.setProperty('--hud-ring-gold', c.goldRing);
    if (c.background) root.setProperty('--hud-ring-bg', c.background);
    if (c.inner)      root.setProperty('--hud-ring-inner', c.inner);

    if (cfg.recovery && typeof cfg.recovery.tickMs === 'number') RECOVERY_TICK_MS = cfg.recovery.tickMs;
    if (cfg.heist) {
        if (typeof cfg.heist.alarmMax === 'number') HEIST_ALARM_MAX = cfg.heist.alarmMax;
        if (typeof cfg.heist.lingerMs === 'number') HEIST_LINGER_MS = cfg.heist.lingerMs;
    }

    // the Display rows: order, choices and defaults come from Config.Settings
    if (Array.isArray(cfg.settings) && cfg.settings.length) {
        var defs = [], defaults = {}, oldNames = {};
        SETTINGS_DEF.forEach(function (d) { oldNames[d.key] = d.name; });
        cfg.settings.forEach(function (s) {
            if (!s || !s.key) return;
            var values = Array.isArray(s.choices) ? s.choices : [s.default];
            defs.push({ key: s.key, name: L('setting' + capitalise(s.key), oldNames[s.key] || s.key), values: values });
            defaults[s.key] = s.default;
        });
        SETTINGS_DEF = defs;
        SETTINGS_DEFAULT = defaults;
    } else {
        SETTINGS_DEF.forEach(function (d) { d.name = L('setting' + capitalise(d.key), d.name); });
    }

    // static editor text
    setText('#hudEditTitle', L('editorTitle', 'HUD'));
    var secs = document.querySelectorAll('#hudEditPanel .hud-sec');
    if (secs[0]) secs[0].textContent = L('sectionDisplay', 'Display');
    if (secs[1]) secs[1].textContent = L('sectionPosition', 'Position');
    setText('#hudEditHint', L('positionHint', 'Drag a gauge, or click a row to reset it'));
    setText('#hudEditSave', L('buttonSave', 'Save'));
    setText('#hudEditReset', L('buttonReset', 'Reset All'));
    setText('#hudEditClose', L('buttonClose', 'Close'));
    if (!window.tempSeen) setText('#varTemp small', L('tempLoading', 'Loading...'));

    if (currentLayout) applyHudLayout(currentLayout);
    if (editorOpen) { buildSettings(); buildPanel(); }
}

function applyHudLayout(layout) {
    for (var key in HUD_KEYS) {
        var el = document.querySelector(HUD_KEYS[key]);
        if (!el) continue;
        var e  = (layout && layout[key]) || {};
        var dx = Number(e.dx) || 0;
        var dy = Number(e.dy) || 0;
        var s  = HUD_SCALE[key];
        el.style.transform = 'translate(' + dx + 'px, ' + dy + 'px)' + (s ? ' scale(' + s + ')' : '');
    }
}

/* ------------------------------------------------------------------
   THE EDITOR (ps-hud style: grab the thing and drag it)

   Money and the ID readout belong to vorp_core's NUI page, and only one
   page can hold mouse focus - so this page owns the editor and draws a
   HANDLE for every movable element, including those two. Dragging a
   handle moves the real element live, whichever page it lives in:
   ours through CSS variables, vorp_core's through Lua.

   The handles for our own gauges are measured off the real elements. The two
   foreign ones cannot be measured from here, so their position is RECREATED
   from vorp_core's own CSS rather than eyeballed - an approximate anchor put
   the grab box nowhere near the thing it moves.
   ------------------------------------------------------------------ */

/* Money lives at the right-hand end of
     .Header__inner__3hvj8 { max-width:1420px; margin:0 auto; padding:0 10px; height:60px; display:flex }
   with .Header__player__2Slh1 { margin-left:auto }.
   So its x depends on the viewport AND that 1420 cap - which is exactly why a
   fixed `right: 2vw` guess drifted. Rebuilding the same boxes lets the browser
   work the position out for us. */
function moneyRect() {
    var vw = window.innerWidth;
    var inner = Math.min(vw, 1420);
    var right = (vw - inner) / 2 + inner - 10;   // 10px padding-right
    var w = 150;
    return { left: right - w, top: 10, width: w, height: 40 };
}

/* #info { position:absolute; bottom:45px; left:10px; width:200px; height:5px }
   and #textid { position:relative; top:-1.9vw; font-size:0.8vw } - the text is
   lifted well above the box it sits in, which is why a plain bottom:38px guess
   landed low. */
function idRect() {
    var vw = window.innerWidth;
    var lift = 1.9 * vw / 100;
    var fs = 0.8 * vw / 100;
    var boxTop = window.innerHeight - 45 - 5;
    return { left: 10, top: boxTop - lift, width: 110, height: Math.max(20, fs * 1.8) };
}

/* The mail envelope is a THIRD frame again - the mail resource's own page.
   #mailEmojiContainer { position:fixed; bottom:10px; left:60px; font-size:2em } */
function mailRect() {
    return { left: 60, top: window.innerHeight - 10 - 38, width: 40, height: 38 };
}

/* pup-ui's #prog-wrap { left:50%; bottom:14vh; width:19vw; min-width:210px }
   translateX(-50%), so the left edge is half its width back from centre */
function progressRect() {
    var vw = window.innerWidth, vh = window.innerHeight;
    var w = Math.max(210, 19 * vw / 100);
    var h = 5.2 * vh / 100;
    return { left: (vw - w) / 2, top: vh - (14 * vh / 100) - h, width: w, height: h };
}

/* mumble_display, NOT mumble: server.cfg sets `voice_enableUi 0`, so mumble's
   own .voiceInfo never renders and a box aimed at it sat over empty screen.
   The gauge is .main { position:absolute; left:0; bottom:11% } holding a 2vw
   mic circle (li adds a 5px left margin) with the #range pill hung underneath,
   so the grab box covers the circle and the pill together. */
function voiceRect() {
    var vw = window.innerWidth, vh = window.innerHeight;
    var circle = 0.02 * vw;
    return { left: 0, top: vh * 0.89 - circle - 2, width: circle + 12, height: circle + 28 };
}

var FOREIGN_RECTS = { money: moneyRect, id: idRect, mail: mailRect, progress: progressRect, voice: voiceRect };
/* ---------- SETTINGS ----------
   A threshold of 0 means "always shown"; anything else means "only once it has
   dropped to that percent or below", which is the point of the setting - a full
   belly is not information worth screen space. */
var SETTINGS_DEF = [
    { key: 'tempUnit',  name: 'Temperature', values: ['C', 'F'] },
    { key: 'money',     name: 'Money',       values: ['always', 'hidden'] },
    { key: 'moneyFont', name: 'Money Font',  values: ['lino', 'display'] },
    { key: 'moneySize', name: 'Money Size',  values: ['m', 's', 'l'] },
    { key: 'hunger',    name: 'Hunger',      values: [0, 75, 50, 25] },
    { key: 'thirst',    name: 'Thirst',      values: [0, 75, 50, 25] },
    { key: 'menuSide',  name: 'Menus',       values: ['left', 'right'] },
    { key: 'progressStyle', name: 'Progress Bar', values: ['line', 'ring'] }
];
var SETTINGS_DEFAULT = {
    tempUnit: 'C', money: 'always', moneyFont: 'lino', moneySize: 'm',
    hunger: 0, thirst: 0, menuSide: 'left', progressStyle: 'line'
};

function settingLabel(key, v) {
    if (key === 'progressStyle') return v === 'ring' ? L('valueProgressRing', 'Ring') : L('valueProgressLine', 'Line');
    if (key === 'menuSide')  return v === 'right' ? L('valueMenuRight', 'Right side') : L('valueMenuLeft', 'Left side');
    if (key === 'tempUnit')  return v === 'F' ? L('valueFahrenheit', 'Fahrenheit  °F') : L('valueCelsius', 'Celsius  °C');
    if (key === 'money')     return v === 'hidden' ? L('valueHidden', 'Hidden') : L('valueAlwaysShown', 'Always shown');
    if (key === 'moneyFont') return v === 'display' ? L('valueFontDisplay', 'Display') : L('valueFontClassic', 'Classic');
    if (key === 'moneySize') return v === 's' ? L('valueSizeSmall', 'Small') : v === 'l' ? L('valueSizeLarge', 'Large') : L('valueSizeNormal', 'Normal');
    return (Number(v) || 0) <= 0 ? L('valueAlwaysShown', 'Always shown') : L('valueBelow', 'Below %d%').replace('%d', v);
}
function settingIsOff(key, v) {
    if (key === 'money') return v === 'hidden';
    return false;
}

var settings   = JSON.parse(JSON.stringify(SETTINGS_DEFAULT));
var editSettings = null;   // the working copy while the editor is open
var editorOpen = false;
var lastPct    = {};       // last hunger/thirst reading, to re-evaluate on change
var lastShow   = true;     // last body-visibility state, so it animates on change only

function activeSettings() { return editSettings || settings; }

/* Whether a gauge should be on screen right now. While the editor is open
   EVERYTHING shows - you cannot position something you cannot see. */
function gaugeVisible(key, pct) {
    if (editorOpen) return true;
    var t = Number(activeSettings()[key]) || 0;
    if (t <= 0) return true;
    return (Number(pct) || 0) <= t;
}

function applyGaugeVisibility() {
    ['hunger', 'thirst'].forEach(function (key) {
        var el = document.querySelector(HUD_KEYS[key]);
        if (el) el.style.display = gaugeVisible(key, lastPct[key]) ? '' : 'none';
    });
    // recovery is normally only up after a revive; show it while editing so it
    // can be placed, then put it back to however the countdown left it
    var rec = document.querySelector('#varRecovery');
    if (rec) {
        if (editorOpen) {
            // 'block', not '': the stylesheet has #varRecovery { display: none },
            // so clearing the inline value just falls back to hidden
            rec.style.display = 'block';
            if (!/\bp\d+\b/.test(rec.className)) rec.className = 'c100 small second p50';
        } else if (!window.recoveryTimer) {
            rec.style.display = 'none';
        }
    }
    // same for the Eco Boost gauge: a sample half-ring while editing
    var eco = document.querySelector('#varEco');
    if (eco) {
        if (editorOpen) {
            eco.style.display = 'block';
            if (!window.ecoActive) eco.className = 'c100 small second eco p50';
        } else if (!window.ecoActive) {
            eco.style.display = 'none';
        }
    }
    // and the heist gauges: sample rings while editing, hidden otherwise
    [['#varHeist', 'heist', 60], ['#varAlarm', 'alarm', 25]].forEach(function (g) {
        var el = document.querySelector(g[0]);
        if (!el) return;
        if (editorOpen) {
            el.style.display = 'block';
            if (!window.heistActive) el.className = 'c100 small second ' + g[1] + ' p' + g[2];
        } else if (!window.heistActive && !window.heistLinger) {
            el.style.display = 'none';
        }
    });
}

/* pup: bank heist gauges (pup_robbery). timer 0-100 fills up; alarm/alarmMax. */
function renderHeist(data) {
    var t = document.querySelector('#varHeist'), a = document.querySelector('#varAlarm');
    if (!t || !a) return;
    if (window.heistHide) { clearTimeout(window.heistHide); window.heistHide = null; }
    if (!data.active) {
        window.heistActive = false;
        // a timer that ran out stays full for a moment before it goes
        var wait = (window.heistLastPct >= 100) ? HEIST_LINGER_MS : 0;
        window.heistLinger = wait > 0;
        window.heistHide = setTimeout(function () {
            window.heistLinger = false;
            if (!editorOpen && !window.heistActive) { t.style.display = 'none'; a.style.display = 'none'; }
        }, wait);
        return;
    }
    window.heistActive = true;
    var pct = Math.max(1, Math.min(100, Math.round(Number(data.timer) || 0)));
    window.heistLastPct = pct;
    var max = Number(data.alarmMax) || HEIST_ALARM_MAX;
    var apct = Math.max(1, Math.min(100, Math.round((Number(data.alarm) || 0) / max * 100)));
    t.className = 'c100 small second heist p' + pct;
    a.className = 'c100 small second alarm p' + apct;
    t.style.display = 'block';
    a.style.display = 'block';
}

/* pup: Eco Boost (pup-misc). Ring = earned / cap, caption = the numbers. */
function ecoMoney(n) {
    n = Number(n) || 0;
    return '$' + (Number.isInteger(n) ? n : n.toFixed(2));
}
function renderEco(data) {
    var eco = document.querySelector('#varEco');
    if (!eco) return;
    window.ecoActive = !!data.active;
    if (!data.active) {
        if (!editorOpen) eco.style.display = 'none';
        return;
    }
    var cap = Number(data.cap) || 0, earned = Number(data.earned) || 0;
    var pct = cap > 0 ? Math.round(earned / cap * 100) : 0;
    pct = Math.max(1, Math.min(100, pct));
    eco.className = 'c100 small second eco p' + pct;
    eco.style.display = 'block';
}

var editLayout = {};
var handles = {};
var dragListeners = [];   // [onMove, onUp] pairs, torn down when handles rebuild

function clearHandles() {
    for (var k in handles) {
        if (handles[k] && handles[k].parentNode) handles[k].parentNode.removeChild(handles[k]);
    }
    handles = {};
    dragListeners.forEach(function (p) {
        window.removeEventListener('mousemove', p[0]);
        window.removeEventListener('mouseup', p[1]);
    });
    dragListeners = [];
}

function offsetOf(key) {
    var e = editLayout[key] || {};
    return { dx: Number(e.dx) || 0, dy: Number(e.dy) || 0 };
}

function pushLive() {
    applyHudLayout(editLayout);
    applyGaugeVisibility();
    // vorp_core's money/ID and the temperature unit are applied by Lua; tell it
    // on every change so everything tracks live rather than jumping on save
    post('hudLive', { layout: editLayout, settings: activeSettings() });
}

/* Derived, never hardcoded: a NUI callback routes by RESOURCE NAME, so a
   renamed folder would silently 404 every save. This is what caught pup_id. */
var NUI_BASE = 'https://' +
    ((typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'fred_hud') + '/';

function post(name, body) {
    try {
        fetch(NUI_BASE + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {})
        }).catch(function () {});
    } catch (err) {}
}

/* No label on the box: you click the gauge itself. The panel row names it, and
   hovering either one lights the other, which is enough to tell them apart. */
function makeHandle(key, rect) {
    var h = document.createElement('div');
    h.className = 'hud-handle';
    h.style.left   = rect.left + 'px';
    h.style.top    = rect.top + 'px';
    h.style.width  = Math.max(60, rect.width) + 'px';
    h.style.height = Math.max(24, rect.height) + 'px';

    var start = null;
    h.addEventListener('mouseenter', function () { highlight(key); });
    h.addEventListener('mousedown', function (ev) {
        var o = offsetOf(key);
        start = { x: ev.clientX, y: ev.clientY, dx: o.dx, dy: o.dy,
                  left: parseFloat(h.style.left), top: parseFloat(h.style.top) };
        h.classList.add('dragging');
        highlight(key);
        ev.preventDefault();
        ev.stopPropagation();
    });

    // On window, not the handle: the pointer routinely outruns a small box.
    // Kept in a list so they can be torn down - rebuilding the handles used to
    // add six more of these every time the menu opened, and never remove any.
    var onMove = function (ev) {
        if (!start) return;
        var mx = ev.clientX - start.x, my = ev.clientY - start.y;
        editLayout[key] = { dx: Math.round(start.dx + mx), dy: Math.round(start.dy + my) };
        h.style.left = (start.left + mx) + 'px';
        h.style.top  = (start.top + my) + 'px';
        pushLive();
        refreshRow(key);
    };
    var onUp = function () {
        if (!start) return;
        start = null;
        h.classList.remove('dragging');
    };
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
    dragListeners.push([onMove, onUp]);

    document.getElementById('hudEdit').appendChild(h);
    handles[key] = h;
    return h;
}

function buildHandles() {
    clearHandles();

    // our own gauges: measure where they actually are right now
    for (var key in HUD_KEYS) {
        var el = document.querySelector(HUD_KEYS[key]);
        if (!el) continue;
        var r = el.getBoundingClientRect();
        // a gauge that measures nothing has no grabbable area; park a box near
        // the corner the HUD lives in so it can still be dragged out
        if (r.width < 4 || r.height < 4) {
            r = { left: 40, top: window.innerHeight - 140, width: 56, height: 56 };
        }
        makeHandle(key, { left: r.left, top: r.top, width: r.width, height: r.height });
    }

    // the two that live in vorp_core's page: position recreated from its CSS,
    // then shifted by whatever offset is already applied to the real element
    for (var fk in FOREIGN_RECTS) {
        var base = FOREIGN_RECTS[fk]();
        var o = offsetOf(fk);
        makeHandle(fk, { left: base.left + o.dx, top: base.top + o.dy,
                         width: base.width, height: base.height });
    }
}

/* The panel and the world handles are two views of the same list: hovering or
   clicking a row lights its handle, and dragging a handle updates its row. */
var PANEL_ORDER = ['hunger', 'thirst', 'temp', 'recovery', 'money', 'id', 'mail', 'eco', 'heist', 'alarm', 'progress', 'voice'];
var PANEL_NAMES = {
    hunger: 'Hunger', thirst: 'Thirst', temp: 'Temperature',
    recovery: 'Recovery', money: 'Money', id: 'Player ID', mail: 'Mail Icon',
    eco: 'Eco Boost', heist: 'Heist Timer', alarm: 'Heist Alarm',
    progress: 'Progress Bar', voice: 'Voice'
};
var rows = {};

function highlight(key) {
    for (var k in handles) { if (handles[k]) handles[k].classList.toggle('active', k === key); }
    for (var r in rows) { if (rows[r]) rows[r].classList.toggle('active', r === key); }
}

function refreshRow(key) {
    var row = rows[key];
    if (!row) return;
    var o = offsetOf(key);
    var moved = (o.dx !== 0 || o.dy !== 0);
    row.classList.toggle('moved', moved);
    row.querySelector('.hud-opt-value').textContent =
        moved ? (o.dx + ', ' + o.dy) : L('positionDefault', 'default');
}

function buildSettings() {
    var list = document.getElementById('hudSetList');
    list.innerHTML = '';

    SETTINGS_DEF.forEach(function (def) {
        var row = document.createElement('div');
        row.className = 'hud-opt setting';

        var name = document.createElement('span');
        name.className = 'hud-opt-name';
        name.textContent = def.name;

        var val = document.createElement('span');
        val.className = 'hud-opt-value';

        var paint = function () {
            var cur = activeSettings()[def.key];
            val.textContent = settingLabel(def.key, cur);
            row.classList.toggle('off', settingIsOff(def.key, cur));
        };
        paint();

        // one click cycles to the next choice - no submenus for four options
        row.addEventListener('click', function () {
            var cur = activeSettings()[def.key];
            var i = def.values.indexOf(cur);
            if (i < 0) {
                i = def.values.map(String).indexOf(String(cur));
            }
            activeSettings()[def.key] = def.values[(i + 1) % def.values.length];
            paint();
            pushLive();
        });

        row.appendChild(name);
        row.appendChild(val);
        list.appendChild(row);
    });
}

function buildPanel() {
    var list = document.getElementById('hudEditList');
    list.innerHTML = '';
    rows = {};

    PANEL_ORDER.forEach(function (key) {
        var row = document.createElement('div');
        row.className = 'hud-opt';

        var name = document.createElement('span');
        name.className = 'hud-opt-name';
        name.textContent = L('element' + capitalise(key), PANEL_NAMES[key] || key);

        var val = document.createElement('span');
        val.className = 'hud-opt-value';

        row.appendChild(name);
        row.appendChild(val);

        row.addEventListener('mouseenter', function () { highlight(key); });
        // clicking a row zeroes just that one - the quickest way to undo a
        // single bad drag without resetting the whole layout
        row.addEventListener('click', function () {
            delete editLayout[key];
            pushLive();
            buildHandles();
            refreshRow(key);
            highlight(key);
        });

        list.appendChild(row);
        rows[key] = row;
        refreshRow(key);
    });
}

/* An EMPTY Lua table encodes to `[]`, not `{}` - so a player who has never saved
   a layout gets an ARRAY here. Assigning editLayout['hunger'] to an array works
   silently, but JSON.stringify then throws those keys away ("[]"), so every drag
   posted an empty layout to Lua, Lua echoed the empty layout straight back, and
   the gauge snapped home on every mouse move. Nothing could be moved - until
   "Reset All", which assigns a real {} and made it start working.

   Copied key by key so whatever arrives, this is a plain object. */
function asObject(v) {
    var out = {};
    if (v && typeof v === 'object') {
        for (var k in v) {
            if (Object.prototype.hasOwnProperty.call(v, k)) out[k] = v[k];
        }
    }
    return out;
}

function openEditor(layout, saved) {
    editLayout   = asObject(JSON.parse(JSON.stringify(layout || {})));
    editSettings = JSON.parse(JSON.stringify(saved || settings || SETTINGS_DEFAULT));
    editorOpen   = true;
    // whatever the fade was doing, the editor has to be visible NOW
    $('body').stop(true).css('opacity', 1);
    lastShow = true;
    document.getElementById('hudEdit').classList.remove('hidden');
    buildSettings();
    buildPanel();
    // everything is forced visible now, so measure the handles AFTER that
    applyGaugeVisibility();
    buildHandles();
}

function closeEditor() {
    editorOpen   = false;
    editSettings = null;
    document.getElementById('hudEdit').classList.add('hidden');
    clearHandles();
    // back to the real rules now that nothing needs to be seen to be placed
    applyGaugeVisibility();
}

document.addEventListener('DOMContentLoaded', function () {
    try {
        fetch(NUI_BASE + 'hudConfig', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: '{}'
        }).then(function (r) { return r.json(); }).then(applyNuiConfig).catch(function () {});
    } catch (err) {}
    document.getElementById('hudEditSave').addEventListener('click', function () {
        settings = JSON.parse(JSON.stringify(activeSettings()));
        post('hudSave', { layout: editLayout, settings: settings });
        closeEditor();
    });
    document.getElementById('hudEditReset').addEventListener('click', function () {
        editLayout   = {};
        editSettings = JSON.parse(JSON.stringify(SETTINGS_DEFAULT));
        pushLive();
        buildHandles();
        buildPanel();
        buildSettings();
    });
    document.getElementById('hudEditClose').addEventListener('click', function () {
        post('hudCancel', {});
        closeEditor();
    });
});

window.addEventListener('message', function (event) {
    if (event.data.action === 'hudConfig') {
        applyNuiConfig(event.data.config);
        return;
    }
    if (event.data.action === 'hudLayout') {
        currentLayout = event.data.layout;
        applyHudLayout(event.data.layout);
        if (event.data.settings) {
            settings = event.data.settings;
            applyGaugeVisibility();
        }
        return;
    }
    if (event.data.action === 'hudEdit') {
        if (event.data.on) { openEditor(event.data.layout, event.data.settings); } else { closeEditor(); }
        return;
    }
    /* pup: whole-HUD switch for /hideUi. #statusHud wraps every gauge, so hiding
       the wrapper takes the rings, the thermometer and the eco/heist/recovery
       bars with it. applyGaugeVisibility only sets display on the gauges INSIDE
       it, so the two never fight. */
    if (event.data.action === 'hudVisible') {
        var hud = document.getElementById('statusHud');
        if (hud) hud.style.display = event.data.show ? '' : 'none';
        return;
    }

// pup: only touch HUD visibility when the message actually carries `show` -
// otherwise every other message (like the recovery bar) faded the HUD out.
//
// ONLY ON CHANGE. `show` rides every 250ms tick, so this used to queue a 500ms
// jQuery animation four times a second forever. The queue outran real time and
// body opacity lagged behind - which is why the editor sometimes opened into a
// half-faded body and looked like /hud had done nothing at all.
if (typeof event.data.show !== 'undefined') {
    // the editor must never be faded out from under itself
    var want = editorOpen ? true : !!event.data.show;
    if (want !== lastShow) {
        lastShow = want;
        $('body').stop(true).animate({ opacity: want ? 1 : 0 }, FADE_MS);
    }
}

if (event.data.action === 'ecoBoost') {
    renderEco(event.data);
    return;
}

if (event.data.action === 'heist') {
    renderHeist(event.data);
    return;
}

// pup: post-revive weakness countdown (action 'recoveryBar', seconds > 0 = start).
// Rendered as a c100 pie circle like hunger/thirst, draining 100 -> 0.
if (event.data.action === 'recoveryBar') {
    if (window.recoveryTimer) { clearInterval(window.recoveryTimer); window.recoveryTimer = null; }
    var secs = Number(event.data.seconds) || 0;
    if (secs > 0) {
        var endAt = Date.now() + secs * 1000;
        $('#varRecovery').attr('class', 'c100 small second p100').show();
        window.recoveryTimer = setInterval(function () {
            var remain = endAt - Date.now();
            if (remain <= 0) {
                clearInterval(window.recoveryTimer);
                window.recoveryTimer = null;
                $('#varRecovery').hide();
                return;
            }
            var pct = Math.max(1, Math.min(100, Math.round(remain / (secs * 10))));
            $('#varRecovery').attr('class', 'c100 small second p' + pct);
        }, RECOVERY_TICK_MS);
    } else {
        $('#varRecovery').hide();
    }
    return;
}
//    console.log(event.data.temp);
    
//    if(typeof(event.data.items) != 'undefined') {
//                    $("#varMoney small").text(event.data.cash);
//        // .toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
//    }
    if(event.data.items) {
        //console.log(JSON.stringify(event.data.items));
        $("#varMoney small").text(event.data.items.cash.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ","));
    }
    
	switch (event.data.action) {
        case 'updateStatusHud':
                if(event.data.temp) {
                    window.tempSeen = true;
                    $("#varTemp small").text(event.data.temp);
                }

                if(event.data.cash) {
                    $("#varMoney small").text(event.data.cash.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ","));
                }

				if(event.data.hunger) {
                    $("#varHunger").attr("class", "c100 small first p"+ Math.ceil(event.data.hunger));
                    lastPct.hunger = event.data.hunger;
                }

                if(event.data.thirst) {
                    $("#varThirst").attr("class", "c100 small second p"+ Math.ceil(event.data.thirst));
                    lastPct.thirst = event.data.thirst;
                }
                // .attr("class") above wipes the class list, so re-apply the
                // show/hide rule every tick rather than only when it changes
                applyGaugeVisibility();

                if(event.data.stress) {
                    $("#varStress").attr("class", "c100 small first p"+ Math.ceil(event.data.stress));
                }
    }
});
