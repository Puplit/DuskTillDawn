'use strict';
// Case Files (list and full-page editor) and the Evidence Locker catalogue.

const CaseStatus = () => [['open', T('ui_st_open', 'Open')], ['active', T('ui_st_active', 'Active')], ['suspended', T('ui_st_suspended', 'Suspended')], ['closed', T('ui_st_closed', 'Closed')]];
const CasePriority = () => [['low', T('ui_pr_low', 'Low')], ['medium', T('ui_pr_medium', 'Medium')], ['high', T('ui_pr_high', 'High')], ['critical', T('ui_pr_critical', 'Critical')]];
function caseStatusTone(s) { return { open: 'green', active: 'blue', suspended: 'orange', closed: 'grey' }[str(s)] || 'grey'; }
function priorityTone(p) { return { low: 'green', medium: 'orange', high: 'red', critical: 'darkred' }[str(p)] || 'grey'; }
function labelOf(list, v) { const f = list.find((x) => x[0] === v); return f ? f[1] : str(v, '—'); }

(function () {
    let root, listView, editorView, q, stSel, countEl, listEl, page = 1, rows = [], seq = 0, editor = null;
    async function load(p) {
        page = p || page;
        const my = ++seq;
        fill(listEl, loading());
        const r = await nui('getCases', { status: stSel.value === 'all' ? '' : stSel.value, search: q.value.trim(), page }, 8000, null);
        if (my !== seq || !root) return;
        rows = arr(r && r.cases);
        countEl.textContent = T('ui_n_cases', '%d cases', num(r && r.totalRecords, rows.length));
        const filtered = q.value.trim() || stSel.value !== 'all';
        fill(listEl,
            table([
                { label: T('ui_col_case_no', 'Case #'), render: (c) => h('button', { class: 'link', type: 'button', onclick: (e) => { e.stopPropagation(); copyText(str(c.case_number)); } }, str(c.case_number)) },
                { label: T('ui_col_title', 'Title'), render: (c) => str(c.title) },
                { label: T('ui_col_status', 'Status'), render: (c) => badge(labelOf(CaseStatus(), c.status), caseStatusTone(c.status)) },
                { label: T('ui_col_priority', 'Priority'), render: (c) => h('span', { class: 'tone-' + priorityTone(c.priority) }, labelOf(CasePriority(), c.priority)) },
                { label: T('ui_col_assigned', 'Assigned Lawmen'), render: (c) => {
                    const ls = arr(c.lawmen).slice().sort((a, b) => (a.role === 'lead' ? -1 : 0) - (b.role === 'lead' ? -1 : 0)).map((l) => str(l.name));
                    const names = ls.length ? ls : arr(parseJson(c.assigned_lawmen, [])).map(String);
                    return names.length > 2 ? names.slice(0, 2).join(', ') + ' +' + (names.length - 2) : names.join(', ') || '—';
                } },
                { label: T('ui_col_created', 'Created'), render: (c) => fmtDate(c.created_at) },
                { label: '', cls: 'act', render: (c) => [
                    can('evidences') && !App.lawyer ? iconBtn('edit', T('ui_edit', 'Edit'), () => openEditor(c)) : null,
                    can('deleterecords') ? iconBtn('delete', T('ui_delete', 'Delete'), () => remove(c)) : null] },
            ], rows, { onRow: (c) => openEditor(c), empty: filtered ? emptyState(T('ui_no_results_filter', 'No results for this filter'), null, 'filter_alt') : emptyState(T('ui_no_cases', 'No cases found'), T('ui_click_new_case', 'Click New Case to open one'), 'folder') }),
            pager(page, r && r.totalPages, r && r.totalRecords, load));
    }
    async function remove(c, after) {
        if (!(await confirmBox({ message: T('ui_delete_case_q', 'Delete case %s? This cannot be undone.', str(c.case_number)), confirm: T('ui_delete', 'Delete'), danger: true }))) return;
        const r = await nui('deleteCase', { id: num(c.id) }, 8000, null);
        notify(ok(r) ? T('ui_case_deleted', 'Case deleted') : msgOf(r, T('ui_delete_failed', 'Could not delete')));
        if (ok(r)) { if (after) after(); load(); }
    }
    function showList() { if (editor) popLayer(editorView); editor = null; clear(editorView); show(editorView, false); show(listView, true); }
    async function openEditor(c) {
        const isNew = !c;
        c = c || {};
        const editable = can('evidences') && !App.lawyer;
        let dirty = false;
        const md = () => { dirty = true; };
        const title = inp({ value: str(c.title), maxlength: 150 });
        const loc = inp({ value: str(c.location), maxlength: 200 });
        const status = sel(CaseStatus(), str(c.status, 'open'));
        const prio = sel(CasePriority(), str(c.priority, 'medium'));
        const desc = area({ rows: 5, value: str(c.description), maxlength: 4000 });
        const inv = inp({ value: str(c.investigator_name), maxlength: 100 });
        [title, loc, status, prio, desc, inv].forEach((el) => el.addEventListener('input', md));
        const involved = arr(c.involved).map((p) => ({ citizenid: str(p.citizenid), name: str(p.name), type: str(p.type, 'suspect'), notes: str(p.notes) }));
        const lawmen = arr(c.lawmen).map((p) => ({ citizenid: str(p.citizenid), name: str(p.name), role: str(p.role, 'lead') }));
        const conf = arr(parseJson(c.confiscated_items, [])).map((it) => ({ name: str(it.name), label: str(it.label || it.name), type: it.type === 'weapon' ? 'weapon' : 'item', quantity: num(it.quantity, 1) }));
        // linked evidence: stored list plus items that point at this case
        const linked = [];
        for (const e of arr(parseJson(c.linked_evidence, []))) {
            const id = num(typeof e === 'object' ? e.id : e);
            if (id && !linked.some((l) => l.id === id)) linked.push({ id, title: str(typeof e === 'object' ? e.title : '') });
        }
        const evSel = h('select', { class: 'inp' });
        const evTags = h('div', { class: 'tags' });
        const evHint = h('small', { class: 'muted' });
        let evItems = [];
        const redrawEv = () => {
            clear(evSel);
            const avail = evItems.filter((e) => !linked.some((l) => l.id === num(e.id)));
            evSel.appendChild(h('option', { value: '' }, T('ui_pick_evidence', '— pick evidence —')));
            for (const e of avail) {
                const other = str(e.linked_case) && str(e.linked_case) !== str(c.case_number);
                evSel.appendChild(h('option', { value: String(e.id) }, '#' + e.id + ' — ' + str(e.title || e.label) + (other ? ' ' + T('ui_linked_elsewhere', '(linked: %s)', str(e.linked_case)) : '')));
            }
            evHint.textContent = !evItems.length ? T('ui_no_evidence_yet', 'No evidence yet') : (!avail.length ? T('ui_all_linked_here', 'All evidence is linked here') : '');
            fill(evTags, linked.length ? linked.map((l, i) => h('span', { class: 'tag' }, '#' + l.id + ' ' + str(l.title),
                editable ? h('button', { class: 'tag-x', type: 'button', onclick: () => { linked.splice(i, 1); md(); redrawEv(); } }, '×') : null)) : h('span', { class: 'muted' }, T('ui_none', 'None')));
        };
        nui('getEvidenceItems', {}, 8000, []).then((r) => {
            evItems = arr(r);
            if (isNew === false) {
                for (const e of evItems) {
                    if (c.case_number && str(e.linked_case) === str(c.case_number) && !linked.some((l) => l.id === num(e.id))) linked.push({ id: num(e.id), title: str(e.title || e.label) });
                }
            }
            for (const l of linked) { const e = evItems.find((x) => num(x.id) === l.id); if (e && !l.title) l.title = str(e.title || e.label); }
            redrawEv();
        });
        redrawEv();
        const linkBtn = h('button', { class: 'btn sm', type: 'button', onclick: () => {
            const id = num(evSel.value);
            if (!id) return;
            if (linked.some((l) => l.id === id)) { notify(T('ui_already_linked', 'Already linked')); return; }
            const e = evItems.find((x) => num(x.id) === id);
            linked.push({ id, title: str(e && (e.title || e.label)) });
            md(); redrawEv();
        } }, icon('link'), T('ui_link', 'Link'));
        const saveBtn = h('button', { class: 'btn primary', type: 'button' }, icon('save'), T('ui_save_case', 'Save Case'));
        const leave = async () => {
            if (dirty && editable && !(await confirmBox({ message: T('ui_discard_q', 'You have unsaved changes. Discard them?'), confirm: T('ui_discard', 'Discard'), danger: true }))) return false;
            showList(); return true;
        };
        saveBtn.addEventListener('click', () => busy(saveBtn, T('ui_saving', 'Saving…'), async () => {
            if (!title.value.trim()) { notify(T('ui_title_required', 'A title is required')); return; }
            const p = {
                title: title.value.trim(), location: loc.value.trim(), status: status.value, priority: prio.value,
                description: desc.value.trim(), investigator_name: inv.value.trim(),
                assignedLawmen: lawmen.map((l) => l.name), linkedReports: [],
                linkedEvidence: linked.map((l) => ({ id: l.id, title: l.title })),
                involved: involved.map((x) => ({ citizenid: x.citizenid, name: x.name, type: x.type, notes: x.notes || '' })),
                caseLawmen: lawmen.map((x) => ({ citizenid: x.citizenid, name: x.name, role: x.role })),
                confiscatedItems: conf.map((it) => ({ name: it.name, label: it.label, type: it.type, quantity: num(it.quantity, 1) })),
            };
            if (c.id) { p.id = num(c.id); p.case_number = str(c.case_number); }
            const r = await nui('saveCase', p, 8000, null);
            if (!ok(r)) { notify(msgOf(r, T('ui_save_failed', 'Could not save'))); return; }
            notify(c.id ? T('ui_case_updated', 'Case updated') : T('ui_case_created', 'Case created'));
            dirty = false;
            Linkables.data = null;
            showList(); load();
        }));
        const body = h('div', { class: 'editor-body' },
            field(T('ui_col_title', 'Title') + ' *', title),
            field(T('ui_location', 'Location'), loc),
            row(field(T('ui_col_status', 'Status'), status), field(T('ui_col_priority', 'Priority'), prio)),
            section(T('ui_involved_citizens', 'Involved Citizens'), personTags({ list: involved, roleKey: 'type', onChange: md, roles: [['suspect', T('ui_role_suspect', 'Suspect')], ['victim', T('ui_role_victim', 'Victim')], ['witness', T('ui_role_witness', 'Witness')], ['person_of_interest', T('ui_role_poi', 'Person of Interest')]] })),
            field(T('ui_case_summary', 'Description / Summary'), desc),
            section(T('ui_linked_evidence', 'Linked Evidence'), editable ? h('div', { class: 'frow tight' }, evSel, linkBtn) : null, evHint, evTags),
            field(T('ui_investigator', 'Investigator'), inv),
            section(T('ui_lawmen_in_charge', 'Lawmen In Charge'), personTags({ list: lawmen, roleKey: 'role', onChange: md, roles: [['lead', T('ui_role_lead_inv', 'Lead Investigator')], ['assisting', T('ui_role_assisting', 'Assisting')], ['supervisor', T('ui_role_supervisor', 'Supervisor')], ['consulting', T('ui_role_consulting', 'Consulting')]] })),
            section(T('ui_confiscated_items', 'Confiscated Items'), confiscationBlock(conf, md)));
        if (!editable) body.querySelectorAll('input, select, textarea, button').forEach((el) => { el.disabled = true; });
        fill(editorView, h('div', { class: 'editor page-turn' },
            h('div', { class: 'sheet-head' }, icon('folder'), ' ', h('b', null, isNew ? T('ui_new_case', 'New Case') : T('ui_edit_case', 'Edit Case')), ' ', h('span', { class: 'muted' }, str(c.case_number)),
                h('span', { class: 'spacer' }), h('button', { class: 'x', type: 'button', onclick: leave }, icon('close'))),
            body,
            h('div', { class: 'frow end' },
                h('button', { class: 'btn ghost', type: 'button', onclick: leave }, T('ui_cancel', 'Cancel')),
                c.id && can('deleterecords') ? h('button', { class: 'btn danger', type: 'button', onclick: () => remove(c, showList) }, T('ui_delete', 'Delete')) : null,
                editable ? saveBtn : null)));
        show(listView, false); show(editorView, true);
        editor = { leave, isDirty: () => dirty };
        popLayer(editorView); pushLayer(editorView, leave);
    }
    regTab({
        id: 'cases', icon: 'folder', perm: 'evidences', feature: 'feature_evidences', label: () => T('ui_nav_cases', 'Case Files'),
        build: (r) => {
            root = r;
            q = inp({ placeholder: T('ui_search_case', 'Search number or title…') });
            stSel = sel([['all', T('ui_all', 'All')]].concat(CaseStatus()), 'all');
            countEl = h('span', { class: 'muted' });
            listEl = h('div');
            q.addEventListener('input', debounce(() => load(1), 300));
            stSel.addEventListener('change', () => load(1));
            listView = h('div', null, h('h2', { class: 'page-title' }, T('ui_nav_cases', 'Case Files')),
                h('div', { class: 'toolbar' }, q, stSel, countEl,
                    can('evidences') && !App.lawyer ? h('button', { class: 'btn primary sm', type: 'button', onclick: () => openEditor(null) }, icon('create_new_folder'), T('ui_new_case', 'New Case')) : null,
                    refreshBtn('cases', () => load(), 0)),
                listEl);
            editorView = h('div', { class: 'hidden' });
            add(r, [listView, editorView]);
        },
        show: async (o) => {
            if (o && o.openId) {
                if (editor && !(await editor.leave())) return;
                let c = rows.find((x) => num(x.id) === num(o.openId));
                if (!c) {
                    const r = await nui('getCases', { status: '', search: '', page: 1, id: num(o.openId) }, 8000, null);
                    c = arr(r && r.cases).find((x) => num(x.id) === num(o.openId));
                }
                if (c) openEditor(c); else notify(T('ui_not_found', 'Not found'));
                load(page);
                return;
            }
            if (!editor) load(page);
        },
        canLeave: async () => (editor && editor.isDirty() ? editor.leave() : true),
        reset: () => { root = null; editor = null; rows = []; page = 1; },
    });
})();

