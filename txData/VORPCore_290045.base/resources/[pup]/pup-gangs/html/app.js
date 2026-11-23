/* pup-gangs / app.js - the gang's own interface.
   One data bundle from Lua (panel / factions / territories / dens / claim
   targets + a static config snapshot); every page renders from it. Actions post back
   to the 'act' NUI callback, which routes them to the server events. */

let DATA = null;   // { panel, factions, territories, dens, claimTargets }
let CFG  = null;   // static config snapshot (ranks, levels, curve, ...)
let tab  = 'overview';
let creating = { faction: null };

const $ = (s) => document.querySelector(s);

function el(cls, text, tagName) {
    const d = document.createElement(tagName || 'div');
    if (cls) d.className = cls;
    if (text !== undefined && text !== null) d.textContent = String(text);
    return d;
}

const post = (name, body) =>
    fetch(`https://${GetParentResourceName()}/${name}`, { method: 'POST', body: JSON.stringify(body || {}) });
const act = (id, extra) => post('act', Object.assign({ id: id }, extra || {}));

const fmt = (n) => (Math.floor(Number(n) || 0)).toLocaleString('en-US');
/* a gang flies the colour it CHOSE (server sends it as `hex` on every marker);
   the faction palette is only the fallback for anything without one */
const FCOLOR = { outlaws: '#c0392b', syndicate: '#2980b9', reapers: '#27ae60' };
const fcolor = (k) => FCOLOR[k] || '#8d8d8d';

function ago(secs) {
    secs = Math.max(0, Math.floor(secs || 0));
    if (secs < 60) return secs + 's';
    if (secs < 3600) return Math.floor(secs / 60) + 'm';
    if (secs < 86400) return Math.floor(secs / 3600) + 'h';
    return Math.floor(secs / 86400) + 'd';
}

function radiusAt(points) {
    let r = (CFG && CFG.baseRadius) || 60;
    ((CFG && CFG.radiusCurve) || []).forEach((s) => {
        if ((Number(points) || 0) >= (Number(s.points) || 0)) r = Number(s.radius) || r;
    });
    return Math.min(r, (CFG && CFG.maxRadius) || 140);
}

/* ------------------------------------------------------------------ chrome */
/* No gang DIRECTORY tab: a board listing every gang on the server
   hands out what should be learned in the world.

   Territory claims and fort raids are DEN-ONLY: both are run out of a den, so
   those tabs appear when the panel was opened at one and not at the gang
   table. CTX comes from Lua ('table' or 'den'). */
const DEN_ONLY = { territory: true, raids: true };
const ALL_TABS = [
    ['overview',  'Overview'],
    ['map',       'Gang Map'],
    ['members',   'Members'],
    ['territory', 'Territory'],
    ['raids',     'Raids'],
    ['wars',      'Wars'],
    ['faction',   'Faction'],
    ['perks',     'Perks'],
    ['drug',      'The Product'],
];
let CTX = 'table';
/* which of the two panels this page is currently showing: 'gang' or 'den' */
let MODE = 'gang';
const tabsFor = () => ALL_TABS.filter(([id]) => !DEN_ONLY[id] || CTX === 'den');

function renderChrome() {
    const p = DATA.panel;
    const tabsHost = $('#tabs');
    tabsHost.textContent = '';
    if (p.hasGang) {
        tabsFor().forEach(([id, label]) => {
            const t = el('tab' + (tab === id ? ' on' : ''), label);
            t.addEventListener('click', () => { tab = id; render(); });
            tabsHost.appendChild(t);
        });
    }
    $('#brandTitle').textContent = p.hasGang ? p.name.toUpperCase() : 'THE GANG';
    $('#brandSub').textContent = p.hasGang ? (p.factionLabel || '') : 'Unaffiliated';

    const ident = $('#ident');
    ident.textContent = '';
    if (p.hasGang) {
        const tag = el('chip tag', p.shortname || '?');
        const lvl = el('chip'); lvl.innerHTML = 'LVL <b>' + (p.level || 1) + '</b> ' + (p.levelLabel || '');
        const pts = el('chip'); pts.innerHTML = '<b>' + fmt(p.points) + '</b> PTS';
        const actv = el('chip act-' + (p.activityScore || 'LOW'), p.activityScore || 'LOW');
        ident.appendChild(tag); ident.appendChild(lvl); ident.appendChild(pts); ident.appendChild(actv);
    }
}

/* ------------------------------------------------------------------ blocks */
function statCards(items) {
    const grid = el('cards');
    items.forEach(([value, label, tone]) => {
        const c = el('card');
        const v = el('v' + (tone ? ' ' + tone : ''), value);
        c.appendChild(v);
        c.appendChild(el('l', label));
        grid.appendChild(c);
    });
    return grid;
}

function block(title) {
    const b = el('block');
    if (title) b.appendChild(el('block-title', title));
    return b;
}

function table(columns, rows) {
    const t = document.createElement('table');
    t.className = 'tbl';
    const thead = document.createElement('thead');
    const hr = document.createElement('tr');
    columns.forEach((c) => { const th = document.createElement('th'); th.textContent = c; hr.appendChild(th); });
    thead.appendChild(hr);
    t.appendChild(thead);
    const tbody = document.createElement('tbody');
    rows.forEach((cells) => {
        const tr = document.createElement('tr');
        if (cells.__me) tr.className = 'me';
        cells.forEach((cell) => {
            const td = document.createElement('td');
            if (cell && typeof cell === 'object' && cell.nodeType) { td.appendChild(cell); }
            else if (cell && typeof cell === 'object') { td.textContent = cell.t || ''; if (cell.cls) td.className = cell.cls; }
            else td.textContent = cell === undefined || cell === null ? '' : String(cell);
            tr.appendChild(td);
        });
        tbody.appendChild(tr);
    });
    t.appendChild(tbody);
    return t;
}

function btn(label, cls, onClick) {
    const b = el('btn' + (cls ? ' ' + cls : ''), label);
    if (onClick) b.addEventListener('click', onClick);
    return b;
}

function pageHead(view, title, sub) {
    view.appendChild(el('page-title', title));
    if (sub) view.appendChild(el('page-sub', sub));
}

/* ------------------------------------------------------------------ confirm
   A styled yes/no over the panel. Used for anything that SPENDS - the ledger
   has no refunds, and a misclick on a swatch costing 15 blood money should not
   be possible. Deliberately not the browser's confirm(), which renders as a
   system dialog titled "cfx-nui-pup-gangs". */
function confirmAsk(title, body, okLabel, onOk) {
    const back = el('confirm-back');
    const card = el('confirm-card');
    card.appendChild(el('confirm-title', title));
    card.appendChild(el('confirm-body', body));
    const row = el('btnrow');
    const yes = btn(okLabel || 'Do it', 'red', () => { back.remove(); onOk(); });
    const no = btn('Never mind', null, () => back.remove());
    row.appendChild(yes); row.appendChild(no);
    card.appendChild(row);
    back.appendChild(card);
    /* clicking the dark ground behind it cancels, same as Never mind */
    back.addEventListener('click', (e) => { if (e.target === back) back.remove(); });
    document.body.appendChild(back);
}

/* ------------------------------------------------------------------ pages */
/* a labelled progress bar, for the two things on this panel with a known
   end: the level ladder and the influence curve */
function progress(label, now, goal, right, hex) {
    const wrap = el('prog');
    const head = el('prog-head');
    head.appendChild(el('prog-l', label, 'span'));
    head.appendChild(el('prog-r', right, 'span'));
    wrap.appendChild(head);
    const bar = el('prog-bar');
    const fill = el('prog-fill');
    const pct = goal > 0 ? Math.max(0, Math.min(100, (now / goal) * 100)) : 100;
    fill.style.width = pct + '%';
    if (hex) fill.style.background = hex;
    bar.appendChild(fill);
    wrap.appendChild(bar);
    return wrap;
}

/* the hex of the banner the gang actually flies, for the page accents */
function myColour(p) {
    const found = ((CFG && CFG.blipColors) || []).find((c) => c.key === p.blipcolor);
    return (found && found.hex) || '#a33a2e';
}

