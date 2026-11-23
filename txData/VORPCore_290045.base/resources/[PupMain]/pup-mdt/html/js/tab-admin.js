'use strict';
// Permissions, Audit Log, Department Settings (switches, ledger, announcement). The ledger card is shared with the Firm Ledger.

// ---------- ledger card ----------
function ledgerCard(isFirm) {
    const wrap = h('div', { class: 'ledger' }, loading());
    const load = async () => {
        const r = await nui('getLedger', {}, 8000, null);
        if (!wrap.isConnected && wrap.parentNode === null) return;
        if (!r || r.enabled === false) { fill(wrap, emptyState(isFirm ? T('ui_firm_ledger_off', 'The firm ledger is turned off') : T('ui_ledger_off', 'The ledger is turned off'), null, 'account_balance')); return; }
        const amount = numInp({ min: 1, placeholder: T('ui_amount', 'Amount') });
        const at = !!r.atStation;
        const dep = h('button', { class: 'btn', type: 'button', disabled: !at || !r.canDeposit }, icon('south'), T('ui_deposit', 'Deposit'));
        const wd = h('button', { class: 'btn', type: 'button', disabled: !at || !r.canWithdraw }, icon('north'), T('ui_withdraw', 'Withdraw'));
        const go = (name, btn) => busy(btn, null, async () => {
            const n = Math.floor(num(amount.value));
            if (n < 1) { notify(T('ui_amount_min', 'Enter a whole amount of at least 1')); return; }
            const res = await nui(name, { amount: n }, 8000, null);
            notify(msgOf(res, ok(res) ? T('ui_done', 'Done') : T('ui_action_failed', 'That did not work')));
            if (ok(res)) load();
        });
        dep.addEventListener('click', () => go('ledgerDeposit', dep));
        wd.addEventListener('click', () => go('ledgerWithdraw', wd));
        const sal = r.salary;
        fill(wrap, h('div', { class: 'card ledger-card' },
            h('div', { class: 'fsec-title' }, isFirm ? T('ui_firm_funds', 'Firm Funds') : T('ui_dept_funds', 'Department Funds')),
            h('div', { class: 'hand huge' }, money(r.balance)),
            sal && num(sal.amount) > 0 ? h('div', { class: 'muted' }, T('ui_your_pay', 'Your pay: %s / %d min on duty', money(sal.amount), num(sal.interval))) : null,
            h('div', { class: 'frow tight' }, amount, dep, wd),
            !at ? h('small', { class: 'muted' }, isFirm ? T('ui_firm_station_note', "The firm's strongbox is kept at the office.") : T('ui_station_note', 'The strongbox is kept at the station.')) : null));
    };
    load();
    return wrap;
}

