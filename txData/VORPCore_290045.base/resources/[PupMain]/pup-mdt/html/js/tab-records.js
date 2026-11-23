'use strict';
// Citations (penal code editor), Bounties, Most Wanted, Witness Statements.

// ---------- Citations ----------
(function () {
    let root, listEl, q, classSel, countEl, page = 1, codes = [];
    async function load(force) {
        fill(listEl, loading());
        codes = await loadPenal(force);
        draw();
    }
    function draw() {
        if (!root) return;
        const t = q.value.trim().toLowerCase(), c = classSel.value;
        const rows = codes.filter((x) => (!t || str(x.code).toLowerCase().includes(t) || str(x.label).toLowerCase().includes(t)) && (c === 'all' || str(x.charge_class).toLowerCase() === c));
        countEl.textContent = T('ui_n_charges', '%d charges', rows.length);
        const pg = slicePage(rows, page, 25); page = pg.page;
        fill(listEl,
            table([
                { label: T('ui_col_code', 'Code'), render: (x) => h('b', null, str(x.code)) },
                { label: T('ui_col_charge', 'Charge'), render: (x) => str(x.label) },
                { label: T('ui_col_class', 'Class'), render: (x) => h('span', { class: 'badge outline tone-' + classTone(x.charge_class) }, classLabel(x.charge_class)) },
                { label: T('ui_col_fine', 'Fine'), render: (x) => money(x.fine) },
                { label: T('ui_col_jail', 'Jail'), render: (x) => num(x.months) > 0 ? T('ui_n_mo_dot', '%d mo.', num(x.months)) : '—' },
                { label: T('ui_col_description', 'Description'), cls: 'trunc', render: (x) => cut(x.description, 60), title: (x) => str(x.description) },
            ], pg.rows, { onRow: (x) => editor(x), empty: emptyState(T('ui_no_charges', 'No charges found'), null, 'gavel') }),
            pager(pg.page, pg.totalPages, pg.total, (p) => { page = p; draw(); }));
    }
    function editor(x) {
        const isNew = !x;
        x = x || {};
        const code = inp({ value: str(x.code), placeholder: 'P.C. 1001', readOnly: !isNew, maxlength: 20 });
        const label = inp({ value: str(x.label), maxlength: 120 });
        const cls = sel([['infraction', T('ui_class_infraction', 'Infraction')], ['misdemeanor', T('ui_class_misdemeanor', 'Misdemeanor')], ['felony', T('ui_class_felony', 'Felony')]], str(x.charge_class, 'misdemeanor'));
        const fine = numInp({ value: isNew ? num(App.settings.default_fine, 0) : num(x.fine) });
        const months = numInp({ value: isNew ? num(App.settings.default_jailtime, 0) : num(x.months) });
        const desc = inp({ value: str(x.description), maxlength: 255 });
        const canEdit = can('managecharges') && !App.lawyer;
        [code, label, cls, fine, months, desc].forEach((el) => { if (!canEdit) el.disabled = true; });
        const saveBtn = h('button', { class: 'btn primary', type: 'button' }, T('ui_save', 'Save'));
        const m = modal({
            title: isNew ? T('ui_new_charge', 'New Charge') : T('ui_edit_charge', 'Edit Charge'), icon: 'gavel',
            body: [field(T('ui_penal_code', 'Penal Code'), code), field(T('ui_charge_name', 'Charge Name'), label),
                row(field(T('ui_col_class', 'Class'), cls), field(T('ui_fine_dollar', 'Fine ($)'), fine), field(T('ui_jail_months', 'Jail (months)'), months)),
                field(T('ui_col_description', 'Description'), desc)],
            footer: [
                h('button', { class: 'btn ghost', type: 'button', onclick: () => m.close() }, T('ui_cancel', 'Cancel')),
                !isNew && canEdit ? h('button', { class: 'btn danger', type: 'button', onclick: async () => {
                    if (!(await confirmBox({ message: T('ui_delete_code_q', 'Delete penal code %s?', str(x.code)), confirm: T('ui_delete', 'Delete'), danger: true }))) return;
                    const r = await nui('deletePenalCode', { code: str(x.code) }, 8000, null);
                    notify(ok(r) ? T('ui_charge_deleted', 'Charge deleted') : msgOf(r, T('ui_delete_failed', 'Could not delete')));
                    if (ok(r)) { m.close(true); load(true); }
                } }, T('ui_delete', 'Delete')) : null,
                canEdit ? saveBtn : null,
            ],
        });
        saveBtn.addEventListener('click', () => busy(saveBtn, T('ui_saving', 'Saving…'), async () => {
            const c = code.value.trim(), l = label.value.trim();
            if (!c || !l) { notify(T('ui_code_label_required', 'Penal code and charge name are required')); return; }
            if (num(fine.value) < 0 || num(months.value) < 0) { notify(T('ui_no_negative', 'Values cannot be negative')); return; }
            if (isNew && codes.some((y) => str(y.code).toLowerCase() === c.toLowerCase())) { notify(T('ui_code_exists', 'That penal code already exists')); return; }
            const colors = { felony: 'red', misdemeanor: 'orange', infraction: 'green' };
            const r = await nui('savePenalCode', { code: c, label: l, charge_class: cls.value, fine: Math.floor(num(fine.value)), months: Math.floor(num(months.value)), color: colors[cls.value], description: desc.value.trim(), isNew }, 8000, null);
            notify(ok(r) ? T('ui_charge_saved', 'Charge saved') : msgOf(r, T('ui_save_failed', 'Could not save')));
            if (ok(r)) { m.close(true); load(true); }
        }));
    }
    regTab({
        id: 'citations', icon: 'gavel', perm: 'fines', feature: 'feature_fines', label: () => T('ui_nav_citations', 'Citations'),
        build: (r) => {
            root = r;
            q = inp({ placeholder: T('ui_search_code_name', 'Search code or name…') });
            classSel = sel([['all', T('ui_all', 'All')], ['felony', T('ui_class_felony', 'Felony')], ['misdemeanor', T('ui_class_misdemeanor', 'Misdemeanor')], ['infraction', T('ui_class_infraction', 'Infraction')]], 'all');
            countEl = h('span', { class: 'muted' });
            listEl = h('div');
            q.addEventListener('input', debounce(() => { page = 1; draw(); }, 250));
            classSel.addEventListener('change', () => { page = 1; draw(); });
            add(r, [h('h2', { class: 'page-title' }, T('ui_nav_citations', 'Citations')),
                h('div', { class: 'toolbar' }, q, classSel, countEl, refreshBtn('citations', () => load(true)),
                    can('managecharges') && !App.lawyer ? h('button', { class: 'btn primary sm', type: 'button', onclick: () => editor(null) }, icon('add'), T('ui_new_charge', 'New Charge')) : null),
                listEl]);
        },
        show: () => load(false),
        reset: () => { root = null; page = 1; codes = []; },
    });
})();

