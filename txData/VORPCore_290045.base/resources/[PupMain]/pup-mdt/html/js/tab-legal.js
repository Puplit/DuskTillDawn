'use strict';
// Legal side: Expungements, Bail & Bond, Sentence Appeals, Case Defense.

function legalStatusTone(s) {
    return { pending: 'gold', approved: 'green', denied: 'red', processing: 'grey', active: 'green', appeared: 'teal', skipped: 'red' }[str(s)] || 'grey';
}
function legalStatusLabel(s) {
    const m = { pending: T('ui_ls_pending', 'Pending'), approved: T('ui_ls_approved', 'Approved'), denied: T('ui_ls_denied', 'Denied'), processing: T('ui_ls_processing', 'Processing'),
        active: T('ui_ls_active', 'Out on bail'), appeared: T('ui_ls_appeared', 'Appeared'), skipped: T('ui_ls_skipped', 'Skipped') };
    return m[str(s)] || str(s, '—');
}
function reviewedTitle(x) { return x.reviewed_by_name ? str(x.reviewed_by_name) + (x.review_notes ? ' — ' + str(x.review_notes) : '') : ''; }
// Generic list page with a toolbar (search + status filter + action button) and server paging.
function legalList(o) {
    const st = { root: null, page: 1, seq: 0, data: null };
    st.q = inp({ placeholder: o.searchPlaceholder || T('ui_search_name_id', 'Search name or identity…') });
    st.sel = sel(o.statuses, '');
    st.list = h('div');
    st.formWrap = h('div');
    st.load = async (p) => {
        st.page = p || st.page;
        const my = ++st.seq;
        fill(st.list, loading());
        const r = await nui(o.getName, { page: st.page, status: st.sel.value, search: st.q.value.trim() }, 8000, null);
        if (my !== st.seq || !st.root) return;
        st.data = r || {};
        fill(st.list, table(o.cols(st), arr(st.data[o.key]), { empty: emptyState(T('ui_nothing_here', 'Nothing here'), null, o.icon) }),
            pager(st.page, st.data.totalPages, st.data.totalRecords, st.load));
    };
    st.closeForm = () => { clear(st.formWrap); popLayer(st.formWrap); };
    st.openForm = (el) => { fill(st.formWrap, h('div', { class: 'inline-form page-turn' }, el)); popLayer(st.formWrap); pushLayer(st.formWrap, st.closeForm); };
    st.q.addEventListener('input', debounce(() => st.load(1), 300));
    st.sel.addEventListener('change', () => st.load(1));
    regTab({
        id: o.id, icon: o.icon, perm: o.perm, feature: o.feature, label: o.label,
        build: (r) => {
            st.root = r;
            add(r, [h('h2', { class: 'page-title' }, o.label()),
                h('div', { class: 'toolbar' }, st.q, st.sel, o.button ? o.button(st) : null, plainRefresh(() => st.load())),
                st.formWrap, st.list]);
        },
        show: (opts) => { st.load(st.page); if (opts && opts.openForm && o.formFn) o.formFn(st); },
        reset: () => { st.root = null; st.page = 1; st.data = null; },
        push: () => { if (st.root && App.current === o.id) st.load(); },
    });
    return st;
}
async function legalAction(st, name, payload, confirmMsg, okMsg, withReason, danger) {
    const ans = await confirmBox({ message: confirmMsg, reason: withReason, confirm: T('ui_confirm', 'Confirm'), danger });
    if (!ans) return null;
    if (withReason) payload.notes = ans.reason || '';
    const r = await nui(name, payload, 8000, null);
    notify(ok(r) ? (typeof okMsg === 'function' ? okMsg(r) : okMsg) : msgOf(r, T('ui_action_failed', 'That did not work')));
    if (ok(r)) st.load();
    return r;
}

