'use strict';
// Incident Reports: list and the full-page report editor.

// the values are the server's own type names (server/reports.lua REPORT_TYPES)
function reportTypes() {
    return [['Incident Report', T('ui_rt_incident', 'Incident')], ['Arrest Report', T('ui_rt_arrest', 'Arrest')], ['Investigation Report', T('ui_rt_investigation', 'Investigation')],
        ['Use of Force Report', T('ui_rt_force', 'Use of Force')], ['Other', T('ui_rt_other', 'Other')]];
}
function reportTypeTone(t) { return { 'arrest report': 'red', 'investigation report': 'purple', 'incident report': 'green' }[str(t).toLowerCase()] || 'grey'; }
function reportTypeLabel(t) { const f = reportTypes().find((x) => x[0].toLowerCase() === str(t).toLowerCase()); return f ? f[1] : str(t, '—'); }
function parseJson(v, d) { if (typeof v !== 'string') return v === undefined || v === null ? d : v; try { return JSON.parse(v); } catch (e) { return d; } }

(function () {
    let root, listView, editorView, q, typeSel, listEl, page = 1, rows = [], seq = 0, editor = null;
    async function load(p) {
        page = p || page;
        const my = ++seq;
        fill(listEl, loading());
        const r = await nui('getReports', { page, search: q.value.trim(), typeFilter: typeSel.value }, 8000, null);
        if (my !== seq || !root) return;
        rows = arr(r && r.reports);
        fill(listEl,
            table([
                { label: T('ui_col_report_no', 'Report #'), render: (x) => { const n = str(x.report_number, 'RPT-' + x.id); return h('button', { class: 'link', type: 'button', onclick: (e) => { e.stopPropagation(); copyText(n); } }, n); } },
                { label: T('ui_col_title', 'Title'), render: (x) => str(x.title, T('ui_untitled_report', 'Untitled Report')) },
                { label: T('ui_col_type', 'Type'), render: (x) => h('span', { class: 'badge outline tone-' + reportTypeTone(x.type) }, reportTypeLabel(x.type)) },
                { label: T('ui_col_author', 'Author'), render: (x) => str(x.author_name, T('ui_unknown', 'Unknown')) },
                { label: T('ui_col_created', 'Created'), render: (x) => fmtDate(x.created_at) },
                { label: '', cls: 'act', render: (x) => [
                    can('deletereports') ? iconBtn('delete', T('ui_delete', 'Delete'), () => remove(x)) : null,
                    iconBtn('edit', T('ui_edit', 'Edit'), () => openEditor(x))] },
            ], rows, { onRow: (x) => openEditor(x), empty: emptyState(T('ui_no_reports', 'No reports found'), null, 'description') }),
            pager(page, r && r.totalPages, r && r.totalRecords, load));
    }
    async function remove(x, after) {
        if (!(await confirmBox({ message: T('ui_delete_report_q', 'Delete report %s? This cannot be undone.', str(x.report_number, '#' + x.id)), confirm: T('ui_delete', 'Delete'), danger: true }))) return false;
        const r = await nui('deleteReport', { id: num(x.id) }, 8000, null);
        notify(ok(r) ? T('ui_report_deleted', 'Report deleted') : msgOf(r, T('ui_delete_failed', 'Could not delete')));
        if (ok(r)) { if (after) after(); load(); }
        return ok(r);
    }
    async function fetchReport(id) {
        let x = rows.find((r) => num(r.id) === num(id));
        if (x) return x;
        // not on this page: search by id across the list
        const r = await nui('getReports', { page: 1, search: String(id), typeFilter: 'all', id: num(id) }, 8000, null);
        x = arr(r && r.reports).find((y) => num(y.id) === num(id));
        return x || null;
    }
    function showList() {
        if (editor) { popLayer(editorView); editor = null; }
        clear(editorView); show(editorView, false); show(listView, true);
    }
    function openEditor(x) {
        const isNew = !x;
        x = x || {};
        const editable = can('reports') && !App.lawyer;
        let dirty = false;
        const markDirty = () => { dirty = true; };
        const crimes = arr(parseJson(x.crimes_json || x.crimes, [])).map((c) => ({ code: c.code || c.charge_code, label: c.label || c.charge_label, charge_class: c.charge_class, months: num(c.months !== undefined ? c.months : c.jail_time), fine: num(c.fine), count: num(c.count, 1) }));
        let savedCrimes = crimes.map((c) => Object.assign({}, c));
        const involved = arr(x.involved).map((p) => ({ citizenid: str(p.citizenid), name: str(p.name), type: str(p.type, 'suspect'), notes: str(p.notes) }));
        const lawmen = arr(x.lawmen || x.reportLawmen).map((p) => ({ citizenid: str(p.citizenid), name: str(p.name), role: str(p.role, 'lead') }));
        const conf = arr(parseJson(x.confiscated_items || x.confiscatedItems, [])).map((it) => ({ name: str(it.name), label: str(it.label || it.name), type: it.type === 'weapon' ? 'weapon' : 'item', quantity: num(it.quantity, 1) }));
        const title = inp({ value: str(x.title), maxlength: 120 });
        const type = sel(reportTypes(), str(x.type, 'Incident Report'));
        const loc = inp({ value: str(x.location), maxlength: 200 });
        const rich = richEditor(markDirty);
        rich.set(x.content || '');
        const jailD = h('input', { type: 'range', min: 0, max: 100, step: 5, value: num(x.jail_reduction_percent !== undefined ? x.jail_reduction_percent : x.reduction_percent) });
        const fineD = h('input', { type: 'range', min: 0, max: 100, step: 5, value: num(x.fine_reduction_percent !== undefined ? x.fine_reduction_percent : x.reduction_percent) });
        const jailOut = h('span', { class: 'hand' }), fineOut = h('span', { class: 'hand' });
        const summary = h('div', { class: 'summary' });
        const crimesEl = h('div');
        const stations = arr(App.cfg.prisonStations);
        const local = h('input', { type: 'checkbox' });
        const stationSel = sel(stations.map((s, i) => [String(i + 1), str(s.label, T('ui_station_n', 'Station %d', i + 1))]), '1');
        const redraw = () => {
            fill(crimesEl, chargeTags(crimes, editable, () => { markDirty(); redraw(); }));
            jailOut.textContent = jailD.value + '%'; fineOut.textContent = fineD.value + '%';
            const t = chargeTotals(crimes);
            const jd = num(jailD.value), fd = num(fineD.value);
            fill(summary, h('div', null, T('ui_total_summary', 'Total: %d months / %s', t.months, money(t.fine))),
                jd || fd ? h('div', { class: 'tone-green' }, T('ui_after_deduction', 'After deduction: %d months / %s', afterDiscount(t.months, jd), money(afterDiscount(t.fine, fd)))) : null);
        };
        jailD.addEventListener('input', () => { markDirty(); redraw(); });
        fineD.addEventListener('input', () => { markDirty(); redraw(); });
        [title, type, loc].forEach((el) => el.addEventListener('input', markDirty));
        loadPenal();
        loadLinkables(true);
        redraw();
        const meta = h('span', { class: 'muted' }, isNew ? T('ui_new_report', 'New Report')
            : T('ui_report_meta', '#%s · Written by %s · %s', str(x.report_number, x.id), str(x.author_name, T('ui_unknown', 'Unknown')), fmtDate(x.created_at)));
        const saveBtn = h('button', { class: 'btn primary sm', type: 'button' }, icon('save'), T('ui_save', 'Save'));
        const payload = () => ({
            title: title.value.trim(), type: type.value, location: loc.value.trim(),
            content: rich.get(), content_plaintext: rich.plain().slice(0, 500),
            crimes: crimes.map((c) => ({ code: c.code, label: c.label, charge_class: c.charge_class, months: num(c.months), fine: num(c.fine), count: num(c.count, 1) })),
            reduction_percent: num(fineD.value), jail_reduction_percent: num(jailD.value), fine_reduction_percent: num(fineD.value),
            involved: involved.map((p) => ({ citizenid: p.citizenid, name: p.name, type: p.type, notes: p.notes || '' })),
            reportLawmen: lawmen.map((p) => ({ citizenid: p.citizenid, name: p.name, role: p.role })),
            confiscatedItems: conf.map((it) => ({ name: it.name, label: it.label, type: it.type, quantity: num(it.quantity, 1) })),
        });
        const save = () => busy(saveBtn, T('ui_saving', 'Saving…'), async () => {
            const p = payload();
            if (!p.title) { notify(T('ui_title_required', 'A title is required')); title.focus(); return; }
            let r;
            if (x.id) r = await nui('updateReport', Object.assign({ id: num(x.id) }, p), 8000, null);
            else r = await nui('saveReport', p, 8000, null);
            if (!ok(r)) { notify(msgOf(r, T('ui_report_save_failed', 'Failed to save report'))); return; }
            x.id = r.id || x.id;
            if (r.report_number) x.report_number = r.report_number;
            x.title = p.title;
            savedCrimes = crimes.map((c) => Object.assign({}, c));
            dirty = false;
            meta.textContent = T('ui_report_meta', '#%s · Written by %s · %s', str(x.report_number, x.id), str(x.author_name || (App.player || {}).name, ''), fmtDate(x.created_at || Date.now()));
            notify(T('ui_report_saved', 'Report saved'));
            Linkables.data = null;
            load();
        });
        saveBtn.addEventListener('click', save);
        const leave = async () => {
            if (dirty && editable && !(await confirmBox({ message: T('ui_discard_q', 'You have unsaved changes. Discard them?'), confirm: T('ui_discard', 'Discard'), danger: true }))) return false;
            showList();
            return true;
        };
        const fineJail = h('button', { class: 'btn danger', type: 'button' }, icon('lock'), T('ui_fine_and_jail', 'Fine & Jail'));
        fineJail.addEventListener('click', async () => {
            if (!involved.length) { notify(T('ui_need_citizen', 'Add at least one citizen')); return; }
            if (!savedCrimes.length) { notify(crimes.length ? T('ui_save_report_first', 'Save the report first') : T('ui_need_charge', 'Add at least one charge')); return; }
            if (!x.id || dirty) { notify(T('ui_save_report_first', 'Save the report first')); return; }
            const suspects = involved.filter((p) => p.type === 'suspect');
            if (!suspects.length) { notify(T('ui_need_suspect', 'Mark at least one citizen as a Suspect')); return; }
            const t = chargeTotals(savedCrimes);
            const jd = num(jailD.value), fd = num(fineD.value);
            const yes = await confirmBox({
                title: T('ui_fine_and_jail', 'Fine & Jail'), confirm: T('ui_fine_and_jail', 'Fine & Jail'), danger: true,
                message: T('ui_fine_jail_q', 'Fine and jail %d suspect(s): %d months / %s each, after deductions?', suspects.length, afterDiscount(t.months, jd), money(afterDiscount(t.fine, fd))),
            });
            if (!yes) return;
            busy(fineJail, T('ui_processing', 'Processing…'), async () => {
                for (const s of suspects) {
                    const r = await nui('processArrest', {
                        citizenIdentity: s.citizenid, citizenName: s.name,
                        charges: savedCrimes.map((c) => ({ code: c.code, label: c.label, fine: num(c.fine), months: num(c.months), class: c.charge_class, count: num(c.count, 1) })),
                        totalFine: t.fine, totalMonths: t.months, discountPercent: fd, jailDiscountPercent: jd, fineDiscountPercent: fd,
                        finalFine: afterDiscount(t.fine, fd), finalMonths: afterDiscount(t.months, jd),
                        notes: T('ui_report_note', 'Report #%s — %s', str(x.report_number, x.id), str(x.title)),
                        applyFine: true, applyJail: true, targetServerId: 0, reportId: num(x.id),
                        serveLocally: !!(stations.length && local.checked), stationIndex: num(stationSel.value, 1),
                    }, 15000, { success: false, message: T('ui_arrest_timeout', 'The arrest timed out. Check the records before trying again.') });
                    notify(s.name + ': ' + (ok(r) ? msgOf(r, T('ui_arrest_processed', 'Arrest processed')) : msgOf(r, T('ui_arrest_failed', 'The arrest could not be processed'))), 5000);
                }
            });
        });
        const involvedEl = personTags({ list: involved, roleKey: 'type', onChange: markDirty, roles: [['suspect', T('ui_role_suspect', 'Suspect')], ['victim', T('ui_role_victim', 'Victim')], ['witness', T('ui_role_witness', 'Witness')]] });
        const lawmenEl = personTags({ list: lawmen, roleKey: 'role', onChange: markDirty, roles: [['lead', T('ui_role_lead', 'Lead')], ['assisting', T('ui_role_assisting', 'Assisting')], ['supervisor', T('ui_role_supervisor', 'Supervisor')]] });
        const body = h('div', { class: 'editor-body' },
            field(T('ui_col_title', 'Title') + ' *', title),
            row(field(T('ui_col_type', 'Type'), type), field(T('ui_location', 'Location'), loc)),
            section(T('ui_involved_citizens', 'Involved Citizens'), involvedEl),
            section(T('ui_crimes_committed', 'Crimes Committed'), editable ? chargePicker((c) => { addCharge(crimes, c); markDirty(); redraw(); }) : null, crimesEl),
            section(T('ui_col_description', 'Description'), h('small', { class: 'muted' }, T('ui_link_hint', 'Type # to link a case, bounty, evidence or report')), rich.el),
            section(T('ui_confiscated_items', 'Confiscated Items'), confiscationBlock(conf, markDirty)),
            section(T('ui_deductions', 'Deductions'),
                row(field(T('ui_jail_deduction', 'Jail Deduction'), h('div', { class: 'range' }, jailD, jailOut)), field(T('ui_fine_deduction', 'Fine Deduction'), h('div', { class: 'range' }, fineD, fineOut))),
                summary),
            stations.length ? section(T('ui_serve_locally', 'Serve Locally'), h('label', { class: 'check' }, local, ' ', T('ui_hold_local', 'Hold at a local station cell')), stationSel) : null,
            section(T('ui_arresting_lawmen', 'Arresting Lawmen'), lawmenEl),
            can('arrest') && editable ? h('div', { class: 'frow end' }, fineJail) : null);
        if (!editable) body.querySelectorAll('input, select, textarea, button.btn, .stepper button').forEach((el) => { el.disabled = true; });
        if (!editable) rich.editor.setAttribute('contenteditable', 'false');
        fill(editorView, h('div', { class: 'editor page-turn' },
            h('div', { class: 'sheet-head' }, icon('description'), ' ', meta, h('span', { class: 'spacer' }),
                editable ? saveBtn : null,
                x.id && can('deletereports') ? h('button', { class: 'btn danger sm', type: 'button', onclick: () => remove(x, showList) }, icon('delete'), T('ui_delete', 'Delete')) : null,
                h('button', { class: 'x', type: 'button', onclick: leave }, icon('close'))),
            body));
        show(listView, false); show(editorView, true);
        editor = { leave, isDirty: () => dirty };
        popLayer(editorView); pushLayer(editorView, () => { if (rich.el.isDropOpen()) return; leave(); });
        if (isNew) setTimeout(() => title.focus(), 50);
    }
    regTab({
        id: 'reports', icon: 'description', perm: 'reports', feature: 'feature_reports', label: () => T('ui_nav_reports', 'Incident Reports'),
        build: (r) => {
            root = r;
            q = inp({ placeholder: T('ui_search_reports', 'Search title, author or type…') });
            typeSel = sel([['all', T('ui_all', 'All')]].concat(reportTypes()), 'all');
            q.addEventListener('input', debounce(() => load(1), 250));
            typeSel.addEventListener('change', () => load(1));
            listEl = h('div');
            listView = h('div', null, h('h2', { class: 'page-title' }, T('ui_nav_reports', 'Incident Reports')),
                h('div', { class: 'toolbar' }, q, typeSel, refreshBtn('reports', () => load(), 0),
                    can('reports') && !App.lawyer ? h('button', { class: 'btn primary sm', type: 'button', onclick: () => openEditor(null) }, icon('add'), T('ui_new_report', 'New Report')) : null),
                listEl);
            editorView = h('div', { class: 'hidden' });
            add(r, [listView, editorView]);
            loadLinkables(false);
        },
        show: async (o) => {
            if (o && o.openId) {
                if (editor && !(await editor.leave())) return;
                const x = await fetchReport(o.openId);
                if (x) openEditor(x); else notify(T('ui_not_found', 'Not found'));
                load(page);
                return;
            }
            if (!editor) load(page);
        },
        canLeave: async () => (editor && editor.isDirty() ? editor.leave() : true),
        reset: () => { root = null; editor = null; page = 1; rows = []; },
    });
})();
