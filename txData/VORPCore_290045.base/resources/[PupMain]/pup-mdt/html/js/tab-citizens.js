'use strict';
// Person Search: citizen list, citizen profile, mugshot, history, Process Arrest, expungement certificate.

function personStatus(c) {
    if (c.hasActiveBounty) return { label: T('ui_st_bounty', 'Bounty'), tone: 'red' };
    if (str(c.status).toLowerCase() === 'wanted') return { label: T('ui_st_wanted', 'Wanted'), tone: 'red' };
    if (c.hasOpenCase) return { label: T('ui_st_open_case', 'Open Case'), tone: 'gold' };
    return { label: T('ui_st_clear', 'Clear'), tone: 'green' };
}
function fullName(c) { return str(c.name || ((str(c.firstname) + ' ' + str(c.lastname)).trim()), T('ui_unknown', 'Unknown')); }

(function () {
    let root, listEl, countEl, q, statusSel, page = 1, criminals = [], seq = 0;
    async function load(p) {
        page = p || page;
        const my = ++seq;
        fill(listEl, loading(T('ui_loading_citizens', 'Loading citizens…')));
        const r = await nui('getCriminals', { page, search: q.value.trim(), status: statusSel.value }, 8000, null);
        if (my !== seq) return;
        draw(r);
    }
    function draw(r) {
        if (!root) return;
        r = r || {};
        criminals = arr(r.criminals);
        page = num(r.currentPage, page);
        countEl.textContent = T('ui_n_records', '%d records', num(r.totalRecords, criminals.length));
        const cols = [
            { label: T('ui_col_status', 'Status'), render: (c) => { const s = personStatus(c); return h('span', { class: 'st tone-' + s.tone }, statusDot(true), ' ', s.label); } },
            { label: T('ui_col_name', 'Name'), render: (c) => [c.hasActiveBounty ? h('span', { class: 'flag tone-red' }) : c.hasOpenCase ? h('span', { class: 'flag tone-gold' }) : null, fullName(c)] },
            { label: T('ui_col_identity', 'Identity'), render: (c) => str(c.identity) },
            { label: T('ui_col_total_fines', 'Total Fines'), render: (c) => money(c.totalFineAmount !== undefined ? c.totalFineAmount : c.totalFines) },
            { label: T('ui_col_registered', 'Registered'), render: (c) => c.registeredAt ? fmtDate(c.registeredAt) : '—' },
            { label: '', cls: 'act', render: (c) => iconBtn('open_in_new', T('ui_open', 'Open'), () => openProfile(c)) },
        ];
        fill(listEl,
            table(cols, criminals, { onRow: (c) => openProfile(c), empty: emptyState(T('ui_no_citizens', 'No citizens found'), T('ui_try_other_search', 'Try another search or filter'), 'person_search') }),
            pager(page, r.totalPages, r.totalRecords, load));
    }
    regTab({
        id: 'citizens', icon: 'person_search', perm: 'criminals', label: () => T('ui_nav_citizens', 'Person Search'),
        build: (r) => {
            root = r;
            q = inp({ placeholder: T('ui_search_name_id', 'Search name or identity…') });
            statusSel = sel([['all', T('ui_all_citizens', 'All Citizens')], ['flagged', T('ui_has_record', 'Has Record')], ['wanted', T('ui_st_wanted', 'Wanted')]], 'all');
            countEl = h('span', { class: 'muted' });
            listEl = h('div');
            q.addEventListener('input', debounce(() => load(1), 500));
            statusSel.addEventListener('change', () => load(1));
            add(r, [h('h2', { class: 'page-title' }, T('ui_nav_citizens', 'Person Search')),
                h('div', { class: 'toolbar' }, q, statusSel, countEl, refreshBtn('citizens', () => load())), listEl]);
        },
        show: (o) => { if (o && o.identity) { openProfile({ identity: o.identity, name: o.name }); } load(page); },
        reset: () => { root = null; page = 1; criminals = []; },
        push: (r) => { /* another lawman changed a record: refresh this page as it is, keeping the filter */ if (root && App.current === 'citizens') load(page); },
    });
    App.openCitizen = (c) => openProfile(c);
})();

