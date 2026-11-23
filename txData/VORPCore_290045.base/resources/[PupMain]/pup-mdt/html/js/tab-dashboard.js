'use strict';
// Dispatch Feed (dashboard) and Law Alerts.

App.alerts = [];          // [{ id, title, text, location, sender, timestamp, locked, lockedBy, coords, responders }]
App.alertResponders = {}; // id -> { count, list }

function alertPriority(a) {
    const t = (str(a.text) + ' ' + str(a.title) + ' ' + str(a.message)).toLowerCase();
    if (/down|backup|urgent/.test(t)) return 'high';
    if (/info|locate/.test(t)) return 'low';
    return 'medium';
}
function alertText(a) { return str(a.text || a.message || a.title, T('ui_lawman_alert', 'Lawman Alert')); }

// ---------- dashboard ----------
(function () {
    let root, cache = null, cacheAt = 0, els = {};
    function countUp(el, to) {
        to = num(to); const start = performance.now();
        const step = (t) => {
            const p = Math.min(1, (t - start) / 1000);
            el.textContent = String(Math.round(to * p));
            if (p < 1 && el.isConnected) requestAnimationFrame(step);
        };
        requestAnimationFrame(step);
    }
    function panel(title, count, body, onAll) {
        return h('div', { class: 'panel' },
            h('div', { class: 'panel-head' }, h('span', { class: 'panel-t' }, title), h('span', { class: 'hand cnt' }, String(count)),
                onAll ? h('button', { class: 'link', type: 'button', onclick: onAll }, T('ui_view_all', 'View all')) : null),
            h('div', { class: 'panel-body' }, body));
    }
    function draw(d) {
        const p = App.player || {};
        d = d || {};
        const stats = h('div', { class: 'stats' },
            h('div', { class: 'stat who' }, h('span', { class: 'stat-l' }, T('ui_on_the_clipboard', 'On the clipboard')), h('b', null, str(p.name)), h('small', null, rankText())),
            h('div', { class: 'stat' }, h('span', { class: 'stat-l' }, T('ui_reports_week', 'Reports This Week')), els.rep = h('span', { class: 'hand big' }, '0')),
            h('div', { class: 'stat' }, h('span', { class: 'stat-l' }, statusDot(true), ' ', T('ui_active_units', 'Active Units')), els.units = h('span', { class: 'hand big' }, '0')),
            h('div', { class: 'stat' }, h('span', { class: 'stat-l' }, T('ui_active_bounties', 'Active Bounties')), els.bnt = h('span', { class: 'hand big' }, '0')));
        const quick = h('div', { class: 'quick' },
            refreshBtn('dashboard', () => load(true)),
            h('button', { class: 'btn danger sm', type: 'button', onclick: () => App.close(true) }, icon('close'), T('ui_close_mdt', 'Close MDT')));

        const bulletins = arr(d.bulletins).filter((b) => b && b.is_active !== false && b.is_active !== 0);
        const bul = bulletins[0];
        const banner = bul ? h('div', { class: 'banner' + (bul.type === 'urgent' ? ' urgent' : '') },
            icon(bul.type === 'urgent' ? 'campaign' : 'notifications'),
            h('div', null,
                bul.type === 'urgent' ? h('span', { class: 'badge tone-red' }, T('ui_urgent', 'URGENT')) : null,
                h('b', null, ' ', str(bul.title)),
                h('p', null, str(bul.content)),
                h('small', null, T('ui_posted_by_rel', 'posted by %s · %s', str(bul.posted_by_name, T('ui_unknown', 'Unknown')), relTime(bul.created_at))))) : null;

        const warrants = arr(d.warrants).slice(0, 8);
        const bolos = arr(d.bolos).slice(0, 5);
        const reports = arr(d.recentReports).slice(0, 8);
        const alerts = App.alerts.slice(0, 8);

        const alertsPanel = panel(T('ui_alerts', 'Alerts'), App.alerts.length, alerts.length ? alerts.map((a) => h('div', { class: 'feed-row prio-' + alertPriority(a), onclick: () => App.showTab('alerts') },
            h('b', null, alertText(a)),
            h('small', null, [str(a.location, T('ui_unknown_location', 'Unknown location')), str(a.sender, T('ui_anonymous', 'Anonymous')), relTime(a.timestamp)].join(' · ')))) : h('div', { class: 'muted' }, T('ui_no_active_alerts', 'No active alerts')),
        () => App.showTab('alerts'));
        const bountyPanel = panel(T('ui_bounties', 'Bounties'), arr(d.warrants).length, warrants.length ? warrants.map((w) => h('div', { class: 'feed-row', onclick: () => App.showTab('bounties', { openId: num(w.id) }) },
            h('b', null, str(w.subject_name || w.citizen_name, T('ui_unknown', 'Unknown'))),
            h('small', null, T('ui_bounty_line', '#%s · Exp. %s', str(w.id), w.expires_at || w.expiry_date ? fmtDate(w.expires_at || w.expiry_date) : T('ui_no_expiry', 'No expiry'))))) : h('div', { class: 'muted' }, T('ui_no_bounties', 'No active bounties')),
        tabVisible('bounties') ? () => App.showTab('bounties') : null);
        const boloPanel = panel(T('ui_witness_statements', 'Witness Statements'), arr(d.bolos).length, bolos.length ? bolos.map((b) => h('div', { class: 'feed-row', onclick: () => App.showTab('statements', { openId: num(b.id) }) },
            h('b', null, str(b.subject || b.subject_name, T('ui_unknown', 'Unknown')), ' ', b.type ? badge(str(b.type), 'grey') : null),
            h('small', null, cut(b.description, 50)))) : h('div', { class: 'muted' }, T('ui_no_statements', 'No active Witness Statements')),
        tabVisible('statements') ? () => App.showTab('statements') : null);
        const repPanel = panel(T('ui_recent_reports', 'Recent Reports'), arr(d.recentReports).length, reports.length ? reports.map((r) => h('div', { class: 'feed-row', onclick: () => App.showTab('reports', { openId: num(r.id) }) },
            h('b', null, str(r.title, T('ui_untitled_report', 'Untitled Report'))),
            h('small', null, str(r.author_name, T('ui_unknown', 'Unknown')) + ' · ' + relTime(r.date || r.created_at)))) : h('div', { class: 'muted' }, T('ui_no_reports', 'No reports found')),
        tabVisible('reports') ? () => App.showTab('reports') : null);

        fill(root,
            h('h2', { class: 'page-title' }, T('ui_dispatch_feed', 'Dispatch Feed')),
            stats, quick, banner,
            h('div', { class: 'dash-grid' }, alertsPanel, tabVisible('bounties') ? bountyPanel : null, tabVisible('statements') ? boloPanel : null, tabVisible('reports') ? repPanel : null));
        countUp(els.rep, d.totalIncidents);
        countUp(els.units, d.activeLawmen);
        countUp(els.bnt, d.activeBounties);
    }
    async function load(force) {
        if (!force && cache && Date.now() - cacheAt < 10000) { draw(cache); return; }
        const d = await nui('getDashboardData', {}, 5000, false);
        if (!d || typeof d !== 'object') { if (!cache) draw({}); return; }
        cache = d; cacheAt = Date.now();
        if (Array.isArray(d.policeAlerts) || (d.policeAlerts && typeof d.policeAlerts === 'object')) App.setAlerts(arr(d.policeAlerts), true);
        if (App.current === 'dashboard') draw(d);
    }
    regTab({
        id: 'dashboard', icon: 'settings_input_antenna', perm: 'dashboard', label: () => T('ui_nav_dashboard', 'Dispatch Feed'),
        build: (r) => { root = r; draw(cache || {}); },
        show: () => load(false),
        reset: () => { cache = null; cacheAt = 0; },
        push: (d) => { if (d && typeof d === 'object') { cache = d; cacheAt = Date.now(); if (App.current === 'dashboard') draw(d); } },
        redraw: () => { if (App.current === 'dashboard' && root) draw(cache || {}); },
    });
})();