// ---------- Expungements ----------
(function () {
    const st = legalList({
        id: 'expungements', icon: 'cleaning_services', perm: 'viewexpungements', feature: 'feature_expungements', label: () => T('ui_nav_expungements', 'Expungements'), key: 'expungements',
        getName: 'getExpungements',
        statuses: [['', T('ui_all', 'All')], ['pending', T('ui_ls_pending', 'Pending')], ['approved', T('ui_ls_approved_hist', 'Approved (history)')], ['denied', T('ui_ls_denied', 'Denied')]],
        button: (s) => can('requestexpungement') ? h('button', { class: 'btn primary sm', type: 'button', onclick: () => form(s) }, icon('add'), T('ui_request_expungement', 'Request Expungement')) : null,
        formFn: (s) => form(s),
        cols: (s) => [
            { label: '#', render: (x) => String(x.id) },
            { label: T('ui_col_citizen', 'Citizen'), render: (x) => str(x.citizen_name) + ' (' + str(x.citizen_identity) + ')' },
            { label: T('ui_col_status', 'Status'), render: (x) => { const b = badge(legalStatusLabel(x.status), legalStatusTone(x.status)); const t = reviewedTitle(x); if (t) b.title = t; return b; } },
            { label: T('ui_requested_by', 'Requested By'), render: (x) => str(x.requested_by_name, '—') },
            { label: T('ui_col_requested', 'Requested'), render: (x) => fmtDate(x.requested_at) },
            { label: '', cls: 'act', render: (x) => [
                x.status === 'approved' ? iconBtn('visibility', T('ui_view_cleared', 'View cleared record'), () => record(x.id, false)) : iconBtn('preview', T('ui_preview_clear', 'Preview what would be cleared'), () => record(x.id, true)),
                x.status === 'pending' && can('approveexpungement') ? iconBtn('check', T('ui_approve', 'Approve'), () => legalAction(s, 'approveExpungement', { id: num(x.id) },
                    T('ui_approve_exp_q', 'Approve the expungement for %s? Their records are permanently cleared; only a tally is kept.', str(x.citizen_name)), (r) => T('ui_records_cleared_n', 'Records cleared (%d rows)', num(r.recordsCleared)), false, true)) : null,
                x.status === 'pending' && can('approveexpungement') ? iconBtn('close', T('ui_deny', 'Deny'), () => legalAction(s, 'denyExpungement', { id: num(x.id) },
                    T('ui_deny_q', 'Deny this petition for %s?', str(x.citizen_name)), T('ui_petition_denied', 'Petition denied'), true, true)) : null] },
        ],
    });
    function form(s) {
        const cid = inp({ placeholder: T('ui_citizen_id', 'Citizen ID') });
        const name = inp({ readOnly: true });
        const look = lookLine();
        const reason = area({ rows: 3, maxlength: 1000 });
        let found = null;
        watchLookup(cid, 400, (v) => nui('lookupExpungementCitizen', { citizenIdentity: v }, 8000, null), (r, v) => {
            found = null; name.value = '';
            if (r === undefined) setLook(look, T('ui_looking_up', 'Looking up…'));
            else if (!v) setLook(look, '');
            else if (!r || !r.found) setLook(look, T('ui_no_player_found', 'No player found'), 'red');
            else { name.value = str(r.name); if (r.hasRecord) { found = r; setLook(look, T('ui_exp_eligible', '%s — record found, eligible', str(r.name)), 'green'); } else setLook(look, T('ui_exp_no_record', '%s — has no record', str(r.name)), 'red'); }
        });
        const submit = h('button', { class: 'btn primary', type: 'button' }, T('ui_submit', 'Submit'));
        submit.addEventListener('click', () => busy(submit, null, async () => {
            if (!found) { notify(T('ui_need_found_record', 'Look up a citizen who has a record first')); return; }
            const r = await nui('requestExpungement', { citizenIdentity: cid.value.trim(), citizenName: name.value, reason: reason.value.trim() }, 8000, null);
            notify(ok(r) ? msgOf(r, T('ui_petition_filed', 'Petition filed')) : msgOf(r, T('ui_save_failed', 'Could not save')));
            if (ok(r)) { s.closeForm(); s.load(1); }
        }));
        s.openForm([h('div', { class: 'fsec-title' }, T('ui_request_expungement', 'Request Expungement')),
            row(field(T('ui_citizen_id', 'Citizen ID') + ' *', cid), field(T('ui_col_name', 'Name'), name)), look,
            field(T('ui_reason', 'Reason'), reason),
            h('div', { class: 'frow end' }, h('button', { class: 'btn ghost', type: 'button', onclick: s.closeForm }, T('ui_cancel', 'Cancel')), submit)]);
        setTimeout(() => cid.focus(), 30);
    }
    function snapSections(snap, cap) {
        const out = [];
        const names = { mdt_criminals: T('ui_sec_profile', 'Criminal Profile'), criminal: T('ui_sec_profile', 'Criminal Profile'), mdt_arrests: T('ui_sec_arrests', 'Arrest Records'), arrests: T('ui_sec_arrests', 'Arrest Records'),
            mdt_reports_warrants: T('ui_bounties', 'Bounties'), warrants: T('ui_bounties', 'Bounties'), mdt_reports_charges: T('ui_charges', 'Charges'), charges: T('ui_charges', 'Charges'),
            mdt_prison_records: T('ui_sec_prison', 'Prison Records'), prison: T('ui_sec_prison', 'Prison Records') };
        for (const k of Object.keys(snap || {})) {
            const v = snap[k];
            if (!v || typeof v !== 'object' || k === 'tally' || k === 'summary') continue;
            const list = Array.isArray(v) ? v : (Array.isArray(v.rows) ? v.rows : [v]);
            if (!list.length || typeof list[0] !== 'object') continue;
            const det = h('details', { class: 'snap-sec' }, h('summary', null, (names[k] || k) + ' (' + list.length + ')'),
                list.slice(0, cap || 100).map((rowObj) => h('div', { class: 'snap-card' }, Object.keys(rowObj || {}).map((f) => h('div', { class: 'info-row' }, h('span', { class: 'lbl' }, f), h('span', null, typeof rowObj[f] === 'object' ? JSON.stringify(rowObj[f]) : str(rowObj[f])))))));
            out.push(det);
        }
        return out;
    }
    function record(id, preview) {
        const body = h('div', null, loading());
        modal({ title: preview ? T('ui_records_to_clear', 'Records to be cleared') : T('ui_cleared_records', 'Cleared Records'), icon: 'cleaning_services', cls: 'wide', body, backdropCloses: true });
        nui(preview ? 'getExpungementPreview' : 'getExpungementSnapshot', { id: num(id) }, 8000, null).then((r) => {
            if (!body.isConnected) return;
            if (!r || r.success === false) { fill(body, emptyState(msgOf(r, T('ui_load_failed', 'Could not load')), null, 'error')); return; }
            const s = r.snapshot || {};
            const snap = s.snapshot || {};
            const t = snapshotTally(s);
            const anything = Object.keys(snap).some((k) => snapCount(snap[k]) > 0);
            if (preview && !anything) { fill(body, emptyState(T('ui_nothing_to_clear', 'No records to clear'), null, 'check_circle')); return; }
            fill(body,
                h('h3', null, str(s.citizenName) + ' (' + str(s.citizenIdentity) + ')'),
                h('div', { class: 'notice' }, preview ? T('ui_preview_notice', 'These records still exist. Approving the petition deletes them.') : T('ui_cleared_notice', 'These records were deleted; only this tally remains.')),
                preview && s.capped ? h('small', { class: 'muted' }, T('ui_cap_note', 'Showing at most %d rows per category.', num(s.rowCap, 100))) : null,
                tallyTiles(t),
                h('div', { class: 'tags' }, t.chargeList.slice(0, 40).map((x) => h('span', { class: 'tag' }, str(x.label || x.name || x.code), ' ×' + num(x.count, 1)))),
                snapSections(snap, num(s.rowCap, 100)));
        });
    }
})();