// ---------- citizen profile ----------
function openProfile(c) {
    c = Object.assign({}, c || {});
    const name = fullName(c);
    const body = h('div', { class: 'profile' }, loading());
    const m = modal({ title: name, icon: 'badge', cls: 'xwide profile-modal', body, backdropCloses: false });
    m.box.appendChild(h('img', { class: 'deco-badge', src: 'img/badge.svg', alt: '' }));
    m.box.appendChild(h('img', { class: 'deco-stamp', src: 'img/stamp.svg', alt: '' }));
    const reload = async () => {
        const p = await nui('getCitizenProfile', { identity: str(c.identity), name }, 8000, {});
        if (!m.el.isConnected) return;
        drawProfile(m, c, p || {}, reload);
    };
    reload();
    return m;
}
function drawProfile(m, c, p, reload) {
    const name = fullName(c);
    const summary = p.summary || {};
    const serving = !!p.isServing;
    const bounty = !!p.hasActiveBounty;
    const status = str(c.status, 'clear').toLowerCase();
    const totalFines = p.totalFines !== undefined ? p.totalFines : (summary.totalFines !== undefined ? summary.totalFines : c.totalFineAmount);
    const stBadge = serving ? badge(T('ui_serving', 'SERVING'), 'grey')
        : bounty ? [badge(T('ui_active_bounty', 'ACTIVE BOUNTY'), 'red'), ' ', badge(T('ui_bounty_up', 'BOUNTY'), 'red')]
            : badge(status === 'wanted' ? T('ui_wanted_up', 'WANTED') : status === 'released' ? T('ui_released_up', 'RELEASED') : T('ui_clear_up', 'CLEAR'), status === 'wanted' ? 'red' : status === 'released' ? 'gold' : 'green');
    const photo = c.photoUrl && isHttpUrl(c.photoUrl) ? img(c.photoUrl, 'mug', (el) => el.replaceWith(icon('person', 'mug'))) : icon('person', 'mug');
    const header = h('div', { class: 'prof-head' }, photo,
        h('div', null, h('h3', null, name), h('div', null, stBadge),
            h('div', { class: 'muted' }, T('ui_profile_line', 'Identity %s • Age %s • Fines %s', str(c.identity, '—'), str(c.age, '—'), money(totalFines)))));

    // left column
    const stSel = sel([['clear', T('ui_st_clear', 'Clear')], ['wanted', T('ui_st_wanted', 'Wanted')], ['released', T('ui_st_released', 'Released')]], bounty && status === 'clear' ? 'wanted' : status);
    const notes = area({ rows: 4, value: str(c.description), maxlength: 2000 });
    const warrants = arr(p.warrants || p.bounties).filter((w) => !w.status || str(w.status) === 'active');
    let bountyCard = null;
    if (bounty && warrants.length) {
        const tf = warrants.reduce((s, w) => s + num(w.bounty_fine !== undefined ? w.bounty_fine : w.fine), 0);
        const tj = warrants.reduce((s, w) => s + num(w.bounty_jailtime !== undefined ? w.bounty_jailtime : w.jailtime), 0);
        const latest = warrants[0];
        bountyCard = h('div', { class: 'card tone-red' },
            h('div', { class: 'fsec-title' }, T('ui_bounty_details', 'Bounty Details')),
            h('div', null, T('ui_total_fine', 'Total Fine'), ': ', h('b', null, money(tf)), '  ', T('ui_total_sentence', 'Total Sentence'), ': ', h('b', null, T('ui_n_mo', '%d mo', tj))),
            h('p', { class: 'muted' }, warrants.length > 1 ? T('ui_n_bounties_latest', '%d active bounties — latest: %s', warrants.length, str(latest.notes || latest.charges)) : str(latest.notes || latest.charges)));
    }
    const saveBtn = h('button', { class: 'btn primary', type: 'button' }, icon('save'), T('ui_save_changes', 'Save Changes'));
    saveBtn.addEventListener('click', async () => {
        saveBtn.disabled = true; saveBtn.textContent = T('ui_saving', 'Saving…');
        setTimeout(() => { if (saveBtn.isConnected) { saveBtn.disabled = false; saveBtn.textContent = T('ui_save_changes', 'Save Changes'); } }, 3000);
        const r = await nuiPush('updateCriminalInfo', { identity: str(c.identity), criminalId: c.id || null, status: stSel.value, description: notes.value.trim() }, 8000, null);
        const res = r && r.result;
        if (res && res.success) {
            c.status = stSel.value; c.description = notes.value.trim();
            if (res.criminal && res.criminal.id) c.id = res.criminal.id;
            notify(msgOf(res, T('ui_record_saved', 'Record saved')));
            preview.textContent = c.description || T('ui_no_notes', 'No notes');
        } else notify(msgOf(res, T('ui_save_failed', 'Could not save')));
    });
    const preview = h('div', { class: 'note-preview' }, str(c.description) || T('ui_no_notes', 'No notes'));
    const left = h('div', { class: 'col' },
        field(T('ui_update_status', 'Update Status'), stSel),
        bountyCard,
        field(T('ui_notes_desc', 'Notes / Description'), h('div', null, preview, notes)),
        section(T('ui_record_info', 'Record Info'),
            h('div', null, h('span', { class: 'lbl' }, T('ui_registered_by', 'Registered by')), ' ', str(c.registeredBy, T('ui_system', 'System'))),
            h('div', null, h('span', { class: 'lbl' }, T('ui_char_created', 'Character created')), ' ', c.characterCreated ? fmtDate(c.characterCreated) : T('ui_unknown', 'Unknown'))),
        h('div', { class: 'btn-col' },
            App.lawyer ? null : saveBtn,
            App.lawyer ? null : h('button', { class: 'btn', type: 'button', onclick: () => openMugshot(c, () => { m.close(true); openProfile(c); }) }, icon('photo_camera'), T('ui_update_mugshot', 'Update Mugshot')),
            can('arrest') && !App.lawyer ? h('button', { class: 'btn', type: 'button', onclick: () => openArrest(c) }, icon('gavel'), T('ui_process_arrest', 'Process Arrest')) : null,
            h('button', { class: 'btn ghost', type: 'button', onclick: () => openHistory(c) }, icon('history'), T('ui_history', 'History')),
            c.id && !App.lawyer && can('deleterecords') ? h('button', { class: 'btn danger', type: 'button', onclick: async () => {
                const yes = await confirmBox({ title: T('ui_delete_record', 'Delete Record'), message: T('ui_delete_record_q', 'Delete the record of %s (%s)? This cannot be undone.', name, str(c.identity)), confirm: T('ui_delete', 'Delete'), danger: true });
                if (!yes) return;
                const r = await nuiPush('deleteCriminal', { criminalId: c.id }, 8000, null);
                const res = r && r.result;
                notify(msgOf(res, ok(res) ? T('ui_record_deleted', 'Record deleted') : T('ui_delete_failed', 'Could not delete')));
                if (ok(res)) { m.close(true); App.tabs.citizens.push(); }
            } }, icon('delete'), T('ui_delete', 'Delete')) : null));

    // right column
    const panels = {};
    const chip = (key, label, n) => h('button', { class: 'chip-btn', type: 'button', onclick: () => {
        const el = panels[key]; if (!el) return;
        el.scrollIntoView({ behavior: 'smooth', block: 'start' });
        el.classList.remove('flash'); void el.offsetWidth; el.classList.add('flash');
    } }, h('span', { class: 'hand' }, String(n)), ' ', label);
    const reports = arr(p.reports).slice(0, 10);
    const cases = arr(p.cases).slice(0, 10);
    const bolos = arr(p.bolos || p.statements).slice(0, 5);
    const charges = arr(p.charges);
    const exps = arr(p.expungements).filter((e) => str(e.status) === 'approved');
    const pp = (key, title, items, render, onClick) => (panels[key] = h('div', { class: 'panel' },
        h('div', { class: 'panel-head' }, h('span', { class: 'panel-t' }, title), h('span', { class: 'hand cnt' }, String(items.length))),
        h('div', { class: 'panel-body' }, items.length ? items.map((x) => h('div', { class: 'feed-row' + (onClick ? '' : ' static'), onclick: onClick ? () => { m.close(true); onClick(x); } : null }, render(x))) : h('div', { class: 'muted' }, T('ui_none', 'None')))));
    const right = h('div', { class: 'col' },
        h('div', { class: 'chips' },
            chip('cases', T('ui_cases', 'Cases'), num(summary.cases, cases.length)),
            chip('reports', T('ui_reports', 'Reports'), num(summary.reports, reports.length)),
            chip('charges', T('ui_charges', 'Charges'), num(summary.charges, charges.length)),
            chip('charges', T('ui_total_fines', 'Total Fines'), money(totalFines))),
        pp('reports', T('ui_recent_reports', 'Recent Reports'), reports, (r) => [h('b', null, str(r.title, T('ui_untitled_report', 'Untitled Report'))), h('small', null, [str(r.type), str(r.author_name), fmtDate(r.created_at)].join(' • '))], (r) => App.showTab('reports', { openId: num(r.id) })),
        pp('cases', T('ui_cases', 'Cases'), cases, (x) => [h('b', null, str(x.title)), h('small', null, [str(x.case_number), str(x.status), str(x.priority), fmtDate(x.created_at)].join(' • '))], (x) => App.showTab('cases', { openId: num(x.id) })),
        pp('bounties', T('ui_active_bounties', 'Active Bounties'), warrants.slice(0, 10), (w) => [h('b', null, str(w.charges, T('ui_no_charges_listed', 'No charges listed'))), h('small', null, [str(w.status), str(w.issued_by), fmtDate(w.created_at)].join(' • '))], (w) => App.showTab('bounties', { openId: num(w.id) })),
        pp('bolos', T('ui_active_statements', 'Active Witness Statements'), bolos, (b) => [h('b', null, str(b.type, T('ui_statement', 'Statement'))), h('small', null, cut(b.description, 50) + ' • ' + fmtDate(b.created_at))], (b) => App.showTab('statements', { openId: num(b.id) })),
        pp('charges', T('ui_charges', 'Charges'), charges, (x) => {
            const n = num(x.count, 1);
            return [h('b', null, str(x.label), n > 1 ? ' x' + n : ''), h('small', null, n > 1 ? T('ui_charge_each', '%s / %d mo each', money(x.fine), num(x.months)) : T('ui_charge_once', '%s / %d mo', money(x.fine), num(x.months)))];
        }, null),
        exps.length ? pp('exps', T('ui_cleared_records', 'Cleared Records'), exps, (e) => [h('b', null, T('ui_records_cleared_reason', 'Records Cleared — %s', str(e.reason))), h('small', null, T('ui_exp_line', '%d rows cleared • Approved by %s • %s', num(e.records_cleared), str(e.reviewed_by_name, '—'), fmtDate(e.reviewed_at)))], (e) => openExpCertificate(e.id)) : null);
    fill(m.body, header, h('div', { class: 'cols2' }, left, right));
}

