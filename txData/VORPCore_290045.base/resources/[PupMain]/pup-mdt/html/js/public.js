'use strict';
// Full-screen pages for any player: public records kiosk, bounty hunter board, prison register, prisoner countdown.

const Pub = { kiosk: false, bh: false, jr: false };

// ---------- Public Records kiosk ----------
(function () {
    const K = { data: null, tab: 'record', tips: {}, penalOn: true, root: null, main: null };
    const PenalCats = () => ({
        1: T('ui_pc_cat1', 'Crimes Against Persons'), 2: T('ui_pc_cat2', 'Property Crimes'), 3: T('ui_pc_cat3', 'Weapons'), 4: T('ui_pc_cat4', 'Public Order'),
        5: T('ui_pc_cat5', 'Against Justice'), 6: T('ui_pc_cat6', 'Wilderness & Hunting'), 7: T('ui_pc_cat7', 'Narcotics & Contraband'),
        violent: T('ui_pc_violent', 'Violent'), property: T('ui_pc_property', 'Property'), theft: T('ui_pc_theft', 'Theft'), weapons: T('ui_pc_weapons', 'Weapons'), drugs: T('ui_pc_drugs', 'Drugs'),
        wildlife: T('ui_pc_wildlife', 'Wildlife'), order: T('ui_pc_order', 'Public Order'), justice: T('ui_pc_justice', 'Justice'), government: T('ui_pc_government', 'Government'),
        fraud: T('ui_pc_fraud', 'Fraud'), livestock: T('ui_pc_livestock', 'Livestock'), citation: T('ui_pc_citation', 'Citation'),
    });
    function close(fromPage) {
        if (!Pub.kiosk) return;
        Pub.kiosk = false;
        show($('#kiosk'), false);
        clear($('#kiosk'));
        if (fromPage) nui('closeCivilianRecord', {});
    }
    App.kioskClose = close;
    function nav() {
        const items = [['record', T('ui_k_my_record', 'My Record'), 'person'], ['search', T('ui_k_search', 'Person Search'), 'person_search'], ['bounties', T('ui_k_bounty_board', 'Bounty Board'), 'balance'], ['prison', T('ui_k_prison', 'Prison Records'), 'lock']];
        if (K.penalOn) items.push(['penal', T('ui_k_penal', 'Penal Code'), 'gavel']);
        if (K.tips.enabled) items.push(['tip', T('ui_k_tip', 'Leave a Tip'), 'lightbulb']);
        return h('nav', { class: 'k-nav' },
            h('div', { class: 'k-brand' }, h('img', { src: 'img/stamp.svg', alt: '' }), h('small', null, '— ' + T('ui_lh_line1', 'Dusk County Law') + ' —'), h('b', null, T('ui_k_title', 'Public Records')), h('small', null, '— ' + T('ui_lh_line2', "Sheriff's Office") + ' —')),
            items.map(([id, l, ic]) => h('button', { class: 'k-nav-btn' + (K.tab === id ? ' on' : ''), type: 'button', onclick: () => go(id) }, icon(ic), ' ', l)),
            h('button', { class: 'k-nav-btn close', type: 'button', onclick: () => close(true) }, icon('close'), ' ', T('ui_close', 'Close')));
    }
    function frame() {
        fill(K.root, h('div', { class: 'k-frame' }, nav(), K.main = h('main', { class: 'k-main' }), h('img', { class: 'k-watermark', src: 'img/logo.png', alt: '' })));
    }
    function go(tab, arg) { K.tab = tab; frame(); ({ record: () => drawRecord(K.data, false), search: () => search(1, ''), bounties: () => board(1, ''), prison: () => prisons(1), penal: penal, tip: tipForm, person: () => drawRecord(arg, true) })[tab](); }
    function statusBadge(r) {
        const wanted = r.isWanted || r.hasActiveBounty || arr(r.bounties || r.warrants).length > 0 || str(r.status) === 'wanted';
        return badge(wanted ? T('ui_wanted_up', 'WANTED') : str(r.status) === 'released' ? T('ui_released_up', 'RELEASED') : T('ui_clear_up', 'CLEAR'), wanted ? 'red' : str(r.status) === 'released' ? 'gold' : 'green');
    }
    function chargeList(c) {
        let v = c;
        if (typeof v === 'string') v = parseJson(v, v);
        if (Array.isArray(v)) return v.map((x) => str(x.label || x.code || x) + (num(x.count, 1) > 1 ? ' x' + num(x.count) : ''));
        return str(v).split(/\s*,\s*/).filter(Boolean);
    }
    function drawRecord(r, other) {
        if (!r) { fill(K.main, emptyState(T('ui_k_no_record', 'No record found'), null, 'person_off')); return; }
        const name = str(r.name || ((str(r.firstname) + ' ' + str(r.lastname)).trim()), T('ui_unknown', 'Unknown'));
        const arrests = arr(r.arrests).slice(0, 50);
        const bounties = arr(r.bounties || r.warrants).slice(0, 10);
        const prisonRows = arr(r.prisonRecords || r.prison || (Array.isArray(r.prisonTerms) ? r.prisonTerms : []));
        const terms = Array.isArray(r.prisonTerms) ? r.prisonTerms.length : prisonRows.length;
        const ident = str(r.identity || r.citizenid, '—');
        const totalCharges = num(r.totalCharges, arrests.reduce((s, a) => s + chargeList(a.charges).length, 0));
        const info = (l, v) => h('div', { class: 'info-row' }, h('span', { class: 'lbl' }, l), h('span', null, v));
        fill(K.main,
            other ? h('button', { class: 'btn ghost sm', type: 'button', onclick: () => go('search') }, icon('arrow_back'), T('ui_back', 'Back')) : null,
            h('div', { class: 'prof-head' }, r.photoUrl && isHttpUrl(r.photoUrl) ? img(r.photoUrl, 'mug') : icon('person', 'mug'),
                h('div', null, h('h2', null, name), statusBadge(r), other && (r.hasActiveBounty || r.isWanted) ? [' ', badge(T('ui_active_bounty', 'ACTIVE BOUNTY'), 'red')] : null,
                    h('div', { class: 'muted' }, T('ui_k_profile_line', 'Identity %s • Fines %s', ident, money(r.totalFines))))),
            h('div', { class: 'cols2' },
                section(T('ui_record_info', 'Record Info'), info(T('ui_col_status', 'Status'), statusBadge(r)), info(T('ui_total_fines', 'Total Fines'), money(r.totalFines)), info(T('ui_total_charges', 'Total Charges'), String(totalCharges)), info(T('ui_prison_terms', 'Prison Terms'), String(terms))),
                bounties.length ? section(T('ui_bounty_details', 'Bounty Details'), bounties.map((b) => h('div', { class: 'card tone-red' },
                    h('b', null, str(b.charges, T('ui_no_charges_listed', 'No charges listed'))),
                    h('div', null, T('ui_col_reward', 'Reward'), ': ', money(num(b.bounty_reward || b.reward) || num(b.bounty_fine || b.fine)), ' · ', T('ui_sentence_mo', 'Sentence %d mo', num(b.bounty_jailtime || b.jailtime))),
                    h('small', null, T('ui_col_expires', 'Expires'), ': ', b.expiry_date ? fmtDate(b.expiry_date) : T('ui_no_expiry', 'No expiry')),
                    b.notes ? h('p', { class: 'pre' }, str(b.notes)) : null))) : null),
            h('div', { class: 'chips' }, h('span', { class: 'chip-btn' }, T('ui_charges', 'Charges'), ': ', String(totalCharges)), h('span', { class: 'chip-btn' }, T('ui_k_prison_short', 'Prison'), ': ', String(terms)), h('span', { class: 'chip-btn' }, T('ui_total_fines', 'Total Fines'), ': ', money(r.totalFines))),
            section(T('ui_k_charges_arrests', 'Charges & Arrests'), arrests.length ? arrests.map((a) => h('div', { class: 'feed-row static' },
                h('b', null, chargeList(a.charges).join(', ') || T('ui_no_charges_listed', 'No charges listed')),
                h('small', null, [str(a.lawman_name, '—'), fmtDate(a.created_at), money(a.final_fine !== undefined ? a.final_fine : a.total_fine), T('ui_n_mo', '%d mo', num(a.final_months !== undefined ? a.final_months : a.total_months))].join(' • ')))) : h('div', { class: 'muted' }, T('ui_none', 'None'))),
            section(T('ui_active_bounties', 'Active Bounties'), bounties.length ? bounties.map((b) => h('div', { class: 'card' },
                badge(T('ui_wanted_up', 'WANTED'), 'red'), ' ', h('span', { class: 'tags inline' }, chargeList(b.charges).map((c) => h('span', { class: 'tag' }, c))),
                h('div', null, T('ui_col_reward', 'Reward'), ': ', money(num(b.bounty_reward || b.reward) || num(b.bounty_fine || b.fine)), ' · ', T('ui_sentence_mo', 'Sentence %d mo', num(b.bounty_jailtime || b.jailtime))),
                h('small', null, T('ui_posted_by_on', 'Posted by %s · %s', str(b.issued_by, '—'), fmtDate(b.created_at)), ' · ', T('ui_col_expires', 'Expires'), ': ', b.expiry_date ? fmtDate(b.expiry_date) : T('ui_no_expiry', 'No expiry')),
                b.notes ? h('p', { class: 'pre' }, str(b.notes)) : null)) : h('div', { class: 'muted' }, T('ui_none', 'None'))),
            section(T('ui_k_prison', 'Prison Records'), prisonRows.length ? prisonRows.map((p) => h('div', { class: 'feed-row static' },
                h('b', null, str(p.player_name || name), ' ', str(p.status) === 'active' ? badge(T('ui_serving', 'SERVING'), 'red') : badge(T('ui_released_up', 'RELEASED'), 'grey')),
                h('small', null, T('ui_jailed_line', 'Jailed by %s • %s • %d min • %s', str(p.imprisoned_by, '—'), fmtDate(p.imprisoned_at), num(p.sentence_minutes), money(p.fine_amount))))) : h('div', { class: 'muted' }, T('ui_none', 'None'))));
    }
    async function search(page, query) {
        const q = inp({ value: query, placeholder: T('ui_k_search_ph', 'Name or ID number…') });
        const results = h('div', null, loading(query ? T('ui_searching', 'Searching…') : T('ui_loading_citizens', 'Loading citizens…')));
        const run = () => search(1, q.value.trim());
        q.addEventListener('keydown', (e) => { if (e.key === 'Enter') run(); });
        fill(K.main, h('h2', null, T('ui_k_search', 'Person Search')), h('div', { class: 'toolbar' }, q, h('button', { class: 'btn primary sm', type: 'button', onclick: run }, icon('search'), T('ui_search_btn', 'Search'))), results);
        const r = await nuiPush('civSearchPerson', { query, page }, 8000, null);
        if (!Pub.kiosk || K.tab !== 'search') return;
        const list = arr(r && r.results);
        fill(results, list.length ? h('div', { class: 'card-grid' }, list.map((p) => h('button', { class: 'person-card', type: 'button', onclick: async () => {
            fill(K.main, loading());
            const d = await nuiPush('civViewPerson', { identity: str(p.identity) }, 8000, null);
            if (!Pub.kiosk) return;
            K.tab = 'person'; frame(); drawRecord(d && d.data, true);
        } }, p.photoUrl && isHttpUrl(p.photoUrl) ? img(p.photoUrl, 'mug') : icon('person', 'mug'), h('b', null, str(p.name || (str(p.firstname) + ' ' + str(p.lastname)))), h('small', null, T('ui_id_no', 'ID No. %s', str(p.identity))),
            num(p.activeBounties) > 0 || p.hasActiveBounty ? badge(T('ui_wanted_up', 'WANTED'), 'red') : badge(str(p.status) === 'released' ? T('ui_released_up', 'RELEASED') : T('ui_clear_up', 'CLEAR'), 'green'),
            num(p.totalFines) > 0 ? h('small', null, money(p.totalFines)) : null))) : emptyState((r && r.message) || T('ui_no_citizens', 'No citizens found'), null, 'person_search'),
        pager(num(r && r.currentPage, page), r && r.totalPages, r && r.totalRecords, (pg) => search(pg, query)));
    }
    async function board(page, query) {
        const q = inp({ value: query, placeholder: T('ui_search', 'Search…') });
        const grid = h('div', null, loading());
        q.addEventListener('input', debounce(() => board(1, q.value.trim()), 300));
        fill(K.main, h('h2', null, T('ui_k_bounty_board', 'Bounty Board')), h('div', { class: 'toolbar' }, q), grid);
        if (query) { q.focus(); q.setSelectionRange(query.length, query.length); }
        const r = await nuiPush('civGetBountyBoard', { page, search: query }, 8000, null);
        if (!Pub.kiosk || K.tab !== 'bounties') return;
        const list = arr(r && r.bounties);
        const counts = (b) => { const c = { felony: 0, misdemeanor: 0, infraction: 0 }; c.felony = num(b.felonies); c.misdemeanor = num(b.misdemeanors); c.infraction = num(b.infractions); return c; };
        fill(grid, list.length ? h('div', { class: 'poster-grid' }, list.map((b) => { const c = counts(b); return h('div', { class: 'poster wanted' },
            h('div', { class: 'poster-h' }, T('ui_wanted_stars', '★ WANTED ★')),
            (b.image_url || b.image || b.photoUrl) && isHttpUrl(b.image_url || b.image || b.photoUrl) ? img(b.image_url || b.image || b.photoUrl, 'poster-img') : icon('person', 'poster-img sil'),
            h('div', { class: 'poster-name' }, str(b.citizen_name || b.name, T('ui_unknown_outlaw', 'Unknown Outlaw'))),
            h('div', { class: 'poster-reward' }, T('ui_reward_up', 'REWARD'), ' ', money(num(b.bounty_reward || b.reward) || num(b.bounty_fine || b.fine))),
            h('small', null, T('ui_sentence_colon', 'Sentence: %d mo', num(b.bounty_jailtime || b.jailtime))),
            c.felony + c.misdemeanor + c.infraction ? h('small', null, T('ui_offence_counts', '%d felony · %d misdemeanor · %d infraction', c.felony, c.misdemeanor, c.infraction)) : null,
            h('div', { class: 'tags inline' }, chargeList(b.charges).map((x) => h('span', { class: 'tag' }, x))),
            b.notes ? h('p', { class: 'pre small' }, cut(b.notes, 160)) : null,
            b.issued_by ? h('small', null, T('ui_posted_by_dot', 'Posted by %s • %s', str(b.issued_by, '—'), fmtDate(b.created_at || b.createdAt))) : h('small', null, fmtDate(b.created_at || b.createdAt)),
            h('small', null, T('ui_expires_on', 'Expires %s', (b.expiry_date || b.expires) ? fmtDate(b.expiry_date || b.expires) : T('ui_no_expiry', 'No expiry')))); }))
            : emptyState(query ? T('ui_no_bounties_match', 'No bounties match your search') : T('ui_no_bounties', 'No active bounties'), null, 'balance'),
        pager(num(r && r.currentPage, page), r && r.totalPages, r && r.totalRecords, (pg) => board(pg, query)));
    }
    async function prisons(page) {
        const list = h('div', null, loading());
        fill(K.main, h('div', { class: 'toolbar' }, h('h2', null, T('ui_k_prison', 'Prison Records')), plainRefresh(() => prisons(page))), list);
        const r = await nuiPush('civGetPrisonRecords', { page }, 8000, null);
        if (!Pub.kiosk || K.tab !== 'prison') return;
        const rows = arr(r && r.records);
        fill(list, rows.length ? h('div', { class: 'card-grid' }, rows.map((p) => h('div', { class: 'card' },
            h('b', null, str(p.player_name || p.name)), ' ', badge(T('ui_serving', 'SERVING'), 'red'),
            h('div', null, T('ui_k_inmate_line', 'Jailed %s • %d min sentence • %d min left', fmtDate(p.imprisoned_at || p.imprisonedAt), num(p.sentence_minutes !== undefined ? p.sentence_minutes : p.sentenceMinutes), num(p.minutesLeft))),
            p.reason ? h('small', { class: 'muted' }, str(p.reason)) : null))) : emptyState(T('ui_no_prisoners', 'No active prisoners'), null, 'lock'),
        pager(num(r && r.currentPage, page), r && r.totalPages, r && r.totalRecords, prisons));
    }
    async function penal() {
        fill(K.main, loading());
        const r = await nuiPush('civGetPenalCode', {}, 8000, null);
        if (!Pub.kiosk || K.tab !== 'penal') return;
        const all = arr(r && r.fines).sort((a, b) => naturalCmp(a.code, b.code));
        const cats = PenalCats();
        const catOf = (x) => {
            if (x.category && cats[x.category]) return x.category;
            const m = /(\d)\d{3}/.exec(str(x.code));
            return m && cats[m[1]] ? m[1] : 'other';
        };
        const counts = {};
        all.forEach((x) => { const c = catOf(x); counts[c] = (counts[c] || 0) + 1; });
        const keys = Object.keys(counts).sort((a, b) => {
            const na = /^\d$/.test(a), nb = /^\d$/.test(b);
            if (a === 'other') return 1; if (b === 'other') return -1;
            if (na !== nb) return na ? -1 : 1;
            return na ? a - b : str(cats[a]).localeCompare(str(cats[b]));
        });
        let cat = 'all', page = 1;
        const q = inp({ placeholder: T('ui_search', 'Search…') });
        const chips = h('div', { class: 'pills' });
        const list = h('div');
        const tierTone = { principal: 'red', attempted: 'orange', accessory: 'green' };
        const draw = () => {
            clear(chips);
            chips.appendChild(h('button', { class: 'pill' + (cat === 'all' ? ' on' : ''), type: 'button', onclick: () => { cat = 'all'; page = 1; draw(); } }, T('ui_all_n', 'All (%d)', all.length)));
            keys.forEach((k) => chips.appendChild(h('button', { class: 'pill' + (cat === k ? ' on' : ''), type: 'button', onclick: () => { cat = k; page = 1; draw(); } }, (cats[k] || T('ui_pc_other', 'Other Offenses')) + ' (' + counts[k] + ')')));
            const t = q.value.trim().toLowerCase();
            const rows = all.filter((x) => (cat === 'all' || catOf(x) === cat) && (!t || [x.label, x.code, x.description, JSON.stringify(x.burdens || '')].some((v) => str(v).toLowerCase().includes(t))));
            const pg = slicePage(rows, page, 12); page = pg.page;
            fill(list, pg.rows.length ? pg.rows.map((x) => {
                const tiers = arr(parseJson(x.tiers, []));
                const burdens = arr(parseJson(x.burdens, []));
                const defs = arr(parseJson(x.definitions, []));
                const tone = x.color ? ({ red: 'red', orange: 'orange', green: 'green' }[x.color] || classTone(x.charge_class)) : classTone(x.charge_class);
                const box = (label, fine, months, tn) => h('div', { class: 'pen-box tone-' + tn }, h('small', null, label), h('b', null, money(fine) + ' | ' + (num(months) ? T('ui_n_months_cap', '%d Months', num(months)) : T('ui_no_jail', 'No jail'))));
                return h('div', { class: 'pc-entry tone-border-' + tone },
                    h('h3', null, str(x.label)),
                    h('div', { class: 'tags inline' }, h('span', { class: 'tag' }, cats[catOf(x)] || T('ui_pc_other', 'Other Offenses')), h('span', { class: 'tag tone-' + classTone(x.charge_class) }, classLabel(x.charge_class)), h('span', { class: 'tag' }, str(x.code))),
                    x.description ? h('p', null, str(x.description)) : null,
                    burdens.length ? section(T('ui_burdens', 'Burdens of Proof'), h('ul', null, burdens.map((b) => h('li', null, str(b))))) : null,
                    defs.length ? section(T('ui_definitions', 'Definitions'), defs.map((d) => h('div', null, h('b', null, str(d.term)), ' ', str(d.body || d.text), arr(d.items).length ? h('ul', null, arr(d.items).map((i) => h('li', null, str(i)))) : null))) : null,
                    h('div', { class: 'pen-boxes' }, tiers.length ? tiers.map((tr) => box(str(tr.kind || tr.label), tr.fine, tr.months, tierTone[str(tr.kind).toLowerCase()] || 'grey')) : box(T('ui_penalty', 'Penalty'), x.fine, x.months, tone)));
            }) : emptyState(T('ui_no_match', 'no match')), pager(pg.page, pg.totalPages, pg.total, (p) => { page = p; draw(); }));
        };
        q.addEventListener('input', () => { page = 1; draw(); });
        fill(K.main, h('h2', null, T('ui_k_penal', 'Penal Code')), h('p', { class: 'muted' }, T('ui_pc_intro', 'The official schedule of offenses, fines and jail terms. For reference only.')), q, chips, list);
        draw();
    }
    function tipForm() {
        const msg = area({ rows: 6, maxlength: num(K.tips.maxLength, 300) });
        const anon = h('input', { type: 'checkbox' });
        const send = h('button', { class: 'btn primary', type: 'button' }, T('ui_send_tip', 'Send Tip'));
        send.addEventListener('click', () => busy(send, null, async () => {
            const t = msg.value.trim();
            if (!t) { notify(T('ui_tip_empty', 'Please enter a tip first.')); return; }
            const r = await nui('submitTip', { message: t.slice(0, num(K.tips.maxLength, 300)), anonymous: !!(K.tips.allowAnonymous && anon.checked) }, 8000, null);
            if (ok(r)) { notify(T('ui_tip_sent', 'Tip sent — thank you')); msg.value = ''; anon.checked = false; }
            else notify(msgOf(r, T('ui_tip_failed', 'Your tip could not be sent')));
        }));
        fill(K.main, h('h2', null, T('ui_k_tip', 'Leave a Tip')),
            h('p', null, T('ui_tip_text', 'Report suspicious activity to the Sheriff\'s Office. Your tip goes straight to on-duty lawmen.')),
            msg, h('small', { class: 'muted' }, T('ui_max_chars', 'Up to %d characters', num(K.tips.maxLength, 300))),
            K.tips.allowAnonymous ? h('label', { class: 'check' }, anon, ' ', T('ui_submit_anon', 'Submit anonymously')) : null,
            h('div', { class: 'frow end' }, send));
    }
    App.kioskOpen = (d) => {
        if (App.open) { nui('closeCivilianRecord', {}); return; } // the client gave the kiosk the cursor: hand it back
        Pub.kiosk = true;
        K.data = d.recordData || d.record || null;
        K.tips = d.tips || {};
        K.penalOn = !(d.penalCode && d.penalCode.enabled === false);
        K.root = $('#kiosk');
        if (d.theme) applyTheme(d.theme);
        show(K.root, true);
        go('record');
    };
})();