// ---------- Permissions ----------
const PermGroups = () => [
    ['CORE', [['dashboard', 'Dashboard', 'Dispatch feed and alerts']]],
    ['OPERATIONS', [['reports', 'Reports', 'Write and edit incident reports'], ['deletereports', 'Delete Reports', 'Remove incident reports'], ['bolos', 'Witness Statements', 'File and resolve statements'], ['deletebolos', 'Delete Statements', 'Remove statements'], ['evidences', 'Cases/Evidence', 'Case files and the evidence catalogue'], ['deleterecords', 'Delete Records', 'Delete cases and evidence']]],
    ['RECORDS', [['criminals', 'Citizens', 'Person search and records'], ['warrants', 'Bounties', 'See the bounty list'], ['mostwanted', 'Most Wanted', 'See the Most Wanted board'], ['managemostwanted', 'Post Wanted', 'Post and remove Most Wanted posters'], ['issuewarrants', 'Post Bounties', 'Post and edit bounties'], ['deletewarrants', 'Delete Bounties', 'Delete or revoke bounties'], ['fines', 'Charges', 'See the penal code and bill'], ['managecharges', 'Manage Charges', 'Edit the penal code'], ['deletefines', 'Delete Fines', 'Remove fines']]],
    ['PERSONNEL', [['lawmen', 'Roster Tab', 'Open the roster'], ['viewlawmen', 'View Profile', "See other lawmen's files"], ['createlawmen', 'Edit Profile', 'Leave, termination, settings and announcements']]],
    ['JAIL & ENFORCEMENT', [['prisons', 'Prisons', 'Prison records tab'], ['arrest', 'Arrest', 'Jail, release and arrests'], ['editincidents', 'Edit Incidents', 'Edit incident records']]],
    ['EXPUNGEMENTS', [['viewexpungements', 'View', 'See petitions'], ['requestexpungement', 'Request', 'File a petition'], ['approveexpungement', 'Approve', 'Rule on petitions']]],
    ['LEGAL — BAIL & APPEALS', [['viewbail', 'View Bail', 'See bail petitions'], ['requestbail', 'Request Bail', 'File bail'], ['approvebail', 'Approve Bail', 'Rule on bail'], ['viewappeals', 'View Appeals', 'See appeals'], ['requestappeal', 'Request Appeal', 'File an appeal'], ['approveappeal', 'Approve Appeal', 'Rule on appeals']]],
    ['LEGAL — CASE DEFENSE', [['viewdefense', 'View Defense', 'Defense threads'], ['assigndefense', 'Assign Defense', 'Appoint counsel'], ['filedefense', 'File Statements', 'Write in a defense thread'], ['firmledger', 'Firm Ledger', 'Firm ledger tab'], ['viewbarroster', 'Bar Roster', 'See the bar roster'], ['firelawyers', 'Fire Attorneys', 'Dismiss lower-ranked attorneys'], ['viewlawyerprofile', 'Attorney Profiles', "Open colleagues' profiles"], ['firmsettings', 'Firm Settings', 'Firm notice and name'], ['firmhome', 'Firm Office', 'Firm landing page']]],
    ['LEDGER', [['ledger', 'Ledger', 'See the ledger balance'], ['ledgerdeposit', 'Deposit', 'Deposit cash'], ['ledgerwithdraw', 'Withdraw', 'Withdraw cash']]],
    ['TIPS', [['viewtips', 'View Tips', 'Tips inbox'], ['deletetips', 'Delete Tips', 'Remove tips']]],
    ['ADMIN', [['settings', 'Department Settings', 'Settings tab'], ['managepermissions', 'Manage Permissions', 'This panel'], ['viewauditlog', 'View Audit Log', 'Audit log tab']]],
];
(function () {
    let root, q, listEl, panelEl, rows = [], current = null;
    async function load() {
        fill(listEl, loading());
        const r = await nui('getPermissionsLawmen', {}, 10000, []);
        rows = arr(r).sort((a, b) => (num(b.grade) - num(a.grade)) || str(a.name).localeCompare(str(b.name)));
        draw();
    }
    function draw() {
        if (!root) return;
        const t = q.value.trim().toLowerCase();
        const list = rows.filter((x) => !t || [x.name, x.rank, x.citizenid].some((v) => str(v).toLowerCase().includes(t)));
        fill(listEl, table([
            { label: T('ui_col_id', 'ID'), render: (x) => str(x.citizenid) },
            { label: T('ui_col_name', 'Name'), render: (x) => str(x.name) },
            { label: T('ui_rank', 'Rank'), render: (x) => str(x.rank) },
            { label: T('ui_region', 'Region'), render: (x) => str(x.region, '--') },
            { label: T('ui_col_overrides', 'Overrides'), render: (x) => Object.keys(x.overrides || {}).length ? badge(T('ui_overrides_up', 'OVERRIDES'), 'gold') : '—' },
        ], list, { onRow: (x) => openPanel(x), empty: emptyState(T('ui_no_profiles', 'No lawmen yet'), T('ui_profiles_first', 'Profiles must be created first'), 'shield') }));
    }
    function closePanel() { current = null; clear(panelEl); popLayer(panelEl); }
    function openPanel(x) {
        current = x;
        const self = str(x.citizenid) === str((App.player || {}).citizenid);
        const defaults = x.defaults || {}, overrides = Object.assign({}, x.overrides || {});
        const state = {};
        const groups = PermGroups().map(([g, items]) => h('div', { class: 'perm-group' }, h('div', { class: 'fsec-title' }, T('ui_permg_' + g.toLowerCase().replace(/[^a-z]+/g, '_'), g)), items.map(([key, label, desc]) => {
            const eff = overrides[key] !== undefined ? !!overrides[key] : !!defaults[key];
            state[key] = eff;
            const word = h('small', { class: 'perm-word' });
            const sw = h('input', { type: 'checkbox', class: 'switch', checked: eff, disabled: self && key === 'managepermissions' });
            const upd = () => { const isOv = state[key] !== !!defaults[key]; word.textContent = isOv ? T('ui_override_up', 'OVERRIDE') : T('ui_default_up', 'DEFAULT'); word.className = 'perm-word ' + (isOv ? 'tone-gold' : 'muted'); };
            sw.addEventListener('change', () => { state[key] = sw.checked; upd(); });
            upd();
            return h('label', { class: 'perm-row', title: self && key === 'managepermissions' ? T('ui_no_self_perm', 'You cannot change your own permissions access') : '' },
                h('div', null, h('b', null, T('ui_perm_' + key, label)), h('small', { class: 'muted' }, ' ' + T('ui_permd_' + key, desc))), word, sw);
        })));
        const saveB = h('button', { class: 'btn primary sm', type: 'button' }, T('ui_save', 'Save'));
        saveB.addEventListener('click', () => busy(saveB, T('ui_saving', 'Saving…'), async () => {
            const perms = {};
            for (const k in state) if (state[k] !== !!defaults[k]) perms[k] = state[k];
            if (self) delete perms.managepermissions;
            const r = await nui('saveLawmanPermissions', { citizenid: str(x.citizenid), lawman_name: str(x.name), permissions: perms }, 10000, null);
            notify(ok(r) ? T('ui_perms_saved', 'Permissions saved for %s', str(x.name)) : msgOf(r, T('ui_save_failed', 'Could not save')));
            if (ok(r)) { closePanel(); load(); }
        }));
        const resetB = h('button', { class: 'btn ghost sm', type: 'button', onclick: async () => {
            if (!(await confirmBox({ message: T('ui_reset_perms_q', 'Remove every override for %s?', str(x.name)), confirm: T('ui_reset_defaults', 'Reset Defaults'), danger: true }))) return;
            const r = await nui('resetLawmanPermissions', { citizenid: str(x.citizenid), lawman_name: str(x.name) }, 10000, null);
            notify(ok(r) ? T('ui_perms_reset', 'Overrides removed for %s', str(x.name)) : msgOf(r, T('ui_action_failed', 'That did not work')));
            if (ok(r)) { closePanel(); load(); }
        } }, T('ui_reset_defaults', 'Reset Defaults'));
        fill(panelEl, h('div', { class: 'side-sheet page-turn perm-panel' },
            h('div', { class: 'sheet-head' }, h('div', null, h('b', null, str(x.name)), h('div', { class: 'muted' }, str(x.rank) + ' · ' + str(x.region, '--'))),
                h('span', { class: 'spacer' }), saveB, resetB, h('button', { class: 'x', type: 'button', onclick: closePanel }, icon('close'))),
            h('p', { class: 'muted' }, T('ui_override_note', 'Overrides beat the job-grade defaults.')),
            groups));
        popLayer(panelEl); pushLayer(panelEl, closePanel);
    }
    regTab({
        id: 'permissions', icon: 'shield', perm: 'managepermissions', label: () => T('ui_nav_permissions', 'Permissions'),
        build: (r) => {
            root = r;
            q = inp({ placeholder: T('ui_search_perm', 'Search name, rank or ID…') });
            q.addEventListener('input', debounce(draw, 250));
            listEl = h('div'); panelEl = h('div', { class: 'perm-panel-wrap' });
            add(r, [h('h2', { class: 'page-title' }, T('ui_nav_permissions', 'Permissions')), h('div', { class: 'toolbar' }, q, plainRefresh(load)), listEl, panelEl]);
        },
        show: () => load(),
        reset: () => { root = null; rows = []; current = null; },
    });
})();