// ---------- Bail & Bond ----------
(function () {
    const st = legalList({
        id: 'bail', icon: 'savings', perm: 'viewbail', label: () => T('ui_nav_bail', 'Bail'), key: 'bail', getName: 'getBail',
        statuses: [['', T('ui_all', 'All')], ['pending', T('ui_ls_pending', 'Pending')], ['processing', T('ui_ls_processing', 'Processing')], ['active', T('ui_ls_active', 'Out on bail')], ['appeared', T('ui_ls_appeared', 'Appeared')], ['skipped', T('ui_ls_skipped', 'Skipped')], ['denied', T('ui_ls_denied', 'Denied')]],
        button: (s) => can('requestbail') ? h('button', { class: 'btn primary sm', type: 'button', onclick: () => form(s) }, icon('add'), T('ui_file_bail', 'File Bail Petition')) : null,
        formFn: (s) => form(s),
        cols: (s) => [
            { label: '#', render: (x) => String(x.id) },
            { label: T('ui_col_citizen', 'Citizen'), render: (x) => str(x.citizen_name) + ' (' + str(x.citizen_identity) + ')' },
            { label: T('ui_amount', 'Amount'), render: (x) => h('b', null, money(x.amount)) },
            { label: T('ui_col_status', 'Status'), render: (x) => {
                const b = badge(legalStatusLabel(x.status), legalStatusTone(x.status));
                if (x.status === 'active' && x.court_due) b.title = T('ui_court_due', 'Court due: %s', fmtDateTime(x.court_due)); else { const t = reviewedTitle(x); if (t) b.title = t; }
                return b;
            } },
            { label: T('ui_requested_by', 'Requested By'), render: (x) => str(x.requested_by_name, '—') },
            { label: '', cls: 'act', render: (x) => {
                if (!(s.data && s.data.canApprove)) return null;
                if (x.status === 'pending') return [
                    iconBtn('check', T('ui_approve_release', 'Approve & release'), () => legalAction(s, 'approveBail', { id: num(x.id) }, T('ui_approve_bail_q', 'Approve bail for %s? The client pays %s and is released with a court date.', str(x.citizen_name), money(x.amount)), T('ui_bail_posted', 'Bail posted — client released.'), false, false)),
                    iconBtn('close', T('ui_deny', 'Deny'), () => legalAction(s, 'denyBail', { id: num(x.id) }, T('ui_deny_q', 'Deny this petition for %s?', str(x.citizen_name)), T('ui_petition_denied', 'Petition denied'), true, true))];
                if (x.status === 'active') return [
                    iconBtn('how_to_reg', T('ui_mark_appeared', 'Mark appeared'), () => legalAction(s, 'resolveBail', { id: num(x.id), outcome: 'appeared' }, T('ui_appeared_q', 'Mark %s as appeared in court? This closes the case.', str(x.citizen_name)), T('ui_bail_closed', 'Bail closed'), false, false)),
                    iconBtn('directions_run', T('ui_mark_skipped', 'Mark skipped'), () => legalAction(s, 'resolveBail', { id: num(x.id), outcome: 'skipped' }, T('ui_skipped_q', 'Mark %s as skipped? The bail is forfeit, the rest of the sentence is re-imposed and they are wanted again.', str(x.citizen_name)), T('ui_bail_forfeit', 'Bail forfeit'), false, true))];
                return null;
            } },
        ],
    });
    function form(s) {
        const cid = inp({ placeholder: T('ui_citizen_id', 'Citizen ID') });
        const look = lookLine();
        const amount = numInp({ value: 0 });
        const reason = area({ rows: 3, maxlength: 1000 });
        let found = null;
        watchLookup(cid, 400, (v) => nui('lookupBailPrisoner', { citizenIdentity: v }, 8000, null), (r, v) => {
            found = null;
            if (r === undefined) setLook(look, T('ui_looking_up', 'Looking up…'));
            else if (!v) setLook(look, '');
            else if (!r || !r.found) setLook(look, T('ui_no_jailed_found', 'No jailed player found'), 'red');
            else if (r.alreadyHasBail) setLook(look, T('ui_already_bail', '%s already has a pending or active bail', str(r.name)), 'red');
            else { found = r; setLook(look, T('ui_bail_eligible', '%s — %d min left. Eligible for bail.', str(r.name), num(r.remainingMinutes)), 'green'); }
        });
        const submit = h('button', { class: 'btn primary', type: 'button' }, T('ui_submit', 'Submit'));
        submit.addEventListener('click', () => busy(submit, null, async () => {
            if (!found) { notify(T('ui_need_jailed', 'Look up an eligible prisoner first')); return; }
            if (num(amount.value) < 0) { notify(T('ui_no_negative', 'Values cannot be negative')); return; }
            const r = await nui('requestBail', { citizenIdentity: cid.value.trim(), citizenName: str(found.name), amount: Math.floor(num(amount.value)), reason: reason.value.trim() }, 8000, null);
            notify(ok(r) ? msgOf(r, T('ui_petition_filed', 'Petition filed')) : msgOf(r, T('ui_save_failed', 'Could not save')));
            if (ok(r)) { s.closeForm(); s.load(1); }
        }));
        s.openForm([h('div', { class: 'fsec-title' }, T('ui_file_bail', 'File Bail Petition')),
            field(T('ui_prisoner_id', 'Prisoner Citizen ID') + ' *', cid), look,
            field(T('ui_bail_amount', 'Bail amount ($)'), amount), field(T('ui_reason', 'Reason'), reason),
            h('div', { class: 'frow end' }, h('button', { class: 'btn ghost', type: 'button', onclick: s.closeForm }, T('ui_cancel', 'Cancel')), submit)]);
        setTimeout(() => cid.focus(), 30);
    }
})();