// ---------- Bounties ----------
function bountyStatusTone(s) { return { active: 'red', served: 'green', expired: 'grey', revoked: 'grey' }[str(s)] || 'grey'; }
function parseChargeText(text) {
    const out = [];
    const list = Penal.list || [];
    for (let piece of str(text).split(/\s*,\s*/)) {
        piece = piece.trim();
        if (!piece) continue;
        let count = 1;
        const m = /\s+x(\d+)$/i.exec(piece);
        if (m) { count = Math.max(1, num(m[1], 1)); piece = piece.slice(0, m.index).trim(); }
        const code = list.find((c) => piece.toLowerCase().startsWith(str(c.code).toLowerCase() + ' ') || piece.toLowerCase() === str(c.code).toLowerCase())
            || list.find((c) => str(c.label).toLowerCase() === piece.toLowerCase());
        if (code) out.push({ code: code.code, label: code.label, charge_class: code.charge_class, months: num(code.months), fine: num(code.fine), count });
        else out.push({ code: '', label: piece, count, months: null, fine: null });
    }
    return out;
}
function chargeText(items) { return items.map((c) => (c.code ? c.code + ' ' : '') + c.label + (num(c.count, 1) > 1 ? ' x' + num(c.count) : '')).join(', '); }

(function () {
    let root, listWrap, sheetWrap, q, stSel, page = 1, rows = [], openId = null;
    async function load() {
        fill(listWrap, loading());
        const r = await nui('getWarrants', {}, 8000, null);
        rows = arr(r);
        draw();
    }
    function draw() {
        if (!root) return;
        const t = q.value.trim().toLowerCase(), s = stSel.value;
        const list = rows.filter((w) => (!t || str(w.citizen_name).toLowerCase().includes(t) || str(w.charges).toLowerCase().includes(t)) && (s === 'all' || str(w.status) === s));
        const pg = slicePage(list, page, 25); page = pg.page;
        fill(listWrap,
            table([
                { label: T('ui_col_citizen', 'Citizen'), render: (w) => str(w.citizen_name, T('ui_unknown', 'Unknown')) },
                { label: T('ui_charges', 'Charges'), cls: 'trunc', render: (w) => str(w.charges) ? cut(w.charges, 50) : h('span', { class: 'muted' }, T('ui_no_charges_listed', 'No charges listed')), title: (w) => str(w.charges) },
                { label: T('ui_col_status', 'Status'), render: (w) => { const b = badge(str(w.status, 'active'), bountyStatusTone(w.status)); if (w.status === 'revoked') b.title = T('ui_revoked_by', 'Revoked by %s · %s', str(w.revoked_by, '—'), fmtDate(w.revoked_at)); return b; } },
                { label: T('ui_col_reward', 'Reward'), render: (w) => money(w.bounty_reward !== undefined ? w.bounty_reward : w.reward) },
                { label: T('ui_col_expires', 'Expires'), render: (w) => w.expiry_date ? fmtDate(w.expiry_date) : T('ui_no_expiry', 'No expiry') },
                { label: '', cls: 'act', render: (w) => can('deletewarrants') ? iconBtn('delete', T('ui_delete', 'Delete'), () => remove(w)) : null },
            ], pg.rows, { onRow: (w) => openSheet(w), rowClass: (w) => String(w.id) === String(openId) ? 'active' : '', empty: emptyState(T('ui_no_bounties', 'No active bounties'), null, 'balance') }),
            pager(pg.page, pg.totalPages, pg.total, (p) => { page = p; draw(); }));
    }
    async function remove(w) {
        if (!(await confirmBox({ message: T('ui_delete_bounty_q', 'Delete the bounty on %s?', str(w.citizen_name)), confirm: T('ui_delete', 'Delete'), danger: true }))) return;
        const r = await nui('deleteWarrant', { id: num(w.id) }, 8000, null);
        notify(ok(r) ? T('ui_bounty_deleted', 'Bounty deleted') : msgOf(r, T('ui_delete_failed', 'Could not delete')));
        if (ok(r)) { if (String(openId) === String(w.id)) closeSheet(); load(); }
    }
    function closeSheet() { openId = null; clear(sheetWrap); root.classList.remove('split'); popLayer(sheetWrap); draw(); }
    function openSheet(w) {
        const isNew = !w;
        w = w || {};
        openId = isNew ? 'new' : w.id;
        const editable = can('issuewarrants') && !App.lawyer;
        const charges = [];
        const cid = inp({ value: str(w.citizenid), placeholder: T('ui_optional', 'optional') });
        const cname = inp({ value: str(w.citizen_name), maxlength: 100 });
        const look = lookLine();
        const expiry = inp({ type: 'date', value: isoDay(w.expiry_date) });
        const stOpts = [['active', T('ui_st_active', 'Active')], ['served', T('ui_st_served', 'Served')], ['expired', T('ui_st_expired', 'Expired')]];
        if (can('deletewarrants') || w.status === 'revoked') stOpts.push(['revoked', T('ui_st_revoked', 'Revoked')]);
        const status = sel(stOpts, str(w.status, 'active'));
        const reward = numInp({ value: w.id ? num(w.bounty_reward !== undefined ? w.bounty_reward : w.reward) : '' });
        const fine = numInp({ value: w.id ? num(w.bounty_fine !== undefined ? w.bounty_fine : w.fine) : '' });
        const jail = numInp({ value: w.id ? num(w.bounty_jailtime !== undefined ? w.bounty_jailtime : w.jailtime) : '' });
        const imgUrl = inp({ value: str(w.image_url || w.imgurl), placeholder: 'https://…' });
        const pv = img(str(w.image_url || w.imgurl), 'poster-preview');
        const notes = area({ rows: 5, value: str(w.notes), maxlength: 2000 });
        const tagsEl = h('div');
        const suggest = h('div', { class: 'suggest' });
        let touched = !isNew;
        const redraw = () => {
            fill(tagsEl, chargeTags(charges, editable, redraw));
            const t = chargeTotals(charges);
            if (!touched) { fine.value = String(t.fine); jail.value = String(t.months); }
            if (editable && reward.value === '' && isNew) reward.placeholder = String(t.fine);
            const differs = touched && (num(fine.value) !== t.fine || num(jail.value) !== t.months);
            fill(suggest, T('ui_suggested', 'Suggested from charges: %d months / %s', t.months, money(t.fine)),
                differs && editable ? h('button', { class: 'link', type: 'button', onclick: () => { fine.value = String(t.fine); jail.value = String(t.months); redraw(); } }, ' ' + T('ui_apply', 'Apply')) : null);
        };
        fine.addEventListener('input', () => { touched = true; redraw(); });
        jail.addEventListener('input', () => { touched = true; redraw(); });
        imgUrl.addEventListener('input', () => { const u = imgUrl.value.trim(); pv.classList.toggle('hidden', !isHttpUrl(u)); if (isHttpUrl(u)) pv.src = u; });
        watchLookup(cid, 400, (v) => nui('lookupBoloCitizen', { citizenIdentity: v }, 8000, null), (r, v) => {
            if (r === undefined) setLook(look, T('ui_looking_up', 'Looking up…'));
            else if (r === null && !v) setLook(look, '');
            else if (r && r.found) { setLook(look, T('ui_name_found', '%s — found.', str(r.name)), 'green'); if (editable) cname.value = str(r.name); }
            else if (r === null) setLook(look, T('ui_lookup_failed', 'Lookup failed'), 'red');
            else setLook(look, T('ui_no_citizen_found', 'No citizen found'), 'red');
        });
        loadPenal().then(() => { if (w.charges) { charges.splice(0, charges.length, ...parseChargeText(w.charges)); } redraw(); });
        const head = isNew ? T('ui_new_bounty', 'New Bounty')
            : T('ui_posted_by_on', 'Posted by %s · %s', str(w.issued_by, '—'), fmtDate(w.created_at)) + (w.status === 'revoked' ? ' · ' + T('ui_revoked_by', 'Revoked by %s · %s', str(w.revoked_by, '—'), fmtDate(w.revoked_at)) : '');
        const headEl = h('span', { class: 'muted' }, head);
        const saveBtn = h('button', { class: 'btn primary sm', type: 'button' }, icon('save'), T('ui_save', 'Save'));
        saveBtn.addEventListener('click', () => busy(saveBtn, T('ui_saving', 'Saving…'), async () => {
            if (!cname.value.trim()) { notify(T('ui_citizen_name_required', 'Citizen name is required')); return; }
            for (const el of [reward, fine, jail]) if (num(el.value) < 0) { notify(T('ui_no_negative', 'Values cannot be negative')); return; }
            const t = chargeTotals(charges);
            const payload = {
                citizen_name: cname.value.trim(), citizenid: cid.value.trim(), charges: chargeText(charges),
                expiry_date: expiry.value || null, status: status.value, notes: notes.value.trim(),
                fine: Math.floor(num(fine.value === '' ? t.fine : fine.value)), jailtime: Math.floor(num(jail.value === '' ? t.months : jail.value)),
                reward: Math.floor(num(reward.value === '' ? t.fine : reward.value)), image_url: imgUrl.value.trim(),
            };
            if (payload.image_url && !isHttpUrl(payload.image_url)) { notify(T('ui_url_http', 'Only http(s) links are accepted')); return; }
            let r;
            if (w.id) r = await nui('updateWarrant', Object.assign({ id: num(w.id) }, payload), 8000, null);
            else r = await nui('createWarrant', payload, 8000, null);
            if (!ok(r)) { notify(msgOf(r, T('ui_save_failed', 'Could not save'))); return; }
            if (r.removed || payload.status === 'served' || payload.status === 'expired') {
                notify(T('ui_bounty_removed', 'Bounty marked %s — removed from the board.', payload.status));
                closeSheet();
            } else {
                w.id = r.id || w.id; openId = w.id;
                headEl.textContent = T('ui_saved_bounty', 'Saved · Bounty #%s', str(w.id));
                notify(T('ui_bounty_saved', 'Bounty saved'));
            }
            load();
        }));
        const form = h('div', { class: 'sheet-form' },
            section(T('ui_wanted_citizen', 'Wanted Citizen'), row(field(T('ui_citizen_id', 'Citizen ID'), cid), field(T('ui_citizen_name', 'Citizen Name') + ' *', cname)), look),
            section(T('ui_charges', 'Charges'), editable ? chargePicker((c) => { addCharge(charges, c); redraw(); }) : null, tagsEl),
            section(T('ui_bounty_details', 'Bounty Details'),
                row(field(T('ui_expiry_date', 'Expiry Date'), expiry), field(T('ui_col_status', 'Status'), status)),
                suggest,
                row(field(T('ui_bounty_reward', 'Bounty Reward ($)'), reward), field(T('ui_fine_dollar', 'Fine ($)'), fine), field(T('ui_jail_months', 'Jail (months)'), jail)),
                h('small', { class: 'muted' }, T('ui_reward_hint', 'Paid to the hunter on capture')),
                field(T('ui_image_url_short', 'Image URL'), imgUrl), pv,
                field(T('ui_notes', 'Notes'), notes)));
        if (!editable) form.querySelectorAll('input, select, textarea').forEach((el) => { el.disabled = true; });
        fill(sheetWrap, h('div', { class: 'side-sheet page-turn' },
            h('div', { class: 'sheet-head' }, h('b', null, T('ui_bounty', 'Bounty')), ' ', headEl,
                h('span', { class: 'spacer' }),
                editable ? saveBtn : null,
                w.id && can('deletewarrants') ? h('button', { class: 'btn danger sm', type: 'button', onclick: () => remove(w) }, icon('delete'), T('ui_delete', 'Delete')) : null,
                h('button', { class: 'x', type: 'button', onclick: closeSheet }, icon('close'))),
            form));
        root.classList.add('split');
        popLayer(sheetWrap); pushLayer(sheetWrap, closeSheet);
        draw();
    }
    regTab({
        id: 'bounties', icon: 'balance', perm: 'warrants', feature: 'feature_warrants', label: () => T('ui_nav_bounties', 'Bounties'),
        build: (r) => {
            root = r;
            q = inp({ placeholder: T('ui_search_name_charges', 'Search name or charges…') });
            stSel = sel([['all', T('ui_all', 'All')], ['active', T('ui_st_active', 'Active')], ['served', T('ui_st_served', 'Served')], ['expired', T('ui_st_expired', 'Expired')], ['revoked', T('ui_st_revoked', 'Revoked')]], 'all');
            q.addEventListener('input', debounce(() => { page = 1; draw(); }, 280));
            stSel.addEventListener('change', () => { page = 1; draw(); });
            listWrap = h('div', { class: 'split-list' });
            sheetWrap = h('div', { class: 'split-sheet' });
            add(r, [h('h2', { class: 'page-title' }, T('ui_nav_bounties', 'Bounties')),
                h('div', { class: 'toolbar' }, q, stSel, refreshBtn('bounties', load, 0),
                    can('issuewarrants') && !App.lawyer ? h('button', { class: 'btn primary sm', type: 'button', onclick: () => openSheet(null) }, icon('add'), T('ui_post_bounty', 'Post Bounty')) : null),
                h('div', { class: 'split-wrap' }, listWrap, sheetWrap)]);
        },
        show: async (o) => {
            await load();
            if (o && o.openId) {
                const w = rows.find((x) => num(x.id) === num(o.openId));
                if (w) openSheet(w); else notify(T('ui_not_found', 'Not found'));
            }
        },
        reset: () => { root = null; rows = []; page = 1; openId = null; },
    });
})();