// ---------- mugshot ----------
function openMugshot(c, after) {
    const url = inp({ placeholder: 'https://…', value: str(c.photoUrl) });
    const pv = img(str(c.photoUrl), 'mug-preview');
    url.addEventListener('input', () => { const u = url.value.trim(); pv.classList.toggle('hidden', !isHttpUrl(u)); if (isHttpUrl(u)) pv.src = u; });
    const saveBtn = h('button', { class: 'btn primary', type: 'button' }, T('ui_save', 'Save'));
    const m = modal({
        title: T('ui_update_mugshot', 'Update Mugshot'), icon: 'photo_camera',
        body: [field(T('ui_image_url', 'Image URL (Discord, Imgur…)'), url), pv],
        footer: [h('button', { class: 'btn ghost', type: 'button', onclick: () => m.close() }, T('ui_cancel', 'Cancel')), saveBtn],
    });
    saveBtn.addEventListener('click', () => busy(saveBtn, T('ui_saving', 'Saving…'), async () => {
        const u = url.value.trim();
        if (!u) { notify(T('ui_url_required', 'Enter an image URL')); return; }
        if (!isHttpUrl(u)) { notify(T('ui_url_http', 'Only http(s) links are accepted')); return; }
        const r = await nuiPush('updateCriminalPhoto', { criminalId: c.id || null, identity: str(c.identity), firstname: str(c.firstname), lastname: str(c.lastname), age: str(c.age), photoUrl: u }, 8000, null);
        const res = r && r.result;
        notify(msgOf(res, ok(res) ? T('ui_mugshot_saved', 'Mugshot updated') : T('ui_save_failed', 'Could not save')));
        if (ok(res)) { c.photoUrl = u; if (res.criminal && res.criminal.id) c.id = res.criminal.id; m.close(true); if (after) after(); }
    }));
}

