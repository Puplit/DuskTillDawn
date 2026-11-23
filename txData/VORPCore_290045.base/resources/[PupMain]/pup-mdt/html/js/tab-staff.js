'use strict';
// Lawmen Roster, Prison Records and Tips.

const Regions = () => [['', T('ui_no_region', '— none —')], ['Ambarino', 'Ambarino'], ['New Hanover', 'New Hanover'], ['Lemoyne', 'Lemoyne'], ['West Elizabeth', 'West Elizabeth'], ['New Austin', 'New Austin'], ['Guarma', 'Guarma']];

// ---------- Lawmen Roster ----------
(function () {
    let root, q, dutySel, countEl, pillsEl, tableEl, unitsEl, region = '', sortKey = 'grade', sortAsc = false, lawmen = [], seq = 0;
    function isLoa(l) { const d = toDate(l.loaUntil); if (!d) return false; const t = new Date(); t.setHours(0, 0, 0, 0); return d >= t; }
    function myId() { const p = App.player || {}; return str(p.citizenid); }
    async function load() {
        if (!can('viewlawmen')) { draw(); return; }
        const my = ++seq;
        fill(tableEl, loading());
        const r = await nui('getLawmen', {}, 8000, []);
        if (my !== seq || !root) return;
        lawmen = arr(r);
        draw();
    }
    function filtered() {
        const t = q.value.trim().toLowerCase(), d = dutySel.value;
        let list = lawmen.filter((l) => (!t || [l.name, l.rank, l.region].some((v) => str(v).toLowerCase().includes(t)))
            && (d === 'all' || (d === 'on' ? !!l.onDuty : !l.onDuty))
            && (!region || str(l.region) === region));
        const key = { status: (l) => (l.onDuty ? 1 : 0), region: (l) => str(l.region), name: (l) => str(l.name).toLowerCase(), rank: (l) => num(l.gradeNum), grade: (l) => num(l.gradeNum) }[sortKey];
        list = list.slice().sort((a, b) => { const x = key(a), y = key(b); const c = x < y ? -1 : x > y ? 1 : 0; return sortAsc ? c : -c; });
        return list;
    }
    function draw() {
        if (!root) return;
        if (!can('viewlawmen')) { fill(tableEl, emptyState(T('ui_restricted', 'Restricted'), T('ui_restricted_roster', 'You may only see your own profile.'), 'lock')); fill(unitsEl); countEl.textContent = ''; return; }
        const list = filtered();
        countEl.textContent = list.length === 1 ? T('ui_one_lawman', '1 lawman') : T('ui_n_lawmen', '%d lawmen', list.length);
        const sortCol = (k, label) => ({ label, onSort: () => { if (sortKey === k) sortAsc = !sortAsc; else { sortKey = k; sortAsc = k === 'name' || k === 'region'; } draw(); }, sortMark: sortKey === k ? (sortAsc ? ' ▲' : ' ▼') : null, cls: 'sortable' });
        fill(tableEl, table([
            Object.assign(sortCol('status', T('ui_col_status', 'Status')), { render: (l) => [statusDot(l.onDuty), ' ', l.onDuty ? T('ui_on_duty', 'On Duty') : T('ui_off_duty', 'Off Duty')] }),
            Object.assign(sortCol('region', T('ui_region', 'Region')), { render: (l) => str(l.region, '--') }),
            Object.assign(sortCol('name', T('ui_col_name', 'Name')), { render: (l) => [str(l.name), isLoa(l) ? h('span', { class: 'badge tone-red sm' }, 'LOA') : null] }),
            Object.assign(sortCol('rank', T('ui_rank', 'Rank')), { render: (l) => str(l.rank) }),
        ], list, { onRow: (l) => openFile(l, false), empty: emptyState(T('ui_no_lawmen', 'No lawmen match'), null, 'badge') }));
        const on = list.filter((l) => l.onDuty);
        fill(unitsEl, h('div', { class: 'panel-head' }, h('span', { class: 'panel-t' }, T('ui_active_units', 'Active Units'))),
            on.length ? on.map((l) => { const parts = str(l.name).split(' '); return h('div', { class: 'unit' }, statusDot(true), ' ', parts[0] + (parts[1] ? ' ' + parts[1][0] + '.' : '')); }) : h('div', { class: 'muted' }, T('ui_no_units', 'No units active')));
    }
    function drawPills() {
        clear(pillsEl);
        const all = [['', T('ui_all_regions', 'All Regions')]].concat(Regions().slice(1));
        for (const [v, l] of all) pillsEl.appendChild(h('button', { class: 'pill' + (region === v ? ' on' : ''), type: 'button', onclick: () => { region = v; drawPills(); draw(); } }, l));
    }
    function canEdit(l) { return (l && str(l.citizenid) === myId()) || !!(App.player && App.player.canEditProfiles); }
    function isManager() { return !!(App.player && App.player.canEditProfiles); }
    function openFile(l, editMode) {
        const self = str(l.citizenid) === myId();
        const editing = editMode && canEdit(l);
        const st = l.stats || {};
        const initials = str(l.name).split(' ').map((x) => x[0] || '').join('').slice(0, 2).toUpperCase();
        const photo = l.photo && isHttpUrl(l.photo) ? img(l.photo, 'mug', (el) => el.replaceWith(h('div', { class: 'mug initials' }, initials))) : h('div', { class: 'mug initials' }, initials);
        const regionSel = sel(Regions(), str(l.region));
        const loa = inp({ type: 'date', value: isoDay(l.loaUntil) });
        const photoUrl = inp({ value: str(l.photo), placeholder: 'https://…' });
        const pv = img(str(l.photo), 'mug-preview');
        photoUrl.addEventListener('input', () => { const u = photoUrl.value.trim(); pv.classList.toggle('hidden', !isHttpUrl(u)); if (isHttpUrl(u)) pv.src = u; });
        const notes = area({ rows: 4, value: str(l.description), maxlength: 1000 });
        const trainingsHeld = arr(typeof l.trainings === 'string' ? parseJson(l.trainings, []) : l.trainings).map(String);
        const allTrain = Array.from(new Set(arr(App.cfg.trainings).map(String).concat(trainingsHeld)));
        const boxes = allTrain.map((t) => ({ t, box: h('input', { type: 'checkbox', checked: trainingsHeld.includes(t) }) }));
        const manager = isManager();
        const info = (label, value) => h('div', { class: 'info-row' }, h('span', { class: 'lbl' }, label), h('span', null, value));
        // the server sends the duty time ready to show ("3h 20m")
        const dutyTime = str(st.dutyTime, '0h 0m');
        const left = h('div', { class: 'col' },
            section(T('ui_record_info', 'Record Info'),
                info(T('ui_col_status', 'Status'), l.onDuty ? T('ui_on_duty', 'On Duty') : T('ui_off_duty', 'Off Duty')),
                info(T('ui_clocked_in', 'Clocked In'), l.onDuty ? str(l.dutyRegion && l.dutyRegion !== 'N/A' ? l.dutyRegion : '', T('ui_no_region_picked', 'No region picked')) : '—'),
                info(T('ui_duty_time', 'Duty Time'), dutyTime),
                info(T('ui_last_on_duty', 'Last On Duty'), l.onDuty ? T('ui_on_duty_now', 'On duty now') : fmtDate(l.lastDutyUpdate)),
                editing ? field(T('ui_region', 'Region'), regionSel) : info(T('ui_region', 'Region'), str(l.region, '--')),
                editing && manager ? field(T('ui_loa_until', 'LOA Until'), loa) : info(T('ui_loa_until', 'LOA Until'), l.loaUntil ? fmtDate(l.loaUntil) : '—')),
            section(T('ui_notes_bio', 'Notes / Biography'), editing ? notes : h('p', { class: 'pre' }, str(l.description) || T('ui_no_notes', 'No notes'))),
            editing ? field(T('ui_photo_url', 'Photo URL'), h('div', null, photoUrl, pv)) : null);
        const tile = (n, lbl) => h('div', { class: 'tile' }, h('span', { class: 'hand big' }, String(num(n))), h('small', null, lbl));
        const right = h('div', { class: 'col' },
            h('div', { class: 'tiles four' }, tile(st.arrests, T('ui_arrests', 'Arrests')), tile(st.fines, T('ui_fines', 'Fines')), tile(st.criminals, T('ui_criminals', 'Criminals')), tile(st.evidences, T('ui_evidence', 'Evidence'))),
            section(T('ui_certifications', 'Certifications'), editing && manager
                ? h('div', { class: 'checks' }, boxes.map((b) => h('label', { class: 'check' }, b.box, ' ', b.t)))
                : h('div', { class: 'tags' }, trainingsHeld.length ? trainingsHeld.map((t) => h('span', { class: 'tag' }, t)) : h('span', { class: 'muted' }, T('ui_none', 'None')))),
            info(T('ui_created', 'Created'), fmtDate(l.createdAt)),
            info(T('ui_last_active', 'Last Active'), fmtDate(l.updatedAt || l.lastDutyUpdate)));
        const saveB = h('button', { class: 'btn primary', type: 'button' }, T('ui_save_changes', 'Save Changes'));
        const m = modal({
            title: T('ui_lawman_profile_no', 'LAWMAN PROFILE No. %s', str(l.id)), icon: 'badge', cls: 'xwide personnel',
            body: [h('div', { class: 'prof-head' }, photo,
                h('div', null, h('h3', null, str(l.name)), h('div', null, str(l.rank), ' ', badge(str(l.department || l.region, '—'), 'leather')), h('div', null, statusDot(l.onDuty), ' ', l.onDuty ? T('ui_on_duty', 'On Duty') : T('ui_off_duty', 'Off Duty')))),
            h('div', { class: 'cols2' }, left, right)],
            footer: [
                !editing && canEdit(l) ? h('button', { class: 'btn', type: 'button', onclick: () => { m.close(true); openFile(l, true); } }, icon('edit'), T('ui_edit', 'Edit')) : null,
                manager && !self ? h('button', { class: 'btn danger', type: 'button', onclick: async () => {
                    if (!(await confirmBox({ message: T('ui_terminate_q', 'Terminate %s? This removes them from the active roster.', str(l.name)), confirm: T('ui_terminate', 'Terminate'), danger: true }))) return;
                    const r = await nui('terminateLawman', { id: l.id }, 8000, null);
                    notify(ok(r) ? T('ui_terminated', '%s has been terminated', str(l.name)) : msgOf(r, T('ui_action_failed', 'That did not work')));
                    if (ok(r)) { m.close(true); load(); }
                } }, T('ui_terminate', 'Terminate')) : null,
                editing ? saveB : null,
                h('button', { class: 'btn ghost', type: 'button', onclick: () => m.close() }, T('ui_close', 'Close'))],
        });
        saveB.addEventListener('click', () => busy(saveB, T('ui_saving', 'Saving…'), async () => {
            if (photoUrl.value.trim() && !isHttpUrl(photoUrl.value)) { notify(T('ui_url_http', 'Only http(s) links are accepted')); return; }
            const payload = { targetCitizenId: str(l.citizenid), isUpdate: true, callsign: str(l.callsign), department: str(l.department), rank: str(l.rank), region: regionSel.value, description: notes.value.trim(), photo: photoUrl.value.trim() };
            if (manager) { payload.trainings = boxes.filter((b) => b.box.checked).map((b) => b.t); payload.loaUntil = loa.value || null; }
            const r = await nuiPush('saveLawmanProfile', payload, 8000, null);
            const res = r && r.result;
            notify(msgOf(res, ok(res) ? T('ui_profile_updated', 'Profile updated') : T('ui_save_failed', 'Could not save')));
            if (ok(res)) { m.close(true); load(); }
        }));
    }
    async function editMine() {
        const r = await nuiPush('getMyProfile', {}, 8000, null);
        const prof = r && r.profile;
        if (prof && prof.exists) {
            const fromList = lawmen.find((l) => str(l.citizenid) === myId());
            openFile(Object.assign({}, fromList || {}, prof, { citizenid: str(prof.citizenid || myId()), photo: prof.photo || prof.photo_url, description: prof.description, loaUntil: prof.loaUntil || prof.loa_until }), true);
            return;
        }
        const p = App.player || {};
        const photo = inp({ placeholder: 'https://…' });
        const pv = img('', 'mug-preview');
        const regionSel = sel(Regions(), '');
        const loa = inp({ type: 'date' });
        const notes = area({ rows: 4, maxlength: 1000 });
        const saveB = h('button', { class: 'btn primary', type: 'button' }, T('ui_save_profile', 'Save Profile'));
        const m = modal({
            title: T('ui_my_profile', 'My Lawman Profile'), icon: 'badge',
            body: [field(T('ui_photo_url', 'Photo URL'), h('div', { class: 'frow tight' }, photo, h('button', { class: 'btn sm', type: 'button', onclick: () => { const u = photo.value.trim(); pv.classList.toggle('hidden', !isHttpUrl(u)); if (isHttpUrl(u)) pv.src = u; } }, T('ui_preview', 'Preview')))), pv,
                row(field(T('ui_first_name', 'First name'), inp({ value: str(p.firstname), readOnly: true })), field(T('ui_last_name', 'Last name'), inp({ value: str(p.lastname), readOnly: true })), field(T('ui_rank', 'Rank'), inp({ value: rankText() + (p.isBoss ? ' ' + T('ui_chief_mark', '(Chief)') : ''), readOnly: true }))),
                field(T('ui_region', 'Region'), regionSel),
                isManager() ? field(T('ui_loa_until', 'LOA Until'), loa) : null,
                field(T('ui_notes', 'Notes'), notes)],
            footer: [h('button', { class: 'btn ghost', type: 'button', onclick: () => m.close() }, T('ui_cancel', 'Cancel')), saveB],
        });
        saveB.addEventListener('click', () => busy(saveB, T('ui_saving', 'Saving…'), async () => {
            if (photo.value.trim() && !isHttpUrl(photo.value)) { notify(T('ui_url_http', 'Only http(s) links are accepted')); return; }
            const payload = { targetCitizenId: myId(), isUpdate: false, region: regionSel.value, description: notes.value.trim(), photo: photo.value.trim(), rank: rankText(), callsign: '', department: '' };
            if (isManager()) payload.loaUntil = loa.value || null;
            const r2 = await nuiPush('saveLawmanProfile', payload, 8000, null);
            const res = r2 && r2.result;
            notify(msgOf(res, ok(res) ? T('ui_profile_created', 'Profile created') : T('ui_save_failed', 'Could not save')));
            if (ok(res)) { m.close(true); load(); }
        }));
    }
    regTab({
        id: 'roster', icon: 'badge', perm: 'lawmen', label: () => T('ui_nav_roster', 'Lawmen Roster'),
        build: (r) => {
            root = r;
            q = inp({ placeholder: T('ui_search_roster', 'Search name, rank or region…') });
            dutySel = sel([['all', T('ui_all', 'All')], ['on', T('ui_on_duty', 'On Duty')], ['off', T('ui_off_duty', 'Off Duty')]], 'on');
            countEl = h('span', { class: 'muted' });
            pillsEl = h('div', { class: 'pills' });
            tableEl = h('div', { class: 'roster-main' });
            unitsEl = h('div', { class: 'panel units' });
            q.addEventListener('input', draw);
            dutySel.addEventListener('change', draw);
            add(r, [h('h2', { class: 'page-title' }, T('ui_nav_roster', 'Lawmen Roster')),
                h('div', { class: 'toolbar' }, q, dutySel, countEl,
                    !App.lawyer ? h('button', { class: 'btn sm', type: 'button', onclick: editMine }, icon('edit'), T('ui_edit_profile', 'Edit Profile')) : null,
                    refreshBtn('roster', load)),
                pillsEl, h('div', { class: 'roster-wrap' }, tableEl, unitsEl)]);
            drawPills();
        },
        show: () => load(),
        reset: () => { root = null; lawmen = []; region = ''; sortKey = 'grade'; sortAsc = false; },
        push: () => { if (root && App.current === 'roster') load(); },
    });
})();