// ---------- Bounty hunter board ----------
(function () {
    const B = { list: [], page: 1, q: '', hints: {}, root: null };
    function close(fromPage) {
        if (!Pub.bh) return;
        Pub.bh = false;
        show(B.root, false); clear(B.root);
        if (fromPage) nui('bhClose', {});
    }
    App.bhClose = close;
    function draw() {
        const t = B.q.toLowerCase();
        const list = B.list.filter((b) => !t || str(b.name).toLowerCase().includes(t));
        const pg = slicePage(list, B.page, 6); B.page = pg.page;
        const search = inp({ value: B.q, placeholder: T('ui_search_name', 'Search name…') });
        search.addEventListener('input', () => { B.q = search.value; B.page = 1; draw(); const s = B.root.querySelector('.bh-search'); if (s) { s.focus(); s.setSelectionRange(s.value.length, s.value.length); } });
        search.classList.add('bh-search');
        fill(B.root, h('div', { class: 'bh-panel page-turn' },
            h('div', { class: 'bh-head' }, h('h2', null, icon('balance'), ' ', T('ui_bh_title', 'Bounty Board')), search, h('button', { class: 'x', type: 'button', onclick: () => close(true) }, icon('close'))),
            pg.rows.length ? h('div', { class: 'poster-grid' }, pg.rows.map((b) => {
                const hint = B.hints[String(b.id)];
                const tipBtn = h('button', { class: 'btn sm', type: 'button' }, T('ui_ask_around', 'Ask around'));
                tipBtn.addEventListener('click', async () => {
                    tipBtn.disabled = true; tipBtn.textContent = T('ui_asking', 'Asking…');
                    const r = await nuiPush('bhTip', { id: b.id }, 8000, null);
                    const hv = r && r.hint;
                    B.hints[String(b.id)] = hv ? str(hv) : false;
                    if (!hv) notify((r && r.message) || T('ui_no_hint', 'Nowhere to be seen. Come back later for a tip.'));
                    if (Pub.bh) draw();
                });
                return h('div', { class: 'poster wanted' },
                    h('div', { class: 'poster-h' }, T('ui_wanted_stars', '★ WANTED ★')),
                    b.image && isHttpUrl(b.image) ? img(b.image, 'poster-img') : icon('person', 'poster-img sil'),
                    h('div', { class: 'poster-name' }, str(b.name, T('ui_unknown_outlaw', 'Unknown Outlaw'))),
                    h('div', { class: 'poster-reward' }, T('ui_reward_up', 'REWARD'), ' ', money(num(b.reward) || num(b.fine))),
                    h('small', null, T('ui_sentence_colon', 'Sentence: %d mo', num(b.jailTime !== undefined ? b.jailTime : b.jailtime))),
                    h('div', { class: 'poster-crimes' }, cut(b.charges, 120)),
                    h('div', { class: 'bh-hint' }, hint ? T('ui_last_seen', 'Last seen: %s', hint) : (b.canTip !== false && b.canHint !== false && hint !== false ? tipBtn : null)),
                    h('button', { class: 'btn danger', type: 'button', onclick: () => nui('bhClaim', { id: b.id }) }, T('ui_claim_bounty', 'Claim Bounty')));
            })) : emptyState(T('ui_no_bounties', 'No active bounties'), null, 'balance'),
            h('div', { class: 'pager' },
                h('button', { class: 'btn ghost sm', type: 'button', disabled: pg.page <= 1, onclick: () => { B.page--; draw(); } }, T('ui_prev', '« Prev')),
                h('span', { class: 'pager-t' }, T('ui_bh_pager', 'Page %d of %d • %d bounties', pg.page, pg.totalPages, pg.total)),
                h('button', { class: 'btn ghost sm', type: 'button', disabled: pg.page >= pg.totalPages, onclick: () => { B.page++; draw(); } }, T('ui_next', 'Next »')))));
    }
    App.bhOpen = (d) => {
        B.root = $('#bhboard'); B.list = arr(d.bounties); B.page = 1; B.q = ''; B.hints = {};
        Pub.bh = true; show(B.root, true); draw();
    };
    App.bhTipResult = (d) => { if (!Pub.bh || !d) return; B.hints[String(d.id)] = d.hint ? str(d.hint) : false; draw(); };
    App.bhRemove = (id) => { if (!Pub.bh) return; B.list = B.list.filter((b) => String(b.id) !== String(id)); draw(); };
})();