// ---------- history ----------
function openHistory(c) {
    const body = h('div', null, loading());
    modal({ title: T('ui_criminal_history', 'Criminal History'), icon: 'history', cls: 'wide', body, backdropCloses: true });
    nuiPush('getCriminalHistory', { id: c.id || null, identity: str(c.identity) }, 8000, null).then((r) => {
        if (!body.isConnected) return;
        const d = (r && r.data) || {};
        const rows = [];
        for (const a of arr(d.arrests)) {
            let charges = a.charges;
            if (typeof charges === 'string') { try { charges = JSON.parse(charges); } catch (e) { /* plain text */ } }
            const text = Array.isArray(charges) ? charges.map((x) => str(x.label || x.code) + (num(x.count, 1) > 1 ? ' x' + num(x.count) : '')).join(', ') : str(charges);
            rows.push({ date: a.created_at, incident: T('ui_arrest', 'Arrest'), charges: text, fine: a.final_fine !== undefined ? a.final_fine : a.total_fine, jail: a.final_months !== undefined ? a.final_months : a.total_months, lawman: a.lawman_name });
        }
        for (const i of arr(d.incidents)) rows.push({ date: i.date || i.created_at || i.imprisoned_at, incident: str(i.title || i.type || i.reason, T('ui_incident', 'Incident')), charges: str(i.charges || i.reason || i.description), fine: i.fine !== undefined ? i.fine : i.fine_amount, jail: i.jail !== undefined ? i.jail : i.sentence_minutes, lawman: i.lawman || i.created_by || i.imprisoned_by });
        rows.sort((a, b) => num(toDate(b.date)) - num(toDate(a.date)));
        fill(body,
            h('div', { class: 'prof-head small' }, c.photoUrl ? img(c.photoUrl, 'mug') : icon('person', 'mug'), h('div', null, h('b', null, fullName(c)), h('div', { class: 'muted' }, str(c.identity)))),
            table([
                { label: T('ui_col_date', 'Date'), render: (x) => fmtDate(x.date) },
                { label: T('ui_col_incident', 'Incident'), render: (x) => x.incident },
                { label: T('ui_charges', 'Charges'), render: (x) => cut(x.charges, 80), title: (x) => x.charges },
                { label: T('ui_col_total_fine', 'Total Fine'), render: (x) => money(x.fine) },
                { label: T('ui_col_jail_time', 'Jail Time'), render: (x) => num(x.jail) ? T('ui_n_mo', '%d mo', num(x.jail)) : '—' },
                { label: T('ui_col_lawman', 'Lawman'), render: (x) => str(x.lawman, '—') },
            ], rows, { empty: emptyState(T('ui_no_history', 'No history found'), null, 'history') }));
    });
}