// ---------- Audit Log ----------
const AuditLawActions = () => [['report_saved', 'Report Saved'], ['report_deleted', 'Report Deleted'], ['bolo_created', 'Statement Created'], ['bolo_resolved', 'Statement Resolved'], ['bolo_deleted', 'Statement Deleted'],
    ['warrant_issued', 'Bounty Issued'], ['warrant_updated', 'Bounty Updated'], ['warrant_deleted', 'Bounty Deleted'], ['criminal_added', 'Criminal Added'], ['criminal_updated', 'Criminal Updated'], ['criminal_info_updated', 'Record Notes Updated'], ['criminal_deleted', 'Criminal Deleted'],
    ['arrest_made', 'Arrest Made'], ['fine_issued', 'Fine Issued'], ['case_created', 'Case Created'], ['case_updated', 'Case Updated'], ['case_deleted', 'Case Deleted'], ['evidence_item_added', 'Evidence Added'], ['evidence_deleted', 'Evidence Deleted'],
    ['lawman_updated', 'Lawman Updated'], ['mostwanted_added', 'Wanted Posted'], ['mostwanted_captured', 'Wanted Captured'], ['mostwanted_removed', 'Wanted Removed'],
    ['bulletin_created', 'Announcement Posted'], ['bulletin_deleted', 'Announcement Deleted'], ['settings_updated', 'Settings Updated'], ['permission_changed', 'Permission Changed'],
    ['expungement_requested', 'Expungement Filed'], ['expungement_approved', 'Expungement Approved'], ['expungement_denied', 'Expungement Denied'],
    ['bail_requested', 'Bail Requested'], ['bail_approved', 'Bail Approved'], ['bail_denied', 'Bail Denied'], ['bail_appeared', 'Court Appearance'], ['bail_skipped', 'Bail Skipped'],
    ['appeal_requested', 'Appeal Filed'], ['appeal_approved', 'Appeal Approved'], ['appeal_denied', 'Appeal Denied'],
    ['ledger_deposit', 'Ledger Deposit'], ['ledger_withdraw', 'Ledger Withdrawal'], ['duty_changed', 'Duty Changed']];