function pageOverview(view) {
    const p = DATA.panel;
    const s = p.stats || {};
    const hex = myColour(p);
    pageHead(view, p.name + '  [' + (p.shortname || '?') + ']',
        'You ride as ' + (p.myRankLabel || '?') + '.');

    /* THE BANNER - who the crew is, in its own colours: the name, the word it
       flies under and what its faction is worth, in one block */
    const ban = el('gang-banner');
    ban.style.borderLeftColor = hex;
    ban.style.background = 'linear-gradient(90deg, ' + hex + '1c 0%, rgba(0,0,0,0) 62%)';
    const btop = el('gb-top');
    btop.appendChild(el('gb-lvl', 'Level ' + (p.level || 1) + ' · ' + (p.levelLabel || ''), 'span'));
    /* NOT `act` - that is the module-level action poster, and shadowing it here
       would break the colour swatches further down this same function */
    btop.appendChild(el('gb-act act-' + (p.activityScore || 'LOW'),
        (p.activityScore || 'LOW') + ' activity', 'span'));
    ban.appendChild(btop);
    if (p.motd && p.motd !== '') ban.appendChild(el('gb-motd', '"' + p.motd + '"'));
    if (p.factionBonus) {
        const edge = el('fac-edge');
        edge.appendChild(el('fac-edge-l', 'Faction edge', 'span'));
        edge.appendChild(el('fac-edge-v', p.factionBonus, 'span'));
        ban.appendChild(edge);
    }
    view.appendChild(ban);

    /* TWO JOURNEYS WITH A KNOWN END */
    const bars = el('prog-set');
    const tier = ((CFG && CFG.levels) || []).find((l) => l.level === (p.level || 1));
    const from = tier ? (Number(tier.points) || 0) : 0;
    if (p.levelNextAt) {
        bars.appendChild(progress('To ' + (p.levelNextLabel || 'the next level'),
            (p.points || 0) - from, Math.max(1, p.levelNextAt - from),
            fmt(Math.max(0, p.levelNextAt - (p.points || 0))) + ' points to go', hex));
    } else {
        bars.appendChild(progress('Gang level', 1, 1, 'Top of the ladder', hex));
    }
    if (p.nextStepIn) {
        /* progress WITHIN the current influence step, off the same curve the
           map draws - not a bar that is always nearly empty */
        const curve = (CFG && CFG.radiusCurve) || [];
        let stepFrom = 0, stepTo = (p.points || 0) + (Number(p.nextStepIn) || 0);
        curve.forEach((st) => {
            const at = Number(st.points) || 0;
            if (at <= (p.points || 0)) stepFrom = at;
        });
        bars.appendChild(progress('Influence ' + Math.floor(p.radius) + 'm',
            (p.points || 0) - stepFrom, Math.max(1, stepTo - stepFrom),
            fmt(p.nextStepIn) + ' points to ' + Math.floor(p.nextStepRadius || 0) + 'm', hex));
    } else {
        bars.appendChild(progress('Influence ' + Math.floor(p.radius) + 'm', 1, 1, 'Maxed out', hex));
    }
    view.appendChild(bars);

    view.appendChild(statCards([
        [fmt(p.points), 'Gang points'],
        ['+' + fmt(p.earnedToday || 0), 'Earned today'],
        ['+' + fmt(p.earnedWeek || 0), 'Earned this week'],
        [(p.members || []).length + (p.maxMembers > 0 ? '/' + p.maxMembers : ''), 'Members'],
    ]));

    /* the record is eight figures, so it is drawn as tiles */
    const rec = block('The record');
    const grid = el('rec');
    [['Robberies', s.robberies], ['Bank heists', s.heists], ['Drug missions', s.missions],
     ['Ground taken', s.territories, 'pos'], ['Wars won', s.warsWon, 'pos'],
     ['Wars lost', s.warsLost, 'neg'], ['Kills', s.kills, 'pos'], ['Deaths', s.deaths, 'neg']
    ].forEach(([label, value, tone]) => {
        const t = el('rec-t');
        const v = el('rec-v' + (tone && Number(value) > 0 ? ' ' + tone : ''), fmt(value));
        t.appendChild(v);
        t.appendChild(el('rec-l', label));
        grid.appendChild(t);
    });
    rec.appendChild(grid);
    view.appendChild(rec);

    /* THE COLOURS WE FLY - boss picks the banner; it paints the gang's blips
       and its circle on the Gang Map, so a crew can match its outfits. */
    if (p.isLeader && CFG && CFG.blipColors) {
        const cb = block('The colours we fly');
        const sw = el('swatches');
        /* Changing the banner costs blood money - except the FIRST pick, which
           a crew should not have to pay to stop flying the default. */
        const bmC = DATA.blood;
        const cCost = bmC ? (Number(bmC.perColour) || 0) : 0;
        const firstPick = !p.blipcolor || p.blipcolor === '';
        const cPrice = firstPick ? 0 : cCost;
        const cBroke = cPrice > 0 && (Number(bmC && bmC.balance) || 0) < cPrice;

        CFG.blipColors.forEach((c) => {
            const worn = p.blipcolor === c.key;
            const s = el('swatch' + (worn ? ' on' : '') + ((cBroke && !worn) ? ' disabled' : ''));
            s.style.background = c.hex;
            s.title = worn ? c.label + ' (flying)'
                : (cPrice > 0 ? c.label + ' - ' + cPrice + ' blood money' : c.label);
            /* the one you already fly is free to click and changes nothing */
            if (!cBroke || worn) {
                s.addEventListener('click', () => {
                    if (worn || cPrice <= 0) return act('setcolor', { key: c.key });
                    confirmAsk('Change the colours?',
                        'Flying ' + c.label + ' costs ' + cPrice + ' blood money out of the ledger. '
                        + 'It holds ' + fmt((bmC && bmC.balance) || 0) + '.',
                        'Fly ' + c.label,
                        () => act('setcolor', { key: c.key }));
                });
            }
            sw.appendChild(s);
        });
        cb.appendChild(sw);
        cb.appendChild(el('note', 'Your banner shows on every map - rivals see the colour, never your faction.'));
        if (cCost > 0) {
            cb.appendChild(el('note',
                firstPick
                    ? ('Your first colour is free. Every change after costs ' + cCost + ' blood money.')
                    : ('Changing colours costs ' + cCost + ' blood money. The ledger holds '
                        + fmt((bmC && bmC.balance) || 0) + '.'
                        + (cBroke ? '  Not enough to change.' : ''))));
        }
        view.appendChild(cb);
    }

    const led = block('Gang ledger');
    const rows = (p.activity || []).map((a) => {
        const delta = Number(a.pts) || 0;
        return [
            { t: delta !== 0 ? ((delta > 0 ? '+' : '') + delta) : '\u2014', cls: delta > 0 ? 'pos' : (delta < 0 ? 'neg' : 'dim') },
            { t: ago((p.now || 0) - (a.ts || 0)) + ' ago', cls: 'dim' },
            a.type || '', a.detail || '', { t: a.actor || '', cls: 'dim' },
        ];
    });
    led.appendChild(rows.length ? table(['Points', 'When', 'Type', 'Detail', 'By'], rows) : el('empty', 'No activity yet.'));
    view.appendChild(led);
}

/* THE FRONTIER - pan/zoom survey chart, influence fields, standing plaques,
   a legend that flies you to a gang's ground, a compass and a live scale bar. */
const MAP_W = 2000, MAP_H = 1500;
const WM = { radius: 16000, xOff: 8515, yOff: 10850, w: 11820, h: 8660 };
const worldToMap = (x, y) => [
    ((x + WM.radius - WM.xOff) / WM.w) * MAP_W,
    MAP_H - ((y + WM.radius - WM.yOff) / WM.h) * MAP_H,
];