// ---------- Process Arrest ----------
function openArrest(c) {
    const name = fullName(c);
    const picked = [];
    const q = inp({ placeholder: T('ui_search_code_label', 'Search code or label…') });
    const cards = h('div', { class: 'pc-cards' }, loading());
    const selEl = h('div');
    const jailD = numInp({ value: 0, max: 100 }), fineD = numInp({ value: 0, max: 100 });
    const totals = h('div', { class: 'totals' });
    const notes = area({ rows: 3, maxlength: 1000 });
    const applyFine = h('input', { type: 'checkbox', checked: true });
    const applyJail = h('input', { type: 'checkbox', checked: true });
    const target = h('select', { class: 'inp' }, h('option', { value: '0' }, T('ui_no_target', '— Offline / No target —')));
    const stations = arr(App.cfg.prisonStations);
    const local = h('input', { type: 'checkbox' });
    const stationSel = sel(stations.map((s, i) => [String(i + 1), str(s.label, T('ui_station_n', 'Station %d', i + 1))]), '1');
    const clampPct = (el) => { let v = Math.floor(num(el.value)); v = Math.min(100, Math.max(0, v)); el.value = String(v); return v; };
    const redrawSel = () => {
        fill(selEl, picked.length ? chargeTags(picked, true, () => { redrawSel(); redrawCards(); }) : h('div', { class: 'muted' }, T('ui_no_charges_selected', 'No charges selected')));
        const t = chargeTotals(picked);
        const jd = clampPct(jailD), fd = clampPct(fineD);
        fill(totals,
            h('div', null, T('ui_total_fine', 'Total Fine'), ': ', h('b', null, money(t.fine))),
            h('div', null, T('ui_total_jail', 'Total Jail'), ': ', h('b', null, T('ui_n_months', '%d months', t.months))),
            h('div', { class: 'tone-green' }, T('ui_final_fine', 'Final Fine'), ': ', h('b', null, money(afterDiscount(t.fine, fd)))),
            h('div', { class: 'tone-green' }, T('ui_final_jail', 'Final Jail'), ': ', h('b', null, T('ui_n_months', '%d months', afterDiscount(t.months, jd)))));
    };
    const redrawCards = () => {
        const list = Penal.list || [];
        const t = q.value.trim().toLowerCase();
        const rows = list.filter((x) => !t || str(x.code).toLowerCase().includes(t) || str(x.label).toLowerCase().includes(t));
        fill(cards, rows.length ? rows.map((x) => h('button', { class: 'pc-card' + (picked.some((p) => p.code === x.code) ? ' on' : ''), type: 'button', onclick: () => { addCharge(picked, x); redrawSel(); redrawCards(); } },
            h('div', null, h('b', null, str(x.code)), ' ', h('span', { class: 'tone-' + classTone(x.charge_class) }, classLabel(x.charge_class))),
            h('div', null, str(x.label)),
            h('small', null, money(x.fine), num(x.months) > 0 ? ' · ' + T('ui_n_mo_dot', '%d mo.', num(x.months)) : ''))) : emptyState(T('ui_no_match', 'no match')));
    };
    q.addEventListener('input', redrawCards);
    jailD.addEventListener('input', redrawSel); fineD.addEventListener('input', redrawSel);
    loadPenal().then((l) => { if (!l.length) fill(cards, emptyState(T('ui_penal_failed', 'Could not load the penal code'), null, 'error')); else redrawCards(); });
    nui('getPlayerData', { type: 'onlinePlayers' }, 5000, []).then((r) => {
        arr(r).forEach((p) => target.appendChild(h('option', { value: String(num(p.serverId)) }, '[' + num(p.serverId) + '] ' + str(p.name))));
    });
    redrawSel();
    const goBtn = h('button', { class: 'btn primary', type: 'button' }, icon('gavel'), T('ui_process_arrest', 'Process Arrest'));
    const m = modal({
        title: T('ui_process_arrest', 'Process Arrest'), icon: 'gavel', cls: 'xwide', headExtra: badge(name, 'red'),
        body: h('div', { class: 'cols2 arrest' },
            h('div', { class: 'col' }, h('div', { class: 'fsec-title' }, T('ui_select_charges', 'Select Charges')), q, cards),
            h('div', { class: 'col' },
                section(T('ui_selected_charges', 'Selected Charges'), selEl),
                section(T('ui_totals', 'Totals'), totals, row(field(T('ui_jail_discount', 'Jail Discount %'), jailD), field(T('ui_fine_discount', 'Fine Discount %'), fineD))),
                stations.length ? section(T('ui_serve_locally', 'Serve Locally'), h('label', { class: 'check' }, local, ' ', T('ui_hold_local', 'Hold at a local station cell')), stationSel) : null,
                field(T('ui_target_player', 'Target Player (online)'), target),
                field(T('ui_notes', 'Notes'), notes),
                h('div', { class: 'frow' }, h('label', { class: 'check' }, applyFine, ' ', T('ui_apply_fine', 'Apply Fine')), h('label', { class: 'check' }, applyJail, ' ', T('ui_apply_jail', 'Apply Jail'))))),
        footer: [h('button', { class: 'btn ghost', type: 'button', onclick: () => m.close() }, T('ui_cancel', 'Cancel')), goBtn],
    });
    goBtn.addEventListener('click', () => {
        if (!picked.length) { notify(T('ui_select_one_charge', 'Select at least one charge')); return; }
        busy(goBtn, T('ui_processing', 'Processing…'), async () => {
            const t = chargeTotals(picked);
            const jd = clampPct(jailD), fd = clampPct(fineD);
            const r = await nui('processArrest', {
                citizenIdentity: str(c.identity), citizenName: name,
                charges: picked.map((x) => ({ code: x.code, label: x.label, fine: num(x.fine), months: num(x.months), class: x.charge_class, count: num(x.count, 1) })),
                totalFine: t.fine, totalMonths: t.months,
                discountPercent: fd, jailDiscountPercent: jd, fineDiscountPercent: fd,
                finalFine: afterDiscount(t.fine, fd), finalMonths: afterDiscount(t.months, jd),
                notes: notes.value.trim(), applyFine: applyFine.checked, applyJail: applyJail.checked,
                targetServerId: num(target.value), serveLocally: !!(stations.length && local.checked), stationIndex: num(stationSel.value, 1),
            }, 15000, { success: false, message: T('ui_arrest_timeout', 'The arrest timed out. Check the records before trying again.') });
            if (ok(r)) { notify(msgOf(r, T('ui_arrest_processed', 'Arrest processed'))); m.close(true); }
            else notify(msgOf(r, T('ui_arrest_failed', 'The arrest could not be processed')));
        });
    });
}

