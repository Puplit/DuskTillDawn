'use strict';
// The firm: Firm Office (lawyer landing page), Firm Settings, Bar Roster, Firm Ledger.

// ---------- Firm Office ----------
(function () {
    let root;
    async function load() {
        fill(root, loading());
        const [home, setts] = await Promise.all([nui('getFirmHome', {}, 8000, null), can('viewbarroster') ? nui('getFirmSettings', {}, 8000, null) : Promise.resolve(null)]);
        if (!root) return;
        const d = home || {};
        const s = setts || {};
        if (s.firmName !== undefined && str(s.firmName) !== str(App.firmName)) { App.firmName = s.firmName; drawLetterhead(); }
        const statCard = (n, l, ic) => h('div', { class: 'stat' }, h('span', { class: 'stat-l' }, icon(ic), ' ', l), h('span', { class: 'hand big' }, String(num(n))));
        const reqs = arr(d.requests);
        const recent = arr(d.recent).slice(0, 8);
        const kindIcon = { bail: 'savings', appeal: 'balance', expungement: 'cleaning_services' };
        fill(root,
            s.motd ? h('div', { class: 'banner' }, icon('campaign'), h('div', null, h('p', { class: 'pre' }, str(s.motd)), h('small', null, '— ' + str(s.postedBy, T('ui_the_firm', 'the firm'))))) : null,
            h('h2', { class: 'page-title' }, str(App.firmName) || T('ui_nav_firmhome', 'Firm Office')),
            h('div', { class: 'stats' },
                statCard(d.totalAttorneys, T('ui_bar_roster', 'Bar Roster'), 'groups'),
                statCard(arr(d.onDuty).length, T('ui_on_duty', 'On Duty'), 'schedule'),
                statCard(d.openCases, T('ui_defense', 'Defense'), 'work'),
                statCard(d.pendingPetitions, T('ui_ls_pending', 'Pending'), 'pending_actions')),
            h('div', { class: 'dash-grid' },
                h('div', { class: 'panel' }, h('div', { class: 'panel-head' }, h('span', { class: 'panel-t' }, T('ui_counsel_requests', 'Counsel Requests')), h('span', { class: 'hand cnt' }, String(reqs.length))),
                    h('div', { class: 'panel-body' }, reqs.length ? reqs.map((r) => h('div', { class: 'feed-row static' },
                        h('b', null, T('ui_counsel_request_n', 'Counsel request #%s', str(r.id))), h('small', null, ' ' + relTime(new Date(Date.now() - num(r.ago) * 1000))),
                        h('div', { class: 'frow tight' },
                            r.respondedBy ? h('span', { class: 'muted' }, T('ui_responded_by', 'Taken by %s', str(r.respondedBy)))
                                : h('button', { class: 'btn primary sm', type: 'button', onclick: async () => {
                                    const res = await nui('respondCounsel', { id: num(r.id) }, 8000, null);
                                    notify(ok(res) ? T('ui_took_call', 'You took the call — marker set on your map') : msgOf(res, T('ui_already_taken', 'Already taken')));
                                    load();
                                } }, T('ui_respond', 'Respond')),
                            iconBtn('close', T('ui_dismiss', 'Dismiss'), async () => {
                                const res = await nui('cancelCounsel', { id: num(r.id) }, 8000, null);
                                notify(ok(res) ? T('ui_request_dismissed', 'Request dismissed') : msgOf(res, T('ui_already_taken', 'Already taken')));
                                load();
                            })))) : h('div', { class: 'muted' }, T('ui_no_requests', 'No counsel requests')))),
                h('div', { class: 'panel' }, h('div', { class: 'panel-head' }, h('span', { class: 'panel-t' }, T('ui_on_duty', 'On Duty'))),
                    h('div', { class: 'panel-body tags' }, arr(d.onDuty).length ? arr(d.onDuty).map((p) => h('span', { class: 'tag' }, str(p.name) + ' · ' + str(p.rank))) : h('span', { class: 'muted' }, T('ui_nobody_on_duty', 'Nobody is on duty')))),
                h('div', { class: 'panel' }, h('div', { class: 'panel-head' }, h('span', { class: 'panel-t' }, T('ui_quick_actions', 'Quick actions'))),
                    h('div', { class: 'panel-body btn-col' },
                        tabVisible('bail') && can('requestbail') ? h('button', { class: 'btn', type: 'button', onclick: () => App.showTab('bail', { openForm: true }) }, icon('savings'), T('ui_file_bail', 'File Bail Petition')) : null,
                        tabVisible('appeals') && can('requestappeal') ? h('button', { class: 'btn', type: 'button', onclick: () => App.showTab('appeals', { openForm: true }) }, icon('balance'), T('ui_file_appeal', 'File Appeal')) : null,
                        tabVisible('expungements') ? h('button', { class: 'btn', type: 'button', onclick: () => App.showTab('expungements') }, icon('cleaning_services'), T('ui_nav_expungements', 'Expungements')) : null,
                        tabVisible('barroster') ? h('button', { class: 'btn', type: 'button', onclick: () => App.showTab('barroster') }, icon('groups'), T('ui_bar_roster', 'Bar Roster')) : null)),
                h('div', { class: 'panel' }, h('div', { class: 'panel-head' }, h('span', { class: 'panel-t' }, T('ui_recent_filings', 'Recent filings'))),
                    h('div', { class: 'panel-body' }, recent.length ? recent.map((f) => h('div', { class: 'feed-row static' },
                        h('b', null, icon(kindIcon[f.kind] || 'description'), ' ', str(f.kind)),
                        h('small', null, str(f.citizen_name) + ' — ' + str(f.requested_by_name) + ' · ' + fmtDate(f.requested_at) + ' '), badge(legalStatusLabel(f.status), legalStatusTone(f.status))))
                        : h('div', { class: 'muted' }, T('ui_firm_blank', 'The firm ledger is blank — no data yet.'))))));
    }
    regTab({
        id: 'firmhome', icon: 'business', perm: 'firmhome', label: () => T('ui_nav_firmhome', 'Firm Office'),
        build: (r) => { root = r; },
        show: () => load(),
        reset: () => { root = null; },
    });
})();