// ---------- Law Alerts ----------
(function () {
    let root, list, countEl;
    function respond(a) {
        nui('respondToExistingAlert', { alertId: a.id, coords: a.coords || null, text: alertText(a) }, 8000, null).then((r) => {
            if (r && r.success === false) notify(msgOf(r, T('ui_alert_respond_failed', 'Could not respond to that alert')));
        });
    }
    function leave(a) { nui('leaveAlert', { alertId: a.id }, 8000, null); }
    function card(a) {
        const pr = alertPriority(a);
        const me = App.player && App.player.name;
        const lockedByOther = a.locked && str(a.lockedBy) && str(a.lockedBy) !== str(me);
        return h('div', { class: 'alert-card prio-' + pr },
            h('div', { class: 'alert-head' },
                h('b', null, T('ui_lawman_alert', 'Lawman Alert')), h('span', { class: 'muted' }, ' ' + fmtTime(a.timestamp)),
                a.locked ? h('span', { class: 'badge tone-gold' }, icon('lock'), ' ', T('ui_locked', 'Locked')) : null,
                h('button', { class: 'x', type: 'button', title: T('ui_dismiss', 'Dismiss'), onclick: () => {
                    // the card goes when the server agrees (the client then pushes removeAlert)
                    nui('removePoliceAlert', { alertId: a.id }, 8000, null).then((r) => { if (ok(r)) App.removeAlert(a.id); });
                } }, icon('close'))),
            h('div', { class: 'alert-text' }, alertText(a)),
            h('div', { class: 'alert-meta' },
                h('span', null, icon('place'), ' ', str(a.location, T('ui_unknown_location', 'Unknown location'))),
                h('span', null, icon('person'), ' ', str(a.sender, T('ui_anonymous', 'Anonymous')))),
            h('div', { class: 'alert-actions' },
                lockedByOther ? h('span', { class: 'muted' }, T('ui_locked_by', 'Locked by %s', str(a.lockedBy)))
                    : h('button', { class: 'btn primary sm', type: 'button', onclick: () => respond(a) }, icon('directions'), T('ui_respond', 'Respond')),
                h('button', { class: 'btn ghost sm', type: 'button', onclick: () => details(a) }, icon('info'), T('ui_details', 'Details')),
                a.coords ? h('button', { class: 'btn ghost sm', type: 'button', onclick: () => nui('locateAlert', { alertId: a.id, coords: a.coords }) }, icon('map'), T('ui_show_on_map', 'Show on map')) : null,
                h('button', { class: 'btn ghost sm', type: 'button', onclick: () => nui('toggleAlertLock', { alertId: a.id }) }, icon(a.locked ? 'lock_open' : 'lock'), a.locked ? T('ui_unlock', 'Unlock') : T('ui_lock', 'Lock'))));
    }
    let detailModal = null;
    function details(a) {
        const body = h('div');
        const draw = () => {
            const cur = App.alerts.find((x) => String(x.id) === String(a.id)) || a;
            const resp = App.alertResponders[String(a.id)] || { count: 0, list: [] };
            fill(body,
                h('p', { class: 'alert-text' }, alertText(cur)),
                h('div', { class: 'grid2' },
                    h('div', null, h('span', { class: 'lbl' }, T('ui_time', 'Time')), ' ', fmtDateTime(cur.timestamp)),
                    h('div', null, h('span', { class: 'lbl' }, T('ui_location', 'Location')), ' ', str(cur.location, '—'))),
                h('div', null, cur.locked ? badge(T('ui_locked_by', 'Locked by %s', str(cur.lockedBy)), 'gold') : badge(T('ui_open', 'Open'), 'green')),
                h('div', { class: 'fsec-title' }, T('ui_responding_lawmen', 'Responding Lawmen'), ' (' + num(resp.count) + ')'),
                arr(resp.list).length ? arr(resp.list).map((r) => h('div', { class: 'resp-row' }, icon('check'), ' ', str(r.name), r.rank ? ' [' + r.rank + ']' : '', h('small', { class: 'muted' }, ' ' + relTime(r.time)))) : h('div', { class: 'muted' }, T('ui_no_responders', 'Nobody is responding yet')));
        };
        draw();
        detailModal = modal({
            title: T('ui_alert_details', 'Alert Details'), icon: 'warning', body, backdropCloses: true,
            footer: [
                h('button', { class: 'btn primary', type: 'button', onclick: () => respond(a) }, T('ui_respond', 'Respond')),
                h('button', { class: 'btn ghost', type: 'button', onclick: () => leave(a) }, T('ui_leave', 'Leave')),
                h('button', { class: 'btn ghost', type: 'button', onclick: () => detailModal.close() }, T('ui_close', 'Close')),
            ],
            onClose: () => { detailModal = null; },
        });
        detailModal.redraw = draw;
        detailModal.alertId = a.id;
    }
    function draw() {
        if (!root) return;
        const n = App.alerts.length;
        countEl.textContent = n === 1 ? T('ui_one_alert', '1 Alert') : T('ui_n_alerts', '%d Alerts', n);
        fill(list, n ? App.alerts.map(card) : emptyState(T('ui_no_active_alerts', 'No active alerts'), null, 'notifications_off'));
        if (detailModal && detailModal.redraw) detailModal.redraw();
    }
    App.setAlerts = (alerts, quiet) => {
        App.alerts = arr(alerts).filter((a) => a && a.id !== undefined).sort((a, b) => num(toDate(b.timestamp)) - num(toDate(a.timestamp)));
        draw();
        if (!quiet && App.tabs.dashboard.redraw) App.tabs.dashboard.redraw();
    };
    App.removeAlert = (id) => {
        App.alerts = App.alerts.filter((a) => String(a.id) !== String(id));
        delete App.alertResponders[String(id)];
        if (detailModal && String(detailModal.alertId) === String(id)) detailModal.close();
        draw();
        App.tabs.dashboard.redraw();
    };
    App.setAlertLock = (d) => {
        const a = App.alerts.find((x) => String(x.id) === String(d.alertId || d.id));
        if (a) { a.locked = !!d.locked; a.lockedBy = d.lockedBy || null; }
        draw();
    };
    App.setAlertResponders = (d) => {
        App.alertResponders[String(d.alertId || d.id)] = { count: num(d.count), list: arr(d.responders || d.responses) };
        draw();
    };
    regTab({
        id: 'alerts', icon: 'notifications_active', perm: 'dashboard', label: () => T('ui_nav_alerts', 'Law Alerts'),
        build: (r) => {
            root = r;
            countEl = h('span', { class: 'hand cnt' });
            list = h('div', { class: 'alert-list' });
            add(r, [h('div', { class: 'toolbar' }, h('h2', { class: 'page-title' }, icon('warning'), ' ', T('ui_nav_alerts', 'Law Alerts')), countEl), list]);
            draw();
        },
        show: () => draw(),
        reset: () => { root = null; App.alerts = []; App.alertResponders = {}; detailModal = null; },
    });
})();