// ---------- Prison register board ----------
(function () {
    function fmtLeft(s) {
        s = Math.max(0, Math.floor(num(s)));
        if (s >= 3600) return T('ui_hm', '%dh %dm', Math.floor(s / 3600), Math.floor((s % 3600) / 60));
        if (s >= 60) return T('ui_ms', '%dm %ds', Math.floor(s / 60), s % 60);
        return T('ui_s', '%ds', s);
    }
    App.jrClose = (fromPage) => {
        if (!Pub.jr) return;
        Pub.jr = false; show($('#register'), false); clear($('#register'));
        if (fromPage) nui('jrClose', {});
    };
    App.jrOpen = (d) => {
        const rows = arr(d.roster).slice().sort((a, b) => num(b.seconds) - num(a.seconds));
        Pub.jr = true;
        const root = $('#register');
        fill(root, h('div', { class: 'jr-panel page-turn' },
            h('div', { class: 'bh-head' }, h('h2', null, icon('gavel'), ' ', T('ui_jr_title', 'Prison Register')), h('button', { class: 'x', type: 'button', onclick: () => App.jrClose(true) }, icon('close'))),
            rows.length ? h('table', { class: 'tbl' }, h('thead', null, h('tr', null, h('th', null, T('ui_jr_inmate', 'Inmate')), h('th', null, T('ui_col_time_left', 'Time Left')))),
                h('tbody', null, rows.map((r) => h('tr', null, h('td', null, str(r.name)), h('td', null, fmtLeft(r.seconds))))))
                : emptyState(T('ui_jr_empty', 'No souls inside — the cells stand empty'), null, 'lock_open')));
        show(root, true);
    };
})();

// ---------- prisoner countdown ----------
(function () {
    let left = 0, tick = null;
    const draw = () => {
        const el = $('#jailtimer');
        const m = Math.floor(left / 60), s = left % 60;
        fill(el, icon('lock'), h('span', { class: 'jt-l' }, T('ui_jt_label', 'Sentence')), h('b', null, m + ':' + pad(s)));
    };
    App.jailTime = (sec) => {
        left = Math.max(0, Math.floor(num(sec)));
        show($('#jailtimer'), true);
        draw();
        if (!tick) tick = setInterval(() => { if (left > 0) left--; draw(); }, 1000);
    };
    App.jailClear = () => { if (tick) clearInterval(tick); tick = null; show($('#jailtimer'), false); clear($('#jailtimer')); };
})();