const AuditLawyerActions = () => [['bail_requested', 'Bail Requested'], ['bail_approved', 'Bail Approved'], ['bail_denied', 'Bail Denied'], ['bail_appeared', 'Court Appearance'], ['bail_skipped', 'Bail Skipped'],
    ['appeal_requested', 'Appeal Filed'], ['appeal_approved', 'Appeal Approved'], ['appeal_denied', 'Appeal Denied'], ['defense_assigned', 'Defense Assigned'], ['defense_unassigned', 'Defense Removed'], ['defense_statement', 'Statement Filed'],
    ['expungement_requested', 'Expungement Filed'], ['expungement_approved', 'Expungement Approved'], ['expungement_denied', 'Expungement Denied'],
    ['lawyer_ledger_deposit', 'Ledger Deposit'], ['lawyer_ledger_withdraw', 'Ledger Withdrawal'], ['lawyer_fired', 'Attorney Fired'], ['lawyer_firm_motd', 'Firm Notice'],
    ['lawyer_counsel_request', 'Counsel Requested'], ['lawyer_counsel_response', 'Counsel Answered'], ['lawyer_counsel_cancel', 'Counsel Dismissed'], ['duty_changed', 'Duty Changed']];
function auditIcon(action) {
    const a = str(action);
    const map = [['report', 'description', 'blue'], ['bolo', 'sticky_note_2', 'green'], ['warrant', 'balance', 'red'], ['criminal', 'person', 'orange'], ['arrest', 'gavel', 'red'], ['fine', 'payments', 'gold'],
        ['case', 'folder', 'purple'], ['evidence', 'inventory_2', 'teal'], ['lawman', 'badge', 'blue'], ['mostwanted', 'local_police', 'red'], ['bulletin', 'campaign', 'gold'], ['settings', 'settings', 'grey'],
        ['permission', 'shield', 'purple'], ['expungement', 'cleaning_services', 'teal'], ['bail', 'savings', 'green'], ['appeal', 'balance', 'blue'], ['defense', 'work', 'brown'],
        ['lawyer_ledger', 'account_balance', 'gold'], ['ledger', 'account_balance', 'gold'], ['lawyer', 'work', 'brown'], ['duty', 'schedule', 'grey']];
    const m = map.find(([p]) => a.startsWith(p)) || ['', 'history', 'grey'];
    return h('span', { class: 'round-ic tone-bg-' + m[2] }, icon(m[1]));
}
(function () {
    let root, actor, actionSel, listEl, page = 1, seq = 0;
    async function load(p) {
        page = p || page;
        const my = ++seq;
        fill(listEl, loading());
        const r = await nui('getAuditLog', { page, action: actionSel.value, actor: App.lawyer ? '' : actor.value.trim() }, 10000, []);
        if (my !== seq || !root) return;
        const rows = arr(r);
        const labels = Object.fromEntries((App.lawyer ? AuditLawyerActions() : AuditLawActions()).map(([k, l]) => [k, T('ui_audit_' + k, l)]));
        const groups = [];
        let last = null;
        const today = isoDay(new Date()), yest = isoDay(new Date(Date.now() - 86400000));
        for (const e of rows) {
            const d = isoDay(e.created_at);
            if (d !== last) { groups.push(h('div', { class: 'day-head' }, d === today ? T('ui_today', 'Today') : d === yest ? T('ui_yesterday', 'Yesterday') : fmtDate(e.created_at))); last = d; }
            groups.push(h('div', { class: 'audit-row', onclick: () => entry(e, labels) },
                auditIcon(e.action),
                h('div', { class: 'audit-main' }, h('div', null, str(e.details)), h('small', { class: 'muted' }, badge(labels[e.action] || str(e.action), 'grey'), ' ', str(e.actor_name), e.target_name ? ' → ' + str(e.target_name) : '')),
                h('small', { class: 'muted' }, fmtTime(e.created_at))));
        }
        fill(listEl, rows.length ? groups : emptyState(T('ui_no_audit', 'Actions will appear as lawmen use the MDT'), null, 'checklist'),
            h('div', { class: 'pager' },
                h('button', { class: 'btn ghost sm', type: 'button', disabled: page <= 1, onclick: () => load(page - 1) }, T('ui_prev', '« Prev')),
                h('span', { class: 'pager-t' }, T('ui_page_n', 'Page %d', page)),
                h('button', { class: 'btn ghost sm', type: 'button', disabled: rows.length < 50, onclick: () => load(page + 1) }, T('ui_next', 'Next »'))));
    }
    function entry(e, labels) {
        let meta = e.metadata;
        if (typeof meta === 'string') meta = parseJson(meta, { raw: meta });
        const m = modal({
            title: T('ui_audit_entry', 'Audit Entry #%s', str(e.id)), icon: 'checklist', backdropCloses: true,
            body: [h('div', { class: 'info-row' }, h('span', { class: 'lbl' }, T('ui_action', 'Action')), h('span', null, labels[e.action] || str(e.action))),
                h('div', { class: 'info-row' }, h('span', { class: 'lbl' }, T('ui_details', 'Details')), h('span', null, str(e.details))),
                h('div', { class: 'info-row' }, h('span', { class: 'lbl' }, T('ui_actor', 'Actor')), h('span', null, str(e.actor_name) + ' (' + str(e.actor_citizenid) + ')')),
                h('div', { class: 'info-row' }, h('span', { class: 'lbl' }, T('ui_target', 'Target')), h('span', null, e.target_name ? str(e.target_name) + (e.target_citizenid ? ' (' + str(e.target_citizenid) + ')' : '') : '—')),
                section(T('ui_metadata', 'Metadata'), meta && typeof meta === 'object' ? Object.keys(meta).map((k) => h('div', { class: 'info-row' }, h('span', { class: 'lbl' }, k), h('span', null, typeof meta[k] === 'object' ? JSON.stringify(meta[k]) : str(meta[k])))) : h('span', { class: 'muted' }, '—')),
                h('div', { class: 'info-row' }, h('span', { class: 'lbl' }, T('ui_timestamp', 'Timestamp')), h('span', null, fmtDateTime(e.created_at)))],
            footer: [h('button', { class: 'btn ghost', type: 'button', onclick: () => m.close() }, T('ui_close', 'Close'))],
        });
    }
    regTab({
        id: 'audit', icon: 'checklist', perm: 'viewauditlog', label: () => T('ui_nav_audit', 'Audit Log'),
        build: (r) => {
            root = r;
            actor = inp({ placeholder: T('ui_filter_actor', 'Filter by name…') });
            actor.addEventListener('input', debounce(() => load(1), 400));
            actionSel = sel([['', T('ui_all_actions', 'All actions')]].concat((App.lawyer ? AuditLawyerActions() : AuditLawActions()).map(([k, l]) => [k, T('ui_audit_' + k, l)])), '');
            actionSel.addEventListener('change', () => load(1));
            listEl = h('div', { class: 'audit-list' });
            add(r, [h('h2', { class: 'page-title' }, T('ui_nav_audit', 'Audit Log')), h('div', { class: 'toolbar' }, App.lawyer ? null : actor, actionSel, plainRefresh(() => load())), listEl]);
        },
        show: () => load(1),
        reset: () => { root = null; page = 1; },
    });
})();