// ---------- Most Wanted ----------
(function () {
    let root, board, formWrap, stSel, canManage = false, rows = [];
    const dangers = () => [['low', T('ui_danger_low', 'Low')], ['medium', T('ui_danger_medium', 'Medium')], ['high', T('ui_danger_high', 'High')], ['extreme', T('ui_danger_extreme', 'Extreme')]];
    const dangerRank = { extreme: 0, high: 1, medium: 2, low: 3 };
    async function load() {
        fill(board, loading());
        const r = await nui('getMostWanted', { status: stSel.value }, 8000, null);
        rows = arr(r && r.rows);
        canManage = !!(r && r.canManage) && !App.lawyer;
        postBtn.classList.toggle('hidden', !canManage);
        draw();
    }
    let postBtn;
    function sorted() {
        return rows.slice().sort((a, b) => ((a.status === 'active' ? 0 : 1) - (b.status === 'active' ? 0 : 1))
            || (num(dangerRank[a.danger], 4) - num(dangerRank[b.danger], 4)) || (num(b.reward) - num(a.reward)) || (num(toDate(b.added_at)) - num(toDate(a.added_at))));
    }
    function poster(x, big) {
        const captured = x.status === 'captured';
        return h('div', { class: 'poster danger-' + str(x.danger, 'high') + (captured ? ' captured' : '') + (big ? ' big' : ''), onclick: big ? null : () => detail(x) },
            h('div', { class: 'ribbon' }, (dangers().find((d) => d[0] === x.danger) || ['', str(x.danger)])[1]),
            h('div', { class: 'poster-h' }, T('ui_outlaw', 'OUTLAW')),
            h('div', { class: 'poster-s' }, T('ui_report_on_sight', 'Report on Sight')),
            x.photo_url && isHttpUrl(x.photo_url) ? img(x.photo_url, 'poster-img', (el) => el.replaceWith(icon('person', 'poster-img sil'))) : icon('person', 'poster-img sil'),
            h('div', { class: 'poster-name' }, str(x.name)),
            num(x.reward) > 0 ? h('div', { class: 'poster-reward' }, T('ui_reward_n', 'Reward %s', money(x.reward))) : null,
            x.crimes ? h('div', { class: 'poster-crimes' }, cut(x.crimes, big ? 400 : 60)) : null,
            h('small', null, T('ui_posted_by', 'posted by %s', str(x.added_by_name, '—'))),
            captured ? h('div', { class: 'stamp-captured' }, T('ui_captured', 'Captured')) : null,
            canManage && !big ? h('div', { class: 'poster-act' },
                !captured ? h('button', { class: 'btn sm', type: 'button', onclick: (e) => { e.stopPropagation(); resolve(x, 'capture'); } }, T('ui_mark_captured', 'Mark captured')) : null,
                h('button', { class: 'btn danger sm', type: 'button', onclick: (e) => { e.stopPropagation(); resolve(x, 'remove'); } }, T('ui_remove', 'Remove'))) : null);
    }
    function draw() {
        if (!root) return;
        const list = sorted();
        fill(board, list.length ? h('div', { class: 'poster-grid' }, list.map((x) => poster(x))) : emptyState(T('ui_no_outlaws', 'No outlaws posted'), null, 'person_off'));
    }
    async function resolve(x, action, after) {
        const msg = action === 'capture' ? T('ui_capture_q', 'Mark %s captured? The poster stays on record.', str(x.name)) : T('ui_remove_poster_q', 'Take %s off the board for good?', str(x.name));
        if (!(await confirmBox({ message: msg, confirm: action === 'capture' ? T('ui_mark_captured', 'Mark captured') : T('ui_remove', 'Remove'), danger: action !== 'capture' }))) return;
        const r = await nui('resolveMostWanted', { id: num(x.id), action }, 8000, null);
        notify(ok(r) ? (action === 'capture' ? T('ui_poster_captured', 'Marked captured') : T('ui_poster_removed', 'Poster removed')) : msgOf(r, T('ui_action_failed', 'That did not work')));
        if (ok(r)) { if (after) after(); load(); }
    }
    function detail(x) {
        const m = modal({
            title: str(x.name), icon: 'person_search', cls: 'poster-modal', backdropCloses: true,
            body: [poster(x, true),
                x.notes ? h('p', null, str(x.notes)) : null,
                x.status === 'captured' ? h('p', null, T('ui_captured_by', 'Captured — by %s', str(x.captured_by_name, '—'))) : null,
                h('small', { class: 'muted' }, T('ui_posted_by_on', 'Posted by %s · %s', str(x.added_by_name, '—'), fmtDate(x.added_at)))],
            footer: [
                canManage && x.status !== 'captured' ? h('button', { class: 'btn', type: 'button', onclick: () => resolve(x, 'capture', () => m.close(true)) }, T('ui_mark_captured', 'Mark captured')) : null,
                canManage ? h('button', { class: 'btn danger', type: 'button', onclick: () => resolve(x, 'remove', () => m.close(true)) }, T('ui_remove', 'Remove')) : null,
                h('button', { class: 'btn ghost', type: 'button', onclick: () => m.close() }, T('ui_close', 'Close')),
            ],
        });
    }
    function openForm() {
        const cid = inp({ placeholder: T('ui_optional', 'optional') });
        const name = inp({ maxlength: 100 });
        const danger = sel(dangers(), 'high');
        const reward = numInp({ value: 0 });
        const crimes = inp({ maxlength: 500 });
        const photo = inp({ maxlength: 500, placeholder: 'https://…' });
        const notes = area({ maxlength: 1000 });
        const look = lookLine();
        const lookup = watchLookup(cid, 450, (v) => nui('lookupMostWantedCitizen', { citizenIdentity: v }, 8000, null), (r, v) => {
            if (r === undefined) setLook(look, T('ui_looking_up', 'Looking up…'));
            else if (r && r.found) {
                if (!name.value.trim()) name.value = str(r.name);
                if (!photo.value.trim() && r.photoUrl) photo.value = str(r.photoUrl);
                setLook(look, T('ui_mw_filled', '%s — name & mugshot filled', str(r.name)), 'green');
            } else if (v) setLook(look, T('ui_mw_no_citizen', 'No citizen with that ID'), 'red'); else setLook(look, '');
        });
        void lookup;
        const postB = h('button', { class: 'btn primary', type: 'button' }, T('ui_post_outlaw', 'Post Outlaw'));
        const close = () => { clear(formWrap); popLayer(formWrap); };
        postB.addEventListener('click', () => busy(postB, null, async () => {
            if (!name.value.trim()) { notify(T('ui_outlaw_name_required', 'Outlaw name is required')); return; }
            if (photo.value.trim() && !isHttpUrl(photo.value)) { notify(T('ui_url_http', 'Only http(s) links are accepted')); return; }
            const r = await nui('addMostWanted', { citizenIdentity: cid.value.trim(), name: name.value.trim(), danger: danger.value, reward: Math.max(0, Math.floor(num(reward.value))), crimes: crimes.value.trim(), photoUrl: photo.value.trim(), notes: notes.value.trim() }, 8000, null);
            notify(ok(r) ? T('ui_poster_added', 'Poster added') : msgOf(r, T('ui_save_failed', 'Could not save')));
            if (ok(r)) { close(); load(); }
        }));
        fill(formWrap, h('div', { class: 'inline-form page-turn' },
            row(field(T('ui_citizen_id', 'Citizen ID'), cid), field(T('ui_outlaw_name', 'Outlaw name') + ' *', name), field(T('ui_danger', 'Danger'), danger)), look,
            row(field(T('ui_reward_dollar', 'Reward ($)'), reward), field(T('ui_crimes', 'Crimes'), crimes)),
            field(T('ui_poster_image', 'Poster image URL'), photo), field(T('ui_notes', 'Notes'), notes),
            h('div', { class: 'frow end' }, h('button', { class: 'btn ghost', type: 'button', onclick: close }, T('ui_cancel', 'Cancel')), postB)));
        popLayer(formWrap); pushLayer(formWrap, close);
    }
    regTab({
        id: 'mostwanted', icon: 'local_police', perm: 'mostwanted', label: () => T('ui_nav_mostwanted', 'Most Wanted'),
        build: (r) => {
            root = r;
            stSel = sel([['', T('ui_st_active', 'Active')], ['captured', T('ui_captured', 'Captured')], ['all', T('ui_all', 'All')]], '');
            stSel.addEventListener('change', load);
            postBtn = h('button', { class: 'btn primary sm hidden', type: 'button', onclick: openForm }, icon('add'), T('ui_post_outlaw', 'Post Outlaw'));
            formWrap = h('div');
            board = h('div');
            add(r, [h('div', { class: 'toolbar' }, h('h2', { class: 'page-title' }, T('ui_nav_mostwanted', 'Most Wanted')), stSel, postBtn, refreshBtn('mostwanted', load, 0)), formWrap, board]);
        },
        show: () => load(),
        reset: () => { root = null; rows = []; },
    });
})();