// ---------- Evidence Locker (catalogue) ----------
// the values are the server's own type names (server/reports.lua EVIDENCE_TYPES)
const EvidenceTypes = () => [
    ['bloodstain', T('ui_ev_blood', 'Blood Stain'), 'water_drop', 'red'], ['boot print', T('ui_ev_boot', 'Boot Print'), 'do_not_step', 'brown'],
    ['horse track', T('ui_ev_horse', 'Horse Track'), 'pets', 'brown'], ['spent casing', T('ui_ev_casing', 'Spent Casing'), 'radio_button_checked', 'gold'],
    ['weapon', T('ui_ev_weapon', 'Weapon'), 'hardware', 'grey'], ['document', T('ui_ev_document', 'Document'), 'article', 'blue'],
    ['contraband', T('ui_ev_contraband', 'Contraband'), 'local_bar', 'purple'], ['item', T('ui_ev_physical', 'Physical Item'), 'category', 'brown'],
    ['photograph', T('ui_ev_photo', 'Photograph'), 'photo_camera', 'blue'], ['fingerprint', T('ui_ev_fingerprint', 'Fingerprint'), 'fingerprint', 'purple'],
    ['fabric', T('ui_ev_fabric', 'Fabric/Clothing'), 'checkroom', 'teal'], ['other', T('ui_ev_other', 'Other'), 'help', 'grey']];
