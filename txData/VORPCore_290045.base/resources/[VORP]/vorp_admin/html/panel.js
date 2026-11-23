/* Permission set for THIS admin, pushed by panel.lua from the getDashboard
   payload. UI ONLY - every panel action is re-checked server-side, so a hidden
   control is a courtesy, not the security boundary.
   null means "not received yet"; show the control and let the server decide,
   rather than hiding the whole panel on a slow first frame. */
let myPerms = null;
function hasPerm(key) {
    if (!key) return true;
    if (!myPerms) return true;
    if (myPerms.all) return true;
    return myPerms[key] === true;
}
/* ADMIN WEB PANEL app logic.
   Data flow: NUI posts (panelStats/panelPlayers/panelMap) -> client/panel.lua
   replies 'ok' and later pushes {app:'panel', action, data} back via
   SendNUIMessage. index.js keeps its clipboard duty (guarded). */

(() => {
    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'vorp_admin';
    const $ = (sel) => document.querySelector(sel);

    const post = (name, data) => fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});

    /* ------------------------------------------------------------- state */
    let open = false;
    let page = 'dashboard';
    let statsTimer = null;
    let mapTimer = null;
    let weatherTimer = null;
    /* the "On Now" board polls so it is actually live; the roster under it is
       only rebuilt when the set of characters changes, so paging survives a tick */
    let playersTimer = null;
    let rosterSig = null;
    let onlineHistory = []; // sampled while the panel is open
    let doorSearchTerm = '';  /* showPage reads it, so it lives up here too */
    let doorPage = 0;
    let doorLastData = null;  /* so the pager can repaint without refetching */

    /* ------------------------------------------------------------- utils */
    const fmt = (n) => {
        n = Math.floor(Number(n) || 0);
        return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    };
    const fmtMoney = (n) => '$' + (Number(n) || 0).toFixed(2).replace(/\B(?=(\d{3})+(?!\d)\.)/g, ',');
    const fmtUptime = (s) => {
        s = Number(s) || 0;
        const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
        return (d > 0 ? d + 'd, ' : '') + h + 'h, ' + m + 'm';
    };
    const initials = (name) => (name || '?').split(/\s+/).map(w => w[0] || '').join('').slice(0, 2).toUpperCase();

    // dates arrive as epoch seconds ("1785790800"), epoch ms, or SQL date strings
    const fmtDate = (v, withTime) => {
        if (v === undefined || v === null || v === '' || v === '0') return '—';
        const s = String(v);
        let d = null;
        if (/^\d{9,11}$/.test(s)) d = new Date(Number(s) * 1000);
        else if (/^\d{12,}$/.test(s)) d = new Date(Number(s));
        else { d = new Date(s.replace(' ', 'T')); }
        if (!d || isNaN(d.getTime())) return s.slice(0, 10);
        const p = (n) => String(n).padStart(2, '0');
        const date = d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
        return withTime ? (date + ' ' + p(d.getHours()) + ':' + p(d.getMinutes())) : date;
    };

    const el = (tag, cls, text) => {
        const e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined) e.textContent = text;
        return e;
    };

    /* --------------------------------------------------------- confirm */
    /* Styled stand-in for the browser's native confirm(). That one renders as
       a system dialog titled "cfx-nui-vorp_admin" - it reads as a different
       program entirely, and it blocks the whole page while it is up.
         askConfirm({ title, body, okLabel, danger, onOk })
       `body` may contain <b>; everything else must be pre-escaped by the caller. */
    const askConfirm = (opts) => {
        const wrap = $('#pconfirm');
        $('#pconfirm-title').textContent = opts.title || 'Are you sure?';
        $('#pconfirm-body').innerHTML = opts.body || '';

        /* clone the buttons to drop every previous listener - a dialog opened
           ten times must not fire its action ten times */
        const ok = $('#pconfirm-ok').cloneNode(true);
        const cancel = $('#pconfirm-cancel').cloneNode(true);
        ok.textContent = opts.okLabel || 'Confirm';
        ok.className = 'abtn' + (opts.danger === false ? '' : ' warn');
        cancel.textContent = 'Cancel';
        $('#pconfirm-ok').replaceWith(ok);
        $('#pconfirm-cancel').replaceWith(cancel);

        const close = () => wrap.classList.add('hidden');
        ok.addEventListener('click', () => { close(); if (opts.onOk) opts.onOk(); });
        cancel.addEventListener('click', close);
        wrap.classList.remove('hidden');
    };
    const confirmOpen = () => !$('#pconfirm').classList.contains('hidden');

    /* --------------------------------------------------------- copy */
    /* An id you can read but not select is no use - the panel is a NUI page with
       text selection off. execCommand goes first: NUI blocks navigator.clipboard
       by permissions policy, and it rejects on a promise, so a try/catch around
       the call never sees the failure and we would report a copy that never
       happened. Returns a promise because that fallback is async. */
    const COPY_GLYPH = '⧉';
    const copyText = (text) => {
        const s = String(text == null ? '' : text);
        if (!s) return Promise.resolve(false);
        try {
            const ta = document.createElement('textarea');
            ta.value = s;
            ta.setAttribute('readonly', '');
            ta.style.position = 'fixed';
            ta.style.top = '0';
            ta.style.left = '0';
            ta.style.opacity = '0';
            document.body.appendChild(ta);
            ta.focus();
            ta.select();
            try { ta.setSelectionRange(0, s.length); } catch (e) { /* not required */ }
            const ok = document.execCommand('copy');
            document.body.removeChild(ta);
            if (ok) return Promise.resolve(true);
        } catch (e) { /* fall through */ }
        if (navigator.clipboard && navigator.clipboard.writeText) {
            return navigator.clipboard.writeText(s).then(() => true, () => false);
        }
        return Promise.resolve(false);
    };

    /* small clipboard button; label is only for the tooltip */
    const copyBtn = (text, label) => {
        const b = el('button', 'abtn copy-btn', COPY_GLYPH);
        b.title = 'Copy ' + (label || 'value');
        b.addEventListener('click', (ev) => {
            ev.stopPropagation();
            copyText(text).then((done) => {
                b.textContent = done ? '✓' : '✗';
                setTimeout(() => { b.textContent = COPY_GLYPH; }, 900);
            });
        });
        return b;
    };

    /* ------------------------------------------------------------- nav */
    const showPage = (id) => {
        page = id;
        document.querySelectorAll('.nav-item[data-page]').forEach(b =>
            b.classList.toggle('active', b.dataset.page === id));
        document.querySelectorAll('.page').forEach(p => p.classList.add('hidden'));
        $('#page-' + id).classList.remove('hidden');

        clearInterval(mapTimer); mapTimer = null;
        clearInterval(playersTimer); playersTimer = null;
        clearInterval(weatherTimer); weatherTimer = null;
        if (id === 'map') {
            onMapPageShown();
            post('panelMap');
            mapTimer = setInterval(() => post('panelMap'), 2000);
        } else if (id === 'players') {
            rosterSig = null; // force a full paint when the page is opened
            post('panelPlayers', { search: $('#playerSearch').value.trim() });
            // slower than the map: this one runs a DB query, the map does not
            playersTimer = setInterval(
                () => post('panelPlayers', { search: $('#playerSearch').value.trim() }), 5000);
        } else if (id === 'items') {
            post('panelItemsSearch', { term: $('#itemSearch').value.trim() });
        } else if (id === 'consumables') {
            post('panelConsumables');
        } else if (id === 'smokes') {
            post('panelSmokes');
        } else if (id === 'deaths') {
            post('panelDeaths');
        } else if (id === 'crafting') {
            post('panelCraftRecipes');
        } else if (id === 'weaponcraft') {
            post('panelWeaponRecipes');
        } else if (id === 'housing') {
            post('panelHousing');
        } else if (id === 'society') {
            post('panelSociety');
        } else if (id === 'ranches') {
            post('panelRanches');
        } else if (id === 'stores') {
            post('panelStores');
        } else if (id === 'gangs') {
            post('panelGangs');
        } else if (id === 'perks') {
            post('panelPerks', { search: $('#perkSearch').value.trim() });
        } else if (id === 'banks') {
            post('panelBanks');
        } else if (id === 'hideouts') {
            post('panelHideouts');
        } else if (id === 'curses') {
            post('panelCurses');
        } else if (id === 'farms') {
            farmView = null;          /* always land on the grower list */
            post('panelFarms');
        } else if (id === 'camps') {
            campView = null;          /* always land on the camp list */
            post('panelCamps');
        } else if (id === 'props') {
            post('panelProps');
        } else if (id === 'events') {
            post('panelEvents');
        } else if (id === 'weather') {
            /* build the controls on open, not when the first feed lands: a slow
               or missing reply would otherwise leave a blank page */
            buildWeatherPage();
            post('panelWeather');
            weatherTimer = setInterval(() => post('panelWeather'), 1000);
        } else if (id === 'teleports') {
            post('panelMyPos');   /* read the position as soon as the page opens */
        } else if (id === 'security') {
            post('panelSecurity');
        } else if (id === 'doorlocks') {
            post('panelDoorLocks', { search: doorSearchTerm });
        }
    };

    document.querySelectorAll('.nav-item[data-page]').forEach(b =>
        b.addEventListener('click', () => showPage(b.dataset.page)));

    document.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape' || !open) return;
        /* peel the dialog first - ESC should not close the whole panel out
           from under an open confirmation */
        if (confirmOpen()) { $('#pconfirm').classList.add('hidden'); return; }
        post('panelClose');
    });

    /* ------------------------------------------------------------- dashboard */
    const card = (title, sub, value, icon) => {
        const c = el('div', 'card');
        const head = el('div', 'card-head');
        const twrap = el('div');
        twrap.appendChild(el('div', 'card-title', title));
        if (sub) twrap.appendChild(el('div', 'card-sub', sub));
        head.appendChild(twrap);
        head.appendChild(el('div', 'card-ico', icon || '✦'));
        c.appendChild(head);
        const v = el('div', 'card-value');
        v.appendChild(value);
        c.appendChild(v);
        return c;
    };
    const valueNode = (main, unit) => {
        const f = document.createDocumentFragment();
        f.appendChild(document.createTextNode(main));
        if (unit) {
            const u = el('span', 'unit', ' ' + unit);
            f.appendChild(u);
        }
        return f;
    };

    let chartData = null; // { points: [{t,n}], now, current }

    const renderStats = (info, econ) => {
        if (!info) return;
        const cards = $('#dashCards');
        cards.textContent = '';
        cards.appendChild(card('Players', 'currently connected',
            valueNode(String(info.playerCount), '/ ' + info.maxPlayers + ' online'), '♟'));
        cards.appendChild(card('Server Up Time', 'since last restart',
            valueNode(fmtUptime(info.uptime)), '⏱'));
        const t = econ && econ.totals;
        cards.appendChild(card('Total Money On Server', 'characters cash + bank',
            valueNode(t ? fmtMoney((t.cash || 0) + (t.banked || 0)) : '—'), '$'));

        const act = $('#activityCards');
        act.textContent = '';
        act.appendChild(card('Total Characters', '', valueNode(info.totalChars != null ? fmt(info.totalChars) : '—'), '♟'));
        act.appendChild(card('Played Last 24h', '', valueNode(info.active24 != null ? fmt(info.active24) : '—'), '◉'));
        act.appendChild(card('New This Week', '', valueNode(info.new7d != null ? ('+' + fmt(info.new7d)) : '—'), '✚'));
        act.appendChild(card('Staff Online', '', valueNode(fmt(info.staffCount || 0)), '✦'));

        const econCards = $('#econCards');
        econCards.textContent = '';
        if (t) {
            econCards.appendChild(card('Cash In Pockets', 'characters.money',
                valueNode(fmtMoney(t.cash || 0)), '$'));
            econCards.appendChild(card('Banked', 'bank accounts',
                valueNode(fmtMoney(t.banked || 0)), '⛁'));
            econCards.appendChild(card('Gold', 'characters.gold',
                valueNode(fmt(t.gold || 0), 'gold'), '●'));
        }

        chartData = {
            points: Array.isArray(info.history) ? info.history : [],
            now: Number(info.now) || Math.floor(Date.now() / 1000),
            current: Number(info.playerCount) || 0,
        };
        drawChart();
    };

    /* txAdmin-style 24h player count chart: axes, gridlines, hour labels */
    const drawChart = () => {
        const cv = $('#dashChart');
        if (!cv || !chartData) return;
        const w = cv.clientWidth || 800;
        cv.width = w;
        const h = cv.height;
        const ctx = cv.getContext('2d');
        ctx.clearRect(0, 0, w, h);

        const L = 44, R = 18, T = 12, B = 26;
        const cw = w - L - R, chh = h - T - B;
        const now = chartData.now;
        const from = now - 86400;

        const pts = chartData.points
            .filter(p => p && Number(p.t) > from)
            .map(p => ({ t: Number(p.t), n: Number(p.n) || 0 }));
        pts.push({ t: now, n: chartData.current });
        pts.sort((a, b) => a.t - b.t);

        let maxN = 0;
        pts.forEach(p => { if (p.n > maxN) maxN = p.n; });
        maxN = Math.max(4, Math.ceil(maxN * 1.15));

        const X = (t) => L + ((t - from) / 86400) * cw;
        const Y = (n) => T + chh - (n / maxN) * chh;

        ctx.font = '11px Georgia';
        ctx.textBaseline = 'middle';

        // horizontal gridlines + y labels
        for (let i = 0; i <= 4; i++) {
            const n = Math.round((maxN / 4) * i);
            const y = Y(n);
            ctx.strokeStyle = 'rgba(239,230,213,.07)';
            ctx.beginPath(); ctx.moveTo(L, y); ctx.lineTo(w - R, y); ctx.stroke();
            ctx.fillStyle = 'rgba(181,170,150,.75)';
            ctx.textAlign = 'right';
            ctx.fillText(String(n), L - 8, y);
        }

        // x labels every 4 hours, on the hour
        ctx.textAlign = 'center';
        const firstHour = Math.ceil(from / 14400) * 14400;
        for (let t = firstHour; t <= now; t += 14400) {
            const d = new Date(t * 1000);
            ctx.fillStyle = 'rgba(181,170,150,.6)';
            ctx.fillText(String(d.getHours()).padStart(2, '0') + ':00', X(t), h - B / 2);
            ctx.strokeStyle = 'rgba(239,230,213,.04)';
            ctx.beginPath(); ctx.moveTo(X(t), T); ctx.lineTo(X(t), T + chh); ctx.stroke();
        }

        if (!pts.length) return;

        // area
        ctx.beginPath();
        ctx.moveTo(X(pts[0].t), Y(0));
        pts.forEach(p => ctx.lineTo(X(p.t), Y(p.n)));
        ctx.lineTo(X(pts[pts.length - 1].t), Y(0));
        ctx.closePath();
        const grad = ctx.createLinearGradient(0, T, 0, T + chh);
        grad.addColorStop(0, 'rgba(239,230,213,.22)');
        grad.addColorStop(1, 'rgba(239,230,213,.01)');
        ctx.fillStyle = grad;
        ctx.fill();

        // line
        ctx.beginPath();
        pts.forEach((p, i) => i === 0 ? ctx.moveTo(X(p.t), Y(p.n)) : ctx.lineTo(X(p.t), Y(p.n)));
        ctx.strokeStyle = '#efe6d5';
        ctx.lineWidth = 2.2;
        ctx.lineJoin = 'round';
        ctx.stroke();

        // current point + value chip
        const last = pts[pts.length - 1];
        const lx = X(last.t), ly = Y(last.n);
        ctx.beginPath(); ctx.arc(lx, ly, 4.5, 0, Math.PI * 2);
        ctx.fillStyle = '#efe6d5'; ctx.fill();
        const label = last.n + ' online';
        ctx.font = '12px Georgia';
        const tw = ctx.measureText(label).width + 14;
        const bx = Math.min(lx + 10, w - R - tw), by = Math.max(T, ly - 26);
        ctx.fillStyle = 'rgba(19,17,16,.92)';
        ctx.strokeStyle = 'rgba(239,230,213,.15)';
        roundRect(ctx, bx, by, tw, 20, 6);
        ctx.fill(); ctx.stroke();
        ctx.fillStyle = '#efe6d5';
        ctx.textAlign = 'left';
        ctx.fillText(label, bx + 7, by + 10);
    };

    const roundRect = (ctx, x, y, w, h, r) => {
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.arcTo(x + w, y, x + w, y + h, r);
        ctx.arcTo(x + w, y + h, x, y + h, r);
        ctx.arcTo(x, y + h, x, y, r);
        ctx.arcTo(x, y, x + w, y, r);
        ctx.closePath();
    };

    /* ------------------------------------------------------------- players */
    let searchTimer = null;
    $('#playerSearch').addEventListener('input', () => {
        clearTimeout(searchTimer);
        searchTimer = setTimeout(() =>
            post('panelPlayers', { search: $('#playerSearch').value.trim() }), 300);
    });

    const pingCls = (p) => (p <= 80 ? 'good' : (p <= 150 ? 'warn' : 'bad'));

    /* One row on the "On Now" board. Everything specific to it comes from
       r.live, which the server fills ONLY for players actually connected. */
    const onNowRow = (r) => {
        const L = r.live || {};
        const row = el('div', 'onrow');

        const namec = el('div', 'pname');
        namec.appendChild(el('div', 'pavatar', initials(r.name)));
        const nw = el('div');
        nw.appendChild(el('div', 'n', r.name || ('#' + r.charid)));
        nw.appendChild(el('div', 's', 'Char ' + r.charid + ' • ID ' + r.online +
            (r.staff ? ' • STAFF' : '')));
        namec.appendChild(nw);
        row.appendChild(namec);

        const jobc = el('div');
        jobc.appendChild(el('span', 'chip', r.job || 'unemployed'));
        row.appendChild(jobc);

        /* ping is the only live data */
        const cond = el('div', 'meta');
        cond.appendChild(el('span', 'pill ' + pingCls(L.ping || 0), (L.ping || 0) + 'ms'));
        row.appendChild(cond);

        /* quick actions, each gated on the SAME key the server re-checks */
        const acts = el('div', 'onacts');
        const target = Number(r.online), nm = r.name || '';
        const act = (label, fn, cls) => {
            const b = el('button', 'abtn' + (cls ? ' ' + cls : ''), label);
            b.addEventListener('click', (e) => { e.stopPropagation(); fn(); });
            acts.appendChild(b);
            return b; // so a caller can add a title
        };
        act('Profile', () => openDetail(r.charid));
        if (hasPerm('tp_to_player')) act('Go to', () => post('panelAction', { action: 'goto', target, name: nm }));
        if (hasPerm('bring_player')) act('Bring', () => post('panelAction', { action: 'bring', target, name: nm }));
        if (hasPerm('spectate')) act('Spectate', () => post('panelAction', { action: 'spectate', target, name: nm }));
        /* both offered: without live state the panel cannot tell who is down */
        if (hasPerm('heal_player')) act('Heal', () => post('panelAction', { action: 'heal', target, name: nm }));
        if (hasPerm('revive_player')) act('Revive', () => post('panelAction', { action: 'revive', target, name: nm }));
        /* makes them run /rc - rebuilds the ped when clothes or tints came back wrong */
        if (hasPerm('heal_player')) {
            const rb = act('Reload', () => post('panelAction', { action: 'reloadchar', target, name: nm }));
            if (rb) rb.title = 'Force /rc - rebuilds their character (clothes, tints)';
        }
        if (hasPerm('kick_player')) {
            act('Kick', () => askConfirm({
                title: 'Kick ' + nm + '?',
                body: 'They are disconnected immediately, and can rejoin straight away.',
                okLabel: 'Kick', danger: true,
                onOk: () => post('panelAction',
                    { action: 'kick', target, name: nm, reason: 'kicked by admin' }),
            }), 'warn');
        }
        row.appendChild(acts);
        return row;
    };

    const renderPlayers = (data) => {
        const rows = $('#playerRows');
        const cards = $('#playerCards');
        cards.textContent = '';
        if (!data || !data.rows) {
            rows.textContent = '';
            rows.appendChild(el('div', 'empty', 'No data (are you allowed?)'));
            rosterSig = null;
            return;
        }

        const onNow = data.rows.filter(r => r.online);
        const rest = data.rows.filter(r => !r.online);
        const downed = onNow.filter(r => r.live && r.live.dead).length;

        /* Two containers, so a 5s tick can repaint the live board without
           touching the roster - rebuilding that would reset the page you are on. */
        let liveWrap = rows.querySelector('#onNowWrap');
        let rosterWrap = rows.querySelector('#rosterWrap');
        if (!liveWrap || !rosterWrap) {
            rows.textContent = '';
            liveWrap = el('div'); liveWrap.id = 'onNowWrap';
            rosterWrap = el('div'); rosterWrap.id = 'rosterWrap';
            rows.appendChild(liveWrap);
            rows.appendChild(rosterWrap);
        }
        liveWrap.textContent = '';

        /* the roster only changes when the SET of offline characters changes */
        const sig = rest.map(r => r.charid).join(',');
        const rosterStale = (sig !== rosterSig);
        rosterSig = sig;

        cards.appendChild(card('Online Players', '', valueNode(fmt(data.onlineCount)), '◉'));
        cards.appendChild(card('Staff Online', '', valueNode(fmt(onNow.filter(r => r.staff).length)), '✦'));
        cards.appendChild(card('Down Right Now', downed ? 'need a revive' : '', valueNode(fmt(downed)), '✚'));
        cards.appendChild(card('Total Characters', '', valueNode(fmt(data.totalCharacters)), '♟'));

        /* ON NOW - repainted every tick */
        const h = el('div', 'onnow-head');
        h.appendChild(el('span', 't', data.searching ? 'Online matches' : 'On Now'));
        h.appendChild(el('span', 'c', onNow.length
            ? (onNow.length + ' connected')
            : (data.searching ? 'none of the matches are online' : 'nobody is connected')));
        liveWrap.appendChild(h);

        if (onNow.length) {
            /* a header, because "Valentine" next to a job chip reads as nothing
               without one - these columns are not the roster's columns */
            const bh = el('div', 'onnow-th');
            ['Character', 'Job', 'Ping'].forEach(t => bh.appendChild(el('div', '', t)));
            bh.appendChild(el('div', 'right', 'Actions'));
            liveWrap.appendChild(bh);

            onNow.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
            onNow.forEach(r => liveWrap.appendChild(onNowRow(r)));
        } else if (!data.searching) {
            liveWrap.appendChild(el('div', 'empty', 'Nobody is on the server right now'));
        }

        /* OFFLINE results appear ONLY for a search - the tab is online-only otherwise */
        if (!data.searching) {
            if (rosterWrap.textContent !== '') { rosterWrap.textContent = ''; rosterSig = null; }
            return;
        }
        if (!rosterStale) return;
        rosterWrap.textContent = '';

        const h2 = el('div', 'onnow-head');
        h2.appendChild(el('span', 't', 'Offline matches'));
        h2.appendChild(el('span', 'c', rest.length ? (rest.length + ' found, richest first') : 'none'));
        rosterWrap.appendChild(h2);

        if (!rest.length) {
            rosterWrap.appendChild(el('div', 'empty', onNow.length
                ? 'Everyone matching that search is online and listed above'
                : 'No characters match that search'));
            return;
        }
        /* the column header belongs to THESE rows, so it lives here rather than
           above the live board, whose columns are completely different */
        const th = el('div', 'table-head');
        ['Character', 'Job', 'Money & Gold', 'Last Login'].forEach(t => th.appendChild(el('div', '', t)));
        th.appendChild(el('div', 'right', 'Status'));
        rosterWrap.appendChild(th);

        /* its own host, so paging cannot wipe the heading above */
        const host = el('div');
        rosterWrap.appendChild(host);
        pagedList(host, rest, null, r => {
            const row = el('div', 'prow');
            row.style.cursor = 'pointer';
            row.addEventListener('click', () => openDetail(r.charid));

            const namec = el('div', 'pname');
            namec.appendChild(el('div', 'pavatar', initials(r.name)));
            const nw = el('div');
            nw.appendChild(el('div', 'n', r.name || ('#' + r.charid)));
            /* you can search by Steam name or Discord id, so show what matched -
               two characters can share a name, their accounts cannot */
            const idbits = ['Char ' + r.charid];
            if (r.steamname) idbits.push(r.steamname);
            if (r.discordid && r.discordid !== '0') idbits.push('discord ' + r.discordid);
            nw.appendChild(el('div', 's', idbits.join(' • ')));
            namec.appendChild(nw);
            row.appendChild(namec);

            const jobc = el('div');
            jobc.appendChild(el('span', 'chip', r.job || 'unemployed'));
            row.appendChild(jobc);

            const moneyc = el('div', 'pmoney');
            moneyc.appendChild(document.createTextNode(fmtMoney(r.money) + ' / '));
            moneyc.appendChild(el('span', 'g', '● ' + fmt(r.gold)));
            row.appendChild(moneyc);

            row.appendChild(el('div', 'pxp', fmtDate(r.lastlogin)));

            const st = el('div', 'right');
            st.appendChild(el('span', 'status ' + (r.online ? 'online' : 'offline'),
                r.online ? '● Online' : '○ Offline'));
            row.appendChild(st);

            return row;
        }, { noSearch: true }); // the top search box already queries the server
    };

    /* ------------------------------------------------------------- player detail */
    const openDetail = (charid) => {
        showPage('detail');
        $('#detailBody').textContent = '';
        $('#detailBody').appendChild(el('div', 'empty', 'Loading character ' + charid + '…'));
        post('panelPlayerDetail', { charid });
    };
    $('#detailBack').addEventListener('click', () => showPage('players'));

    const sendAction = (payload) => post('panelAction', payload);

    /* item-name autocomplete: type "aci" -> dropdown with "acid — Acid (limit 10)".
       Fed by panelItemSuggest (itemsSearch under the hood); one active target. */
    let suggestTarget = null; // { input, box }
    const attachItemSuggest = (input) => {
        const wrap = el('div', 'suggest-wrap');
        const box = el('div', 'suggest hidden');
        wrap.appendChild(input);
        wrap.appendChild(box);
        let timer = null;
        input.addEventListener('input', () => {
            clearTimeout(timer);
            const term = input.value.trim();
            if (term.length < 2) { box.classList.add('hidden'); return; }
            timer = setTimeout(() => {
                suggestTarget = { input, box };
                post('panelItemSuggest', { term });
            }, 250);
        });
        input.addEventListener('blur', () => setTimeout(() => box.classList.add('hidden'), 200));
        return wrap;
    };
    const renderItemSuggest = (data) => {
        if (!suggestTarget || !data || !Array.isArray(data.rows)) return;
        const { input, box } = suggestTarget;
        box.textContent = '';
        if (!data.rows.length) { box.classList.add('hidden'); return; }
        data.rows.slice(0, 8).forEach(r => {
            const row = el('div', 'suggest-row');
            row.appendChild(el('strong', null, r.item));
            row.appendChild(el('span', null,
                ' — ' + (r.label || '') + '  (limit ' + (r.limit === null ? '∞' : r.limit) + ')'));
            row.addEventListener('mousedown', () => {
                input.value = r.item;
                box.classList.add('hidden');
            });
            box.appendChild(row);
        });
        box.classList.remove('hidden');
    };

    /* prop-name autocomplete for the Prop Placer. Same shape as the item one,
       but the list lives on the CLIENT (dataprops.lua) so the round trip never
       touches the server, and one letter is enough to be useful - prop names
       are long and nobody remembers them. */
    let propSuggestTarget = null; // { input, box }
    const attachPropSuggest = (input) => {
        const wrap = el('div', 'suggest-wrap');
        const box = el('div', 'suggest hidden');
        wrap.appendChild(input);
        wrap.appendChild(box);
        let timer = null;
        const ask = () => {
            clearTimeout(timer);
            const term = input.value.trim();
            if (term.length < 1) { box.classList.add('hidden'); return; }
            timer = setTimeout(() => {
                propSuggestTarget = { input, box };
                post('panelPropSuggest', { term });
            }, 150);
        };
        input.addEventListener('input', ask);
        input.addEventListener('focus', ask);
        input.addEventListener('blur', () => setTimeout(() => box.classList.add('hidden'), 200));
        return wrap;
    };
    const renderPropSuggest = (data) => {
        if (!propSuggestTarget || !data || !Array.isArray(data.rows)) return;
        const { input, box } = propSuggestTarget;
        box.textContent = '';
        if (!data.rows.length) { box.classList.add('hidden'); return; }
        data.rows.slice(0, 10).forEach(name => {
            const row = el('div', 'suggest-row');
            row.appendChild(el('strong', null, name));
            row.addEventListener('mousedown', () => {
                input.value = name;
                box.classList.add('hidden');
            });
            box.appendChild(row);
        });
        box.classList.remove('hidden');
    };

    const kvCard = (title, pairs) => {
        const c = el('div', 'card info-card');
        c.appendChild(el('div', 'icard-title', title));
        pairs.forEach(([k, v]) => {
            if (v === undefined || v === null || v === '') return;
            const line = el('div', 'kv');
            line.appendChild(el('span', 'k', k));
            line.appendChild(el('span', 'v', String(v)));
            c.appendChild(line);
        });
        return c;
    };

    const assetCard = (title, items, render) => {
        const c = el('div', 'card info-card');
        c.appendChild(el('div', 'icard-title', title));
        const list = el('div', 'asset-list');
        if (!items || !items.length) {
            list.appendChild(el('div', 'asset-empty', 'None'));
        } else {
            items.forEach(it => list.appendChild(render(it)));
        }
        c.appendChild(list);
        return c;
    };

    const renderDetail = (d) => {
        const body = $('#detailBody');
        body.textContent = '';
        if (!d || !d.char) {
            body.appendChild(el('div', 'empty', 'Could not load this character'));
            return;
        }
        const ch = d.char;
        const fullName = ((ch.firstname || '') + ' ' + (ch.lastname || '')).trim() || ('Char ' + ch.charid);

        /* head */
        const head = el('div', 'detail-head');
        head.appendChild(el('div', 'pavatar', initials(fullName)));
        const hw = el('div');
        hw.appendChild(el('div', 'dname', fullName));
        hw.appendChild(el('div', 'dsub', 'Char ' + ch.charid + ' • ' + (ch.steamname || ch.identifier || '')));
        head.appendChild(hw);
        const chips = el('div', 'chips');
        chips.appendChild(el('span', 'chip', ch.group || 'user'));
        chips.appendChild(el('span', 'chip', ch.joblabel || ch.job || 'unemployed'));
        chips.appendChild(el('span', 'status ' + (d.online ? 'online' : 'offline'),
            d.online ? ('● Online — ID ' + d.online) : '○ Offline'));
        head.appendChild(chips);
        body.appendChild(head);

        /* actions (online only - every event needs a server id), organised into
           labelled category tabs so it's obvious what lives where:
           Player = movement/state · Database = items/money · Character = job/
           group/stable · Troll = trolls · Punish = kick/ban */
        if (d.online) {
            const t = d.online;
            const act = (action, extra) => sendAction(Object.assign({ action, target: t, name: fullName }, extra || {}));
            /* A category is worth showing only if this admin holds at least one
               of its permissions. A tab full of buttons the server will refuse
               is worse than no tab at all. */
            const CAT_PERMS = {
                Player:    ['heal_player', 'revive_player', 'respawn_player', 'freeze_player',
                            'spectate', 'godmode', 'infinite_ammo', 'golden_cores',
                            'tp_to_player', 'bring_player', 'send_player_back', 'tp_player_back'],
                Database:  ['check_player_inventory', 'open_player_inventory', 'clear_inventory',
                            'clear_currency',
                            'give_item', 'give_weapon', 'give_moneygold', 'give_horse', 'give_wagon'],
                Character: ['set_group', 'set_job', 'admin_actions_menu'],
                Troll:     ['troll_kill_player', 'troll_lightning_strike', 'troll_set_player_on_fire',
                            'troll_tp_to_heaven', 'troll_ragdoll_player', 'troll_handcuff_player',
                            'troll_invisible', 'troll_drain_player_stam', 'troll_temp_high_player'],
                Punish:    ['kick_player', 'ban_player', 'ban_offline'],
            };
            const catAllowed = (cat) => (CAT_PERMS[cat] || []).some(hasPerm);

            const CATS = ['Player', 'Database', 'Character', 'Troll', 'Punish'].filter(catAllowed);
            const catCards = {};
            /* Per-CARD permissions. The category gate is not enough on its own:
               a moderator holds check_player_inventory, which opens Database,
               and would otherwise be looking at Give Money and Clear Weapons.
               A card appears only if its holder can use something on it. */
            const CARD_PERMS = {
                'Movement & State': ['tp_to_player', 'bring_player', 'send_player_back',
                                     'tp_player_back', 'spectate', 'heal_player',
                                     'revive_player', 'respawn_player', 'freeze_player',
                                     'godmode', 'infinite_ammo', 'golden_cores'],
                'Instance':         ['admin_actions_menu'],
                'Money & Gold':     ['give_moneygold', 'clear_currency'],
                'Items & Weapons':  ['check_player_inventory', 'open_player_inventory',
                                     'give_item', 'give_weapon', 'clear_inventory'],
                'Job & Group':      ['set_job', 'set_group'],
                'Stable':           ['give_horse', 'give_wagon'],
                'Troll Actions':    ['troll_kill_player', 'troll_lightning_strike',
                                     'troll_set_player_on_fire', 'troll_tp_to_heaven',
                                     'troll_ragdoll_player', 'troll_handcuff_player',
                                     'troll_invisible', 'troll_drain_player_stam',
                                     'troll_temp_high_player'],
                'Kick & Ban':       ['kick_player', 'ban_player', 'ban_offline'],
            };

            const group = (cat, title, build) => {
                if (!catAllowed(cat)) return;
                const need = CARD_PERMS[title];
                if (need && !need.some(hasPerm)) return;
                const c = el('div', 'card actions-card');
                if (title) c.appendChild(el('div', 'actions-title', title));
                build(c);
                (catCards[cat] = catCards[cat] || []).push(c);
            };
            const btnRow = (parent, defs) => {
                const grid = el('div', 'actions-grid');
                defs.forEach(([label, fn, warn]) => {
                    const b = el('button', 'abtn' + (warn ? ' warn' : ''), label);
                    b.addEventListener('click', fn);
                    grid.appendChild(b);
                });
                parent.appendChild(grid);
            };
            const inp = (ph, narrow, width) => {
                const i = el('input', narrow ? 'narrow' : null);
                i.placeholder = ph;
                if (width) i.style.width = width;
                return i;
            };
            const form = (parent, nodes) => {
                const f = el('div', 'action-form');
                nodes.forEach(n => f.appendChild(n));
                parent.appendChild(f);
            };
            const fbtn = (label, fn, warn) => {
                const b = el('button', 'abtn' + (warn ? ' warn' : ''), label);
                b.addEventListener('click', fn);
                return b;
            };

            /* -------- Player: movement + state -------- */
            /* mixed card: spectating and reviving are different powers, so each
               button carries the key it actually needs */
            group('Player', 'Movement & State', (c) => {
                const defs = [
                    ['Bring',     () => act('bring'),   false, 'bring_player'],
                    ['Go To',     () => act('goto'),    false, 'tp_to_player'],
                    ['Send Back', () => act('tpback'),  false, 'send_player_back'],
                    ['Spectate',  () => act('spectate'), false, 'spectate'],
                    ['Heal',      () => act('heal'),    false, 'heal_player'],
                    ['Revive',    () => act('revive'),  false, 'revive_player'],
                    ['Respawn',   () => act('respawn'), false, 'respawn_player'],
                    ['Freeze',    () => act('freeze', { state: true }),  false, 'freeze_player'],
                    ['Unfreeze',  () => act('freeze', { state: false }), false, 'freeze_player'],
                ].filter(d => hasPerm(d[3]));
                if (defs.length) btnRow(c, defs);
            });

            /* -------- Player: instance (routing bucket) -------- */
            group('Player', 'Instance', (c) => {
                const b = inp('instance #', true);
                form(c, [b,
                    fbtn('Set Instance', () => act('instance', { bucket: Number(b.value) })),
                    fbtn('To World (0)', () => act('instance', { bucket: 0 })),
                ]);
                c.appendChild(el('div', 'offline-note',
                    'Instance 0 is the shared world everyone plays in. Go To / Bring follow across instances.'));
            });

            /* -------- Database: items, weapons, money -------- */
            group('Database', 'Money & Gold', (c) => {
                const amount = inp('amount', true);
                const row = [amount];
                if (hasPerm('give_moneygold')) {
                    row.push(fbtn('Give Money', () => act('givemoney', { amount: Number(amount.value) })));
                    row.push(fbtn('Give Gold', () => act('givegold', { amount: Number(amount.value) })));
                }
                if (hasPerm('clear_currency')) {
                    row.push(fbtn('Clear Money', () => act('clearmoney'), true));
                    row.push(fbtn('Clear Gold', () => act('cleargold'), true));
                }
                form(c, row);
            });
            /* the one genuinely MIXED card: looking at a satchel and emptying it
               are different powers, so these are gated one control at a time */
            group('Database', 'Items & Weapons', (c) => {
                const item = inp('item name - type to search');
                const qty = inp('qty', true);
                const weapon = inp('WEAPON_NAME', false, '12vw');

                const row = [];
                if (hasPerm('give_item')) {
                    row.push(attachItemSuggest(item), qty,
                        fbtn('Give Item', () => act('giveitem', { item: item.value.trim(), qty: Number(qty.value) })));
                }
                if (hasPerm('give_weapon')) {
                    row.push(weapon,
                        fbtn('Give Weapon', () => act('giveweapon', { weapon: weapon.value.trim().toUpperCase() })));
                }
                if (row.length) form(c, row);

                const btns = [];
                /* two separate things: the read-only list anyone with view can
                   see, and the real panel you can take items out of */
                if (hasPerm('open_player_inventory')) btns.push(['Open Their Inventory', () => act('liveinv')]);
                if (hasPerm('clear_inventory')) {
                    btns.push(['Clear Items', () => act('clearitems', { what: 'items' }), true]);
                    btns.push(['Clear Weapons', () => act('clearitems', { what: 'weapons' }), true]);
                }
                if (btns.length) btnRow(c, btns);
            });

            /* -------- Character: job, group, stable -------- */
            group('Character', 'Job & Group', (c) => {
                const job = inp('job'); const grade = inp('grade', true); const label = inp('job label');
                const grp = inp('group');
                form(c, [job, grade, label,
                    fbtn('Set Job', () => act('setjob', { job: job.value.trim(), grade: grade.value, label: label.value.trim() }))]);
                form(c, [grp, fbtn('Set Group', () => act('setgroup', { group: grp.value.trim() }))]);
            });
            group('Character', 'Stable', (c) => {
                const hm = inp('horse model', false, '13vw'); const hn = inp('horse name');
                const hs = inp('male/female', true);
                form(c, [hm, hn, hs, fbtn('Give Horse', () => act('givehorse',
                    { model: hm.value.trim(), hname: hn.value.trim() || 'Horse', sex: (hs.value.trim() || 'male') }))]);
                const wm = inp('wagon model', false, '13vw'); const wn = inp('wagon name');
                form(c, [wm, wn, fbtn('Give Wagon', () => act('givewagon',
                    { model: wm.value.trim(), wname: wn.value.trim() || 'Wagon' }))]);
            });

            /* -------- Troll -------- */
            group('Troll', 'Troll Actions', (c) => {
                btnRow(c, [
                    ['Kill', () => act('troll', { kind: 'kill' }), true],
                    ['Lightning', () => act('troll', { kind: 'lightning' }), true],
                    ['Set On Fire', () => act('troll', { kind: 'fire' }), true],
                    ['TP To Heaven', () => act('troll', { kind: 'heaven' }), true],
                    ['Ragdoll', () => act('troll', { kind: 'ragdoll' }), true],
                    ['Handcuff', () => act('troll', { kind: 'handcuff' }), true],
                    ['Drain Stamina', () => act('troll', { kind: 'drainstam' }), true],
                ]);
            });

            /* -------- Punish --------
               Ban goes through the Server Bans system: it records every
               identifier and the hardware tokens, and hands back a Ban ID. */
            group('Punish', 'Kick & Ban', (c) => {
                const reason = inp('reason - the player is shown this', false, '14vw');
                const time = banDurationSelect();
                form(c, [reason, fbtn('Kick', () => act('kick', { reason: reason.value.trim() }), true),
                    time, fbtn('Ban', () => {
                        post('panelBanPlayer', {
                            target: t,
                            reason: reason.value.trim(),
                            seconds: Number(time.value) || 0,
                        });
                    }, true)]);
                c.appendChild(el('div', 'offline-note',
                    'Records licence, Steam, Discord, IP and hardware tokens. They get the reason and a Ban ID.'));
            });

            /* category chip bar + active category content */
            const bar = el('div', 'cat-bar');
            const content = el('div');
            /* not hardcoded to 'Player': that category can be filtered out */
            let activeCat = CATS[0];
            const renderCat = () => {
                content.textContent = '';
                (catCards[activeCat] || []).forEach(c => content.appendChild(c));
                bar.querySelectorAll('.cat-chip').forEach(b => b.classList.toggle('on', b.dataset.cat === activeCat));
            };
            CATS.forEach(cat => {
                const b = el('button', 'cat-chip', cat);
                b.dataset.cat = cat;
                b.addEventListener('click', () => { activeCat = cat; renderCat(); });
                bar.appendChild(b);
            });
            body.appendChild(bar);
            body.appendChild(content);
            renderCat();
        } else {
            const ac = el('div', 'card actions-card');
            ac.appendChild(el('div', 'actions-title', 'Actions'));
            ac.appendChild(el('div', 'offline-note',
                'Player is offline — in-game actions unavailable. Static ID ' +
                (ch.staticid || '?') + ' works on the Bans & Whitelist page.'));
            body.appendChild(ac);
        }

        /* height (ped scale) - live for online players, next-login for offline */
        if (hasPerm('admin_actions_menu')) {
            const hc = el('div', 'card actions-card');
            hc.appendChild(el('div', 'actions-title',
                'Height — current: ' + (ch.scale != null ? Number(ch.scale).toFixed(2) : 'unknown') +
                ' (0.95 short • 1.00 normal • 1.05 tall)' +
                (d.online ? '' : ' — offline: applies on next login')));
            const hf = el('div', 'action-form');
            const hv = el('input', 'narrow');
            hv.placeholder = 'e.g. 1.02';
            if (ch.scale != null) hv.value = String(ch.scale);
            const sendScale = (v) => {
                v = Number(v);
                if (!v || isNaN(v)) return;
                sendAction({ action: 'setscale', target: d.online || 0, charid: ch.charid, scale: v, name: fullName });
                setTimeout(() => post('panelPlayerDetail', { charid: ch.charid }), 700);
            };
            const pbtn = (label, v) => {
                const b = el('button', 'abtn', label);
                b.addEventListener('click', () => sendScale(v));
                return b;
            };
            hf.appendChild(pbtn('Short (0.95)', 0.95));
            hf.appendChild(pbtn('Normal (1.00)', 1.0));
            hf.appendChild(pbtn('Tall (1.05)', 1.05));
            hf.appendChild(hv);
            const setBtn = el('button', 'abtn', 'Set Custom');
            setBtn.addEventListener('click', () => sendScale(hv.value));
            hf.appendChild(setBtn);
            hf.appendChild(el('span', 'offline-note', 'any value 0.1–5.0; far outside 0.95–1.05 can break animations'));
            hc.appendChild(hf);
            body.appendChild(hc);
        }

        /* mail PO Box - works offline: the mail resource is keyed by charid and
           only pushes to the player if they happen to be online. A box is the
           PRIMARY KEY of the mail table, so changing one migrates their letters,
           address book and folders with it.

           Gated to match its own server handlers (vorp_admin:setPoBox and
           :createPoBox both require admin_actions_menu) - it sat outside the
           category system, so the card gating above never reached it. */
        if (hasPerm('admin_actions_menu')) {
            const mc = el('div', 'card actions-card');
            const has = ch.mailbox != null && ch.mailbox !== false;
            mc.appendChild(el('div', 'actions-title',
                'Mail — PO Box: ' + (has ? ch.mailbox : 'none registered')));
            const mf = el('div', 'action-form');
            const mv = el('input', 'narrow');
            const refresh = () => setTimeout(() => post('panelPlayerDetail', { charid: ch.charid }), 700);

            if (has) {
                mv.placeholder = 'new number';
                const mb = el('button', 'abtn', 'Change PO Box');
                mb.addEventListener('click', () => {
                    const v = Number(mv.value);
                    if (!v || v < 1) return;
                    sendAction({ action: 'setpobox', target: 0, charid: ch.charid, box: v, name: fullName });
                    refresh();
                });
                mf.appendChild(mv);
                mf.appendChild(mb);
                mf.appendChild(el('span', 'offline-note',
                    'moves their letters, address book and folders to the new number'));
            } else {
                mv.placeholder = 'blank = next free';
                const mb = el('button', 'abtn', 'Register PO Box');
                mb.addEventListener('click', () => {
                    const raw = mv.value.trim();
                    sendAction({ action: 'createpobox', target: 0, charid: ch.charid,
                        box: raw === '' ? null : Number(raw), name: fullName });
                    refresh();
                });
                mf.appendChild(mv);
                mf.appendChild(mb);
                mf.appendChild(el('span', 'offline-note',
                    'players normally buy their own — this hands one out'));
            }
            mc.appendChild(mf);
            body.appendChild(mc);
        }

        /* danger zone: permanent character deletion.
           Offline only - the server refuses an online character anyway, but
           there is no point offering a button that cannot work. The char id has
           to be typed back in, so this cannot happen on a stray click.

           Gated to match vorp_admin:panelDeleteCharacter, which needs
           delete_character. This card is outside the category system too. */
        if (hasPerm('delete_character')) {
            const dc = el('div', 'card actions-card');
            dc.appendChild(el('div', 'actions-title', 'Danger Zone'));
            if (d.online) {
                dc.appendChild(el('div', 'offline-note',
                    'This character is online. Kick them first to delete it.'));
            } else {
                dc.appendChild(el('div', 'offline-note',
                    'Deletes character ' + ch.charid + ' (' + fullName + ') from the database. ' +
                    'This cannot be undone. Type the character id to confirm.'));
                const df = el('div', 'action-form');
                const cid = el('input', 'narrow');
                cid.placeholder = 'type ' + ch.charid;
                const del = el('button', 'abtn warn', 'Delete Character');
                del.addEventListener('click', () => {
                    if (cid.value.trim() !== String(ch.charid)) {
                        cid.value = '';
                        cid.placeholder = 'type ' + ch.charid + ' exactly';
                        return;
                    }
                    sendAction({ action: 'deletecharacter', target: 0, charid: ch.charid, name: fullName });
                    del.disabled = true;
                    del.textContent = 'Deleted';
                    // back to the list, refreshed, so the row is gone
                    setTimeout(() => {
                        showPage('players');
                        post('panelPlayers', { search: $('#playerSearch').value.trim() });
                    }, 900);
                });
                df.appendChild(cid);
                df.appendChild(del);
                dc.appendChild(df);
            }
            body.appendChild(dc);
        }

        /* info cards */
        const grid1 = el('div', 'info-grid');
        grid1.appendChild(kvCard('Identity', [
            ['Steam', ch.steamname], ['Identifier', ch.identifier],
            ['Static ID', ch.staticid || '—'],
            ['Whitelist', ch.wlstatus || '—'],
            ['Discord ID', (ch.discordid && ch.discordid !== '0') ? ch.discordid : '—'],
            ['Gender', ch.gender], ['Age', ch.age || '—'],
            ['Height (Scale)', ch.scale != null ? Number(ch.scale).toFixed(2) : '—'],
            ['Hours Played', (Math.round((ch.hours || 0) * 10) / 10) + 'h'],
            ['Last Login', fmtDate(ch.lastlogin, true)],
            ['Created', fmtDate(ch.created, true)],
        ]));
        grid1.appendChild(kvCard('Economy', [
            ['Cash', fmtMoney(ch.money)],
            ['Gold', fmt(ch.gold)],
            ['Rol', fmt(ch.rol)],
            ['Bank Total', d.bank ? fmtMoney(d.bank.total) : '—'],
            ...(d.bank && d.bank.accounts ? d.bank.accounts.map(a => ['Bank: ' + a.name, fmtMoney(a.amount)]) : []),
        ]));
        grid1.appendChild(kvCard('Job & Clan', [
            ['Job', ch.job], ['Job Label', ch.joblabel], ['Grade', ch.jobgrade],
            ['Clan', d.clan ? (d.clan.name + ' (#' + d.clan.id + ')') : (ch.clanid > 0 ? ('#' + ch.clanid) : 'None')],
            ['Group', ch.group],
        ]));
        grid1.appendChild(kvCard('Skills & Crafting', [
            ['Weapon Crafting XP', fmt(ch.gunsmith) + ' (pup_gunsmith)'],
            ...(ch.crafting
                ? Object.keys(ch.crafting).sort().map(k =>
                    [k[0].toUpperCase() + k.slice(1), fmt(ch.crafting[k]) + ' xp'])
                : [['Crafting', '—']]),
        ]));
        grid1.appendChild(assetCard('Houses (' + (d.houses || []).length + ')', d.houses, (h) => {
            const a = el('div', 'aitem');
            const left = el('div');
            left.appendChild(el('div', null, 'House #' + h.id + (h.repoed ? ' • REPOSSESSED' : '')));
            const bits = [];
            if (h.role === 'owner') {
                bits.push('bought ' + fmtMoney(h.price || 0));
                bits.push('ledger ' + fmtMoney(h.ledger || 0));
                if (h.taxowed) bits.push('tax owed ' + fmtMoney(h.taxowed));
                if (h.invspace) bits.push(fmt(h.invspace) + ' storage');
                if (h.upgrade) bits.push('upgrade ' + h.upgrade);
                if (h.keys) bits.push(h.keys + ' keyholder' + (h.keys === 1 ? '' : 's'));
            } else {
                bits.push('has a key');
            }
            left.appendChild(el('div', 'sub', bits.join(' • ')));
            a.appendChild(left);
            a.appendChild(el('span', 'chip', h.role));
            return a;
        }));
        body.appendChild(grid1);

        const grid2 = el('div', 'info-grid');
        grid2.appendChild(assetCard('Hideouts (' + (d.hideouts || []).length + ')', d.hideouts, (h) => {
            const a = el('div', 'aitem');
            const left = el('div');
            left.appendChild(el('div', null, 'Hideout #' + h.id + (h.level ? (' • still level ' + h.level) : '')));
            if (h.ledger) left.appendChild(el('div', 'sub', 'ledger ' + fmtMoney(h.ledger)));
            a.appendChild(left);
            a.appendChild(el('span', 'chip', h.role));
            return a;
        }));
        grid2.appendChild(assetCard('Horses (' + (d.horses || []).length + ')', d.horses, (h) => {
            const a = el('div', 'aitem');
            const left = el('div');
            left.appendChild(el('div', null, h.name));
            left.appendChild(el('div', 'sub', h.model));
            a.appendChild(left);
            if (h.out) a.appendChild(el('span', 'chip', 'out'));
            return a;
        }));
        grid2.appendChild(assetCard('Wagons (' + (d.wagons || []).length + ')', d.wagons, (w) => {
            const a = el('div', 'aitem');
            const left = el('div');
            left.appendChild(el('div', null, w.name));
            left.appendChild(el('div', 'sub', w.model));
            a.appendChild(left);
            return a;
        }));
        grid2.appendChild(kvCard('Clan', d.clan ? [
            ['Name', d.clan.name],
            ['ID', '#' + d.clan.id],
            ['Members', fmt(d.clan.members)],
            ['Rank', d.clan.role || '—'],
            ['Clan Cash', fmtMoney(d.clan.cash || 0)],
        ] : [['Membership', 'None']]));
        body.appendChild(grid2);

        /* WHAT THEY RUN - business, ranches, shops. A job alone does not say
           whether they OWN the place, so the boss check is spelled out. */
        const grid3 = el('div', 'info-grid');
        const chip = (text, cls) => el('span', 'chip' + (cls ? ' ' + cls : ''), text);
        const b = d.business;
        const bizCard = () => {
            const c = el('div', 'card info-card');
            c.appendChild(el('div', 'icard-title', 'Business'));
            if (!b) {
                c.appendChild(el('div', 'asset-empty', ch.job && ch.job !== 'unemployed'
                    ? (ch.job + ' — no business is registered under that job')
                    : 'Unemployed'));
                return c;
            }
            const hero = el('div', 'hold-hero');
            hero.appendChild(el('div', 'nm', b.name));
            hero.appendChild(el('span', 'ownchip' + (b.isBoss ? '' : ' staff'),
                b.isBoss ? 'Owner' : 'Staff'));
            c.appendChild(hero);
            c.appendChild(el('div', 'hold-sub',
                b.job + ' • rank ' + b.grade + ' of ' + b.bossrank
                + (b.isBoss ? '' : (' • owned by ' + (b.owner
                    ? (b.owner + ' (char ' + b.ownerid + ')') : 'nobody at boss rank')))));

            const fig = el('div', 'hold-figure');
            fig.appendChild(el('span', 'big', fmtMoney(b.ledger || 0)));
            fig.appendChild(el('span', 'lbl', 'business ledger'));
            c.appendChild(fig);

            const cs = el('div', 'statchips');
            cs.appendChild(chip(fmt(b.staff || 0) + ' employee' + (b.staff === 1 ? '' : 's')));
            cs.appendChild(chip(b.salary
                ? ('pays ' + fmtMoney(b.salary) + (b.taxperiod ? ' / ' + b.taxperiod : ''))
                : 'unpaid rank'));
            cs.appendChild(chip('billing ' + (b.billing ? 'on' : 'off')));
            cs.appendChild(chip(b.taxed ? 'taxed' : 'untaxed'));
            if (b.stash) cs.appendChild(chip('stash: ' + b.stash));
            c.appendChild(cs);
            return c;
        };
        grid3.appendChild(bizCard());

        /* name + role on one line, money under it, then the detail as chips -
           the same shape for ranches and shops so the column reads as a set */
        const holding = (name, role, repoed, moneyLine, chips, foot) => {
            const a = el('div', 'aitem block');
            const top = el('div', 'btop');
            top.appendChild(el('div', 'nm', name));
            top.appendChild(el('span', 'ownchip' + (repoed ? ' bad'
                : (role === 'owner' ? '' : ' staff')), repoed ? 'Repossessed' : role));
            a.appendChild(top);
            if (moneyLine) a.appendChild(el('div', 'sub', moneyLine));
            if (chips && chips.length) {
                const cs = el('div', 'statchips');
                chips.forEach(t => cs.appendChild(chip(t)));
                a.appendChild(cs);
            }
            if (foot) a.appendChild(el('div', 'sub', foot));
            return a;
        };

        grid3.appendChild(assetCard('Ranches (' + (d.ranches || []).length + ')', d.ranches, (r) => {
            const money = [];
            if (r.role === 'owner') money.push(fmtMoney(r.ledger || 0) + ' in the ledger');
            if (r.tax) money.push(fmtMoney(r.tax) + ' tax');
            if (r.milk) money.push(fmt(r.milk) + ' milk');
            if (r.eggs) money.push(fmt(r.eggs) + ' eggs');

            /* each animal as its own chip, so the herd is scannable */
            const chips = (r.breakdown ? r.breakdown.split(', ') : []);
            if (r.livestock) chips.unshift(r.livestock + ' head');

            const who = [];
            if (r.managers) who.push('managers: ' + r.managers);
            if (r.hands) who.push('hands: ' + r.hands);

            return holding(r.name, r.role, r.repoed, money.join('  •  '), chips,
                who.length ? who.join('   ') : 'nobody hired');
        }));

        grid3.appendChild(assetCard('Shops (' + (d.shops || []).length + ')', d.shops, (s) => {
            const money = [fmtMoney(s.ledger || 0) + ' in the ledger'];
            if (s.tax) money.push(fmtMoney(s.tax) + ' tax owed');
            return holding(s.name, s.role, s.repo, money.join('  •  '),
                ['level ' + (s.level || 0)], null);
        }));
        body.appendChild(grid3);

        if (d.missing && d.missing.length) {
            body.appendChild(el('div', 'offline-note', 'Unavailable sections (table missing): ' + d.missing.join(', ')));
        }
    };

    /* ------------------------------------------------------------- tools page */
    let overlayState = { ids: false, blips: false }; // mirrors the client toggles
    const tool = (id, extra) => post('panelTool', Object.assign({ id }, extra || {}));

    const toolCard = (title, sub, build) => {
        const c = el('div', 'card actions-card');
        c.appendChild(el('div', 'actions-title', title + (sub ? (' — ' + sub) : '')));
        build(c);
        return c;
    };
    const toolBtns = (parent, defs) => {
        const grid = el('div', 'actions-grid');
        defs.forEach(([label, id, warn]) => {
            const b = el('button', 'abtn' + (warn ? ' warn' : ''), label);
            b.addEventListener('click', () => tool(id));
            grid.appendChild(b);
        });
        parent.appendChild(grid);
    };

    const buildTools = () => {
        const body = $('#toolsBody');
        body.textContent = '';

        /* admin overlays - local to you, stay on after the panel closes */
        body.appendChild(toolCard('Overlays', 'only you see these; they stay on when the panel closes', (c) => {
            const grid = el('div', 'actions-grid');
            const mk = (label, which) => {
                const b = el('button', 'abtn', label + ': ' + (overlayState[which] ? 'ON' : 'OFF'));
                b.addEventListener('click', () => {
                    fetch(`https://${RES}/panelOverlay`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                        body: JSON.stringify({ which }),
                    }).then(r => r.json()).then(state => {
                        if (state && typeof state === 'object') overlayState = state;
                        b.textContent = label + ': ' + (overlayState[which] ? 'ON' : 'OFF');
                    }).catch(() => {});
                });
                grid.appendChild(b);
            };
            mk('Player IDs', 'ids');
            mk('Player Blips', 'blips');
            c.appendChild(grid);
            c.appendChild(el('div', 'offline-note',
                'Player IDs: name, server id and health above every player within 60m. Player Blips: everyone on the map.'));
        }));

        body.appendChild(toolCard('Player Mode', 'toggles', (c) => {
            toolBtns(c, [
                ['Godmode', 'godmode'], ['Invisible', 'invisible'], ['NoClip', 'noclip'],
                ['Infinite Ammo', 'infiammo'], ['Golden Cores', 'goldencores'],
                ['Heal Self', 'healself'], ['Revive Self', 'reviveself'], ['Dev Laser', 'devlaser'],
            ]);
        }));
        /* ped menu - closes the panel, the list is a pup-ui menu */
        body.appendChild(toolCard('Ped Menu', 'become another ped, or put one on a player', (c) => {
            toolBtns(c, [['Open Ped Menu', 'pedmenu']]);
            c.appendChild(el('div', 'offline-note',
                'Temporary: a relog, a death or /rc puts the real character back. Nothing is saved.'));
        }));
        /* stable admin - closes the panel, the list is a pup-ui menu. Hidden
           without the key: Tools is open to roles that cannot use this. */
        if (hasPerm('stable_admin')) {
            body.appendChild(toolCard('Stable Admin', "a player's horses and wagons", (c) => {
                toolBtns(c, [['Open Stable Admin', 'stableadmin']]);
                c.appendChild(el('div', 'offline-note',
                    'Transfer, fully train, reset coat colour or delete. Deleting is permanent.'));
            }));
        }
        /* prop placer - place a prop by eye and get the coordinate back.
           Closes the panel: the gizmo is a world tool, you need to see it. */
        body.appendChild(toolCard('Prop Placer', 'place a prop and copy where you put it', (c) => {
            const f = el('div', 'action-form');
            const model = el('input');
            model.placeholder = 'type to search 12,400 props (e.g. dynamite)';
            model.style.width = '17vw';
            const pb = el('button', 'abtn', 'Place');
            pb.addEventListener('click', () => {
                const m = model.value.trim();
                if (m) tool('placeprop', { model: m });
            });
            const rb = el('button', 'abtn', 'Repeat Last');
            rb.addEventListener('click', () => tool('placeprop', { model: '' }));
            /* gizmo mode - drag handles instead of a raycast. Blank box repeats
               the last model, same rule as Repeat Last. */
            const gb = el('button', 'abtn', 'Gizmo');
            gb.addEventListener('click', () => tool('placepropgizmo', { model: model.value.trim() }));
            f.appendChild(attachPropSuggest(model)); f.appendChild(pb); f.appendChild(rb); f.appendChild(gb);
            c.appendChild(f);
            c.appendChild(el('div', 'offline-note',
                'PLACE — look where you want it. Arrows nudge distance and height, G snaps to ground, '
                + 'ENTER places, BACKSPACE cancels.'));
            c.appendChild(el('div', 'offline-note',
                'GIZMO — drag handles for precise position AND rotation. T switches move/rotate, '
                + 'WASD/QE flies the camera, F re-centres it on the prop, ALT snaps to ground, '
                + 'ENTER applies, ESC cancels. Use this when the prop has to sit at an angle — '
                + 'it reports pitch and roll, which the camera mode cannot.'));
            c.appendChild(el('div', 'offline-note',
                'Either way the position is copied to your clipboard and printed to F8 in every config format.'));
        }));

        /* zone creator - drives PolyZone's creation flow. Starting closes the
           panel, because the shape is walked out in the world. */
        body.appendChild(toolCard('Zone Creator', 'draw a PolyZone and copy it out', (c) => {
            const f = el('div', 'action-form');
            const zname = el('input');
            zname.placeholder = 'zone name (e.g. valentine_saloon)';
            zname.style.width = '14vw';
            const a = el('input');
            a.placeholder = 'radius / length';
            a.style.width = '7vw';
            const b = el('input');
            b.placeholder = 'width (box only)';
            b.style.width = '7vw';
            f.appendChild(zname); f.appendChild(a); f.appendChild(b);
            c.appendChild(f);

            const start = (kind) => {
                const n = zname.value.trim();
                if (!n) return;
                tool('pzcreate', { kind, zname: n, a: a.value.trim(), b: b.value.trim() });
            };
            const grid = el('div', 'actions-grid');
            const mk = (label, fn, warn) => {
                const btn = el('button', 'abtn' + (warn ? ' warn' : ''), label);
                btn.addEventListener('click', fn);
                grid.appendChild(btn);
            };
            mk('Start Poly', () => start('poly'));
            mk('Start Box', () => start('box'));
            mk('Start Circle', () => start('circle'));
            mk('Add Point', () => tool('pzadd'));
            mk('Undo Point', () => tool('pzundo'));
            mk('Finish', () => tool('pzfinish'));
            mk('Repeat Last', () => tool('pzlast'));
            mk('Cancel', () => tool('pzcancel'), true);
            c.appendChild(grid);

            c.appendChild(el('div', 'offline-note',
                'POLY — name it, press Start Poly, then walk the outline adding a point at every corner. '
                + 'Finish closes the shape. BOX needs a length and a width, CIRCLE needs a radius; '
                + 'leave those boxes empty and it uses 10.'));
            c.appendChild(el('div', 'offline-note',
                'Starting closes the panel, so use /pzadd, /pzundo and /pzfinish while you walk. '
                + 'The buttons above do the same thing if you would rather reopen the panel. '
                + 'Arrow keys nudge the shape, PAGE UP and PAGE DOWN move it vertically.'));
            c.appendChild(el('div', 'offline-note',
                'The finished zone is appended to polyzone_created_zones.txt in the PolyZone '
                + 'resource folder, ready to paste into a config.'));
        }));

        body.appendChild(toolCard('Spawns', 'closes the panel so you can see it', (c) => {
            const f = el('div', 'action-form');
            const horse = el('input'); horse.placeholder = 'horse model (e.g. A_C_Horse_Arabian_White)';
            horse.style.width = '17vw';
            const hb = el('button', 'abtn', 'Spawn Horse');
            hb.addEventListener('click', () => tool('spawnhorse', { model: horse.value.trim() }));
            const wagon = el('input'); wagon.placeholder = 'wagon model';
            const wb = el('button', 'abtn', 'Spawn Wagon');
            wb.addEventListener('click', () => tool('spawnwagon', { model: wagon.value.trim() }));
            f.appendChild(horse); f.appendChild(hb); f.appendChild(wagon); f.appendChild(wb);
            c.appendChild(f);

            /* animals get their own row: unlike the horse, you are not put on it,
               and the field takes a raw hash as well as a model name */
            const f2 = el('div', 'action-form');
            const animal = el('input');
            animal.placeholder = 'animal model or hash (e.g. A_C_Bear_01 or 1682622302)';
            animal.style.width = '24vw';
            const ab = el('button', 'abtn', 'Spawn Animal');
            const doAnimal = () => {
                const v = animal.value.trim();
                if (v) tool('spawnanimal', { model: v });
            };
            ab.addEventListener('click', doAnimal);
            animal.addEventListener('keydown', (e) => { if (e.key === 'Enter') doAnimal(); });
            f2.appendChild(animal); f2.appendChild(ab);
            c.appendChild(f2);
        }));
        body.appendChild(toolCard('Announcement', 'broadcast to everyone', (c) => {
            const f = el('div', 'action-form');
            const text = el('input'); text.placeholder = 'announcement text'; text.style.width = '24vw';
            const b = el('button', 'abtn warn', 'Announce');
            b.addEventListener('click', () => { if (text.value.trim()) { tool('announce', { text: text.value.trim() }); text.value = ''; } });
            f.appendChild(text); f.appendChild(b);
            c.appendChild(f);
        }));
    };

    /* the coord inputs live outside buildTeleports so "use this" can fill them */
    let tpX, tpY, tpZ, tpH;
    let myPos = null;

    /* every shape a config file might want the position in */
    const posFormats = (p) => {
        const n = (v, d) => Number(v || 0).toFixed(d === undefined ? 3 : d);
        const x = n(p.x), y = n(p.y), z = n(p.z), h = n(p.h, 2);
        const gz = (p.groundZ !== undefined && p.groundZ !== null) ? n(p.groundZ) : null;
        return [
            ['Plain',        `${x}, ${y}, ${z}`],
            ['With heading', `${x}, ${y}, ${z}, ${h}`],
            ['vector3',      `vector3(${x}, ${y}, ${z})`],
            ['vector4',      `vector4(${x}, ${y}, ${z}, ${h})`],
            ['Lua table',    `{ x = ${x}, y = ${y}, z = ${z}, h = ${h} }`],
            ['Heading only', h],
            gz ? ['Ground z', gz] : null,
        ].filter(Boolean);
    };

    const renderMyPos = (p) => {
        const host = $('#myPosBody');
        if (!host) return;
        host.textContent = '';
        if (!p) {
            host.appendChild(el('div', 'offline-note', 'Press Read My Position.'));
            return;
        }

        const facts = [
            ['X', Number(p.x).toFixed(3)],
            ['Y', Number(p.y).toFixed(3)],
            ['Z', Number(p.z).toFixed(3)],
            ['Heading', Number(p.h).toFixed(2)],
        ];
        if (p.groundZ !== undefined && p.groundZ !== null) facts.push(['Ground Z', Number(p.groundZ).toFixed(3)]);
        if (p.zone) facts.push(['Zone', p.zone]);
        if (p.interior) facts.push(['Interior', String(p.interior)]);
        if (p.mounted) facts.push(['Mounted', 'yes']);

        const grid = el('div', 'actions-grid');
        facts.forEach(([k, v]) => {
            const row = el('div', 'action-form');
            row.appendChild(el('span', 'chip', k));
            row.appendChild(el('span', null, v));
            row.appendChild(copyBtn(v, k));
            grid.appendChild(row);
        });
        host.appendChild(grid);

        host.appendChild(el('div', 'actions-title', 'Copy as'));
        posFormats(p).forEach(([label, text]) => {
            const row = el('div', 'action-form');
            row.appendChild(el('span', 'chip', label));
            const code = el('span', null, text);
            code.style.fontFamily = 'monospace';
            row.appendChild(code);
            row.appendChild(copyBtn(text, label));
            host.appendChild(row);
        });
    };

    const buildTeleports = () => {
        const body = $('#teleportsBody');
        body.textContent = '';
        body.appendChild(toolCard('Quick Teleports', null, (c) => {
            toolBtns(c, [
                ['To Waypoint', 'tpwaypoint'], ['Auto TPM (toggle)', 'autotpm'],
                ['Back to Last Location', 'tpback'], ['Guarma (toggle)', 'guarma'],
            ]);
        }));

        /* where you are standing, in every format, with a copy button on each */
        body.appendChild(toolCard('My Position', 'read it, copy it, or drop it into the box below', (c) => {
            const f = el('div', 'action-form');
            const read = el('button', 'abtn', 'Read My Position');
            read.addEventListener('click', () => post('panelMyPos'));
            const use = el('button', 'abtn', 'Use in the box below');
            use.addEventListener('click', () => {
                if (!myPos) return;
                if (tpX) tpX.value = Number(myPos.x).toFixed(3);
                if (tpY) tpY.value = Number(myPos.y).toFixed(3);
                if (tpZ) tpZ.value = Number(myPos.z).toFixed(3);
                if (tpH) tpH.value = Number(myPos.h).toFixed(2);
            });
            f.appendChild(read); f.appendChild(use);
            c.appendChild(f);
            const host = el('div'); host.id = 'myPosBody';
            c.appendChild(host);
        }));
        renderMyPos(myPos);

        body.appendChild(toolCard('Teleport to Coordinates', 'heading is optional', (c) => {
            const f = el('div', 'action-form');
            tpX = el('input', 'narrow'); tpX.placeholder = 'x';
            tpY = el('input', 'narrow'); tpY.placeholder = 'y';
            tpZ = el('input', 'narrow'); tpZ.placeholder = 'z';
            tpH = el('input', 'narrow'); tpH.placeholder = 'heading';
            const b = el('button', 'abtn', 'Teleport');
            b.addEventListener('click', () => tool('tpcoords', {
                x: tpX.value, y: tpY.value, z: tpZ.value, h: tpH.value,
            }));
            f.appendChild(tpX); f.appendChild(tpY); f.appendChild(tpZ); f.appendChild(tpH); f.appendChild(b);
            c.appendChild(f);
            c.appendChild(el('div', 'offline-note',
                'Paste any of the formats above straight in - a vector3, a vector4 or a plain list all work.'));

            /* one box that eats any of the formats we hand out */
            const pf = el('div', 'action-form');
            const paste = el('input'); paste.placeholder = 'or paste a whole coordinate here';
            paste.style.width = '22vw';
            const pb = el('button', 'abtn', 'Split');
            pb.addEventListener('click', () => {
                const nums = String(paste.value).match(/-?\d+(\.\d+)?/g) || [];
                if (nums.length >= 3) {
                    tpX.value = nums[0]; tpY.value = nums[1]; tpZ.value = nums[2];
                    if (nums.length >= 4) tpH.value = nums[3];
                    paste.value = '';
                }
            });
            pf.appendChild(paste); pf.appendChild(pb);
            c.appendChild(pf);
        }));
    };

    /* ------------------------------------------------------------- housing page */
    let housingData = null;
    /* ------------------------------------------------------------- banks */
    let bankData = null;
    let bankView = null; // charid while a detail is open - refreshes stay on it

    const bankAct = (payload) => post('panelBankAction', payload);
    const bankTypeLabel = (t) => ({ deposit: 'Deposit', withdraw: 'Withdraw', adminwipe: 'ADMIN WIPE', adminset: 'ADMIN SET' })[t] || (t || '?');

    const bankActivityRow = (a, withName) => el('div', 'offline-note',
        fmtDate(a.ts, true) + ' — ' + (withName ? (a.name || '?') + ' (' + a.charid + '): ' : '')
        + bankTypeLabel(a.type) + ' ' + fmtMoney(a.amount) + ' at ' + (a.bank || '?')
        + ' → balance ' + fmtMoney(a.balance_after)
        + (a.actor && String(a.actor).startsWith('ADMIN') ? ' [' + a.actor + ']' : ''));

    const renderBanks = (data) => {
        const body = $('#banksBody');
        body.textContent = '';
        if (!data || data.missing) {
            body.appendChild(el('div', 'empty', 'No access (needs the manage_bank permission)'));
            return;
        }
        bankData = data;
        const list = data.list || [];
        const banks = data.banks || [];

        if (bankView) {
            const fresh = list.find(x => x.charid === bankView);
            if (fresh) return renderBankDetail(fresh);
            bankView = null;
        }

        const inBanks = list.reduce((n, c) => n + (c.bank || 0), 0);
        const inCash = list.reduce((n, c) => n + (c.cash || 0), 0);
        const richest = list[0];
        const cards = el('div', 'cards small');
        cards.appendChild(card('Accounts', 'characters with money in a bank', valueNode(fmt(list.filter(c => (c.bank || 0) > 0).length)), '⛁'));
        cards.appendChild(card('In Banks', 'every branch added up', valueNode(fmtMoney(inBanks)), '$'));
        cards.appendChild(card('Cash On Hand', 'every satchel added up', valueNode(fmtMoney(inCash)), '$'));
        cards.appendChild(card('Richest', richest ? (richest.name + ' (' + richest.charid + ')') : '—', valueNode(richest ? fmtMoney(richest.bank) : '$0.00'), '♛'));
        body.appendChild(cards);

        const cols = '1.8fr 1fr 1fr .8fr 1.4fr';
        const headRow = el('div', 'table-head');
        headRow.style.gridTemplateColumns = cols;
        ['Character', 'Bank Total', 'Cash', 'Gold', 'Biggest Branch'].forEach(t => headRow.appendChild(el('div', null, t)));
        body.appendChild(headRow);

        const rows = el('div');
        body.appendChild(rows);
        pagedList(rows, list,
            c => (c.name + ' ' + c.charid),
            c => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = cols;
                row.style.cursor = 'pointer';
                row.addEventListener('click', () => renderBankDetail(c));
                const nw = el('div', 'pname');
                const nn = el('div');
                nn.appendChild(el('div', 'n', c.name || ('char ' + c.charid)));
                nn.appendChild(el('div', 's', '#' + c.charid));
                nw.appendChild(nn);
                row.appendChild(nw);
                row.appendChild(el('div', 'pmoney', fmtMoney(c.bank)));
                row.appendChild(el('div', 'pxp', fmtMoney(c.cash)));
                row.appendChild(el('div', 'pxp', String(Number(c.gold || 0).toFixed(2))));
                let top = null;
                banks.forEach(b => {
                    const v = (c.branches || {})[b.col] || 0;
                    if (v > 0 && (!top || v > top.v)) top = { label: b.label, v };
                });
                row.appendChild(el('div', 'pxp', top ? (top.label + ' ' + fmtMoney(top.v)) : '—'));
                return row;
            }, { placeholder: 'Search by character name or ID...' });

        const acC = el('div', 'card actions-card');
        acC.style.marginTop = '.9vw';
        acC.appendChild(el('div', 'actions-title', 'Recent Bank Activity (all characters)'));
        if (!(data.activity || []).length) {
            acC.appendChild(el('div', 'offline-note', 'None recorded'));
        } else {
            pagedList(acC, data.activity,
                a => (a.name || '') + ' ' + (a.charid || '') + ' ' + (a.type || '') + ' ' + (a.bank || '') + ' ' + (a.actor || ''),
                a => bankActivityRow(a, true),
                { per: 10, categoryOf: a => bankTypeLabel(a.type),
                  placeholder: 'Search by name, character ID, branch or action...' });
        }
        body.appendChild(acC);
    };

    const renderBankDetail = (c) => {
        bankView = c.charid;
        const body = $('#banksBody');
        body.textContent = '';
        const banks = (bankData && bankData.banks) || [];

        const back = el('button', 'back-btn', '← Back to banks');
        back.addEventListener('click', () => { bankView = null; post('panelBanks'); });
        body.appendChild(back);

        const pairs = [['Character', c.name + ' (char ' + c.charid + ')'], ['Bank total', fmtMoney(c.bank)],
                       ['Cash on hand', fmtMoney(c.cash)], ['Gold', String(Number(c.gold || 0).toFixed(2))]];
        banks.forEach(b => pairs.push([b.label + ' Bank', fmtMoney((c.branches || {})[b.col] || 0)]));
        body.appendChild(kvCard('Money', pairs));

        const prof = el('div', 'action-form');
        const pb = el('button', 'abtn', 'Open character profile');
        pb.addEventListener('click', () => openDetail(Number(c.charid)));
        prof.appendChild(pb);
        body.appendChild(prof);

        /* per-branch set / wipe */
        const bc = el('div', 'card actions-card');
        bc.appendChild(el('div', 'actions-title', 'Branches'));
        banks.forEach(b => {
            const f = el('div', 'action-form');
            f.appendChild(el('span', 'chip', b.label));
            const inp = el('input', 'narrow'); inp.value = String(((c.branches || {})[b.col] || 0).toFixed(2));
            const set = el('button', 'abtn', 'Set');
            set.addEventListener('click', () => {
                const v = Number(inp.value);
                if (!isNaN(v) && v >= 0) bankAct({ action: 'setbank', charid: c.charid, bank: b.col, value: v });
            });
            const wipe = el('button', 'abtn warn', 'Wipe');
            wipe.addEventListener('click', () => bankAct({ action: 'wipebank', charid: c.charid, bank: b.col }));
            f.appendChild(inp); f.appendChild(set);
            if (hasPerm('wipe_money')) f.appendChild(wipe);
            bc.appendChild(f);
        });
        body.appendChild(bc);

        /* cash + wipe everything */
        const cc = el('div', 'card actions-card');
        cc.appendChild(el('div', 'actions-title', 'Cash and full wipe'));
        const f1 = el('div', 'action-form');
        f1.appendChild(el('span', 'chip', 'Cash'));
        const cashI = el('input', 'narrow'); cashI.value = String(Number(c.cash || 0).toFixed(2));
        const cs = el('button', 'abtn', 'Set Cash');
        cs.addEventListener('click', () => {
            const v = Number(cashI.value);
            if (!isNaN(v) && v >= 0) bankAct({ action: 'setcash', charid: c.charid, value: v });
        });
        const cw = el('button', 'abtn warn', 'Wipe Cash');
        cw.addEventListener('click', () => askConfirm({
            title: 'Wipe cash for ' + c.name + '?',
            body: 'Their satchel money goes to <b>$0.00</b>. Online characters lose it on the spot.',
            okLabel: 'Wipe cash', danger: true,
            onOk: () => bankAct({ action: 'wipecash', charid: c.charid }),
        }));
        f1.appendChild(cashI); f1.appendChild(cs);
        if (hasPerm('wipe_money')) f1.appendChild(cw);
        cc.appendChild(f1);

        const f2 = el('div', 'action-form');
        const wa = el('button', 'abtn warn', 'Wipe ALL bank money');
        wa.addEventListener('click', () => askConfirm({
            title: 'Wipe every bank account for ' + c.name + '?',
            body: '<b>' + fmtMoney(c.bank) + '</b> across every branch goes to $0.00. This <b>cannot be undone</b>; a ledger row is written under your name.',
            okLabel: 'Wipe all branches', danger: true,
            onOk: () => bankAct({ action: 'wipebank', charid: c.charid }),
        }));
        if (hasPerm('wipe_money')) f2.appendChild(wa);
        f2.appendChild(el('span', 'offline-note', 'cash edits reach an online player immediately; bank edits apply next time they use a teller'));
        cc.appendChild(f2);
        body.appendChild(cc);

        /* this character's ledger */
        const mine = ((bankData && bankData.activity) || []).filter(a => a.charid === c.charid);
        const acC = el('div', 'card actions-card');
        acC.appendChild(el('div', 'actions-title', 'Ledger (' + mine.length + ')'));
        if (!mine.length) {
            acC.appendChild(el('div', 'offline-note', 'None recorded'));
        } else {
            pagedList(acC, mine,
                a => (a.type || '') + ' ' + (a.bank || '') + ' ' + (a.actor || ''),
                a => bankActivityRow(a, false),
                { per: 10, categoryOf: a => bankTypeLabel(a.type), placeholder: 'Search by branch or action...' });
        }
        body.appendChild(acC);
    };

    /* --------------------------------------------------------------- curses */
    const renderCurses = (data) => {
        const body = $('#cursesBody');
        body.textContent = '';
        if (!data || data.missing) {
            body.appendChild(el('div', 'empty', data && data.missing ? 'pup_shaman is not running' : 'No access (needs the manage_curses permission)'));
            return;
        }
        const defs = data.curses || [];
        const defOf = (key) => defs.find(c => c.key === key);
        const labelOf = (key) => (defOf(key) ? defOf(key).label : key);
        const online = data.players || [];
        const offline = data.offline || [];
        const cursedNow = online.filter(p => p.curse);

        const cards = el('div', 'cards small');
        cards.appendChild(card('Online', 'players with a character loaded', valueNode(fmt(online.length)), '☺'));
        cards.appendChild(card('Cursed Online', 'carrying a curse right now', valueNode(fmt(cursedNow.length)), '☾'));
        cards.appendChild(card('Cursed Offline', 'carrying one, not on right now', valueNode(fmt(offline.length)), '☾'));
        body.appendChild(cards);

        const cols = '1.5fr .8fr 1fr 2.6fr';
        const headRow = el('div', 'table-head');
        headRow.style.gridTemplateColumns = cols;
        ['Player', 'Character', 'Curse', 'Actions'].forEach(t => headRow.appendChild(el('div', null, t)));
        body.appendChild(headRow);

        /* carriers first: they are usually who staff came here for */
        const list = online.map(p => Object.assign({ on: true }, p))
            .sort((a, b) => (a.curse ? 0 : 1) - (b.curse ? 0 : 1) || String(a.name).localeCompare(String(b.name)))
            .concat(offline.map(p => Object.assign({ on: false }, p)));

        const act = (payload) => post('panelCurseAction', payload);
        const rows = el('div');
        body.appendChild(rows);
        pagedList(rows, list,
            p => [p.name, p.steam, p.charid, p.src, p.curse, p.curse ? labelOf(p.curse) : 'none', p.on ? 'online' : 'offline'].join(' '),
            p => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = cols;
                const nw = el('div');
                nw.appendChild(el('div', 'n', p.name || '?'));
                nw.appendChild(el('div', 's', p.on ? (p.steam + ' / server id ' + p.src) : 'offline'));
                const pn = el('div', 'pname');
                pn.appendChild(nw);
                row.appendChild(pn);
                row.appendChild(el('div', 'pxp', String(p.charid)));
                const cc = el('div');
                if (p.curse) cc.appendChild(el('span', 'chip', labelOf(p.curse)));
                else cc.appendChild(el('span', 'pxp', 'None'));
                row.appendChild(cc);

                const f = el('div', 'action-form');
                const who = escHtml(p.name || 'this character');
                if (p.on) {
                    const sel = el('select');
                    defs.forEach((c) => {
                        const o = el('option', null, c.label);
                        o.value = c.key;
                        sel.appendChild(o);
                    });
                    f.appendChild(sel);
                    const give = el('button', 'abtn', p.curse ? 'Replace' : 'Give');
                    give.addEventListener('click', () => {
                        const key = sel.value;
                        askConfirm({
                            title: (p.curse ? 'Replace the curse on ' : 'Curse ') + (p.name || 'this character') + '?',
                            body: '<b>' + escHtml(labelOf(key)) + '</b> takes hold on ' + who + ' straight away, and they are told.',
                            okLabel: p.curse ? 'Replace' : 'Give Curse',
                            onOk: () => act({ action: 'give', src: p.src, curse: key }),
                        });
                    });
                    f.appendChild(give);
                }
                const def = defOf(p.curse);
                if (p.on && def && def.harmful) {
                    const ease = el('button', 'abtn', 'Ease');
                    ease.title = 'Wind this curse back to an early step';
                    ease.addEventListener('click', () => act({ action: 'ease', src: p.src }));
                    f.appendChild(ease);
                }
                if (p.curse) {
                    const cl = el('button', 'abtn warn', 'Cleanse');
                    cl.addEventListener('click', () => askConfirm({
                        title: 'Cleanse ' + (p.name || 'this character') + '?',
                        body: 'Removes <b>' + escHtml(labelOf(p.curse)) + '</b> from ' + who + '.',
                        okLabel: 'Cleanse',
                        onOk: () => act(p.on ? { action: 'cleanse', src: p.src } : { action: 'cleanse', charid: p.charid }),
                    }));
                    f.appendChild(cl);
                }
                row.appendChild(f);
                return row;
            }, { placeholder: 'Search by name, Steam name, char id, server id or curse...',
                 categoryOf: p => (p.curse ? labelOf(p.curse) : 'No curse') });
    };

    /* ---------------------------------------------------------------- farms */
    let farmData = null;
    let farmView = null; // the grower's char id while their plants are open - refreshes stay on it

    const plantGrowth = (p) => {
        if (p.ripe) return 'Ripe';
        const m = Math.max(0, Number(p.left) || 0);
        return m >= 60 ? Math.floor(m / 60) + 'h ' + (m % 60) + 'm left' : m + ' min left';
    };

    const renderFarms = (data) => {
        const body = $('#farmsBody');
        body.textContent = '';
        if (!data || data.missing) {
            body.appendChild(el('div', 'empty', data && data.missing ? 'pup_homestead is not running' : 'No access (needs the manage_farms permission)'));
            return;
        }
        farmData = data;
        const plants = data.plants || [];
        const growers = data.growers || [];

        if (farmView !== null) {
            const g = growers.find(x => x.charid === farmView);
            if (g) return renderFarmGrower(g);
            farmView = null;
        }

        const cards = el('div', 'cards small');
        cards.appendChild(card('Plants', 'everything in the ground', valueNode(fmt(plants.length)), '✿'));
        cards.appendChild(card('Growers', 'characters with a plant down', valueNode(fmt(growers.length)), '☺'));
        cards.appendChild(card('Ripe', 'ready to harvest', valueNode(fmt(plants.filter(p => p.ripe).length)), '✓'));
        cards.appendChild(card('Unwatered', 'still growing, not watered', valueNode(fmt(plants.filter(p => !p.ripe && !p.watered).length)), '◌'));
        body.appendChild(cards);

        const cols = '1.6fr .7fr .6fr .6fr 2.2fr';
        const headRow = el('div', 'table-head');
        headRow.style.gridTemplateColumns = cols;
        ['Grower', 'Status', 'Plants', 'Ripe', 'Crops'].forEach(t => headRow.appendChild(el('div', null, t)));
        body.appendChild(headRow);

        const mine = (g) => plants.filter(p => p.owner === g.charid);
        const cropsOf = (g) => {
            const n = {};
            mine(g).forEach((p) => { n[p.crop] = (n[p.crop] || 0) + 1; });
            return Object.keys(n).sort().map(c => n[c] + ' ' + c).join(', ');
        };
        const rows = el('div');
        body.appendChild(rows);
        pagedList(rows, growers,
            g => [g.name, g.charid, cropsOf(g)].join(' '),
            g => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = cols;
                row.style.cursor = 'pointer';
                row.addEventListener('click', () => renderFarmGrower(g));
                const pn = el('div', 'pname');
                const nn = el('div');
                nn.appendChild(el('div', 'n', g.name));
                nn.appendChild(el('div', 's', 'char ' + g.charid));
                pn.appendChild(nn);
                row.appendChild(pn);
                row.appendChild(el('div', 'pxp', g.online ? 'Online' : 'Offline'));
                row.appendChild(el('div', 'pxp', fmt(mine(g).length)));
                row.appendChild(el('div', 'pxp', fmt(mine(g).filter(p => p.ripe).length)));
                row.appendChild(el('div', 'pxp', cropsOf(g)));
                return row;
            }, { placeholder: 'Search by name, char id or crop...' });
    };

    const renderFarmGrower = (g) => {
        farmView = g.charid;
        const body = $('#farmsBody');
        body.textContent = '';
        const plants = ((farmData && farmData.plants) || []).filter(p => p.owner === g.charid);

        const back = el('button', 'back-btn', '← Back to growers');
        back.addEventListener('click', () => { farmView = null; post('panelFarms'); });
        body.appendChild(back);

        const who = el('div', 'action-form');
        who.appendChild(el('span', 'chip', g.online ? 'Online' : 'Offline'));
        who.appendChild(el('span', null, g.name + ' (char ' + g.charid + '), ' + plants.length + ' plant' + (plants.length === 1 ? '' : 's')));
        const prof = el('button', 'abtn', 'Profile');
        prof.addEventListener('click', () => openDetail(Number(g.charid)));
        who.appendChild(prof);
        const clear = el('button', 'abtn warn', 'Pull Up All');
        clear.addEventListener('click', () => askConfirm({
            title: 'Pull up every plant of ' + g.name + '?',
            body: 'All <b>' + plants.length + '</b> plants are removed from the ground, and nothing is paid back. This <b>cannot be undone</b>.',
            okLabel: 'Pull Up All',
            onOk: () => post('panelFarmAction', { action: 'clearchar', charid: g.charid }),
        }));
        who.appendChild(clear);
        body.appendChild(who);

        const cols = '1.3fr .9fr .6fr 1.5fr 1.4fr';
        const headRow = el('div', 'table-head');
        headRow.style.gridTemplateColumns = cols;
        ['Crop', 'Growth', 'Health', 'Care', 'Actions'].forEach(t => headRow.appendChild(el('div', null, t)));
        body.appendChild(headRow);

        const rows = el('div');
        body.appendChild(rows);
        pagedList(rows, plants,
            p => [p.crop, p.id, p.ripe ? 'ripe' : 'growing'].join(' '),
            p => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = cols;
                const pn = el('div', 'pname');
                const nn = el('div');
                nn.appendChild(el('div', 'n', p.crop));
                nn.appendChild(el('div', 's', 'plant ' + p.id + (p.gang ? ' / gang crop' : '')));
                pn.appendChild(nn);
                row.appendChild(pn);
                row.appendChild(el('div', 'pxp', plantGrowth(p)));
                row.appendChild(el('div', 'pxp', fmt(p.health || 0)));
                const care = el('div');
                [['Watered', p.watered], ['Fed', p.fert], ['Trimmed', p.trim]].forEach(([t, on]) => { if (on) care.appendChild(el('span', 'chip', t)); });
                if (!care.childNodes.length) care.appendChild(el('span', 'pxp', 'None yet'));
                row.appendChild(care);
                const f = el('div', 'action-form');
                const go = el('button', 'abtn', 'Go To');
                go.addEventListener('click', () => post('panelHideoutGoto', { x: p.x, y: p.y, z: p.z }));
                f.appendChild(go);
                const rm = el('button', 'abtn warn', 'Pull Up');
                rm.addEventListener('click', () => askConfirm({
                    title: 'Pull up this ' + p.crop + '?',
                    body: 'Plant <b>' + escHtml(p.id) + '</b> of ' + escHtml(g.name) + ' is removed from the ground. This <b>cannot be undone</b>.',
                    okLabel: 'Pull Up',
                    onOk: () => post('panelFarmAction', { action: 'remove', id: p.id }),
                }));
                f.appendChild(rm);
                row.appendChild(f);
                return row;
            }, { placeholder: 'Search by crop or plant id...', categoryOf: p => p.crop });
    };

    /* "Open storage" card, shared by stores, camps, houses, societies and hideouts. The
       stored items are not listed here any more: the button opens the REAL
       inventory grid (the panel closes first) with the owner's controls, and the
       owning resource checks the permission again and logs the open. summary is
       plain text (textContent), never HTML. */
    const storageCard = (title, label, summary, note, onOpen) => {
        const c = el('div', 'card actions-card');
        c.appendChild(el('div', 'actions-title', title));
        const f = el('div', 'action-form');
        const b = el('button', 'abtn', label);
        b.style.fontSize = '.9vw';
        b.style.padding = '.6vw 1.6vw';
        b.addEventListener('click', onOpen);
        f.appendChild(b);
        const sum = el('span', 'offline-note', summary || '');
        f.appendChild(sum);
        c.appendChild(f);
        if (note) c.appendChild(el('div', 'offline-note', note));
        c.summary = sum;
        return c;
    };

    /* ------------------------------------------------------------- hideouts */
    let hideoutData = null;
    let hideoutView = null; // hideout id while a detail is open - refreshes stay on it

    /* Mirrors the server's destructive-action tables. The server is what actually
       enforces this; refusing here just saves a round trip and says why. */
    const DESTRUCTIVE = {
        hideout: ['delete', 'wipestash', 'wipeledger', 'clearproduction', 'setledger',
                  'removeitem', 'evict', 'setowner', 'removecoowner'],
        camp:    ['delete', 'wipestash', 'wipeledger', 'wipetax', 'repo', 'setledger',
                  'settax', 'removeitem', 'removemember', 'setleader'],
        house:   ['delete', 'seize', 'transfer', 'repo', 'removekey'],
    };
    const guardAct = (kind, perm, send) => (payload) => {
        if (DESTRUCTIVE[kind].includes(payload && payload.action) && !hasPerm(perm)) {
            showPanelToast({ text: 'That is Management only.', error: true });
            return;
        }
        send(payload);
    };

    const hideoutAct = guardAct('hideout', 'delete_hideout',
        (payload) => post('panelHideoutAction', payload));
    const hideoutStatus = (h) => {
        const s = [];
        if (!h.owned) s.push('for sale');
        if (h.raidOpen) s.push('raided');
        if (h.raidCooldown) s.push('raid cooldown');
        if (h.mash) s.push('mashing');
        if (h.still) s.push('distilling');
        if ((h.inside || []).length) s.push(h.inside.length + ' inside');
        return s;
    };
    const timeLeft = (endsAt, now) => {
        const s = Math.max(0, (Number(endsAt) || 0) - (Number(now) || 0));
        if (s <= 0) return 'due';
        const m = Math.floor(s / 60);
        return m >= 60 ? Math.floor(m / 60) + 'h ' + (m % 60) + 'm' : m + 'm ' + (s % 60) + 's';
    };

    const renderHideouts = (data) => {
        const body = $('#hideoutsBody');
        body.textContent = '';
        if (!data || data.missing) {
            body.appendChild(el('div', 'empty', data && data.missing ? 'pup_hideouts is not running' : 'No access (needs the manage_hideouts permission)'));
            return;
        }
        hideoutData = data;
        const list = data.list || [];

        if (hideoutView !== null) {
            const fresh = list.find(x => x.id === hideoutView);
            if (fresh) return renderHideoutDetail(fresh);
            hideoutView = null;
        }

        const ownedN = list.filter(h => h.owned).length;
        const ledger = list.reduce((n, h) => n + (h.ledger || 0), 0);
        const stash = list.reduce((n, h) => n + (h.stashTotal || 0), 0);
        const inside = list.reduce((n, h) => n + (h.inside || []).length, 0);
        const cards = el('div', 'cards small');
        cards.appendChild(card('Hideouts', ownedN + ' owned, ' + (list.length - ownedN) + ' for sale', valueNode(fmt(list.length)), '⌂'));
        cards.appendChild(card('In Ledgers', 'every hideout ledger added up', valueNode(fmtMoney(ledger)), '$'));
        cards.appendChild(card('Stashed Items', 'every stash added up', valueNode(fmt(stash)), '▦'));
        cards.appendChild(card('Inside Now', 'players in a hideout right now', valueNode(fmt(inside)), '☺'));
        body.appendChild(cards);

        const cols = '1.6fr 1.4fr .8fr .9fr .7fr 1.4fr';
        const headRow = el('div', 'table-head');
        headRow.style.gridTemplateColumns = cols;
        ['Hideout', 'Owner', 'Zone', 'Ledger', 'Stash', 'Status'].forEach(t => headRow.appendChild(el('div', null, t)));
        body.appendChild(headRow);

        const rows = el('div');
        body.appendChild(rows);
        pagedList(rows, list,
            h => [h.name, h.id, h.zone, h.owner && h.owner.name, h.owner && h.owner.charid]
                .concat((h.coowners || []).map(c => c.name + ' ' + c.charid)).join(' '),
            h => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = cols;
                row.style.cursor = 'pointer';
                row.addEventListener('click', () => renderHideoutDetail(h));
                const nw = el('div', 'pname');
                const nn = el('div');
                nn.appendChild(el('div', 'n', h.name || ('Hideout ' + h.id)));
                nn.appendChild(el('div', 's', '#' + h.id));
                nw.appendChild(nn);
                row.appendChild(nw);
                row.appendChild(el('div', 'pxp', h.owner ? (h.owner.name + ' (' + h.owner.charid + ')') : '—'));
                row.appendChild(el('div', 'pxp', h.zone || '—'));
                row.appendChild(el('div', 'pmoney', fmtMoney(h.ledger)));
                row.appendChild(el('div', 'pxp', fmt(h.stashTotal || 0) + '/' + fmt(h.invslots || 0)));
                const st = el('div');
                hideoutStatus(h).forEach(s => st.appendChild(el('span', 'chip', s)));
                if (!st.childNodes.length) st.appendChild(el('span', 'pxp', 'quiet'));
                row.appendChild(st);
                return row;
            }, { placeholder: 'Search by hideout, owner, co-owner or zone...', categoryOf: h => h.zone || '' });
    };

    const renderHideoutDetail = (h) => {
        hideoutView = h.id;
        const body = $('#hideoutsBody');
        body.textContent = '';
        const now = (hideoutData && hideoutData.now) || 0;
        const c = h.coords || {};

        const back = el('button', 'back-btn', '← Back to hideouts');
        back.addEventListener('click', () => { hideoutView = null; post('panelHideouts'); });
        body.appendChild(back);

        // upgrades arrive as a list or as a keyed table, depending on how the hideout bought them
        const upgrades = (() => {
            const u = h.upgrades;
            if (Array.isArray(u)) {
                return u.length ? u.map(x => (x && typeof x === 'object') ? (x.name || x.label || x.key || JSON.stringify(x)) : String(x)).join(', ') : 'None';
            }
            if (u && typeof u === 'object') {
                const keys = Object.keys(u).filter(k => u[k]);
                return keys.length ? keys.join(', ') : 'None';
            }
            return 'None';
        })();
        body.appendChild(kvCard('Hideout', [
            ['Hideout', (h.name || 'Hideout') + ' (#' + h.id + ')'],
            ['Zone', h.zone || '—'],
            ['Status', h.owned ? 'Owned' : ('For sale' + (h.price ? ' at ' + fmtMoney(h.price) : ''))],
            ['Ledger', fmtMoney(h.ledger)],
            ['Stash', fmt(h.stashTotal || 0) + ' of ' + fmt(h.invslots || 0) + ' slots (storage level ' + (h.invlevel || 0) + ')'],
            ['Still level', String(h.stilllevel || 0)],
            ['Bookie', h.bookie ? 'Installed' : 'No'],
            ['Upgrades', upgrades],
            ['Theme', h.theme || 'Default'],
            ['Own Discord log', h.haswebhook ? 'Set by the owner' : 'Not set'],
            ['Entrance', (c.x !== undefined) ? Number(c.x).toFixed(1) + ', ' + Number(c.y).toFixed(1) + ', ' + Number(c.z).toFixed(1) : '—'],
        ]));

        body.appendChild(kvCard('Raids and production', [
            ['Raid', h.raidOpen
                ? ('OPEN since ' + fmtDate(h.raidOpenedAt, true) + ' (anyone can walk in for ' + ((hideoutData && hideoutData.raidWindow) || 20) + ' min)')
                : 'Closed'],
            ['Raid cooldown', h.raidCooldown
                ? ('Active since ' + fmtDate(h.raidDay, true) + ' (' + ((hideoutData && hideoutData.raidDays) || 3) + ' days)')
                : 'None'],
            ['Mash', h.mash ? ((h.mash.qt ? h.mash.qt + ' x ' : '') + (h.mash.label || '?') + ', ' + timeLeft(h.mash.endsAt, now) + ' left') : 'Idle'],
            ['Still', h.still ? ((h.still.qt ? h.still.qt + ' x ' : '') + (h.still.label || '?') + ', ' + timeLeft(h.still.endsAt, now) + ' left') : 'Idle'],
            ['Mission cooldown', h.missionCooldown ? timeLeft(h.missionCooldown, now) + ' left' : 'None'],
        ]));

        /* members */
        const mc = el('div', 'card actions-card');
        mc.appendChild(el('div', 'actions-title', 'Members'));
        const memberRow = (role, name, charid, onRemove) => {
            const f = el('div', 'action-form');
            f.appendChild(el('span', 'chip', role));
            f.appendChild(el('span', null, (name || '?') + (charid ? ' (' + charid + ')' : '')));
            if (charid) {
                const pb = el('button', 'abtn', 'Profile');
                pb.addEventListener('click', () => openDetail(Number(charid)));
                f.appendChild(pb);
            }
            if (onRemove) {
                const rb = el('button', 'abtn warn', 'Remove');
                rb.addEventListener('click', onRemove);
                f.appendChild(rb);
            }
            return f;
        };
        if (h.owner) mc.appendChild(memberRow('Owner', h.owner.name, h.owner.charid, null));
        else mc.appendChild(el('div', 'offline-note', 'No owner - this hideout is for sale'));
        (h.coowners || []).forEach(co => mc.appendChild(memberRow('Co-owner', co.name, co.charid,
            () => hideoutAct({ action: 'removecoowner', id: h.id, charid: co.charid }))));
        (h.inside || []).forEach(p => mc.appendChild(memberRow('Inside now', p.name, p.charid, null)));

        const af = el('div', 'action-form');
        const cid = el('input', 'narrow'); cid.placeholder = 'character ID';
        const addB = el('button', 'abtn', 'Add co-owner');
        addB.addEventListener('click', () => {
            const v = Number(cid.value);
            if (v > 0) hideoutAct({ action: 'addcoowner', id: h.id, charid: v });
        });
        const ownB = el('button', 'abtn warn', 'Make owner');
        ownB.addEventListener('click', () => {
            const v = Number(cid.value);
            if (!(v > 0)) return;
            askConfirm({
                title: 'Transfer ' + (h.name || 'this hideout') + ' to character ' + v + '?',
                body: 'The current owner loses the hideout. Co-owners stay.',
                okLabel: 'Transfer', danger: true,
                onOk: () => hideoutAct({ action: 'setowner', id: h.id, charid: v }),
            });
        });
        af.appendChild(cid); af.appendChild(addB); af.appendChild(ownB);
        af.appendChild(el('span', 'offline-note', 'works on offline characters'));
        mc.appendChild(af);
        body.appendChild(mc);

        /* stash: the real hideout stash panel, not a list */
        const sc = storageCard('Stash', 'Open storage',
            fmt(h.stashTotal || 0) + ' of ' + fmt(h.invslots || 0) + ' slots used, '
            + fmt((h.items || []).length) + ' stack(s)',
            'Closes the panel and opens this hideout\'s real stash with the owner\'s controls: '
            + 'take items out or put them in, from anywhere. You are not made a co-owner. Logged.',
            () => post('panelHideoutOpenStash', { id: h.id }));
        if ((h.items || []).length && hasPerm('delete_hideout')) {
            const wf = el('div', 'action-form');
            const wb = el('button', 'abtn warn', 'Wipe stash');
            wb.addEventListener('click', () => askConfirm({
                title: 'Wipe the stash of ' + (h.name || 'this hideout') + '?',
                body: '<b>' + fmt(h.stashTotal || 0) + '</b> items are deleted. This <b>cannot be undone</b>.',
                okLabel: 'Wipe stash', danger: true,
                onOk: () => hideoutAct({ action: 'wipestash', id: h.id }),
            }));
            wf.appendChild(wb);
            sc.appendChild(wf);
        }
        body.appendChild(sc);

        /* actions */
        const ac = el('div', 'card actions-card');
        ac.appendChild(el('div', 'actions-title', 'Actions'));

        const f0 = el('div', 'action-form');
        const gb = el('button', 'abtn', 'Go to entrance');
        gb.addEventListener('click', () => post('panelHideoutGoto', { x: c.x, y: c.y, z: c.z }));
        f0.appendChild(gb);

        /* stand where you want it, then press this. The server reads the coords
           off your own ped, so the panel never dictates them. */
        const mv = el('button', 'abtn', 'Move hideout here');
        mv.addEventListener('click', () => askConfirm({
            title: 'Move ' + (h.name || 'this hideout') + ' to where you are standing?',
            body: 'The entrance and its blip move to your current position. Nothing else changes.',
            okLabel: 'Move it',
            onOk: () => hideoutAct({ action: 'movehere', id: h.id }),
        }));
        f0.appendChild(mv);
        if (h.raidOpen) {
            const eb = el('button', 'abtn', 'End raid now');
            eb.addEventListener('click', () => hideoutAct({ action: 'endraid', id: h.id }));
            f0.appendChild(eb);
        }
        if (h.raidCooldown) {
            const rb = el('button', 'abtn', 'Reset raid cooldown');
            rb.addEventListener('click', () => hideoutAct({ action: 'resetcooldown', id: h.id }));
            f0.appendChild(rb);
        }
        if (h.mash || h.still) {
            const pb = el('button', 'abtn warn', 'Cancel production');
            pb.addEventListener('click', () => askConfirm({
                title: 'Cancel the mash / still at ' + (h.name || 'this hideout') + '?',
                body: 'The batch in progress is lost. Ingredients are <b>not</b> refunded.',
                okLabel: 'Cancel production', danger: true,
                onOk: () => hideoutAct({ action: 'clearproduction', id: h.id }),
            }));
            if (hasPerm('delete_hideout')) f0.appendChild(pb);
        }
        ac.appendChild(f0);

        const f1 = el('div', 'action-form');
        f1.appendChild(el('span', 'chip', 'Ledger'));
        const li = el('input', 'narrow'); li.value = String(Math.floor(h.ledger || 0));
        const ls = el('button', 'abtn', 'Set');
        ls.addEventListener('click', () => {
            const v = Number(li.value);
            if (!isNaN(v) && v >= 0) hideoutAct({ action: 'setledger', id: h.id, value: v });
        });
        const lw = el('button', 'abtn warn', 'Wipe');
        lw.addEventListener('click', () => askConfirm({
            title: 'Wipe the ledger of ' + (h.name || 'this hideout') + '?',
            body: '<b>' + fmtMoney(h.ledger) + '</b> goes to $0.00.',
            okLabel: 'Wipe ledger', danger: true,
            onOk: () => hideoutAct({ action: 'wipeledger', id: h.id }),
        }));
        f1.appendChild(li); f1.appendChild(ls);
        if (hasPerm('delete_hideout')) f1.appendChild(lw);
        ac.appendChild(f1);

        const f2 = el('div', 'action-form');
        f2.appendChild(el('span', 'chip', 'Name'));
        const ni = el('input'); ni.value = h.name || '';
        const nb = el('button', 'abtn', 'Rename');
        nb.addEventListener('click', () => {
            const v = ni.value.trim();
            if (v) hideoutAct({ action: 'rename', id: h.id, name: v });
        });
        f2.appendChild(ni); f2.appendChild(nb);
        ac.appendChild(f2);

        const f3 = el('div', 'action-form');
        if (h.owned) {
            const ev = el('button', 'abtn warn', 'Evict (put back up for sale)');
            ev.addEventListener('click', () => askConfirm({
                title: 'Evict everyone from ' + (h.name || 'this hideout') + '?',
                body: 'Owner, co-owners, ledger, stash and production are cleared and it goes back on sale. Upgrades stay with the building. This <b>cannot be undone</b>.',
                okLabel: 'Evict', danger: true,
                onOk: () => hideoutAct({ action: 'evict', id: h.id }),
            }));
            f3.appendChild(ev);
        }
        const del = el('button', 'abtn warn', 'Delete hideout');
        del.addEventListener('click', () => askConfirm({
            title: 'Delete ' + (h.name || 'hideout') + ' (#' + h.id + ')?',
            body: 'The hideout, its ledger and its stash are removed from the map for good. This <b>cannot be undone</b>.',
            okLabel: 'Delete', danger: true,
            onOk: () => { hideoutView = null; hideoutAct({ action: 'delete', id: h.id }); },
        }));
        if (hasPerm('delete_hideout')) f3.appendChild(del);
        ac.appendChild(f3);
        body.appendChild(ac);
    };

    let housingView = null; // house id while a detail is open - refreshes stay on it

    const houseAct = guardAct('house', 'delete_housing',
        (payload) => post('panelHousingAction', payload));
    const houseName = (names, cid) => (names && names[cid]) || ('char ' + cid);

    const renderHousing = (data) => {
        const body = $('#housingBody');
        body.textContent = '';
        if (!data || data.missing) {
            body.appendChild(el('div', 'empty', data && data.missing ? 'pup_realestate is not running' : 'No access (needs the manage_housing permission)'));
            return;
        }
        housingData = data;
        const names = data.names || {};
        const auctions = data.auctions || {};

        // a detail was open: stay on it with the FRESH row (refreshes after
        // actions must not bounce the admin back to the list)
        if (housingView) {
            const fresh = (data.list || []).find(x => x.id === housingView);
            if (fresh) return renderHouseDetail(fresh);
            housingView = null; // deleted - fall through to the list
        }

        const toolBar = el('div', 'action-form');
        const toolBtn = el('button', 'abtn', 'Create House (starts the in-world door capture)');
        toolBtn.addEventListener('click', () => post('panelOpenTool', { tool: 'housing' }));
        toolBar.appendChild(toolBtn);
        body.appendChild(toolBar);

        const owned = data.list.filter(h => h.owned).length;
        const cards = el('div', 'cards small');
        cards.appendChild(card('Total', 'houses + motel rooms', valueNode(fmt(data.list.length)), '⌂'));
        cards.appendChild(card('Owned', '', valueNode(fmt(owned)), '✔'));
        cards.appendChild(card('For Sale', '', valueNode(fmt(data.list.filter(h => !h.owned && !h.motel).length)), '$'));
        cards.appendChild(card('On Auction', '', valueNode(fmt(Object.keys(auctions).length)), '⚖'));
        body.appendChild(cards);

        const headRow = el('div', 'table-head');
        headRow.style.gridTemplateColumns = '1.2fr 1.8fr 1fr 1.4fr 1.2fr';
        ['House', 'Owner', 'Price / Tax', 'Ledger / Tax owed', 'Status'].forEach((t, i) => {
            const d = el('div', i === 4 ? 'right' : null, t);
            headRow.appendChild(d);
        });
        body.appendChild(headRow);

        const rows = el('div');
        body.appendChild(rows);
        pagedList(rows, data.list,
            h => ((h.motel ? 'motel ' : 'house ') + h.id + ' ' + houseName(names, h.ownerCharid) + ' ' + (h.owned ? 'owned' : 'for sale')),
            h => {
            const row = el('div', 'prow');
            row.style.gridTemplateColumns = '1.2fr 1.8fr 1fr 1.4fr 1.2fr';
            row.style.cursor = 'pointer';
            row.addEventListener('click', () => renderHouseDetail(h));

            row.appendChild(el('div', 'pmoney', (h.motel ? 'Motel #' : 'House #') + h.id));

            const oc = el('div');
            if (h.ownerCharid > 0) {
                const btn = el('span', 'chip', houseName(names, h.ownerCharid) + ' (' + h.ownerCharid + ')');
                btn.style.cursor = 'pointer';
                btn.addEventListener('click', (ev) => { ev.stopPropagation(); openDetail(h.ownerCharid); });
                oc.appendChild(btn);
            } else {
                oc.appendChild(el('span', 'pxp', '—'));
            }
            row.appendChild(oc);

            row.appendChild(el('div', 'pxp', fmtMoney(h.price) + ' / ' + fmtMoney(h.tax)));
            row.appendChild(el('div', 'pxp', fmtMoney(h.ledger) + ' / ' + fmtMoney(h.taxledger)));

            const st = el('div', 'right');
            const chip = (t) => st.appendChild(el('span', 'chip', t));
            if (h.motel) chip('motel');
            else if (h.owned) chip('owned');
            else chip('for sale');
            if (h.repo) chip('repo');
            if (auctions[String(h.id)]) chip('auction');
            if ((h.keyholders || []).length) chip((h.keyholders || []).length + ' keys');
            row.appendChild(st);

            return row;
        }, { placeholder: 'Search houses by number, owner or status...' });
    };

    const renderHouseDetail = (h) => {
        housingView = h.id;
        const body = $('#housingBody');
        body.textContent = '';
        const names = (housingData && housingData.names) || {};
        const auctions = (housingData && housingData.auctions) || {};

        const back = el('button', 'back-btn', '← Back to housing');
        back.addEventListener('click', () => { housingView = null; post('panelHousing'); });
        body.appendChild(back);

        const a = auctions[String(h.id)];
        body.appendChild(kvCard((h.motel ? 'Motel Room #' : 'House #') + h.id, [
            ['Owner', h.ownerCharid > 0 ? (houseName(names, h.ownerCharid) + ' (char ' + h.ownerCharid + ')') : 'none - for sale'],
            ['Price', fmtMoney(h.price)],
            ['Tax', fmtMoney(h.tax)],
            ['Ledger', fmtMoney(h.ledger)],
            ['Tax owed', fmtMoney(h.taxledger)],
            ['Repo flag', h.repo ? 'YES' : 'no'],
            ['Furniture range', (h.range || 0) + ' units'],
            ['Storage slots', (h.slots || 0) === 0 ? 'unlimited' : String(h.slots)],
            ['Auction', a ? ('active, min bid ' + fmtMoney(a.minbid)) : 'none'],
        ]));

        /* storage: the real container, not a list */
        body.appendChild(storageCard('Storage', 'Open storage',
            'Capacity ' + ((h.slots || 0) === 0 ? 'unlimited' : String(h.slots) + ' slots'),
            'Closes the panel and opens this house\'s real storage with the owner\'s controls: '
            + 'take items out or put them in, from anywhere. Nothing about the house changes. Logged.',
            () => post('panelHousingOpenStorage', { id: h.id })));

        /* keyholders */
        const kh = h.keyholders || [];
        const kc = el('div', 'card actions-card');
        kc.appendChild(el('div', 'actions-title', 'Keyholders (' + kh.length + ')'));
        if (!kh.length) {
            kc.appendChild(el('div', 'offline-note', 'None'));
        } else {
            const grid = el('div', 'actions-grid');
            kh.forEach(k => {
                const cid = Number(typeof k === 'object' ? (k.charid || k.charidentifier) : k) || 0;
                const b = el('button', 'abtn', houseName(names, cid) + ' (' + cid + ')');
                b.addEventListener('click', () => openDetail(cid));
                grid.appendChild(b);
                const rm = el('button', 'abtn warn', '✕');
                rm.addEventListener('click', () => houseAct({ action: 'removekey', id: h.id, charid: cid }));
                grid.appendChild(rm);
            });
            kc.appendChild(grid);
        }
        body.appendChild(kc);

        /* actions */
        const ac = el('div', 'card actions-card');
        ac.appendChild(el('div', 'actions-title', h.motel
            ? 'Motel rooms are managed by their own flow - read-only here'
            : 'Actions'));
        if (!h.motel) {
            const f1 = el('div', 'action-form');
            const price = el('input', 'narrow'); price.value = String(h.price);
            const sp = el('button', 'abtn', 'Set Price');
            sp.addEventListener('click', () => houseAct({ action: 'setprice', id: h.id, value: Number(price.value) }));
            const tax = el('input', 'narrow'); tax.value = String(h.tax);
            const stx = el('button', 'abtn', 'Set Tax');
            stx.addEventListener('click', () => houseAct({ action: 'settax', id: h.id, value: Number(tax.value) }));
            f1.appendChild(price); f1.appendChild(sp);
            f1.appendChild(tax); f1.appendChild(stx);
            const rp = el('button', 'abtn' + (h.repo ? '' : ' warn'), h.repo ? 'Clear Repo Flag' : 'Mark Repo');
            rp.addEventListener('click', () => houseAct({ action: 'repo', id: h.id, state: !h.repo }));
            f1.appendChild(rp);
            ac.appendChild(f1);

            /* pup: furniture range + storage slots. Both live on the house row and
               used to be settable only at creation, so widening a cramped house or
               upgrading its storage meant editing the database by hand. */
            const f1b = el('div', 'action-form');
            const rng = el('input', 'narrow'); rng.value = String(h.range || 0);
            const srg = el('button', 'abtn', 'Set Furniture Range');
            srg.addEventListener('click', () => houseAct({ action: 'setrange', id: h.id, value: Number(rng.value) }));
            const slt = el('input', 'narrow'); slt.value = String(h.slots || 0);
            const ssl = el('button', 'abtn', 'Set Storage Slots');
            ssl.addEventListener('click', () => houseAct({ action: 'setslots', id: h.id, value: Number(slt.value) }));
            f1b.appendChild(rng); f1b.appendChild(srg);
            f1b.appendChild(slt); f1b.appendChild(ssl);
            f1b.appendChild(el('span', 'offline-note',
                'range = how far from the door furniture can be placed; slots = house storage capacity'));
            ac.appendChild(f1b);

            const f2 = el('div', 'action-form');
            const tch = el('input', 'narrow'); tch.placeholder = 'charid';
            const tr = el('button', 'abtn', 'Transfer To');
            tr.addEventListener('click', () => {
                if (Number(tch.value) > 0) houseAct({ action: 'transfer', id: h.id, charid: Number(tch.value) });
            });
            f2.appendChild(tch); f2.appendChild(tr);

            if (h.owned) {
                const sconfirm = el('input'); sconfirm.placeholder = 'type SEIZE to confirm';
                const sz = el('button', 'abtn warn', 'Seize (evict to market)');
                sz.addEventListener('click', () => {
                    if (sconfirm.value.trim() === 'SEIZE') houseAct({ action: 'seize', id: h.id });
                });
                f2.appendChild(sconfirm); f2.appendChild(sz);
            } else if (hasPerm('delete_housing')) {
                const dconfirm = el('input'); dconfirm.placeholder = 'type DELETE to confirm';
                const del = el('button', 'abtn warn', 'Delete House');
                del.addEventListener('click', () => {
                    if (dconfirm.value.trim() === 'DELETE') houseAct({ action: 'delete', id: h.id });
                });
                f2.appendChild(dconfirm); f2.appendChild(del);
            } else {
                f2.appendChild(el('div', 'offline-note', 'Deleting a house is Management only.'));
            }
            ac.appendChild(f2);
            ac.appendChild(el('div', 'offline-note', 'Delete needs the house unowned (seize first). Changes push to all players live.'));
        }
        body.appendChild(ac);

        /* auction - pure server events, fully panel-native */
        if (!h.motel) {
            const auc = el('div', 'card actions-card');
            auc.appendChild(el('div', 'actions-title', 'Auction'));
            const af = el('div', 'action-form');
            const aa = auctions[String(h.id)];
            if (aa) {
                af.appendChild(el('span', 'offline-note', 'ACTIVE - min bid ' + fmtMoney(aa.minbid)));
                const cx = el('button', 'abtn warn', 'Cancel Auction');
                // aucid is the AUCTION row; id stays the house so the panel can refresh
                cx.addEventListener('click', () => post('panelHousingAuction',
                    { id: h.id, aucid: aa.id, act: 'cancel' }));
                af.appendChild(cx);
            } else if (!h.owned) {
                const mb = el('input', 'narrow'); mb.placeholder = 'min bid';
                const hrs = el('input', 'narrow'); hrs.placeholder = 'hours';
                const cr = el('button', 'abtn', 'Create Auction');
                cr.addEventListener('click', () => {
                    if (mb.value !== '' && Number(hrs.value) > 0) {
                        post('panelHousingAuction', { id: h.id, act: 'create', minbid: Number(mb.value), hours: Number(hrs.value) });
                    }
                });
                af.appendChild(mb); af.appendChild(hrs); af.appendChild(cr);
            } else {
                af.appendChild(el('span', 'offline-note', 'owned houses cannot be auctioned - seize first'));
            }
            auc.appendChild(af);
            body.appendChild(auc);
        }
    };

    /* ------------------------------------------------------------- camps */
    let campData = null;
    let campView = null; // camp id while a detail is open - refreshes stay on it

    const campAct = guardAct('camp', 'delete_camp',
        (payload) => post('panelCampAction', payload));

    const renderCamps = (data) => {
        const body = $('#campsBody');
        body.textContent = '';
        if (!data || data.missing) {
            body.appendChild(el('div', 'empty', data && data.missing ? 'pup_camps is not running' : 'No access (needs the manage_camps permission)'));
            return;
        }
        campData = data;
        const list = data.list || [];

        if (campView !== null) {
            const fresh = list.find(x => x.id === campView);
            if (fresh) return renderCampDetail(fresh);
            campView = null;
        }

        const repoN = list.filter(c => c.repo).length;
        const safe = list.reduce((n, c) => n + (c.cash || 0), 0);
        const tax = list.reduce((n, c) => n + (c.taxmoney || 0), 0);
        const members = list.reduce((n, c) => n + (c.memberCount || 0), 0);
        const cards = el('div', 'cards small');
        cards.appendChild(card('Camps', repoN + ' repossessed', valueNode(fmt(list.length)), '⛺'));
        cards.appendChild(card('In Safes', 'every camp safe added up', valueNode(fmtMoney(safe)), '$'));
        cards.appendChild(card('Tax Pots', 'every camp tax pot added up', valueNode(fmtMoney(tax)), '%'));
        cards.appendChild(card('Members', 'people in a camp', valueNode(fmt(members)), '☺'));
        body.appendChild(cards);

        const cols = '1.6fr 1.4fr .8fr .9fr .8fr 1.2fr';
        const headRow = el('div', 'table-head');
        headRow.style.gridTemplateColumns = cols;
        ['Camp', 'Leader', 'Members', 'Safe', 'Stash', 'Status'].forEach(t => headRow.appendChild(el('div', null, t)));
        body.appendChild(headRow);

        const rows = el('div');
        body.appendChild(rows);
        pagedList(rows, list,
            c => [c.name, c.id, c.leader && c.leader.name, c.leader && c.leader.charid]
                .concat((c.members || []).map(m => m.name + ' ' + m.charid)).join(' '),
            c => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = cols;
                row.style.cursor = 'pointer';
                row.addEventListener('click', () => renderCampDetail(c));
                const nw = el('div', 'pname');
                const nn = el('div');
                nn.appendChild(el('div', 'n', c.name || ('Camp ' + c.id)));
                nn.appendChild(el('div', 's', '#' + c.id));
                nw.appendChild(nn);
                row.appendChild(nw);
                row.appendChild(el('div', null, (c.leader && c.leader.name) || '—'));
                row.appendChild(el('div', null, fmt(c.memberCount || 0) + (c.memberLimit ? ' / ' + c.memberLimit : '')));
                row.appendChild(el('div', null, fmtMoney(c.cash)));
                row.appendChild(el('div', null, fmt(c.itemCount || 0) + ' / ' + fmt(c.invlimit || 0)));
                row.appendChild(el('div', null, c.repo ? 'repossessed' : 'active'));
                return row;
            });
    };

    /* ----------------------------------------------------------- world props */
    const renderProps = (data) => {
        const body = $('#propsBody');
        body.textContent = '';
        if (!data || data.missing) {
            body.appendChild(el('div', 'empty', data && data.missing
                ? 'pup-props is not running'
                : 'No access (needs the list_world_props permission)'));
            return;
        }
        const list = data.list || [];
        const canDelete = data.canDelete === true;

        /* how many of each model, so a runaway placement is obvious at a glance */
        const byModel = {};
        list.forEach(p => { byModel[p.model] = (byModel[p.model] || 0) + 1; });
        const distinct = Object.keys(byModel).length;
        let topModel = '—', topN = 0;
        for (const m in byModel) { if (byModel[m] > topN) { topN = byModel[m]; topModel = m; } }

        const cards = el('div', 'cards small');
        cards.appendChild(card('Placed', 'props in the world', valueNode(fmt(list.length)), '#'));
        cards.appendChild(card('Models', 'different props used', valueNode(fmt(distinct)), '*'));
        cards.appendChild(card('Most used', topModel, valueNode(fmt(topN)), '^'));
        body.appendChild(cards);

        const cols = '1.8fr 1.2fr 1fr 1fr .8fr';
        const headRow = el('div', 'table-head');
        headRow.style.gridTemplateColumns = cols;
        ['Model', 'Placed by', 'Where', 'When', ''].forEach(t => headRow.appendChild(el('div', null, t)));
        body.appendChild(headRow);

        const rows = el('div');
        body.appendChild(rows);
        pagedList(rows, list,
            p => [p.model, p.id, p.label, p.placed_by_name].join(' '),
            p => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = cols;

                const nw = el('div', 'pname');
                const nn = el('div');
                nn.appendChild(el('div', 'n', p.label || p.model));
                nn.appendChild(el('div', 's', '#' + p.id + (p.label ? ' - ' + p.model : '')));
                nw.appendChild(nn);
                row.appendChild(nw);

                row.appendChild(el('div', null, p.placed_by_name || '—'));
                row.appendChild(el('div', null,
                    Number(p.x).toFixed(0) + ', ' + Number(p.y).toFixed(0) + ', ' + Number(p.z).toFixed(0)));
                row.appendChild(el('div', null, (p.created_at || '').toString().slice(0, 16) || '—'));

                const acts = el('div', 'action-form');
                const gb = el('button', 'abtn', 'Go');
                gb.addEventListener('click', (e) => {
                    e.stopPropagation();
                    post('panelPropGoto', { x: p.x, y: p.y, z: p.z });
                });
                acts.appendChild(gb);

                if (canDelete) {
                    const db = el('button', 'abtn danger', 'Delete');
                    db.addEventListener('click', (e) => {
                        e.stopPropagation();
                        askConfirm({
                            title: 'Remove this prop?',
                            body: p.model + ' (#' + p.id + ') disappears for everyone. This cannot be undone.',
                            okLabel: 'Delete',
                            danger: true,
                            onOk: () => post('panelPropDelete', { id: p.id }),
                        });
                    });
                    acts.appendChild(db);
                }
                row.appendChild(acts);
                return row;
            });
    };

    const renderCampDetail = (c) => {
        campView = c.id;
        const body = $('#campsBody');
        body.textContent = '';
        const co = c.coords || {};

        const back = el('button', 'back-btn', '← Back to camps');
        back.addEventListener('click', () => { campView = null; post('panelCamps'); });
        body.appendChild(back);

        body.appendChild(kvCard('Camp', [
            ['Camp', (c.name || 'Camp') + ' (#' + c.id + ')'],
            ['Leader', c.leader ? (c.leader.name + ' (' + c.leader.charid + ')') : '—'],
            ['Members', fmt(c.memberCount || 0) + (c.memberLimit ? ' of ' + c.memberLimit : '')],
            ['Safe', fmtMoney(c.cash)],
            ['Tax pot', fmtMoney(c.taxmoney)],
            ['Stash', fmt(c.itemCount || 0) + ' stack(s), limit ' + fmt(c.invlimit || 0)],
            ['Furniture', fmt(c.furniCount || 0) + ' / ' + fmt(c.furniLimit || 0)],
            ['Status', c.repo ? 'Repossessed' : 'Active'],
            ['Own Discord log', c.haswebhook ? 'Set by the leader' : 'Not set'],
            ['Location', (co.x !== undefined) ? Number(co.x).toFixed(1) + ', ' + Number(co.y).toFixed(1) + ', ' + Number(co.z).toFixed(1) : '—'],
        ]));

        if (co.x !== undefined) {
            const gf = el('div', 'action-form');
            const gb = el('button', 'abtn', 'Teleport here');
            gb.addEventListener('click', () => post('panelCampGoto', { x: co.x, y: co.y, z: co.z }));
            gf.appendChild(gb);
            body.appendChild(gf);
        }

        /* money */
        const mon = el('div', 'card actions-card');
        mon.appendChild(el('div', 'actions-title', 'Safe and tax'));
        const mf = el('div', 'action-form');
        const amt = el('input', 'narrow'); amt.placeholder = 'amount';
        const setSafe = el('button', 'abtn', 'Set safe');
        setSafe.addEventListener('click', () => {
            const v = Number(amt.value);
            if (v >= 0) campAct({ action: 'setledger', id: c.id, value: v });
        });
        const setTax = el('button', 'abtn', 'Set tax pot');
        setTax.addEventListener('click', () => {
            const v = Number(amt.value);
            if (v >= 0) campAct({ action: 'settax', id: c.id, value: v });
        });
        const wipeSafe = el('button', 'abtn warn', 'Empty safe');
        wipeSafe.addEventListener('click', () => askConfirm({
            title: 'Empty the safe of ' + (c.name || 'this camp') + '?',
            body: 'The balance goes to $0. This cannot be undone.',
            okLabel: 'Empty', danger: true,
            onOk: () => campAct({ action: 'wipeledger', id: c.id }),
        }));
        mf.appendChild(amt); mf.appendChild(setSafe); mf.appendChild(setTax); mf.appendChild(wipeSafe);
        mon.appendChild(mf);
        body.appendChild(mon);

        /* name and storage */
        const cfg = el('div', 'card actions-card');
        cfg.appendChild(el('div', 'actions-title', 'Name and storage'));
        const cf = el('div', 'action-form');
        const nameIn = el('input'); nameIn.placeholder = 'new camp name'; nameIn.value = c.name || '';
        const renB = el('button', 'abtn', 'Rename');
        renB.addEventListener('click', () => {
            const v = nameIn.value.trim();
            if (v) campAct({ action: 'rename', id: c.id, value: v });
        });
        const slots = el('input', 'narrow'); slots.placeholder = 'slots'; slots.value = c.invlimit || 0;
        const slotB = el('button', 'abtn', 'Set storage limit');
        slotB.addEventListener('click', () => {
            const v = Number(slots.value);
            if (v >= 0) campAct({ action: 'setlimit', id: c.id, value: v });
        });
        cf.appendChild(nameIn); cf.appendChild(renB); cf.appendChild(slots); cf.appendChild(slotB);
        cfg.appendChild(cf);
        body.appendChild(cfg);

        /* members */
        const mc = el('div', 'card actions-card');
        mc.appendChild(el('div', 'actions-title', 'Members (' + fmt(c.memberCount || 0) + ')'));
        const memberRow = (role, name, charid, onRemove) => {
            const f = el('div', 'action-form');
            f.appendChild(el('span', 'offline-note', role));
            f.appendChild(el('span', null, (name || '—') + (charid ? ' (' + charid + ')' : '')));
            if (charid) {
                const pb = el('button', 'abtn', 'Open');
                pb.addEventListener('click', () => openDetail(Number(charid)));
                f.appendChild(pb);
            }
            if (onRemove) {
                const rb = el('button', 'abtn warn', 'Remove');
                rb.addEventListener('click', onRemove);
                f.appendChild(rb);
            }
            return f;
        };
        const leaderId = c.leader && c.leader.charid;
        (c.members || []).forEach(m => {
            const isLeader = leaderId && m.charid === leaderId;
            mc.appendChild(memberRow(isLeader ? 'Leader' : 'Member', m.name, m.charid,
                isLeader ? null : () => askConfirm({
                    title: 'Remove ' + (m.name || 'this member') + ' from ' + (c.name || 'the camp') + '?',
                    body: 'They lose access immediately.',
                    okLabel: 'Remove', danger: true,
                    onOk: () => campAct({ action: 'removemember', id: c.id, charid: m.charid }),
                })));
        });
        if (!(c.members || []).length) mc.appendChild(el('div', 'offline-note', 'No members'));

        const lf = el('div', 'action-form');
        const lid = el('input', 'narrow'); lid.placeholder = 'character ID';
        const addB = el('button', 'abtn', 'Add member');
        addB.addEventListener('click', () => {
            const v = Number(lid.value);
            if (v > 0) campAct({ action: 'addmember', id: c.id, charid: v });
        });
        const ldB = el('button', 'abtn warn', 'Make leader');
        ldB.addEventListener('click', () => {
            const v = Number(lid.value);
            if (!(v > 0)) return;
            askConfirm({
                title: 'Hand ' + (c.name || 'this camp') + ' to character ' + v + '?',
                body: 'They have to be a member already. The current leader becomes an ordinary member.',
                okLabel: 'Transfer', danger: true,
                onOk: () => campAct({ action: 'setleader', id: c.id, charid: v }),
            });
        });
        lf.appendChild(lid); lf.appendChild(addB); lf.appendChild(ldB);
        lf.appendChild(el('span', 'offline-note', 'works on offline characters'));
        mc.appendChild(lf);
        body.appendChild(mc);

        /* stash: the real camp stash panel, not a list */
        const sc = storageCard('Stash', 'Open storage',
            fmt(c.itemCount || 0) + ' stack(s), limit ' + fmt(c.invlimit || 0),
            'Closes the panel and opens this camp\'s real stash with the leader\'s controls: '
            + 'take items out or put them in, from anywhere. You are not made a member. Logged.',
            () => post('panelCampOpenStash', { id: c.id }));
        if ((c.items || []).length) {
            const wf = el('div', 'action-form');
            const wb = el('button', 'abtn warn', 'Empty the whole stash');
            wb.addEventListener('click', () => askConfirm({
                title: 'Empty the stash of ' + (c.name || 'this camp') + '?',
                body: 'Every stack is destroyed. This cannot be undone.',
                okLabel: 'Empty', danger: true,
                onOk: () => campAct({ action: 'wipestash', id: c.id }),
            }));
            wf.appendChild(wb);
            sc.appendChild(wf);
        }
        body.appendChild(sc);

        /* danger */
        const dz = el('div', 'card actions-card');
        dz.appendChild(el('div', 'actions-title', 'Repossession and disbanding'));
        const df = el('div', 'action-form');
        if (c.repo) {
            const rb = el('button', 'abtn', 'Restore camp');
            rb.addEventListener('click', () => campAct({ action: 'unrepo', id: c.id }));
            df.appendChild(rb);
        } else {
            const rb = el('button', 'abtn warn', 'Mark repossessed');
            rb.addEventListener('click', () => askConfirm({
                title: 'Repossess ' + (c.name || 'this camp') + '?',
                body: 'The camp is hidden from its members until it is restored. Nothing is deleted.',
                okLabel: 'Repossess', danger: true,
                onOk: () => campAct({ action: 'repo', id: c.id }),
            }));
            df.appendChild(rb);
        }
        const delB = el('button', 'abtn warn', 'Disband camp');
        delB.addEventListener('click', () => askConfirm({
            title: 'Disband ' + (c.name || 'this camp') + '?',
            body: 'The camp, its safe, its tax pot, its stash and its furniture are all destroyed and every member is released. This cannot be undone.',
            okLabel: 'Disband', danger: true,
            onOk: () => { campView = null; campAct({ action: 'delete', id: c.id }); },
        }));
        df.appendChild(delB);
        dz.appendChild(df);
        body.appendChild(dz);
    };

    /* ------------------------------------------------------------- stores page */
    let storeView = null;   // shop id while a detail is open
    let storeData = null;
    let storeStockHost = null;  // the Stock card's summary line, filled when the read comes back

    // one line: on sale / shelved / buy orders. The rows themselves are not listed;
    // "Open shop inventory" opens the real grid.
    const renderStoreStock = (data) => {
        const host = storeStockHost;
        if (!host) return;
        if (!data || data.id !== storeView) return;

        const stock = data.stock;
        if (!stock) {
            host.textContent = 'Could not read the stock (pup_mercantile not running, or no permission).';
            return;
        }

        const items = stock.items || [], weapons = stock.weapons || [], buying = stock.buying || [];
        const onSale = items.filter(i => i.forsale).length + weapons.filter(w => w.forsale).length;
        const shelved = (items.length + weapons.length) - onSale;
        host.textContent = onSale + ' row(s) on sale, ' + shelved + ' shelved, '
            + buying.length + ' buy order(s).';
    };

    const renderStoreDetail = (s) => {
        const body = $('#storesBody');
        body.textContent = '';

        const back = el('button', 'abtn', '← All shops');
        back.addEventListener('click', () => { storeView = null; storeStockHost = null; renderStores(storeData); });
        body.appendChild(back);

        const act = (action, value) => post('panelStoreAction', { id: s.id, action, value });

        const cards = el('div', 'cards small');
        cards.appendChild(card('Shop', '#' + s.id, valueNode(s.name), '⌂'));
        cards.appendChild(card('Ledger', 'shop takings', valueNode(fmtMoney(s.ledger || 0)), '$'));
        cards.appendChild(card('Tax Owed', '', valueNode(fmtMoney(s.taxledger || 0)), '⚁'));
        cards.appendChild(card('Status', s.blip ? 'blip shown' : 'blip hidden',
            valueNode(s.repo ? 'Repossessed' : 'Active'), s.repo ? '⚠' : '✓'));
        body.appendChild(cards);

        const cards2 = el('div', 'cards small');
        cards2.appendChild(card('Owner', s.ownerCharid > 0 ? ('char ' + s.ownerCharid) : 'unowned',
            valueNode(s.ownerName || '—'), '♟'));
        cards2.appendChild(card('Stock Used', 'items + weapons',
            valueNode(fmt((s.items || 0) + (s.weapons || 0)) + ' / ' + fmt(s.slots || 0)), '☰'));
        cards2.appendChild(card('Items', '', valueNode(fmt(s.items || 0)), '■'));
        cards2.appendChild(card('Weapons', '', valueNode(fmt(s.weapons || 0)), '⚔'));
        body.appendChild(cards2);

        if (s.ownerCharid > 0) {
            const oc = el('div', 'actions-card card');
            oc.appendChild(el('div', 'actions-title', 'Owner'));
            const of = el('div', 'action-form');
            const chip = el('span', 'chip', (s.ownerName || '?') + ' (' + s.ownerCharid + ')');
            chip.style.cursor = 'pointer';
            chip.addEventListener('click', () => openDetail(s.ownerCharid));
            of.appendChild(chip);
            if (s.ownerDiscord) {
                of.appendChild(el('span', 'offline-note', 'Discord ' + s.ownerDiscord));
                of.appendChild(copyBtn(s.ownerDiscord, 'Discord ID'));
            }
            oc.appendChild(of);
            body.appendChild(oc);
        }

        /* ownership + visibility */
        const ac = el('div', 'actions-card card');
        ac.appendChild(el('div', 'actions-title', 'Shop'));
        const af = el('div', 'action-form');
        const btn = (host, label, fn, warn) => {
            const b = el('button', 'abtn' + (warn ? ' warn' : ''), label);
            b.addEventListener('click', fn);
            host.appendChild(b);
        };
        btn(af, s.repo ? 'Restore to owner' : 'Repossess', () => act(s.repo ? 'unrepo' : 'repo'));
        btn(af, s.blip ? 'Hide map blip' : 'Show map blip', () => act('blip', !s.blip));
        btn(af, 'Move here', () => post('panelStoreMoveHere', { id: s.id }));
        if (s.coords && s.coords.x != null) {
            btn(af, 'Go to shop', () => post('panelStoreGoto', { id: s.id, coords: s.coords }));
        }
        ac.appendChild(af);
        ac.appendChild(el('div', 'offline-note',
            'Move here places the shop at YOUR position. Go to shop closes the panel and stands you at it. '
            + 'Repossessing hides it and locks the owner out.'));
        body.appendChild(ac);

        /* stock: the real grid, not a list. One summary line comes back from the read. */
        if (s.live) {
            const kc = storageCard('Stock', 'Open shop inventory', 'Reading the shop…',
                'Closes the panel and opens the real stock grid with the owner\'s controls: '
                + 'take items out, put them on or off sale, set prices. Logged.',
                () => post('panelStoreOpenStock', { id: s.id }));
            body.appendChild(kc);
            storeStockHost = kc.summary;
            post('panelStoreStock', { id: s.id });
        } else {
            const kc = el('div', 'actions-card card');
            kc.appendChild(el('div', 'actions-title', 'Stock'));
            kc.appendChild(el('div', 'offline-note',
                'pup_mercantile is not running, so the stock grid cannot be opened.'));
            body.appendChild(kc);
            storeStockHost = null;
        }

        /* rename */
        const rc = el('div', 'actions-card card');
        rc.appendChild(el('div', 'actions-title', 'Rename'));
        const rf = el('div', 'action-form');
        const rv = el('input');
        rv.placeholder = 'new shop name';
        rv.value = s.name || '';
        rf.appendChild(rv);
        btn(rf, 'Rename', () => {
            const v = String(rv.value || '').trim();
            if (v) act('rename', v);
        });
        rc.appendChild(rf);
        body.appendChild(rc);

        /* stock slots */
        const sc = el('div', 'actions-card card');
        sc.appendChild(el('div', 'actions-title', 'Stock Slots'));
        const sf = el('div', 'action-form');
        const sv = el('input', 'narrow');
        sv.placeholder = '1-500';
        sv.value = String(s.slots || '');
        sf.appendChild(sv);
        btn(sf, 'Set slots', () => {
            const v = Number(sv.value);
            if (v >= 1) act('slots', v);
        });
        sc.appendChild(sf);
        sc.appendChild(el('div', 'offline-note',
            'Currently holding ' + fmt((s.items || 0) + (s.weapons || 0)) + ' of ' + fmt(s.slots || 0) + '.'));
        body.appendChild(sc);

        /* delete */
        if (hasPerm('delete_store')) {
            const dc = el('div', 'actions-card card');
            dc.appendChild(el('div', 'actions-title', 'Danger'));
            const df = el('div', 'action-form');
            btn(df, 'Delete shop', () => askConfirm({
                title: 'Delete shop?',
                body: '<b>' + escHtml(s.name) + '</b> (#' + escHtml(s.id) + ') and its stock will be removed. This cannot be undone.',
                okLabel: 'Delete',
                onOk: () => { storeView = null; storeStockHost = null; act('delete'); },
            }), true);
            dc.appendChild(df);
            body.appendChild(dc);
        }
    };

    const renderStores = (data) => {
        const body = $('#storesBody');
        body.textContent = '';
        if (!data) {
            body.appendChild(el('div', 'empty', 'No access (needs the manage_stores permission)'));
            return;
        }
        storeData = data;
        const list = data.list || [];

        /* a refresh while a detail is open stays on that shop */
        if (storeView !== null) {
            const fresh = list.find(x => x.id === storeView);
            if (fresh) return renderStoreDetail(fresh);
            storeView = null;
        }

        const live = list.length ? list[0].live : false;

        const cards = el('div', 'cards small');
        cards.appendChild(card('Player Shops', '', valueNode(fmt(list.length)), '⌂'));
        cards.appendChild(card('Ledgers Total', '', valueNode(fmtMoney(list.reduce((n, s) => n + (s.ledger || 0), 0))), '$'));
        cards.appendChild(card('Tax Owed Total', '', valueNode(fmtMoney(list.reduce((n, s) => n + (s.taxledger || 0), 0))), '⚁'));
        cards.appendChild(card('Owners', '', valueNode(fmt(new Set(list.map(s => s.ownerCharid).filter(c => c > 0)).size)), '♟'));
        body.appendChild(cards);

        const COLS = '1.8fr 1.6fr 1fr 1fr';
        const headRow = el('div', 'table-head');
        headRow.style.gridTemplateColumns = COLS;
        ['Shop', 'Owner', 'Ledger', 'Tax owed'].forEach(t => headRow.appendChild(el('div', null, t)));
        body.appendChild(headRow);

        const rows = el('div');
        body.appendChild(rows);
        if (!list.length) rows.appendChild(el('div', 'empty', 'No player shops exist yet'));

        /* searchable by shop name, id (with or without #) and owner name or charid */
        pagedList(rows, list,
            s => [s.name, '#' + s.id, s.id, s.ownerName || '', s.ownerCharid || ''].join(' '),
            s => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = COLS;
                row.style.cursor = 'pointer';
                row.addEventListener('click', () => { storeView = s.id; renderStoreDetail(s); });

                const nw = el('div', 'pname');
                const nn = el('div');
                nn.appendChild(el('div', 'n', s.name));
                const sub = ['#' + s.id];
                if (s.live) {
                    if (s.repo) sub.push('REPOSSESSED');
                    if (s.slots) sub.push(fmt((s.items || 0) + (s.weapons || 0)) + '/' + fmt(s.slots) + ' slots');
                }
                nn.appendChild(el('div', 's', sub.join(' · ')));
                nw.appendChild(nn);
                row.appendChild(nw);

                const oc = el('div');
                if (s.ownerCharid > 0) {
                    oc.appendChild(el('span', 'chip', (s.ownerName || '?') + ' (' + s.ownerCharid + ')'));
                } else {
                    oc.appendChild(el('span', 'pxp', '—'));
                }
                row.appendChild(oc);
                row.appendChild(el('div', 'pmoney', fmtMoney(s.ledger || 0)));
                row.appendChild(el('div', 'pxp', fmtMoney(s.taxledger || 0)));
                return row;
            },
            { placeholder: 'Search by shop name, #id, owner name or charid...' });

        body.appendChild(el('div', 'offline-note', live
            ? 'Click a shop to manage it. Stock and pricing stay with the owner in-world.'
            : 'pup_mercantile is not running - read-only. Start it to repossess, rename, move or delete shops.'));
    };


    /* ------------------------------------------------------------- ranches page */
    let ranchData = null;
    let ranchView = null; // ranch id while a detail is open

    /* GANGS -----------------------------------------------------------------
       Oversight for pup-gangs. Points are the lever that matters: they set BOTH
       the territory radius on the map AND the perk level, so the adjust buttons
       here change what a gang can actually do, not just a number on a screen.

       Uses the panel's own row vocabulary (rows / prow / pname / chip) rather
       than inventing classes - the first version used a `table-row` class that
       does not exist in panel.css, which is why it rendered unstyled. */
    let gangView = null;
    let gangData = null;

    const ago = (secs) => {
        secs = Math.max(0, Math.floor(secs || 0));
        if (secs < 60) return secs + 's';
        if (secs < 3600) return Math.floor(secs / 60) + 'm';
        if (secs < 86400) return Math.floor(secs / 3600) + 'h';
        return Math.floor(secs / 86400) + 'd';
    };

    /* A labelled progress meter. panel.css has no bar component (.cat-bar is the
       pill-shaped chip strip on the items page, not a track), so this is built from
       the panel's own CSS variables to stay on-theme without inventing classes. */
    const gangMeter = (label, value, max, note) => {
        const wrap = el('div', 'card');
        wrap.appendChild(el('div', 'card-title', label));

        const track = el('div');
        track.style.cssText = 'height:.5vw;border-radius:999px;background:var(--panel-2);'
            + 'border:1px solid var(--line);overflow:hidden;margin:.45vw 0;';
        const pct = max > 0 ? Math.max(0, Math.min(100, (value / max) * 100)) : 100;
        const fill = el('div');
        fill.style.cssText = 'height:100%;background:var(--accent);width:' + pct.toFixed(1) + '%;';
        track.appendChild(fill);
        wrap.appendChild(track);

        wrap.appendChild(el('div', 'card-sub', note || (fmt(value) + ' / ' + fmt(max))));
        return wrap;
    };

    const renderGangDetail = (g) => {
        const body = $('#gangsBody');
        body.textContent = '';

        const back = el('button', 'abtn', '\u2190 All gangs');
        back.addEventListener('click', () => { gangView = null; post('panelGangs'); });
        body.appendChild(back);

        /* headline numbers */
        const cards = el('div', 'cards small');
        cards.appendChild(card('Gang', g.factionLabel || g.faction,
            valueNode(g.name + (g.shortname ? '  [' + g.shortname + ']' : '')), '\u2620'));
        cards.appendChild(card('Level', g.levelLabel || '', valueNode(g.level), '\u2605'));
        cards.appendChild(card('Points', 'drives radius + level', valueNode(fmt(g.points)), '\u25C6'));
        cards.appendChild(card('Influence Radius', 'on the map', valueNode(Math.floor(g.radius), 'm'), '\u25CB'));
        body.appendChild(cards);

        const cards2 = el('div', 'cards small');
        cards2.appendChild(card('Members', '', valueNode(fmt((g.members || []).length)), '\u265F'));
        cards2.appendChild(card('Territory Held', '', valueNode(fmt((g.territories || []).length)), '\u2691'));
        cards2.appendChild(card('Gang Table', g.hasTable ? ('house #' + g.tableHouse) : 'not placed',
            valueNode(g.hasTable ? 'Placed' : 'None'), '\u2616'));
        cards2.appendChild(card('Last Activity', '', valueNode(g.lastActivity ? (ago((gangData.now || 0) - g.lastActivity) + ' ago') : '-'), '\u23F1'));
        body.appendChild(cards2);

        /* activity + the lifetime record */
        const s = g.stats || {};
        const cards3 = el('div', 'cards small');
        cards3.appendChild(card('Activity', 'earned ' + fmt(g.earnedWeek || 0) + ' pts this week',
            valueNode(g.activityScore || 'LOW'), '\u26A1'));
        cards3.appendChild(card('Robberies', fmt(s.heists || 0) + ' bank heists', valueNode(fmt(s.robberies || 0)), '\u2718'));
        cards3.appendChild(card('Drug Missions', '', valueNode(fmt(s.missions || 0)), '\u2698'));
        cards3.appendChild(card('Wars', (s.warsWon || 0) + 'W / ' + (s.warsLost || 0) + 'L \u2022 '
            + fmt(s.kills || 0) + ' kills / ' + fmt(s.deaths || 0) + ' deaths',
            valueNode(fmt((s.warsWon || 0) + (s.warsLost || 0))), '\u2694'));
        body.appendChild(cards3);

        /* level progress + what the current tier grants */
        if (g.levelNextAt) {
            const span = g.levelNextAt - (g.levelFrom || 0);
            const done = g.points - (g.levelFrom || 0);
            body.appendChild(gangMeter(
                'Progress to ' + (g.levelNextLabel || 'next level'),
                done, span,
                fmt(g.points) + ' / ' + fmt(g.levelNextAt) + ' points  \u2022  ' + fmt(g.levelNextAt - g.points) + ' to go'));
        } else {
            body.appendChild(gangMeter('Maximum level reached', 1, 1, 'No further tiers'));
        }

        if (g.perks) {
            const p = g.perks;
            const perkLine = '+' + (p.stashSlots || 0) + ' stash slots \u2022 +' + (p.extraRadius || 0)
                + 'm radius \u2022 x' + (p.pointsMult || 1).toFixed(2) + ' points \u2022 +' + (p.members || 0) + ' member slots';
            const pc = el('div', 'card');
            pc.appendChild(el('div', 'card-title', 'Tier perks'));
            pc.appendChild(el('div', 'card-sub', perkLine));
            if ((p.unlocks || []).length) {
                pc.appendChild(el('div', 'card-sub', 'Unlocked: ' + p.unlocks.join(', ')));
            }
            body.appendChild(pc);
        }

        /* admin levers */
        const act = el('div', 'card actions-card');
        act.appendChild(el('div', 'actions-title', 'Adjust points \u2014 changes map radius AND perk level'));
        const grid = el('div', 'action-form');
        const amt = el('input', 'narrow'); amt.value = '100';
        grid.appendChild(amt);
        [['+ Add', 1], ['- Remove', -1]].forEach(([label, sign]) => {
            const b = el('button', 'abtn', label);
            b.addEventListener('click', () => {
                const n = parseInt(amt.value, 10);
                if (!isNaN(n) && n > 0) post('panelGangAction', { action: 'points', id: g.id, value: n * sign });
            });
            grid.appendChild(b);
        });
        const dis = el('button', 'abtn warn', 'Disband gang');
        dis.addEventListener('click', () => {
            askConfirm({
                title: 'Disband ' + g.name + '?',
                body: 'Members, territory, the gang table, wars and live drug plants are <b>all released</b>. '
                    + 'This cannot be undone.',
                okLabel: 'Disband gang',
                onOk: () => {
                    post('panelGangAction', { action: 'disband', id: g.id });
                    gangView = null;
                },
            });
        });
        if (hasPerm('delete_gang')) grid.appendChild(dis);
        act.appendChild(grid);
        body.appendChild(act);

        /* roster */
        body.appendChild(el('div', 'actions-title', 'Roster (' + (g.members || []).length + ')'));
        const mHead = el('div', 'table-head');
        mHead.style.gridTemplateColumns = '2fr 1.2fr 1fr 1fr';
        ['Member', 'Rank', 'Contributed', 'Character'].forEach(t => mHead.appendChild(el('div', null, t)));
        body.appendChild(mHead);
        const mRows = el('div', 'rows');
        (g.members || []).forEach(m => {
            const row = el('div', 'prow');
            row.style.gridTemplateColumns = '2fr 1.2fr 1fr 1fr';
            const nw = el('div', 'pname');
            const nn = el('div');
            nn.appendChild(el('div', 'n', m.name || ('char ' + m.charid)));
            nn.appendChild(el('div', 's', m.isLeader ? 'boss' : ''));
            nw.appendChild(nn);
            row.appendChild(nw);
            row.appendChild(el('div', null, m.rankLabel || '?'));
            row.appendChild(el('div', null, fmt(m.points)));
            const cw = el('div');
            const chip = el('span', 'chip', String(m.charid));
            chip.style.cursor = 'pointer';
            chip.addEventListener('click', () => openDetail(m.charid));
            cw.appendChild(chip);
            row.appendChild(cw);
            mRows.appendChild(row);
        });
        body.appendChild(mRows);
        if (!(g.members || []).length) body.appendChild(el('div', 'empty', 'No members.'));

        /* territory */
        if ((g.territories || []).length) {
            body.appendChild(el('div', 'actions-title', 'Territory held'));
            const tRows = el('div', 'rows');
            g.territories.forEach(t => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = '2fr 1fr';
                row.appendChild(el('div', null, t.name));
                row.appendChild(el('div', null, Math.floor(g.radius) + 'm radius'));
                tRows.appendChild(row);
            });
            body.appendChild(tRows);
        }

        /* dens (level 3+ drug ops) */
        if ((g.dens || []).length) {
            body.appendChild(el('div', 'actions-title', 'Dens'));
            const thRows = el('div', 'rows');
            g.dens.forEach(th => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = '1.4fr 1.4fr 1fr';
                row.appendChild(el('div', null, 'House #' + th.houseid));
                row.appendChild(el('div', null, th.stored + ' package(s) on the shelf'));
                const st = el('div', null, th.underRaid ? 'UNDER RAID' : 'quiet');
                if (th.underRaid) st.style.color = 'var(--bad, #b4534b)';
                thRows.appendChild(row);
                row.appendChild(st);
            });
            body.appendChild(thRows);
        }

        /* wars */
        if ((g.wars || []).length) {
            body.appendChild(el('div', 'actions-title', 'Active wars'));
            const wHead = el('div', 'table-head');
            wHead.style.gridTemplateColumns = '2fr 1fr 1fr';
            ['Against', 'Score', 'Ends in'].forEach(t => wHead.appendChild(el('div', null, t)));
            body.appendChild(wHead);
            const wRows = el('div', 'rows');
            g.wars.forEach(w => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = '2fr 1fr 1fr';
                row.appendChild(el('div', null, w.enemy));
                const sc = el('div', null, w.mine + ' - ' + w.theirs);
                sc.style.color = w.mine > w.theirs ? 'var(--good, #7fb069)' : 'var(--bad, #b4534b)';
                row.appendChild(sc);
                row.appendChild(el('div', null, ago(w.endsIn)));
                wRows.appendChild(row);
            });
            body.appendChild(wRows);
        }

        /* live drug plants */
        if ((g.plants || []).length) {
            body.appendChild(el('div', 'actions-title', 'Live plants'));
            const pRows = el('div', 'rows');
            g.plants.forEach(pl => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = '1fr 2fr 1fr';
                row.appendChild(el('div', null, pl.attacking ? 'Attacking' : 'Defending'));
                row.appendChild(el('div', null, pl.other ? pl.other.name : '-'));
                row.appendChild(el('div', null, ago(pl.endsIn) + ' left'));
                pRows.appendChild(row);
            });
            body.appendChild(pRows);
        }

        /* the gang ledger - every row carries its point delta */
        body.appendChild(el('div', 'actions-title', 'Gang ledger'));
        const aRows = el('div', 'rows');
        (g.activity || []).forEach(a => {
            const row = el('div', 'prow');
            row.style.gridTemplateColumns = '.6fr .7fr 1fr 2.3fr 1.2fr';
            const delta = Number(a.pts) || 0;
            // ASCII placeholder: an em dash renders as mojibake on rows with no pts value
            const pn = el('div', null, delta !== 0 ? ((delta > 0 ? '+' : '') + delta) : '-');
            if (delta !== 0) pn.style.color = delta > 0 ? 'var(--good, #7fb069)' : 'var(--bad, #b4534b)';
            row.appendChild(pn);
            row.appendChild(el('div', null, ago((gangData.now || 0) - (a.ts || 0)) + ' ago'));
            row.appendChild(el('div', null, a.type || ''));
            row.appendChild(el('div', null, a.detail || ''));
            row.appendChild(el('div', null, a.actor || ''));
            aRows.appendChild(row);
        });
        body.appendChild(aRows);
        if (!(g.activity || []).length) body.appendChild(el('div', 'empty', 'Nothing logged yet.'));
    };

    const renderGangs = (data) => {
        const body = $('#gangsBody');
        body.textContent = '';
        if (!data || data.missing) {
            body.appendChild(el('div', 'empty', data && data.missing ? 'pup-gangs is not running' : 'No access (needs the manage_gangs permission)'));
            return;
        }
        gangData = data;
        const list = data.list || [];

        if (gangView) {
            const fresh = list.find(x => x.id === gangView);
            if (fresh) return renderGangDetail(fresh);
            gangView = null;
        }

        const cards = el('div', 'cards small');
        cards.appendChild(card('Gangs', '', valueNode(fmt(list.length)), '\u2620'));
        cards.appendChild(card('Members', 'across all gangs', valueNode(fmt(list.reduce((n, g) => n + (g.members || []).length, 0))), '\u265F'));
        cards.appendChild(card('Active Wars', '', valueNode(fmt(data.wars || 0)), '\u2694'));
        cards.appendChild(card('Live Plants', 'drug missions running', valueNode(fmt(data.plants || 0)), '\u2623'));
        body.appendChild(cards);

        /* FACTION WAR standings. `season` accumulates and never decays - every point any
           gang in that faction has ever earned. `live` is what its current gangs hold
           right now, which can be far lower after decay or a disband. History vs present
           strength, side by side. */
        const factions = data.factions || [];
        if (factions.length) {
            body.appendChild(el('div', 'actions-title', 'Faction war \u2014 season score vs present strength'));
            const fHead = el('div', 'table-head');
            fHead.style.gridTemplateColumns = '.5fr 2fr 1fr 1fr .8fr .8fr';
            ['#', 'Faction', 'War score', 'Live points', 'Gangs', 'Ground'].forEach(t => fHead.appendChild(el('div', null, t)));
            body.appendChild(fHead);
            const fRows = el('div', 'rows');
            factions.forEach(f => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = '.5fr 2fr 1fr 1fr .8fr .8fr';
                row.appendChild(el('div', null, '#' + f.place));
                const nw = el('div', 'pname');
                const nn = el('div');
                nn.appendChild(el('div', 'n', f.label));
                nn.appendChild(el('div', 's', f.blurb || ''));
                nw.appendChild(nn);
                row.appendChild(nw);
                row.appendChild(el('div', null, fmt(f.season)));
                row.appendChild(el('div', null, fmt(f.livePoints)));
                row.appendChild(el('div', null, fmt(f.gangs)));
                row.appendChild(el('div', null, fmt(f.territories)));
                fRows.appendChild(row);
            });
            body.appendChild(fRows);
        }

        /* SEASON RESET. Its own table because none of this is a per-gang action -
           it wipes every ladder on the server at once, so it sits behind
           reset_gang_points rather than riding on manage_gangs. */
        if (hasPerm('reset_gang_points')) {
            const gangPts = list.reduce((n, g) => n + (Number(g.points) || 0), 0);
            const memberPts = list.reduce((n, g) =>
                n + (g.members || []).reduce((m, x) => m + (Number(x.points) || 0), 0), 0);
            const seasonPts = factions.reduce((n, f) => n + (Number(f.season) || 0), 0);

            body.appendChild(el('div', 'actions-title', 'Season reset \u2014 clears the ladders, keeps the gangs'));
            const RCOLS = '1.3fr 3fr 1.1fr .8fr';
            const rHead = el('div', 'table-head');
            rHead.style.gridTemplateColumns = RCOLS;
            ['Ladder', 'What it clears', 'Standing now', ''].forEach(t => rHead.appendChild(el('div', null, t)));
            body.appendChild(rHead);

            const RESETS = [
                ['gangs', 'Gang points',
                    'Every gang back to 0. Map radius and perk level collapse to level 1. Rosters, territory, money, dens and stashes are untouched.',
                    fmt(gangPts) + ' pts \u2022 ' + fmt(list.length) + ' gang(s)'],
                ['members', 'Member contributions',
                    'Every roster member\u2019s personal tally back to 0. Ranks are untouched.',
                    fmt(memberPts) + ' pts'],
                ['factions', 'Faction war scores',
                    'The three-way season leaderboard back to 0. Live strength recalculates on its own.',
                    fmt(seasonPts) + ' pts'],
                ['all', 'Everything',
                    'All three ladders at once \u2014 a clean season.',
                    ''],
            ];
            const rRows = el('div', 'rows');
            RESETS.forEach(r => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = RCOLS;
                const nw = el('div', 'pname');
                const nn = el('div');
                nn.appendChild(el('div', 'n', r[1]));
                nw.appendChild(nn);
                row.appendChild(nw);
                row.appendChild(el('div', 's', r[2]));
                row.appendChild(el('div', null, r[3]));

                const b = el('button', 'abtn warn', r[0] === 'all' ? 'Reset all' : 'Reset');
                b.addEventListener('click', () => askConfirm({
                    title: 'Reset ' + r[1].toLowerCase() + '?',
                    body: r[2] + '<br><br>This runs across the <b>whole server</b> and cannot be undone.',
                    okLabel: 'Reset',
                    onOk: () => post('panelGangReset', { scope: r[0] }),
                }));
                const bw = el('div');
                bw.appendChild(b);
                row.appendChild(bw);
                rRows.appendChild(row);
            });
            body.appendChild(rRows);
        }

        body.appendChild(el('div', 'actions-title', 'All gangs \u2014 click one for detail'));
        const headRow = el('div', 'table-head');
        headRow.style.gridTemplateColumns = '2fr 1.2fr 1.2fr 1fr .9fr 1.3fr';
        ['Gang', 'Faction', 'Level', 'Points', 'Radius', 'Members / Table'].forEach(t => headRow.appendChild(el('div', null, t)));
        body.appendChild(headRow);

        const rows = el('div');
        body.appendChild(rows);
        pagedList(rows, list, g => (String(g.name || '') + ' ' + (g.shortname || '') + ' ' + (g.factionLabel || g.faction || '')), g => {
            const row = el('div', 'prow');
            row.style.gridTemplateColumns = '2fr 1.2fr 1.2fr 1fr .9fr 1.3fr';
            row.style.cursor = 'pointer';
            row.addEventListener('click', () => { gangView = g.id; renderGangDetail(g); });

            const nw = el('div', 'pname');
            const nn = el('div');
            nn.appendChild(el('div', 'n', (g.shortname ? '[' + g.shortname + '] ' : '') + g.name));
            nn.appendChild(el('div', 's', '#' + g.id + ' \u2022 ' + (g.activityScore || 'LOW') + ' activity'
                + (g.motd ? ' \u2022 ' + g.motd : '')));
            nw.appendChild(nn);
            row.appendChild(nw);

            row.appendChild(el('div', null, g.factionLabel || g.faction));
            row.appendChild(el('div', null, g.level + ' \u2022 ' + (g.levelLabel || '')));
            row.appendChild(el('div', null, fmt(g.points)));
            row.appendChild(el('div', null, Math.floor(g.radius) + 'm'));
            row.appendChild(el('div', null, (g.members || []).length + (g.hasTable ? ' \u2022 table' : ' \u2022 no table')));
            return row;
        }, { placeholder: 'Search gangs by name or faction...' });

        if (!list.length) body.appendChild(el('div', 'empty', 'No gangs founded yet.'));
    };
    /* RANCH ENVIRONMENT ------------------------------------------------------
       q_ranch drives everything a ranch produces: milk and eggs are
       (minigame score / 10) x (environment / 300) x 42, so at environment 0 a
       perfect run still pays nothing.

       pup_ranchero decays it by 10 every 30 minutes (server/upkeep.lua, the chore reset
       loop). The panel only ever receives a SNAPSHOT of the value, so if the
       page is left open the number on screen drifts high. These helpers project
       it forward from when it was observed.

       The decay thread is started by the resource, waits 30 minutes, then
       repeats - so the ticks land on :00 and :30, and the tick that WOULD have
       fired at a restart never does, because the resource restarted instead.
       Those hours are therefore skipped.

       RESTART TIMES ARE IN THE SERVER'S OWN TIMEZONE, not the viewer's. They
       come from txData/config.json -> schedule, which txAdmin runs on server
       local time. This box is on Europe/London, so that is what is checked
       here. If the host moves, change RANCH_ENV.restartZone or the projection
       silently skips the wrong ticks. */
    const RANCH_ENV = {
        max: 300,
        dropPerTick: 10,
        tickMinutes: 30,
        restartHours: [0, 8, 16],
        restartZone: 'Europe/London',
    };

    const ranchEnvironmentData = {};   /* ranchId -> { value, max, observedAt } */

    /* hour/minute in a named zone, DST handled by the browser's own tz data */
    const zonedParts = (date, zone) => {
        try {
            const p = new Intl.DateTimeFormat('en-GB', {
                timeZone: zone, hour12: false,
                hour: '2-digit', minute: '2-digit',
            }).formatToParts(date);
            const get = (t) => Number((p.find(x => x.type === t) || {}).value);
            return { hour: get('hour') % 24, minute: get('minute') };
        } catch (e) {
            return { hour: date.getUTCHours(), minute: date.getUTCMinutes() };
        }
    };

    const calculateCurrentEnvironment = (ranchId, now = new Date()) => {
        const state = ranchEnvironmentData[ranchId];
        const storedValue = Number(state && (state.value != null ? state.value : state.percent));
        if (!state || !Number.isFinite(storedValue) || !state.observedAt) return null;

        const observedAt = new Date(state.observedAt);
        if (Number.isNaN(observedAt.getTime())) return null;

        const max = Number(state.max || RANCH_ENV.max);
        let currentValue = Math.max(0, Math.min(max, storedValue));

        /* first tick boundary strictly after the observation */
        let boundary = new Date(observedAt);
        boundary.setUTCSeconds(0, 0);
        const step = RANCH_ENV.tickMinutes;
        boundary = new Date(boundary.getTime()
            + (step - (boundary.getUTCMinutes() % step || step)) * 60 * 1000);
        if (boundary <= observedAt) boundary = new Date(boundary.getTime() + step * 60 * 1000);

        /* it can never drop more times than it has points to lose */
        const maximumDrops = Math.ceil(currentValue / RANCH_ENV.dropPerTick);
        let drops = 0;
        while (boundary <= now && currentValue > 0) {
            const t = zonedParts(boundary, RANCH_ENV.restartZone);
            const isRestart = t.minute === 0 && RANCH_ENV.restartHours.indexOf(t.hour) !== -1;
            if (!isRestart) {
                currentValue = Math.max(0, currentValue - RANCH_ENV.dropPerTick);
                drops++;
            }
            boundary = new Date(boundary.getTime() + step * 60 * 1000);
            if (drops >= maximumDrops) break;
        }
        return currentValue;
    };

    /* how long until the next decay tick, in whole minutes */
    const minutesToNextDrop = (now = new Date()) => {
        const step = RANCH_ENV.tickMinutes;
        const mins = now.getUTCMinutes() % step;
        return step - mins - (now.getUTCSeconds() > 0 ? 1 : 0);
    };

    /* "148 / 300 (49%)" plus what that actually pays at a perfect score.
       `now` is injectable so this can be reasoned about at a fixed time. */
    const ranchEnvText = (ranchId, fallback, now = new Date()) => {
        const v = calculateCurrentEnvironment(ranchId, now);
        const value = v === null ? Number(fallback || 0) : v;
        const pct = Math.floor((value / RANCH_ENV.max) * 100);
        const bestYield = Math.floor((value / RANCH_ENV.max) * 42 + 0.5);
        return { value: value, pct: pct, bestYield: bestYield };
    };

    const renderRanches = (data) => {
        const body = $('#ranchesBody');
        body.textContent = '';
        if (!data || data.missing) {
            body.appendChild(el('div', 'empty', data && data.missing ? 'pup_ranchero is not running' : 'No access (needs the manage_ranch permission)'));
            return;
        }
        ranchData = data;
        const list = data.list || [];
        const names = data.names || {};

        /* stamp every quality reading with the moment it arrived, so the decay
           projection has something to count forward from */
        const observedAt = new Date().toISOString();
        list.forEach(r => {
            ranchEnvironmentData[r.id] = {
                value: Number(r.quality) || 0,
                max: RANCH_ENV.max,
                observedAt: observedAt,
            };
        });

        if (ranchView) {
            const fresh = list.find(x => x.id === ranchView);
            if (fresh) return renderRanchDetail(fresh);
            ranchView = null;
        }

        const cards = el('div', 'cards small');
        cards.appendChild(card('Ranches', '', valueNode(fmt(list.length)), '⛺'));
        cards.appendChild(card('Owned', '', valueNode(fmt(list.filter(r => r.owned === 1).length)), '✔'));
        cards.appendChild(card('For Sale', '', valueNode(fmt(list.filter(r => r.owned !== 1).length)), '$'));
        cards.appendChild(card('Ledgers Total', '', valueNode(fmtMoney(list.reduce((n, r) => n + (r.ledger || 0), 0))), '⛁'));
        body.appendChild(cards);

        const headRow = el('div', 'table-head');
        headRow.style.gridTemplateColumns = '1.4fr 1.4fr 1fr 1fr 1.2fr 1.1fr';
        ['Ranch', 'Owner', 'Price / Tax', 'Ledger', 'Herd / Production', 'Environment']
            .forEach(t => headRow.appendChild(el('div', null, t)));
        body.appendChild(headRow);

        const rows = el('div');
        body.appendChild(rows);
        pagedList(rows, list,
            r => ((r.name || ('ranch ' + r.id)) + ' ' + (names[r.ownerCharid] || '') + ' ' + (r.owned === 1 ? 'owned' : 'for sale')),
            r => {
            const row = el('div', 'prow');
            row.style.gridTemplateColumns = '1.4fr 1.4fr 1fr 1fr 1.2fr 1.1fr';
            row.style.cursor = 'pointer';
            row.addEventListener('click', () => renderRanchDetail(r));
            const nw = el('div', 'pname');
            const nn = el('div');
            nn.appendChild(el('div', 'n', r.name || ('Ranch #' + r.id)));
            nn.appendChild(el('div', 's', '#' + r.id + (r.repoed === 1 ? ' • repo' : '')));
            nw.appendChild(nn);
            row.appendChild(nw);

            const oc = el('div');
            if (r.owned === 1 && r.ownerCharid) {
                const chip = el('span', 'chip', (names[r.ownerCharid] || '?') + ' (' + r.ownerCharid + ')');
                chip.style.cursor = 'pointer';
                chip.addEventListener('click', (ev) => { ev.stopPropagation(); openDetail(r.ownerCharid); });
                oc.appendChild(chip);
            } else {
                oc.appendChild(el('span', 'chip', 'for sale'));
            }
            row.appendChild(oc);

            row.appendChild(el('div', 'pxp', fmtMoney(r.price) + ' / ' + fmtMoney(r.tax)));
            row.appendChild(el('div', 'pmoney', fmtMoney(r.ledger || 0)));
            row.appendChild(el('div', 'pxp',
                (r.cattleCount || 0) + ' cattle • ' + (r.milk || 0) + ' milk • ' + (r.eggs || 0) + ' eggs'));

            /* projected forward from the snapshot, not the raw payload value */
            const env = ranchEnvText(r.id, r.quality);
            const ec = el('div');
            const chip = el('span', 'chip', env.value + ' / ' + RANCH_ENV.max + '  (' + env.pct + '%)');
            if (env.value <= 0)        chip.style.background = 'rgba(200,60,60,.20)';
            else if (env.pct < 34)     chip.style.background = 'rgba(200,140,40,.18)';
            ec.appendChild(chip);
            ec.appendChild(el('div', 's', env.value <= 0
                ? 'produces nothing'
                : 'up to ' + env.bestYield + ' per collection'));
            row.appendChild(ec);
            return row;
        }, { placeholder: 'Search ranches by name, owner or status...' });

        /* global activity feed */
        const acC = el('div', 'card actions-card');
        acC.style.marginTop = '.9vw';
        acC.appendChild(el('div', 'actions-title', 'Recent Activity (all ranches)'));
        if (!(data.activity || []).length) {
            acC.appendChild(el('div', 'offline-note', 'None recorded'));
        } else {
            /* pup: paged, so every fetched entry stays reachable. */
            /* same treatment as the society feed: charid in the search text and
               the action type as tabs - HERD, EGGS, MILK, CHORE, CATTLE_BUY,
               HIRE and the rest come straight from the data. */
            pagedList(acC, data.activity,
                a => fmtDate(a.ts, true) + ' ranch #' + a.ranchid + ' ' + (a.actor || '')
                     + ' ' + (a.charid || '') + ' ' + (a.type || '') + ' ' + (a.detail || ''),
                a => el('div', 'offline-note',
                    fmtDate(a.ts, true) + ' — ranch #' + a.ranchid + ' — ' + (a.actor || '?')
                    + (a.charid ? ' (' + a.charid + ')' : '')
                    + ': ' + (a.type || '') + ' ' + (a.detail || '')),
                { per: 10, categoryOf: a => a.type,
                  placeholder: 'Search by ranch, player name, character ID or action...' });
        }
        body.appendChild(acC);
    };

    const renderRanchDetail = (r) => {
        ranchView = r.id;
        const body = $('#ranchesBody');
        body.textContent = '';
        const names = (ranchData && ranchData.names) || {};

        const back = el('button', 'back-btn', '← Back to ranches');
        back.addEventListener('click', () => { ranchView = null; post('panelRanches'); });
        body.appendChild(back);

        const grid = el('div', 'info-grid');
        grid.appendChild(kvCard((r.name || ('Ranch #' + r.id)) + ' (#' + r.id + ')', [
            ['Owner', r.owned === 1 ? ((names[r.ownerCharid] || '?') + ' (char ' + r.ownerCharid + ')') : 'for sale'],
            ['Price', fmtMoney(r.price)], ['Tax', fmtMoney(r.tax)],
            ['Ledger', fmtMoney(r.ledger || 0)],
            ['Repo', r.repoed === 1 ? 'YES' : 'no'],
            ['Quality', r.quality || 0],
            ['Cattle', r.cattleCount || 0],
            ['Milk stored', r.milk || 0], ['Eggs stored', r.eggs || 0],
            ['Cow pen', r.hasCowPen ? 'built' : '—'], ['Chicken coop', r.hasChickenCoop ? 'built' : '—'],
        ]));

        /* hands - one row each, with the rank change and the firing on the row
           itself rather than hidden behind a separate form */
        const ranchAct = (payload) => post('panelRanchAction', Object.assign({ id: r.id }, payload));
        const hc = el('div', 'card info-card');
        hc.appendChild(el('div', 'icard-title', 'Ranch Hands (' + (r.hired || []).length + ')'));

        const hireF = el('div', 'action-form');
        const hireI = el('input', 'narrow');
        hireI.placeholder = 'charid';
        const hireB = el('button', 'abtn', 'Hire');
        hireB.addEventListener('click', () => {
            const v = Number(hireI.value);
            if (!v) return;
            ranchAct({ action: 'hire', value: v });
            hireI.value = '';
        });
        hireF.appendChild(el('span', 'offline-note', 'Hire by character ID'));
        hireF.appendChild(hireI); hireF.appendChild(hireB);
        hc.appendChild(hireF);

        if (!(r.hired || []).length) {
            hc.appendChild(el('div', 'offline-note', 'Nobody hired'));
        } else {
            const list = el('div', 'asset-list');
            r.hired.forEach(h => {
                const a = el('div', 'aitem');
                const left = el('div');
                const nm = el('div', null, h.name || ('char ' + h.charid));
                if (h.manager) nm.appendChild(el('span', 'ownchip', 'Manager'));
                left.appendChild(nm);
                left.appendChild(el('div', 'sub', 'char ' + h.charid));
                a.appendChild(left);

                const btns = el('div', 'onacts');
                const mk = (label, fn, cls) => {
                    const b = el('button', 'abtn' + (cls ? ' ' + cls : ''), label);
                    b.addEventListener('click', fn);
                    btns.appendChild(b);
                };
                mk('Profile', () => openDetail(Number(h.charid)));
                /* only the owner may change ranks in game, so this is admin-only ground */
                mk(h.manager ? 'Demote' : 'Promote',
                    () => ranchAct({ action: 'rank', value: Number(h.charid), manager: !h.manager }));
                mk('Fire', () => askConfirm({
                    title: 'Fire ' + (h.name || ('char ' + h.charid)) + '?',
                    body: 'They lose access to this ranch immediately.',
                    okLabel: 'Fire', danger: true,
                    onOk: () => ranchAct({ action: 'fire', value: Number(h.charid) }),
                }), 'warn');
                a.appendChild(btns);
                return list.appendChild(a);
            });
            hc.appendChild(list);
        }
        grid.appendChild(hc);
        body.appendChild(grid);

        /* actions */
        const ac = el('div', 'card actions-card');
        ac.appendChild(el('div', 'actions-title', 'Actions'));
        const f = el('div', 'action-form');
        const price = el('input', 'narrow'); price.value = String(r.price || 0);
        const sp = el('button', 'abtn', 'Set Price');
        sp.addEventListener('click', () => post('panelRanchAction', { action: 'setprice', id: r.id, value: Number(price.value) }));
        const tax = el('input', 'narrow'); tax.value = String(r.tax || 0);
        const st = el('button', 'abtn', 'Set Tax');
        st.addEventListener('click', () => post('panelRanchAction', { action: 'settax', id: r.id, value: Number(tax.value) }));
        f.appendChild(price); f.appendChild(sp); f.appendChild(tax); f.appendChild(st);
        ac.appendChild(f);

        /* ownership + location. charid 0 clears the owner and puts it back on sale. */
        const f2 = el('div', 'action-form');
        const owner = el('input', 'narrow');
        owner.placeholder = 'charid';
        owner.value = r.ownerCharid ? String(r.ownerCharid) : '';
        const tr = el('button', 'abtn', 'Transfer');
        tr.addEventListener('click', () => {
            const v = owner.value.trim() === '' ? 0 : Number(owner.value);
            if (!Number.isFinite(v) || v < 0) {
                showPanelToast({ text: 'charid must be a number, or 0 to clear the owner.', error: true });
                return;
            }
            post('panelRanchAction', { action: 'transfer', id: r.id, value: v });
        });
        f2.appendChild(owner); f2.appendChild(tr);

        /* the panel has no map picker: the ranch comes to wherever the admin stands */
        const mv = el('button', 'abtn warn', 'Move Here');
        mv.addEventListener('click', () => post('panelRanchAction', { action: 'move', id: r.id }));
        f2.appendChild(mv);
        ac.appendChild(f2);

        /* DELETE: typed confirmation, and the server re-checks the same word */
        const f3 = el('div', 'action-form');
        const conf = el('input', 'narrow');
        conf.placeholder = 'type DELETE';
        const dl = el('button', 'abtn warn', 'Delete Ranch');
        dl.addEventListener('click', () => {
            if (conf.value.trim() !== 'DELETE') {
                showPanelToast({ text: 'Type DELETE in the box first.', error: true });
                return;
            }
            post('panelRanchAction', { action: 'delete', id: r.id, confirm: 'DELETE' });
            conf.value = '';
        });
        f3.appendChild(conf); f3.appendChild(dl);
        ac.appendChild(f3);

        ac.appendChild(el('div', 'offline-note',
            'Transfer clears the hired hands. Move puts the ranch at your feet. Delete takes the cattle, '
            + 'pens, stored produce and ledger with it and cannot be undone. Create and sell stay in-world.'));
        body.appendChild(ac);
    };

    /* ------------------------------------------------------------- society page */
    let societyData = null;
    let societyView = null; // job while a detail is open - refreshes stay on it

    const socAct = (payload) => post('panelSocietyAction', payload);

    const renderSociety = (data) => {
        const body = $('#societyBody');
        body.textContent = '';
        if (!data || data.missing) {
            body.appendChild(el('div', 'empty', data && data.missing ? 'pup_business is not running' : 'No access (needs the manage_society permission)'));
            return;
        }
        societyData = data;
        const list = data.list || [];

        // toggles/settings refresh must NOT bounce back to the list - stay on
        // the open business with its fresh row
        if (societyView) {
            const fresh = list.find(x => x.job === societyView);
            if (fresh) return renderSocietyDetail(fresh);
            societyView = null; // deleted - fall through to the list
        }

        /* fully panel-native creation - proper form with validation. Your
           current spot seeds the first management + job menu point; add more
           from the business detail view afterwards. */
        const createCard = el('div', 'card actions-card');
        createCard.appendChild(el('div', 'actions-title', 'Create Business'));

        const cJob = el('input'); cJob.placeholder = 'butcher';
        const cName = el('input'); cName.placeholder = 'Valentine Butcher';
        const cBoss = el('input', 'narrow'); cBoss.value = '5';
        const cRec = el('input', 'narrow'); cRec.value = '3';
        const row = (label, input, hint) => {
            const f = el('div', 'action-form');
            const l = el('span', 'offline-note', label);
            l.style.width = '8vw';
            f.appendChild(l); f.appendChild(input);
            f.appendChild(el('span', 'offline-note', hint));
            createCard.appendChild(f);
        };
        row('Job name', cJob, 'internal id - lowercase letters, numbers, _ (becomes the job on characters)');
        row('Display name', cName, 'shown to players; defaults to the job name');
        row('Boss rank', cBoss, 'highest grade - the owner/boss level');
        row('Recruit rank', cRec, 'minimum grade allowed to hire');

        const cFoot = el('div', 'action-form');
        const cMsg = el('span', 'offline-note', 'creates at YOUR current position (first management + job menu point)');
        const cBtn = el('button', 'abtn', 'Create Business Here');
        cBtn.addEventListener('click', () => {
            const job = cJob.value.trim().toLowerCase().replace(/[^a-z0-9_]/g, '');
            if (job === '') {
                cMsg.textContent = 'A job name is required (letters, numbers, _).';
                return;
            }
            if (list.some(b => b.job === job)) {
                cMsg.textContent = 'That job name already exists - pick another.';
                return;
            }
            const boss = Number(cBoss.value) || 1;
            const rec = Number(cRec.value) || 0;
            if (rec > boss) {
                cMsg.textContent = 'Recruit rank cannot be higher than the boss rank.';
                return;
            }
            cMsg.textContent = 'Creating "' + job + '" at your position…';
            socAct({ action: 'create', job, name: cName.value.trim(), bossrank: boss });
            // recruit rank is a separate column - set it right after creation
            setTimeout(() => socAct({ action: 'update', job, changes: { recruitmentrank: rec } }), 900);
            cJob.value = ''; cName.value = '';
        });
        cFoot.appendChild(cBtn); cFoot.appendChild(cMsg);
        createCard.appendChild(cFoot);
        body.appendChild(createCard);

        const cards = el('div', 'cards small');
        cards.appendChild(card('Businesses', '', valueNode(fmt(list.length)), '⚖'));
        cards.appendChild(card('Employees', 'across all societies', valueNode(fmt(list.reduce((n, b) => n + (b.staffcount || 0), 0))), '♟'));
        cards.appendChild(card('Ledgers Total', '', valueNode(fmtMoney(list.reduce((n, b) => n + (b.ledger || 0), 0))), '$'));
        cards.appendChild(card('With Billing', '', valueNode(fmt(list.filter(b => b.billing).length)), '✉'));
        body.appendChild(cards);

        const headRow = el('div', 'table-head');
        headRow.style.gridTemplateColumns = '1.6fr 1.2fr 1fr 1fr 1.2fr';
        ['Business', 'Boss', 'Staff', 'Ledger', 'Last Active'].forEach(t => headRow.appendChild(el('div', null, t)));
        body.appendChild(headRow);

        const rows = el('div');
        body.appendChild(rows);
        pagedList(rows, list, b => (String(b.name || '') + ' ' + String(b.job || '') + ' ' + (b.owner || '')), b => {
            const row = el('div', 'prow');
            row.style.gridTemplateColumns = '1.6fr 1.2fr 1fr 1fr 1.2fr';
            row.style.cursor = 'pointer';
            row.addEventListener('click', () => renderSocietyDetail(b));
            const nw = el('div', 'pname');
            const nn = el('div');
            nn.appendChild(el('div', 'n', b.name || b.job));
            nn.appendChild(el('div', 's', b.job));
            nw.appendChild(nn);
            row.appendChild(nw);
            row.appendChild(el('div', 'pxp', b.owner || '—'));
            row.appendChild(el('div', 'pxp', String(b.staffcount || 0)));
            row.appendChild(el('div', 'pmoney', fmtMoney(b.ledger || 0)));
            row.appendChild(el('div', 'pxp', b.lastactive > 0 ? fmtDate(b.lastactive, true) : '—'));
            return row;
        }, { placeholder: 'Search businesses by name, job or boss...' });
    };

    const renderSocietyDetail = (b) => {
        societyView = b.job;
        const body = $('#societyBody');
        body.textContent = '';

        const back = el('button', 'back-btn', '← Back to societies');
        back.addEventListener('click', () => { societyView = null; post('panelSociety'); });
        body.appendChild(back);

        const grid = el('div', 'info-grid');
        grid.appendChild(kvCard(b.name + ' (' + b.job + ')', [
            ['Boss', b.owner || '—'],
            ['Staff', b.staffcount || 0],
            ['Ledger', fmtMoney(b.ledger || 0)],
            ['Boss rank', b.bossrank], ['Recruit rank', b.recruitmentrank],
            ['Billing', b.billing ? 'on' : 'off'], ['Salary', b.salary ? 'on' : 'off'],
            ['Webhook', b.webhook ? 'on' : 'off'], ['Blip', b.showblip ? 'on' : 'off'],
            ['Tax', b.tax ? 'on' : 'off'],
            ['Blip sprite', b.blipsprite],
            ['PO address', b.mailhandle || '— none —'],
            ['Stash slots', fmt((Number(b.baseSlots) || 1500) + (Number(b.boughtslots) || 0))
                + ' total (' + fmt(b.boughtslots || 0) + ' bought)'],
            ['Last active', b.lastactive > 0 ? fmtDate(b.lastactive, true) : '—'],
        ]));

        /* settings */
        const sc = el('div', 'card info-card');
        sc.appendChild(el('div', 'icard-title', 'Settings'));
        const srow = (label, inputEl, saveFn) => {
            const f = el('div', 'action-form');
            const lbl = el('span', 'offline-note', label);
            lbl.style.width = '7vw';
            const sv = el('button', 'abtn', 'Set');
            sv.addEventListener('click', saveFn);
            f.appendChild(lbl); f.appendChild(inputEl); f.appendChild(sv);
            sc.appendChild(f);
        };
        const nameI = el('input'); nameI.value = b.name || '';
        srow('Name', nameI, () => socAct({ action: 'update', job: b.job, changes: { name: nameI.value } }));
        const bossI = el('input', 'narrow'); bossI.value = String(b.bossrank || 0);
        srow('Boss rank', bossI, () => socAct({ action: 'update', job: b.job, changes: { bossrank: Number(bossI.value) } }));
        const recI = el('input', 'narrow'); recI.value = String(b.recruitmentrank || 0);
        srow('Recruit rank', recI, () => socAct({ action: 'update', job: b.job, changes: { recruitmentrank: Number(recI.value) } }));
        /* pup: blipsprite comes in the adminOverview payload (pup_business). The default sprite is
           Config.DefaultBlipSprite in pup_business/config/main.lua. */
        const sprI = el('input'); sprI.value = String(b.blipsprite || '');
        srow('Blip sprite', sprI, () => {
            const v = parseInt(sprI.value, 10);
            if (!isNaN(v)) socAct({ action: 'update', job: b.job, changes: { blipsprite: v } });
        });
        /* business PO address - 3 letters then 3 numbers, e.g. val556. Blank it
           out and nothing is sent; pup_postoffice rejects a taken one and suggests a free. */
        const mailI = el('input', 'narrow'); mailI.value = b.mailhandle || '';
        mailI.placeholder = 'val556';
        srow('PO address', mailI, () => {
            const v = mailI.value.trim().toLowerCase();
            if (v) socAct({ action: 'setmailhandle', job: b.job, handle: v });
        });
        /* TOTAL stash slots, not the extra on top.
           pup_business stores what the business BOUGHT (container.invslots) and
           the real capacity is base + bought. An admin typing 5,000 means 5,000,
           so the total is what is shown and typed here and the extra is worked
           out before sending. The stored meaning is unchanged, which matters
           because the in-game upgrade adds to the same figure.
           Setting it costs the business nothing; the upgrade still bills the
           ledger. pup_business re-registers the container, so it applies now. */
        const stashBase = Number(b.baseSlots) || 1500;
        const stashTotal = stashBase + (Number(b.boughtslots) || 0);
        const slotI = el('input', 'narrow'); slotI.value = String(stashTotal);
        srow('Total stash slots', slotI, () => {
            const v = parseInt(slotI.value, 10);
            if (isNaN(v)) return;
            // cannot go under the base every business gets; show the clamp rather
            // than silently sending something else
            const total = Math.max(stashBase, v);
            slotI.value = String(total);
            socAct({ action: 'setslots', job: b.job, value: total - stashBase });
        });
        sc.appendChild(el('div', 'offline-note',
            'Type the TOTAL you want. ' + fmt(stashBase) + ' base is included, so that is the minimum.'));

        const tgl = el('div', 'actions-grid');
        [['billing', 'Billing'], ['salary', 'Salary'], ['webhook', 'Webhook'], ['showblip', 'Blip'],
         ['tax', 'Tax']].forEach(([k, label]) => {
            const btn = el('button', 'abtn', label + ': ' + (b[k] ? 'ON' : 'OFF'));
            btn.addEventListener('click', () => socAct({ action: 'update', job: b.job, changes: { [k]: !b[k] } }));
            tgl.appendChild(btn);
        });
        sc.appendChild(tgl);
        grid.appendChild(sc);
        body.appendChild(grid);

        /* storage: the real business stash, not a list */
        body.appendChild(storageCard('Storage', 'Open storage',
            fmt(stashTotal) + ' slots in total',
            'Closes the panel and opens this business\'s real stash with the boss\'s controls: '
            + 'take items out or put them in, from anywhere. Your job does not change. Logged.',
            () => post('panelSocietyOpenStash', { job: b.job })));

        /* staff */
        const stc = el('div', 'card actions-card');
        stc.appendChild(el('div', 'actions-title', 'Staff (' + (b.staff || []).length + ') - click a name for the profile'));
        // search by name, character id or rank; the rows repaint as the admin types
        const staffRows = el('div');
        const staffFilter = { text: '' };
        const paintStaff = () => {
            staffRows.textContent = '';
            const f = staffFilter.text.trim().toLowerCase();
            const shown = (b.staff || []).filter(s => f === ''
                || (s.name + ' ' + s.charid + ' rank ' + (s.grade || 0)).toLowerCase().includes(f));
            if (!shown.length) staffRows.appendChild(el('div', 'empty', 'Nothing matches "' + staffFilter.text + '"'));
            shown.forEach(s => {
                const f2 = el('div', 'action-form');
                const nameBtn = el('button', 'abtn', s.name + ' (char ' + s.charid + ')');
                nameBtn.addEventListener('click', () => openDetail(Number(s.charid)));
                f2.appendChild(nameBtn);
                f2.appendChild(el('span', 'offline-note', 'rank ' + (s.grade || 0)));
                const rankI = el('input', 'narrow'); rankI.value = String(s.grade || 0);
                const rk = el('button', 'abtn', 'Set Rank');
                rk.addEventListener('click', () => socAct({ action: 'setrank', job: b.job, grade: Number(rankI.value), charid: Number(s.charid) }));
                f2.appendChild(rankI); f2.appendChild(rk);
                const fire = el('button', 'abtn warn', 'Fire');
                fire.addEventListener('click', () => socAct({ action: 'fire', job: b.job, charid: Number(s.charid) }));
                f2.appendChild(fire);
                staffRows.appendChild(f2);
            });
        };
        if ((b.staff || []).length > 5) {
            const sb = el('div', 'searchbar');
            const si = el('input');
            si.placeholder = 'Search staff by name, character ID or rank...';
            si.addEventListener('input', () => { staffFilter.text = si.value; paintStaff(); });
            sb.appendChild(si);
            stc.appendChild(sb);
        }
        stc.appendChild(staffRows);
        paintStaff();
        const hf = el('div', 'action-form');
        const hireI = el('input', 'narrow'); hireI.placeholder = 'server id';
        const hb = el('button', 'abtn', 'Hire (online player)');
        hb.addEventListener('click', () => {
            if (Number(hireI.value) > 0) socAct({ action: 'hire', job: b.job, serverId: Number(hireI.value) });
        });
        hf.appendChild(hireI); hf.appendChild(hb);
        stc.appendChild(hf);
        body.appendChild(stc);

        /* management + job menu points - panel-native placement: "Add My
           Position" grabs where the admin is standing right now */
        const pointsCard = (title, key, points) => {
            const pc = el('div', 'card actions-card');
            pc.appendChild(el('div', 'actions-title', title + ' (' + (points || []).length + ')'));
            const grid2 = el('div', 'actions-grid');
            (points || []).forEach((p, i) => {
                grid2.appendChild(el('span', 'chip',
                    '#' + (i + 1) + '  ' + Math.round(p.x) + ', ' + Math.round(p.y) + ', ' + Math.round(p.z)));
                const rm = el('button', 'abtn warn', '✕');
                rm.addEventListener('click', () => {
                    const kept = (points || []).filter((_, j) => j !== i);
                    socAct({ action: 'points', job: b.job, key, points: kept });
                });
                grid2.appendChild(rm);
            });
            const add = el('button', 'abtn', '+ Add My Position');
            add.addEventListener('click', () => socAct({ action: 'points', job: b.job, key, points: points || [], addhere: true }));
            grid2.appendChild(add);
            pc.appendChild(grid2);
            body.appendChild(pc);
        };
        pointsCard('Management Points', 'positions', b.positions);
        pointsCard('Job Menu Points', 'jobmenu', b.jobmenu);

        /* shops (async fill) */
        const shc = el('div', 'card actions-card');
        shc.appendChild(el('div', 'actions-title', 'Shops'));
        const shBody = el('div');
        shBody.id = 'societyShopsBody';
        shBody.appendChild(el('div', 'offline-note', 'loading…'));
        shc.appendChild(shBody);
        body.appendChild(shc);
        post('panelSocietyShops', { job: b.job });

        /* activity */
        const acC = el('div', 'card actions-card');
        acC.appendChild(el('div', 'actions-title', 'Recent Activity'));
        if (!(b.activity || []).length) {
            acC.appendChild(el('div', 'offline-note', 'None recorded'));
        } else {
            /* charid is in the search text so an admin can type 1518 and get
               that character's rows; the server resolves it from the actor name
               because society_activity only stores a name. categoryOf turns the
               action type into tabs - Bills, Withdraw, Rank, Duty and so on -
               derived from the feed itself, so a new action type appears without
               touching this. */
            pagedList(acC, b.activity,
                a => fmtDate(a.ts, true) + ' ' + (a.actor || '') + ' ' + (a.charid || '')
                     + ' ' + (a.type || '') + ' ' + (a.detail || ''),
                a => el('div', 'offline-note',
                    fmtDate(a.ts, true) + ' — ' + (a.actor || '?')
                    + (a.charid ? ' (' + a.charid + ')' : '')
                    + ': ' + (a.type || '') + ' ' + (a.detail || '')),
                { per: 10, categoryOf: a => a.type,
                  placeholder: 'Search by player name, character ID or action...' });
        }
        body.appendChild(acC);

        /* danger zone - the business team runs businesses, it does not remove them */
        const dz = el('div', 'card actions-card');
        dz.appendChild(el('div', 'actions-title', 'Danger Zone'));
        if (!hasPerm('delete_society')) {
            dz.appendChild(el('div', 'offline-note', 'Deleting a business is Management only.'));
            body.appendChild(dz);
            return;
        }
        const df = el('div', 'action-form');
        /* HANDING A BUSINESS OVER. Both wipes the delete path does, without
           removing the business, its staff, its ledger or its ranks - so a new
           owner starts on empty shelves. */
        const handover = el('div', 'actions-grid');
        const clrStash = el('button', 'abtn warn', 'Clear Storage');
        clrStash.addEventListener('click', () => askConfirm({
            title: 'Empty the storage of ' + b.name + '?',
            body: 'Removes <b>every item in the business container</b>, the one staff open as '
                + 'the shared stash. The container itself, staff, ranks, the ledger and the '
                + 'business are left alone. This <b>cannot be undone</b>.',
            okLabel: 'Empty storage',
            danger: true,
            onOk: () => socAct({ action: 'clear', job: b.job, kind: 'stash' }),
        }));
        const clrShops = el('button', 'abtn warn', 'Clear Shop Fronts');
        clrShops.addEventListener('click', () => askConfirm({
            title: 'Empty every shop front of ' + b.name + '?',
            body: 'Clears the <b>stock, prices and buy listings</b> of every shop this business '
                + 'owns. The shops themselves stay where they are, along with the business, '
                + 'its storage and its staff. This <b>cannot be undone</b>.',
            okLabel: 'Empty shops',
            danger: true,
            onOk: () => socAct({ action: 'clear', job: b.job, kind: 'shops' }),
        }));
        handover.appendChild(clrStash);
        handover.appendChild(clrShops);
        df.appendChild(el('span', 'offline-note',
            'handing the business to a new owner: clear what the last one left behind'));
        df.appendChild(handover);

        const conf = el('input'); conf.placeholder = 'type DELETE to confirm';
        const del = el('button', 'abtn warn', 'Delete Business');
        const delMsg = el('span', 'offline-note',
            'releases all staff to unemployed, then removes the business, its storage and '
            + 'contents, ledger, bills, history and shops');
        del.addEventListener('click', () => {
            if (conf.value.trim() !== 'DELETE') {
                delMsg.textContent = 'Type DELETE in the box first.';
                return;
            }
            /* pup: staff do not block the delete - the server releases them to
               unemployed first. Still name the number, because it is the one part
               of this that changes other people's characters. */
            const staff = Number(b.staffcount || 0);
            askConfirm({
                title: 'Delete ' + b.name + '?',
                body: (staff > 0
                        ? '<b>' + staff + ' character(s)</b> will be made unemployed, including yourself if you '
                          + 'hold this job.<br><br>'
                        : '')
                    + 'Deletes the business, its <b>storage and everything in it</b>, its ledger balance, '
                    + 'bills, activity history and any society shops. This <b>cannot be undone</b>.',
                okLabel: 'Delete business',
                danger: true,
                onOk: () => { socAct({ action: 'delete', job: b.job }); societyView = null; },
            });
        });
        df.appendChild(conf); df.appendChild(del);
        df.appendChild(delMsg);
        dz.appendChild(df);
        body.appendChild(dz);
    };

    const renderSocietyShops = (payload) => {
        const shBody = document.getElementById('societyShopsBody');
        if (!shBody || !payload) return;
        shBody.textContent = '';
        const d = payload.data;
        if (!d || d.ready === false || !Array.isArray(d.shops)) {
            shBody.appendChild(el('div', 'offline-note', 'pup_mercantile not available or no shops'));
            return;
        }
        if (!d.shops.length) {
            shBody.appendChild(el('div', 'offline-note', 'This business has no shops'));
            return;
        }
        d.shops.forEach(s => {
            const f = el('div', 'action-form');
            f.appendChild(el('span', 'offline-note', '#' + s.id + ' ' + (s.name || '')));
            const nameI = el('input'); nameI.value = s.name || '';
            const rn = el('button', 'abtn', 'Rename');
            rn.addEventListener('click', () => socAct({ action: 'shop', job: payload.job, shopId: s.id, act: 'rename', value: nameI.value }));
            f.appendChild(nameI); f.appendChild(rn);
            /* stock capacity, 50 out of the box. Lowering it below what is
               already stocked drops nothing - the shop just cannot take more. */
            const slI = el('input', 'narrow');
            slI.value = String(s.slots != null ? s.slots : 50);
            slI.title = 'Stock slots';
            const sl = el('button', 'abtn', 'Slots');
            sl.addEventListener('click', () => {
                const v = parseInt(slI.value, 10);
                if (!isNaN(v) && v > 0) {
                    socAct({ action: 'shop', job: payload.job, shopId: s.id, act: 'slots', value: v });
                }
            });
            f.appendChild(slI); f.appendChild(sl);
            const bl = el('button', 'abtn', 'Blip: ' + (Number(s.blip) === 1 ? 'ON' : 'OFF'));
            bl.addEventListener('click', () => socAct({ action: 'shop', job: payload.job, shopId: s.id, act: 'blip', value: Number(s.blip) !== 1 }));
            f.appendChild(bl);
            /* pup: MOVE HERE. pup_business's shopAction has a 'move' branch and
               pup_mercantile exports AdminMoveSocietyShop.
               No coordinates are sent from this page: it has no idea where the
               admin is standing, so client/panel.lua fills in their position.
               Confirmed first, because a misclick would drop the shop wherever
               the admin happens to be. */
            const mv = el('button', 'abtn', 'Move Here');
            mv.addEventListener('click', () => askConfirm({
                title: 'Move shop',
                body: 'Move <b>' + (s.name || ('#' + s.id)) + '</b> to where you are standing?',
                okLabel: 'Move it',
                onOk: () => socAct({ action: 'shop', job: payload.job, shopId: s.id, act: 'move' }),
            }));
            f.appendChild(mv);
            if (hasPerm('delete_society')) {
                const del = el('button', 'abtn warn', 'Delete');
                del.addEventListener('click', () => socAct({ action: 'shop', job: payload.job, shopId: s.id, act: 'delete' }));
                f.appendChild(del);
            }
            shBody.appendChild(f);
        });
    };

    /* Ban length. Seconds already, so nothing has to parse free text, and 0 is the
       permanent value the server already uses. */
    const BAN_DURATIONS = [
        ['86400',  '1 day'],
        ['259200', '3 days'],
        ['604800', '1 week'],
        ['0',      'Permanent'],
    ];

    function banDurationSelect() {
        const s = el('select', 'panel-select');
        BAN_DURATIONS.forEach(([v, label]) => {
            const o = el('option', '', label);
            o.value = v;
            if (v === '0') o.selected = true;   // same default the blank box had
            s.appendChild(o);
        });
        s.title = 'How long the ban lasts';
        return s;
    }

    /* same picker as markup, for the dialogs that take an HTML body */
    function banDurationSelectHTML(id) {
        return '<select id="' + id + '" class="panel-select">'
            + BAN_DURATIONS.map(([v, label]) =>
                '<option value="' + v + '"' + (v === '0' ? ' selected' : '') + '>' + label + '</option>').join('')
            + '</select>';
    }

    /* ------------------------------------------------------------- bans page
       Every ban is a row in admin_bans with its own Ban ID. The search box asks
       the server, so it reaches lifted bans and offline players too. */
    let banSearch = '';
    let banShowLifted = false;

    const buildBans = () => { post('panelServerBans', { search: banSearch, showLifted: banShowLifted }); };

    /* oxmysql hands a TIMESTAMP back as a millisecond epoch, not a string.
       Both shapes are handled. */
    function banWhen(v) {
        if (v === null || v === undefined || v === '') return '—';
        const n = Number(v);
        if (Number.isFinite(n) && n > 0) {
            return new Date(n > 1e11 ? n : n * 1000).toLocaleString();
        }
        return String(v).replace('T', ' ').slice(0, 16);
    }

    let banIssueTerm = '';  // the "Issue a ban" lookup box
    let banLookupRows = []; // who that lookup found
    let banLastData = null; // the last ban list, so a lookup can repaint without a refetch
    let banField = 'any';   // which column the search box looks at
    let banType = 'any';    // any | permanent | temporary | lifted
    let banAdmin = 'any';
    let banOpen = null;     // the ban_id whose detail panel is expanded

    /* lookup results arrive on their own; repaint the page around them */
    function renderBanLookup(d) {
        banLookupRows = (d && d.rows) || [];
        if (banLastData) renderServerBans(banLastData);
    }

    function renderServerBans(d) {
        const body = $('#bansBody');
        body.textContent = '';
        if (!d) { body.appendChild(el('div', 'empty', 'Could not read the ban list')); return; }
        banLastData = d;
        const st = d.stats || {};

        /* the four figures, same shape as every other page's header */
        const cards = el('div', 'cards small');
        cards.appendChild(card('Bans In Force', 'active right now', valueNode(fmt(st.inforce || 0)), '⊘'));
        cards.appendChild(card('New Bans Last 7d', '', valueNode('+' + fmt(st.last7d || 0)), '⚠'));
        cards.appendChild(card('Total Bans', 'ever issued', valueNode(fmt(st.total || 0)), '▤'));
        cards.appendChild(card('Lifted', 'appealed or expired', valueNode(fmt(st.lifted || 0)), '✓'));
        body.appendChild(cards);

        /* ISSUE A BAN - find them by server id, char id, name or any identifier.
           server_ban is its own permission: someone can be allowed to read the
           ban list and lift bans without being able to hand them out. */
        if (hasPerm('server_ban')) {
            const ib = el('div', 'card actions-card');
            ib.appendChild(el('div', 'actions-title', 'Issue a ban'));
            const lf = el('div', 'action-form');
            const who = el('input');
            who.placeholder = 'server ID, char ID, name, Steam or Discord';
            who.style.width = '18vw';
            who.value = banIssueTerm;
            const look = el('button', 'abtn', 'Find player');
            const run = () => { banIssueTerm = who.value.trim(); post('panelBanLookup', { term: banIssueTerm }); };
            look.addEventListener('click', run);
            who.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') run(); });
            lf.appendChild(who); lf.appendChild(look);
            ib.appendChild(lf);

            const results = el('div');
            ib.appendChild(results);

            (banLookupRows || []).forEach(r => {
                const row = el('div', 'action-form');
                const label = (r.charname || r.playername || 'Unknown')
                    + (r.charid ? '  (char #' + r.charid + ')' : '')
                    + (r.online ? '  [ONLINE id ' + r.online + ']' : '  [offline]');
                row.appendChild(el('span', '', label));

                const reason = el('input');
                reason.placeholder = 'reason - the player is shown this';
                reason.style.width = '14vw';
                const dur = banDurationSelect();

                const b = el('button', 'abtn warn', 'Ban');
                b.addEventListener('click', () => {
                    if (!reason.value.trim()) { reason.focus(); return; }
                    b.disabled = true; b.textContent = 'Banning...';
                    post('panelBanIssue', {
                        online: r.online || null, steam: r.steam || '',
                        charname: r.charname || '', playername: r.playername || '',
                        reason: reason.value.trim(), seconds: Number(dur.value) || 0,
                    });
                    banLookupRows = [];
                });
                row.appendChild(reason); row.appendChild(dur); row.appendChild(b);
                results.appendChild(row);

                if (!r.online) {
                    results.appendChild(el('div', 'offline-note',
                        'Offline: only their Steam ID can be recorded - licence and hardware tokens need them online, so a new account could get back in.'));
                }
            });
            if (banIssueTerm && banLookupRows && banLookupRows.length === 0) {
                ib.appendChild(el('div', 'offline-note', 'Nobody matches that'));
            }
            body.appendChild(ib);
        }

        /* filter bar */
        const bar = el('div', 'card actions-card');
        const f = el('div', 'action-form');

        const q = el('input');
        q.placeholder = 'XXXX-XXXX';
        q.style.width = '18vw';
        q.value = banSearch;

        const sel = (opts, cur, onPick) => {
            const s = el('select', 'panel-select'); // the panel's own select styling
            opts.forEach(([v, label]) => {
                const o = el('option', '', label);
                o.value = v;
                if (v === cur) o.selected = true;
                s.appendChild(o);
            });
            s.addEventListener('change', () => onPick(s.value));
            return s;
        };

        const run = () => { banSearch = q.value.trim(); buildBans(); };
        q.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') run(); });
        const go = el('button', 'abtn', 'Search');
        go.addEventListener('click', run);

        f.appendChild(q);
        f.appendChild(go);
        f.appendChild(sel([['any', 'Search anything'], ['ban_id', 'By Ban ID'], ['player', 'By player'],
            ['reason', 'By reason'], ['ident', 'By identifier']], banField, (v) => { banField = v; renderServerBans(d); }));
        f.appendChild(sel([['any', 'Any type'], ['permanent', 'Permanent'],
            ['temporary', 'Temporary'], ['lifted', 'Lifted']], banType, (v) => {
                banType = v;
                banShowLifted = (v === 'lifted' || v === 'any');
                buildBans();
            }));
        f.appendChild(sel([['any', 'By any admin']].concat((d.admins || []).map(a => [a, a])),
            banAdmin, (v) => { banAdmin = v; renderServerBans(d); }));
        bar.appendChild(f);
        bar.appendChild(el('div', 'offline-note', 'Search reaches Ban ID, name, Discord, Steam, licence, IP and reason.'));
        body.appendChild(bar);

        /* client-side narrowing on top of the server's search */
        let rows = (d.rows || []).filter(b => {
            if (banAdmin !== 'any' && b.staff !== banAdmin) return false;
            if (banType === 'permanent' && (!b.active || Number(b.expires) > 0)) return false;
            if (banType === 'temporary' && (!b.active || Number(b.expires) === 0)) return false;
            if (banType === 'lifted' && b.active) return false;
            if (banType === 'any' && false) return false;
            if (banSearch && banField !== 'any') {
                const needle = banSearch.toLowerCase();
                const hay = {
                    ban_id: b.ban_id,
                    player: (b.playername || '') + ' ' + (b.charname || ''),
                    reason: b.reason || '',
                    ident: [b.license, b.steam, b.discord, b.ip].join(' '),
                }[banField] || '';
                if (!String(hay).toLowerCase().includes(needle)) return false;
            }
            return true;
        });

        if (!rows.length) {
            body.appendChild(el('div', 'empty', banSearch ? 'Nothing matches that' : 'Nobody is banned'));
            return;
        }

        /* the table. .table-head and .prow share one 5-column grid, so the
           headings line up with the cells without a width of their own. */
        const head = el('div', 'table-head');
        ['Ban ID', 'Player', 'Reason', 'Author', 'Date'].forEach(h => head.appendChild(el('div', '', h)));
        body.appendChild(head);

        const list = el('div'); // pagedList makes its own .rows wrapper inside this
        body.appendChild(list);

        pagedList(list, rows, null, b => {
            const row = el('div', 'prow');
            row.style.cursor = 'pointer';

            const idc = el('div', 'pname');
            const nw = el('div');
            nw.appendChild(el('div', 'n', b.ban_id));
            nw.appendChild(el('div', 's', b.active
                ? (Number(b.expires) > 0 ? 'temporary' : 'permanent') : 'lifted'));
            idc.appendChild(nw);
            row.appendChild(idc);

            row.appendChild(el('div', '', b.playername || b.charname || 'Unknown'));
            row.appendChild(el('div', '', (b.reason || 'none given').slice(0, 60)));
            row.appendChild(el('div', '', b.staff || '?'));
            row.appendChild(el('div', '', banWhen(b.created)));

            /* the whole record, opened under the row it belongs to */
            const detail = el('div', 'card actions-card');
            detail.hidden = (banOpen !== b.ban_id);
            const line = (label, text) => {
                if (!text) return;
                const r = el('div', 'offline-note', '');
                r.appendChild(el('strong', '', label + ': '));
                r.appendChild(document.createTextNode(String(text)));
                detail.appendChild(r);
            };
            line('Reason', b.reason || 'none given');
            line('Banned by', b.staff + '   on ' + banWhen(b.created));
            line('Expires', Number(b.expires) > 0
                ? banWhen(Number(b.expires)) : 'never (permanent)');
            if (b.charname) line('Character', b.charname + (b.charid ? ' (#' + b.charid + ')' : ''));
            line('Licence', b.license);
            line('Steam', b.steam);
            line('Discord', b.discord);
            line('IP', b.ip);
            line('Hardware', b.tokenCount > 0
                ? b.tokenCount + ' token(s) recorded' : 'none recorded - cannot catch a new account');
            if (!b.active) line('Lifted by', (b.unbanned_by || 'unknown') + '   on ' + banWhen(b.unbanned_at));

            if (d.canWrite && b.active) {
                const act = el('div', 'action-form');
                const u = el('button', 'abtn', 'Lift this ban');
                u.addEventListener('click', (ev) => {
                    ev.stopPropagation();
                    u.disabled = true; u.textContent = 'Lifting...';
                    post('panelBanUnban', { banId: b.ban_id, search: banSearch, showLifted: banShowLifted });
                });
                act.appendChild(u);
                detail.appendChild(act);
            }

            row.addEventListener('click', () => {
                banOpen = (banOpen === b.ban_id) ? null : b.ban_id;
                detail.hidden = (banOpen !== b.ban_id);
            });

            const wrap = el('div');
            wrap.appendChild(row);
            wrap.appendChild(detail);
            return wrap;
        });
    }

    /* ------------------------------------------------------------- smokes page
       pup-misc/smokes: pipe, cigar and cigarette items from the smokes
       table. Editing here is live - no restart. */
    const SMOKE_TYPES = ['cigar', 'cigarette', 'pipe', 'peace', 'chew'];
    const SMOKE_BOOLS = [
        ['pipe', 'needs a pipe item in the bag to use'],
        ['subitem', 'consumed on use'],
        ['high', 'plays a screen effect / high'],
        ['boost', 'gives the core buffs below'],
        ['turbo', 'cycles through the effects list instead of one effect'],
    ];
    const SMOKE_NUMS = [
        ['highduration', 'how long the high lasts, in SECONDS (300 = 5 min)'],
        ['healthboost', 'gold health core duration: 1 = instant, 2500 = brief, 10000 = long'],
        ['staminaboost', 'gold stamina core duration, same scale'],
        ['drunkamount', 'intensity of the high (200 = strong)'],
        ['drunkscreen', 'screen blur amount (10 = strong)'],
        ['drunkwalk', 'stagger, 0 = steady, 0.8 = very drunk'],
        ['effectinterval', 'turbo only: SECONDS between filter switches'],
    ];
    let smokeFilter = '', smokePage = 0;

    const renderSmokes = (list) => {
        const body = $('#page-smokes-body');
        if (!body) return;
        body.textContent = '';
        if (!Array.isArray(list)) {
            body.appendChild(el('div', 'empty', 'pup-misc is not running'));
            return;
        }

        const head = el('div', 'action-form');
        const add = el('button', 'abtn', 'New smoke');
        add.addEventListener('click', () => renderSmokeEditor({ Name: '', typeof: 'cigar', subitem: true }, true, list));
        head.appendChild(add);
        head.appendChild(el('span', 'offline-note',
            list.length + ' smoke(s) in smokes - the item must also exist in vorp_inventory'));
        body.appendChild(head);

        const PER = 25;
        const sb = el('div', 'searchbar');
        const si = el('input');
        si.placeholder = 'Search smokes by name...';
        si.value = smokeFilter;
        sb.appendChild(si);
        body.appendChild(sb);

        const listHost = el('div');
        body.appendChild(listHost);

        const paint = () => {
            listHost.textContent = '';
            const f = smokeFilter.trim().toLowerCase();
            const items = f === '' ? list : list.filter(it => String(it.Name).toLowerCase().includes(f));
            const pages = Math.max(1, Math.ceil(items.length / PER));
            if (smokePage >= pages) smokePage = pages - 1;
            if (smokePage < 0) smokePage = 0;

            const rows = el('div', 'rows');
            rows.style.marginTop = '.5vw';
            items.slice(smokePage * PER, smokePage * PER + PER).forEach(it => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = '2.2fr 1.2fr 1.6fr .8fr';
                row.style.cursor = 'pointer';
                row.addEventListener('click', () => renderSmokeEditor(it, false, list));

                const namec = el('div', 'pname');
                namec.appendChild(itemImg(it.Name, '1.9vw'));
                const nw = el('div');
                nw.appendChild(el('div', 'n', it.Name));
                nw.appendChild(el('div', 's', it.typeof + (it.pipe ? ' • needs a pipe' : '')));
                namec.appendChild(nw);
                row.appendChild(namec);

                row.appendChild(el('div', 'pxp', it.high
                    ? ('high ' + (it.highduration || 0) + 's' + (it.hightype ? ' • ' + it.hightype : ''))
                    : 'no high'));

                const eff = [];
                if (it.healthboost) eff.push('hp ' + it.healthboost);
                if (it.staminaboost) eff.push('stam ' + it.staminaboost);
                if (it.drunkamount) eff.push('drunk ' + it.drunkamount);
                row.appendChild(el('div', 'pxp', eff.length ? eff.join(' • ') : '-'));

                const st = el('div', 'right');
                if (it.turbo) st.appendChild(el('span', 'chip', 'turbo'));
                if ((it.effects || []).length) st.appendChild(el('span', 'chip', it.effects.length + ' fx'));
                row.appendChild(st);
                rows.appendChild(row);
            });
            listHost.appendChild(rows);
            if (!items.length) {
                listHost.appendChild(el('div', 'empty', 'No smokes match "' + smokeFilter + '"'));
            }

            if (pages > 1) {
                listHost.appendChild(pagerBar(items.length, smokePage, PER,
                    p => { smokePage = p; paint(); }));
            }
        };
        si.addEventListener('input', () => { smokeFilter = si.value; smokePage = 0; paint(); });
        paint();
    };

    const renderSmokeEditor = (it, isNew, list) => {
        const body = $('#page-smokes-body');
        body.textContent = '';
        const inputs = {};

        const back = el('button', 'abtn', '< Back');
        back.addEventListener('click', () => renderSmokes(list));
        body.appendChild(back);
        const headWrap = el('div', 'pname');
        headWrap.style.marginBottom = '.6vw';
        if (!isNew) headWrap.appendChild(itemImg(it.Name, '2.4vw'));
        headWrap.appendChild(el('div', 'actions-title', isNew ? 'New smoke' : ('Edit "' + it.Name + '"')));
        body.appendChild(headWrap);

        const row = (label, hint, node) => {
            const f = el('div', 'action-form');
            const lbl = el('span', 'offline-note', label);
            lbl.style.width = '9vw';
            f.appendChild(lbl); f.appendChild(node);
            if (hint) f.appendChild(el('span', 'offline-note', hint));
            body.appendChild(f);
            return f;
        };

        const nameIn = el('input');
        nameIn.style.width = '12vw';
        nameIn.value = it.Name || '';
        if (!isNew) { nameIn.disabled = true; nameIn.style.opacity = '.55'; }
        inputs.Name = nameIn;
        row('Name', 'item db name (a-z, 0-9, _)', nameIn);

        const typeSel = document.createElement('select');
        typeSel.className = 'panel-select';
        SMOKE_TYPES.forEach(v => {
            const o = document.createElement('option');
            o.value = v; o.textContent = v;
            typeSel.appendChild(o);
        });
        typeSel.value = it.typeof || 'cigar';
        inputs.typeof = typeSel;
        row('typeof', 'which animation and prop the client plays', typeSel);

        const fxSel = document.createElement('select');
        fxSel.className = 'panel-select';
        const cur = it.hightype || '';
        const known = CONSUMABLE_EFFECTS.slice();
        if (cur && known.indexOf(cur) === -1) known.push(cur);
        known.forEach(v => {
            const o = document.createElement('option');
            o.value = v; o.textContent = v === '' ? '(none)' : v;
            fxSel.appendChild(o);
        });
        fxSel.value = cur;
        inputs.hightype = fxSel;
        const fxRow = row('hightype', 'screen effect while high', fxSel);
        const fxPlay = el('button', 'abtn', 'Play');
        const fxStop = el('button', 'abtn', 'Stop');
        fxStop.style.display = 'none';
        fxPlay.addEventListener('click', () => {
            if (fxSel.value) post('panelFxPreview', { effect: fxSel.value, seconds: 5 });
        });
        fxStop.addEventListener('click', () => post('panelFxStop', {}));
        fxPreviewButtons = { play: fxPlay, stop: fxStop };
        fxRow.insertBefore(fxStop, fxRow.lastChild);
        fxRow.insertBefore(fxPlay, fxStop);

        SMOKE_BOOLS.forEach(([k, hint]) => {
            const cb = el('input');
            cb.type = 'checkbox';
            cb.checked = !!it[k];
            inputs[k] = cb;
            row(k, hint, cb);
        });

        SMOKE_NUMS.forEach(([k, hint]) => {
            const inp = el('input');
            inp.style.width = '12vw';
            inp.value = it[k] === undefined || it[k] === null ? 0 : it[k];
            inputs[k] = inp;
            row(k, hint, inp);
        });

        const fxList = document.createElement('textarea');
        fxList.style.cssText = 'width:26vw;height:6vw;';
        fxList.value = (it.effects || []).join('\n');
        inputs.effects = fxList;
        row('effects', 'turbo only: one animpostfx name per line', fxList);

        const actions = el('div', 'action-form');
        const save = el('button', 'abtn', isNew ? 'Create' : 'Save');
        save.addEventListener('click', () => {
            const payload = { Name: (inputs.Name.value || '').trim() };
            if (!payload.Name) return;
            payload.typeof = inputs.typeof.value;
            payload.hightype = inputs.hightype.value;
            SMOKE_BOOLS.forEach(([k]) => { payload[k] = inputs[k].checked; });
            SMOKE_NUMS.forEach(([k]) => { payload[k] = Number(inputs[k].value) || 0; });
            payload.effects = fxList.value.split('\n').map(s => s.trim()).filter(Boolean);
            post('panelSmokeSave', payload);
        });
        actions.appendChild(save);

        if (!isNew && hasPerm('delete_consumable')) {
            const confirm = el('input');
            confirm.placeholder = 'type DELETE to confirm';
            confirm.style.width = '10vw';
            const del = el('button', 'abtn warn', 'Delete');
            del.addEventListener('click', () => {
                if (confirm.value.trim() === 'DELETE') post('panelSmokeDelete', { name: it.Name });
            });
            actions.appendChild(confirm);
            actions.appendChild(del);
        }
        body.appendChild(actions);
    };

    /* ------------------------------------------------------------- consumables page
       fred_metabolism items: list -> editor. Thumbnails come straight from
       vorp_inventory's NUI assets (nui://vorp_inventory/html/img/items/<name>.png). */
    // EffectDuration is stored in ms but edited in SECONDS, so every duration on
    // this page reads in the same unit as the gold cores - and the same unit
    // pup-smokes uses for its highduration. Converted on load and on save.
    const SEC_FIELDS = { EffectDuration: 1000 }; // field -> ms per unit shown
    const toUnits = (k, v) => (SEC_FIELDS[k] ? Math.round(((Number(v) || 0) / SEC_FIELDS[k]) * 100) / 100 : v);
    const toStored = (k, v) => (SEC_FIELDS[k] ? Math.round((Number(v) || 0) * SEC_FIELDS[k]) : v);

    // The gold fields are a BUFF DURATION passed to EnableAttributeOverpower,
    // not a 0-100 amount.
    //
    // Confirmed in game: 1 expires the moment it is applied, 10000 holds long
    // enough to take noticeably more body shots. The extra survivability comes
    // from the gold core LASTING, not from stronger resistance - the gold core
    // is a state the game either has or does not.
    const GOLD_HINT = 'buff duration: 1 = instant, 2500 = brief, 10000 = holds through a fight';
    const CONSUMABLE_NUM_FIELDS = [
        ['Hunger', 'food given (0-100)'], ['Thirst', 'water given (0-100)'],
        ['Metabolism', 'body weight change (e.g. 200)'],
        ['EffectDuration', 'screen effect length in SECONDS (120 = 2 min)'],
        ['InnerCoreStamina', 'inner stamina core restore (0-100)'], ['InnerCoreStaminaGold', GOLD_HINT],
        ['OuterCoreStaminaGold', GOLD_HINT], ['InnerCoreHealth', 'inner health core restore (0-100)'],
        ['InnerCoreHealthGold', GOLD_HINT], ['OuterCoreHealthGold', GOLD_HINT + ' - this is the tanky one'],
        ['InnerCoreDeadeye', 'dead eye core restore (0-100)'], ['InnerCoreDeadeyeGold', GOLD_HINT],
        ['OuterCoreDeadeyeGold', GOLD_HINT],
    ];

    // Props the smoke animation can hold. Every one is a model pup-smokes
    // actually creates, so they are known to exist and to sit in the hand with
    // the shared amb_rest@world_human_smoke_cigar dict.
    const SMOKE_PROPS = [
        'P_CIGAR01X', 'P_CIGARETTE01X', 'P_PIPE01X', 'p_peacepipe01x', 'S_TOBACCOTIN01X',
    ];

    // animpostfx names. Everything already in use on this server, plus the
    // handful the resource documents. Free text is still allowed via (custom).
    const CONSUMABLE_EFFECTS = [
        '', 'DEADEYE', 'PlayerDrunk01', 'PlayerDrunk01_PassOut', 'PlayerDrunkAberdeen',
        'PlayerRPGcore', 'PlayerDrugsPoisonWell', 'playerdrugshalluc01',
        'PlayerHealthPoor', 'PlayerHealthPoorCS', 'MP_Downed', 'MP_SuddenDeath',
        'MP_ArrowDrain', 'OJDominoBlur', 'KingCastleRed', 'KingCastleBlue',
        'MP_DeathInk_Color01', 'MP_Deathink_color02', 'MP_DeathInk_Color04',
        'MP_Deathink_color05', 'MP_Deathink_color06', 'MP_DeathInk_Color09', 'MP_DeathInk_Color10',
        'PhotoMode_FilterModern01', 'PhotoMode_FilterModern02', 'Photomode_filtermodern03',
        'PhotoMode_FilterModern04', 'Photomode_FilterModern05', 'PhotoMode_FilterModern10',
        'PhotoMode_FilterGame02', 'PhotoMode_FilterGame03', 'PhotoMode_FilterGame04',
        'PhotoMode_FilterGame06', 'PHOTOMODE_FILTERGAME10', 'PhotoMode_FilterGame16',
        'PhotoMode_FilterVintage02',
    ];
    let consumableImages = {}; // [name] = true/false, from the server audit

    // the Play/Stop pair on the Effect row, swapped while a preview is running
    let fxPreviewButtons = null;
    const setFxPreviewing = (on) => {
        if (!fxPreviewButtons) return;
        fxPreviewButtons.play.style.display = on ? 'none' : '';
        fxPreviewButtons.stop.style.display = on ? '' : 'none';
    };

    // live readout for the gold-core buff timer, so its unit can be measured
    // rather than guessed
    let buffTestNote = null;
    const renderBuffTest = (d) => {
        if (!buffTestNote || !d) return;
        if (d.error) { buffTestNote.textContent = 'test failed: ' + d.error; return; }
        if (d.never) {
            buffTestNote.textContent = 'value ' + d.value + ' never turned the core gold - try a larger number';
            return;
        }
        if (!d.done) { buffTestNote.textContent = 'gold for ' + d.seconds + 's...'; return; }
        buffTestNote.textContent = d.capped
            ? 'still gold after 180s - value ' + d.value + ' lasts longer than the test'
            : 'value ' + d.value + ' = ' + d.seconds + 's of gold core';
    };

    // which attribute index each gold field drives, and whether it is the outer
    // ring (EnableAttributeOverpower) or the inner (…CoreOverpower)
    const GOLD_FIELDS = {
        InnerCoreHealthGold:  { attribute: 0, outer: false },
        OuterCoreHealthGold:  { attribute: 0, outer: true },
        InnerCoreStaminaGold: { attribute: 1, outer: false },
        OuterCoreStaminaGold: { attribute: 1, outer: true },
        InnerCoreDeadeyeGold: { attribute: 2, outer: false },
        OuterCoreDeadeyeGold: { attribute: 2, outer: true },
    };

    const CONSUMABLE_TEXT_FIELDS = [
        ['DisplayName', 'name shown on use'],
        ['Animation', '"" / eat / drink / drink_cup / bowl / shortbottle / longbottle / syringe / berry / smoke / sponge'],
        ['PropName', 'prop model - blank uses the animation default'],
        ['Effect', 'animpostfx name or ""'],
    ];

    const itemImg = (name, size) => {
        const im = document.createElement('img');
        im.src = 'nui://vorp_inventory/html/img/items/' + name + '.png';
        im.style.cssText = 'width:' + size + ';height:' + size + ';object-fit:contain;flex:none;';
        im.onerror = () => { im.style.visibility = 'hidden'; };
        return im;
    };

    // pup: shared prev/next pager bar (Consumables client-side, Items DB server-side)
    const pagerBar = (total, page, per, go) => {
        const pages = Math.max(1, Math.ceil(total / per));
        const bar = el('div', 'action-form');
        const prev = el('button', 'abtn', '← Prev');
        prev.disabled = page <= 0;
        prev.addEventListener('click', () => go(page - 1));
        const label = el('span', 'offline-note', 'Page ' + (page + 1) + ' / ' + pages);
        const next = el('button', 'abtn', 'Next →');
        next.disabled = page + 1 >= pages;
        next.addEventListener('click', () => go(page + 1));
        bar.appendChild(prev); bar.appendChild(label); bar.appendChild(next);
        return bar;
    };
    // pup: generic client-side search + pages for the big panel lists.
    // Repaints only the list (never the search box), so typing keeps focus.
    // toText(item) feeds the filter; pass null + noSearch for pager-only.
    /* opts.categoryOf (it => string) turns on a row of category tabs above the
       search box. Categories are derived from the list itself rather than passed
       in, so a page can never show a tab that filters to nothing, and a recipe in
       a brand new category appears without touching this code. The tab narrows
       the list first, then the text search runs inside it - so you can pick
       "medical" and then search within only medical recipes. */
    const pagedList = (host, list, toText, renderRow, opts) => {
        opts = opts || {};
        const PER = opts.per || 25;
        const catOf = opts.categoryOf || null;
        let filter = '';
        let page = 0;
        let cat = '';   // '' = all categories
        const lh = el('div');

        function visible() {
            const f = filter.trim().toLowerCase();
            let items = list;
            if (catOf && cat !== '') items = items.filter(it => String(catOf(it) || '') === cat);
            if (f !== '') items = items.filter(it => toText(it).toLowerCase().includes(f));
            return items;
        }

        function paint() {
            lh.textContent = '';
            const f = filter.trim().toLowerCase();
            const items = visible();
            const pages = Math.max(1, Math.ceil(items.length / PER));
            if (page >= pages) page = pages - 1;
            if (page < 0) page = 0;
            const rows = el('div', 'rows');
            rows.style.marginTop = '.5vw';
            items.slice(page * PER, page * PER + PER).forEach(it => rows.appendChild(renderRow(it)));
            lh.appendChild(rows);
            if (!items.length) {
                let why = 'Nothing here';
                if (f !== '' && cat !== '') why = 'Nothing matches "' + filter + '" in ' + cat;
                else if (f !== '') why = 'Nothing matches "' + filter + '"';
                else if (cat !== '') why = 'Nothing in ' + cat;
                lh.appendChild(el('div', 'empty', why));
            } else if (items.length > PER) {
                lh.appendChild(pagerBar(items.length, page, PER, p => { page = p; paint(); }));
            }
        }

        if (catOf) {
            const counts = new Map();
            list.forEach(it => {
                const c = String(catOf(it) || '').trim();
                if (c !== '') counts.set(c, (counts.get(c) || 0) + 1);
            });
            const names = Array.from(counts.keys()).sort();
            // one category is not a filter, it is just noise
            if (names.length > 1) {
                const bar = el('div', 'cat-tabs');
                const mk = (value, text, n) => {
                    const b = el('button', 'cat-tab', text);
                    b.appendChild(el('span', 'n', String(n)));
                    if (value === cat) b.classList.add('on');
                    b.addEventListener('click', () => {
                        cat = value;
                        page = 0;
                        Array.prototype.forEach.call(bar.children, x => x.classList.remove('on'));
                        b.classList.add('on');
                        paint();
                    });
                    return b;
                };
                bar.appendChild(mk('', 'All', list.length));
                names.forEach(c => bar.appendChild(mk(c, c, counts.get(c))));
                host.appendChild(bar);
            }
        }

        if (!opts.noSearch && list.length > 8) {
            const sb = el('div', 'searchbar');
            const si = el('input');
            si.placeholder = opts.placeholder || 'Search...';
            si.addEventListener('input', () => { filter = si.value; page = 0; paint(); });
            sb.appendChild(si);
            host.appendChild(sb);
        }
        host.appendChild(lh);
        paint();
    };

    let consumFilter = '';
    let consumPage = 0;

    const renderConsumables = (data) => {
        const body = $('#consumablesBody');
        body.textContent = '';
        if (!data || data.missing) {
            body.appendChild(el('div', 'empty', 'fred_metabolism is not running'));
            return;
        }
        if (!Array.isArray(data.items)) {
            body.appendChild(el('div', 'empty', 'No data (are you allowed?)'));
            return;
        }
        const managed = data.managed || {};
        const images = data.images || {};
        consumableImages = images;

        const head = el('div', 'action-form');
        const nb = el('button', 'abtn', '+ New Consumable');
        nb.addEventListener('click', () => renderConsumableEditor(null, false));
        head.appendChild(nb);
        head.appendChild(el('span', 'offline-note',
            data.items.length + ' consumables - [panel] = editable here, [config] = from config.lua'));
        body.appendChild(head);

        const noImg = data.items.filter(it => images[it.Name] === false);
        if (noImg.length) {
            const warn = el('div', 'card actions-card');
            warn.appendChild(el('div', 'actions-title',
                noImg.length + ' consumable(s) have NO inventory image - they show as a blank slot in bags'));
            warn.appendChild(el('div', 'offline-note',
                'add: vorp_inventory/html/img/items/<name>.png  →  ' + noImg.map(it => it.Name + '.png').join(', ')));
            body.appendChild(warn);
        }

        // pup: SEARCH + PAGES. Everything is already in the
        // payload, so both are client-side; only the list repaints on input,
        // so the search box never loses focus.
        const PER = 25;
        const sb = el('div', 'searchbar');
        const si = el('input');
        si.placeholder = 'Search consumables by item name or label...';
        si.value = consumFilter;
        sb.appendChild(si);
        body.appendChild(sb);

        const listHost = el('div');
        body.appendChild(listHost);

        const paint = () => {
            listHost.textContent = '';
            const f = consumFilter.trim().toLowerCase();
            const items = f === '' ? data.items : data.items.filter(it =>
                String(it.Name).toLowerCase().includes(f) ||
                String(it.DisplayName || '').toLowerCase().includes(f));
            const pages = Math.max(1, Math.ceil(items.length / PER));
            if (consumPage >= pages) consumPage = pages - 1;
            if (consumPage < 0) consumPage = 0;

            const rows = el('div', 'rows');
            rows.style.marginTop = '.5vw';
            items.slice(consumPage * PER, consumPage * PER + PER).forEach(it => {
                const isManaged = !!managed[it.Name];
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = '2.2fr 1.2fr 1.6fr .8fr';
                row.style.cursor = 'pointer';
                row.addEventListener('click', () => renderConsumableEditor(it, isManaged));

                const namec = el('div', 'pname');
                namec.appendChild(itemImg(it.Name, '1.9vw'));
                const nw = el('div');
                nw.appendChild(el('div', 'n', it.DisplayName || it.Name));
                nw.appendChild(el('div', 's', it.Name));
                namec.appendChild(nw);
                row.appendChild(namec);

                row.appendChild(el('div', 'pxp', '+' + (it.Hunger || 0) + ' food  +' + (it.Thirst || 0) + ' water'));
                row.appendChild(el('div', 'pxp',
                    'metab ' + (it.Metabolism || 0) + (it.Animation ? (' • ' + it.Animation) : '')));
                const st = el('div', 'right');
                if (images[it.Name] === false) {
                    const w = el('span', 'chip', 'no image');
                    w.style.color = 'var(--red)';
                    w.style.borderColor = 'rgba(217,138,127,.35)';
                    st.appendChild(w);
                }
                st.appendChild(el('span', 'chip', isManaged ? 'panel' : 'config'));
                row.appendChild(st);
                rows.appendChild(row);
            });
            listHost.appendChild(rows);
            if (!items.length) {
                listHost.appendChild(el('div', 'empty', 'No consumables match "' + consumFilter + '"'));
            } else if (items.length > PER) {
                listHost.appendChild(pagerBar(items.length, consumPage, PER, p => { consumPage = p; paint(); }));
            }
        };
        si.addEventListener('input', () => { consumFilter = si.value; consumPage = 0; paint(); });
        paint();
    };

    const renderConsumableEditor = (it, isManaged) => {
        const body = $('#consumablesBody');
        body.textContent = '';
        const isNew = !it;
        it = it || {};

        const back = el('button', 'back-btn', '← Back to consumables');
        back.addEventListener('click', () => post('panelConsumables'));
        body.appendChild(back);

        const c = el('div', 'card actions-card');
        const headWrap = el('div', 'pname');
        headWrap.style.marginBottom = '.6vw';
        if (!isNew) headWrap.appendChild(itemImg(it.Name, '2.4vw'));
        headWrap.appendChild(el('div', 'actions-title',
            isNew ? 'New consumable - saves live, auto-creates the usable item row'
                  : ('Edit "' + it.Name + '"' + (isManaged ? '' : ' - from config.lua; saving makes a panel-managed copy that OVERRIDES it'))));
        c.appendChild(headWrap);

        // image status, always visible while editing
        if (!isNew) {
            const has = consumableImages[it.Name];
            const imgLine = el('div', 'offline-note', has === false
                ? ('NO INVENTORY IMAGE - add vorp_inventory/html/img/items/' + it.Name + '.png (players see a blank slot without it)')
                : ('image OK: vorp_inventory/html/img/items/' + it.Name + '.png'));
            if (has === false) imgLine.style.color = 'var(--red)';
            c.appendChild(imgLine);
        }

        const inputs = {};
        const fieldRow = (key, hint, value, locked) => {
            const f = el('div', 'action-form');
            const lbl = el('span', 'offline-note', key);
            lbl.style.width = '9vw';
            const input = el('input');
            input.style.width = '12vw';
            input.value = (value === undefined || value === null) ? '' : String(value);
            if (locked) { input.disabled = true; input.style.opacity = '.55'; }
            inputs[key] = input;
            f.appendChild(lbl); f.appendChild(input);
            f.appendChild(el('span', 'offline-note', hint));
            c.appendChild(f);
        };

        fieldRow('Name', 'item db name (a-z, 0-9, _) - also the image filename', it.Name, !isNew);
        CONSUMABLE_TEXT_FIELDS.forEach(([k, hint]) => {
            if (k === 'Animation') {
                // dropdown, not free text - the valid keys are a fixed set
                const f = el('div', 'action-form');
                const lbl = el('span', 'offline-note', k);
                lbl.style.width = '9vw';
                const sel = document.createElement('select');
                sel.className = 'panel-select';
                ['', 'eat', 'drink', 'drink_cup', 'bowl', 'shortbottle', 'longbottle', 'syringe', 'berry', 'smoke', 'sponge'].forEach(v => {
                    const o = document.createElement('option');
                    o.value = v;
                    o.textContent = v === '' ? '(none)' : v;
                    sel.appendChild(o);
                });
                sel.value = it[k] || '';
                inputs[k] = sel;
                f.appendChild(lbl); f.appendChild(sel);
                f.appendChild(el('span', 'offline-note', 'eat/drink/shortbottle/longbottle need a PropName; smoke and sponge do not'));
                c.appendChild(f);
                return;
            }
            if (k === 'PropName') {
                // a real select, not a datalist - CEF does not render datalist
                // dropdowns, so its suggestions would be invisible. Eat/drink props
                // are open ended, so (type a name...) keeps free text available.
                const f = el('div', 'action-form');
                const lbl = el('span', 'offline-note', k);
                lbl.style.width = '9vw';
                const sel = document.createElement('select');
                sel.className = 'panel-select';
                const current = it[k] || '';
                const known = SMOKE_PROPS.slice();
                if (current && known.indexOf(current) === -1) known.unshift(current);
                [''].concat(known).forEach(v => {
                    const o = document.createElement('option');
                    o.value = v;
                    o.textContent = v === '' ? '(none - use animation default)' : v;
                    sel.appendChild(o);
                });
                const customOpt = document.createElement('option');
                customOpt.value = '__custom__';
                customOpt.textContent = '(type a name...)';
                sel.appendChild(customOpt);

                const free = el('input');
                free.style.cssText = 'width:12vw;display:none;';
                free.placeholder = 'prop model';
                sel.value = current;
                sel.addEventListener('change', () => {
                    const isCustom = sel.value === '__custom__';
                    free.style.display = isCustom ? '' : 'none';
                    if (isCustom) free.focus();
                });

                inputs[k] = { get value() { return sel.value === '__custom__' ? free.value.trim() : sel.value; } };
                f.appendChild(lbl); f.appendChild(sel); f.appendChild(free);
                f.appendChild(el('span', 'offline-note', 'blank = animation default (smoke uses P_CIGAR01X)'));
                c.appendChild(f);
                return;
            }
            if (k === 'Effect') {
                // dropdown of known animpostfx names, with an escape hatch for
                // anything not on the list
                const f = el('div', 'action-form');
                const lbl = el('span', 'offline-note', k);
                lbl.style.width = '9vw';
                const sel = document.createElement('select');
                sel.className = 'panel-select';
                const current = it[k] || '';
                const known = CONSUMABLE_EFFECTS.slice();
                if (current && known.indexOf(current) === -1) known.push(current);
                known.forEach(v => {
                    const o = document.createElement('option');
                    o.value = v;
                    o.textContent = v === '' ? '(none)' : v;
                    sel.appendChild(o);
                });
                const custom = document.createElement('option');
                custom.value = '__custom__';
                custom.textContent = '(type a name...)';
                sel.appendChild(custom);

                const free = el('input');
                free.style.cssText = 'width:12vw;display:none;';
                free.placeholder = 'animpostfx name';
                sel.value = current;
                sel.addEventListener('change', () => {
                    const isCustom = sel.value === '__custom__';
                    free.style.display = isCustom ? '' : 'none';
                    if (isCustom) free.focus();
                });

                // read whichever control is in play at save time
                const read = () => (sel.value === '__custom__' ? free.value.trim() : sel.value);
                inputs[k] = { get value() { return read(); } };

                // try it before saving it: the panel hides, the effect plays,
                // the panel comes back. Stop ends it early.
                const play = el('button', 'abtn', 'Play');
                const stop = el('button', 'abtn', 'Stop');
                stop.style.display = 'none';
                play.addEventListener('click', () => {
                    const name = read();
                    if (!name) return;
                    post('panelFxPreview', { effect: name, seconds: 5 });
                });
                stop.addEventListener('click', () => post('panelFxStop', {}));
                fxPreviewButtons = { play: play, stop: stop };

                f.appendChild(lbl); f.appendChild(sel); f.appendChild(free);
                f.appendChild(play); f.appendChild(stop);
                f.appendChild(el('span', 'offline-note', 'screen effect on use - Play tries it for 5s'));
                c.appendChild(f);
                return;
            }
            fieldRow(k, hint, it[k]);
        });
        CONSUMABLE_NUM_FIELDS.forEach(([k, hint]) =>
            fieldRow(k, hint, toUnits(k, it[k] !== undefined ? it[k] : 0)));

        // One buff timer for the whole form rather than a button per gold field:
        // it answers the same question (how long does this value actually last)
        // without six buttons down the page.
        const bt = el('div', 'action-form');
        const btLbl = el('span', 'offline-note', 'buff timer');
        btLbl.style.width = '9vw';
        const btSel = document.createElement('select');
        btSel.className = 'panel-select';
        Object.keys(GOLD_FIELDS).forEach(name => {
            const o = document.createElement('option');
            o.value = name;
            o.textContent = name;
            btSel.appendChild(o);
        });
        btSel.value = 'OuterCoreHealthGold';
        const btRun = el('button', 'abtn', 'Test');
        buffTestNote = el('span', 'offline-note buff-note', 'applies the value above and times how long the core stays gold');
        btRun.addEventListener('click', () => {
            const k = btSel.value;
            const v = Number(inputs[k] && inputs[k].value) || 0;
            if (v <= 0) { buffTestNote.textContent = k + ' is 0 - set a value first'; return; }
            buffTestNote.textContent = 'applying ' + v + '...';
            post('panelBuffTest', { attribute: GOLD_FIELDS[k].attribute, outer: GOLD_FIELDS[k].outer, value: v });
        });
        bt.appendChild(btLbl); bt.appendChild(btSel); bt.appendChild(btRun); bt.appendChild(buffTestNote);
        c.appendChild(bt);

        const actions = el('div', 'action-form');
        const save = el('button', 'abtn', isNew ? 'Create' : 'Save');
        save.addEventListener('click', () => {
            const payload = {};
            payload.Name = (inputs.Name.value || '').trim();
            if (!payload.Name) return;
            CONSUMABLE_TEXT_FIELDS.forEach(([k]) => { payload[k] = inputs[k].value; });
            // minutes back to the ms the consume handler expects
            CONSUMABLE_NUM_FIELDS.forEach(([k]) => { payload[k] = toStored(k, Number(inputs[k].value) || 0); });
            post('panelConsumableSave', payload);
        });
        actions.appendChild(save);

        if (isManaged && hasPerm('delete_consumable')) {
            const confirm = el('input');
            confirm.placeholder = 'type DELETE to confirm';
            const del = el('button', 'abtn warn', 'Delete');
            del.addEventListener('click', () => {
                if (confirm.value.trim() === 'DELETE') post('panelConsumableDelete', { name: it.Name });
            });
            actions.appendChild(confirm); actions.appendChild(del);
        }
        actions.appendChild(el('span', 'offline-note',
            'image: vorp_inventory/html/img/items/<name>.png - new item rows need a vorp_inventory restart'));
        c.appendChild(actions);
        body.appendChild(c);
    };

    /* ------------------------------------------------------------- crafting page
       pup-crafting recipes: list -> editor. Recipes are DISABLED not deleted so
       player favourites (stored as recipe positions) never shift. */
    let craftCats = [];
    let craftCanWrite = false;
    let craftLocNames = []; // valid station names, for the Stations field hint

    const renderCraftRecipes = (data) => {
        const body = $('#craftingBody');
        body.textContent = '';
        if (!data || data.missing) {
            body.appendChild(el('div', 'empty', 'pup_workbench is not running'));
            return;
        }
        if (!Array.isArray(data.recipes)) {
            body.appendChild(el('div', 'empty', 'No data (are you allowed?)'));
            return;
        }
        craftCats = data.categories || [];
        craftCanWrite = !!data.canWrite;
        craftLocNames = data.locationNames || [];

        const head = el('div', 'action-form');
        if (craftCanWrite) {
            const nb = el('button', 'abtn', '+ New Recipe');
            nb.addEventListener('click', () => renderCraftEditor(null));
            head.appendChild(nb);
        }
        const lb = el('button', 'abtn', 'Manage Locations');
        lb.addEventListener('click', () => post('panelCraftLocations'));
        head.appendChild(lb);
        const enabledCount = data.recipes.filter(r => r.enabled).length;
        head.appendChild(el('span', 'offline-note',
            data.recipes.length + ' recipes (' + enabledCount + ' enabled)' +
            (craftCanWrite ? '' : ' - read only (needs manage_crafting to edit)')));
        body.appendChild(head);

        const listHost = el('div');
        body.appendChild(listHost);

        pagedList(listHost, data.recipes,
            it => (it.name + ' ' + it.category + ' #' + it.id),
            it => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = '2.4fr 1.2fr 1.4fr .8fr';
                row.style.cursor = 'pointer';
                row.style.opacity = it.enabled ? '1' : '.5';
                const nm = el('div', 'pname');
                if (it.rewards && it.rewards[0]) nm.appendChild(itemImg(it.rewards[0].name, '1.8vw'));
                nm.appendChild(el('span', null, '#' + it.id + '  ' + it.name));
                row.appendChild(nm);
                row.appendChild(el('div', null, it.category));
                row.appendChild(el('div', 'offline-note',
                    (it.materials || []).map(m => m.count + '× ' + (m.label || m.name)).join(', ')
                    + ((it.tools && it.tools.length)
                        ? '   ·   needs ' + it.tools.map(t => t.label || t.name).join(', ')
                        : '')));
                const st = el('div');
                st.appendChild(el('span', 'chip', it.enabled ? 'on' : 'off'));
                if (it.tools && it.tools.length) st.appendChild(el('span', 'chip', 'tool'));
                if (it.job) {
                    // a recipe locked to many jobs (e.g. every town blacksmith)
                    // would overflow as one huge chip - show a count, full list
                    // on hover. One job shows its name.
                    const jobs = it.job.split(',').map(j => j.trim()).filter(Boolean);
                    const jc = el('span', 'chip', jobs.length > 1 ? (jobs.length + ' jobs') : jobs[0]);
                    jc.title = jobs.join(', ');
                    st.appendChild(jc);
                }
                row.appendChild(st);
                row.addEventListener('click', () => renderCraftEditor(it));
                return row;
            },
            {
                per: 25,
                placeholder: 'Search recipes by name, category or #id...',
                categoryOf: it => it.category
            });
    };

    /* --- item-name autocomplete --------------------------------------------
       Shared by the crafting and weapon-crafting editors. Typing 2+ chars in
       an item-name field searches the items DB; picking a result fills the db
       name and, when empty, the label beside it. Results arrive through the
       'itemSearch' push; seq drops stale replies from fast typing. */
    let acSeq = 0, acInput = null, acLabelI = null, acBox = null, acTimer = null;
    const acClose = () => { if (acBox) acBox.remove(); acBox = null; acInput = null; acLabelI = null; };
    const attachItemSearch = (nameI, labelI) => {
        nameI.setAttribute('autocomplete', 'off');
        nameI.addEventListener('input', () => {
            clearTimeout(acTimer);
            const q = nameI.value.trim();
            if (q.length < 2) { if (acInput === nameI) acClose(); return; }
            acTimer = setTimeout(() => {
                acSeq++; acInput = nameI; acLabelI = labelI || null;
                post('panelItemSearch', { q: q, seq: acSeq });
            }, 200);
        });
        /* result rows use mousedown, which fires before this blur closes the box */
        nameI.addEventListener('blur', () => setTimeout(() => { if (acInput === nameI) acClose(); }, 200));
    };
    const showItemSearch = (data) => {
        if (!acInput || !data || Number(data.seq) !== acSeq) return;
        if (acBox) acBox.remove();
        acBox = el('div', 'item-ac');
        const rect = acInput.getBoundingClientRect();
        acBox.style.left = rect.left + 'px';
        acBox.style.top = (rect.bottom + 2) + 'px';
        acBox.style.minWidth = rect.width + 'px';
        const rows = data.rows || [];
        if (!rows.length) acBox.appendChild(el('div', 'item-ac-empty', 'no matching items'));
        rows.forEach(r => {
            const rw = el('div', 'item-ac-row');
            rw.appendChild(itemImg(r.item, '1.6vw'));
            rw.appendChild(el('span', 'item-ac-name', r.item));
            rw.appendChild(el('span', 'item-ac-label', r.label || ''));
            rw.addEventListener('mousedown', (ev) => {
                ev.preventDefault();
                acInput.value = r.item;
                if (acLabelI && !acLabelI.value.trim()) acLabelI.value = r.label || '';
                acClose();
            });
            acBox.appendChild(rw);
        });
        document.body.appendChild(acBox);
    };

    /* DEATHS: what each respawn took, and the button that hands it back */
    function renderDeaths(d) {
        const body = $('#deathsBody');
        body.textContent = '';
        if (!d) { body.appendChild(el('div', 'empty', 'Could not read the death log')); return; }
        if (d.missing) { body.appendChild(el('div', 'empty', 'pup-medical is not running')); return; }

        const rows = d.rows || [];
        if (!rows.length) { body.appendChild(el('div', 'empty', 'Nothing has been lost to a respawn yet')); return; }

        rows.forEach(r => {
            const c = el('div', 'card actions-card');
            c.appendChild(el('div', 'actions-title',
                '#' + r.id + '  ' + (r.charname || 'Unknown') + '  (char #' + r.charidentifier + ')'));

            const meta = [];
            if (r.steamname) meta.push(r.steamname);
            if (r.created) meta.push(String(r.created));
            if (r.restored) meta.push('RESTORED by ' + (r.restoredby || 'staff'));
            c.appendChild(el('div', 'offline-note', meta.join('   ·   ')));

            const money = [];
            if (Number(r.cash) > 0) money.push('$' + Number(r.cash).toFixed(2));
            if (Number(r.gold) > 0) money.push(Number(r.gold).toFixed(2) + ' gold');

            const w = r.weapons || [], it = r.items || [];
            const line = (label, text) => {
                if (!text) return;
                const row = el('div', 'offline-note', '');
                row.appendChild(el('strong', '', label + ': '));
                row.appendChild(document.createTextNode(text));
                c.appendChild(row);
            };
            // a weapon row is the whole loadout record; older ones are just a name
            const wName = x => {
                if (typeof x === 'string') return x;
                const base = x.customLabel || x.label || x.name || '?';
                const comps = x.comps && x.comps !== '[]' && x.comps !== '{}';
                return base + (comps ? ' +parts' : '') + (Number(x.tier) > 0 ? ' T' + x.tier : '')
                     + (x.serial ? ' #' + x.serial : '');
            };
            line('Money', money.join(', '));
            line('Weapons (' + w.length + ')', w.map(wName).join(', '));
            line('Items (' + it.length + ')',
                it.map(x => (x.label || x.name) + ' x' + x.count + (x.metadata ? '*' : '')).join(', '));

            if (d.canWrite && !r.restored) {
                const actions = el('div', 'action-form');
                const b = el('button', 'abtn', 'Give it all back');
                b.addEventListener('click', () => {
                    b.disabled = true;
                    b.textContent = 'Restoring...';
                    post('panelDeathRestore', { id: r.id });
                });
                actions.appendChild(b);
                actions.appendChild(el('span', 'offline-note',
                    'the character has to be online for this to land'));
                c.appendChild(actions);
            }
            body.appendChild(c);
        });
    }

    /* character-lock lookups land here; the open crafting editor installs it */
    let craftCharInfoHandler = null;
    /* same, for resolving a legacy steam hex to its name and characters */
    let craftSteamInfoHandler = null;

    const renderCraftEditor = (it) => {
        const body = $('#craftingBody');
        body.textContent = '';
        const isNew = !it;
        it = it || { materials: [], rewards: [], tools: [], category: (craftCats[0] && craftCats[0].key) || '', diff: 3000 };

        const back = el('button', 'back-btn', '← Back to recipes');
        back.addEventListener('click', () => post('panelCraftRecipes'));
        body.appendChild(back);

        const c = el('div', 'card actions-card');
        c.appendChild(el('div', 'actions-title',
            isNew ? 'New recipe - appends at the end; live when a player re-opens a station'
                  : ('Edit #' + it.id + ' "' + it.name + '"')));

        const inputs = {};
        const fieldRow = (key, label, hint, value, isSelect, options) => {
            const f = el('div', 'action-form');
            const lbl = el('span', 'offline-note', label);
            lbl.style.width = '8vw';
            let input;
            if (isSelect) {
                input = document.createElement('select');
                input.className = 'panel-select';
                (options || []).forEach(o => {
                    const op = document.createElement('option');
                    op.value = o.value; op.textContent = o.label;
                    input.appendChild(op);
                });
                input.value = value || '';
            } else {
                input = el('input');
                input.style.width = '12vw';
                input.value = (value === undefined || value === null) ? '' : String(value);
            }
            if (!craftCanWrite) { input.disabled = true; input.style.opacity = '.55'; }
            inputs[key] = input;
            f.appendChild(lbl); f.appendChild(input);
            if (hint) f.appendChild(el('span', 'offline-note', hint));
            c.appendChild(f);
        };

        fieldRow('name', 'Name', 'shown in the crafting list', it.name);
        fieldRow('category', 'Category', 'which station tab', it.category, true,
            craftCats.map(ct => ({ value: ct.key, label: ct.label })));
        fieldRow('desc', 'Description', 'optional flavour text', it.desc);
        fieldRow('job', 'Job lock', 'comma list e.g. blacksmith,doctor - blank = anyone', it.job);
        fieldRow('location', 'Stations',
            'comma list of location names - BLANK = campfire / crafting kit only, never at a station',
            it.location);
        if (craftLocNames.length) {
            const names = el('div', 'offline-note', 'Valid stations: ' + craftLocNames.join(', '));
            names.style.marginBottom = '0.6vh';
            c.appendChild(names);
        }
        fieldRow('gradelock', 'Grade lock', 'min job grade (blank = any)', it.gradelock);
        fieldRow('expreq', 'XP required', 'to unlock this recipe', it.expreq || 0);
        fieldRow('expadd', 'XP gained', 'per craft', it.expadd || 0);
        fieldRow('diff', 'Difficulty', 'minigame ms (higher = harder, 3000 typical)', it.diff || 3000);

        // dynamic materials / rewards editors
        const ingredientEditor = (title, list, hasLabel) => {
            c.appendChild(el('div', 'actions-title', title));
            const host = el('div');
            const rows = [];
            const addRow = (m) => {
                m = m || {};
                const r = el('div', 'action-form');
                const nameI = el('input'); nameI.placeholder = 'item db name'; nameI.style.width = '10vw';
                nameI.value = m.name || '';
                const labelI = el('input'); labelI.placeholder = 'label (shown)'; labelI.style.width = '9vw';
                labelI.value = m.label || '';
                const countI = el('input'); countI.type = 'number'; countI.min = '1'; countI.style.width = '5vw';
                countI.value = m.count || 1;
                const rm = el('button', 'abtn warn', '×');
                const entry = { nameI, labelI, countI, row: r };
                rm.addEventListener('click', () => {
                    const idx = rows.indexOf(entry);
                    if (idx >= 0) rows.splice(idx, 1);
                    r.remove();
                });
                r.appendChild(nameI);
                r.appendChild(labelI);
                r.appendChild(countI);
                if (craftCanWrite) r.appendChild(rm);
                if (!craftCanWrite) { nameI.disabled = labelI.disabled = countI.disabled = true; }
                if (craftCanWrite) attachItemSearch(nameI, labelI);
                rows.push(entry);
                host.appendChild(r);
            };
            (list || []).forEach(addRow);
            c.appendChild(host);
            if (craftCanWrite) {
                const add = el('button', 'abtn', '+ Add ' + (hasLabel ? 'material' : 'reward'));
                add.addEventListener('click', () => addRow({}));
                c.appendChild(add);
            }
            return () => rows.map(e => ({
                name: e.nameI.value.trim(),
                label: e.labelI.value.trim(),
                count: Number(e.countI.value) || 1,
            })).filter(x => x.name !== '');
        };

        const collectMats = ingredientEditor('Materials (consumed)', it.materials, true);
        /* TOOLS: the crafter must be HOLDING these, they are never taken, and the
           requirement does NOT scale with batch size - one skinning knife makes
           fifty leather. Put a thing here instead of in Materials whenever it
           should survive the craft. */
        const collectTools = ingredientEditor('Tools (required, never consumed)', it.tools, true);
        const collectRew = ingredientEditor('Rewards (produced)', it.rewards, false);

        /* CHARACTER LOCK (uinuqe) - the recipe is HIDDEN from anyone not
           listed. Ids resolve to character names through panelCraftCharLookup
           so the admin sees who they locked it to, not bare numbers. */
        c.appendChild(el('div', 'actions-title', 'Character lock'));
        const lockList = (it.uinuqe || []).map(Number).filter(n => n > 0);
        const lockHost = el('div');
        lockHost.className = 'lock-host';
        const lockNames = {}; // charid -> text span inside its chip
        const lockChip = (cid, name) => {
            const chip = el('span', 'chip lock-chip');
            const t = el('span', '', '#' + cid + (name ? ' ' + name : ''));
            chip.appendChild(t);
            lockNames[cid] = t;
            if (craftCanWrite) {
                const x = el('span', 'lock-chip-x', '×');
                x.addEventListener('click', () => {
                    const i = lockList.indexOf(cid);
                    if (i >= 0) lockList.splice(i, 1);
                    chip.remove(); delete lockNames[cid];
                });
                chip.appendChild(x);
            }
            lockHost.appendChild(chip);
        };
        lockList.forEach(cid => { lockChip(cid, null); post('panelCraftCharLookup', { charid: cid, intent: 'refresh' }); });
        c.appendChild(lockHost);
        /* LEGACY STEAM LOCK. Each hex resolves to its steam name and every character
           on that account, so the owner can see who it was and move them to char ids. */
        let steamList = (it.steamlocks || []).map(String).filter(s => s !== '');
        const steamRows = {}; // hex -> { chip, text, chars }
        if (steamList.length) {
            c.appendChild(el('div', 'offline-note',
                'legacy steam lock (' + steamList.length + ') - this account and ALL its characters can craft it. ' +
                'Players matching EITHER list get access.'));
            const steamHost = el('div');
            steamHost.className = 'lock-host';
            steamList.forEach(hex => {
                const chip = el('span', 'chip lock-chip');
                const t = el('span', '', hex + ' — looking up...');
                chip.appendChild(t);
                if (craftCanWrite) {
                    const x = el('span', 'lock-chip-x', '×');
                    x.addEventListener('click', () => {
                        const i = steamList.indexOf(hex);
                        if (i >= 0) steamList.splice(i, 1);
                        chip.remove(); delete steamRows[hex];
                    });
                    chip.appendChild(x);
                }
                steamRows[hex] = { chip: chip, text: t, chars: [] };
                steamHost.appendChild(chip);
                post('panelCraftSteamLookup', { hex: hex });
            });
            c.appendChild(steamHost);

            if (craftCanWrite) {
                const mf = el('div', 'action-form');
                const conv = el('button', 'abtn', 'Convert to character locks');
                const convMsg = el('span', 'offline-note', '');
                conv.addEventListener('click', () => {
                    let added = 0, dead = 0;
                    Object.keys(steamRows).forEach(hex => {
                        const chars = steamRows[hex].chars || [];
                        if (!chars.length) { dead++; return; }
                        chars.forEach(ch => {
                            if (lockList.includes(ch.charid)) return;
                            lockList.push(ch.charid);
                            lockChip(ch.charid, ch.name || '');
                            added++;
                        });
                    });
                    steamList = [];
                    Object.keys(steamRows).forEach(h => { steamRows[h].chip.remove(); delete steamRows[h]; });
                    convMsg.textContent = 'added ' + added + ' character lock' + (added === 1 ? '' : 's') +
                        (dead ? ', ' + dead + ' account(s) had no characters left and were dropped' : '') +
                        ' — press Save to apply';
                });
                mf.appendChild(conv);
                mf.appendChild(convMsg);
                c.appendChild(mf);
                c.appendChild(el('div', 'offline-note',
                    'converting lists each character by id, so the lock stops following every character on the account'));
            }
        }
        craftSteamInfoHandler = (d) => {
            if (!d || !d.hex || !steamRows[d.hex]) return;
            const row = steamRows[d.hex];
            if (!d.info || !d.info.chars || !d.info.chars.length) {
                row.chars = [];
                row.text.textContent = d.hex + ' — never seen, no characters on this account';
                row.chip.classList.add('is-off');
                return;
            }
            // a deleted character is still named, but it is not worth converting
            row.chars = d.info.chars.filter(ch => !ch.gone);
            const who = d.info.chars.map(ch =>
                '#' + ch.charid + (ch.name ? ' ' + ch.name : '') + (ch.gone ? ' (deleted)' : '')).join(', ');
            row.text.textContent = (d.info.steamname ? d.info.steamname + ' ' : '') + d.hex + ' — ' + who;
            if (!row.chars.length) row.chip.classList.add('is-off');
        };

        const lockMsg = el('span', 'offline-note', '');
        if (craftCanWrite) {
            const lf = el('div', 'action-form');
            const cidI = el('input'); cidI.type = 'number'; cidI.placeholder = 'char ID'; cidI.style.width = '6vw';
            const addB = el('button', 'abtn', 'Add character');
            const doAdd = () => {
                const cid = Math.floor(Number(cidI.value));
                if (!cid || cid <= 0) return;
                if (lockList.includes(cid)) { lockMsg.textContent = '#' + cid + ' is already listed'; return; }
                lockMsg.textContent = 'looking up #' + cid + '...';
                post('panelCraftCharLookup', { charid: cid, intent: 'add' });
            };
            addB.addEventListener('click', doAdd);
            cidI.addEventListener('keydown', (ev) => { if (ev.key === 'Enter') doAdd(); });
            lf.appendChild(cidI); lf.appendChild(addB); lf.appendChild(lockMsg);
            c.appendChild(lf);
            c.appendChild(el('div', 'offline-note',
                'empty = no lock. Locked recipes stay hidden from everyone not listed (outranks the job lock).'));
        }
        craftCharInfoHandler = (d) => {
            if (!d || !d.charid) return;
            if (d.intent === 'add') {
                if (!d.info) { lockMsg.textContent = 'character #' + d.charid + ' not found'; return; }
                if (lockList.includes(d.charid)) return;
                lockList.push(d.charid);
                lockChip(d.charid, d.info.name || '');
                lockMsg.textContent = '';
            } else if (d.info && lockNames[d.charid]) {
                lockNames[d.charid].textContent = '#' + d.charid + ' ' + (d.info.name || '');
            } else if (!d.info && lockNames[d.charid]) {
                lockNames[d.charid].textContent = '#' + d.charid + ' (deleted character)';
            }
        };

        if (craftCanWrite) {
            const actions = el('div', 'action-form');
            const save = el('button', 'abtn', isNew ? 'Create' : 'Save');
            save.addEventListener('click', () => {
                const payload = {
                    id: isNew ? null : it.id,
                    name: inputs.name.value.trim(),
                    category: inputs.category.value,
                    desc: inputs.desc.value,
                    job: inputs.job.value.trim(),
                    location: inputs.location.value.trim(),
                    gradelock: inputs.gradelock.value.trim() === '' ? null : Number(inputs.gradelock.value),
                    expreq: Number(inputs.expreq.value) || 0,
                    expadd: Number(inputs.expadd.value) || 0,
                    diff: Number(inputs.diff.value) || 3000,
                    materials: collectMats(),
                    rewards: collectRew(),
                    tools: collectTools(),
                    uinuqe: lockList.slice(),
                };
                // only sent when the recipe actually had one, so it can never be wiped by accident
                if (it.steamlocks) payload.uinuqesteam = steamList.slice();
                if (!payload.name || !payload.category) return;
                if (!payload.materials.length || !payload.rewards.length) return;
                post('panelCraftSave', payload);
            });
            actions.appendChild(save);

            if (!isNew) {
                const toggle = el('button', it.enabled ? 'abtn warn' : 'abtn', it.enabled ? 'Disable' : 'Enable');
                toggle.addEventListener('click', () => post('panelCraftSetEnabled', { id: it.id, enabled: !it.enabled }));
                actions.appendChild(toggle);
                actions.appendChild(el('span', 'offline-note', 'disable keeps the slot (favourites never shift)'));
            }
            c.appendChild(actions);
        }
        body.appendChild(c);
    };

    /* crafting LOCATIONS (name-keyed markers; recipes reference them by name) */
    let craftLocCanWrite = false;

    const renderCraftLocations = (data) => {
        const body = $('#craftingBody');
        body.textContent = '';
        const back = el('button', 'back-btn', '← Back to recipes');
        back.addEventListener('click', () => post('panelCraftRecipes'));
        body.appendChild(back);

        if (!data || data.missing) { body.appendChild(el('div', 'empty', 'pup_workbench is not running')); return; }
        const locs = data.locations || [];
        craftLocCanWrite = !!data.canWrite;

        const head = el('div', 'action-form');
        if (craftLocCanWrite) {
            const nb = el('button', 'abtn', '+ New Location (at my position)');
            nb.addEventListener('click', () => renderCraftLocationEditor(null));
            head.appendChild(nb);
        }
        head.appendChild(el('span', 'offline-note',
            locs.length + ' locations - recipes with a matching location name craft here. Name 0 = anywhere.'));
        body.appendChild(head);

        const listHost = el('div');
        body.appendChild(listHost);
        pagedList(listHost, locs, it => it.name, it => {
            const row = el('div', 'prow');
            row.style.gridTemplateColumns = '1.6fr 2fr .8fr';
            row.style.opacity = it.enabled ? '1' : '.5';
            row.appendChild(el('div', 'pname', it.name));
            row.appendChild(el('div', 'offline-note',
                it.x.toFixed(1) + ', ' + it.y.toFixed(1) + ', ' + it.z.toFixed(1)));
            const st = el('div');
            st.appendChild(el('span', 'chip', it.enabled ? 'on' : 'off'));
            row.appendChild(st);
            if (craftLocCanWrite) {
                row.style.cursor = 'pointer';
                row.addEventListener('click', () => renderCraftLocationEditor(it));
            }
            return row;
        }, { per: 25, placeholder: 'Search locations...' });
    };

    const renderCraftLocationEditor = (it) => {
        const body = $('#craftingBody');
        body.textContent = '';
        const isNew = !it;
        it = it || {};
        const back = el('button', 'back-btn', '← Back to locations');
        back.addEventListener('click', () => post('panelCraftLocations'));
        body.appendChild(back);

        const c = el('div', 'card actions-card');
        c.appendChild(el('div', 'actions-title', isNew ? 'New location' : ('Edit "' + it.name + '"')));

        const mk = (label, val) => {
            const f = el('div', 'action-form');
            const l = el('span', 'offline-note', label); l.style.width = '6vw';
            const i = el('input'); i.style.width = '11vw';
            i.value = (val === undefined || val === null) ? '' : String(val);
            f.appendChild(l); f.appendChild(i); c.appendChild(f);
            return i;
        };
        const nameI = mk('Name', it.name);
        if (!isNew) { nameI.disabled = true; nameI.style.opacity = '.55'; }
        const xI = mk('X', it.x), yI = mk('Y', it.y), zI = mk('Z', it.z);

        const posBtn = el('button', 'abtn', 'Use my current position');
        posBtn.addEventListener('click', () => {
            post('panelCraftMyPos').then(r => r && r.json()).then(pos => {
                if (pos) { xI.value = pos.x.toFixed(3); yI.value = pos.y.toFixed(3); zI.value = pos.z.toFixed(3); }
            });
        });
        c.appendChild(posBtn);

        const actions = el('div', 'action-form');
        const save = el('button', 'abtn', isNew ? 'Create' : 'Save');
        // pup: every refusal says which field it was, in the panel, so a save that
        // went nowhere does not look like a click that never registered. A
        // successful save drops back to the list so the new coords show at once.
        save.addEventListener('click', () => {
            try {
                // the name box is disabled when editing; read it from the row we
                // were opened with rather than the greyed-out input
                const nm = (isNew ? nameI.value : (it.name || nameI.value) || '').trim();
                const nums = { X: Number(xI.value), Y: Number(yI.value), Z: Number(zI.value) };
                if (!nm) {
                    return showPanelToast({ text: 'Give the location a name first.', error: true });
                }
                const bad = Object.keys(nums).filter(k => !isFinite(nums[k]));
                if (bad.length) {
                    return showPanelToast({
                        text: bad.join(' and ') + ' must be a number. Use "Use my current position".',
                        error: true,
                    });
                }
                post('panelCraftSaveLocation', { name: nm, x: nums.X, y: nums.Y, z: nums.Z });
                showPanelToast({ text: 'Saving "' + nm + '"...' });
                setTimeout(() => post('panelCraftLocations'), 900);
            } catch (e) {
                showPanelToast({ text: 'Save failed in the panel: ' + e.message, error: true });
            }
        });
        if (!craftLocCanWrite) {
            save.disabled = true;
            save.style.opacity = '.5';
        }
        actions.appendChild(save);
        if (!craftLocCanWrite) {
            actions.appendChild(el('span', 'offline-note', 'read only - you do not have manage_crafting'));
        }
        if (!isNew) {
            const toggle = el('button', it.enabled ? 'abtn warn' : 'abtn', it.enabled ? 'Disable' : 'Enable');
            toggle.addEventListener('click', () => post('panelCraftSetLocationEnabled', { name: it.name, enabled: !it.enabled }));
            actions.appendChild(toggle);
        }
        c.appendChild(actions);
        body.appendChild(c);
    };

    /* ---------------------------------------------------- weapon crafting page
       pup-weapons recipes. Two kinds: 'weapon' (reward = a weapon hashname) and
       'ammo' (reward = an ammo item + game key + box qty). Materials are keyed
       item1..itemN in the config; shown as a row list here. */
    let weaponCats = { weapon: [], ammo: [] };
    let weaponCanWrite = false;

    /* WEAPON CRAFTING STATIONS - pup_gunsmith reads these from the database and
       pushes every change to players at once, so nothing here needs a restart.
       Position is set in game with /weaponcraftloc; the panel does the rest. */
    function renderWeaponCraftLocations(d) {
        const body = $('#weaponcraftBody');
        if (!body) return;
        body.textContent = '';

        const back = el('button', 'back-btn', '← Back to recipes');
        back.addEventListener('click', () => post('panelWeaponRecipes'));
        body.appendChild(back);

        if (!d) { body.appendChild(el('div', 'empty', 'Could not read the stations')); return; }
        if (d.missing) { body.appendChild(el('div', 'empty', 'pup_gunsmith is not running')); return; }

        const rows = d.rows || [];
        const c = el('div', 'card actions-card');
        c.appendChild(el('div', 'actions-title',
            rows.length + ' crafting station' + (rows.length === 1 ? '' : 's')));
        c.appendChild(el('div', 'offline-note',
            'Edit a position here and press Save, or press Here to drop it where you are standing. Every change is live at once - no restart.'));
        c.appendChild(el('div', 'offline-note',
            'To add a NEW station, stand where it belongs and run  /weaponcraftloc <name> [job1,job2]'));
        // the Here buttons read this; ask once so the first press is instant
        post('panelMyPos');
        body.appendChild(c);

        if (!rows.length) { body.appendChild(el('div', 'empty', 'No stations yet')); return; }

        /* five columns, and the grid is set here rather than reusing .prow's:
           Position needs room for three boxes and a button on ONE line. */
        const COLS = '1.3fr 1.1fr 1.6fr .6fr .9fr';
        const head = el('div', 'table-head');
        head.style.gridTemplateColumns = COLS;
        ['Station', 'Jobs', 'Position', 'Status', ''].forEach(h => head.appendChild(el('div', '', h)));
        body.appendChild(head);

        const act = (payload) => post('panelWeaponCraftLocAction', payload);

        rows.forEach(r => {
            const row = el('div', 'prow');
            row.style.gridTemplateColumns = COLS;
            const nw = el('div', 'pname');
            const inner = el('div');
            inner.appendChild(el('div', 'n', r.name));
            inner.appendChild(el('div', 's', r.enabled ? 'live' : 'switched off'));
            nw.appendChild(inner);
            row.appendChild(nw);

            // wrapped in an action-form: panel.css only styles inputs inside one,
            // and a bare input renders as a white browser default
            const jobWrap = el('div', 'action-form');
            const jobsIn = el('input');
            jobsIn.value = r.jobs || '';
            jobsIn.placeholder = 'any job';
            jobsIn.title = 'Comma separated, e.g. vtgunsmith,rdgunsmith. Blank = any job.';
            jobWrap.appendChild(jobsIn);
            row.appendChild(jobWrap);

            /* editable position. "Here" fills it from where the admin is standing,
               which is the same thing /weaponcraftloc does. */
            const pos = el('div', 'action-form');
            const num = (v) => {
                const i = el('input', 'narrow');
                i.value = Number(v).toFixed(2);
                return i;
            };
            const xi = num(r.x), yi = num(r.y), zi = num(r.z);
            const here = el('button', 'abtn', 'Here');
            here.title = 'Fill with your current position';
            here.addEventListener('click', () => {
                if (!myPos) { post('panelMyPos'); here.textContent = '...'; setTimeout(() => {
                    if (myPos) { xi.value = Number(myPos.x).toFixed(2); yi.value = Number(myPos.y).toFixed(2); zi.value = Number(myPos.z).toFixed(2); }
                    here.textContent = 'Here';
                }, 600); return; }
                xi.value = Number(myPos.x).toFixed(2);
                yi.value = Number(myPos.y).toFixed(2);
                zi.value = Number(myPos.z).toFixed(2);
            });
            pos.appendChild(xi); pos.appendChild(yi); pos.appendChild(zi); pos.appendChild(here);
            row.appendChild(pos);

            row.appendChild(el('span', 'chip', r.enabled ? 'enabled' : 'disabled'));

            const btns = el('div', 'right');
            const save = el('button', 'abtn', 'Save');
            save.title = 'Saves the jobs and the position together - live immediately';
            save.addEventListener('click', () => {
                const x = parseFloat(xi.value), y = parseFloat(yi.value), z = parseFloat(zi.value);
                if (!isFinite(x) || !isFinite(y) || !isFinite(z)) {
                    showPanelToast({ kind: 'error', text: 'Those coordinates are not numbers' });
                    return;
                }
                act({ act: 'move', name: r.name, jobs: jobsIn.value.trim(), x: x, y: y, z: z });
            });
            btns.appendChild(save);
            const tog = el('button', r.enabled ? 'abtn warn' : 'abtn', r.enabled ? 'Disable' : 'Enable');
            tog.addEventListener('click', () => act({ act: r.enabled ? 'disable' : 'enable', name: r.name }));
            btns.appendChild(tog);
            row.appendChild(btns);

            body.appendChild(row);
        });
    }

    function renderDoorLocks(d) {
        const body = $('#doorlocksBody');
        if (!body) return;
        body.textContent = '';

        if (!d) { body.appendChild(el('div', 'empty', 'Could not read the doors (are you allowed?)')); return; }
        if (d.missing) { body.appendChild(el('div', 'empty', 'doorlocks is not running')); return; }

        doorLastData = d;
        const DOORS_PER = 15;
        const rows = d.rows || [];
        /* a search that shrinks the list must not leave you stranded on page 6 */
        const doorPages = Math.max(1, Math.ceil(rows.length / DOORS_PER));
        if (doorPage >= doorPages) doorPage = doorPages - 1;
        if (doorPage < 0) doorPage = 0;
        const shown = rows.slice(doorPage * DOORS_PER, (doorPage + 1) * DOORS_PER);

        const c = el('div', 'card actions-card');
        c.appendChild(el('div', 'actions-title',
            rows.length + ' of ' + (d.total || rows.length) + ' door' + ((d.total || rows.length) === 1 ? '' : 's')));
        c.appendChild(el('div', 'offline-note',
            'Jobs are comma separated. A grade can be added after a colon - ValSheriff:0, RhoSheriff:2 means a Rhodes deputy needs grade 2 or above. Blank means ANY player can open it.'));
        c.appendChild(el('div', 'offline-note',
            'Go to teleports you to the door and closes the panel. Every save is live for all players at once.'));

        const sf = el('div', 'action-form');
        const si = el('input');
        si.placeholder = 'Search by door name, job or id';
        si.value = doorSearchTerm;
        const go = el('button', 'abtn', 'Search');
        const runSearch = () => {
            doorSearchTerm = si.value.trim();
            doorPage = 0;   // a new search always starts at the top
            post('panelDoorLocks', { search: doorSearchTerm });
        };
        go.addEventListener('click', runSearch);
        si.addEventListener('keydown', (e) => { if (e.key === 'Enter') runSearch(); });
        const clear = el('button', 'abtn', 'Clear');
        clear.addEventListener('click', () => { si.value = ''; runSearch(); });
        sf.appendChild(si); sf.appendChild(go); sf.appendChild(clear);
        c.appendChild(sf);
        body.appendChild(c);

        if (!rows.length) {
            body.appendChild(el('div', 'empty', doorSearchTerm ? 'No door matches that' : 'No doors registered'));
            return;
        }

        const COLS = '1.2fr 1.7fr .7fr .8fr 1.1fr';
        const head = el('div', 'table-head');
        head.style.gridTemplateColumns = COLS;
        ['Door', 'Jobs with a key', 'State', 'Keys', ''].forEach(h => head.appendChild(el('div', '', h)));
        body.appendChild(head);

        const act = (payload) => post('panelDoorLockAction', payload);

        shown.forEach(r => {
            const row = el('div', 'prow');
            row.style.gridTemplateColumns = COLS;

            const nw = el('div', 'pname');
            const inner = el('div');
            inner.appendChild(el('div', 'n', r.name || 'Door'));
            inner.appendChild(el('div', 's', '#' + r.doorid + (r.double ? ' - double' : '')));
            nw.appendChild(inner);
            row.appendChild(nw);

            const jobWrap = el('div', 'action-form');
            const jobsIn = el('input');
            jobsIn.value = r.jobs || '';
            jobsIn.placeholder = 'anyone';
            jobsIn.title = 'Comma separated. job:grade sets a minimum grade. Blank = anyone can open it.';
            jobWrap.appendChild(jobsIn);
            row.appendChild(jobWrap);

            row.appendChild(el('span', r.locked ? 'chip warn' : 'chip', r.locked ? 'locked' : 'unlocked'));

            const keys = el('div', 's');
            keys.textContent = (r.charCount > 0 ? r.charCount + ' character' + (r.charCount === 1 ? '' : 's') : 'job only')
                + (r.canLockpick ? ' - pickable' : '');
            row.appendChild(keys);

            const btns = el('div', 'right');

            const save = el('button', 'abtn', 'Save');
            save.title = 'Save the job list - live immediately';
            save.addEventListener('click', () => act({ act: 'jobs', doorid: r.doorid, jobs: jobsIn.value.trim() }));
            btns.appendChild(save);

            const tog = el('button', r.locked ? 'abtn' : 'abtn warn', r.locked ? 'Unlock' : 'Lock');
            tog.addEventListener('click', () => act({ act: r.locked ? 'unlock' : 'lock', doorid: r.doorid }));
            btns.appendChild(tog);

            const goto = el('button', 'abtn', 'Go to');
            goto.title = 'Teleport to this door';
            goto.addEventListener('click', () => post('panelDoorGoto', { x: r.x, y: r.y, z: r.z }));
            btns.appendChild(goto);

            row.appendChild(btns);
            body.appendChild(row);
        });

        if (rows.length > DOORS_PER) {
            body.appendChild(pagerBar(rows.length, doorPage, DOORS_PER,
                p => { doorPage = p; renderDoorLocks(doorLastData); }));
        }
    }

    const renderWeaponRecipes = (data) => {
        const body = $('#weaponcraftBody');
        body.textContent = '';
        if (!data || data.missing) { body.appendChild(el('div', 'empty', 'pup_gunsmith is not running')); return; }
        if (!Array.isArray(data.recipes)) { body.appendChild(el('div', 'empty', 'No data (are you allowed?)')); return; }
        weaponCats = data.categories || { weapon: [], ammo: [] };
        weaponCanWrite = !!data.canWrite;

        const head = el('div', 'action-form');
        if (weaponCanWrite) {
            const nw = el('button', 'abtn', '+ New Weapon');
            nw.addEventListener('click', () => renderWeaponEditor(null, 'weapon'));
            head.appendChild(nw);
            const na = el('button', 'abtn', '+ New Ammo');
            na.addEventListener('click', () => renderWeaponEditor(null, 'ammo'));
            head.appendChild(na);
            // where they can be crafted; opens over this page like the editor does
            const loc = el('button', 'abtn', 'Crafting Stations');
            loc.addEventListener('click', () => post('panelWeaponCraftLocations'));
            head.appendChild(loc);
        }
        const enabledCount = data.recipes.filter(r => r.enabled).length;
        head.appendChild(el('span', 'offline-note',
            data.recipes.length + ' recipes (' + enabledCount + ' enabled)' +
            (weaponCanWrite ? '' : ' - read only (needs manage_crafting to edit)')));
        body.appendChild(head);

        const listHost = el('div');
        body.appendChild(listHost);
        pagedList(listHost, data.recipes,
            it => (it.label + ' ' + it.category + ' ' + it.kind),
            it => {
                const row = el('div', 'prow');
                row.style.gridTemplateColumns = '.7fr 2.2fr 1.4fr 1.3fr .7fr';
                row.style.cursor = weaponCanWrite ? 'pointer' : 'default';
                row.style.opacity = it.enabled ? '1' : '.5';
                row.appendChild(el('div', null, it.kind === 'ammo' ? 'ammo' : 'gun'));
                row.appendChild(el('div', 'pname', it.label));
                row.appendChild(el('div', null, it.category));
                row.appendChild(el('div', 'offline-note',
                    (it.materials || []).map(m => m.amount + '× ' + (m.label || m.name)).join(', ')));
                const st = el('div');
                st.appendChild(el('span', 'chip', it.enabled ? 'on' : 'off'));
                if (!it.letcraft) st.appendChild(el('span', 'chip', 'no-craft'));
                if (it.jobonly) st.appendChild(el('span', 'chip', 'job'));
                row.appendChild(st);
                if (weaponCanWrite) row.addEventListener('click', () => renderWeaponEditor(it, it.kind));
                return row;
            },
            {
                per: 25,
                placeholder: 'Search by weapon/ammo name, category or kind...',
                // weapon and ammo keep separate category lists in pup-weapons, and the
                // same name can appear in both - so the tab carries the kind too,
                // otherwise picking "revolver" would mix guns in with their ammo
                categoryOf: it => (it.kind === 'ammo' ? 'ammo' : 'gun') + ' · ' + it.category
            });
    };

    const renderWeaponEditor = (it, kind) => {
        const body = $('#weaponcraftBody');
        body.textContent = '';
        const isNew = !it;
        it = it || { materials: [], kind: kind, category: (weaponCats[kind] && weaponCats[kind][0]) || '', diff: 3000, letcraft: true, jobonly: false };
        kind = it.kind || kind;

        const back = el('button', 'back-btn', '← Back to weapon recipes');
        back.addEventListener('click', () => post('panelWeaponRecipes'));
        body.appendChild(back);

        const c = el('div', 'card actions-card');
        c.appendChild(el('div', 'actions-title',
            (isNew ? 'New ' : 'Edit ') + (kind === 'ammo' ? 'ammo' : 'weapon') +
            (isNew ? ' - live when a player re-opens a gunsmith' : (' "' + it.label + '"'))));

        const inputs = {};
        const row = (key, label, hint, value, isSelect, options, isCheck) => {
            const f = el('div', 'action-form');
            const lbl = el('span', 'offline-note', label); lbl.style.width = '8vw';
            let input;
            if (isCheck) {
                input = el('input'); input.type = 'checkbox'; input.checked = !!value;
            } else if (isSelect) {
                input = document.createElement('select'); input.className = 'panel-select';
                (options || []).forEach(o => { const op = document.createElement('option'); op.value = o; op.textContent = o; input.appendChild(op); });
                input.value = value || '';
            } else {
                input = el('input'); input.style.width = '12vw';
                input.value = (value === undefined || value === null) ? '' : String(value);
            }
            if (!weaponCanWrite) { input.disabled = true; input.style.opacity = '.55'; }
            inputs[key] = input;
            f.appendChild(lbl); f.appendChild(input);
            if (hint) f.appendChild(el('span', 'offline-note', hint));
            c.appendChild(f);
        };

        row('label', 'Name', 'shown in the craft list', it.label);
        row('category', 'Category', 'gunsmith tab', it.category, true, weaponCats[kind] || []);
        if (kind === 'weapon') {
            row('hashname', 'Weapon hash', 'e.g. WEAPON_MELEE_KNIFE_HORROR', it.hashname);
        } else {
            row('item', 'Ammo item', 'inventory item name of the box', it.item);
            row('key', 'Ammo key', 'game ammo key e.g. AMMO_REPEATER', it.key);
            row('qt', 'Box quantity', 'bullets per box', it.qt || 1);
            row('maxammo', 'Max ammo', 'game cap (e.g. 200)', it.maxammo || 200);
        }
        row('expreq', 'XP required', 'gunsmith XP to unlock', it.expreq || 0);
        row('expadd', 'XP gained', 'per craft', it.expadd || 0);
        row('diff', 'Difficulty', 'minigame ms (3000 typical)', it.diff || 3000);
        row('letcraft', 'Craftable', 'off = sellable but not craftable', it.letcraft !== false, false, null, true);
        row('jobonly', 'Job only', 'restrict to the jobs below', it.jobonly === true, false, null, true);
        row('jobs', 'Jobs', 'comma list e.g. rdgunsmith,badmanners', it.jobs);
        if (kind === 'ammo' && weaponCanWrite && inputs.item) attachItemSearch(inputs.item, null);

        // materials editor (keyed item1..N under the hood)
        c.appendChild(el('div', 'actions-title', 'Materials (consumed per craft)'));
        const host = el('div'); const mrows = [];
        const addMat = (m) => {
            m = m || {};
            const r = el('div', 'action-form');
            const nameI = el('input'); nameI.placeholder = 'item name'; nameI.style.width = '10vw'; nameI.value = m.name || '';
            const labelI = el('input'); labelI.placeholder = 'label'; labelI.style.width = '9vw'; labelI.value = m.label || '';
            const amtI = el('input'); amtI.type = 'number'; amtI.min = '1'; amtI.style.width = '5vw'; amtI.value = m.amount || 1;
            const rm = el('button', 'abtn warn', '×');
            const entry = { nameI, labelI, amtI };
            rm.addEventListener('click', () => { const i = mrows.indexOf(entry); if (i >= 0) mrows.splice(i, 1); r.remove(); });
            r.appendChild(nameI); r.appendChild(labelI); r.appendChild(amtI);
            if (weaponCanWrite) r.appendChild(rm); else { nameI.disabled = labelI.disabled = amtI.disabled = true; }
            if (weaponCanWrite) attachItemSearch(nameI, labelI);
            mrows.push(entry); host.appendChild(r);
        };
        (it.materials || []).forEach(addMat);
        c.appendChild(host);
        if (weaponCanWrite) {
            const add = el('button', 'abtn', '+ Add material');
            add.addEventListener('click', () => addMat({}));
            c.appendChild(add);
        }

        if (weaponCanWrite) {
            const actions = el('div', 'action-form');
            const save = el('button', 'abtn', isNew ? 'Create' : 'Save');
            save.addEventListener('click', () => {
                const payload = {
                    id: isNew ? null : it.id,
                    kind: kind,
                    label: inputs.label.value.trim(),
                    category: inputs.category.value,
                    expreq: Number(inputs.expreq.value) || 0,
                    expadd: Number(inputs.expadd.value) || 0,
                    diff: Number(inputs.diff.value) || 3000,
                    letcraft: inputs.letcraft.checked,
                    jobonly: inputs.jobonly.checked,
                    jobs: inputs.jobs.value.trim(),
                    materials: mrows.map(e => ({ name: e.nameI.value.trim(), label: e.labelI.value.trim(), amount: Number(e.amtI.value) || 1 })).filter(x => x.name !== ''),
                };
                if (kind === 'weapon') payload.hashname = inputs.hashname.value.trim();
                else { payload.item = inputs.item.value.trim(); payload.key = inputs.key.value.trim(); payload.qt = Number(inputs.qt.value) || 1; payload.maxammo = Number(inputs.maxammo.value) || 200; }
                if (!payload.label || !payload.category || !payload.materials.length) return;
                if (kind === 'weapon' && !payload.hashname) return;
                if (kind === 'ammo' && (!payload.item || !payload.key)) return;
                post('panelWeaponSave', payload);
            });
            actions.appendChild(save);
            if (!isNew) {
                const toggle = el('button', it.enabled ? 'abtn warn' : 'abtn', it.enabled ? 'Disable' : 'Enable');
                toggle.addEventListener('click', () => post('panelWeaponSetEnabled', { id: it.id, enabled: !it.enabled }));
                actions.appendChild(toggle);
            }
            c.appendChild(actions);
        }
        body.appendChild(c);
    };

    /* ------------------------------------------------------------- items db page */
    let itemSearchTimer = null;
    $('#itemSearch').addEventListener('input', () => {
        clearTimeout(itemSearchTimer);
        itemSearchTimer = setTimeout(() => post('panelItemsSearch', { term: $('#itemSearch').value.trim() }), 300);
    });

    // ALL editable columns - mirrors the server's ITEM_FIELDS whitelist exactly
    // (only `item` and `id` are immutable). [col, hint]
    const ITEM_COLS = [
        ['label', 'display name, max 50'],
        ['limit', '-1 = unlimited'],
        ['weight', 'kg, decimal'],
        ['type', 'item_standard / item_weapon ...'],
        ['usable', 'true / false'],
        ['can_remove', 'true / false'],
        ['useExpired', 'true / false'],
        ['groupId', 'filter group (int)'],
        ['rarityId', 'rarity (int)'],
        ['degradation', 'minutes, 0 = no decay'],
        ['durability', 'int, -1 sets NULL'],
        ['metadata', 'JSON object'],
        ['instructions', 'crafting text, "" sets NULL'],
        ['desc', 'description, max 5550'],
    ];

    // a labelled paragraph line, used by both the create and the delete cards
    const noteLine = (text, warn) => {
        const p = el('div', 'offline-note', text);
        p.style.margin = '.25vw 0';
        p.style.lineHeight = '1.5';
        if (warn) p.style.color = '#e0a17a';
        return p;
    };

    // "New item" card, collapsed until wanted so the list stays first on the page.
    const newItemCard = () => {
        const wrap = el('div');
        const open = el('button', 'abtn', '+ Create a new item');
        wrap.appendChild(open);

        const c = el('div', 'card actions-card');
        c.style.display = 'none';
        c.appendChild(el('div', 'actions-title', 'Create a new item'));
        c.appendChild(noteLine('This inserts one row into the `items` table. That is all it does — '
            + 'it makes the item EXIST so it can be given, sold, crafted and carried.'));
        c.appendChild(noteLine('It does NOT write any script logic. A usable item still needs a '
            + 'resource to register a handler for its name, or "use" will do nothing.'));

        const field = (label, hint, setup) => {
            const f = el('div', 'action-form');
            f.style.alignItems = 'flex-start';
            const lbl = el('span', 'offline-note', label);
            lbl.style.width = '6vw';
            const input = el('input');
            input.style.width = '14vw';
            if (setup) setup(input);
            const h = el('span', 'offline-note', hint);
            h.style.maxWidth = '26vw';
            h.style.lineHeight = '1.45';
            f.appendChild(lbl); f.appendChild(input); f.appendChild(h);
            c.appendChild(f);
            return input;
        };

        const nameIn = field('item',
            'The internal name — the primary key, and what every script, shop and recipe refers to. '
            + 'Letters, numbers and underscore only, max 50. It also has to match the icon filename '
            + '(vorp_inventory/html/img/<name>.png). Cannot be changed later without breaking anything using it.',
            i => i.placeholder = 'apple_pie');

        const labelIn = field('label',
            'What players see in the inventory and in shops. Max 50 characters, spaces and punctuation fine. '
            + 'Safe to change any time.',
            i => i.placeholder = 'Apple Pie');

        const limitIn = field('limit',
            'How many a player may carry of this one item. -1 = unlimited. Set 1 for things that must not '
            + 'stack (outfits, unique tools). This is the per-item cap, separate from the inventory weight cap.',
            i => { i.placeholder = '10'; i.value = '10'; });

        const weightIn = field('weight',
            'LEAVE THIS AT 1. This server counts inventory SLOTS through weight — every item is 1.0, '
            + 'so one item fills one slot. A weight of 0 is carried for free and fills nothing; '
            + 'anything above 1 makes the item cost that many slots.',
            i => { i.placeholder = '1'; i.value = '1'; });

        const usableIn = field('usable',
            'true = the "Use" button appears on it. Only set true if a script actually handles it — a usable '
            + 'item with no handler is a button that does nothing and confuses players.',
            i => { i.placeholder = 'false'; i.value = 'false'; });

        const typeIn = field('type',
            'Almost always item_standard. item_weapon is for weapon rows and those are managed by the weapon '
            + 'system, not created here — leave this alone unless you know why you are changing it.',
            i => { i.placeholder = 'item_standard'; i.value = 'item_standard'; });

        const descIn = field('desc',
            'Description text shown on the item. Leave blank to reuse the label. Max 5550 characters.',
            i => i.placeholder = '(defaults to the label)');

        c.appendChild(noteLine('Defaults applied for you: can_remove 1 (can be dropped/given), degradation 0 '
            + '(never spoils), no durability, no metadata. All of them are editable afterwards by clicking '
            + 'the item in the list.'));
        c.appendChild(noteLine('AFTER CREATING — two things this panel cannot do for you: '
            + '(1) drop a PNG named exactly like the item into vorp_inventory/html/img/, or it shows a blank box; '
            + '(2) run "restart vorp_inventory" — item definitions are cached at that resource\'s start, so '
            + 'until you restart it the item exists in the database but the server will not hand it out.', true));

        const row = el('div', 'action-form');
        const create = el('button', 'abtn', 'Create Item');
        const note = el('span', 'offline-note', '');
        note.style.maxWidth = '30vw';
        note.style.lineHeight = '1.45';
        create.addEventListener('click', () => {
            const item = nameIn.value.trim();
            const label = labelIn.value.trim();
            if (!item || !label) { note.textContent = 'Item name and label are both required.'; return; }
            if (/[^A-Za-z0-9_]/.test(item)) {
                note.textContent = 'Item name "' + item + '" is not allowed — letters, numbers and _ only, no spaces.';
                return;
            }
            if (item.length > 50) { note.textContent = 'Item name is longer than 50 characters.'; return; }
            if (label.length > 50) { note.textContent = 'Label is longer than 50 characters.'; return; }
            const lim = Number(limitIn.value);
            if (limitIn.value.trim() !== '' && !Number.isFinite(lim)) { note.textContent = 'Limit must be a number (-1 for unlimited).'; return; }
            const wt = Number(weightIn.value);
            if (weightIn.value.trim() !== '' && (!Number.isFinite(wt) || wt < 0)) { note.textContent = 'Weight must be 0 or a positive number.'; return; }

            note.textContent = 'Creating "' + item + '" — if the name is already taken the server will say so.';
            post('panelItemsCreate', {
                item: item,
                label: label,
                limit: Number.isFinite(lim) ? lim : 10,
                weight: Number.isFinite(wt) ? wt : 0,
                usable: /^(1|true|yes)$/i.test(usableIn.value.trim()),
                type: typeIn.value.trim() || 'item_standard',
                desc: descIn.value.trim(),
            });
            nameIn.value = ''; labelIn.value = ''; descIn.value = '';
        });
        row.appendChild(create); row.appendChild(note);
        c.appendChild(row);
        wrap.appendChild(c);

        open.addEventListener('click', () => {
            const shown = c.style.display !== 'none';
            c.style.display = shown ? 'none' : '';
            open.textContent = shown ? '+ Create a new item' : '− Hide the new item form';
        });
        return wrap;
    };

    const renderItems = (data) => {
        const body = $('#itemsBody');
        body.textContent = '';
        body.appendChild(newItemCard());
        if (!data || !data.rows) {
            body.appendChild(el('div', 'empty', 'No data'));
            return;
        }
        // pup: server-side pages (30/page); the count respects the search term
        const ipage = Number(data.page) || 0;
        const from = data.rows.length ? (ipage * 30 + 1) : 0;
        const to = ipage * 30 + data.rows.length;
        body.appendChild(el('div', 'offline-note', from + '–' + to + ' of ' + fmt(data.total) + ' items — click one to edit'));
        const rows = el('div', 'rows');
        rows.style.marginTop = '.5vw';
        data.rows.forEach(r => {
            const row = el('div', 'prow');
            row.style.gridTemplateColumns = '2fr 2fr 1fr 1fr 1fr';
            row.style.cursor = 'pointer';
            row.addEventListener('click', () => post('panelItemsGet', { item: r.item }));
            row.appendChild(el('div', 'pmoney', r.item));
            row.appendChild(el('div', 'pxp', r.label || ''));
            row.appendChild(el('div', 'pxp', 'limit ' + (r.limit === null ? '∞' : r.limit)));
            row.appendChild(el('div', 'pxp', (r.weight === null ? '—' : r.weight) + ' kg'));
            row.appendChild(el('div', 'pxp', (Number(r.usable) ? 'usable' : '')));
            rows.appendChild(row);
        });
        body.appendChild(rows);
        if (data.total > 30) {
            body.appendChild(pagerBar(data.total, ipage, 30,
                p => post('panelItemsSearch', { term: $('#itemSearch').value.trim(), page: p })));
        }
    };

    const renderItemDetail = (r) => {
        const body = $('#itemsBody');
        body.textContent = '';
        if (!r) { body.appendChild(el('div', 'empty', 'Could not load item (need admin_actions_menu permission)')); return; }
        const back = el('button', 'back-btn', '← Back to list');
        back.addEventListener('click', () => post('panelItemsSearch', { term: $('#itemSearch').value.trim() }));
        body.appendChild(back);

        const c = el('div', 'card actions-card');
        c.appendChild(el('div', 'actions-title', 'Edit "' + r.item + '" — saves instantly, applies after vorp_inventory restart'));
        ITEM_COLS.forEach(([col, hint]) => {
            const f = el('div', 'action-form');
            const lbl = el('span', 'offline-note', col);
            lbl.style.width = '6vw';
            const input = el('input');
            input.style.width = '14vw';
            let v = r[col];
            if (v !== null && typeof v === 'object') v = JSON.stringify(v);
            input.value = (v === null || v === undefined) ? '' : String(v);
            const save = el('button', 'abtn', 'Save');
            save.addEventListener('click', () => post('panelItemsUpdate', { item: r.item, col, value: input.value }));
            f.appendChild(lbl); f.appendChild(input); f.appendChild(save);
            f.appendChild(el('span', 'offline-note', hint));
            c.appendChild(f);
        });
        body.appendChild(c);

        // DELETE in its own card. Copies players hold are NOT removed - items_crafted
        // keeps its rows and DbService LEFT JOINs items, so they load with no name.
        if (!hasPerm('delete_item')) return;
        const d = el('div', 'card actions-card');
        d.appendChild(el('div', 'actions-title', 'Delete "' + r.item + '"'));
        d.appendChild(noteLine('Removes this one row from the `items` table. It cannot be undone from this '
            + 'panel — recreating it means re-entering every column by hand.', true));
        d.appendChild(noteLine('Copies players already own are NOT removed. Their stacks stay in the '
            + 'inventory tables pointing at a row that no longer exists, and load back with no name or label. '
            + 'Take the item off people first if you care about that.', true));
        d.appendChild(noteLine('Anything that references this name — shops, crafting recipes, jobs, reward '
            + 'tables — will stop working and may spam the server console. Search the name in your resources '
            + 'before deleting it.', true));
        d.appendChild(noteLine('If you only want it out of circulation, editing is safer: set usable to false, '
            + 'or pull it from the shop that sells it. The row can sit in the table doing no harm.'));
        d.appendChild(noteLine('Takes effect in-game after "restart vorp_inventory".'));

        const df = el('div', 'action-form');
        const confirm = el('input');
        confirm.placeholder = 'type ' + r.item + ' to confirm';
        confirm.style.width = '14vw';
        const del = el('button', 'abtn warn', 'Delete Item');
        const dnote = el('span', 'offline-note', 'Type the item name exactly to unlock this.');
        dnote.style.maxWidth = '24vw';
        del.addEventListener('click', () => {
            if (confirm.value.trim() !== r.item) {
                dnote.textContent = 'Type "' + r.item + '" exactly — nothing was deleted.';
                return;
            }
            dnote.textContent = 'Deleting "' + r.item + '"...';
            post('panelItemsUpdate', { item: r.item, delete: true });
            post('panelItemsSearch', { term: '' });
        });
        df.appendChild(confirm); df.appendChild(del); df.appendChild(dnote);
        d.appendChild(df);
        body.appendChild(d);
    };

    /* ------------------------------------------------------------- live map
       Leaflet (html/vendor) over kibook/webmap's rdr3 map.jpg (7200x5400 = zoom 5), loaded from its public
       GitHub URL. The image is not shipped with this resource (no licence); if it cannot load, the map
       is plain parchment and every pin, filter and teleport still works.
       World -> image pixel is kibook/webmap's rdr3 transform for that image:
           px = (x + 16000 - 8515) / 11820 * 7200
           py = 5400 - (y + 16000 - 10850) / 8660 * 5400
       CRS.Simple: latlng = unproject(px, py) at zoom 5, so markers land exactly where the old canvas put them. */
    const WM = { radius: 16000, xOff: 8515, yOff: 10850, w: 11820, h: 8660 };
    const IMG_W = 7200, IMG_H = 5400, TILE_MAX_Z = 5;
    const MAP_IMAGE_URL = 'https://raw.githubusercontent.com/kibook/webmap/master/http/rdr3/map.jpg';
    const worldToPx = (x, y) => [
        (x + WM.radius - WM.xOff) / WM.w * IMG_W,
        IMG_H - (y + WM.radius - WM.yOff) / WM.h * IMG_H,
    ];
    const pxToWorld = (px, py) => [
        px / IMG_W * WM.w - WM.radius + WM.xOff,
        (IMG_H - py) / IMG_H * WM.h - WM.radius + WM.yOff,
    ];

    /* pup: MAP BLIP GLYPHS - inline SVG, 24x24 viewBox, currentColor so the badge colour drives the glyph. */
    const MAP_ICON = {
        house: '<svg viewBox="0 0 24 24"><path d="M12 3 2 11h3v9h5v-6h4v6h5v-9h3L12 3z"/></svg>',
        clan: '<svg viewBox="0 0 24 24"><path d="M12 3 2 20h8l2-4 2 4h8L12 3zm0 5.5L15.5 18h-7L12 8.5z"/></svg>',
        hideout: '<svg viewBox="0 0 24 24"><path d="M12 2a6 6 0 0 0-3 11.2V20l3 2 3-2v-6.8A6 6 0 0 0 12 2zm0 3a3 3 0 1 1 0 6 3 3 0 0 1 0-6z"/></svg>',
        door: '<svg viewBox="0 0 24 24"><path d="M5 2h14v20H5V2zm2 2v16h10V4H7zm8 7a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 0 1 0-2.4z"/></svg>',
        shop: '<svg viewBox="0 0 24 24"><path d="M3 3h18l1 5a3 3 0 0 1-5 2 3 3 0 0 1-5 0 3 3 0 0 1-5 0 3 3 0 0 1-5-2l1-5zm1 9.7A4.8 4.8 0 0 0 7 12a4.8 4.8 0 0 0 10 0 4.8 4.8 0 0 0 3 .7V21H4v-8.3zM9 15h6v6H9v-6z"/></svg>',
        socshop: '<svg viewBox="0 0 24 24"><path d="M12 2 2 7v2h20V7L12 2zM4 11h2v7H4v-7zm5 0h2v7H9v-7zm4 0h2v7h-2v-7zm5 0h2v7h-2v-7zM2 20h20v2H2v-2z"/></svg>',
        ranch: '<svg viewBox="0 0 24 24"><path d="M12 2 2 7v15h20V7L12 2zm0 2.4 8 4V20h-4v-6H8v6H4V8.4l8-4zM10 16h4v4h-4v-4z"/></svg>',
    };

    /* Guarma is off the bottom of the map image, so anyone there goes to the side list rather than off-canvas. */
    const GUARMA = { minX: 600, maxX: 2200, minY: -7600, maxY: -6000 };
    const inGuarma = (x, y) =>
        x >= GUARMA.minX && x <= GUARMA.maxX && y >= GUARMA.minY && y <= GUARMA.maxY;

    let leafMap = null;
    let mapFitted = false;
    let mapBounds = null;
    const mapGroups = {};          // filter key -> L.layerGroup
    const playerMarkers = new Map(); // server id -> { marker, p }
    let lastMapData = null;        // last players payload
    let lastLayers = null;         // last property payload
    let layersAt = 0;              // when the property layers were last fetched
    let followId = null;           // server id the view stays centred on
    let mapMe = null;              // my own server id (from the payload)

    const mapFilters = {
        players: true, staff: true,
        houses: false, hideouts: false, clans: false, doors: false,
        shops: false, socshops: false, ranches: false,
    };
    const PROPERTY_KEYS = ['houses', 'hideouts', 'clans', 'doors', 'shops', 'socshops', 'ranches'];

    const toLatLng = (x, y) => {
        const [px, py] = worldToPx(x, y);
        return leafMap.unproject([px, py], TILE_MAX_Z);
    };
    const fromLatLng = (ll) => {
        const pt = leafMap.project(ll, TILE_MAX_Z);
        return pxToWorld(pt.x, pt.y);
    };

    const escHtml = (s) => String(s == null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

    const requestLayers = (force) => {
        if (!force && lastLayers && Date.now() - layersAt < 60000) return;
        post('panelMapLayers');
    };

    const setFollow = (p) => {
        followId = p ? p.id : null;
        const box = $('#mapFollow');
        if (!box) return;
        box.classList.toggle('hidden', !followId);
        if (p) box.querySelector('b').textContent = p.name;
        if (p && leafMap) leafMap.flyTo(toLatLng(p.x, p.y), Math.max(leafMap.getZoom(), 4), { duration: .6 });
    };

    const playerPopup = (p) => {
        const wrap = el('div', 'mpop');
        const head = el('div', 'mpop-head');
        head.appendChild(el('b', null, p.name));
        head.appendChild(el('span', 'mpop-id', '#' + p.id + (p.staff ? ' • staff' : '')));
        wrap.appendChild(head);
        wrap.appendChild(el('div', 'mpop-sub', (p.job ? p.job + ' • ' : '') + 'x ' + p.x + ', y ' + p.y));
        const row = el('div', 'mpop-btns');
        const btn = (label, fn, cls) => {
            const b = el('button', 'abtn' + (cls ? ' ' + cls : ''), label);
            b.addEventListener('click', (ev) => { ev.stopPropagation(); fn(); });
            row.appendChild(b);
        };
        /* seeing the map is live_map; acting on a pin needs the key for that act,
           so a map-only role is not shown buttons the server will refuse */
        if (p.charid) btn('Profile', () => openDetail(Number(p.charid)));
        if (hasPerm('tp_to_player')) btn('Go to', () => post('panelAction', { action: 'goto', target: p.id, name: p.name }));
        if (hasPerm('bring_player')) btn('Bring', () => post('panelAction', { action: 'bring', target: p.id, name: p.name }));
        if (hasPerm('spectate')) btn('Spectate', () => post('panelAction', { action: 'spectate', target: p.id, name: p.name }));
        btn(followId === p.id ? 'Unfollow' : 'Follow', () => { setFollow(followId === p.id ? null : p); leafMap.closePopup(); });
        wrap.appendChild(row);
        return wrap;
    };

    const playerIcon = (p) => L.divIcon({
        className: 'pm-wrap',
        iconSize: [22, 22], iconAnchor: [11, 11], popupAnchor: [0, -12],
        html: `<div class="pm${p.staff ? ' staff' : ''}${p.id === mapMe ? ' me' : ''}" style="--h:${-(Number(p.h) || 0)}deg">`
            + '<i class="pm-arrow"></i><span class="pm-name">' + escHtml(p.name) + '</span></div>',
    });

    /* REAL BLIP SPRITES. A game blip is a texture inside the game's own dictionary,
       addressed by hash - there is no URL a web page can point at. So: cut the
       sprite to a PNG and drop it at html/img/blips/<key>.png (see the README
       there for the hash each layer uses) and it is drawn instead of the glyph.
       No file, no problem - onerror hides the image and shows the glyph behind it. */
    const blipArt = (key, svg) => {
        if (!key) return svg;
        return '<img class="pm-blip" src="img/blips/' + key + '.png" alt="" '
            + 'onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'\'">'
            + '<span class="pm-glyph" style="display:none">' + svg + '</span>';
    };

    const propIcon = (cls, svg, key) => L.divIcon({
        className: 'pm-wrap',
        iconSize: [22, 22], iconAnchor: [11, 11], tooltipAnchor: [0, -12],
        html: '<div class="pm-prop ' + cls + '">' + blipArt(key, svg) + '</div>',
    });

    const buildMapBase = () => {
        if (leafMap) return;
        const node = $('#leafMap');
        if (!node || typeof L === 'undefined') return;
        leafMap = L.map(node, {
            crs: L.CRS.Simple,
            minZoom: 1, maxZoom: 7, zoomSnap: 0.25, zoomDelta: 0.5, wheelPxPerZoomLevel: 90,
            zoomControl: false, attributionControl: false, doubleClickZoom: true,
            inertia: true,
        });
        const sw = leafMap.unproject([0, IMG_H], TILE_MAX_Z);
        const ne = leafMap.unproject([IMG_W, 0], TILE_MAX_Z);
        mapBounds = L.latLngBounds(sw, ne);
        L.imageOverlay(MAP_IMAGE_URL, mapBounds, { interactive: false })
            .on('error', () => console.warn('[vorp_admin] map image did not load; showing plain parchment'))
            .addTo(leafMap);
        leafMap.setMaxBounds(mapBounds.pad(0.15));

        // property layers under the players, players on top
        for (const k of PROPERTY_KEYS) mapGroups[k] = L.layerGroup();
        mapGroups.players = L.layerGroup();
        mapGroups.staff = L.layerGroup();
        for (const k of Object.keys(mapFilters)) if (mapFilters[k]) mapGroups[k].addTo(leafMap);

        // names only when zoomed in enough to read them; the tag wins over the dot again at zoom 3.5+
        const syncNames = () => node.classList.toggle('show-names', leafMap.getZoom() >= 3.5);
        leafMap.on('zoomend', syncNames);
        leafMap.on('zoomstart', () => node.classList.add('no-anim'));
        leafMap.on('zoomend', () => node.classList.remove('no-anim'));
        syncNames();

        // cursor readout in world units
        leafMap.on('mousemove', (e) => {
            const [wx, wy] = fromLatLng(e.latlng);
            const c = $('#mapCoords');
            if (c) c.textContent = 'x ' + Math.round(wx) + '   y ' + Math.round(wy);
        });

        // right-click: teleport to that spot
        leafMap.on('contextmenu', (e) => {
            const [wx, wy] = fromLatLng(e.latlng);
            const x = Math.round(wx), y = Math.round(wy);
            const wrap = el('div', 'mpop');
            wrap.appendChild(el('div', 'mpop-sub', 'x ' + x + ', y ' + y));
            const row = el('div', 'mpop-btns');
            const tp = el('button', 'abtn', 'Teleport here');
            tp.addEventListener('click', () => { leafMap.closePopup(); post('panelMapTeleport', { x, y }); });
            const cp = el('button', 'abtn', 'Copy coords');
            cp.addEventListener('click', () => {
                const ta = document.createElement('textarea');
                ta.value = x + ', ' + y; document.body.appendChild(ta); ta.select();
                try { document.execCommand('copy'); } catch (err) { /* clipboard blocked */ }
                ta.remove(); leafMap.closePopup();
            });
            row.appendChild(tp); row.appendChild(cp);
            wrap.appendChild(row);
            L.popup({ closeButton: false, className: 'mpop-popup' }).setLatLng(e.latlng).setContent(wrap).openOn(leafMap);
        });

        $('#zoomIn').addEventListener('click', () => leafMap.zoomIn());
        $('#zoomOut').addEventListener('click', () => leafMap.zoomOut());
        $('#zoomReset').addEventListener('click', () => { setFollow(null); centerMap(); });
        const unf = $('#mapUnfollow');
        if (unf) unf.addEventListener('click', () => setFollow(null));
        // a manual drag ends follow mode; the admin clearly wants to look elsewhere
        leafMap.on('dragstart', () => { if (followId) setFollow(null); });

        document.querySelectorAll('.map-filters .mf').forEach(b => {
            const key = b.dataset.f;
            const dot = b.querySelector('.dot');
            if (dot && MAP_ICON[key.replace(/s$/, '')]) {
                dot.innerHTML = MAP_ICON[key.replace(/s$/, '')];
                dot.classList.add('has-ico');
            } else if (dot && key === 'socshops') {
                dot.innerHTML = MAP_ICON.socshop; dot.classList.add('has-ico');
            }
            b.addEventListener('click', () => {
                mapFilters[key] = !mapFilters[key];
                b.classList.toggle('on', mapFilters[key]);
                if (mapFilters[key]) mapGroups[key].addTo(leafMap); else mapGroups[key].remove();
                if (PROPERTY_KEYS.includes(key) && mapFilters[key]) requestLayers(false);
                if (lastMapData) renderMap(lastMapData);
            });
        });

        const search = $('#mapSearch');
        if (search) search.addEventListener('input', () => { if (lastMapData) renderMapList(lastMapData); });
    };

    const centerMap = () => {
        if (!leafMap || !mapBounds) return;
        leafMap.invalidateSize();
        leafMap.fitBounds(mapBounds, { padding: [10, 10] });
    };

    // the map page was hidden (display:none) when Leaflet measured itself; fix it up the moment it is visible
    const onMapPageShown = () => {
        if (!leafMap) buildMapBase();
        if (!leafMap) return;
        setTimeout(() => {
            leafMap.invalidateSize();
            if (!mapFitted) { centerMap(); mapFitted = true; }
        }, 60);
        requestLayers(false);
    };

    const focusPlayer = (p) => {
        if (!leafMap) return;
        leafMap.flyTo(toLatLng(p.x, p.y), Math.max(leafMap.getZoom(), 4.5), { duration: .7 });
        const rec = playerMarkers.get(p.id);
        if (rec) setTimeout(() => rec.marker.openPopup(), 750);
    };

    const renderMapList = (data) => {
        const list = $('#mapList');
        if (!list) return;
        const searchEl = $('#mapSearch');
        const q = ((searchEl && searchEl.value) || '').trim().toLowerCase();
        list.textContent = '';
        const players = (data.players || []).slice().sort((a, b) =>
            (b.staff ? 1 : 0) - (a.staff ? 1 : 0) || String(a.name).localeCompare(String(b.name)));
        let shown = 0;
        players.forEach(p => {
            const hay = (p.name + ' ' + p.id + ' ' + (p.job || '')).toLowerCase();
            if (q && !hay.includes(q)) return;
            shown++;
            const row = el('div', 'ms-row' + (p.staff ? ' staff' : '') + (p.id === followId ? ' following' : ''));
            const dot = el('i', 'dot ' + (p.staff ? 'staff' : 'player'));
            row.appendChild(dot);
            const txt = el('div', 'ms-txt');
            txt.appendChild(el('div', 'ms-name', p.name));
            txt.appendChild(el('div', 'ms-sub', '#' + p.id + (p.job ? ' • ' + p.job : '') + (inGuarma(p.x, p.y) ? ' • Guarma' : '')));
            row.appendChild(txt);
            row.addEventListener('click', () => { if (!inGuarma(p.x, p.y)) focusPlayer(p); });
            const hot = (on) => {
                const r = playerMarkers.get(p.id);
                const node = r && r.marker.getElement();
                if (node) node.classList.toggle('hot', on);
            };
            row.addEventListener('mouseenter', () => hot(true));
            row.addEventListener('mouseleave', () => hot(false));
            list.appendChild(row);
        });
        if (!shown) list.appendChild(el('div', 'ms-empty', q ? 'No player matches "' + q + '"' : 'Nobody online'));
        const online = $('#mapOnline');
        if (online) online.textContent = String((data.players || []).length);
    };

    const setCount = (key, n) => {
        const b = document.querySelector('.map-filters .mf[data-f="' + key + '"] .n');
        if (b) b.textContent = n ? String(n) : '';
    };

    const renderMap = (data) => {
        if (!data) return;
        lastMapData = data;
        if (data.me != null) mapMe = data.me;
        if (!leafMap) buildMapBase();
        if (!leafMap) return;

        const seen = new Set();
        let staffN = 0, playerN = 0, guarmaN = 0;
        const gl = $('#guarmaList');
        if (gl) gl.textContent = '';

        (data.players || []).forEach(p => {
            if (p.staff) staffN++; else playerN++;
            if (inGuarma(p.x, p.y)) {
                guarmaN++;
                if (gl) gl.appendChild(el('div', 'ms-sub', p.name + ' (#' + p.id + ')'));
                return;
            }
            seen.add(p.id);
            const ll = toLatLng(p.x, p.y);
            const group = p.staff ? mapGroups.staff : mapGroups.players;
            let rec = playerMarkers.get(p.id);
            if (!rec) {
                const marker = L.marker(ll, { icon: playerIcon(p), zIndexOffset: p.staff ? 1000 : 500, keyboard: false });
                marker.bindPopup(() => playerPopup(p), { closeButton: false, className: 'mpop-popup', minWidth: 220 });
                rec = { marker, p, group };
                playerMarkers.set(p.id, rec);
                marker.addTo(group);
            } else {
                rec.marker.setLatLng(ll);
                // re-render the icon only when something on it changed (name, staff flag, heading)
                if (rec.p.name !== p.name || rec.p.staff !== p.staff || rec.p.h !== p.h) rec.marker.setIcon(playerIcon(p));
                if (rec.group !== group) { rec.group.removeLayer(rec.marker); rec.group = group; rec.marker.addTo(group); }
                rec.p = p;
            }
        });
        for (const [id, rec] of playerMarkers) {
            if (!seen.has(id)) { rec.group.removeLayer(rec.marker); playerMarkers.delete(id); if (followId === id) setFollow(null); }
        }
        setCount('players', playerN); setCount('staff', staffN);

        const gb = $('#guarmaBox');
        if (gb) { gb.classList.toggle('hidden', guarmaN === 0); const c = $('#guarmaCount'); if (c) c.textContent = String(guarmaN); }

        if (followId) {
            const rec = playerMarkers.get(followId);
            if (rec) leafMap.panTo(rec.marker.getLatLng(), { animate: true, duration: 1.0 });
        }
        renderMapList(data);
    };

    const renderMapLayers = (data) => {
        if (!data) return;
        lastLayers = data; layersAt = Date.now();
        if (!leafMap) buildMapBase();
        if (!leafMap) return;

        const ownerTip = (o) => o.ownerCharid
            ? ('owner: ' + (o.ownerName || '?') + ' (char ' + o.ownerCharid + ')')
            : null;
        const money = (n) => '$' + Number(n || 0).toLocaleString();

        const fill = (key, list, cls, svg, mainOf, subOf, clickOf) => {
            const g = mapGroups[key];
            g.clearLayers();
            (list || []).forEach(o => {
                if (inGuarma(o.x, o.y)) return;
                const m = L.marker(toLatLng(o.x, o.y), { icon: propIcon(cls(o), svg, key), keyboard: false, zIndexOffset: 100 });
                const sub = subOf(o);
                m.bindTooltip('<b>' + escHtml(mainOf(o)) + '</b>' + (sub ? '<br><small>' + escHtml(sub) + '</small>' : ''),
                    { direction: 'top', className: 'mtip', opacity: 1 });
                const cid = clickOf ? clickOf(o) : null;
                if (cid) m.on('click', () => openDetail(cid));
                m.addTo(g);
            });
            setCount(key, (list || []).length);
        };

        fill('doors', data.doors, () => 'door', MAP_ICON.door, d => 'Door', d => String(d.id), null);
        fill('houses', data.houses, h => 'house' + (h.owned ? '' : ' unowned'), MAP_ICON.house,
            h => 'House #' + h.id, h => h.owned ? ownerTip(h) : 'for sale', h => h.ownerCharid || null);
        fill('hideouts', data.hideouts, () => 'hideout', MAP_ICON.hideout,
            h => 'Hideout #' + h.id, h => ownerTip(h) || 'unowned', h => h.ownerCharid || null);
        fill('clans', data.clans, () => 'clan', MAP_ICON.clan,
            c => c.name, c => (c.ownerCharid ? 'leader: ' + (c.ownerName || '?') + ' • ' : '') + c.members + ' members', c => c.ownerCharid || null);
        fill('shops', data.shops, s => 'shop' + (s.owned ? '' : ' unowned'), MAP_ICON.shop,
            s => s.name, s => s.repoed ? 'repossessed - for sale' : (s.owned ? ownerTip(s) + ' • ledger ' + money(s.ledger) : 'for sale'), s => s.ownerCharid || null);
        fill('socshops', data.socshops, () => 'socshop', MAP_ICON.socshop,
            s => s.name, s => (s.society || '?') + ' • rank ' + s.rank + '+', null);
        fill('ranches', data.ranches, r => 'ranch' + (r.owned ? '' : ' unowned'), MAP_ICON.ranch,
            r => r.name, r => r.repoed ? 'repossessed - for sale' : (r.owned ? ownerTip(r) + ' • ledger ' + money(r.ledger) : 'for sale'), r => r.ownerCharid || null);
    };

    /* Hide every nav row this admin does not hold the permission for, and the
       group heading above it once the whole group is gone. If the page they are
       standing on just disappeared, fall back to the dashboard - which is the
       one page open_menu alone always earns. */
    function applyNavPermissions() {
        document.querySelectorAll('.nav-item[data-perm]').forEach((btn) => {
            btn.hidden = !hasPerm(btn.dataset.perm);
        });

        document.querySelectorAll('.nav-group').forEach((head) => {
            const nav = head.nextElementSibling;
            if (!nav || !nav.classList.contains('nav')) return;
            const anyLeft = [...nav.querySelectorAll('.nav-item')].some(b => !b.hidden);
            head.hidden = !anyLeft;
            nav.hidden = !anyLeft;
        });

        const active = document.querySelector('.nav-item.active');
        if (active && active.hidden) {
            const first = document.querySelector('.nav-item:not([hidden])');
            if (first) first.click();
        }
    }

    /* ------------------------------------------------------------- lifecycle */
    const openPanel = (data) => {
        open = true;
        myPerms = data.perms || null;
        applyNavPermissions();
        $('#panel').classList.remove('hidden');
        $('#serverName').textContent = data.serverName || 'ADMIN';
        const meName = data.charName || 'Admin';
        document.querySelector('.me-name').textContent = meName;
        $('#meGroup').textContent = data.group || 'admin';
        $('#meAvatar').textContent = initials(meName);
        onlineHistory = [];
        buildMapBase();
        mapFitted = false; // the map page is hidden right now; it fits itself the first time it is shown
        buildTools();
        buildTeleports();
        buildBans();
        showPage('dashboard');
        renderStats(data.stats, null);
        post('panelStats');
        clearInterval(statsTimer);
        statsTimer = setInterval(() => { if (page === 'dashboard') post('panelStats'); }, 5000);
    };

    const closePanel = () => {
        open = false;
        $('#panel').classList.add('hidden');
        clearInterval(statsTimer); statsTimer = null;
        clearInterval(mapTimer); mapTimer = null;
        setFollow(null);
    };

    /* PERKS -----------------------------------------------------------------
       Oversight for pup-perks. Points are the lever: they are what a player
       spends to rank a perk up, so granting them is granting capability, not
       just a number. Every mutation here works on offline characters too -
       an online one is updated live and their open panel repaints itself.
       ---------------------------------------------------------------------- */
    let perkView = null;    /* charid of the open detail, or null for the list */
    let perkData = null;

    const perkSearchEl = $('#perkSearch');
    if (perkSearchEl) {
        let perkTimer = null;
        perkSearchEl.addEventListener('input', () => {
            clearTimeout(perkTimer);
            /* debounced: this one hits the database, unlike the client-side
               filters elsewhere in the panel */
            perkTimer = setTimeout(() => {
                perkView = null;
                post('panelPerks', { search: perkSearchEl.value.trim() });
            }, 250);
        });
    }

    const perkAct = (payload) => post('panelPerkAction', payload);

    const renderPerkDetail = (d) => {
        const body = $('#perksBody');
        body.innerHTML = '';

        const back = el('button', 'abtn', '← All characters');
        back.addEventListener('click', () => { perkView = null; renderPerks(perkData); });
        body.appendChild(back);

        const cards = el('div', 'cards small');
        cards.appendChild(card('Character', d.online ? 'online' : 'offline',
            valueNode(d.name || ('char ' + d.charid)), '♟'));
        cards.appendChild(card('Equipped', d.slots + ' slots unlocked',
            valueNode(d.equipped + ' / ' + d.slots), '⚒'));
        cards.appendChild(card('Total experience', 'both sides', valueNode(fmt(d.xp)), '◴'));
        body.appendChild(cards);

        /* the two sides never mix, so they get a row each */
        [d.civ, d.crime].forEach((s) => {
            if (!s) return;
            const row = el('div', 'cards small');
            row.appendChild(card(s.label, 'level', valueNode(String(s.level) + ' / ' + d.maxLevel), '★'));
            row.appendChild(card('Specialisation', s.tree ? 'committed' : 'not chosen',
                valueNode(s.treeLabel || '—'), '❖'));
            row.appendChild(card('Points', s.spent + ' spent', valueNode(String(s.points)), '♠'));
            row.appendChild(card('Experience',
                s.bonus ? ((s.bonus > 0 ? '+' : '') + s.bonus + ' admin points') : '',
                valueNode(fmt(s.xp)), '◴'));
            body.appendChild(row);
        });

        /* ---- points ---- */
        const pAct = el('div', 'card actions-card');
        pAct.appendChild(el('div', 'actions-title',
            'Adjust perk points — each side has its own pool and they cannot cross'));
        const pGrid = el('div', 'action-form');
        const pAmt = el('input', 'narrow'); pAmt.value = '1';
        pGrid.appendChild(pAmt);
        [['+ ' + (d.civ ? d.civ.label : 'Honest Work'), 'civ', 1],
         ['+ ' + (d.crime ? d.crime.label : 'Outlaw'), 'crime', 1],
         ['- ' + (d.civ ? d.civ.label : 'Honest Work'), 'civ', -1],
         ['- ' + (d.crime ? d.crime.label : 'Outlaw'), 'crime', -1]].forEach(([label, track, sign]) => {
            const b = el('button', 'abtn', label);
            b.addEventListener('click', () => {
                const n = parseInt(pAmt.value, 10);
                if (!isNaN(n) && n > 0) {
                    perkAct({ action: 'points', charid: d.charid, track: track, value: n * sign });
                }
            });
            pGrid.appendChild(b);
        });
        pAct.appendChild(pGrid);
        pAct.appendChild(el('div', 'card-sub',
            'Taking points stops at zero unspent on that side — it will not claw back points already spent on perks. Use Reset for that.'));
        body.appendChild(pAct);

        /* ---- experience ---- */
        const xAct = el('div', 'card actions-card');
        xAct.appendChild(el('div', 'actions-title',
            'Grant experience — levels earned this way pay their perk points normally'));
        const xGrid = el('div', 'action-form');
        const xAmt = el('input', 'narrow'); xAmt.value = '500';
        xGrid.appendChild(xAmt);
        [['+ Honest work', 'civ', 1], ['+ Outlaw', 'crime', 1],
         ['- Honest work', 'civ', -1], ['- Outlaw', 'crime', -1]].forEach(([label, track, sign]) => {
            const b = el('button', 'abtn', label);
            b.addEventListener('click', () => {
                const n = parseInt(xAmt.value, 10);
                if (!isNaN(n) && n > 0) {
                    perkAct({ action: 'xp', charid: d.charid, track: track, value: n * sign });
                }
            });
            xGrid.appendChild(b);
        });
        xAct.appendChild(xGrid);
        body.appendChild(xAct);

        /* ---- reset ---- */
        const rAct = el('div', 'card actions-card');
        rAct.appendChild(el('div', 'actions-title', 'Reset'));
        const rGrid = el('div', 'action-form');
        const rst = el('button', 'abtn warn', 'Wipe all progress');
        rst.addEventListener('click', () => {
            const cx = (d.civ && d.civ.xp) || 0;
            const rx = (d.crime && d.crime.xp) || 0;
            askConfirm({
                title: 'Wipe every perk and all experience?',
                body: '<b>' + (d.name || ('char ' + d.charid)) + '</b> goes back to a brand-new character: '
                    + '<b>' + fmt(cx) + ' honest</b> and <b>' + fmt(rx) + ' outlaw</b> experience erased, '
                    + 'both levels back to 1, every point and rank gone, nothing equipped and both '
                    + 'specialisations released. <b>Nothing is refunded and this cannot be undone.</b>',
                okLabel: 'Wipe progress',
                onOk: () => perkAct({ action: 'reset', charid: d.charid }),
            });
        });
        rGrid.appendChild(rst);
        rAct.appendChild(rGrid);
        rAct.appendChild(el('div', 'card-sub',
            'A full wipe, not a respec. To let them re-pick perks while keeping their levels, take points instead.'));
        body.appendChild(rAct);

        /* ---- owned perks ---- */
        body.appendChild(el('div', 'actions-title', 'Unlocked perks (' + (d.perks || []).length + ')'));
        if (!(d.perks || []).length) {
            body.appendChild(el('div', 'empty', 'This character has not unlocked any perks yet.'));
            return;
        }
        const head = el('div', 'table-head');
        head.style.gridTemplateColumns = '2fr 1.2fr 1fr 1fr 1fr';
        ['Perk', 'Category', 'Rank', 'Points in', 'Equipped'].forEach(t => head.appendChild(el('div', null, t)));
        body.appendChild(head);

        const rows = el('div', 'rows');
        (d.perks || []).forEach(p => {
            const row = el('div', 'prow');
            row.style.gridTemplateColumns = '2fr 1.2fr 1fr 1fr 1fr';
            const nw = el('div', 'pname');
            const nn = el('div');
            nn.appendChild(el('div', 'n', p.name));
            nn.appendChild(el('div', 's', p.id));
            nw.appendChild(nn);
            row.appendChild(nw);
            row.appendChild(el('div', null, p.cat || '-'));
            row.appendChild(el('div', null, p.rank + ' / ' + p.maxRank));
            row.appendChild(el('div', null, String(p.spent)));
            const ew = el('div');
            if (p.equipped) ew.appendChild(el('span', 'chip', 'equipped'));
            row.appendChild(ew);
            rows.appendChild(row);
        });
        body.appendChild(rows);
    };

    const renderPerks = (d) => {
        const body = $('#perksBody');
        if (!body) return;

        if (d === false || !d) {
            body.innerHTML = '';
            body.appendChild(el('div', 'empty', 'Unable to load perks — no permission, or pup-perks is not running.'));
            return;
        }
        if (d.missing) {
            body.innerHTML = '';
            body.appendChild(el('div', 'empty', 'pup-perks is not started.'));
            return;
        }

        perkData = d;
        if (perkView) return;   /* a detail view is open; the list waits its turn */

        const list = d.list || [];
        body.innerHTML = '';

        if (!list.length) {
            body.appendChild(el('div', 'empty',
                perkSearchEl && perkSearchEl.value.trim()
                    ? 'No character matches that search.'
                    : 'No character has earned any progression yet.'));
            return;
        }

        const cards = el('div', 'cards small');
        cards.appendChild(card('Characters', 'with progression', valueNode(fmt(list.length)), '♟'));
        cards.appendChild(card('Online', '', valueNode(fmt(list.filter(p => p.online).length)), '●'));
        cards.appendChild(card('Highest level', 'either side',
            valueNode(String(list.reduce((m, p) => Math.max(m, p.civLevel, p.crimeLevel), 0))), '★'));
        cards.appendChild(card('Unspent points', 'both pools, across the list',
            valueNode(fmt(list.reduce((s, p) => s + p.civPoints + p.crimePoints, 0))), '♠'));
        body.appendChild(cards);

        const COLS = '1.8fr 1.5fr 1.5fr 0.8fr 1fr';
        const head = el('div', 'table-head');
        head.style.gridTemplateColumns = COLS;
        ['Character', 'Honest Work', 'Outlaw', 'Perks', 'Character ID']
            .forEach(t => head.appendChild(el('div', null, t)));
        body.appendChild(head);

        /* one cell per side: level, specialisation and unspent points together,
           because those three only ever make sense read as a set */
        const sideCell = (level, tree, points) => {
            const w = el('div');
            w.appendChild(el('div', 'n', 'L' + level + ' · ' + points + ' pts'));
            w.appendChild(el('div', 's', tree || 'no specialisation'));
            return w;
        };

        const rows = el('div');
        body.appendChild(rows);
        pagedList(rows, list, null, p => {
            const row = el('div', 'prow');
            row.style.gridTemplateColumns = COLS;
            row.style.cursor = 'pointer';

            const nw = el('div', 'pname');
            const nn = el('div');
            nn.appendChild(el('div', 'n', p.name || ('char ' + p.charid)));
            nn.appendChild(el('div', 's', p.online ? 'online' : 'offline'));
            nw.appendChild(nn);
            row.appendChild(nw);

            row.appendChild(sideCell(p.civLevel, p.civTree, p.civPoints));
            row.appendChild(sideCell(p.crimeLevel, p.crimeTree, p.crimePoints));
            row.appendChild(el('div', null, String(p.owned)));

            const cw = el('div');
            cw.appendChild(el('span', 'chip', String(p.charid)));
            row.appendChild(cw);

            row.addEventListener('click', () => {
                perkView = p.charid;
                post('panelPerkDetail', { charid: p.charid });
            });
            return row;
        }, { noSearch: true }); // #perkSearch already queries the server
    };


    /* pup: the panel is FULLSCREEN, so every Core.NotifyRightTip the server sends
       about a panel action is drawn behind it and never seen, and a failure looks
       exactly like "nothing happened". Results surface here instead. */
    let toastTimer = null;
    const showPanelToast = (d) => {
        if (!d || !d.text) return;
        let box = document.getElementById('panelToast');
        if (!box) {
            box = el('div');
            box.id = 'panelToast';
            document.body.appendChild(box);
        }
        box.textContent = d.text;
        box.className = d.error ? 'ptoast err show' : 'ptoast show';
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => { box.className = box.className.replace(' show', ''); }, 5000);
    };

    /* ===================================================================
       EVENTS (pup-events)
       =================================================================== */
    function renderEvents(d) {
        const body = $('#eventsBody');
        body.innerHTML = '';

        if (!d) {
            body.appendChild(el('div', 'empty', 'No access (needs the manage_events permission)'));
            return;
        }
        if (d.down) {
            body.appendChild(el('div', 'empty', 'pup-events is not running. Start the resource, then reopen this page.'));
            return;
        }

        const act = (payload) => post('panelEventsAction', payload);
        const liveCount = (d.events || []).filter(e => e.live).length;
        const hourTxt = (d.hour === null || d.hour === undefined)
            ? '—' : String(d.hour).padStart(2, '0') + ':00';

        /* top cards */
        const cards = el('div', 'cards small');
        cards.appendChild(card('In-game clock', 'what pup-events reads', valueNode(hourTxt), '◷'));
        cards.appendChild(card('Today', 'real date used for windows', valueNode(d.today || '—'), '▤'));
        cards.appendChild(card('Running', 'events live right now', valueNode(String(liveCount)), '◉'));
        cards.appendChild(card('Blood moon',
            d.bloodMoon === null ? 'pup-bloodmoon not reachable' : 'pup-bloodmoon state',
            valueNode(d.bloodMoon === null ? '—' : (d.bloodMoon ? 'UP' : 'DOWN')), '☾'));
        body.appendChild(cards);

        /* clock jumper: the quickest way to reach a night window */
        const clock = el('div', 'card info-card');
        clock.appendChild(el('div', 'icard-title', 'Set the in-game hour'));
        clock.appendChild(el('div', 'offline-note',
            'Moves the clock for every player on the server. Use it to drop straight into an event window instead of waiting for night.'));
        const row = el('div', 'actions-grid');
        [0, 2, 4, 6, 12, 20, 22].forEach(h => {
            const b = el('button', 'abtn', String(h).padStart(2, '0') + ':00');
            b.addEventListener('click', () => act({ action: 'hour', hour: h }));
            row.appendChild(b);
        });
        clock.appendChild(row);
        body.appendChild(clock);

        /* one card per event */
        const hh = (n) => String(n).padStart(2, '0') + ':00';
        const mark = (ok, yes, no) => {
            const s = el('span', ok ? 'ev-ok' : 'ev-bad', (ok ? '✓ ' : '✗ ') + (ok ? yes : no));
            return s;
        };

        (d.events || []).forEach(e => {
            const c = el('div', 'card');

            /* name, then state and override as pills rather than a run-on title */
            const head = el('div', 'ev-head');
            head.appendChild(el('div', 'ev-name', e.label));
            head.appendChild(el('span', 'ev-pill ' + (e.live ? 'live' : 'off'), e.live ? 'live' : 'off'));
            if (e.forced === true)       head.appendChild(el('span', 'ev-pill forced', 'forced on'));
            else if (e.forced === false) head.appendChild(el('span', 'ev-pill forced', 'forced off'));
            else                         head.appendChild(el('span', 'ev-pill', 'on schedule'));
            if (!e.enabled)  head.appendChild(el('span', 'ev-pill', 'disabled in config'));
            if (e.bloodMoon) head.appendChild(el('span', 'ev-pill', 'blood moon'));
            c.appendChild(head);

            const meta = el('div', 'ev-meta');
            const dates = el('div');
            if (e.dated) {
                dates.appendChild(document.createTextNode((e.from || '…') + '  to  ' + (e.to || '…') + '   '));
                dates.appendChild(mark(e.inDate, 'today is inside', 'today is outside'));
            } else {
                dates.appendChild(el('span', 'ev-bad', 'No dates set, it will never start itself'));
            }
            meta.appendChild(dates);

            const hours = el('div');
            hours.appendChild(document.createTextNode(hh(e.hourFrom) + '  to  ' + hh(e.hourTo) + '   '));
            hours.appendChild(mark(e.inHour, 'in the hour window', 'outside the hour window'));
            meta.appendChild(hours);
            c.appendChild(meta);

            /* the window editor: dates live in the database, not a config file */
            const form = el('div', 'ev-form');
            const field = (label, val, opts) => {
                opts = opts || {};
                const w = el('div', 'ev-field');
                w.appendChild(el('span', null, label));
                const i = el('input', opts.cls || null);
                /* type=date gives the native picker, and its value is already
                   YYYY-MM-DD, which is exactly what the server validates */
                i.type = opts.type || 'text';
                if (opts.min !== undefined) i.min = opts.min;
                if (opts.max !== undefined) i.max = opts.max;
                if (opts.ph) i.placeholder = opts.ph;
                if (val !== null && val !== undefined) i.value = String(val);
                w.appendChild(i);
                form.appendChild(w);
                return i;
            };
            const fFrom = field('Start date', e.from || '', { type: 'date', cls: 'dt' });
            const fTo   = field('End date',   e.to || '',   { type: 'date', cls: 'dt' });
            const fHf   = field('From h', e.hourFrom, { type: 'number', cls: 'hr', min: 0, max: 24 });
            const fHt   = field('To h',   e.hourTo,   { type: 'number', cls: 'hr', min: 0, max: 24 });

            const btns = el('div', 'ev-field');
            btns.appendChild(el('span', null, ' '));
            const row = el('div', 'actions-grid');
            const save = el('button', 'abtn', 'Save window');
            save.addEventListener('click', () => act({
                action: 'window', key: e.key,
                from: fFrom.value.trim(), to: fTo.value.trim(),
                hourFrom: fHf.value.trim(), hourTo: fHt.value.trim(),
            }));
            const clr = el('button', 'abtn', 'Clear dates');
            clr.addEventListener('click', () => act({
                action: 'window', key: e.key, from: '', to: '',
                hourFrom: fHf.value.trim(), hourTo: fHt.value.trim(),
            }));
            row.appendChild(save); row.appendChild(clr);
            btns.appendChild(row);
            form.appendChild(btns);
            c.appendChild(form);

            const brow = el('div', 'actions-grid');
            [['Force on', 'on'], ['Force off', 'off'], ['Back to schedule', 'auto']].forEach(p => {
                const b = el('button', 'abtn', p[0]);
                b.addEventListener('click', () => act({ action: 'force', key: e.key, mode: p[1] }));
                brow.appendChild(b);
            });
            c.appendChild(brow);
            body.appendChild(c);
        });

        if (!(d.events || []).length) {
            body.appendChild(el('div', 'empty', 'No events registered in pup-events/shared/config.lua'));
        }

        /* Dead of Night detail, so it is obvious whether it is actually doing anything */
        if (d.don) {
            const n = d.don;
            const dc = el('div', 'card info-card');
            dc.appendChild(el('div', 'icard-title', 'Dead of Night — what is running'));
            const line = (label, ok, detail) =>
                dc.appendChild(el('div', 'offline-note', (ok ? '✓ ' : '✗ ') + label + (detail ? ' — ' + detail : '')));

            line('UFO', n.ufoOn, n.ufoSites + ' sites');
            line('Van Horn lighthouse', n.lighthouseOn, '');
            line('Bats', n.batsOn, n.batTowns + ' towns');
            if (n.tntOn !== undefined) {
                line('Trick or treat', n.tntOn,
                    n.tntDoors + ' of ' + n.tntPool + ' doors live tonight, ' + n.tntTrick + ' of them tricks');
            }
            dc.appendChild(el('div', 'offline-note',
                'UFO, lighthouse and bats are drawn per player, so nothing shows here until somebody is near one.'));
            body.appendChild(dc);
        }

        /* Spring Hunt detail */
        if (d.easter) {
            const n = d.easter;
            const ec = el('div', 'card info-card');
            ec.appendChild(el('div', 'icard-title', 'The Spring Hunt — what is running'));
            ec.appendChild(el('div', 'offline-note',
                'Generation ' + n.generation + ' — ' + n.patches + ' patches out, ' + n.eggsLeft + ' eggs still hidden'));
            ec.appendChild(el('div', 'offline-note',
                'Patches are re-rolled anywhere inside ' + n.regions + ' regions every ' + n.resetMins + ' minutes'));
            ec.appendChild(el('div', 'offline-note',
                (n.blipsOn ? '✓' : '✗') + ' map blips   ·   ' + (n.rabbitsOn ? '✓' : '✗') + ' rabbits'));
            ec.appendChild(el('div', 'offline-note',
                (n.webhooks > 0 ? '✓ ' + n.webhooks + ' webhook(s) configured' : '✗ no webhooks set in server/serverconfig.lua')));
            body.appendChild(ec);
        }

        /* Purge detail. Its rules live in other resources, so each line says
           whether that resource answered as well as what it is doing. */
        if (d.purge) {
            const p = d.purge;
            const pc = el('div', 'card info-card');
            pc.appendChild(el('div', 'icard-title', 'The Purge — what is running'));

            pc.appendChild(el('div', 'offline-note',
                (p.live ? '✓ live' : '✗ off') + '   ·   ' +
                (p.weatherOn ? '✓ thunderstorm / dust' : '✗ normal weather')));

            if (!p.searchOk) {
                pc.appendChild(el('div', 'offline-note', '✗ pup-misc did not answer — robbery rules unknown'));
            } else {
                pc.appendChild(el('div', 'offline-note',
                    (p.searchOn ? '✓ robbery overrides on' : '✗ robbery overrides off') + '   ·   ' +
                    (p.lootDead ? 'corpses lootable' : 'corpses protected')));
                pc.appendChild(el('div', 'offline-note',
                    p.maxItems + ' stacks per robbery   ·   ' +
                    (p.shieldMins > 0 ? p.shieldMins + ' min new-character shield' : 'no new-character shield') + '   ·   ' +
                    p.protectedJobs + ' protected job(s)   ·   ' + p.blacklisted + ' blacklisted item(s)'));
            }

            if (!p.deathOk) {
                pc.appendChild(el('div', 'offline-note', '✗ pup-medical did not answer — respawn delay unknown'));
            } else {
                pc.appendChild(el('div', 'offline-note',
                    (p.deathOn ? '✓ death overrides on' : '✗ death overrides off') +
                    '   ·   respawn after ' + p.respawn + 's'));
            }

            pc.appendChild(el('div', 'offline-note',
                'No headshot kills and no shoving are set on each player, so they do not show here.'));
            body.appendChild(pc);
        }
    }

    /* ------------------------------------------------------- weather ---
       Replaces /weatherui. Every control fires the weathersync server event
       that command fired, so the ace check on command.weatherui still decides
       who may change anything - this is a different way in, not new powers.
       Readouts come from weathersync:updateAdminUi once a second. The form is
       built once and only the cards repaint, and an input being typed into is
       left alone, or a refresh would eat what the admin is entering. */
    const WEATHER_TYPES = ['blizzard','clouds','drizzle','fog','groundblizzard','hail',
        'highpressure','hurricane','misty','overcast','overcastdark','rain','sandstorm',
        'shower','sleet','snow','snowlight','sunny','thunder','thunderstorm','whiteout'];
    const DAY_NAMES = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    let weatherBuilt = false;

    const wset = (action, payload) =>
        post('panelWeatherSet', Object.assign({ action: action }, payload || {}));
    const wNum = (id, fallback) => {
        const n = $('#' + id) ? parseFloat($('#' + id).value) : NaN;
        return isNaN(n) ? fallback : n;
    };
    const wOn = (id) => !!($('#' + id) && $('#' + id).dataset.on === '1');

    /* one labelled control, matching the Events page's form vocabulary */
    function wField(label, inner) {
        const f = el('label', 'ev-field');
        f.appendChild(el('span', '', label));
        f.insertAdjacentHTML('beforeend', inner);
        return f;
    }
    function wBtn(text, cls, onClick) {
        const b = el('button', cls, text);
        b.addEventListener('click', onClick);
        return b;
    }
    /* same shape the Events page uses for its blocks: a card, a title, an
       italic note, then the controls. Loose headings on the page background
       were why this read as a form dumped on the floor. */
    function wGroup(body, title, sub) {
        const c = el('div', 'card info-card');
        c.appendChild(el('div', 'icard-title', title));
        if (sub) c.appendChild(el('div', 'offline-note', sub));
        const form = el('div', 'ev-form');
        c.appendChild(form);
        body.appendChild(c);
        return form;
    }

    /* a bare checkbox has no styling in this panel and renders as a white
       square; a plate that reads its own state does, and freezing is a notable
       state so it borrows the warn colour when it is on */
    function wToggle(id, label) {
        const b = el('button', 'abtn', label + ': off');
        b.id = id;
        b.dataset.on = '0';
        b.addEventListener('click', () => {
            const on = b.dataset.on === '1' ? '0' : '1';
            b.dataset.on = on;
            b.textContent = label + (on === '1' ? ': on' : ': off');
            b.classList.toggle('warn', on === '1');
        });
        return b;
    }

    function buildWeatherPage() {
        if (weatherBuilt) return;
        const body = $('#weatherBody');
        if (!body) return;
        body.innerHTML = '';

        const cards = el('div', 'cards small');
        cards.id = 'wxCards';
        body.appendChild(cards);

        /* weather */
        const wf = wGroup(body, 'Weather', 'applies to every player at once');
        wf.appendChild(wField('Type', '<select id="wxType" class="panel-select">' +
            WEATHER_TYPES.map(w => '<option value="' + w + '">' + w + '</option>').join('') + '</select>'));
        wf.appendChild(wField('Transition s', '<input id="wxTrans" class="hr" type="number" min="0" max="600" value="15">'));
        wf.appendChild(wToggle('wxFreeze', 'Freeze'));
        wf.appendChild(wToggle('wxSnow', 'Perma snow'));
        wf.appendChild(wBtn('Apply', 'abtn', () => wset('weather', {
            weather: $('#wxType').value, transition: wNum('wxTrans', 15),
            frozen: wOn('wxFreeze'), snow: wOn('wxSnow') })));
        wf.appendChild(wBtn('Reset', 'abtn warn', () => wset('resetWeather')));

        /* time */
        const tf = wGroup(body, 'Time', 'day 0 is Sunday; the presets keep the current day');
        [['Dawn', 6], ['Noon', 12], ['Dusk', 18], ['Midnight', 0]].forEach(pair => {
            tf.appendChild(wBtn(pair[0], 'abtn', () => wset('time', {
                day: wNum('wxDay', 0), hour: pair[1], minute: 0, frozen: wOn('wxTimeFreeze') })));
        });
        tf.appendChild(wField('Day', '<input id="wxDay" class="hr" type="number" min="0" value="0">'));
        tf.appendChild(wField('Hour', '<input id="wxHour" class="hr" type="number" min="0" max="23" value="12">'));
        tf.appendChild(wField('Minute', '<input id="wxMin" class="hr" type="number" min="0" max="59" value="0">'));
        tf.appendChild(wToggle('wxTimeFreeze', 'Freeze clock'));
        tf.appendChild(wBtn('Apply', 'abtn', () => wset('time', {
            day: wNum('wxDay', 0), hour: wNum('wxHour', 12),
            minute: wNum('wxMin', 0), frozen: wOn('wxTimeFreeze') })));
        tf.appendChild(wBtn('Reset', 'abtn warn', () => wset('resetTime')));

        /* wind */
        const df = wGroup(body, 'Wind', 'direction in degrees, speed 0 to 12');
        df.appendChild(wField('Direction', '<input id="wxDir" class="hr" type="number" min="0" max="360" value="0">'));
        df.appendChild(wField('Speed', '<input id="wxSpeed" class="hr" type="number" min="0" max="12" step="0.1" value="0">'));
        df.appendChild(wToggle('wxWindFreeze', 'Freeze wind'));
        df.appendChild(wBtn('Apply', 'abtn', () => wset('wind', {
            direction: wNum('wxDir', 0), speed: wNum('wxSpeed', 0), frozen: wOn('wxWindFreeze') })));
        df.appendChild(wBtn('Reset', 'abtn warn', () => wset('resetWind')));

        /* clock speed + sync */
        const sf = wGroup(body, 'Clock speed and sync',
            'timescale is game seconds per real second; 0 is real time');
        sf.appendChild(wField('Timescale', '<input id="wxScale" class="hr" type="number" min="0" max="1000" step="0.1" value="30">'));
        sf.appendChild(wBtn('Apply', 'abtn', () => wset('timescale', { scale: wNum('wxScale', 30) })));
        sf.appendChild(wBtn('Reset', 'abtn warn', () => wset('resetTimescale')));
        sf.appendChild(wField('Sync delay s', '<input id="wxDelay" class="hr" type="number" min="0" max="600" value="0">'));
        sf.appendChild(wBtn('Apply', 'abtn', () => wset('syncDelay', { delay: wNum('wxDelay', 0) })));
        sf.appendChild(wBtn('Reset', 'abtn warn', () => wset('resetSyncDelay')));

        weatherBuilt = true;
    }

    function renderWeather(d) {
        buildWeatherPage();
        const cards = $('#wxCards');
        if (!cards) return;

        if (!d) {
            cards.innerHTML = '';
            cards.appendChild(el('div', 'empty',
                'No answer from weathersync. Check it is running and that you hold the command.weatherui ace.'));
            return;
        }

        const two = (n) => String(n).padStart(2, '0');
        cards.innerHTML = '';
        cards.appendChild(card('Time', 'in game now',
            valueNode(DAY_NAMES[(d.day || 0) % 7] + ' ' + two(d.hour || 0) + ':' + two(d.minute || 0)), '\u25F7'));
        cards.appendChild(card('Weather', 'current type', valueNode(d.weather || '?'), '\u2601'));
        cards.appendChild(card('Wind', 'speed and bearing',
            valueNode((Math.round((d.windSpeed || 0) * 10) / 10) + ' @ ' + Math.round(d.windDirection || 0) + '\u00b0'), '\u27A4'));
        cards.appendChild(card('Timescale', 'game s per real s', valueNode(String(d.timescale || 0)), '\u25F4'));
        cards.appendChild(card('Sync delay', 'client corrections', valueNode((d.syncDelay || 0) + 's'), '\u21BB'));

        /* never fight the admin for the caret */
        const idle = (id) => $('#' + id) && document.activeElement !== $('#' + id);
        if (idle('wxType') && d.weather && WEATHER_TYPES.indexOf(d.weather) !== -1) $('#wxType').value = d.weather;
        if (idle('wxDay')) $('#wxDay').value = d.day || 0;
        if (idle('wxHour')) $('#wxHour').value = d.hour || 0;
        if (idle('wxMin')) $('#wxMin').value = d.minute || 0;
        if (idle('wxDir')) $('#wxDir').value = Math.round(d.windDirection || 0);
        if (idle('wxSpeed')) $('#wxSpeed').value = Math.round((d.windSpeed || 0) * 10) / 10;
        if (idle('wxScale')) $('#wxScale').value = d.timescale || 0;
        if (idle('wxDelay')) $('#wxDelay').value = d.syncDelay || 0;
    }
    window.addEventListener('message', (e) => {
        const msg = e.data;
        if (!msg || msg.app !== 'panel') return;
        if (msg.action === 'open') openPanel(msg.data || {});
        else if (msg.action === 'close') closePanel();
        else if (msg.action === 'stats') { if (msg.data) renderStats(msg.data.info, msg.data.econ); }
        else if (msg.action === 'players') renderPlayers(msg.data);
        else if (msg.action === 'map') renderMap(msg.data);
        else if (msg.action === 'mapLayers') renderMapLayers(msg.data);
        else if (msg.action === 'detail') renderDetail(msg.data);
        else if (msg.action === 'items') renderItems(msg.data);
        else if (msg.action === 'security') renderSecurity(msg.data);
        else if (msg.action === 'itemDetail') renderItemDetail(msg.data);
        else if (msg.action === 'itemSuggest') renderItemSuggest(msg.data);
        else if (msg.action === 'propSuggest') renderPropSuggest(msg.data);
        else if (msg.action === 'consumables') renderConsumables(msg.data);
        else if (msg.action === 'smokes') renderSmokes(msg.data);
        else if (msg.action === 'weather') renderWeather(msg.data);
        // hidden, not closed: the page keeps its scroll and every field the
        // admin has typed, so it comes back exactly where they left it
        else if (msg.action === 'fxPreviewStart') {
            setFxPreviewing(true);
            $('#panel').classList.add('hidden');
        }
        else if (msg.action === 'fxPreviewEnd') {
            $('#panel').classList.remove('hidden');
            setFxPreviewing(false);
            if (msg.data && msg.data.bad) showPanelToast({ kind: 'error', text: 'That effect name is not valid.' });
        }
        else if (msg.action === 'buffTest') renderBuffTest(msg.data);
        else if (msg.action === 'serverBans') renderServerBans(msg.data);
        else if (msg.action === 'banLookup') renderBanLookup(msg.data);
        else if (msg.action === 'deathLosses') renderDeaths(msg.data);
        else if (msg.action === 'craftRecipes') renderCraftRecipes(msg.data);
        else if (msg.action === 'storeStock') renderStoreStock(msg.data);
        else if (msg.action === 'craftLocations') renderCraftLocations(msg.data);
        else if (msg.action === 'itemSearch') showItemSearch(msg.data);
        else if (msg.action === 'craftCharInfo') { if (craftCharInfoHandler) craftCharInfoHandler(msg.data); }
        else if (msg.action === 'craftSteamInfo') { if (craftSteamInfoHandler) craftSteamInfoHandler(msg.data); }
        else if (msg.action === 'weaponRecipes') renderWeaponRecipes(msg.data);
        else if (msg.action === 'weaponCraftLocations') renderWeaponCraftLocations(msg.data);
        else if (msg.action === 'doorLocks') renderDoorLocks(msg.data);
        else if (msg.action === 'toast') showPanelToast(msg.data);
        else if (msg.action === 'housing') renderHousing(msg.data);
        else if (msg.action === 'mypos') { myPos = msg.data || null; renderMyPos(myPos); }
        else if (msg.action === 'banks') renderBanks(msg.data);
        else if (msg.action === 'hideouts') renderHideouts(msg.data);
        else if (msg.action === 'curses') renderCurses(msg.data);
        else if (msg.action === 'farms') renderFarms(msg.data);
        else if (msg.action === 'camps') renderCamps(msg.data);
        else if (msg.action === 'props') renderProps(msg.data);
        else if (msg.action === 'events') renderEvents(msg.data);
        else if (msg.action === 'society') renderSociety(msg.data);
        else if (msg.action === 'societyShops') renderSocietyShops(msg.data);
        else if (msg.action === 'ranches') renderRanches(msg.data);
        else if (msg.action === 'stores') renderStores(msg.data);
        else if (msg.action === 'gangs') renderGangs(msg.data);
        else if (msg.action === 'perks') renderPerks(msg.data);
        else if (msg.action === 'perkDetail') {
            if (msg.data) renderPerkDetail(msg.data);
            else { perkView = null; renderPerks(perkData); }
        }
    });

    /* pup: THE ANTI-CHEAT BLOCK MUST STAY INSIDE THE IIFE.
       $ and el are declared inside it. After the closing })(); the dispatcher
       could still CALL renderSecurity (function declarations hoist to global),
       so the tab would look wired up and then throw
       "Uncaught ReferenceError: $ is not defined" the moment it rendered. */
/* ---------------------------------------------------------------- anti-cheat */
function agoText(at, now) {
    const s = Math.max(0, (now || Math.floor(Date.now() / 1000)) - (at || 0));
    if (s < 60) return s + 's ago';
    if (s < 3600) return Math.floor(s / 60) + 'm ago';
    if (s < 86400) return Math.floor(s / 3600) + 'h ago';
    return Math.floor(s / 86400) + 'd ago';
}

const SEC_COLS = '.8fr 1.6fr .8fr 2.2fr .5fr 1.5fr';

function renderSecurity(d) {
    const body = $('#securityBody');
    body.innerHTML = '';
    if (!d) {
        body.appendChild(el('div', 'empty', 'No access (needs the anticheat_panel permission)'));
        return;
    }

    const card = el('div', 'card');
    card.appendChild(el('div', 'actions-title',
        `Recent flags: ${(d.flags || []).length}   |   Spawns blocked: ${d.guardBlocked || 0}` +
        `   |   Guard: ${String(d.guardMode || 'off').toUpperCase()}` +
        `   |   Spam: ${String(d.spamMode || 'off').toUpperCase()}` +
        `   |   Response: ${d.kickOn ? 'KICK' : 'LOG ONLY'}`));
    const det = [];
    if (d.teleportOn) det.push('teleport');
    if (d.noclipOn) det.push('noclip');
    if (d.freecamOn) det.push('free cam');
    det.push('spawn guard');
    if (d.spamMode && d.spamMode !== 'off') det.push('spam guard');
    det.push('cash watcher');
    card.appendChild(el('div', 'offline-note',
        'Detectors: ' + det.join(' \u00b7 ') +
        ' \u2014 teleport and noclip run client-side and can be defeated; the spawn guard and cash watcher cannot.'));
    body.appendChild(card);

    /* World cleanup (server/pup_worldCleanup.lua). The server re-checks
       anticheat_cleanup on every request; this only decides who sees it. */
    if (d.canCleanup && hasPerm('anticheat_cleanup')) {
        const wc = d.cleanup || {};
        const box = el('div', 'card');
        box.appendChild(el('div', 'actions-title', 'World Cleanup'));
        let note;
        if (wc.running) {
            note = 'Counting down: ' + (wc.secondsLeft || 0) + 's left (started by ' + (wc.by || '?') + ').';
        } else if (wc.last) {
            const l = wc.last;
            note = 'Last run ' + agoText(l.at) + ' by ' + (l.by || '?') + ': ' + (l.vehicle || 0) + ' vehicles, '
                + (l.ped || 0) + ' peds, ' + (l.object || 0) + ' objects deleted, ' + (l.kept || 0) + ' kept.';
        } else {
            note = 'Deletes every script-spawned wagon, horse, ped and prop after a chat countdown. '
                + 'Players are never touched, nor the horse or wagon they are on.';
        }
        box.appendChild(el('div', 'offline-note', note));
        if (!wc.running) {
            const b = el('button', 'abtn warn', 'Clear spawned entities');
            b.style.marginTop = '.6vw';
            b.addEventListener('click', () => askConfirm({
                title: 'Clear spawned entities?',
                body: '<div class="offline-note">Everyone is warned in chat, then after the countdown every '
                    + 'script-spawned wagon, horse, ped and prop is deleted. Stabled horses and wagons count as '
                    + 'put away. Players and what they are riding are kept.</div>',
                okLabel: 'Start countdown',
                onOk: () => post('panelWorldCleanup'),
            }));
            box.appendChild(b);
        }
        body.appendChild(box);
    }

    if (!d.flags || !d.flags.length) {
        body.appendChild(el('div', 'empty', 'No flags recorded. Nothing to look at \u2014 that is the good outcome.'));
        return;
    }

    const head = el('div', 'table-head');
    head.style.gridTemplateColumns = SEC_COLS;
    ['When', 'Player', 'Type', 'Detail', 'Total', ''].forEach((t, i) => {
        head.appendChild(el('div', i === 4 ? 'right' : null, t));
    });
    body.appendChild(head);

    const rows = el('div', 'rows');
    const now = Math.floor(Date.now() / 1000);

    d.flags.forEach(f => {
        const row = el('div', 'prow');
        row.style.gridTemplateColumns = SEC_COLS;

        row.appendChild(el('div', null, agoText(f.at, now)));
        row.appendChild(el('div', null, f.name || '?'));

        /* spawn and cash are things the SERVER observed; teleport and noclip are
           client-reported. Colouring them apart keeps that distinction visible
           when someone is deciding whether to act on a flag. */
        const hard = (f.kind === 'spawn' || f.kind === 'cash' || f.kind === 'spam');
        const kind = el('div', null, String(f.kind || '').toUpperCase());
        kind.style.color = hard ? 'var(--danger, #c0392b)' : 'var(--cream-faint, #9a8f80)';
        kind.style.fontWeight = '600';
        row.appendChild(kind);

        row.appendChild(el('div', null, f.detail || ''));

        const total = el('div', 'right', f.total != null ? String(f.total) : '-');
        if ((f.total || 0) >= 3) total.style.color = 'var(--danger, #c0392b)';
        row.appendChild(total);

        /* Go and look before you act - the note at the top of this page says so.
           Buttons only appear while the flagged character is STILL on that server
           id, checked server-side, so a recycled id cannot be hit by mistake. */
        const acts = el('div');
        acts.style.display = 'flex';
        acts.style.gap = '.4vw';
        if (f.online) {
            const mk = (label, fn, warn) => {
                const b = el('button', 'abtn' + (warn ? ' warn' : ''), label);
                b.style.padding = '.2vh .6vw';
                b.style.fontSize = '.75em';
                b.addEventListener('click', fn);
                acts.appendChild(b);
            };
            if (hasPerm('spectate')) {
                mk('Spectate', () => post('panelAction',
                    { action: 'spectate', target: f.serverId, name: f.name }));
            }
            if (hasPerm('freeze_player')) {
                mk('Freeze', () => post('panelAction',
                    { action: 'freeze', target: f.serverId, name: f.name, state: true }), true);
                mk('Unfreeze', () => post('panelAction',
                    { action: 'freeze', target: f.serverId, name: f.name, state: false }));
            }
            /* Ban straight off a flag. The reason is prefilled with what tripped
               it so the Ban ID in Discord lines up with a row on this page. */
            if (hasPerm('server_ban')) {
                mk('Ban', () => {
                    /* not window.prompt(), which RedM renders as a system box titled
                       cfx-nui-vorp_admin outside the game. Same styled dialog as every
                       other confirm here, and it carries the duration picker too. */
                    const preset = String(f.kind || '').toUpperCase() + ' - ' + (f.detail || 'anti-cheat flag');
                    askConfirm({
                        title: 'Ban ' + (f.name || 'this player'),
                        body: '<div class="offline-note">They are shown this reason and a Ban ID.</div>'
                            + '<div class="action-form" style="margin-top:.6vw">'
                            + '<input id="acBanReason" style="width:17vw" value="' + escHtml(preset) + '">'
                            + banDurationSelectHTML('acBanDur')
                            + '</div>',
                        okLabel: 'Ban',
                        onOk: () => {
                            const r = $('#acBanReason'), d = $('#acBanDur');
                            const why = r ? r.value.trim() : '';
                            if (!why) return;
                            post('panelBanPlayer', {
                                target: f.serverId,
                                reason: why,
                                seconds: d ? (Number(d.value) || 0) : 0,
                            });
                        },
                    });
                }, true);
            }
        } else {
            acts.appendChild(el('div', 'offline-note', 'offline'));
        }
        row.appendChild(acts);

        rows.appendChild(row);
    });
    body.appendChild(rows);
}
})();