// ---------- Witness Statements ----------
(function () {
    let root, listEl, q, page = 1, rows = [], seq = 0;
    async function load(p) {
        page = p || page;
        const my = ++seq;
        fill(listEl, loading());
        const r = await nui('getBolos', { page, search: q.value.trim() }, 8000, null);
        if (my !== seq || !root) return;
        rows = arr(r && r.bolos);
        fill(listEl,
            table([
                { label: T('ui_col_subject', 'Subject'), render: (b) => str(b.subject_name, T('ui_unknown', 'Unknown')) },
                { label: T('ui_col_po', 'PO #'), render: (b) => str(b.po_number, '—') },
                { label: T('ui_location', 'Location'), cls: 'trunc', render: (b) => cut(b.location, 30) || '—', title: (b) => str(b.location) },
                { label: T('ui_col_lawman', 'Lawman'), render: (b) => str(b.lawman_name || b.issued_by_name || b.issued_by, '—') },
                { label: T('ui_col_filed', 'Filed'), render: (b) => fmtDate(b.created_at) },
                { label: '', cls: 'act', render: (b) => [
                    !App.lawyer ? iconBtn('check', T('ui_resolve', 'Resolve'), () => act('resolveBolo', b)) : null,
                    can('deletebolos') ? iconBtn('delete', T('ui_delete', 'Delete'), () => act('deleteBolo', b)) : null] },
            ], rows, { onRow: (b) => viewer(b), empty: emptyState(T('ui_no_statements', 'No active Witness Statements'), null, 'sticky_note_2') }),
            pager(page, r && r.totalPages, r && r.totalRecords, load));
    }
    async function act(name, b, after) {
        const del = name === 'deleteBolo';
        if (!(await confirmBox({ message: del ? T('ui_delete_statement_q', 'Delete the statement about %s?', str(b.subject_name)) : T('ui_resolve_statement_q', 'Mark the statement about %s resolved?', str(b.subject_name)), confirm: del ? T('ui_delete', 'Delete') : T('ui_resolve', 'Resolve'), danger: del }))) return;
        const r = await nui(name, { id: num(b.id) }, 8000, null);
        notify(ok(r) ? (del ? T('ui_statement_deleted', 'Statement deleted') : T('ui_statement_resolved', 'Statement resolved')) : msgOf(r, T('ui_action_failed', 'That did not work')));
        if (ok(r)) { if (after) after(); load(); }
    }
    function viewer(b) {
        const resolved = str(b.status) === 'resolved';
        const rowIf = (l, v) => v ? h('div', { class: 'doc-row' }, h('span', { class: 'lbl' }, l), ' ', str(v)) : null;
        const m = modal({
            title: T('ui_witness_statement', 'Witness Statement'), icon: 'sticky_note_2', cls: 'doc', backdropCloses: true,
            body: [h('h3', null, str(b.subject_name), h('small', { class: 'muted' }, ' — ' + fmtDateTime(b.created_at))),
                resolved ? h('div', { class: 'stamp-red' }, T('ui_resolved', 'Resolved')) : null,
                rowIf(T('ui_po_number', 'PO Number'), b.po_number), rowIf(T('ui_location', 'Location'), b.location),
                rowIf(T('ui_col_lawman', 'Lawman'), b.lawman_name), rowIf(T('ui_region', 'Region'), b.region),
                rowIf(T('ui_filed_by', 'Filed By'), b.issued_by_name || b.issued_by), rowIf(T('ui_col_status', 'Status'), b.status),
                h('div', { class: 'fsec-title' }, T('ui_statement', 'Statement')), h('p', { class: 'pre' }, str(b.description))],
            footer: [
                !resolved && !App.lawyer ? h('button', { class: 'btn', type: 'button', onclick: () => act('resolveBolo', b, () => m.close(true)) }, T('ui_resolve', 'Resolve')) : null,
                can('deletebolos') ? h('button', { class: 'btn danger', type: 'button', onclick: () => act('deleteBolo', b, () => m.close(true)) }, T('ui_delete', 'Delete')) : null],
        });
    }
    function newStatement() {
        const p = App.player || {};
        const cid = inp({ placeholder: T('ui_optional', 'optional') });
        const look = lookLine();
        const name = inp({ maxlength: 100 });
        const po = inp({ maxlength: 50 });
        const loc = inp({ maxlength: 200 });
        const desc = area({ rows: 5, maxlength: 4000 });
        const lid = inp({ value: str(p.citizenid || p.charId) });
        const lname = inp({ value: str(p.name) });
        const region = inp({ value: str(p.region || p.dutyRegion) });
        watchLookup(cid, 400, (v) => nui('lookupBoloCitizen', { citizenIdentity: v }, 8000, null), (r, v) => {
            if (r === undefined) setLook(look, T('ui_looking_citizen', 'Looking up citizen…'));
            else if (r && r.found) { setLook(look, T('ui_name_found', '%s — found.', str(r.name)), 'green'); name.value = str(r.name); }
            else if (v) setLook(look, T('ui_no_citizen_found', 'No citizen found'), 'red'); else setLook(look, '');
        });
        watchLookup(lid, 400, (v) => nui('lookupBoloCitizen', { citizenIdentity: v }, 8000, null), (r) => {
            if (r && r.found) { lname.value = str(r.name); if (r.region) region.value = str(r.region); }
        });
        const fileBtn = h('button', { class: 'btn primary', type: 'button' }, T('ui_file_statement', 'File Statement'));
        const m = modal({
            title: T('ui_new_statement', 'New Statement'), icon: 'sticky_note_2',
            body: [field(T('ui_citizen_id', 'Citizen ID'), cid), look, field(T('ui_civilian_name', 'Civilian Name') + ' *', name),
                row(field(T('ui_po_number', 'PO Number'), po), field(T('ui_location', 'Location'), loc)),
                field(T('ui_col_description', 'Description') + ' *', desc),
                row(field(T('ui_lawman_id', 'Lawman ID'), lid), field(T('ui_lawman_name', 'Lawman Name'), lname), field(T('ui_region', 'Region'), region))],
            footer: [h('button', { class: 'btn ghost', type: 'button', onclick: () => m.close() }, T('ui_cancel', 'Cancel')), fileBtn],
        });
        setTimeout(() => cid.focus(), 30);
        fileBtn.addEventListener('click', () => busy(fileBtn, null, async () => {
            if (!name.value.trim() || !desc.value.trim()) { notify(T('ui_statement_required', 'Civilian name and description are required')); return; }
            const r = await nui('createBolo', { subject_name: name.value.trim(), po_number: po.value.trim(), location: loc.value.trim(), description: desc.value.trim(), lawman_name: lname.value.trim(), region: region.value.trim() }, 8000, null);
            notify(ok(r) ? T('ui_statement_filed', 'Statement filed') : msgOf(r, T('ui_save_failed', 'Could not save')));
            if (ok(r)) { m.close(true); load(1); }
        }));
    }
    regTab({
        id: 'statements', icon: 'sticky_note_2', perm: 'bolos', feature: 'feature_bolos', label: () => T('ui_nav_statements', 'Witness Statements'),
        build: (r) => {
            root = r;
            q = inp({ placeholder: T('ui_search', 'Search…') });
            q.addEventListener('input', debounce(() => load(1), 250));
            listEl = h('div');
            add(r, [h('h2', { class: 'page-title' }, T('ui_nav_statements', 'Witness Statements')),
                h('div', { class: 'toolbar' }, q, refreshBtn('statements', () => load(), 0),
                    !App.lawyer ? h('button', { class: 'btn primary sm', type: 'button', onclick: newStatement }, icon('add'), T('ui_new_statement', 'New Statement')) : null),
                listEl]);
        },
        show: async (o) => {
            await load(page);
            if (o && o.openId) { const b = rows.find((x) => num(x.id) === num(o.openId)); if (b) viewer(b); }
        },
        reset: () => { root = null; page = 1; rows = []; },
    });
})();