const EvidenceStatus = () => [['collected', T('ui_es_collected', 'Collected')], ['analyzed', T('ui_es_analyzed', 'Analyzed')], ['stored', T('ui_es_stored', 'Stored')], ['destroyed', T('ui_es_destroyed', 'Destroyed')]];
function evType(t) { return EvidenceTypes().find((x) => x[0] === str(t).toLowerCase()) || ['other', str(t, T('ui_ev_other', 'Other')), 'help', 'grey']; }
function evStatusTone(s) { return { collected: 'blue', analyzed: 'green', stored: 'grey', destroyed: 'red' }[str(s)] || 'grey'; }

(function () {
    let root, q, typeSel, stSel, countEl, listEl, page = 1, rows = [], seq = 0;
    async function load(p) {
        page = p || page;
        const my = ++seq;
        fill(listEl, loading());
        const r = await nui('getEvidence', { type: typeSel.value === 'all' ? '' : typeSel.value, status: stSel.value === 'all' ? '' : stSel.value, search: q.value.trim(), page }, 8000, null);
        if (my !== seq || !root) return;
        rows = arr(r && r.evidence);
        countEl.textContent = T('ui_n_items', '%d items', num(r && r.totalRecords, rows.length));
        fill(listEl,
            table([
                { label: T('ui_col_type', 'Type'), render: (e) => { const t = evType(e.type); return h('span', { class: 'tone-' + t[3] }, icon(t[2]), ' ', t[1]); } },
                { label: T('ui_col_label', 'Label'), render: (e) => str(e.label) },
                { label: T('ui_location_found', 'Location Found'), render: (e) => str(e.location_found, '—') },
                { label: T('ui_collected_by', 'Collected By'), render: (e) => str(e.collected_by, '—') },
                { label: T('ui_linked_case', 'Linked Case'), render: (e) => str(e.linked_case, '—') },
                { label: T('ui_col_status', 'Status'), render: (e) => badge(labelOf(EvidenceStatus(), e.status), evStatusTone(e.status)) },
                { label: T('ui_col_date', 'Date'), render: (e) => fmtDate(e.created_at) },
                { label: '', cls: 'act', render: (e) => iconBtn('visibility', T('ui_view', 'View'), () => detail(e)) },
            ], rows, { onRow: (e) => detail(e), empty: emptyState(T('ui_no_evidence', 'No evidence found'), null, 'inventory_2') }),
            pager(page, r && r.totalPages, r && r.totalRecords, load));
    }
    function photos(list) {
        return h('div', { class: 'polaroids' }, list.map((p) => {
            const u = typeof p === 'string' ? p : str(p.url);
            const cap = typeof p === 'string' ? '' : str(p.caption);
            if (!isHttpUrl(u)) return null;
            return h('figure', { class: 'polaroid' }, img(u, '', (el) => el.closest('figure').classList.add('broken')), h('figcaption', null, cap));
        }));
    }
    function detail(e) {
        const t = evType(e.type);
        const st = sel(EvidenceStatus(), str(e.status, 'collected'));
        const canEdit = can('evidences') && !App.lawyer;
        if (!canEdit) st.disabled = true;
        const m = modal({
            title: t[1], icon: t[2], cls: 'wide ev-detail tone-' + t[3], backdropCloses: true,
            body: [photos(arr(parseJson(e.image_urls, []))),
                h('h3', null, str(e.label)), h('p', null, str(e.description) || T('ui_no_description', 'No description provided')),
                h('div', { class: 'grid2' },
                    h('div', null, h('span', { class: 'lbl' }, T('ui_location_found', 'Location Found')), ' ', str(e.location_found, '—')),
                    h('div', null, h('span', { class: 'lbl' }, T('ui_collected_by', 'Collected By')), ' ', str(e.collected_by, '—')),
                    h('div', null, h('span', { class: 'lbl' }, T('ui_linked_case', 'Linked Case')), ' ', str(e.linked_case, '—')),
                    h('div', null, h('span', { class: 'lbl' }, T('ui_date_collected', 'Date Collected')), ' ', fmtDate(e.created_at))),
                e.notes ? section(T('ui_notes', 'Notes'), h('p', { class: 'pre' }, str(e.notes))) : null,
                field(T('ui_update_status', 'Update Status'), st)],
            footer: [
                can('deleterecords') ? h('button', { class: 'btn danger', type: 'button', onclick: async () => {
                    if (!(await confirmBox({ message: T('ui_delete_evidence_q', 'Delete evidence %s?', str(e.label)), confirm: T('ui_delete', 'Delete'), danger: true }))) return;
                    const r = await nui('deleteEvidence', { id: num(e.id) }, 8000, null);
                    notify(ok(r) ? T('ui_evidence_deleted', 'Evidence deleted') : msgOf(r, T('ui_delete_failed', 'Could not delete')));
                    if (ok(r)) { m.close(true); load(); Linkables.data = null; }
                } }, T('ui_delete', 'Delete')) : null,
                h('button', { class: 'btn ghost', type: 'button', onclick: () => m.close() }, T('ui_close', 'Close')),
                canEdit ? h('button', { class: 'btn primary', type: 'button', onclick: async (ev) => {
                    const b = ev.currentTarget;
                    busy(b, T('ui_saving', 'Saving…'), async () => {
                        const r = await nui('saveEvidence', { id: num(e.id), status: st.value }, 8000, null);
                        notify(ok(r) ? T('ui_status_saved', 'Status saved') : msgOf(r, T('ui_save_failed', 'Could not save')));
                        if (ok(r)) { m.close(true); load(); }
                    });
                } }, T('ui_save_status', 'Save Status')) : null],
        });
    }
    function newEvidence() {
        const type = sel(EvidenceTypes().map((x) => [x[0], x[1]]), 'bloodstain');
        const label = inp({ maxlength: 150 });
        const desc = area({ maxlength: 2000 });
        const loc = inp({ maxlength: 200 });
        const caseSel = h('select', { class: 'inp' }, h('option', { value: '' }, T('ui_none', 'None')));
        nui('getCasesList', {}, 8000, []).then((r) => arr(r).forEach((c) => caseSel.appendChild(h('option', { value: str(c.case_number) }, str(c.case_number) + ' — ' + str(c.title) + ' [' + str(c.status) + ']'))));
        const notes = area({ maxlength: 2000 });
        const photoRows = h('div');
        const preview = h('div', { class: 'polaroids' });
        const urls = [];
        const redrawPreview = () => { const p = photos(urls.filter((x) => isHttpUrl(x.url))); fill(preview, Array.from(p.childNodes)); };
        const addRow = () => {
            const entry = { url: '', caption: '' };
            urls.push(entry);
            const u = inp({ placeholder: 'https://…' }), c = inp({ placeholder: T('ui_caption', 'Caption') });
            u.addEventListener('input', debounce(() => { entry.url = u.value.trim(); redrawPreview(); }, 300));
            c.addEventListener('input', () => { entry.caption = c.value.trim(); });
            const r = h('div', { class: 'frow tight' }, u, c, h('button', { class: 'tag-x', type: 'button', onclick: () => { urls.splice(urls.indexOf(entry), 1); r.remove(); redrawPreview(); } }, '×'));
            photoRows.appendChild(r);
        };
        addRow();
        const saveB = h('button', { class: 'btn primary', type: 'button' }, T('ui_save', 'Save'));
        const m = modal({
            title: T('ui_log_evidence', 'Log New Evidence'), icon: 'inventory_2', cls: 'wide',
            body: [row(field(T('ui_col_type', 'Type'), type), field(T('ui_label_name', 'Label / Name') + ' *', label)),
                field(T('ui_col_description', 'Description'), desc),
                row(field(T('ui_location_found', 'Location Found'), loc), field(T('ui_linked_case', 'Linked Case'), caseSel)),
                field(T('ui_notes', 'Notes'), notes),
                section(T('ui_photos', 'Photos'), photoRows, h('button', { class: 'link', type: 'button', onclick: addRow }, T('ui_add_photo', '+ Add Photo URL')), preview)],
            footer: [h('button', { class: 'btn ghost', type: 'button', onclick: () => m.close() }, T('ui_cancel', 'Cancel')), saveB],
        });
        saveB.addEventListener('click', () => busy(saveB, T('ui_saving', 'Saving…'), async () => {
            if (!label.value.trim()) { notify(T('ui_label_required', 'A label is required')); return; }
            const bad = urls.find((p) => p.url && !isHttpUrl(p.url));
            if (bad) { notify(T('ui_url_http', 'Only http(s) links are accepted')); return; }
            const r = await nui('saveEvidence', { type: type.value, label: label.value.trim(), description: desc.value.trim(), location_found: loc.value.trim(), linked_case: caseSel.value, notes: notes.value.trim(), image_urls: urls.filter((p) => p.url).map((p) => ({ url: p.url, caption: p.caption })) }, 8000, null);
            notify(ok(r) ? msgOf(r, T('ui_evidence_logged', 'Evidence logged')) : msgOf(r, T('ui_save_failed', 'Could not save')));
            if (ok(r)) { m.close(true); load(1); Linkables.data = null; }
        }));
    }
    regTab({
        id: 'evidence', icon: 'inventory_2', perm: 'evidences', feature: 'feature_evidences', label: () => T('ui_nav_evidence', 'Evidence Locker'),
        build: (r) => {
            root = r;
            q = inp({ placeholder: T('ui_search_label_loc', 'Search label or location…') });
            typeSel = sel([['all', T('ui_all', 'All')]].concat(EvidenceTypes().map((x) => [x[0], x[1]])), 'all');
            stSel = sel([['all', T('ui_all', 'All')]].concat(EvidenceStatus()), 'all');
            countEl = h('span', { class: 'muted' });
            listEl = h('div');
            q.addEventListener('input', debounce(() => load(1), 350));
            typeSel.addEventListener('change', () => load(1));
            stSel.addEventListener('change', () => load(1));
            add(r, [h('h2', { class: 'page-title' }, T('ui_nav_evidence', 'Evidence Locker')),
                h('div', { class: 'toolbar' }, q, typeSel, stSel, countEl,
                    can('evidences') && !App.lawyer ? h('button', { class: 'btn primary sm', type: 'button', onclick: newEvidence }, icon('add'), T('ui_new_evidence', 'New Evidence')) : null,
                    refreshBtn('evidence', () => load(), 0)),
                listEl]);
        },
        show: async (o) => {
            await load(page);
            if (o && o.openId) {
                let e = rows.find((x) => num(x.id) === num(o.openId));
                if (!e) {
                    const r = await nui('getEvidence', { type: '', status: '', search: '', page: 1, id: num(o.openId) }, 8000, null);
                    e = arr(r && r.evidence).find((x) => num(x.id) === num(o.openId));
                }
                if (e) detail(e); else notify(T('ui_not_found', 'Not found'));
            }
        },
        reset: () => { root = null; rows = []; page = 1; },
    });
})();