/* markers are tinted from one hex, so every fill/edge/glow comes off it */
function hexRgb(h) {
    h = String(h || '').replace('#', '');
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    const n = parseInt(h, 16);
    if (h.length !== 6 || !isFinite(n)) return [141, 141, 141];
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
const rgba = (h, a) => { const c = hexRgb(h); return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')'; };

const ROSE = '<svg viewBox="0 0 100 100" aria-hidden="true">'
    + '<circle cx="50" cy="50" r="34" fill="none" stroke="rgba(239,230,213,.35)" stroke-width="1"/>'
    + '<circle cx="50" cy="50" r="27" fill="none" stroke="rgba(239,230,213,.16)" stroke-width="1"/>'
    + '<path d="M50 8 L56 44 L50 50 L44 44 Z" fill="rgba(163,58,46,.9)"/>'
    + '<path d="M50 92 L44 56 L50 50 L56 56 Z" fill="rgba(239,230,213,.5)"/>'
    + '<path d="M8 50 L44 44 L50 50 L44 56 Z" fill="rgba(239,230,213,.28)"/>'
    + '<path d="M92 50 L56 56 L50 50 L56 44 Z" fill="rgba(239,230,213,.28)"/>'
    + '<text x="50" y="20" fill="rgba(239,230,213,.7)" font-size="13" font-family="Georgia,serif"'
    + ' text-anchor="middle">N</text></svg>';

function pageMap(view) {
    const list = DATA.territories || [];
    const held = list.filter((t) => t.gang).length;
    pageHead(view, 'The Frontier',
        held + ' of ' + list.length + ' marker(s) under a flag. Scroll to zoom, drag to pan, pick a gang to fly to its ground.');

    const frame = el('map-frame');
    const world = el('map-world');
    world.appendChild(el('map-plate'));
    world.appendChild(el('map-grid'));

    /* one legend row per gang, not per marker - a gang holding four plots is
       still one force in the field */
    const camps = {};
    const order = [];
    let freeCount = 0;

    list.forEach((t) => {
        const [mx, my] = worldToMap(Number(t.x) || 0, Number(t.y) || 0);
        const color = t.hex || (t.faction ? fcolor(t.faction) : '#8d8d8d');
        const free = !t.gang;
        const d = Math.max(16, ((Number(t.radius) || 60) / WM.w) * MAP_W * 2);

        const c = el('map-circle' + (t.mine ? ' mine' : '') + (free ? ' free' : ''));
        c.style.left = (mx - d / 2) + 'px';
        c.style.top = (my - d / 2) + 'px';
        c.style.width = d + 'px';
        c.style.height = d + 'px';
        c.style.borderColor = rgba(color, free ? 0.4 : 0.8);
        c.style.background = 'radial-gradient(circle at 50% 50%, '
            + rgba(color, 0.04) + ' 0%, '
            + rgba(color, 0.13) + ' 58%, '
            + rgba(color, free ? 0.14 : 0.3) + ' 86%, '
            + rgba(color, 0.05) + ' 100%)';
        world.appendChild(c);

        const dot = el('map-dot' + (free ? ' free' : ''));
        dot.style.left = mx + 'px';
        dot.style.top = my + 'px';
        dot.style.color = color;
        world.appendChild(dot);

        const mark = el('map-mark' + (t.mine ? ' mine' : '') + (free ? ' free' : ''));
        mark.style.left = mx + 'px';
        mark.style.top = my + 'px';
        mark.style.color = color;

        const plaque = el('map-plaque');
        plaque.style.borderColor = rgba(color, free ? 0.4 : 0.6);
        const head = el('map-pl-head');
        head.appendChild(el('map-gl' + (t.hq ? ' hq' : '') + (free ? ' free' : '')));
        head.appendChild(el('bn', t.gang ? ((t.short && t.short !== '') ? t.short : t.gang) : t.name));
        plaque.appendChild(head);
        plaque.appendChild(el('bs', free ? 'UNCLAIMED' : fmt(t.points) + ' PTS'));
        /* no faction line on the map - even your own. Faction is identity, not
           signage; it lives on the Overview and Faction pages.
           The third line says what the marker IS, which is fair game. */
        if (t.hq) plaque.appendChild(el('bf', t.mine ? 'YOUR HEADQUARTERS' : 'HEADQUARTERS'));
        else if (t.mine) plaque.appendChild(el('bf', 'YOUR GROUND'));
        mark.appendChild(plaque);
        mark.appendChild(el('map-stem'));
        world.appendChild(mark);

        if (free) { freeCount++; return; }
        const key = String(t.gangid);
        if (!camps[key]) {
            camps[key] = {
                name: (t.short && t.short !== '') ? t.short : t.gang,
                hex: color, points: Number(t.points) || 0, mine: !!t.mine,
                n: 0, x: mx, y: my,
            };
            order.push(key);
        }
        camps[key].n++;
        /* fly to the HQ when there is one, otherwise the first plot seen */
        if (t.hq) { camps[key].x = mx; camps[key].y = my; }
    });

    const zoom = el('map-zoom');
    const zin = el('map-zbtn', '+');
    const zout = el('map-zbtn', '−');
    const zfit = el('map-zbtn small', 'FIT');
    zoom.appendChild(zin); zoom.appendChild(zout); zoom.appendChild(zfit);

    const rose = el('map-rose');
    rose.innerHTML = ROSE;

    const scale = el('map-scale');
    const scaleBar = el('map-scale-bar');
    const scaleTxt = el('map-scale-txt', '');
    scale.appendChild(scaleBar); scale.appendChild(scaleTxt);

    const legend = el('map-legend');
    legend.appendChild(el('map-leg-title', 'Forces in the field'));
    const legBody = el('map-leg-body');
    legend.appendChild(legBody);

    frame.appendChild(world);
    frame.appendChild(el('map-vig'));
    frame.appendChild(legend);
    frame.appendChild(zoom);
    frame.appendChild(rose);
    frame.appendChild(scale);
    view.appendChild(frame);

    const foot = el('map-foot');
    foot.appendChild(el('mf-l', list.length + ' markers · ' + order.length + ' gang(s) flying colours'));
    foot.appendChild(el('mf-r', 'Scroll to zoom · drag to pan'));
    view.appendChild(foot);

    const v = { x: 0, y: 0, s: 1 };
    const UPX = WM.w / MAP_W;   // world units per plate pixel, for the scale bar
    const apply = () => {
        const vw = frame.clientWidth || 1, vh = frame.clientHeight || 1;
        /* COVER, not contain: the smallest allowed zoom is the one that fills
           the frame on both axes, so the map always reaches every edge (no dead
           space on a wide panel) and you drag to see what is off-screen. */
        const minS = Math.max(vw / MAP_W, vh / MAP_H);
        v.s = Math.min(5, Math.max(minS, v.s));

        /* CENTRE when the map is smaller than the frame on an axis, clamp when
           it is bigger, so the slack is never all piled up on one side. */
        const mw = MAP_W * v.s, mh = MAP_H * v.s;
        if (mw <= vw) { v.x = (vw - mw) / 2; }
        else { v.x = Math.min(0, Math.max(vw - mw, v.x)); }
        if (mh <= vh) { v.y = (vh - mh) / 2; }
        else { v.y = Math.min(0, Math.max(vh - mh, v.y)); }
        world.style.transform = 'translate(' + v.x + 'px, ' + v.y + 'px) scale(' + v.s + ')';
        world.style.setProperty('--inv', String(1 / v.s));
        /* zoomed out: tag only, so plaques never swamp their circles */
        world.classList.toggle('far', v.s < 1.6);

        /* scale bar - a round distance near 140px on screen */
        let dist = 140 * UPX / v.s;
        const pow = Math.pow(10, Math.floor(Math.log10(Math.max(1, dist))));
        const step = [1, 2, 5, 10].find((m) => dist <= m * pow) || 10;
        dist = step * pow;
        scaleBar.style.width = Math.round((dist / UPX) * v.s) + 'px';
        scaleTxt.textContent = dist >= 1000 ? (dist / 1000) + ' KM' : dist + ' M';
    };

    const flyTo = (mx, my, s) => {
        v.s = s;
        apply();
        v.x = frame.clientWidth / 2 - mx * v.s;
        v.y = frame.clientHeight / 2 - my * v.s;
        apply();
    };

    order.sort((a, b) => camps[b].points - camps[a].points).forEach((key) => {
        const g = camps[key];
        const row = el('map-leg-row' + (g.mine ? ' mine' : ''));
        const sw = el('map-leg-sw');
        sw.style.background = g.hex;
        sw.style.boxShadow = '0 0 6px ' + rgba(g.hex, 0.8);
        const txt = el('map-leg-txt');
        txt.appendChild(el('map-leg-n', g.name));
        txt.appendChild(el('map-leg-p', fmt(g.points) + ' PTS · ' + g.n + ' marker(s)' + (g.mine ? ' · YOURS' : '')));
        row.appendChild(sw); row.appendChild(txt);
        row.addEventListener('click', () => flyTo(g.x, g.y, 2.2));
        legBody.appendChild(row);
    });
    if (!order.length) legBody.appendChild(el('map-leg-empty', 'No gang is flying colours on ground you can see.'));
    if (freeCount) {
        /* unclaimed ground is noise once you are reading the war - let it mute */
        const row = el('map-leg-row');
        const sw = el('map-leg-sw');
        sw.style.background = 'none';
        sw.style.border = '1px solid rgba(239,230,213,.5)';
        const txt = el('map-leg-txt');
        txt.appendChild(el('map-leg-n', 'Unclaimed ground'));
        txt.appendChild(el('map-leg-p', freeCount + ' marker(s) · click to hide'));
        row.appendChild(sw); row.appendChild(txt);
        row.addEventListener('click', () => {
            const off = world.classList.toggle('nofree');
            row.classList.toggle('off', off);
            txt.lastChild.textContent = freeCount + ' marker(s) · click to ' + (off ? 'show' : 'hide');
        });
        legBody.appendChild(row);
    }

    let drag = null;
    frame.addEventListener('mousedown', (e) => {
        if (legend.contains(e.target) || zoom.contains(e.target)) return;
        drag = { x: e.clientX, y: e.clientY };
        e.preventDefault();
    });
    window.addEventListener('mouseup', () => { drag = null; });
    frame.addEventListener('mousemove', (e) => {
        if (!drag) return;
        v.x += e.clientX - drag.x;
        v.y += e.clientY - drag.y;
        drag = { x: e.clientX, y: e.clientY };
        apply();
    });
    const zoomAt = (mx, my, f) => {
        const prev = v.s;
        v.s *= f; apply();
        v.x = mx - (mx - v.x) * (v.s / prev);
        v.y = my - (my - v.y) * (v.s / prev);
        apply();
    };
    frame.addEventListener('wheel', (e) => {
        if (legend.contains(e.target)) return;   // the legend scrolls itself
        e.preventDefault();
        const r = frame.getBoundingClientRect();
        zoomAt(e.clientX - r.left, e.clientY - r.top, e.deltaY < 0 ? 1.2 : 1 / 1.2);
    }, { passive: false });
    zin.addEventListener('click', () => zoomAt(frame.clientWidth / 2, frame.clientHeight / 2, 1.3));
    zout.addEventListener('click', () => zoomAt(frame.clientWidth / 2, frame.clientHeight / 2, 1 / 1.3));
    zfit.addEventListener('click', () => { v.s = 0; v.x = 0; v.y = 0; apply(); });

    setTimeout(() => {
        const focus = list.find((m) => m.mine && m.hq) || list.find((m) => m.mine);
        /* 0 on both means "as far out as allowed", which apply() clamps up to
           the cover scale - so the opening view always fills the frame. A gang
           with ground on the map opens centred on it instead. */
        v.s = 0; v.x = 0; v.y = 0;
        apply();
        if (focus) {
            const [fx, fy] = worldToMap(Number(focus.x) || 0, Number(focus.y) || 0);
            flyTo(fx, fy, Math.max(v.s, 1.9));
        }
    }, 0);
}

function pageMembers(view) {
    const p = DATA.panel;
    pageHead(view, 'Members', (p.members || []).length + (p.maxMembers > 0 ? ' / ' + p.maxMembers : '') + ' on the roster.');

    /* THE ROSTER. A flat table said nothing about who is actually carrying the
       gang; a share bar against the top contributor does it at a glance. */
    const b = block('Roster');
    const roster = (p.members || []);
    const hex = myColour(p);
    const topPts = roster.reduce((n, m) => Math.max(n, Number(m.points) || 0), 0);
    const total = roster.reduce((n, m) => n + (Number(m.points) || 0), 0);

    roster.forEach((m) => {
        const row = el('mem' + (m.isLeader ? ' boss' : ''));
        if (m.isLeader) row.style.borderLeftColor = hex;

        const head = el('mem-head');
        const who = el('mem-who');
        who.appendChild(el('mem-name', m.name, 'span'));
        if (m.isLeader) who.appendChild(el('mem-tag', 'Boss', 'span'));
        head.appendChild(who);
        head.appendChild(el('mem-rank', m.rankLabel || '?'));
        row.appendChild(head);

        const bar = el('prog-bar thin');
        const fill = el('prog-fill');
        fill.style.width = (topPts > 0 ? Math.max(0, ((Number(m.points) || 0) / topPts) * 100) : 0) + '%';
        fill.style.background = m.isLeader ? hex : 'rgba(239, 230, 213, 0.32)';
        bar.appendChild(fill);
        row.appendChild(bar);

        const foot = el('mem-foot');
        const share = total > 0 ? Math.round(((Number(m.points) || 0) / total) * 100) : 0;
        foot.appendChild(el('mem-pts', fmt(m.points) + ' contributed'
            + (total > 0 ? '  ·  ' + share + '% of the gang' : ''), 'span'));

        const actions = el('btnrow');
        actions.style.marginTop = '0';
        if (!m.isLeader && m.rank < p.myRank) {
            if (p.perms.promote && (m.rank + 1) < p.myRank) {
                actions.appendChild(btn('Promote', 'sm', () => act('promote', { charid: m.charid, rank: m.rank + 1 })));
            }
            if (p.perms.promote && m.rank > 1) {
                actions.appendChild(btn('Demote', 'sm', () => act('promote', { charid: m.charid, rank: m.rank - 1 })));
            }
            if (p.perms.kick) {
                actions.appendChild(btn('Remove', 'sm red', () => act('kick', { charid: m.charid })));
            }
        }
        foot.appendChild(actions);
        row.appendChild(foot);
        b.appendChild(row);
    });
    if (!roster.length) b.appendChild(el('empty', 'Nobody yet.'));

    /* WHAT A NEW RIDER COSTS. Taking somebody on spends blood money out of the
       ledger - charged when they accept, not when the invite is sent. */
    const cap = Number(p.maxMembers) || 0;
    const have = (p.members || []).length;
    const bm = DATA.blood;
    const cost = bm ? (Number(bm.perMember) || 0) : 0;
    const bal = bm ? (Number(bm.balance) || 0) : 0;
    const full = cap > 0 && have >= cap;
    const broke = cost > 0 && bal < cost;

    if (cap > 0 || cost > 0) {
        b.appendChild(el('note',
            (cap > 0 ? have + ' of ' + cap + ' places filled.  ' : '')
            + (cost > 0
                ? ('Taking on a new rider costs ' + cost + ' blood money, paid out of the ledger '
                    + 'when they accept. The ledger holds ' + fmt(bal) + '.')
                : '')
            + (full ? '  THE ROSTER IS FULL - level the gang for more places.' : '')));
    }
    view.appendChild(b);

    const bar = el('btnrow');
    if (p.perms.invite) {
        /* the price goes ON the button - it is the thing being spent */
        const label = 'Invite nearest player' + (cost > 0 ? '  (' + cost + ')' : '');
        bar.appendChild(btn(label, (full || broke) ? 'disabled' : null,
            (full || broke) ? null : () => {
                if (cost <= 0) return act('invite');
                confirmAsk('Take on a new rider?',
                    'If they accept, ' + cost + ' blood money comes out of the ledger. It holds ' + fmt(bal) + '.',
                    'Send the invite', () => act('invite'));
            }));
        if (broke) bar.appendChild(el('dim', 'The ledger is short - needs ' + cost + '.'));
    }
    bar.appendChild(btn('Leave gang', 'red', () => act('leave')));
    view.appendChild(bar);

    /* BOSS RANK EDITOR: design the gang's own ladder - names + what each rank
       may do. Server re-checks that only the leader can touch this. */
    if (p.isLeader) {
        const PERMS = [
            ['invite', 'Invite'], ['kick', 'Kick'], ['promote', 'Promote'],
            /* 'bank' is THE LEDGER: spending the gang's blood money. The key
               stays `bank` because it is what the DB column and every saved
               rank already use; only the label says Ledger. */
            ['war', 'Wars'], ['bank', 'Ledger'], ['territory', 'Territory'],
        ];
        const re = block('Ranks - design your ladder');
        const rows = (p.ranks || []).map((r, idx) => {
            const i = idx + 1;
            const isTop = i === (p.ranks || []).length;

            const nameI = document.createElement('input');
            nameI.className = 'rank-name';
            nameI.maxLength = 20;
            nameI.value = r.label || ('Rank ' + i);

            const permHost = el('permrow');
            const boxes = {};
            PERMS.forEach(([key, label]) => {
                const wrap = el('pchk' + ((isTop || r[key]) ? ' on' : ''), label, 'span');
                if (!isTop) {
                    boxes[key] = r[key] === true;
                    wrap.addEventListener('click', () => {
                        boxes[key] = !boxes[key];
                        wrap.classList.toggle('on', boxes[key]);
                    });
                }
                permHost.appendChild(wrap);
            });

            const actions = el('btnrow');
            actions.style.marginTop = '0';
            actions.appendChild(btn('Save', 'sm', () => {
                const perms = {};
                PERMS.forEach(([key]) => { perms[key] = boxes[key] === true; });
                act('rank:save', { index: i, label: nameI.value, perms: perms });
            }));
            if (!isTop && (p.ranks || []).length > 2) {
                actions.appendChild(btn('Remove', 'sm red', () => act('rank:remove', { index: i })));
            }

            return ['#' + i + (isTop ? ' (boss)' : ''), nameI, isTop ? { t: 'everything - the boss seat', cls: 'dim' } : permHost, actions];
        });
        re.appendChild(table(['Seat', 'Name', 'Permissions', ''], rows));
        const addBar = el('btnrow');
        addBar.appendChild(btn('+ New rank', null, () => act('rank:add', { label: 'New Rank' })));
        re.appendChild(addBar);
        re.appendChild(el('note', 'New ranks slot in just under the boss seat with no permissions - name them and tick what they may do. Removing a rank drops its members one step.'));
        view.appendChild(re);
    }
}

function pageTerritory(view) {
    const p = DATA.panel;
    pageHead(view, 'Territory',
        'Influence grows in steps with points. Currently ' + Math.floor(p.radius) + 'm'
        + (p.nextStepIn ? (' - ' + fmt(p.nextStepIn) + ' points to ' + Math.floor(p.nextStepRadius || 0) + 'm.') : ' (maxed).'));

    view.appendChild(statCards([
        [(p.territories || []).length, 'Territories held'],
        [Math.floor(p.radius) + 'm', 'Current influence'],
        [Math.floor((CFG && CFG.maxRadius) || 140) + 'm', 'Maximum influence'],
        [fmt(p.points), 'Gang points'],
    ]));

    const held = block('Your ground');
    const rows = (p.territories || []).map((t) => [t.name, { t: 'Held', cls: 'pos' }]);
    held.appendChild(rows.length ? table(['Territory', 'Status'], rows) : el('empty', 'Your gang holds no ground yet.'));
    view.appendChild(held);

    /* THE SIEGE BOARD: pick the ground you mean to take. Starting a claim
       alerts every gang and starts a public countdown - the target list and
       every block reason come from the server. */
    const cl = (CFG && CFG.claims) || {};
    if (cl.enabled) {
        const cb = block('Stake a claim');
        const targets = DATA.claimTargets || [];
        const trows = targets.map((t) => {
            const holder = t.mine ? 'yours'
                : (t.held ? ('held by ' + (t.holderTag || '?')) : 'unclaimed');
            let action;
            const why = {
                yours: 'Your ground',
                contested: 'Already contested',
                cooldown: 'Contested too recently',
                nodefender: 'No defenders online',
            };
            if (t.blocked) {
                action = { t: why[t.blocked] || '\u2014', cls: 'dim' };
            } else if (p.perms && p.perms.territory) {
                action = btn(t.held ? 'Take it' : 'Claim it', 'sm red', () => act('claim', { territoryId: t.id }));
            } else {
                action = { t: 'Rank cannot claim', cls: 'dim' };
            }
            return [t.name, { t: holder, cls: t.mine ? 'pos' : 'dim' }, action];
        });
        cb.appendChild(trows.length ? table(['Ground', 'Status', ''], trows) : el('empty', 'No ground to contest.'));
        cb.appendChild(el('note',
            'A claim runs ' + (cl.durationMinutes || 20) + ' minutes and every gang is told the moment it starts. '
            + 'You get ' + (cl.travelGraceMinutes || 5) + ' minutes to reach the ground, then your crew must HOLD it - '
            + 'if every claimer is dead or gone the claim collapses. ' + (cl.cooldownMinutes || 15) + ' minute cooldown per fort afterwards.'));
        view.appendChild(cb);
    }

    const ladder = block('Influence ladder');
    ladder.appendChild(table(['Points', 'Influence radius'],
        ((CFG && CFG.radiusCurve) || []).map((s) => {
            const reached = (p.points || 0) >= (s.points || 0);
            return [{ t: fmt(s.points) + ' pts', cls: reached ? 'pos' : 'dim' }, Math.floor(s.radius) + 'm'];
        })));
    view.appendChild(ladder);
}

/* RAIDS - the PvE page. Ride on a fort, fight the locals off it in waves, put
   the boss down, crack the strongbox. Always available: no rivals required. */
function pageRaids(view) {
    const p = DATA.panel;
    const unlocked = p.perkFlags && p.perkFlags.fort_raid;
    pageHead(view, 'Fort Raids',
        unlocked ? 'Ride out, clear the locals off a fort, and take the strongbox. Call it standing at the fort.'
                 : 'Locked - your gang unlocks fort raids at Ring (750 points).');

    const b = block('The forts');
    const why = { yours: 'Your raid is running', busy: 'Another crew is on it',
                  cooldown: 'Quiet again soon', gangcooldown: 'Your crew rode recently' };
    const rows = (DATA.forts || []).map((f) => {
        let action;
        if (!unlocked) action = { t: 'Locked', cls: 'dim' };
        else if (f.blocked) action = { t: why[f.blocked] || '\u2014', cls: 'dim' };
        else action = btn('Call the raid', 'sm red', () => act('fortraid', { index: f.index }));
        return [f.label, { t: Math.round(f.x) + ', ' + Math.round(f.y), cls: 'dim' }, action];
    });
    b.appendChild(rows.length ? table(['Fort', 'Where', ''], rows) : el('empty', 'No forts configured.'));
    view.appendChild(b);

    const w = block('How it goes');
    const waves = (CFG && CFG.fortWaves) || 3;
    w.appendChild(el('note',
        waves + ' waves of locals, then whoever runs the place, then the strongbox. '
        + 'Your crew has to be ON the ground - wander off and the raid falls apart. '
        + 'Everyone in the gang sees the fight; only the caller brings the locals in.'));
    view.appendChild(w);
}

function pageWars(view) {
    const p = DATA.panel;
    const w = (CFG && CFG.wars) || {};
    const s = p.stats || {};
    const hex = myColour(p);
    const wars = p.wars || [];

    pageHead(view, 'Wars', wars.length
        ? (wars.length === 1 ? 'One war running.' : wars.length + ' wars running.')
        : 'Nothing running. Pick a fight below.');

    view.appendChild(statCards([
        [String(wars.length), 'Running now'],
        [fmt(s.warsWon), 'Won', 'pos'],
        [fmt(s.warsLost), 'Lost', 'neg'],
        [fmt(w.warWin || 0), 'Points for a win'],
    ]));

    /* RUNNING WARS.
       Each one is a scoreline with a tug-of-war bar showing your share of
       the kills, so who is winning reads before either number does. */
    const active = block('Running');
    wars.forEach((x) => {
        const mineN = Number(x.mine) || 0;
        const theirs = Number(x.theirs) || 0;
        const total = mineN + theirs;
        const lead = mineN - theirs;

        const row = el('war' + (lead > 0 ? ' me' : ''));
        row.style.borderLeftColor = lead > 0 ? hex
            : (lead < 0 ? 'rgba(180, 83, 75, 0.75)' : 'rgba(239, 230, 213, 0.22)');

        const head = el('war-head');
        const who = el('war-who');
        who.appendChild(el('war-label', x.enemy, 'span'));
        head.appendChild(who);
        const clock = el('war-score');
        clock.appendChild(el('war-sv', ago(x.endsIn), 'span'));
        clock.appendChild(el('war-sl', 'left', 'span'));
        head.appendChild(clock);
        row.appendChild(head);

        const line = el('war-line');
        const mySide = el('war-side');
        mySide.appendChild(el('war-n', fmt(mineN), 'span'));
        mySide.appendChild(el('war-sl', 'yours', 'span'));
        const theirSide = el('war-side right');
        theirSide.appendChild(el('war-sl', 'theirs', 'span'));
        theirSide.appendChild(el('war-n', fmt(theirs), 'span'));
        line.appendChild(mySide);
        line.appendChild(theirSide);
        row.appendChild(line);

        const bar = el('war-bar');
        const fill = el('war-fill');
        /* no kills either way opens level at the halfway mark rather than empty */
        fill.style.width = (total > 0 ? (mineN / total) * 100 : 50) + '%';
        fill.style.background = hex;
        bar.appendChild(fill);
        row.appendChild(bar);

        row.appendChild(el('war-state' + (lead > 0 ? ' pos' : (lead < 0 ? ' neg' : '')),
            lead > 0 ? ('Ahead by ' + fmt(lead))
                : (lead < 0 ? ('Behind by ' + fmt(-lead)) : 'Level')));
        active.appendChild(row);
    });
    if (!wars.length) active.appendChild(el('empty', 'No war running.'));
    active.appendChild(el('note',
        'A kill on one of their riders scores ' + (w.pointsPerKill || 5)
        + '. Whoever leads when the clock runs out takes ' + fmt(w.warWin || 150) + ' gang points.'));
    view.appendChild(active);

    /* WHO YOU CAN FIGHT */
    const canDeclare = !!(p.perms && p.perms.war && w.enabled);
    const wBlood = (DATA.blood && Number(DATA.blood.perWar)) || 0;
    const wBal = (DATA.blood && Number(DATA.blood.balance)) || 0;
    const wBroke = wBlood > 0 && wBal < wBlood;

    const rb = block('Who you can fight');
    (p.rivals || []).forEach((r) => {
        const row = el('rival');
        const head = el('mem-head');
        const who = el('mem-who');
        if (r.short && r.short !== '') who.appendChild(el('rival-tag', r.short, 'span'));
        who.appendChild(el('mem-name', r.name, 'span'));
        head.appendChild(who);
        head.appendChild(el('mem-rank', fmt(r.points) + ' pts'));
        row.appendChild(head);

        if (canDeclare) {
            const foot = el('mem-foot');
            /* war costs CASH and BLOOD MONEY. Both on the button: the blood
               money is the half a crew is likely to be short of. */
            foot.appendChild(el('mem-pts',
                '$' + fmt(w.declareCost || 0) + (wBlood > 0 ? '  ·  ' + wBlood + ' blood money' : ''), 'span'));
            const bar = el('btnrow');
            bar.style.marginTop = '0';
            bar.appendChild(btn('Declare war', wBroke ? 'sm red disabled' : 'sm red',
                wBroke ? null : () => confirmAsk('Declare war on ' + (r.name || 'them') + '?',
                    'This costs $' + fmt(w.declareCost || 0) + ' cash and ' + wBlood + ' blood money, and every '
                    + 'gang will know. There is no calling it off.',
                    'Declare war', () => act('declarewar', { gangid: r.id }))));
            foot.appendChild(bar);
            row.appendChild(foot);
        }
        rb.appendChild(row);
    });
    if (!(p.rivals || []).length) rb.appendChild(el('empty', 'No gangs you can war.'));
    if (canDeclare && wBroke) {
        rb.appendChild(el('note', 'The ledger is short of the ' + wBlood + ' blood money a declaration costs. It holds ' + fmt(wBal) + '.'));
    } else if (!canDeclare) {
        rb.appendChild(el('note', w.enabled === false
            ? 'Wars are switched off on this server.'
            : 'Your rank cannot declare a war.'));
    }
    view.appendChild(rb);

    view.appendChild(el('note', 'Who reps what faction is not written down anywhere - a declaration refused as "same faction" is how you find out.'));
}

function pageFaction(view) {
    const p = DATA.panel;
    const standings = DATA.factions || [];
    let mine = null, myIdx = -1;
    standings.forEach((f, i) => { if (f.key === p.faction) { mine = f; myIdx = i; } });

    /* the gap to the faction directly above and below - the only two numbers
       that actually change what a crew does this week */
    let gap = '';
    if (mine) {
        const above = myIdx > 0 ? standings[myIdx - 1] : null;
        const below = myIdx >= 0 && myIdx < standings.length - 1 ? standings[myIdx + 1] : null;
        if (above) gap = fmt(Math.max(0, above.season - mine.season)) + ' behind ' + above.label;
        else if (below) gap = fmt(Math.max(0, mine.season - below.season)) + ' clear of ' + below.label;
    }
    pageHead(view, p.factionLabel || 'Faction',
        mine ? ('Placed ' + mine.place + ' of ' + standings.length + ' in the faction war'
                + (gap ? ' - ' + gap + '.' : '.'))
             : 'Your gang represents no faction.');

    /* YOUR COLOURS - identity first: the blurb and the bonus, the one thing
       picking a faction actually buys. */
    if (mine || p.factionLabel) {
        const hex = fcolor(p.faction);
        const ban = el('fac-banner');
        ban.style.borderLeftColor = hex;
        ban.style.background = 'linear-gradient(90deg, ' + hex + '1f 0%, rgba(0,0,0,0) 60%)';
        ban.appendChild(el('fac-eyebrow', 'Your colours'));
        const nm = el('fac-name', p.factionLabel || '?');
        nm.style.color = hex;
        ban.appendChild(nm);
        const blurb = mine && mine.blurb;
        if (blurb) ban.appendChild(el('fac-blurb', '"' + blurb + '"'));
        if (p.factionBonus) {
            const edge = el('fac-edge');
            edge.appendChild(el('fac-edge-l', 'Your edge', 'span'));
            edge.appendChild(el('fac-edge-v', p.factionBonus, 'span'));
            ban.appendChild(edge);
        }
        view.appendChild(ban);
    }

    /* THE WAR - a bar per faction against the leader's score, so the shape of
       the race reads before any of the numbers do */
    const top = standings.reduce((n, f) => Math.max(n, Number(f.season) || 0), 0);
    const war = block('The faction war');
    standings.forEach((f) => {
        const isMine = f.key === p.faction;
        const hex = fcolor(f.key);
        const row = el('war' + (isMine ? ' me' : ''));
        row.style.borderLeftColor = hex;

        const head = el('war-head');
        const left = el('war-who');
        left.appendChild(el('war-place', '#' + f.place, 'span'));
        const lbl = el('war-label', f.label, 'span');
        if (isMine) lbl.style.color = hex;
        left.appendChild(lbl);
        if (isMine) left.appendChild(el('war-you', 'Yours', 'span'));
        head.appendChild(left);
        const score = el('war-score');
        score.appendChild(el('war-sv', fmt(f.season), 'span'));
        score.appendChild(el('war-sl', 'war score', 'span'));
        head.appendChild(score);
        row.appendChild(head);

        const bar = el('war-bar');
        const fill = el('war-fill');
        fill.style.width = (top > 0 ? Math.max(1.5, ((Number(f.season) || 0) / top) * 100) : 0) + '%';
        fill.style.background = hex;
        bar.appendChild(fill);
        row.appendChild(bar);

        const stats = el('lad-stats');
        [[fmt(f.livePoints), 'live points'], [fmt(f.gangs), 'gangs'],
         [fmt(f.territories), 'plots held']].forEach(([v, l]) => {
            const s = el('lad-s');
            s.appendChild(el('lad-sv', v, 'span'));
            s.appendChild(el('lad-sl', l, 'span'));
            stats.appendChild(s);
        });
        const cfgF = ((CFG && CFG.factions) || []).find((x) => x.key === f.key);
        if (cfgF && cfgF.bonus) {
            const s = el('lad-s');
            s.appendChild(el('lad-sv', cfgF.bonus, 'span'));
            s.appendChild(el('lad-sl', 'edge', 'span'));
            stats.appendChild(s);
        }
        row.appendChild(stats);
        war.appendChild(row);
    });
    if (!standings.length) war.appendChild(el('empty', 'No standings yet.'));
    view.appendChild(war);

    view.appendChild(el('note',
        'War score is every point any gang of that faction has ever earned - it accumulates and never decays. '
        + 'Live points is what its gangs hold right now, which drops when one decays or disbands. '
        + 'A gang represents one faction for life, and who reps what is not written down anywhere.'));
}

function pagePerks(view) {
    const p = DATA.panel;
    pageHead(view, 'Level ' + (p.level || 1) + ' - ' + (p.levelLabel || ''),
        p.levelNextAt ? (fmt(Math.max(0, p.levelNextAt - p.points)) + ' more points to reach ' + (p.levelNextLabel || '')) : 'Maximum level reached.');

    view.appendChild(statCards([
        ['Lv ' + (p.level || 1), p.levelLabel || 'Level'],
        [fmt(p.points), 'Points'],
        [p.hasTable ? 'Placed' : 'Missing', 'Gang table'],
        [(DATA.dens || []).length, 'Dens'],
    ]));

    /* THE LADDER.
       Each tier shows only what is NEW at it, as chips, with the
       parenthetical explanation on hover. */
    const ladder = block('Level ladder');
    const levels = (CFG && CFG.levels) || [];
    levels.forEach((tier, i) => {
        const reached = (p.points || 0) >= tier.points;
        const isCur = (p.level || 1) === tier.level;
        const prev = i > 0 ? ((levels[i - 1].perks || {}).unlocks || []) : [];
        const fresh = (tier.perks.unlocks || []).filter((u) => prev.indexOf(u) < 0);

        const row = el('lad' + (isCur ? ' now' : (reached ? ' done' : ' locked')));

        const head = el('lad-head');
        const name = el('lad-name');
        name.appendChild(el('lad-n', tier.level, 'span'));
        name.appendChild(el('lad-l', tier.label, 'span'));
        if (isCur) name.appendChild(el('lad-you', 'You are here', 'span'));
        head.appendChild(name);
        head.appendChild(el('lad-req', tier.points === 0 ? 'From the start' : fmt(tier.points) + ' points'));
        row.appendChild(head);

        const cap = (CFG.maxMembers || 0) > 0 ? String(CFG.maxMembers + (tier.perks.members || 0)) : 'no cap';
        const stats = el('lad-stats');
        [[cap, 'members'], ['+' + (tier.perks.stashSlots || 0), 'stash slots'],
         [Math.floor(radiusAt(tier.points)) + 'm', 'influence'],
         ['x' + (tier.perks.pointsMult || 1).toFixed(2), 'point rate']].forEach(([v, l]) => {
            const s = el('lad-s');
            s.appendChild(el('lad-sv', v, 'span'));
            s.appendChild(el('lad-sl', l, 'span'));
            stats.appendChild(s);
        });
        row.appendChild(stats);

        const chips = el('lad-perks');
        if (!fresh.length) {
            chips.appendChild(el('lad-nil', 'Nothing new on the shelf'));
        } else {
            fresh.forEach((u) => {
                const full = (CFG.perkLabels && CFG.perkLabels[u]) || u;
                /* the labels read "Bulk Cooking (+1 product per batch)" - the
                   name goes on the chip, the explanation onto its tooltip */
                const cut = full.indexOf(' (');
                /* perkOwned, not perkFlags: reaching a level only puts a perk on
                   the shelf, it does not hand it over */
                const c = el('pchip' + ((p.perkOwned && p.perkOwned[u]) ? ' has' : ''),
                    cut > 0 ? full.slice(0, cut) : full);
                c.title = full;
                chips.appendChild(c);
            });
        }
        row.appendChild(chips);
        ladder.appendChild(row);
    });
    ladder.appendChild(el('note',
        'Each level only puts its new perks on the shelf. Buy them with blood money below - reaching the level does not hand them over. Green means your crew already holds it.'));
    view.appendChild(ladder);

    /* the gang's ACTUAL ladder (boss-designed) - what each rank may do */
    const PERM_NAMES = [['invite', 'invite'], ['kick', 'kick'], ['promote', 'promote'],
                        ['war', 'wars'], ['bank', 'the ledger'], ['territory', 'territory']];
    const ranks = block('Your ladder');
    ranks.appendChild(table(['Rank', 'May do'],
        (p.ranks || []).map((r, i) => {
            const isTop = (i + 1) === (p.ranks || []).length;
            const grants = isTop ? 'everything - the boss seat'
                : (PERM_NAMES.filter(([k]) => r[k] === true).map(([, n]) => n).join(', ') || 'run with the gang');
            return [
                { t: r.label, cls: (i + 1) === p.myRank ? 'pos' : undefined },
                { t: grants, cls: 'dim' },
            ];
        })));
    view.appendChild(ranks);

    /* HQ actions: table, stashes, deliveries, dens */
    const hq = block('The hideout');
    const bar = el('btnrow');
    if (p.perms && p.perms.territory) {
        bar.appendChild(p.hasTable
            ? btn('Pick up gang table', 'red', () => act('pickuptable'))
            : btn('Place gang table', null, () => act('placetable')));
    }
    if (p.hasTable) {
        ((CFG && CFG.stashes) || []).forEach((s) => {
            /* The Den Inventory is not a table stash: it hangs off a den, not the
               hideout, and it is opened by standing at the chest in the shack. */
            if (s.den) return;
            const locked = s.unlock && !(p.perkFlags && p.perkFlags[s.unlock]);
            const rankLow = (p.myRank || 1) < (s.minRank || 1);
            const b2 = btn(s.label + (locked ? ' (locked)' : (rankLow ? ' (rank)' : '')),
                (locked || rankLow) ? 'disabled' : null,
                (locked || rankLow) ? null : () => act('stash', { key: s.key }));
            bar.appendChild(b2);
        });
        /* delivery runs START AT THE DEN (G there), not here - the panel
           only opens at the table, so a button would be unreachable anyway */
    }
    hq.appendChild(bar);
    view.appendChild(hq);

    /* ------------------------------------------------------------- the ledger
       BLOOD MONEY. Deposited at the table, spent from the table - so it lives
       on this page and nowhere else. DATA.blood comes from getBlood. */
    if (CFG && CFG.blood && CFG.blood.enabled && DATA.blood) {
        const bm = DATA.blood;
        const led = block('The ledger');
        /* "2 / 5 places bought" told you nothing about what the gang can field,
           which is the number you actually decide on. Show the ROSTER. */
        led.appendChild(statCards([
            [fmt(bm.balance || 0), 'Blood money banked'],
            [fmt(bm.carrying || 0), 'On you now'],
            [bm.cap ? ((bm.members || 0) + ' / ' + bm.cap) : (bm.members || 0), 'Riders on the roster'],
            [bm.perMember, 'Cost of a new rider'],
        ]));

        const lbar = el('btnrow');
        if ((bm.carrying || 0) > 0) {
            lbar.appendChild(btn('Bank all ' + fmt(bm.carrying), null, () => act('blood:deposit')));
        } else {
            lbar.appendChild(el('dim', 'Nothing on you to bank.'));
        }
        /* No "buy a slot" button: taking on a rider is what costs blood money,
           charged on the Members page when the invite is accepted. Raising the
           roster ceiling past the level allowance is what levelling is for. */
        led.appendChild(lbar);

        /* perks the gang's LEVEL has put on the shelf and it has not bought.
           Reaching the level is permission to buy, not the perk itself. */
        if (bm.canPerk && (bm.buyable || []).length) {
            const rows = bm.buyable.map((u) => [
                u.label,
                { t: bm.perPerk + ' blood money', cls: (bm.balance || 0) >= bm.perPerk ? 'pos' : 'neg' },
                (bm.balance || 0) >= bm.perPerk
                    ? btn('Unlock', 'sm', () => confirmAsk('Unlock ' + u.label + '?',
                        'That costs ' + bm.perPerk + ' blood money. The ledger holds ' + fmt(bm.balance || 0) + '.',
                        'Unlock it', () => act('blood:perk', { flag: u.flag })))
                    : el('dim', 'short'),
            ]);
            led.appendChild(table(['Upgrade', 'Cost', ''], rows));
        }

        /* No recent-transactions table. It is still written to
           gang_blood_log server-side, so an admin can audit where a
           crew's money went; the balance is the number that matters here. */

        led.appendChild(el('note',
            'Blood money is earned by gang members only - selling contraband, working robberies, running gang '
            + 'missions. Carry it and it can be taken off your body; bank it here and it is the crew\'s.'));
        led.appendChild(el('note',
            'A NEW RIDER costs ' + bm.perMember + ', taken from the ledger the moment they accept the '
            + 'invite - so the crew pays, not them. An UPGRADE costs ' + bm.perPerk + ' - your level puts a perk on '
            + 'the shelf, this is what takes it off. Colours cost ' + (bm.perColour || 0) + ', a WAR ' + (bm.perWar || 0) + '.'));
        view.appendChild(led);
    }

    /* Dens and the powder bench live on the den's own panel (MODE 'den'), the
       only place either can be acted on. */
}

function pageCreate(view) {
    pageHead(view, 'Found a Gang',
        'Choose a faction to represent - this is permanent. Charter fee: $' + fmt((CFG && CFG.createPrice) || 0) + '.');

    const fc = el('fcards');
    ((CFG && CFG.factions) || []).forEach((f) => {
        const c = el('fcard' + (creating.faction === f.key ? ' on' : ''));
        c.style.setProperty('--fc', fcolor(f.key));
        c.appendChild(el('fname', f.label));
        c.appendChild(el('fblurb', f.blurb || ''));
        c.appendChild(el('fbonus', f.bonus || ''));
        c.addEventListener('click', () => { creating.faction = f.key; render(); });
        fc.appendChild(c);
    });
    view.appendChild(fc);

    const form = block('The charter');
    const f1 = el('field');
    f1.appendChild(el(null, 'Gang name (e.g. Valentine Predators)', 'label'));
    const nameI = document.createElement('input');
    nameI.id = 'createName';
    nameI.maxLength = 24;
    nameI.value = creating.name || '';
    f1.appendChild(nameI);
    form.appendChild(f1);

    const f2 = el('field');
    f2.appendChild(el(null, 'Tag, ' + ((CFG && CFG.shortMin) || 2) + '-' + ((CFG && CFG.shortMax) || 5) + ' letters (e.g. VPR)', 'label'));
    const shortI = document.createElement('input');
    shortI.id = 'createShort';
    shortI.maxLength = (CFG && CFG.shortMax) || 5;
    shortI.style.width = '8vw';
    shortI.style.textTransform = 'uppercase';
    shortI.value = creating.short || '';
    f2.appendChild(shortI);
    form.appendChild(f2);

    const bar = el('btnrow');
    bar.appendChild(btn('Found the gang ($' + fmt((CFG && CFG.createPrice) || 0) + ')', 'red', () => {
        creating.name = (nameI.value || '').trim();
        creating.short = (shortI.value || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
        if (!creating.faction || !creating.name) return;
        act('create', { name: creating.name, short: creating.short, faction: creating.faction });
    }));
    form.appendChild(bar);
    form.appendChild(el('note', 'A gang is founded at its table - you are standing at yours now.'));
    view.appendChild(form);

    /* typing must not hit game binds; inputs keep focus naturally since the
       whole page has NUI focus while open */
    nameI.addEventListener('input', () => { creating.name = nameI.value; });
    shortI.addEventListener('input', () => { creating.short = shortI.value; });
}

/* =================================================================== the den
   A SECOND PANEL sharing this page's chrome and stylesheet. The gang panel
   describes a GANG - roster, wars, faction, points - and opens at the gang
   table. This describes the SHACK you are stood in, and only opens inside one.
   Same look on purpose; different subject, different tabs, different actions.

   Every button here posts to an action that already existed server-side and
   re-checks its own gates, so nothing is granted by what this draws. ==== */
/* Claims and Raids are the SAME pages the gang panel draws - the den payload
   carries the gang bundle alongside it precisely so they can render here. */
const DEN_TABS = [
    ['den',      'The Den'],
    ['crafting', 'Crafting'],
    ['missions', 'Missions'],
    ['dens',     'Rival Dens'],
    ['claims',   'Claims'],
    ['raids',    'Raids'],
];
let DEN = null;
let denTab = 'den';

const mmss = (s) => {
    s = Math.max(0, Math.floor(Number(s) || 0));
    return String(Math.floor(s / 60)).padStart(2, '0') + ':' + String(s % 60).padStart(2, '0');
};

function renderDenChrome() {
    const tabsHost = $('#tabs');
    tabsHost.textContent = '';
    DEN_TABS.forEach(([id, label]) => {
        const t = el('tab' + (denTab === id ? ' on' : ''), label);
        t.addEventListener('click', () => { denTab = id; renderDen(); });
        tabsHost.appendChild(t);
    });
    $('#brandTitle').textContent = (DEN.label || 'The Den').toUpperCase();
    $('#brandSub').textContent = 'Drug operation';

    const ident = $('#ident');
    ident.textContent = '';
    ident.appendChild(el('chip tag', DEN.gangTag || '?'));
    const shelf = el('chip');
    shelf.innerHTML = '<b>' + (DEN.shelf || 0) + '</b> / ' + (DEN.maxStored || 3) + ' ON THE SHELF';
    ident.appendChild(shelf);
    if (DEN.cook && DEN.cook.cooking) ident.appendChild(el('chip act-HIGH', 'COOKING'));
    if (DEN.beingRaided) ident.appendChild(el('chip act-HIGH', 'UNDER RAID'));
}

function denPageOverview(view) {
    const c = DEN.cook || {};
    const b = block('The den');
    const cards = [
        [DEN.shelf || 0, 'On the shelf'],
        [(DEN.raid && (DEN.raid.targets || []).length) || 0, 'Rival dens showing'],
        [(DEN.bench && DEN.bench.unlocked) ? 'open' : 'locked', 'The bench'],
    ];
    /* the still only earns a card while cooking is switched on at all */
    if (c.enabled) {
        cards.push([c.cooking ? mmss(c.leftSecs) : (c.cooldown > 0 ? mmss(c.cooldown) : 'ready'),
            c.cooking ? 'Batch left' : 'The still']);
    }
    b.appendChild(statCards(cards));

    /* No inventory button: the den's inventory is a PLACE in the room, opened
       by standing at it. Putting it on a menu would mean reaching your stores
       from anywhere in the shack, which is not what a chest is. */
    const bar = el('btnrow');
    if ((DEN.shelf || 0) > 0 && DEN.rank >= (DEN.collectRank || 1)) {
        bar.appendChild(btn('Collect the shelf', null, () => act('den:collect', { tid: DEN.id })));
    }
    if (c.enabled && !c.cooking && c.cooldown <= 0 && DEN.rank >= (c.minRank || 1)) {
        bar.appendChild(btn('Put a batch on', null, () => act('den:cook', { tid: DEN.id })));
    }
    if (bar.childNodes.length) b.appendChild(bar);

    b.appendChild(el('note',
        'Two things happen here: you start a run, or you work the bench. Everything the bench makes and '
        + 'everything a run brings home goes in the den inventory, over by the wall.'));
    if (c.cooking) {
        b.appendChild(el('note',
            'The still is running and this den is HOT - every gang can see the circle until the batch is done.'));
    }
    view.appendChild(b);
}

function denPageCrafting(view) {
    const b = DEN.bench || {};
    const blk = block('The powder bench');
    if (!b.enabled) {
        blk.appendChild(el('empty', 'The bench is closed.'));
    } else if (!b.unlocked) {
        blk.appendChild(el('empty', 'Locked - your crew needs ' + (b.unlockLabel || 'the perk') + '.'));
    } else if (DEN.rank < (b.minRank || 1)) {
        blk.appendChild(el('empty', 'You do not have the rank to work this bench.'));
    } else {
        /* A batch in progress takes the whole bench: its own row counts down and
           every other row goes quiet. One job per den - it is a workbench in a
           room, not a queue. */
        const job = b.job;
        const rows = (b.recipes || []).map((r) => {
            const mine = job && job.index === r.index;
            let last;
            if (mine) {
                last = el('pos', 'IN PROGRESS  ' + mmss(job.leftSecs));
            } else if (r.broken) {
                /* names an item that is not in the items table - no amount of
                   playing changes that, so say so rather than showing "short" */
                last = el('neg', 'BROKEN');
            } else if (job) {
                last = el('dim', '-');
            } else if (r.canMake) {
                last = btn('Make', 'sm', () => act('den:craft', { tid: DEN.id, index: r.index }));
            } else {
                last = el('dim', 'short');
            }
            return [
                mine ? { t: r.name, cls: 'pos' } : r.name,
                (r.give.count || 1) + 'x ' + r.give.item,
                {
                    t: mine ? ('on the bench - ' + (r.minutes || '?') + ' min batch')
                        : r.broken ? ('"' + r.broken + '" is not an item on this server')
                        : (r.costs || []).map((c) => c.have + '/' + c.count + ' ' + c.item).join('   '),
                    cls: mine ? 'dim' : (r.canMake ? 'pos' : 'neg'),
                },
                last,
            ];
        });
        blk.appendChild(rows.length
            ? table(['Item', 'Makes', job ? 'State' : 'Needs', ''], rows)
            : el('empty', 'Nothing on the bench.'));
        if (job) {
            blk.appendChild(el('note',
                job.count + 'x ' + job.name + ' is on the bench, ' + mmss(job.leftSecs) + ' to go. '
                + 'Nobody has to stand here - it lands in the den inventory when it is done.'));
        }
    }
    blk.appendChild(el('note',
        'Dynamite is off the gunsmith bench entirely - a den is the only place on the frontier it gets made. '
        + 'That makes it a gang product other people have to buy, trade or take.'));
    view.appendChild(blk);
}

function denPageMissions(view) {
    const r = DEN.run || {};
    const blk = block('The plant run');
    blk.appendChild(statCards([
        [r.minPosse || 5, 'Posse needed'],
        [r.posse || 0, 'Riding with you'],
        [Math.round((r.defendSeconds || 900) / 60) + 'm', 'Survive'],
    ]));
    const bar = el('btnrow');
    const ready = (r.posse || 0) >= (r.minPosse || 5) && (r.have || 0) > 0;
    if (ready) {
        bar.appendChild(btn('Take a package and ride', null, () => act('den:run')));
    } else {
        bar.appendChild(el('dim', (r.posse || 0) < (r.minPosse || 5)
            ? 'You need a posse of ' + (r.minPosse || 5) + '.'
            : 'No gang package. Craft one at the bench.'));
    }
    blk.appendChild(bar);
    blk.appendChild(el('note',
        'The target picks itself - whichever rival crew has the most riders online right now, so the fight is '
        + 'always real. Carry the package into their ground and plant it. They get a circle, not a pin, and '
        + Math.round((r.defendSeconds || 900) / 60) + ' minutes to sweep for it.'));
    blk.appendChild(el('note',
        'Hold the ground while the clock runs. Wipe your crew off it and the plant is theirs. Survive and it '
        + 'still is not paid - somebody has to get back to this den alive to collect.'));
    view.appendChild(blk);
}

function denPageRaids(view) {
    const r = DEN.raid || {};
    const blk = block('Rival dens');
    const rows = (r.targets || []).map((t) => [
        t.gang,
        { t: t.hot ? 'COOKING' : 'stocked', cls: t.hot ? 'neg' : 'dim' },
        { t: t.beingRaided ? 'already being hit' : 'open', cls: t.beingRaided ? 'dim' : 'pos' },
        (DEN.rank >= (r.minRank || 1) && !t.beingRaided)
            ? btn('Raid it', 'sm red', () => act('den:raid', { target: t.id }))
            : el('dim', '-'),
    ]);
    blk.appendChild(rows.length
        ? table(['Crew', 'State', 'Status', ''], rows)
        : el('empty', 'Nothing showing. A quiet den cannot be seen - wait for one to stock up or start cooking.'));
    blk.appendChild(el('note',
        'Raiding puts you at their door, not at yours. You have to hold their ground while they come to stop you.'));
    view.appendChild(blk);
}

function renderDen() {
    if (!DEN) return;
    renderDenChrome();
    const view = $('#view');
    view.textContent = '';
    if (denTab === 'crafting') return denPageCrafting(view);
    if (denTab === 'missions') return denPageMissions(view);
    if (denTab === 'dens')     return denPageRaids(view);
    /* the gang panel's own pages, drawn inside this one. They read DATA, which
       the den payload ships alongside DEN for exactly this. */
    if (denTab === 'claims' && DATA && DATA.panel) return pageTerritory(view);
    if (denTab === 'raids'  && DATA && DATA.panel) return pageRaids(view);
    return denPageOverview(view);
}

/* -------------------------------------------------------------- the product
   The gang's own drug: named and skinned here, grown through the farm, sold
   through the fence, and improved by running it onto somebody else's ground.
   Everything on this page is a request - the server owns every number. */
const ITEM_IMG = (key) => 'nui://vorp_inventory/html/img/items/' + key + '.png';

function drugIconTile(ic, selected, onPick) {
    const t = el('dicon' + (selected ? ' on' : ''));
    const img = document.createElement('img');
    img.src = ITEM_IMG(ic.image);
    img.alt = ic.label;
    t.appendChild(img);
    t.appendChild(el('dicon-l', ic.label));
    if (onPick) t.addEventListener('click', () => onPick(ic));
    else t.classList.add('static');
    return t;
}

function pageDrug(view) {
    const d = DATA.drug;
    if (!d) {
        pageHead(view, 'The Product', 'Nothing to run yet.');
        view.appendChild(el('empty', 'Your gang has no product operation.'));
        return;
    }

    /* LOCKED: the perk is bought on the Perks tab with blood money, like every
       other gang unlock. Nothing here works until it is. */
    if (!d.unlocked) {
        pageHead(view, 'The Product', 'Your crew has nothing of its own to sell.');
        const b = block('Locked');
        b.appendChild(el('note',
            'A crew cooks its own product only once it has bought ' + (d.perkLabel || 'the perk')
            + '. Buy it on the Perks tab out of the blood money ledger, then come back and name what you are making.'));
        view.appendChild(b);
        return;
    }

    /* THE CHARTER - name it and pick what it looks like. Bosses only. */
    if (!d.created) {
        pageHead(view, 'The Product', 'Name it, and decide what it looks like when it changes hands.');
        if (!d.canManage) {
            view.appendChild(el('empty', 'Your bosses have not settled on a product yet.'));
            return;
        }
        const form = block('Start production');

        const f1 = el('field');
        f1.appendChild(el(null, 'What it is called (' + d.nameMin + ' to ' + d.nameMax + ' characters)', 'label'));
        const nameI = document.createElement('input');
        nameI.maxLength = d.nameMax || 24;
        nameI.placeholder = 'Black Lotus';
        f1.appendChild(nameI);
        form.appendChild(f1);

        form.appendChild(el('block-title', 'How it is packaged'));
        const grid = el('dicons');
        let picked = (d.icons[0] || {}).key;
        d.icons.forEach((ic) => {
            const tile = drugIconTile(ic, ic.key === picked, (chosen) => {
                picked = chosen.key;
                Array.prototype.forEach.call(grid.children, (c, i) => {
                    c.classList.toggle('on', d.icons[i].key === picked);
                });
            });
            grid.appendChild(tile);
        });
        form.appendChild(grid);

        const row = el('btnrow');
        row.appendChild(btn('Start production', '', () => {
            const n = (nameI.value || '').trim();
            if (n.length < (d.nameMin || 3)) return;
            act('drug:create', { name: n, icon: picked });
        }));
        form.appendChild(row);
        form.appendChild(el('note',
            'The name and the label stay with the gang. Product already made keeps the name it was made under.'));
        view.appendChild(form);
        return;
    }

    /* RUNNING */
    pageHead(view, d.name, 'Drug level ' + d.level + ' - ' + (d.levelLabel || ''));

    view.appendChild(statCards([
        [fmt(d.points), 'Progress to spend'],
        [fmt(d.earned), 'Earned all time'],
        ['Lv ' + d.level, d.levelLabel || 'Level'],
        [fmt(d.ledger), 'Blood money'],
    ]));

    /* WHAT IT DOES - the resolved effect, tree included */
    const eff = block('What it does to a man');
    const e = d.effect || {};
    const erows = [];
    if (e.health > 0) erows.push(['Health', '+' + e.health + ' core']);
    if (e.stamina > 0) erows.push(['Stamina', '+' + e.stamina + ' core']);
    if (e.deadeye > 0) erows.push(['Dead Eye', '+' + e.deadeye + ' core']);
    if (e.healthGold > 0) erows.push(['Fortified health', 'yes']);
    if (e.staminaGold > 0) erows.push(['Fortified stamina', 'yes']);
    erows.push(['Holds for', e.seconds + ' seconds']);
    const m = d.mods || {};
    if (m.yield > 0) erows.push(['Extra off every plant', '+' + m.yield]);
    if (m.saleValue > 0) erows.push(['Street value', '+' + Math.round(m.saleValue * 100) + '%']);
    if (m.progression > 0) erows.push(['Word travels', '+' + Math.round(m.progression * 100) + '%']);
    if (m.seedDiscount > 0) erows.push(['Seed', '-' + Math.round(m.seedDiscount * 100) + '%']);
    eff.appendChild(table(['', ''], erows));
    view.appendChild(eff);

    /* SEED - ordered here, collected in person from the fence */
    const seed = block('Seed');
    if (d.seedAtFence && d.seedPending > 0) {
        const wait = el('seed-wait');
        wait.appendChild(el('seed-wait-v', fmt(d.seedPending), 'span'));
        wait.appendChild(el('seed-wait-l', 'seed waiting with the fence', 'span'));
        seed.appendChild(wait);
        seed.appendChild(el('note',
            'Paid for already. Any of the crew can ride out and collect it - talk to the fence and take what you can carry. '
            + 'He moves on the hour, so ask around if you do not know where he is working.'));
    }
    seed.appendChild(table(['', ''], [
        ['Cost', fmt(d.seedCost) + ' blood money for ' + d.seedPer],
        ['Ledger holds', fmt(d.ledger)],
    ]));
    if (d.canBuy) {
        const row = el('btnrow');
        [1, 2, 5].forEach((n) => {
            const total = d.seedCost * n;
            const b = btn((d.seedAtFence ? 'Order ' : 'Buy ') + (d.seedPer * n) + ' (' + fmt(total) + ')', 'sm',
                () => act('drug:seeds', { batches: n }));
            if (total > d.ledger) b.classList.add('disabled');
            row.appendChild(b);
        });
        seed.appendChild(row);
    } else {
        seed.appendChild(el('note', 'Your rank cannot spend the ledger.'));
    }
    seed.appendChild(el('note', d.seedAtFence
        ? 'The ledger pays when the order is placed; the fence holds the seed until somebody fetches it. '
          + 'Use it with a hoe in hand to put it in the ground, water it, and cut it when it is ready.'
        : 'Bought out of the gang ledger, not your own pocket. Use the seed with a hoe in hand to put it in the ground, '
          + 'water it, and cut it when it is ready.'));
    view.appendChild(seed);

    /* THE LABEL - rename and re-skin, bosses only */
    if (d.canManage) {
        const lab = block('The label');
        const grid = el('dicons');
        d.icons.forEach((ic) => {
            grid.appendChild(drugIconTile(ic, ic.key === d.icon, (chosen) => {
                if (chosen.key !== d.icon) act('drug:icon', { icon: chosen.key });
            }));
        });
        lab.appendChild(grid);

        const f = el('field');
        f.appendChild(el(null, 'Rename it'
            + (d.renameCost > 0 ? ' (' + fmt(d.renameCost) + ' blood money)' : ''), 'label'));
        const nameI = document.createElement('input');
        nameI.maxLength = d.nameMax || 24;
        nameI.value = d.name;
        f.appendChild(nameI);
        lab.appendChild(f);
        const row = el('btnrow');
        row.appendChild(btn('Rename', 'sm', () => {
            const n = (nameI.value || '').trim();
            if (n.length < (d.nameMin || 3) || n === d.name) return;
            act('drug:rename', { name: n });
        }));
        lab.appendChild(row);
        view.appendChild(lab);
    }

    /* THE TREE */
    const tr = block('What the crew has worked out');
    tr.appendChild(el('note',
        'Progress comes from moving the product on ground another gang holds. Selling at home or on nobody\'s ground '
        + 'still pays, it just teaches the crew nothing.'));

    const tiers = {};
    (d.tree || []).forEach((n) => {
        const t = n.tier || 1;
        (tiers[t] = tiers[t] || []).push(n);
    });
    Object.keys(tiers).map(Number).sort((a, b) => a - b).forEach((t) => {
        tr.appendChild(el('tier-l', 'Tier ' + t));
        const row = el('dtree');
        tiers[t].forEach((n) => {
            const owned = n.owned === true;
            const can = !owned && n.ready && d.points >= n.cost;
            const card = el('dnode' + (owned ? ' owned' : (n.ready ? '' : ' locked')));
            card.appendChild(el('dn-n', n.name));
            card.appendChild(el('dn-d', n.description || ''));
            card.appendChild(el('dn-c', owned ? 'LEARNED' : (fmt(n.cost) + ' progress')));
            if (!owned && !n.ready) {
                const need = (n.prerequisites || []).map((id) => {
                    const p = (d.tree || []).find((x) => x.id === id);
                    return p ? p.name : id;
                }).join(', ');
                card.appendChild(el('dn-r', 'Needs ' + need));
            }
            if (d.canManage && !owned) {
                const b = btn(can ? 'Unlock' : 'Locked', 'sm', can ? () => act('drug:unlock', { node: n.id }) : null);
                if (!can) b.classList.add('disabled');
                card.appendChild(b);
            }
            row.appendChild(card);
        });
        tr.appendChild(row);
    });
    if (!d.canManage) tr.appendChild(el('note', 'Only the bosses can spend the crew\'s progress.'));
    view.appendChild(tr);
}

/* ------------------------------------------------------------------ render */
function render() {
    if (MODE === 'den') return renderDen();
    if (!DATA) return;
    renderChrome();
    const view = $('#view');
    view.textContent = '';
    if (!DATA.panel.hasGang) return pageCreate(view);
    if (tab === 'map') return pageMap(view);
    if (tab === 'members') return pageMembers(view);
    if (tab === 'territory') return pageTerritory(view);
    if (tab === 'raids') return pageRaids(view);
    if (tab === 'wars') return pageWars(view);
    if (tab === 'faction') return pageFaction(view);
    if (tab === 'perks') return pagePerks(view);
    if (tab === 'drug') return pageDrug(view);
    return pageOverview(view);
}

/* ------------------------------------------------------------------ wiring */
function show() { $('#app').classList.remove('hidden'); }
function hide() { $('#app').classList.add('hidden'); }
function closeUi() { hide(); post('close'); }

window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'open') {
        CFG = m.config;
        // two panels share this page; `mode` picks which one is being opened
        MODE = m.mode === 'den' ? 'den' : 'gang';
        if (MODE === 'den') {
            DEN = m.den;
            /* the gang bundle rides along so the Claims and Raids tabs - which
               are the gang panel's own pages - have their DATA. Assigned BEFORE
               the return; without it those two tabs fall through to the
               overview. */
            DATA = m.data || DATA;
            denTab = 'den';
            show();
            return renderDen();
        }
        DATA = m.data;
        CTX = m.ctx || 'table';
        creating = { faction: creating.faction };
        tab = m.view || 'overview';
        if (tab === 'create') tab = 'overview';
        // a den-only tab is unreachable from the gang table
        if (DEN_ONLY[tab] && CTX !== 'den') tab = 'overview';
        show();
        render();
    } else if (m.action === 'data') {
        if (m.mode === 'den') {
            if (MODE !== 'den') return;
            DEN = m.den;
            DATA = m.data || DATA;   /* same reason as the open branch above */
            return renderDen();
        }
        if (!DATA || MODE === 'den') return;
        DATA = m.data;
        if (m.ctx) CTX = m.ctx;
        if (DEN_ONLY[tab] && CTX !== 'den') tab = 'overview';
        render();
    } else if (m.action === 'territories') {
        if (!DATA) return;
        DATA.territories = m.territories || [];
        if (tab === 'map') render();
    } else if (m.action === 'close') {
        hide();
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeUi();
});
$('#closeBtn').addEventListener('click', closeUi);