// ---------- Firm Settings ----------
(function () {
    let root;
    async function load() {
        fill(root, loading());
        const s = await nui('getFirmSettings', {}, 8000, null);
        if (!root) return;
        // denied or timed out: never draw a form of empty defaults that a save would push back
        if (!s || s.denied || s.success === false) { fill(root, emptyState(msgOf(s, T('ui_load_failed', 'Could not load')), null, 'error')); return; }
        const name = inp({ value: str(s.firmName), maxlength: 40 });
        const motd = area({ rows: 5, value: str(s.motd), maxlength: 500 });
        const acc = h('input', { type: 'checkbox', class: 'switch', checked: s.acceptRequests !== false && s.acceptRequests !== 0 && s.acceptRequests !== '0' });
        const canEdit = s.canEdit !== false && can('firmsettings');
        [name, motd, acc].forEach((el) => { el.disabled = !canEdit; });
        const post = h('button', { class: 'btn primary', type: 'button' }, T('ui_post', 'Post'));
        post.addEventListener('click', () => busy(post, null, async () => {
            const r = await nui('saveFirmMotd', { motd: motd.value.trim().slice(0, 500), name: name.value.trim().slice(0, 40), acceptRequests: acc.checked }, 8000, null);
            notify(ok(r) ? T('ui_firm_saved', 'Firm settings saved.') : msgOf(r, T('ui_save_failed', 'Could not save')));
            if (ok(r)) { App.firmName = name.value.trim(); drawLetterhead(); }
        }));
        fill(root, h('h2', { class: 'page-title' }, T('ui_nav_firmsettings', 'Firm Settings')),
            h('div', { class: 'card' },
                field(T('ui_firm_name', 'Firm name'), name), h('small', { class: 'muted' }, T('ui_firm_name_hint', 'Leave empty to use the default letterhead.')),
                field(T('ui_announcement', 'Announcement'), motd),
                h('label', { class: 'perm-row' }, h('b', null, T('ui_accept_requests', 'Accept counsel requests (/lawyer)')), acc),
                s.postedBy ? h('small', { class: 'muted' }, T('ui_last_posted_by', 'Last posted by %s', str(s.postedBy))) : null,
                canEdit ? h('div', { class: 'frow end' }, post) : null));
    }
    regTab({
        id: 'firmsettings', icon: 'settings', perm: 'firmsettings', label: () => T('ui_nav_firmsettings', 'Firm Settings'),
        build: (r) => { root = r; }, show: () => load(), reset: () => { root = null; },
    });
})();