// ---------- Prison Records ----------
(function () {
    let root, q, countEl, listEl, rows = [];
    // seconds left: secondsLeft when sent, otherwise time_remaining is minutes left
    function left(p) {
        if (typeof p.remainingTime === 'number') return p.remainingTime;
        if (p.secondsLeft !== undefined) return num(p.secondsLeft);
        if (p.seconds_left !== undefined) return num(p.seconds_left);
        return num(p.time_remaining !== undefined ? p.time_remaining : p.timeRemaining) * 60;
    }
    // sentence length in minutes
    function sentence(p) { return num(p.sentence_time !== undefined ? p.sentence_time : (p.sentenceMinutes !== undefined ? p.sentenceMinutes : p.totalTime)); }
    function leftMin(p) { return Math.ceil(left(p) / 60); }
    async function load() {
        fill(listEl, loading());
        const r = await nui('getPrisons', {}, 8000, []);
        rows = arr(r);
        draw();
    }
    function draw() {
        if (!root) return;
        const t = q.value.trim().toLowerCase();
        const list = rows.filter((p) => !t || [p.prisoner_name, p.citizen_id, p.charges].some((v) => str(v).toLowerCase().includes(t)));
        countEl.textContent = T('ui_n_prisoners', '%d prisoners', list.length);
        fill(listEl, table([
            { label: T('ui_col_prisoner', 'Prisoner'), render: (p) => str(p.prisoner_name) },
            { label: T('ui_col_id', 'ID'), render: (p) => str(p.citizen_id) },
            { label: T('ui_col_status', 'Status'), render: (p) => left(p) < 60 ? badge(T('ui_expired', 'Expired'), 'grey') : badge(T('ui_serving_s', 'Serving'), 'red') },
            { label: T('ui_col_time_left', 'Time Left'), render: (p) => h('span', { class: left(p) < 60 ? 'tone-red' : '' }, T('ui_n_m', '%d m', leftMin(p))) },
            { label: T('ui_col_fine', 'Fine'), render: (p) => money(p.fine_amount) },
            { label: T('ui_col_arrested_by', 'Arrested By'), render: (p) => str(p.lawman || p.imprisonedBy, '—') },
            { label: '', cls: 'act', render: (p) => [iconBtn('visibility', T('ui_details', 'Details'), () => details(p)), can('arrest') ? iconBtn('lock_open', T('ui_release', 'Release'), () => release(p)) : null] },
        ], list, { onRow: (p) => details(p), empty: emptyState(T('ui_no_prisoners', 'No active prisoners'), null, 'lock') }));
    }
    async function release(p, after) {
        if (!(await confirmBox({ message: T('ui_release_q', 'Release %s? This sets the remaining time to 0 and releases them immediately.', str(p.prisoner_name)), confirm: T('ui_release', 'Release'), danger: true }))) return;
        const r = await nuiPush('releasePrisoner', { id: num(p.id), setRemainingTime: 0 }, 8000, null);
        const res = r && r.result;
        notify(msgOf(res, ok(res) ? T('ui_prisoner_released', 'Prisoner released') : T('ui_action_failed', 'That did not work')));
        if (ok(res)) { if (after) after(); load(); }
    }
    async function toCell(p) {
        const cells = arr(await nui('getPrisonCells', {}, 3000, []));
        const m = modal({
            title: T('ui_send_to_cell', 'Send to Cell'), icon: 'meeting_room', backdropCloses: true,
            body: [h('p', null, T('ui_choose_cell', 'Choose a cell for %s:', str(p.prisoner_name))),
                cells.length ? h('div', { class: 'btn-col' }, cells.map((c) => h('button', { class: 'btn', type: 'button', onclick: async () => {
                    const r = await nuiPush('sendPrisonerToCell', { id: num(p.id), cell: num(c.index) }, 8000, null);
                    const res = r && r.result;
                    notify(msgOf(res, ok(res) ? T('ui_moved_to_cell', 'Moved to %s', str(c.label)) : T('ui_action_failed', 'That did not work')));
                    m.close(true);
                } }, str(c.label)))) : h('div', { class: 'muted' }, T('ui_no_cells', 'No cells configured'))],
        });
    }
    function details(p) {
        const sMin = sentence(p);
        const lSec = left(p);
        const served = sMin > 0 ? Math.min(100, Math.max(0, Math.round(((sMin * 60 - lSec) / (sMin * 60)) * 100))) : 0;
        const arrested = toDate(p.arrest_date || p.imprisonedAt);
        const releaseAt = arrested && sMin ? new Date(arrested.getTime() + sMin * 60000) : null;
        const cell = (l, v) => h('div', { class: 'tile' }, h('small', null, l), h('b', null, v));
        const m = modal({
            title: str(p.prisoner_name), icon: 'lock', cls: 'wide', backdropCloses: true,
            headExtra: h('span', { class: 'muted' }, ' ' + T('ui_id_n', 'ID: %s', str(p.citizen_id))),
            body: [p.is_bounty_claim ? h('div', { class: 'ribbon-bar' }, T('ui_claimed_by_hunter', 'CLAIMED BY BOUNTY HUNTER')) : null,
                lSec < 60 ? badge(T('ui_expired', 'Expired'), 'grey') : badge(T('ui_serving_s', 'Serving'), 'red'),
                h('div', { class: 'tiles three' },
                    cell(T('ui_sentence', 'Sentence'), T('ui_n_m', '%d m', sMin)), cell(T('ui_remaining', 'Remaining'), mmss(lSec)), cell(T('ui_col_fine', 'Fine'), money(p.fine_amount)),
                    cell(T('ui_col_arrested_by', 'Arrested By'), str(p.lawman || p.imprisonedBy, '—')), cell(T('ui_arrest_date', 'Arrest Date'), fmtDateTime(arrested)), cell(T('ui_release_date', 'Release Date'), releaseAt ? fmtDateTime(releaseAt) : '—')),
                h('div', { class: 'progress' }, h('div', { class: 'progress-fill', style: { width: served + '%' } }), h('span', null, served + '%')),
                section(T('ui_charges_narrative', 'Charges / Narrative'), h('p', { class: 'pre' }, str(p.charges || p.notes, '—')))],
            footer: [
                can('arrest') ? h('button', { class: 'btn', type: 'button', onclick: () => toCell(p) }, icon('meeting_room'), T('ui_send_to_cell', 'Send to Cell')) : null,
                can('arrest') ? h('button', { class: 'btn danger', type: 'button', onclick: () => release(p, () => m.close(true)) }, icon('lock_open'), T('ui_release', 'Release')) : null,
                h('button', { class: 'btn ghost', type: 'button', onclick: () => m.close() }, T('ui_close', 'Close'))],
        });
    }
    regTab({
        id: 'prisons', icon: 'lock', perm: 'prisons', feature: 'feature_prisons', label: () => T('ui_nav_prisons', 'Prison Records'),
        build: (r) => {
            root = r;
            q = inp({ placeholder: T('ui_search_prison', 'Search name, id or charges…') });
            q.addEventListener('input', draw);
            countEl = h('span', { class: 'muted' });
            listEl = h('div');
            add(r, [h('h2', { class: 'page-title' }, icon('lock'), ' ', T('ui_prison_management', 'Prison Management')),
                h('div', { class: 'toolbar' }, q, countEl, refreshBtn('prisons', load)), listEl]);
        },
        show: () => load(),
        reset: () => { root = null; rows = []; },
        push: () => { if (root && App.current === 'prisons') load(); },
    });
})();