// ---------- Sentence Appeals ----------
(function () {
    const st = legalList({
        id: 'appeals', icon: 'balance', perm: 'viewappeals', label: () => T('ui_nav_appeals', 'Appeals'), key: 'appeals', getName: 'getAppeals',
        statuses: [['', T('ui_all', 'All')], ['pending', T('ui_ls_pending', 'Pending')], ['approved', T('ui_ls_approved', 'Approved')], ['denied', T('ui_ls_denied', 'Denied')]],
        button: (s) => can('requestappeal') ? h('button', { class: 'btn primary sm', type: 'button', onclick: () => form(s) }, icon('add'), T('ui_file_appeal', 'File Appeal')) : null,
        formFn: (s) => form(s),
        cols: (s) => [
            { label: '#', render: (x) => String(x.id) },
            { label: T('ui_col_citizen', 'Citizen'), render: (x) => str(x.citizen_name) + ' (' + str(x.citizen_identity) + ')' },
            { label: T('ui_col_motion', 'Motion'), render: (x) => {
                const commute = !!(x.commute && x.commute !== 0 && x.commute !== '0');
                if (x.status === 'approved') {
                    const red = num(x.minutes_reduced);
                    return h('b', null, commute || red <= 0 ? T('ui_commuted', 'Commuted') : T('ui_minus_min', '-%d min', red));
                }
                return commute ? T('ui_commute', 'Commute') : T('ui_minus_min', '-%d min', num(x.reduction_minutes));
            } },
            { label: T('ui_col_status', 'Status'), render: (x) => { const b = badge(legalStatusLabel(x.status), legalStatusTone(x.status)); const t = reviewedTitle(x); if (t) b.title = t; return b; } },
            { label: T('ui_requested_by', 'Requested By'), render: (x) => str(x.requested_by_name, '—') },
            { label: '', cls: 'act', render: (x) => (x.status === 'pending' && s.data && s.data.canApprove) ? [
                iconBtn('check', T('ui_approve', 'Approve'), () => legalAction(s, 'approveAppeal', { id: num(x.id) }, T('ui_approve_appeal_q', 'Grant the appeal for %s?', str(x.citizen_name)),
                    (r) => (r.released ? T('ui_commuted_released', 'Commuted — prisoner released') : T('ui_reduced_by', 'Sentence reduced by %d min', num(r.minutesReduced))), false, false)),
                iconBtn('close', T('ui_deny', 'Deny'), () => legalAction(s, 'denyAppeal', { id: num(x.id) }, T('ui_deny_q', 'Deny this petition for %s?', str(x.citizen_name)), T('ui_petition_denied', 'Petition denied'), true, true))] : null },
        ],
    });
    function form(s) {
        const cid = inp({ placeholder: T('ui_citizen_id', 'Citizen ID') });
        const look = lookLine();
        const minutes = numInp({ min: 1, value: 1 });
        const commute = h('input', { type: 'checkbox' });
        commute.addEventListener('change', () => { minutes.disabled = commute.checked; });
        const reason = area({ rows: 3, maxlength: 1000 });
        let found = null;
        watchLookup(cid, 400, (v) => nui('lookupAppealPrisoner', { citizenIdentity: v }, 8000, null), (r, v) => {
            found = null;
            if (r === undefined) setLook(look, T('ui_looking_up', 'Looking up…'));
            else if (!v) setLook(look, '');
            else if (!r || !r.found) setLook(look, T('ui_no_jailed_found', 'No jailed player found'), 'red');
            else if (r.alreadyPending) setLook(look, T('ui_already_appeal', '%s already has a pending appeal', str(r.name)), 'red');
            else { found = r; setLook(look, T('ui_appeal_eligible', '%s — %d min left. Eligible.', str(r.name), num(r.remainingMinutes)), 'green'); }
        });
        const submit = h('button', { class: 'btn primary', type: 'button' }, T('ui_submit', 'Submit'));
        submit.addEventListener('click', () => busy(submit, null, async () => {
            if (!found) { notify(T('ui_need_jailed', 'Look up an eligible prisoner first')); return; }
            if (!commute.checked && Math.floor(num(minutes.value)) < 1) { notify(T('ui_minutes_or_commute', 'Enter minutes to reduce, or tick Commute')); return; }
            const r = await nui('requestAppeal', { citizenIdentity: cid.value.trim(), citizenName: str(found.name), reductionMinutes: commute.checked ? 0 : Math.floor(num(minutes.value)), commute: commute.checked, reason: reason.value.trim() }, 8000, null);
            notify(ok(r) ? msgOf(r, T('ui_appeal_filed', 'Appeal filed')) : msgOf(r, T('ui_save_failed', 'Could not save')));
            if (ok(r)) { s.closeForm(); s.load(1); }
        }));
        s.openForm([h('div', { class: 'fsec-title' }, T('ui_file_appeal', 'File Appeal')),
            field(T('ui_prisoner_id', 'Prisoner Citizen ID') + ' *', cid), look,
            row(field(T('ui_minutes_reduce', 'Minutes to reduce'), minutes), h('label', { class: 'check' }, commute, ' ', T('ui_commute_full', 'Commute — release the client entirely'))),
            field(T('ui_grounds', 'Grounds'), reason),
            h('div', { class: 'frow end' }, h('button', { class: 'btn ghost', type: 'button', onclick: s.closeForm }, T('ui_cancel', 'Cancel')), submit)]);
        setTimeout(() => cid.focus(), 30);
    }
})();