// ---------- Bar Roster ----------
(function () {
    let root, stSel, body, data = null, profileOpen = false;
    function rowStatus(x) { return x.onDuty ? ['on', T('ui_on_duty', 'On Duty'), 'green'] : x.online ? ['online', T('ui_online', 'Online'), 'teal'] : ['off', T('ui_offline', 'Offline'), 'grey']; }
    async function load() {
        profileOpen = false; popLayer(body);
        fill(body, loading());
        data = (await nui('getBarRoster', {}, 8000, null)) || {};
        if (!root) return;
        draw();
    }
    let dutyBtn;
    function draw() {
        const f = stSel.value;
        const rows = arr(data.rows).filter((x) => f === 'all' || rowStatus(x)[0] === f || (f === 'online' && x.online))
            .sort((a, b) => (num(b.grade) - num(a.grade)) || str(a.name).localeCompare(str(b.name)));
        if (App.lawyer) {
            dutyBtn.classList.remove('hidden');
            dutyBtn.className = 'btn sm ' + (data.myOnDuty ? 'danger' : 'primary');
            dutyBtn.textContent = data.myOnDuty ? T('ui_clock_off', 'Clock Off') : T('ui_clock_on', 'Clock On');
        }
        fill(body, table([
            { label: T('ui_col_name', 'Name'), render: (x) => [str(x.name), x.isMe ? h('small', { class: 'muted' }, ' ' + T('ui_you', '(you)')) : null] },
            { label: T('ui_rank', 'Rank'), render: (x) => str(x.rank) + ' (' + num(x.grade) + ')' },
            { label: T('ui_col_status', 'Status'), render: (x) => { const s = rowStatus(x); return badge(s[1], s[2]); } },
            { label: T('ui_citizen_id', 'Citizen ID'), render: (x) => str(x.citizenid) },
            { label: T('ui_cases', 'Cases'), render: (x) => String(num(x.cases)) },
            { label: T('ui_petitions', 'Petitions'), render: (x) => String(num(x.petitions)) },
            { label: '', cls: 'act', render: (x) => data.canFire && !x.isMe && num(x.grade) < num(data.myGrade) ? iconBtn('person_remove', T('ui_fire', 'Fire'), () => fire(x)) : null },
        ], rows, { onRow: (x) => { if (x.isMe || can('viewlawyerprofile')) profile(x); }, empty: emptyState(T('ui_no_attorneys', 'No attorneys yet'), T('ui_lawyers_auto', 'Lawyer jobs appear automatically'), 'groups') }));
    }
    async function fire(x) {
        if (!(await confirmBox({ message: T('ui_fire_q', 'Remove %s from the firm? They lose the lawyer job immediately.', str(x.name)), confirm: T('ui_fire', 'Fire'), danger: true }))) return;
        const r = await nui('fireLawyer', { citizenid: str(x.citizenid) }, 8000, null);
        notify(ok(r) ? T('ui_fired', '%s has been fired', str(r.name || x.name)) : msgOf(r, T('ui_action_failed', 'That did not work')));
        if (ok(r)) load();
    }
    async function profile(x) {
        profileOpen = true;
        popLayer(body); pushLayer(body, () => { draw(); profileOpen = false; popLayer(body); });
        fill(body, loading());
        const p = await nui('getLawyerProfile', { citizenid: str(x.citizenid) }, 8000, null);
        if (!root || !profileOpen) return;
        const back = h('button', { class: 'btn ghost sm', type: 'button', onclick: () => { profileOpen = false; popLayer(body); draw(); } }, icon('arrow_back'), T('ui_back', 'Back'));
        if (!p || p.denied) { fill(body, back, emptyState(T('ui_not_authorised', 'Not authorised'), null, 'lock')); return; }
        if (!p.found) { fill(body, back, emptyState(T('ui_not_found', 'Not found'), null, 'person_off')); return; }
        const s = rowStatus(p);
        const counts = arr(p.counts);
        const tally = (src) => {
            const w = counts.filter((c) => c.src === src && ['approved', 'appeared', 'active'].includes(str(c.status))).reduce((a, c) => a + num(c.n), 0);
            const l = counts.filter((c) => c.src === src && ['denied', 'skipped'].includes(str(c.status))).reduce((a, c) => a + num(c.n), 0);
            return w + '/' + l;
        };
        const mins = num(p.dutyMinutes);
        const list = (title, items, render) => section(title + ' (' + items.length + ')', items.length ? items.slice(0, 25).map((i) => h('div', { class: 'feed-row static' }, render(i))) : h('div', { class: 'muted' }, T('ui_none', 'None')));
        fill(body, back,
            h('h3', null, str(p.name) + ' — ' + str(p.rank) + ' (' + num(p.grade) + ')'), badge(s[1], s[2]), ' ', h('span', { class: 'muted' }, str(p.citizenid)),
            h('div', { class: 'chips' },
                h('span', { class: 'chip-btn' }, T('ui_duty_time', 'Duty Time'), ': ', Math.floor(mins / 60) + 'h ' + (mins % 60) + 'm'),
                h('span', { class: 'chip-btn' }, T('ui_defense', 'Defense'), ': ', String(arr(p.defense).length)),
                h('span', { class: 'chip-btn' }, T('ui_nav_bail', 'Bail'), ' ', tally('bail')),
                h('span', { class: 'chip-btn' }, T('ui_nav_appeals', 'Appeals'), ' ', tally('appeals')),
                h('span', { class: 'chip-btn' }, T('ui_nav_expungements', 'Expungements'), ' ', tally('expungements'))),
            h('div', { class: 'cols2' },
                list(T('ui_defense', 'Defense'), arr(p.defense), (i) => [h('b', null, str(i.case_number)), ' ', str(i.title), h('small', null, ' ' + fmtDate(i.assigned_at))]),
                list(T('ui_nav_bail', 'Bail'), arr(p.bail), (i) => [h('b', null, str(i.citizen_name)), ' ', money(i.amount), ' ', badge(legalStatusLabel(i.status), legalStatusTone(i.status))]),
                list(T('ui_nav_appeals', 'Appeals'), arr(p.appeals), (i) => [h('b', null, str(i.citizen_name)), ' ', badge(legalStatusLabel(i.status), legalStatusTone(i.status))]),
                list(T('ui_nav_expungements', 'Expungements'), arr(p.expungements), (i) => [h('b', null, str(i.citizen_name)), ' ', badge(legalStatusLabel(i.status), legalStatusTone(i.status))])));
    }
    regTab({
        id: 'barroster', icon: 'groups', perm: 'viewbarroster', label: () => T('ui_nav_barroster', 'Bar Roster'),
        build: (r) => {
            root = r;
            stSel = sel([['all', T('ui_all', 'All')], ['on', T('ui_on_duty', 'On Duty')], ['online', T('ui_online', 'Online')], ['off', T('ui_offline', 'Offline')]], 'all');
            stSel.addEventListener('change', () => { if (data && !profileOpen) draw(); });
            dutyBtn = h('button', { class: 'btn sm hidden', type: 'button', onclick: async () => {
                const going = !data.myOnDuty;
                await nui('barSetDuty', { onDuty: going }, 8000, null);
                if (!going) return; // clocking off closes the MDT from the client
                load();
            } });
            body = h('div');
            add(r, [h('div', { class: 'toolbar' }, h('h2', { class: 'page-title' }, T('ui_attorneys_bar', 'Attorneys at the Bar')), stSel, dutyBtn, plainRefresh(load)), body]);
        },
        show: () => load(),
        reset: () => { root = null; data = null; profileOpen = false; },
    });
})();

// ---------- Firm Ledger ----------
regTab({
    id: 'firmledger', icon: 'account_balance', perm: 'firmledger', label: () => T('ui_nav_firmledger', 'Firm Ledger'),
    build: (r) => { r.dataset.x = '1'; },
    show: () => { const r = App.built.firmledger; if (r) fill(r, h('h2', { class: 'page-title' }, T('ui_nav_firmledger', 'Firm Ledger')), ledgerCard(true)); },
});