// ---------- Department Settings ----------
const FeatureSwitches = () => [['feature_reports', T('ui_nav_reports', 'Incident Reports')], ['feature_bolos', T('ui_nav_statements', 'Witness Statements')], ['feature_warrants', T('ui_nav_bounties', 'Bounties')],
    ['feature_fines', T('ui_nav_citations', 'Citations')], ['feature_evidences', T('ui_feat_evidence', 'Evidence / Cases')], ['feature_tips', T('ui_feat_tips', 'Citizen Tips')],
    ['feature_expungements', T('ui_nav_expungements', 'Expungements')], ['feature_prisons', T('ui_nav_prisons', 'Prison Records')], ['feature_prisonregister', T('ui_feat_register', 'Prison Register Board')]];
(function () {
    let root, cfgEl, annEl, ledgerEl, postBtn;
    async function loadSettings() {
        if (!can('createlawmen') || App.lawyer) { clear(cfgEl); return; }
        const s = await nui('getMdtSettings', {}, 8000, null);
        // denied or timed out: never draw switches from defaults that a save would push back
        if (!s || s.denied || s.success === false) { fill(cfgEl, emptyState(msgOf(s, T('ui_load_failed', 'Could not load')), null, 'error')); return; }
        const boxes = FeatureSwitches().map(([k, l]) => ({ k, box: h('input', { type: 'checkbox', class: 'switch', checked: !(s[k] === false || s[k] === 0 || s[k] === '0' || s[k] === 'false') }), l }));
        const saveB = h('button', { class: 'btn primary', type: 'button' }, T('ui_save_config', 'Save Configuration'));
        saveB.addEventListener('click', () => busy(saveB, T('ui_saving', 'Saving…'), async () => {
            const p = {};
            boxes.forEach((b) => { p[b.k] = b.box.checked; });
            const r = await nui('saveMdtSettings', p, 8000, null);
            notify(ok(r) ? msgOf(r, T('ui_settings_saved', 'Department settings saved')) : msgOf(r, T('ui_save_failed', 'Could not save')));
            if (ok(r)) { App.settings = Object.assign({}, App.settings, r.settings || p); if (App.player) App.player.settings = App.settings; App.recheckTabs(); }
        }));
        fill(cfgEl, h('div', { class: 'card' },
            h('div', { class: 'fsec-title' }, T('ui_dept_config', 'Department Configuration'), ' ', badge(T('ui_command_only', 'COMMAND ONLY'), 'red')),
            h('div', { class: 'switch-grid' }, boxes.map((b) => h('label', { class: 'perm-row' }, h('b', null, b.l), b.box))),
            h('div', { class: 'frow end' }, saveB)));
    }
    async function loadBulletins() {
        fill(annEl, loading());
        const r = await nui('getBulletins', {}, 8000, []);
        const b = arr(r)[0];
        const canPost = can('createlawmen') && !App.lawyer;
        fill(annEl, h('div', { class: 'card' }, h('div', { class: 'fsec-title' }, T('ui_current_announcement', 'Current Announcement')),
            b ? h('div', { class: 'banner' + (b.type === 'urgent' ? ' urgent' : '') },
                h('div', null, b.type === 'urgent' ? badge(T('ui_urgent', 'URGENT'), 'red') : null, h('b', null, ' ', str(b.title)), h('p', { class: 'pre' }, str(b.content)),
                    h('small', null, T('ui_posted_by_dot', 'Posted by %s • %s', str(b.posted_by_name, '—'), fmtDate(b.created_at)))),
                canPost ? iconBtn('delete', T('ui_delete', 'Delete'), async () => {
                    if (!(await confirmBox({ message: T('ui_delete_announcement_q', 'Take down this announcement?'), confirm: T('ui_delete', 'Delete'), danger: true }))) return;
                    const res = await nui('deleteBulletin', { id: num(b.id) }, 5000, null);
                    notify(ok(res) ? T('ui_announcement_deleted', 'Announcement deleted') : msgOf(res, T('ui_delete_failed', 'Could not delete')));
                    if (ok(res)) loadBulletins();
                }) : null)
                : h('div', { class: 'muted' }, T('ui_no_announcement', 'No announcement is posted.'))));
    }
    function post() {
        const title = inp({ maxlength: 100 });
        const content = area({ rows: 5, maxlength: 2000 });
        const urgent = h('input', { type: 'checkbox' });
        const go = h('button', { class: 'btn primary', type: 'button' }, T('ui_post', 'Post'));
        const m = modal({
            title: T('ui_post_announcement', 'Post Announcement'), icon: 'campaign',
            body: [field(T('ui_col_title', 'Title') + ' *', title), field(T('ui_content', 'Content') + ' *', content), h('label', { class: 'check' }, urgent, ' ', T('ui_mark_urgent', 'Mark as urgent')), h('small', { class: 'muted' }, T('ui_replaces_current', 'Posting replaces the current announcement.'))],
            footer: [h('button', { class: 'btn ghost', type: 'button', onclick: () => m.close() }, T('ui_cancel', 'Cancel')), go],
        });
        go.addEventListener('click', () => busy(go, null, async () => {
            if (!title.value.trim() || !content.value.trim()) { notify(T('ui_title_content_required', 'Title and content are required')); return; }
            const r = await nui('createBulletin', { title: title.value.trim(), content: content.value.trim(), type: urgent.checked ? 'urgent' : 'general' }, 8000, null);
            notify(ok(r) ? T('ui_announcement_posted', 'Announcement posted!') : msgOf(r, T('ui_save_failed', 'Could not save')));
            if (ok(r)) { m.close(true); loadBulletins(); }
        }));
    }
    regTab({
        id: 'settings', icon: 'settings', perm: 'settings', label: () => T('ui_nav_settings', 'Settings'),
        build: (r) => {
            root = r;
            cfgEl = h('div'); annEl = h('div'); ledgerEl = h('div');
            postBtn = can('createlawmen') && !App.lawyer ? h('button', { class: 'btn primary sm', type: 'button', onclick: post }, icon('campaign'), T('ui_post_announcement', 'Post Announcement')) : null;
            add(r, [h('div', { class: 'toolbar' }, h('div', null, h('h2', { class: 'page-title' }, T('ui_dept_settings', 'Department Settings')), h('small', { class: 'muted' }, T('ui_settings_sub', 'Bulletins, MOTD and department announcements'))), h('span', { class: 'spacer' }), postBtn),
                cfgEl, ledgerEl, annEl]);
        },
        show: () => {
            loadSettings();
            loadBulletins();
            if (can('ledger')) fill(ledgerEl, ledgerCard(false)); else clear(ledgerEl);
        },
        reset: () => { root = null; },
    });
})();