// ---------- Case Defense ----------
(function () {
    let root, q, listWrap, formWrap, data = null, seq = 0, brief = null;
    async function load() {
        const my = ++seq;
        fill(listWrap, loading());
        const r = await nui('getDefenseCases', { search: q.value.trim() }, 8000, null);
        if (my !== seq || !root) return;
        data = r || {};
        assignBtn.classList.toggle('hidden', !data.canAssign);
        if (brief) return;
        fill(listWrap, table([
            { label: T('ui_col_case', 'Case'), render: (x) => str(x.case_number) },
            { label: T('ui_col_title', 'Title'), render: (x) => str(x.title) },
            { label: T('ui_col_status', 'Status'), render: (x) => badge(labelOf(CaseStatus(), x.case_status), caseStatusTone(x.case_status)) },
            { label: T('ui_col_defense', 'Defense Lawyer'), render: (x) => str(x.lawyer_name) },
            { label: T('ui_col_statements', 'Statements'), render: (x) => String(num(x.statement_count)) },
            { label: '', cls: 'act', render: (x) => [iconBtn('menu_book', T('ui_open_brief', 'Open brief'), () => openBrief(x)),
                data.canAssign ? iconBtn('person_remove', T('ui_remove', 'Remove'), async () => {
                    if (!(await confirmBox({ message: T('ui_unassign_q', 'Remove %s from %s? Filed statements stay on record.', str(x.lawyer_name), str(x.case_number)), confirm: T('ui_remove', 'Remove'), danger: true }))) return;
                    const res = await nui('unassignDefense', { id: num(x.id) }, 8000, null);
                    notify(ok(res) ? T('ui_defense_removed', 'Defense removed') : msgOf(res, T('ui_action_failed', 'That did not work')));
                    if (ok(res)) load();
                }) : null] },
        ], arr(data.cases).slice(0, 100), { onRow: (x) => openBrief(x), empty: emptyState(T('ui_no_defense', 'No defense assignments'), null, 'work') }));
    }
    let assignBtn;
    function assignForm() {
        const cnum = inp({ placeholder: 'CASE-1899-0001' });
        const clook = lookLine();
        const lid = inp({ placeholder: T('ui_citizen_id', 'Citizen ID') });
        const llook = lookLine();
        let fc = null, fl = null;
        watchLookup(cnum, 400, (v) => nui('lookupDefenseCase', { caseNumber: v }, 8000, null), (r, v) => {
            fc = null;
            if (r === undefined) setLook(clook, T('ui_looking_up', 'Looking up…'));
            else if (!v) setLook(clook, '');
            else if (r && r.found) { fc = r; setLook(clook, str(r.caseNumber) + ' — ' + str(r.title) + ' (' + str(r.status) + ')', 'green'); }
            else setLook(clook, T('ui_no_case_found', 'No case found'), 'red');
        });
        watchLookup(lid, 400, (v) => nui('lookupDefenseLawyer', { citizenIdentity: v }, 8000, null), (r, v) => {
            fl = null;
            if (r === undefined) setLook(llook, T('ui_looking_up', 'Looking up…'));
            else if (!v) setLook(llook, '');
            else if (r && r.found) { fl = r; setLook(llook, T('ui_will_assign', '%s — will be assigned as defense', str(r.name)), 'green'); }
            else setLook(llook, msgOf(r, T('ui_no_lawyer_found', 'No attorney with that ID')), 'red');
        });
        const close = () => { clear(formWrap); popLayer(formWrap); };
        const go = h('button', { class: 'btn primary', type: 'button' }, T('ui_assign', 'Assign'));
        go.addEventListener('click', () => busy(go, null, async () => {
            if (!fc || !fl) { notify(T('ui_need_both', 'Both lookups must succeed first')); return; }
            const r = await nui('assignDefense', { caseId: num(fc.caseId), caseNumber: str(fc.caseNumber), lawyerCitizenId: str(fl.citizenid), lawyerName: str(fl.name) }, 8000, null);
            notify(ok(r) ? T('ui_defense_assigned', 'Defense assigned') : msgOf(r, T('ui_action_failed', 'That did not work')));
            if (ok(r)) { close(); load(); }
        }));
        fill(formWrap, h('div', { class: 'inline-form page-turn' }, h('div', { class: 'fsec-title' }, T('ui_assign_defense', 'Assign Defense')),
            field(T('ui_case_number', 'Case number'), cnum), clook, field(T('ui_lawyer_id', "Lawyer's Citizen ID"), lid), llook,
            h('div', { class: 'frow end' }, h('button', { class: 'btn ghost', type: 'button', onclick: close }, T('ui_cancel', 'Cancel')), go)));
        popLayer(formWrap); pushLayer(formWrap, close);
    }
    function closeBrief() { brief = null; popLayer(listWrap); load(); }
    async function openBrief(x) {
        brief = x;
        popLayer(listWrap); pushLayer(listWrap, closeBrief);
        fill(listWrap, loading());
        const r = await nui('getDefenseCaseDetail', { caseId: num(x.case_id) }, 8000, null);
        if (brief !== x) return;
        if (!ok(r)) { fill(listWrap, h('button', { class: 'btn ghost sm', type: 'button', onclick: closeBrief }, icon('arrow_back'), T('ui_back', 'Back')), emptyState(msgOf(r, T('ui_load_failed', 'Could not load')), null, 'error')); return; }
        const d = r.detail || {};
        const ci = d.caseInfo || {};
        const stmt = area({ rows: 4, maxlength: 4000 });
        const fileB = h('button', { class: 'btn primary', type: 'button' }, T('ui_file_statement', 'File Statement'));
        fileB.addEventListener('click', () => busy(fileB, null, async () => {
            const t = stmt.value.trim();
            if (!t) { notify(T('ui_statement_empty', 'Write a statement first')); return; }
            const res = await nui('fileDefenseStatement', { caseId: num(x.case_id), statement: t.slice(0, 4000) }, 8000, null);
            notify(ok(res) ? T('ui_statement_filed', 'Statement filed') : msgOf(res, T('ui_save_failed', 'Could not save')));
            if (ok(res)) openBrief(x);
        }));
        const statements = arr(d.statements).slice().sort((a, b) => num(toDate(a.filed_at)) - num(toDate(b.filed_at)));
        fill(listWrap, h('div', { class: 'brief page-turn' },
            h('button', { class: 'btn ghost sm', type: 'button', onclick: closeBrief }, icon('arrow_back'), T('ui_back', 'Back')),
            h('h3', null, str(ci.case_number || x.case_number) + ' — ' + str(ci.title || x.title)),
            h('div', { class: 'grid2' },
                h('div', null, h('span', { class: 'lbl' }, T('ui_col_status', 'Status')), ' ', labelOf(CaseStatus(), ci.status)),
                h('div', null, h('span', { class: 'lbl' }, T('ui_col_priority', 'Priority')), ' ', labelOf(CasePriority(), ci.priority)),
                h('div', null, h('span', { class: 'lbl' }, T('ui_location', 'Location')), ' ', str(ci.location, '—')),
                h('div', null, h('span', { class: 'lbl' }, T('ui_lead', 'Lead')), ' ', str(ci.investigator_name || ci.created_by, '—')),
                h('div', null, h('span', { class: 'lbl' }, T('ui_opened', 'Opened')), ' ', fmtDate(ci.created_at))),
            section(T('ui_case_summary_short', 'Case summary'), h('p', { class: 'pre' }, str(ci.description, '—'))),
            section(T('ui_involved_citizens', 'Involved Citizens'), h('div', { class: 'tags' }, arr(d.involved).map((p) => h('span', { class: 'tag' }, str(p.name) + ' (' + str(p.type) + ')')))),
            section(T('ui_statements_thread', 'Statements'), statements.length ? statements.map((s) => h('div', { class: 'stmt ' + (s.author_role === 'defense' ? 'defense' : 'law') },
                h('div', null, h('b', null, str(s.author_name)), ' ', badge(s.author_role === 'defense' ? T('ui_defense', 'Defense') : T('ui_law', 'Law'), s.author_role === 'defense' ? 'gold' : 'blue'), h('small', { class: 'muted' }, ' ' + fmtDateTime(s.filed_at))),
                h('p', { class: 'pre' }, str(s.statement)))) : h('div', { class: 'muted' }, T('ui_no_statements_yet', 'No statements yet'))),
            data && data.canFile ? section(T('ui_file_statement', 'File Statement'), stmt, h('div', { class: 'frow end' }, fileB)) : null));
    }
    regTab({
        id: 'defense', icon: 'work', perm: 'viewdefense', label: () => T('ui_nav_defense', 'Defense'),
        build: (r) => {
            root = r;
            q = inp({ placeholder: T('ui_search_defense', 'Search case number, title or lawyer…') });
            q.addEventListener('input', debounce(load, 300));
            assignBtn = h('button', { class: 'btn primary sm hidden', type: 'button', onclick: assignForm }, icon('person_add'), T('ui_assign_defense', 'Assign Defense'));
            listWrap = h('div'); formWrap = h('div');
            add(r, [h('h2', { class: 'page-title' }, T('ui_defense_title', 'Case Defense')), h('div', { class: 'toolbar' }, q, assignBtn, plainRefresh(load)), formWrap, listWrap]);
        },
        show: () => { brief = null; load(); },
        reset: () => { root = null; data = null; brief = null; },
        push: () => { if (root && App.current === 'defense' && !brief) load(); },
    });
})();