// ---------- Tips ----------
(function () {
    let root, q, stSel, listEl, tips = [];
    function from(t) { return t.anonymous && t.anonymous !== 0 ? T('ui_anonymous', 'Anonymous') : str(t.citizen_name, T('ui_unknown', 'Unknown')); }
    function countUnread() { App.setUnreadTips(tips.filter((t) => str(t.status, 'new') === 'new').length); }
    async function load() {
        if (listEl) fill(listEl, loading());
        const r = await nui('getTips', {}, 8000, null);
        tips = arr(r && r.tips);
        countUnread();
        draw();
    }
    function sorted() { return tips.slice().sort((a, b) => ((str(a.status) === 'new' ? 0 : 1) - (str(b.status) === 'new' ? 0 : 1)) || (num(toDate(b.created_at)) - num(toDate(a.created_at)))).slice(0, 100); }
    function draw() {
        if (!root) return;
        const t = q.value.trim().toLowerCase(), s = stSel.value;
        const list = sorted().filter((x) => (s === 'all' || str(x.status, 'new') === s) && (!t || [x.message, from(x), x.location].some((v) => str(v).toLowerCase().includes(t))));
        fill(listEl, table([
            { label: '#', render: (x) => str(x.status, 'new') === 'new' ? h('b', { class: 'tone-darkred' }, T('ui_new_up', 'NEW')) : '#' + x.id },
            { label: T('ui_col_tip', 'Tip'), render: (x) => cut(x.message, 70), title: (x) => str(x.message) },
            { label: T('ui_col_from', 'From'), render: (x) => from(x) },
            { label: T('ui_location', 'Location'), render: (x) => str(x.location, '—') },
            { label: T('ui_col_received', 'Received'), render: (x) => fmtDateTime(x.created_at) },
            { label: '', cls: 'act', render: (x) => [iconBtn('visibility', T('ui_view', 'View'), () => view(x)),
                str(x.status, 'new') === 'new' ? iconBtn('done', T('ui_mark_read', 'Mark read'), () => markRead(x)) : null,
                can('deletetips') ? iconBtn('delete', T('ui_delete', 'Delete'), () => remove(x)) : null] },
        ], list, { onRow: (x) => view(x), rowClass: (x) => str(x.status, 'new') === 'new' ? 'unread' : '', empty: emptyState(T('ui_no_tips', 'No tips'), null, 'lightbulb') }));
    }
    async function markRead(x) { await nui('markTipRead', { id: num(x.id) }, 8000, null); x.status = 'read'; countUnread(); draw(); }
    async function remove(x, after) {
        if (!(await confirmBox({ message: T('ui_delete_tip_q', 'Delete tip #%s?', str(x.id)), confirm: T('ui_delete', 'Delete'), danger: true }))) return;
        const r = await nui('deleteTip', { id: num(x.id) }, 8000, null);
        if (!ok(r)) { notify(msgOf(r, T('ui_action_failed', 'That did not work'))); return; }
        tips = tips.filter((y) => y !== x); countUnread(); draw();
        notify(T('ui_tip_deleted', 'Tip deleted'));
        if (after) after();
    }
    function view(x) {
        const m = modal({
            title: T('ui_citizen_tip_n', 'Citizen Tip #%s', str(x.id)), icon: 'lightbulb', backdropCloses: true,
            body: [h('div', { class: 'muted' }, [from(x), str(x.location, '—'), fmtDateTime(x.created_at)].join(' · ')), h('p', { class: 'pre' }, str(x.message))],
            footer: [str(x.status, 'new') === 'new' ? h('button', { class: 'btn', type: 'button', onclick: () => { markRead(x); m.close(true); } }, T('ui_mark_read', 'Mark read')) : null,
                can('deletetips') ? h('button', { class: 'btn danger', type: 'button', onclick: () => remove(x, () => m.close(true)) }, T('ui_delete', 'Delete')) : null],
        });
    }
    regTab({
        id: 'tips', icon: 'lightbulb', perm: 'viewtips', feature: 'feature_tips', label: () => T('ui_nav_tips', 'Tips'),
        build: (r) => {
            root = r;
            q = inp({ placeholder: T('ui_search_tips', 'Search message, sender or location…') });
            stSel = sel([['all', T('ui_all', 'All')], ['new', T('ui_tip_new', 'New')], ['read', T('ui_tip_read', 'Read')]], 'all');
            q.addEventListener('input', debounce(draw, 200));
            stSel.addEventListener('change', draw);
            listEl = h('div');
            add(r, [h('h2', { class: 'page-title' }, T('ui_nav_tips', 'Tips')), h('div', { class: 'toolbar' }, q, stSel, refreshBtn('tips', load, 0)), listEl]);
        },
        show: () => load(),
        preload: () => load(),
        reset: () => { root = null; tips = []; App.unreadTips = 0; },
        newTip: (tip) => {
            if (!tip) return;
            tip.status = tip.status || 'new';
            tips.unshift(tip);
            countUnread();
            draw();
            notify(T('ui_new_tip', 'New tip received (%s)', str(tip.location, T('ui_unknown_location', 'Unknown location'))), 5000);
        },
        push: () => { if (root && App.current === 'tips') load(); },
    });
})();