// ---------- expungement certificate ----------
// counts from a stored snapshot (flat numbers) or a preview ({ table: { count, rows } })
function snapCount(v) {
    if (typeof v === 'number' || typeof v === 'string') return num(v);
    if (Array.isArray(v)) return v.length;
    if (v && typeof v === 'object') return v.count !== undefined ? num(v.count) : arr(v.rows).length;
    return 0;
}
function snapshotTally(s) {
    const snap = (s && s.snapshot) || {};
    const t = snap.tally || snap.summary || snap;
    let fines = num(t.totalFines !== undefined ? t.totalFines : t.fines);
    let months = num(t.totalMonths !== undefined ? t.totalMonths : t.monthsJail);
    const arrestRows = arr((snap.mdt_arrests && snap.mdt_arrests.rows) || []);
    if (!fines && arrestRows.length) fines = arrestRows.reduce((a, r) => a + num(r.final_fine), 0);
    if (!months && arrestRows.length) months = arrestRows.reduce((a, r) => a + num(r.final_months), 0);
    const names = arr(t.chargeNames || t.chargeList || t.chargeCounts).map((x) => (typeof x === 'string' ? { label: x, count: 1 } : x));
    return {
        arrests: snapCount(t.arrests !== undefined ? t.arrests : snap.mdt_arrests),
        charges: snapCount(t.charges !== undefined ? t.charges : snap.mdt_reports_charges),
        fines, months,
        prison: snapCount(t.prisonTerms !== undefined ? t.prisonTerms : snap.mdt_prison_records),
        bounties: snapCount(t.bounties !== undefined ? t.bounties : snap.mdt_reports_warrants),
        chargeList: names,
    };
}
function openExpCertificate(id) {
    const body = h('div', { class: 'cert' }, loading());
    modal({ title: T('ui_record_of_expungement', 'Record of Expungement'), icon: 'verified', cls: 'wide', body, backdropCloses: true });
    nui('getExpungementSnapshot', { id: num(id) }, 8000, null).then((r) => {
        if (!body.isConnected) return;
        if (!r || r.success === false) { fill(body, emptyState(msgOf(r, T('ui_load_failed', 'Could not load')), null, 'error')); return; }
        const s = r.snapshot || {};
        if (!s.snapshot) { fill(body, emptyState(T('ui_no_snapshot', 'No snapshot was kept for this expungement'), null, 'inventory')); return; }
        const t = snapshotTally(s);
        fill(body,
            h('div', { class: 'stamp-big' }, T('ui_expunged', 'Expunged'), h('small', null, fmtDate(s.reviewedAt))),
            h('h3', null, T('ui_record_of_expungement', 'Record of Expungement')),
            h('p', { class: 'muted' }, T('ui_by_order', 'By order of the law department — %s', str(s.reviewedBy || s.reviewed_by_name, '—'))),
            h('div', { class: 'grid2' },
                h('div', null, h('span', { class: 'lbl' }, T('ui_reason', 'Reason')), ' ', str(s.reason, '—')),
                h('div', null, h('span', { class: 'lbl' }, T('ui_requested_by', 'Requested By')), ' ', str(s.requestedBy || s.requested_by_name, '—')),
                h('div', null, h('span', { class: 'lbl' }, T('ui_approved_by', 'Approved By')), ' ', str(s.reviewedBy || s.reviewed_by_name, '—')),
                h('div', null, h('span', { class: 'lbl' }, T('ui_date_approved', 'Date Approved')), ' ', fmtDate(s.reviewedAt)),
                h('div', null, h('span', { class: 'lbl' }, T('ui_records_cleared', 'Records Cleared')), ' ', String(num(s.recordsCleared)))),
            s.reviewNotes || s.review_notes ? h('blockquote', null, str(s.reviewNotes || s.review_notes)) : null,
            h('div', { class: 'fsec-title' }, T('ui_old_record', 'The old record')),
            tallyTiles(t),
            h('div', { class: 'tags' }, t.chargeList.slice(0, 40).map((x) => h('span', { class: 'tag' }, str(x.label || x.name || x.code), ' ×' + num(x.count, 1)))));
    });
}
function tallyTiles(t) {
    const tile = (n, l) => h('div', { class: 'tile' }, h('span', { class: 'hand big' }, String(n)), h('small', null, l));
    return h('div', { class: 'tiles' },
        tile(t.arrests, T('ui_arrests', 'Arrests')), tile(t.charges, T('ui_charges', 'Charges')), tile(money(t.fines), T('ui_old_fines', 'Old Fines')),
        tile(t.months, T('ui_months_jail', 'Months Jail')), tile(t.prison, T('ui_prison_terms', 'Prison Terms')), tile(t.bounties, T('ui_bounties', 'Bounties')));
}
