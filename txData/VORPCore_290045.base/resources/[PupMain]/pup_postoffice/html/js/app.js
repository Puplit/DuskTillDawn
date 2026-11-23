/* pup_postoffice | the mail window */
'use strict';

(() => {
    const { h, icon } = U;
    const $ = id => document.getElementById(id);

    // chats: one list per side ('p' = your own box, 'b' = the business you may write for)
    function newChatState() {
        return {
            p: { list: [], badge: 0 }, b: { list: [], badge: 0 },
            blocks: [],
            bizBlocks: [],    // boxes the business blocked: [{ box, date }] (staff only)
            open: null,       // { id, view } of the chat on screen
            thread: null,     // { info, messages, hasMore, view }
            side: null,       // the reply thread beside it: { view, convId, parentId, parent, replies, hasMore, loading }
            seen: {},         // `${view}:${id}` -> what was read before the chat opened (marks threads with new replies)
            threads: false,   // the server has reply threads and reactions
            drafts: {},
            typing: {},       // `${view}:${id}` -> { label, until }
            filter: { p: 'all', b: 'all' },
            search: '',
            starting: null,   // ref of a start/create waiting for the server
            lastTyping: 0,
        };
    }

    const PAGE_ROWS = 60;
    const TOAST_MAX = 3;
    const SEND_TIMEOUT = 8000;
    const BUSY_MAX = 5000;
    const RESERVED = ['inbox', 'sent', 'trash'];

    const S = {
        cfg: { branding: {}, limits: { page: {} }, command: 'mail', changeCost: 0 },
        look: LOOK.validate({}),
        eff: {},
        open: false,
        loaded: false,
        box: null,
        letters: { p: [], b: [] },
        folders: { p: [], b: [] },
        contacts: [],
        business: null,
        directory: {},
        chat: newChatState(),
        view: 'p',
        route: { page: 'chats' },
        lists: {},
        draft: null,
        sending: null,
        reqSeq: 0,
        refSeq: 0,
        hud: { dx: 0, dy: 0, preview: false },
        contactFilter: { search: '', starred: false, selecting: false, selected: new Set() },
    };

    const lim = key => {
        const p = (S.cfg.limits && S.cfg.limits.page) || {};
        const d = { subject: 120, contactName: 48, contactBox: 24, contactNotes: 500, folderName: 32, groupTitle: 40, groupMessage: 500 };
        return Number(p[key]) || d[key];
    };

    /* ================================================================ model helpers */

    const bizBox = () => !!(S.business && S.business.handle && S.business.token);
    const canSendBiz = () => bizBox() && S.business.canSend === true;
    const canManage = view => (view || S.view) === 'p' || canSendBiz();
    const viewToken = view => ((view || S.view) === 'b' && bizBox()) ? S.business.job : String(S.box || '');
    const isSent = l => !l.copyTo && !l.copyToJob;
    const isSystem = l => l.from === 'system' || l.from === '0';
    const handleToJob = handle => {
        const want = String(handle || '').trim().toLowerCase();
        for (const job in S.directory) if (S.directory[job] && S.directory[job].handle === want) return job;
        return null;
    };
    const contactForBox = token => {
        const t = String(token || '').trim().toLowerCase();
        if (!t) return null;
        return S.contacts.find(c => String(c.poBox || '').trim().toLowerCase() === t) || null;
    };
    const contactKey = c => c.id ? 'i' + c.id : c.ref;
    const findContact = key => S.contacts.find(c => contactKey(c) === key) || null;
    const isFav = c => c.id && S.look.favorites.includes(String(c.id));

    function norm(l) {
        const out = Object.assign({}, l);
        out.id = Number(l.id) || 0;
        out.read = (l.read === true || Number(l.read) === 1) ? 1 : 0;
        out.anon = (l.anon === true || Number(l.anon) === 1) ? 1 : 0;
        out.hidesent = Number(l.hidesent) === 1 ? 1 : 0;
        out.from = l.from === undefined || l.from === null ? '' : String(l.from);
        out.to = Array.isArray(l.to) ? l.to.map(String) : [];
        out.toNames = Array.isArray(l.toNames) ? l.toNames.map(x => String(x || '')) : [];
        out.folder = typeof l.folder === 'string' && l.folder ? l.folder : 'Inbox';
        out.subject = typeof l.subject === 'string' ? l.subject : '';
        out.body = typeof l.body === 'string' ? l.body : '';
        out.fromName = typeof l.fromName === 'string' ? l.fromName : '';
        out.date = typeof l.date === 'string' ? l.date : '';
        out.copyTo = l.copyTo ? String(l.copyTo) : null;
        out.copyToJob = l.copyToJob ? String(l.copyToJob) : null;
        out.fromJob = l.fromJob ? String(l.fromJob) : null;
        return out;
    }

    function inFolder(l, folder) {
        if (folder === 'Inbox') return l.folder === 'Inbox' && !isSent(l);
        if (folder === 'Sent') return l.folder === 'Inbox' && isSent(l) && !l.hidesent;
        if (folder === 'Trash') return l.folder === 'Trash' && !isSent(l);
        return l.folder === folder;
    }
    const unreadIn = (view, folder) => S.letters[view].filter(l => inFolder(l, folder) && !isSent(l) && !l.read).length;
    const unreadBox = view => (view === 'b' && !bizBox()) ? 0 : unreadIn(view, 'Inbox');

    function senderInfo(l) {
        if (l.anon) return { name: l.fromName || 'Anonymous', sub: 'Sender withheld', kind: 'anon' };
        if (isSystem(l)) return { name: l.fromName || 'Post Office', sub: 'Official letter', kind: 'system' };
        const job = l.fromJob || (S.directory[l.from] ? l.from : null);
        if (job && S.directory[job]) return { name: S.directory[job].name || job, sub: S.directory[job].handle, kind: 'biz', job };
        if (job && S.business && S.business.job === job) return { name: S.business.name, sub: S.business.handle || '', kind: 'biz', job };
        const c = U.isBoxNumber(l.from) ? contactForBox(l.from) : null;
        if (c) return { name: c.name, sub: 'PO Box ' + l.from, kind: 'contact' };
        if (l.fromName) return { name: l.fromName, sub: U.isBoxNumber(l.from) ? 'PO Box ' + l.from : '', kind: 'named' };
        return { name: 'PO Box ' + l.from, sub: '', kind: 'box' };
    }

    function recipientLabel(t) {
        if (S.business && S.business.job === t) return S.business.name;
        if (S.directory[t]) return `${S.directory[t].name} (${S.directory[t].handle})`;
        const c = U.isBoxNumber(t) ? contactForBox(t) : null;
        if (c) return `${c.name} (${t})`;
        if (String(S.box) === t) return `You (PO Box ${t})`;
        return 'PO Box ' + t;
    }

    function sentToLine(l) {
        const names = l.toNames.filter(Boolean);
        return 'To: ' + (names.length ? names.join(', ') : l.to.map(recipientLabel).join(', '));
    }

    function plain(l) {
        if (l._plain === undefined) l._plain = U.plainText(l.body);
        return l._plain;
    }

    /* ================================================================ talking to the client */

    const post = U.post;
    function file(payload) {
        // the server caps every list at 200: send in slices
        const lists = ['read', 'del', 'hide', 'move'];
        let more = true, offset = 0;
        while (more) {
            more = false;
            const slice = {};
            let any = false;
            for (const k of lists) {
                const arr = payload[k] || [];
                const part = arr.slice(offset, offset + 200);
                if (part.length) { slice[k] = part; any = true; }
                if (arr.length > offset + 200) more = true;
            }
            if (any) post('file', slice);
            offset += 200;
        }
    }

    /* ================================================================ toasts, busy veil, dialogs */

    function toast(text, isError) {
        const host = $('toasts');
        while (host.children.length >= TOAST_MAX) host.removeChild(host.firstChild);
        const t = h('div', { class: 'toast' + (isError ? ' err' : '') }, text);
        host.appendChild(t);
        setTimeout(() => { t.classList.add('out'); setTimeout(() => t.remove(), 300); }, isError ? 5200 : 3400);
    }

    let busyTimer = null;
    function busy(on) {
        $('busy').classList.toggle('hidden', !on);
        clearTimeout(busyTimer);
        if (on) busyTimer = setTimeout(() => $('busy').classList.add('hidden'), BUSY_MAX);
    }

    function shake(node) {
        if (!node) return;
        node.classList.remove('shake');
        void node.offsetWidth;
        node.classList.add('shake');
    }

    let modalClose = null;
    function modal({ title, body, actions, wide }) {
        const host = $('modal');
        U.clear(host);
        const box = h('div', { class: 'dialog' + (wide ? ' wide' : '') });
        const close = () => { host.classList.add('hidden'); U.clear(host); modalClose = null; };
        box.appendChild(h('h2', { class: 'dialog-title' }, title));
        if (body) box.appendChild(h('div', { class: 'dialog-body' }, body));
        const row = h('div', { class: 'dialog-actions' });
        (actions || []).forEach(a => {
            row.appendChild(h('button', {
                class: 'btn' + (a.kind ? ' ' + a.kind : ''), type: 'button',
                on: { click: () => { if (a.onClick && a.onClick() === false) return; close(); } },
            }, a.label));
        });
        box.appendChild(row);
        host.appendChild(box);
        host.classList.remove('hidden');
        modalClose = close;
        const first = box.querySelector('input, textarea');
        if (first) setTimeout(() => first.focus(), 30);
        return close;
    }

    function confirmBox(title, text, okLabel, danger) {
        return new Promise(resolve => {
            let done = false;
            modal({
                title, body: h('p', null, text),
                actions: [
                    { label: 'Cancel', onClick: () => { done = true; resolve(false); } },
                    { label: okLabel || 'Confirm', kind: danger ? 'danger' : 'primary', onClick: () => { done = true; resolve(true); } },
                ],
            });
            const prev = modalClose;
            modalClose = () => { prev(); if (!done) resolve(false); };
        });
    }

    function promptBox(title, label, initial, maxLength, okLabel, check) {
        return new Promise(resolve => {
            let done = false;
            const input = h('input', { class: 'field', type: 'text', value: initial || '', maxLength: maxLength || 64 });
            const submit = () => {
                const v = input.value.trim();
                if (check) {
                    const err = check(v);
                    if (err) { toast(err, true); shake(input); return false; }
                }
                done = true; resolve(v); return true;
            };
            input.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); if (submit() !== false && modalClose) modalClose(); } });
            modal({
                title, body: h('label', { class: 'lbl' }, h('span', null, label), input),
                actions: [
                    { label: 'Cancel', onClick: () => { done = true; resolve(null); } },
                    { label: okLabel || 'Save', kind: 'primary', onClick: submit },
                ],
            });
            const prev = modalClose;
            modalClose = () => { prev(); if (!done) resolve(null); };
        });
    }

    /* ================================================================ HUD envelope */

    // red = your chats, blue = the business (its chats and letters), gold = your letters (Post)
    function hudCounts() {
        return { p: S.chat.p.badge || 0, b: (S.chat.b.badge || 0) + unreadBox('b'), g: unreadBox('p') };
    }

    function renderHud(forceShow) {
        const c = hudCounts();
        const hud = $('hud');
        const set = (id, n) => { const el = $(id); el.textContent = U.count(n); el.classList.toggle('hidden', n <= 0); };
        set('hud-p', c.p); set('hud-b', c.b); set('hud-g', c.g);
        hud.style.transform = `translate(${S.hud.dx}px, ${S.hud.dy}px)`;
        const any = c.p + c.b + c.g > 0;
        if (S.hud.preview) hud.classList.remove('hidden');
        else if (S.open || !any) hud.classList.add('hidden');
        else if (forceShow || !hud.classList.contains('hidden')) hud.classList.remove('hidden');
    }

    /* ================================================================ window geometry and dragging */

    function layoutWindow() {
        const win = $('win');
        const compact = S.look.layout === 'compact';
        const bw = compact ? 960 : 1280, bh = compact ? 700 : 760;
        const k = S.look.scale / 100;
        const w = Math.min(Math.round(bw * k), window.innerWidth - 16);
        const hgt = Math.min(Math.round(bh * k), window.innerHeight - 16);
        win.style.width = w + 'px';
        win.style.height = hgt + 'px';
        let left;
        if (S.look.anchor === 'left') left = 24;
        else if (S.look.anchor === 'right') left = window.innerWidth - w - 24;
        else left = (window.innerWidth - w) / 2;
        let top = (window.innerHeight - hgt) / 2;
        let x = left + S.look.dx, y = top + S.look.dy;
        // keep at least 80 px reachable sideways and the top bar on screen
        x = Math.min(Math.max(x, 80 - w), window.innerWidth - 80);
        y = Math.min(Math.max(y, 0), window.innerHeight - 48);
        win.style.left = Math.round(x) + 'px';
        win.style.top = Math.round(y) + 'px';
        return { left, top, w, hgt };
    }

    function setupDrag() {
        const bar = $('topbar');
        let drag = null;
        bar.addEventListener('mousedown', e => {
            if (e.button !== 0 || e.target.closest('button, input, select, textarea, a, label')) return;
            drag = { x: e.clientX, y: e.clientY, dx: S.look.dx, dy: S.look.dy };
            e.preventDefault();
        });
        window.addEventListener('mousemove', e => {
            if (!drag) return;
            const base = layoutWindow();
            let dx = drag.dx + (e.clientX - drag.x), dy = drag.dy + (e.clientY - drag.y);
            const x = Math.min(Math.max(base.left + dx, 80 - base.w), window.innerWidth - 80);
            const y = Math.min(Math.max(base.top + dy, 0), window.innerHeight - 48);
            S.look.dx = Math.max(-4000, Math.min(4000, Math.round(x - base.left)));
            S.look.dy = Math.max(-3000, Math.min(3000, Math.round(y - base.top)));
            layoutWindow();
        });
        window.addEventListener('mouseup', () => { if (drag) { drag = null; saveLook(); } });
        bar.addEventListener('dblclick', e => {
            if (e.target.closest('button, input, select, textarea')) return;
            S.look.dx = 0; S.look.dy = 0; layoutWindow(); saveLook();
        });
        window.addEventListener('resize', layoutWindow);
        // the window and its main column hide their overflow and are never meant to scroll; the browser
        // still scrolls them to reach a focused control, which slid the whole window out of place
        [$('win'), document.querySelector('#win > .main')].forEach(el => {
            if (el) el.addEventListener('scroll', () => { if (el.scrollTop || el.scrollLeft) { el.scrollTop = 0; el.scrollLeft = 0; } });
        });
    }

    let saveTimer = null;
    function saveLook() {
        clearTimeout(saveTimer);
        saveTimer = setTimeout(() => {
            const text = LOOK.serialize(S.look);
            if (text) post('saveSettings', { json: text });
        }, 350);
    }

    function applyLook() {
        S.eff = LOOK.apply(S.look, S.cfg.branding);
        layoutWindow();
    }

    /* ================================================================ open / close */

    function openWindow(box) {
        if (box) S.box = Number(box) || S.box;
        S.open = true;
        S.view = 'p';
        S.route = { page: 'chats' };
        S.chat.open = null; S.chat.thread = null; S.chat.side = null;
        chatOp('list', { view: 'p' });
        if (canSendBiz()) chatOp('list', { view: 'b' });
        $('win').classList.remove('hidden');
        $('dim').classList.remove('hidden');
        applyLook();
        render();
        renderHud();
        post('ready');
    }

    function hideWindow(tellClient) {
        if (modalClose) modalClose();
        EMOJI.close();
        S.open = false;
        $('win').classList.add('hidden');
        $('dim').classList.add('hidden');
        renderHud(true);
        if (tellClient) post('close');
    }

    /* ================================================================ data from the client */

    function wipe() {
        S.loaded = false;
        S.box = null;
        S.letters = { p: [], b: [] };
        S.folders = { p: [], b: [] };
        S.contacts = [];
        S.business = null;
        S.chat = newChatState();
        S.draft = null; S.lists = {};
        S.view = 'p';
        if (S.sending) { clearTimeout(S.sending.timer); S.sending = null; }
        $('hud').classList.add('hidden');
        if (S.open) hideWindow(false);
    }

    function loadMailbox(data) {
        if (!data || typeof data !== 'object') { wipe(); return; }
        S.box = Number(data.box) || null;
        S.letters.p = (data.letters || []).map(norm);
        S.letters.b = (data.businessLetters || []).map(norm);
        S.folders.p = (data.folders || []).filter(f => f && f.id).map(f => ({ id: f.id, name: String(f.name || '') }));
        S.folders.b = (data.businessFolders || []).filter(f => f && f.id).map(f => ({ id: f.id, name: String(f.name || '') }));
        // contacts still waiting for their id stay until the server answers
        const waiting = S.contacts.filter(c => !c.id);
        S.contacts = (data.contacts || []).map(c => ({ id: c.id, name: String(c.name || ''), poBox: String(c.poBox || ''), notes: String(c.notes || '') })).concat(waiting);
        S.business = data.business && typeof data.business === 'object' ? data.business : null;
        S.directory = data.directory && typeof data.directory === 'object' ? data.directory : {};
        if (S.view === 'b' && !bizBox()) { S.view = 'p'; if (S.route.page === 'list') S.route = { page: 'list', folder: 'Inbox' }; }
        // business chats only for ranks that may write for the business
        if (canSendBiz()) chatOp('list', { view: 'b' });
        else {
            S.chat.b = { list: [], badge: 0 };
            if (S.chat.open && S.chat.open.view === 'b') { S.chat.open = null; S.chat.thread = null; }
            if (S.view === 'b' && S.route.page === 'chats') S.route = { page: 'list', folder: 'Inbox' };
        }
        S.loaded = true;
        if (S.open) render();
        renderHud(true);
    }

    function addLetter(raw, incoming) {
        if (!raw || typeof raw !== 'object') return;
        const l = norm(raw);
        if (!l.id) return;
        // another resource may fire the event without the flag: a copy with no recipient column that is not
        // our own sent copy can only be a letter for us
        if (!incoming && !l.copyTo && !l.copyToJob && l.from !== String(S.box || '')
            && !(l.fromJob && bizBox() && l.fromJob === S.business.job)) incoming = true;
        let view;
        if (l.copyToJob) view = 'b';
        else if (l.copyTo) view = 'p';
        else if (!incoming) view = l.fromJob ? 'b' : 'p';
        else { l.copyTo = String(S.box || ''); view = 'p'; }
        if (view === 'b' && (!bizBox() || S.business.job !== (l.copyToJob || l.fromJob))) return;
        const list = S.letters[view];
        const at = list.findIndex(x => x.id === l.id);
        if (at >= 0) list[at] = l; else list.push(l);
        if (incoming && !l.read) {
            if (S.open) {
                if (view === S.view) toast('New letter from ' + senderInfo(l).name);
            }
        }
        if (S.open) render();
        renderHud(incoming && !l.read);
    }

    const HANDLERS = {
        init(m) {
            const c = m.config || {};
            S.cfg = {
                branding: c.branding || {}, limits: c.limits || { page: {} }, command: c.command || 'mail', changeCost: c.changeCost || 0,
                reactions: arr(c.reactions).filter(e => typeof e === 'string' && e).slice(0, 12),
            };
            S.look = LOOK.load(m.settings);
            applyLook();
            renderHud();
        },
        open(m) { openWindow(m.box); },
        close() { hideWindow(false); },
        // a new character (or a restart): nothing of the previous character may stay, drafts included
        forgetBox() { wipe(); },
        mailbox(m) { loadMailbox(m.data); },
        boxNumber(m) { S.box = Number(m.box) || null; if (S.open) render(); },
        letter(m) { addLetter(m.letter, m.incoming === true); },
        sendResult(m) { onSendResult(m.req, m.ok === true); },
        contactAdded(m) { onContactAdded(m.ref, m.id, m.contact); },
        folderAdded(m) { onFolderAdded(m.ref, m.id, m.business === true, m.name); },
        directory(m) { S.directory = m.data || {}; if (S.open) render(); },
        chat(m) { if (m.data && typeof m.data === 'object') onChat(m.data); },
        hudPos(m) {
            S.hud = { dx: Number(m.dx) || 0, dy: Number(m.dy) || 0, preview: m.preview === true };
            renderHud();
        },
    };

    window.addEventListener('message', ev => {
        const m = ev.data;
        if (!m || typeof m !== 'object' || typeof m.type !== 'string') return;
        const fn = HANDLERS[m.type];
        if (fn) { try { fn(m); } catch (e) { console.error('[mail]', m.type, e); } }
    });

    /* ================================================================ navigation and rendering */

    function go(route) {
        S.route = route;
        EMOJI.close();
        if (S.open) render();
    }

    function render() {
        if (!S.open) return;
        renderRail();
        renderView();
    }

    function setTop({ kicker, heading, back, tools }) {
        $('kicker').textContent = kicker || '';
        $('heading').textContent = heading || '';
        const b = $('back');
        b.classList.toggle('hidden', !back);
        b.onclick = back || null;
        const t = U.clear($('tools'));
        (tools || []).forEach(n => n && t.appendChild(n));
    }

    function renderView() {
        const r = S.route;
        const view = U.clear($('view'));
        view.className = 'view page-' + r.page;
        view.onkeydown = null;
        if (r.page === 'compose') return renderCompose(view);
        if (r.page === 'contacts') return renderContacts(view);
        if (r.page === 'contact') return renderContact(view);
        if (r.page === 'contactForm') return renderContactForm(view);
        if (r.page === 'chats') return renderChats(view);
        if (r.page === 'settings') return renderSettings(view);
        return renderList(view);
    }

    /* ---------------------------------------------------------------- rail */

    function crest(cls) {
        const logo = S.cfg.branding && S.cfg.branding.logo;
        if (logo) return h('img', { class: cls, attrs: { src: logo, alt: '' } });
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        svg.setAttribute('viewBox', '0 0 64 64');
        svg.setAttribute('class', cls + ' drawn');
        svg.innerHTML = '<circle cx="32" cy="32" r="29" fill="none" stroke="currentColor" stroke-width="2.5"/>'
            + '<circle cx="32" cy="32" r="23" fill="none" stroke="currentColor" stroke-width="1" stroke-dasharray="2 3"/>'
            + '<path d="M17 24h30v18H17z" fill="none" stroke="currentColor" stroke-width="2.2"/>'
            + '<path d="M17 24l15 11 15-11" fill="none" stroke="currentColor" stroke-width="2.2"/>';
        return svg;
    }

    function railItem({ label, ico, active, count, onClick, extra, dot }) {
        return h('div', { class: 'rail-item' + (active ? ' active' : ''), on: { click: onClick }, title: label },
            icon(ico), h('span', { class: 'rail-label' }, label),
            dot ? h('span', { class: 'dot ' + dot }) : null,
            count ? h('span', { class: 'badge' }, U.count(count)) : null,
            extra || null);
    }

    function renderRail() {
        const rail = U.clear($('rail'));
        const r = S.route;
        const b = S.cfg.branding || {};
        rail.appendChild(h('div', { class: 'brand' }, crest('crest'),
            h('div', { class: 'brand-text' },
                h('div', { class: 'brand-title' }, b.title || 'Mail'),
                h('div', { class: 'brand-sub' }, S.box ? 'PO Box ' + S.box : 'Not registered'))));

        if (bizBox()) {
            const sw = h('div', { class: 'switcher' });
            [['p', 'Personal', 'red'], ['b', 'Business', 'blue']].forEach(([v, label, colour]) => {
                const chats = v === 'p' || canSendBiz();
                sw.appendChild(h('button', {
                    class: 'sw' + (S.view === v ? ' on' : ''), type: 'button',
                    on: { click: () => { S.view = v; go(chats ? { page: 'chats' } : { page: 'list', folder: 'Inbox' }); } },
                }, label, (unreadBox(v) || S.chat[v].badge) ? h('span', { class: 'dot ' + colour }) : null));
            });
            rail.appendChild(sw);
        }

        if (S.view === 'p' || canSendBiz()) {
            rail.appendChild(h('div', { class: 'rail-sec' }, railItem({
                label: S.view === 'b' ? 'Customers' : 'Chats', ico: 'chat', active: r.page === 'chats',
                count: S.chat[S.view].badge, onClick: () => go({ page: 'chats' }),
            })));
        }

        rail.appendChild(h('button', {
            class: 'write-btn', type: 'button', on: { click: () => go({ page: 'compose' }) },
        }, icon('pen'), h('span', { class: 'rail-label' }, 'Write a Letter'),
            (S.draft && r.page !== 'compose' && !draftEmpty(S.draft)) ? h('span', { class: 'tag' }, 'Draft') : null));

        const sec = (title, kids, extra) => h('div', { class: 'rail-sec' },
            h('div', { class: 'rail-head' }, h('span', { class: 'rail-label' }, title), extra || null), kids);

        const isList = f => r.page === 'list' && !r.from && r.folder === f;
        const mbTitle = S.view === 'b' && bizBox() ? S.business.name + ' · Post' : 'Post';
        rail.appendChild(sec(mbTitle, [
            railItem({ label: 'Inbox', ico: 'inbox', active: isList('Inbox'), count: unreadBox(S.view), onClick: () => go({ page: 'list', folder: 'Inbox' }) }),
            railItem({ label: 'Sent', ico: 'sent', active: isList('Sent'), onClick: () => go({ page: 'list', folder: 'Sent' }) }),
            railItem({ label: 'Trash', ico: 'trash', active: isList('Trash'), onClick: () => go({ page: 'list', folder: 'Trash' }) }),
        ]));

        const manage = canManage();
        const folders = S.folders[S.view].slice().sort((a, b2) => U.nameCompare(a.name, b2.name));
        const fItems = folders.map(f => railItem({
            label: f.name, ico: 'folder', active: isList(f.name), count: unreadIn(S.view, f.name),
            onClick: () => go({ page: 'list', folder: f.name }),
            extra: manage ? h('span', { class: 'row-tools' },
                h('button', { class: 'mini', type: 'button', title: 'Rename', on: { click: e => { e.stopPropagation(); renameFolder(f); } } }, icon('edit')),
                h('button', { class: 'mini', type: 'button', title: 'Delete', on: { click: e => { e.stopPropagation(); deleteFolder(f); } } }, icon('trash'))) : null,
        }));
        if (!fItems.length) fItems.push(h('div', { class: 'rail-empty' }, manage ? 'No folders yet' : 'None'));
        rail.appendChild(sec('Folders', fItems, manage ? h('button', {
            class: 'mini', type: 'button', title: 'New folder', on: { click: createFolder },
        }, icon('plus')) : null));

        rail.appendChild(sec('People', [
            railItem({ label: 'Address Book', ico: 'book', active: ['contacts', 'contact', 'contactForm'].includes(r.page), onClick: () => go({ page: 'contacts' }) }),
        ]));

        rail.appendChild(h('div', { class: 'rail-foot' },
            railItem({ label: 'Settings', ico: 'gear', active: r.page === 'settings', onClick: () => go({ page: 'settings' }) }),
            b.motto ? h('div', { class: 'motto' }, b.motto) : null));
    }

    /* ---------------------------------------------------------------- folders */

    function folderNameError(name, except) {
        if (!name) return 'Give the folder a name';
        const low = name.toLowerCase();
        if (RESERVED.includes(low)) return 'There is already a folder with that name';
        if (S.folders[S.view].some(f => f !== except && f.name.toLowerCase() === low)) return 'There is already a folder with that name';
        return null;
    }

    async function createFolder(e) {
        if (e) e.stopPropagation();
        if (!canManage()) return;
        const view = S.view;
        const name = await promptBox('New folder', 'Folder name', '', lim('folderName'), 'Create', v => folderNameError(v));
        if (!name || view !== S.view) return;
        const ref = 'f' + (++S.refSeq);
        S.folders[view].push({ id: null, ref, name });
        busy(true);
        post('folders', { op: 'add', business: view === 'b', name, ref });
        render();
    }

    function onFolderAdded(ref, id, business, name) {
        const view = business ? 'b' : 'p';
        const f = S.folders[view].find(x => x.ref === ref);
        busy(false);
        if (!id) {
            if (f) S.folders[view] = S.folders[view].filter(x => x !== f);
            if (S.route.page === 'list' && f && S.route.folder === f.name) S.route = { page: 'list', folder: 'Inbox' };
        } else if (f) {
            f.id = id; delete f.ref;
            toast(`Folder "${f.name}" created`);
        } else if (!S.folders[view].some(x => x.id === id)) {
            S.folders[view].push({ id, name: String(name || '') });
        }
        if (S.open) render();
    }

    async function renameFolder(f) {
        if (!f.id) return toast('That folder is still being filed. Try again in a moment.', true);
        const view = S.view;
        const name = await promptBox('Rename folder', 'Folder name', f.name, lim('folderName'), 'Rename', v => folderNameError(v, f));
        if (!name || name === f.name) return;
        const old = f.name;
        f.name = name;
        S.letters[view].forEach(l => { if (l.folder === old) l.folder = name; });
        post('folders', { op: 'rename', business: view === 'b', id: f.id, name });
        if (S.route.page === 'list' && S.route.folder === old) S.route = { page: 'list', folder: name };
        render();
    }

    async function deleteFolder(f) {
        if (!f.id) return toast('That folder is still being filed. Try again in a moment.', true);
        const view = S.view;
        const ok = await confirmBox('Delete folder', `Delete "${f.name}"? Letters inside are moved to Trash.`, 'Delete', true);
        if (!ok) return;
        S.letters[view].forEach(l => { if (l.folder === f.name) l.folder = 'Trash'; });
        S.folders[view] = S.folders[view].filter(x => x !== f);
        post('folders', { op: 'del', business: view === 'b', id: f.id });
        if (S.route.page === 'list' && S.route.folder === f.name) S.route = { page: 'list', folder: 'Inbox' };
        render();
    }

    /* ---------------------------------------------------------------- letter list */

    function listKey(r) { return `${S.view}:${r.folder}:${r.from || ''}`; }

    function listState(r) {
        const key = listKey(r);
        if (!S.lists[key]) S.lists[key] = { search: '', sort: 'new', unread: false, openId: null, selected: new Set(), shown: PAGE_ROWS, scroll: 0 };
        return S.lists[key];
    }

    function lettersFor(r) {
        if (r.from) {
            return S.letters.p.filter(l => !l.anon && l.from === r.from && !isSent(l) && l.folder !== 'Trash');
        }
        return S.letters[S.view].filter(l => inFolder(l, r.folder));
    }

    function senderLine(l, folder) {
        return folder === 'Sent' ? sentToLine(l) : senderInfo(l).name;
    }

    function filterSort(list, st, folder) {
        let out = list;
        const q = st.search.trim().toLowerCase();
        if (q) {
            out = out.filter(l => {
                const s = senderInfo(l);
                const hay = [s.name, s.sub, l.subject, l.to.map(recipientLabel).join(' '), l.toNames.join(' '), plain(l)].join('\n').toLowerCase();
                return hay.includes(q);
            });
        }
        if (st.unread && folder !== 'Sent' && folder !== 'Trash') out = out.filter(l => !l.read && !isSent(l));
        const byNew = (a, b) => (b.date || '').localeCompare(a.date || '') || b.id - a.id;
        out = out.slice();
        if (st.sort === 'old') out.sort((a, b) => -byNew(a, b));
        else if (st.sort === 'unread') out.sort((a, b) => (a.read - b.read) || byNew(a, b));
        else if (st.sort === 'sender') out.sort((a, b) => U.nameCompare(senderLine(a, folder), senderLine(b, folder)) || byNew(a, b));
        else out.sort(byNew);
        return out;
    }

    function avatar(l, folder) {
        const s = senderInfo(l);
        if (l.anon) return h('div', { class: 'avatar anon' }, icon('mask'));
        if (folder === 'Sent') return h('div', { class: 'avatar' }, icon('sent'));
        return h('div', { class: 'avatar' + (s.kind === 'biz' ? ' biz' : s.kind === 'system' ? ' sys' : '') }, U.initials(s.name));
    }

    function renderList(view) {
        const r = S.route;
        const st = listState(r);
        const folder = r.from ? 'From' : r.folder;
        const manage = canManage();
        const kicker = S.view === 'b' && bizBox() ? S.business.name : 'Your Mailbox';
        let heading = r.folder;
        let back = null;
        if (r.from) {
            const c = findContact(r.contactKey);
            heading = 'Letters from ' + (c ? c.name : 'PO Box ' + r.from);
            back = () => go(c ? { page: 'contact', key: r.contactKey } : { page: 'contacts' });
        }
        setTop({ kicker, heading, back });

        const all = lettersFor(r);
        const shown = filterSort(all, st, folder);
        const present = new Set(all.map(l => l.id));
        st.selected.forEach(id => { if (!present.has(id)) st.selected.delete(id); });
        if (st.openId && !present.has(st.openId)) st.openId = null;

        const compact = S.look.layout === 'compact';
        const wrap = h('div', { class: 'list-wrap' + (st.openId ? ' has-open' : '') });
        view.appendChild(wrap);

        if (compact && st.openId) {
            const l = all.find(x => x.id === st.openId);
            wrap.appendChild(renderReader(l, folder, () => { st.openId = null; renderView(); }));
            return;
        }

        const pane = h('div', { class: 'list-pane' });
        wrap.appendChild(pane);

        // toolbar
        const search = h('input', { class: 'field search', type: 'search', placeholder: 'Search letters', value: st.search });
        search.addEventListener('input', () => { st.search = search.value; st.shown = PAGE_ROWS; redrawRows(); });
        const sort = h('select', { class: 'field sort', on: { change: () => { st.sort = sort.value; redrawRows(); } } },
            [['new', 'Newest first'], ['old', 'Oldest first'], ['unread', 'Unread first'], ['sender', 'Sender A to Z']].map(([v, t]) => h('option', { value: v }, t)));
        sort.value = st.sort;
        const selAll = h('input', { type: 'checkbox', title: 'Select all' });
        selAll.addEventListener('change', () => {
            const visible = filterSort(lettersFor(r), st, folder);
            if (selAll.checked) visible.forEach(l => st.selected.add(l.id)); else st.selected.clear();
            redrawRows();
        });
        const tools = h('div', { class: 'list-tools' }, h('label', { class: 'chk' }, selAll), h('span', { class: 'search-wrap' }, icon('search'), search), sort);
        if (folder !== 'Sent' && folder !== 'Trash') {
            tools.appendChild(h('button', {
                class: 'chip' + (st.unread ? ' on' : ''), type: 'button',
                on: { click: () => { st.unread = !st.unread; st.shown = PAGE_ROWS; renderView(); } },
            }, 'Unread'));
        }
        pane.appendChild(tools);
        const bulk = h('div', { class: 'bulk hidden' });
        pane.appendChild(bulk);
        const rows = h('div', { class: 'rows' });
        rows.addEventListener('scroll', () => { st.scroll = rows.scrollTop; });
        pane.appendChild(rows);

        function redrawRows() {
            const list = filterSort(lettersFor(r), st, folder);
            U.clear(rows);
            selAll.checked = list.length > 0 && list.every(l => st.selected.has(l.id));
            if (!list.length) {
                let msg = 'No letters here';
                if (st.search.trim() || st.unread) msg = 'Nothing matches';
                else if (folder === 'Trash') msg = 'The bin is empty';
                else if (folder === 'Sent') msg = 'No letters sent yet';
                rows.appendChild(h('div', { class: 'empty' }, h('p', null, msg),
                    (msg === 'No letters here' && !r.from) ? h('button', { class: 'btn primary', type: 'button', on: { click: () => go({ page: 'compose' }) } }, 'Write a letter') : null));
            }
            list.slice(0, st.shown).forEach(l => rows.appendChild(row(l)));
            if (list.length > st.shown) {
                rows.appendChild(h('button', {
                    class: 'btn more', type: 'button', on: { click: () => { st.shown += PAGE_ROWS; redrawRows(); } },
                }, `Show ${Math.min(PAGE_ROWS, list.length - st.shown)} more of ${list.length - st.shown}`));
            }
            renderBulk(list);
        }

        function row(l) {
            const unread = !l.read && !isSent(l);
            const cb = h('input', { type: 'checkbox', checked: st.selected.has(l.id) });
            cb.addEventListener('click', e => e.stopPropagation());
            cb.addEventListener('change', () => { if (cb.checked) st.selected.add(l.id); else st.selected.delete(l.id); redrawRows(); });
            return h('div', {
                class: 'row' + (unread ? ' unread' : '') + (st.openId === l.id ? ' open' : '') + (st.selected.has(l.id) ? ' sel' : ''),
                on: { click: () => openLetter(l) },
            },
                h('label', { class: 'chk' }, cb),
                avatar(l, folder),
                h('div', { class: 'row-main' },
                    h('div', { class: 'row-top' }, h('span', { class: 'row-from' }, senderLine(l, folder)), h('span', { class: 'row-date' }, U.shortDate(l.date))),
                    h('div', { class: 'row-subject' }, l.subject || '(no subject)'),
                    h('div', { class: 'row-preview' }, U.preview(l.body, 140))));
        }

        function openLetter(l) {
            st.openId = l.id;
            if (folder !== 'Sent' && !isSent(l) && !l.read) {
                l.read = 1;
                file({ read: [l.id] });
                renderRail();
                renderHud();
            }
            renderView();
        }

        function renderBulk(list) {
            U.clear(bulk);
            const ids = [...st.selected];
            bulk.classList.toggle('hidden', !ids.length);
            if (!ids.length) return;
            const sel = list.filter(l => st.selected.has(l.id));
            const all2 = lettersFor(r).filter(l => st.selected.has(l.id));
            const chosen = all2.length ? all2 : sel;
            bulk.appendChild(h('span', { class: 'bulk-count' }, `${ids.length} selected`));
            const btn = (label, ico, fn, cls) => bulk.appendChild(h('button', { class: 'btn small' + (cls ? ' ' + cls : ''), type: 'button', on: { click: fn } }, icon(ico), label));
            if (folder !== 'Sent' && folder !== 'Trash' && chosen.some(l => !l.read && !isSent(l))) {
                btn('Mark read', 'check', () => { markRead(chosen); st.selected.clear(); renderView(); });
            }
            if (manage && !r.from && folder !== 'Sent' && folder !== 'Trash') {
                btn('Move', 'move', () => pickFolder(r.folder, chosen, () => st.selected.clear()));
                btn('Trash', 'trash', () => { moveLetters(chosen, 'Trash'); st.selected.clear(); render(); });
            }
            if (folder === 'Sent') {
                btn('Remove', 'trash', async () => {
                    if (!await confirmBox('Remove from Sent', `Remove ${chosen.length} letter(s) from Sent? The recipients keep their copies.`, 'Remove', true)) return;
                    hideSent(chosen); st.selected.clear(); render();
                });
            }
            if (folder === 'Trash' && manage) {
                btn('Restore', 'restore', () => { moveLetters(chosen, 'Inbox'); st.selected.clear(); render(); });
                btn('Delete forever', 'trash', async () => {
                    if (!await confirmBox('Delete forever', `Delete ${chosen.length} letter(s) for good? This cannot be undone.`, 'Delete', true)) return;
                    deleteLetters(chosen); st.selected.clear(); render();
                }, 'danger');
            }
            btn('Clear', 'close', () => { st.selected.clear(); redrawRows(); });
        }

        redrawRows();
        rows.scrollTop = st.scroll;

        if (!compact) {
            const l = st.openId ? all.find(x => x.id === st.openId) : null;
            const side = h('div', { class: 'reader-pane' });
            if (l) side.appendChild(renderReader(l, folder, () => { st.openId = null; renderView(); }));
            else side.appendChild(h('div', { class: 'reader-empty' }, crest('crest big'), h('p', null, 'Choose a letter to read it')));
            wrap.appendChild(side);
        }
    }

    /* ---------------------------------------------------------------- filing actions */

    function markRead(list) {
        const ids = list.filter(l => !l.read && !isSent(l)).map(l => { l.read = 1; return l.id; });
        if (ids.length) file({ read: ids });
        renderHud();
    }

    function moveLetters(list, folder) {
        if (!list.length) return;
        list.forEach(l => { l.folder = folder; });
        file({ move: list.map(l => ({ id: l.id, folder })) });
        if (folder === 'Trash') toast(list.length === 1 ? 'Moved to Trash' : `${list.length} moved to Trash`);
        else if (folder === 'Inbox') toast(list.length === 1 ? 'Restored to Inbox' : `${list.length} restored to Inbox`);
        else toast(`Moved ${list.length} to ${folder}`);
        renderHud();
    }

    function deleteLetters(list) {
        const ids = new Set(list.map(l => l.id));
        S.letters[S.view] = S.letters[S.view].filter(l => !ids.has(l.id));
        file({ del: [...ids] });
        renderHud();
    }

    function hideSent(list) {
        const ids = new Set(list.map(l => l.id));
        S.letters[S.view] = S.letters[S.view].filter(l => !ids.has(l.id));
        file({ hide: [...ids] });
    }

    function pickFolder(current, list, after) {
        const targets = S.folders[S.view].filter(f => f.name !== current && f.id).map(f => f.name).sort(U.nameCompare);
        if (current !== 'Inbox' && list.some(l => l.folder !== 'Inbox')) targets.unshift('Inbox');
        if (!targets.length) return toast('Make a folder first', true);
        const body = h('div', { class: 'pick-list' }, targets.map(name => h('button', {
            class: 'pick', type: 'button',
            on: { click: () => { moveLetters(list, name); if (after) after(); if (modalClose) modalClose(); render(); } },
        }, icon(name === 'Inbox' ? 'inbox' : 'folder'), name)));
        modal({ title: 'Move to folder', body, actions: [{ label: 'Cancel' }] });
    }

    /* ---------------------------------------------------------------- envelope and sheet */

    function stamp() {
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        svg.setAttribute('viewBox', '0 0 60 72');
        svg.setAttribute('class', 'stamp');
        svg.innerHTML = '<rect x="2" y="2" width="56" height="68" rx="2" class="st-edge"/>'
            + '<rect x="7" y="7" width="46" height="58" class="st-face"/>'
            + '<path d="M14 48c4-10 10-16 16-18 6 2 12 8 16 18z" class="st-art"/>'
            + '<circle cx="30" cy="22" r="7" class="st-art"/>'
            + '<text x="30" y="60" text-anchor="middle" class="st-text">POSTAGE 2¢</text>';
        return svg;
    }

    function postmarkEl(iso) {
        const p = U.postmark(iso);
        return h('div', { class: 'postmark' }, h('span', { class: 'pm-month' }, p.month), h('span', { class: 'pm-day' }, p.day), h('span', { class: 'pm-time' }, p.time));
    }

    function envelope(fromBlock, toBlock, iso) {
        return h('div', { class: 'envelope' },
            h('div', { class: 'env-top' }, postmarkEl(iso), stamp()),
            h('div', { class: 'env-rows' },
                h('div', { class: 'env-row' }, h('span', { class: 'env-lbl' }, 'From'), fromBlock),
                h('div', { class: 'env-row' }, h('span', { class: 'env-lbl' }, 'To'), toBlock)));
    }

    function seal() {
        return h('div', { class: 'seal' }, crest('seal-crest'));
    }

    function sheet({ letterhead, date, subject, body, signoff, sending }) {
        const wm = (S.cfg.branding && S.cfg.branding.logo) ? h('img', { class: 'watermark', attrs: { src: S.cfg.branding.logo, alt: '' } }) : null;
        return h('div', { class: 'sheet' + (sending ? ' sending' : '') },
            h('div', { class: 'tg-head' }, S.cfg.branding.telegramHeader || 'TELEGRAPH OFFICE'),
            wm,
            letterhead || null,
            h('div', { class: 'sheet-date' }, date),
            subject,
            body,
            h('div', { class: 'signoff' }, signoff),
            seal());
    }

    /** A business letter's one heading: monogram, name and its mail address. */
    function letterhead(name, handle) {
        return h('div', { class: 'letterhead' },
            h('div', { class: 'lh-mono' }, U.initials(name)),
            h('div', { class: 'lh-text' },
                h('div', { class: 'lh-name' }, name),
                handle ? h('div', { class: 'lh-sub' }, 'Mail address ' + handle) : null),
            h('div', { class: 'lh-kind' }, 'Business', h('br'), 'correspondence'));
    }

    /** The company's rubber stamp, in place of a hand-written sign-off. */
    function bizStamp(name, handle) {
        return h('div', { class: 'co-stamp' }, h('div', { class: 'cs-name' }, name), handle ? h('div', { class: 'cs-sub' }, handle) : null);
    }

    /* ---------------------------------------------------------------- reader */

    function renderReader(l, folder, onBack) {
        if (!l) return h('div', { class: 'reader-empty' }, 'That letter is gone');
        const s = senderInfo(l);
        const own = isSent(l);
        const manage = canManage();
        const wrap = h('div', { class: 'reader' });

        const acts = h('div', { class: 'reader-actions' });
        const act = (label, ico, fn, cls) => acts.appendChild(h('button', { class: 'btn small' + (cls ? ' ' + cls : ''), type: 'button', on: { click: fn } }, icon(ico), label));
        act('Back', 'back', onBack);
        const rTok = (!own && !l.anon && !isSystem(l)) ? replyToken(l) : null;
        // a letter from a business is answered in the business chat (Config.Letters.businessByChat)
        const bizReply = !!rTok && !U.isBoxNumber(rTok) && bizByChat()
            && !(S.business && S.business.job === handleToJob(rTok));
        if (bizReply) {
            act('Reply in chat', 'chat', () => messageTarget(rTok));
        } else if (rTok) {
            act('Reply', 'reply', () => startReply(l, false));
            if (l.to.length > 1) act('Reply all', 'replyAll', () => startReply(l, true));
        }
        // a letter from a box can be answered in a chat as well
        if (!bizReply && !own && !l.anon && !isSystem(l)) {
            const fromJob = l.fromJob || (S.directory[l.from] ? l.from : null);
            const chatTo = U.isBoxNumber(l.from) && l.from !== String(S.box) ? l.from
                : (fromJob && S.directory[fromJob] && (!S.business || S.business.job !== fromJob) ? S.directory[fromJob].handle : null);
            if (chatTo) act('Chat', 'chat', () => messageTarget(chatTo));
        }
        act('Forward', 'forward', () => startForward(l));
        if (manage && folder !== 'Sent' && folder !== 'Trash' && folder !== 'From' && !own) {
            act('Move', 'move', () => pickFolder(l.folder, [l]));
            act('Trash', 'trash', () => { moveLetters([l], 'Trash'); render(); });
        }
        if (own && folder === 'Sent') {
            act('Remove from Sent', 'trash', async () => {
                if (!await confirmBox('Remove from Sent', 'Remove this letter from Sent? The recipients keep their copies.', 'Remove', true)) return;
                hideSent([l]); render();
            });
        }
        if (folder === 'Trash' && manage) {
            act('Restore', 'restore', () => { moveLetters([l], 'Inbox'); render(); });
            act('Delete for good', 'trash', async () => {
                if (!await confirmBox('Delete for good', 'Delete this letter for good? This cannot be undone.', 'Delete', true)) return;
                deleteLetters([l]); render();
            }, 'danger');
        }
        wrap.appendChild(acts);

        // From block
        const isBizLetter = !l.anon && s.kind === 'biz';
        // a business letter names its address once, in the letterhead
        const from = h('div', { class: 'env-who' }, h('div', { class: 'who-name' }, s.name), isBizLetter ? h('div', { class: 'who-sub' }, 'Business') : (s.sub ? h('div', { class: 'who-sub' }, s.sub) : null));
        if (!l.anon && !isSystem(l) && U.isBoxNumber(l.from) && l.from !== String(S.box) && !contactForBox(l.from)) {
            from.appendChild(h('a', {
                class: 'link', href: '#',
                on: { click: e => { e.preventDefault(); go({ page: 'contactForm', key: null, prefill: { poBox: l.from }, back: S.route }); } },
            }, 'Save contact'));
        }
        const to = h('div', { class: 'env-who' }, h('div', { class: 'who-name' }, l.to.map(recipientLabel).join(', ') || '—'));

        const bizHead = isBizLetter ? letterhead(s.name, s.sub) : null;
        const body = U.renderBody(l.body);
        wrap.appendChild(h('div', { class: 'paper-stack' + (isBizLetter ? ' biz' : '') },
            envelope(from, to, l.date),
            sheet({
                letterhead: bizHead,
                date: U.fullDate(l.date),
                subject: h('div', { class: 'sheet-subject' }, l.subject || '(no subject)'),
                body,
                signoff: l.anon ? 'Unsigned' : (isBizLetter ? bizStamp(s.name, s.sub) : '— ' + s.name),
            })));
        return wrap;
    }

    /* ---------------------------------------------------------------- reply and forward */

    function replyToken(l) {
        const job = l.fromJob || (S.directory[l.from] ? l.from : null);
        if (job && S.directory[job]) return S.directory[job].handle;
        if (U.isBoxNumber(l.from)) return l.from;
        return null;
    }

    function chipForToken(t) {
        if (U.isBoxNumber(t)) return boxChip(String(t).trim());
        const job = S.directory[t] ? t : handleToJob(t);
        if (job && S.directory[job]) return bizChip(job);
        return null;
    }

    function stripPrefix(s, re) {
        return String(s || '').replace(re, '');
    }

    function quoteBlock(headNodes, l) {
        const bq = document.createElement('blockquote');
        headNodes.forEach(n => bq.appendChild(n));
        const body = document.createElement('div');
        body.innerHTML = U.cleanHtml(l.body); // cleaned: only harmless tags, no attributes
        bq.appendChild(body);
        const box = document.createElement('div');
        box.appendChild(document.createElement('p')).appendChild(document.createElement('br'));
        box.appendChild(bq);
        return box.innerHTML;
    }

    function startReply(l, all) {
        let chips = [];
        const first = chipForToken(replyToken(l));
        if (first) chips.push(first);
        if (all) {
            const mine = viewToken();
            l.to.forEach(t => {
                if (t === mine || t === String(S.box)) return;
                const c = chipForToken(t);
                if (c && !chips.some(x => x.token === c.token)) chips.push(c);
            });
        }
        if (bizByChat()) chips = chips.filter(c => !chipIsBiz(c));
        const head = document.createElement('p');
        const em = document.createElement('i');
        em.textContent = `On ${U.longDate(l.date)}, ${senderInfo(l).name} wrote:`;
        head.appendChild(em);
        S.draft = {
            to: chips,
            subject: ('Re: ' + stripPrefix(l.subject, /^(\s*re\s*:\s*)+/i)).slice(0, lim('subject')),
            body: quoteBlock([head], l),
            caretTop: true,
            anon: false,
            asBiz: S.view === 'b' && canSendBiz(),
        };
        go({ page: 'compose' });
    }

    function startForward(l) {
        const head = document.createElement('p');
        const b = document.createElement('b');
        b.textContent = 'Forwarded letter';
        head.appendChild(b);
        const meta = document.createElement('p');
        [['From', senderInfo(l).name], ['To', l.to.map(recipientLabel).join(', ')], ['Dated', U.longDate(l.date)]].forEach(([k, v], i) => {
            if (i) meta.appendChild(document.createElement('br'));
            meta.appendChild(document.createTextNode(`${k}: ${v}`));
        });
        S.draft = {
            to: [],
            subject: ('Fwd: ' + stripPrefix(l.subject, /^(\s*fwd?\s*:\s*)+/i)).slice(0, lim('subject')),
            body: quoteBlock([head, meta, document.createElement('hr')], l),
            caretTop: true,
            anon: false,
            asBiz: S.view === 'b' && canSendBiz(),
        };
        go({ page: 'compose' });
    }

    /* ---------------------------------------------------------------- compose */

    function boxChip(n) {
        const c = contactForBox(n);
        return { token: n, name: c ? c.name : '', label: c ? `${c.name} · ${n}` : 'PO Box ' + n, contactKey: c ? contactKey(c) : null };
    }
    function bizChip(job) {
        const d = S.directory[job];
        return { token: d.handle, name: d.name, label: `${d.name} (${d.handle})`, biz: true };
    }
    // businesses take messages by chat, never by letter (Config.Letters.businessByChat)
    const bizByChat = () => !(S.cfg.limits && S.cfg.limits.businessByChat === false);
    const toHint = () => (bizByChat() ? 'PO box or contact' : 'PO box, contact or business');
    const chipIsBiz = c => !!(c && (c.biz || (c.token && !U.isBoxNumber(c.token) && handleToJob(c.token))));
    async function offerBizChat(c) {
        const handle = c.biz ? c.token : String(c.token || '').toLowerCase();
        const name = c.name || handle;
        if (await confirmBox('Businesses take messages by chat', `${name} reads its messages in Chats, not by letter. Open a chat with ${handle}? Your letter stays as a draft.`, 'Open chat')) {
            messageTarget(handle);
        }
    }
    function contactChip(c) {
        const raw = String(c.poBox || '').trim();
        if (!raw) return { token: '', name: c.name, label: c.name, contactKey: contactKey(c), missing: true };
        if (U.isBoxNumber(raw)) return { token: raw, name: c.name, label: `${c.name} · ${raw}`, contactKey: contactKey(c) };
        const job = handleToJob(raw);
        return { token: raw.toLowerCase(), name: c.name, label: job ? `${c.name} · ${raw.toLowerCase()}` : c.name, contactKey: contactKey(c), missing: !job };
    }

    function draftEmpty(d) {
        return !d || (!d.to.length && !d.subject.trim() && !U.plainText(d.body).trim());
    }

    function ensureDraft() {
        if (!S.draft) S.draft = { to: [], subject: '', body: '', anon: false, asBiz: S.view === 'b' && canSendBiz() };
        if (S.draft.asBiz && !canSendBiz()) S.draft.asBiz = false;
        return S.draft;
    }

    function suggestionsFor(text) {
        const q = text.trim().toLowerCase();
        const out = [];
        if (!q) return out;
        if (U.isBoxNumber(q)) out.push({ kind: 'box', chip: boxChip(q), title: 'PO Box ' + q, hint: 'Send to this box' });
        S.contacts.slice().sort((a, b) => U.nameCompare(a.name, b.name)).forEach(c => {
            if (c.name.toLowerCase().includes(q) || String(c.poBox || '').toLowerCase().includes(q)) {
                out.push({ kind: 'contact', chip: contactChip(c), title: c.name, hint: c.poBox ? (U.isBoxNumber(c.poBox) ? 'PO Box ' + c.poBox.trim() : c.poBox) : 'no PO box' });
            }
        });
        Object.keys(S.directory).forEach(job => {
            const d = S.directory[job];
            if (!d) return;
            if (String(d.name || '').toLowerCase().includes(q) || String(d.handle || '').includes(q)) {
                out.push({ kind: 'biz', chip: bizChip(job), title: d.name, hint: 'Business · ' + d.handle + (bizByChat() ? ' · by chat' : '') });
            }
        });
        return out.slice(0, 7);
    }

    let suggestState = null; // { list, index, host }

    function closeSuggest() {
        if (suggestState) { suggestState.host.classList.add('hidden'); U.clear(suggestState.host); suggestState = null; return true; }
        return false;
    }

    function renderCompose(view) {
        const d = ensureDraft();
        const sending = !!S.sending;
        setTop({ kicker: 'Correspondence', heading: 'Write a Letter' });

        const chipsHost = h('div', { class: 'chips' });
        const input = h('input', { class: 'chip-input', type: 'text', placeholder: d.to.length ? '' : toHint(), disabled: sending });
        const suggest = h('div', { class: 'suggest hidden' });
        const toField = h('div', { class: 'to-field' }, chipsHost, input, suggest);

        function drawChips() {
            U.clear(chipsHost);
            d.to.forEach((c, i) => chipsHost.appendChild(h('span', { class: 'rchip' + (c.missing ? ' warn' : '') + (c.biz ? ' biz' : '') },
                c.missing ? `${c.label} · no PO box` : c.label,
                sending ? null : h('button', { class: 'x', type: 'button', title: 'Remove', on: { click: () => { d.to.splice(i, 1); drawChips(); } } }, '×'))));
            input.placeholder = d.to.length ? '' : toHint();
            renderRail();
        }
        function addChip(c) {
            if (!c) return;
            if (bizByChat() && chipIsBiz(c)) { offerBizChat(c); return; }
            if (c.token && d.to.some(x => x.token && x.token === c.token)) return;
            if (c.contactKey && d.to.some(x => x.contactKey === c.contactKey)) return;
            d.to.push(c);
            drawChips();
        }
        function drawSuggest() {
            const list = suggestionsFor(input.value);
            U.clear(suggest);
            if (!list.length) { closeSuggest(); return; }
            suggestState = { list, index: suggestState && suggestState.host === suggest ? Math.min(suggestState.index, list.length - 1) : 0, host: suggest };
            list.forEach((s, i) => suggest.appendChild(h('div', {
                class: 'sg' + (i === suggestState.index ? ' on' : '') + ' sg-' + s.kind,
                on: { mousedown: e => { e.preventDefault(); addChip(s.chip); input.value = ''; closeSuggest(); } },
            }, h('span', { class: 'sg-title' }, s.title), h('span', { class: 'sg-hint' }, s.hint))));
            suggest.classList.remove('hidden');
        }
        function commitTyped() {
            const text = input.value.trim().replace(/,$/, '').trim();
            if (suggestState && suggestState.host === suggest && suggestState.list[suggestState.index] && input.value.trim()) {
                addChip(suggestState.list[suggestState.index].chip);
                input.value = ''; closeSuggest();
                return true;
            }
            if (!text) return true;
            if (U.isBoxNumber(text)) { addChip(boxChip(text)); input.value = ''; closeSuggest(); return true; }
            const job = handleToJob(text);
            if (job) { addChip(bizChip(job)); input.value = ''; closeSuggest(); return true; }
            shake(toField);
            toast('No PO box or business goes by that address', true);
            return false;
        }
        input.addEventListener('input', drawSuggest);
        input.addEventListener('blur', () => setTimeout(() => { if (suggestState && suggestState.host === suggest) closeSuggest(); }, 120));
        input.addEventListener('keydown', e => {
            if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
                if (!suggestState) return;
                e.preventDefault();
                const n = suggestState.list.length;
                suggestState.index = (suggestState.index + (e.key === 'ArrowDown' ? 1 : -1) + n) % n;
                drawSuggest();
            } else if (e.key === 'Enter' || e.key === 'Tab' || e.key === ',') {
                if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) return;
                if (!input.value.trim()) { if (e.key === ',') e.preventDefault(); return; }
                e.preventDefault();
                commitTyped();
            } else if (e.key === 'Backspace' && !input.value && d.to.length) {
                d.to.pop(); drawChips();
            }
        });
        drawChips();

        const bookBtn = h('button', { class: 'mini book', type: 'button', title: 'Address book', disabled: sending, on: { click: () => pickContacts(d, drawChips) } }, icon('book'));

        // from block depends on the toggles
        const fromHost = h('div', { class: 'env-who' });
        const headHost = h('div');
        const signHost = h('span');
        function drawFrom() {
            U.clear(fromHost); U.clear(headHost); U.clear(signHost);
            const stack = view.querySelector('.paper-stack');
            if (stack) stack.classList.toggle('biz', !d.anon && !!d.asBiz && canSendBiz());
            if (d.anon) {
                fromHost.appendChild(h('div', { class: 'who-name' }, 'Anonymous'));
                fromHost.appendChild(h('div', { class: 'who-sub' }, 'No reply possible'));
                signHost.textContent = 'Unsigned';
            } else if (d.asBiz && canSendBiz()) {
                const name = S.business.label || S.business.name;
                fromHost.appendChild(h('div', { class: 'who-name' }, name));
                fromHost.appendChild(h('div', { class: 'who-sub' }, 'Business'));
                headHost.appendChild(letterhead(name, S.business.handle));
                signHost.appendChild(bizStamp(name, S.business.handle));
            } else {
                fromHost.appendChild(h('div', { class: 'who-name' }, 'PO Box ' + (S.box || '')));
                fromHost.appendChild(h('div', { class: 'who-sub' }, 'Your own box'));
                signHost.textContent = '— PO Box ' + (S.box || '');
            }
        }
        drawFrom();

        const subject = h('input', { class: 'subject-input', type: 'text', placeholder: 'Subject', maxLength: lim('subject'), value: d.subject, disabled: sending });
        subject.addEventListener('input', () => { d.subject = subject.value.slice(0, lim('subject')); });

        const editor = h('div', { class: 'editor', contentEditable: sending ? 'false' : 'true', spellcheck: true, attrs: { 'data-placeholder': 'Dear friend,' } });
        editor.innerHTML = U.cleanHtml(d.body); // only cleaned markup ever goes back into the editor
        const syncBody = () => { d.body = editor.innerHTML; editor.classList.toggle('empty', !U.plainText(d.body).trim() && !editor.querySelector('hr')); };
        editor.addEventListener('input', syncBody);
        // a reply or forward: the caret starts on the empty line ABOVE the quote, never inside it
        if (d.caretTop && !sending) {
            d.caretTop = false;
            setTimeout(() => {
                const first = editor.firstElementChild;
                if (!first || first.tagName === 'BLOCKQUOTE' || !document.contains(editor)) return;
                editor.focus();
                const r = document.createRange();
                r.setStart(first, 0);
                r.collapse(true);
                const sel = window.getSelection();
                sel.removeAllRanges();
                sel.addRange(r);
            }, 40);
        }
        editor.addEventListener('paste', e => {
            e.preventDefault();
            const text = (e.clipboardData && e.clipboardData.getData('text/plain')) || '';
            document.execCommand('insertText', false, text);
        });
        syncBody();

        const fmt = (cmd, ico, title) => h('button', {
            class: 'mini', type: 'button', title, disabled: sending,
            on: { mousedown: e => e.preventDefault(), click: () => { editor.focus(); document.execCommand(cmd, false, null); syncBody(); } },
        }, icon(ico));
        const toolbar = h('div', { class: 'fmt' },
            fmt('bold', 'bold', 'Bold'), fmt('italic', 'italic', 'Italic'), fmt('underline', 'underline', 'Underline'),
            fmt('insertUnorderedList', 'list', 'Bulleted list'), fmt('insertHorizontalRule', 'rule', 'Divider'),
            sending ? null : EMOJI.buttonForEditor(editor, syncBody));

        const toggles = h('div', { class: 'compose-opts' });
        const toggle = (label, hint, value, fn) => {
            const cb = h('input', { type: 'checkbox', checked: value, disabled: sending });
            cb.addEventListener('change', () => fn(cb.checked));
            return h('label', { class: 'toggle' }, cb, h('span', { class: 'tg-ui' }), h('span', { class: 'tg-text' }, h('b', null, label), hint ? h('small', null, hint) : null));
        };
        toggles.appendChild(toggle('Anonymous', 'your name and box are left off; the reader cannot reply', d.anon, v => { d.anon = v; drawFrom(); }));
        if (canSendBiz()) {
            toggles.appendChild(toggle('Sign as ' + S.business.name, 'the letter comes from the business box ' + S.business.handle, d.asBiz, v => { d.asBiz = v; drawFrom(); }));
        }

        const sendBtn = h('button', { class: 'btn primary', type: 'button', disabled: sending, on: { click: () => sendDraft(commitTyped, { toField, subject, editor }) } },
            icon('send'), sending ? 'Sending…' : 'Seal & Send');
        const discard = h('button', {
            class: 'btn', type: 'button', disabled: sending,
            on: {
                click: async () => {
                    if (!draftEmpty(d) && !await confirmBox('Discard letter', 'Discard this letter? What you wrote will be lost.', 'Discard', true)) return;
                    S.draft = null;
                    go({ page: 'list', folder: 'Inbox' });
                },
            },
        }, 'Discard');

        view.appendChild(h('div', { class: 'compose' },
            toggles,
            h('div', { class: 'paper-stack' + (!d.anon && d.asBiz && canSendBiz() ? ' biz' : '') },
                envelope(fromHost, h('div', { class: 'to-line' }, toField, bookBtn), new Date().toISOString()),
                sheet({
                    letterhead: headHost,
                    date: U.fullDate(new Date().toISOString()),
                    subject,
                    body: h('div', { class: 'editor-wrap' }, toolbar, editor),
                    signoff: signHost,
                    sending,
                })),
            h('div', { class: 'compose-foot' }, discard, sendBtn)));

        view.onkeydown = e => {
            if (e.key === 'Enter' && (e.ctrlKey || e.metaKey) && !S.sending) { e.preventDefault(); sendDraft(commitTyped, { toField, subject, editor }); }
        };
    }

    function pickContacts(d, redraw) {
        const chosen = new Set(d.to.filter(c => c.contactKey).map(c => c.contactKey));
        const search = h('input', { class: 'field', type: 'search', placeholder: 'Search contacts' });
        const list = h('div', { class: 'pick-list tall' });
        const draw = () => {
            U.clear(list);
            const q = search.value.trim().toLowerCase();
            const items = S.contacts.filter(c => !q || c.name.toLowerCase().includes(q) || String(c.poBox || '').toLowerCase().includes(q))
                .sort((a, b) => U.nameCompare(a.name, b.name));
            if (!items.length) list.appendChild(h('div', { class: 'empty small' }, S.contacts.length ? 'Nothing matches' : 'Your address book is empty'));
            items.forEach(c => {
                const key = contactKey(c);
                const cb = h('input', { type: 'checkbox', checked: chosen.has(key) });
                cb.addEventListener('change', () => { if (cb.checked) chosen.add(key); else chosen.delete(key); });
                list.appendChild(h('label', { class: 'pick' }, cb, h('span', { class: 'pick-name' }, c.name), h('small', null, c.poBox || 'no PO box')));
            });
        };
        search.addEventListener('input', draw);
        draw();
        modal({
            title: 'Address book', wide: true, body: [search, list],
            actions: [{ label: 'Cancel' }, {
                label: 'Add to letter', kind: 'primary', onClick: () => {
                    const skipped = [];
                    d.to = d.to.filter(c => !c.contactKey || chosen.has(c.contactKey));
                    chosen.forEach(key => {
                        if (d.to.some(c => c.contactKey === key)) return;
                        const c = findContact(key);
                        if (!c) return;
                        const chip = contactChip(c);
                        if (chip.token && d.to.some(x => x.token === chip.token)) return;
                        if (bizByChat() && chipIsBiz(chip)) { skipped.push(c.name); return; }
                        d.to.push(chip);
                    });
                    if (skipped.length) toast(`Businesses take messages by chat, so ${skipped.join(', ')} ${skipped.length === 1 ? 'was' : 'were'} left off`, true);
                    redraw();
                },
            }],
        });
    }

    function sendDraft(commitTyped, fields) {
        if (S.sending) return;
        const d = S.draft;
        if (!d) return;
        if (!commitTyped()) return;
        const text = U.plainText(fields.editor.innerHTML).trim();
        const missing = [];
        if (!d.to.length) missing.push(fields.toField);
        if (!d.subject.trim()) missing.push(fields.subject);
        if (!text) missing.push(fields.editor);
        if (missing.length) {
            missing.forEach(shake);
            return toast('A letter needs someone to go to, a subject and a few words', true);
        }
        if (bizByChat() && d.to.some(chipIsBiz)) {
            const biz = d.to.find(chipIsBiz);
            shake(fields.toField);
            return offerBizChat(biz);
        }
        const noBox = d.to.filter(c => c.missing || !c.token);
        if (noBox.length) {
            return toast(`No PO box saved for ${noBox.map(c => c.name || c.label).join(', ')}`, true);
        }
        const seen = new Set(), to = [], names = [];
        d.to.forEach(c => {
            if (seen.has(c.token)) return;
            seen.add(c.token);
            to.push(c.token);
            names.push(c.name || c.label);
        });
        const max = Number(S.cfg.limits.maxRecipients) || 20;
        if (to.length > max) return toast(`A letter can go to ${max} people at most`, true);
        const body = U.cleanHtml(fields.editor.innerHTML);
        if (U.utf8Length(body) > (Number(S.cfg.limits.maxBody) || 20000)) return toast('That letter is too long to send', true);

        const req = ++S.reqSeq;
        S.sending = {
            req,
            timer: setTimeout(() => {
                if (!S.sending || S.sending.req !== req) return;
                S.sending = null;
                toast('No word from the post office. Your letter is still here.', true);
                if (S.open && S.route.page === 'compose') render();
            }, SEND_TIMEOUT),
        };
        d.body = body;
        post('send', { to, names, subject: d.subject.slice(0, lim('subject')), body, anon: d.anon === true, asBusiness: d.asBiz === true && canSendBiz(), req });
        if (S.route.page === 'compose') renderView();
    }

    function onSendResult(req, ok) {
        if (!S.sending || S.sending.req !== Number(req)) return;
        clearTimeout(S.sending.timer);
        S.sending = null;
        if (ok) {
            const wasBiz = S.draft && S.draft.asBiz;
            S.draft = null;
            toast('Sealed and sent');
            if (S.open && S.route.page === 'compose') renderView();
            setTimeout(() => {
                if (!S.open || S.route.page !== 'compose') return;
                S.view = wasBiz && bizBox() ? 'b' : 'p';
                go({ page: 'list', folder: 'Sent' });
            }, 700);
        } else if (S.open && S.route.page === 'compose') {
            renderView();
        }
    }

    /* ---------------------------------------------------------------- address book */

    function boxLabel(c) {
        const raw = String(c.poBox || '').trim();
        if (!raw) return 'No PO box saved';
        if (U.isBoxNumber(raw)) return 'PO Box ' + raw;
        return 'Business · ' + raw.toLowerCase();
    }

    function renderContacts(view) {
        const f = S.contactFilter;
        const search = h('input', { class: 'field search', type: 'search', placeholder: 'Search names, boxes and notes', value: f.search });
        const list = h('div', { class: 'contact-list' });
        setTop({
            kicker: 'People', heading: 'Address Book',
            tools: [
                h('button', { class: 'chip' + (f.starred ? ' on' : ''), type: 'button', on: { click: () => { f.starred = !f.starred; renderView(); } } }, icon('star'), 'Starred'),
                h('button', { class: 'chip' + (f.selecting ? ' on' : ''), type: 'button', on: { click: () => { f.selecting = !f.selecting; f.selected.clear(); renderView(); } } }, 'Select'),
                h('button', { class: 'btn primary small', type: 'button', on: { click: () => go({ page: 'contactForm', key: null }) } }, icon('plus'), 'New'),
            ],
        });
        const bulk = h('div', { class: 'bulk' + (f.selecting && f.selected.size ? '' : ' hidden') },
            h('span', { class: 'bulk-count' }, `${f.selected.size} selected`),
            h('button', {
                class: 'btn small danger', type: 'button', on: {
                    click: async () => {
                        const keys = [...f.selected];
                        if (!keys.length) return;
                        const targets = keys.map(findContact).filter(Boolean);
                        if (targets.some(c => !c.id)) return toast('A contact is still being saved. Try again in a moment.', true);
                        if (!await confirmBox('Delete contacts', `Delete ${targets.length} contact(s) from your address book?`, 'Delete', true)) return;
                        removeContacts(targets);
                        f.selected.clear();
                        renderView();
                    },
                },
            }, icon('trash'), 'Delete'));
        search.addEventListener('input', () => { f.search = search.value; draw(); });
        view.appendChild(h('div', { class: 'contacts' }, h('div', { class: 'list-tools' }, h('span', { class: 'search-wrap' }, icon('search'), search)), bulk, list));

        function draw() {
            U.clear(list);
            const q = f.search.trim().toLowerCase();
            let items = S.contacts.filter(c => !q || c.name.toLowerCase().includes(q) || String(c.poBox || '').toLowerCase().includes(q) || String(c.notes || '').toLowerCase().includes(q));
            if (f.starred) items = items.filter(isFav);
            items.sort((a, b) => U.nameCompare(a.name, b.name));
            if (!items.length) {
                list.appendChild(h('div', { class: 'empty' }, h('p', null, S.contacts.length ? 'Nothing matches' : 'No contacts yet'),
                    S.contacts.length ? null : h('button', { class: 'btn primary', type: 'button', on: { click: () => go({ page: 'contactForm', key: null }) } }, 'Add a contact')));
                drawBlocked();
                return;
            }
            const starred = items.filter(isFav);
            const rest = items.filter(c => !isFav(c));
            const group = (title, arr) => {
                if (!arr.length) return;
                list.appendChild(h('div', { class: 'letter-head' }, title));
                arr.forEach(c => list.appendChild(contactRow(c)));
            };
            group('Starred', starred);
            const buckets = new Map();
            rest.forEach(c => {
                const ch = (c.name.trim()[0] || '#').toUpperCase();
                const key = /\p{L}/u.test(ch) ? ch : '#';
                if (!buckets.has(key)) buckets.set(key, []);
                buckets.get(key).push(c);
            });
            const keys = [...buckets.keys()].sort((a, b) => (a === '#') - (b === '#') || a.localeCompare(b));
            keys.forEach(k => group(k, buckets.get(k)));
            drawBlocked();
        }

        // boxes you blocked: their chat messages are hidden from you
        function drawBlocked() {
            if (!S.chat.blocks.length || f.search.trim() || f.starred) return;
            list.appendChild(h('div', { class: 'letter-head blocked-list' }, 'Blocked'));
            S.chat.blocks.slice().sort((a, b) => a - b).forEach(b => list.appendChild(h('div', { class: 'row contact' },
                h('div', { class: 'avatar' }, '×'),
                h('div', { class: 'row-main' }, h('div', { class: 'row-from' }, boxName(b) + (isSavedBox(b) ? ` (${b})` : '')), h('div', { class: 'row-preview' }, 'Their chat messages are hidden from you')),
                h('button', { class: 'btn small', type: 'button', on: { click: e => { e.stopPropagation(); setBlock(b, false); } } }, 'Unblock'))));
        }

        function contactRow(c) {
            const key = contactKey(c);
            const kids = [];
            if (f.selecting) {
                const cb = h('input', { type: 'checkbox', checked: f.selected.has(key) });
                cb.addEventListener('click', e => e.stopPropagation());
                cb.addEventListener('change', () => { if (cb.checked) f.selected.add(key); else f.selected.delete(key); renderView(); });
                kids.push(h('label', { class: 'chk' }, cb));
            }
            kids.push(h('div', { class: 'avatar' }, U.initials(c.name)));
            kids.push(h('div', { class: 'row-main' }, h('div', { class: 'row-from' }, c.name, isFav(c) ? icon('star', 'star-on') : null), h('div', { class: 'row-preview' }, boxLabel(c))));
            if (!c.id) kids.push(h('span', { class: 'tag' }, 'saving'));
            return h('div', { class: 'row contact', on: { click: () => (f.selecting ? null : go({ page: 'contact', key })) } }, kids);
        }
        draw();
    }

    function removeContacts(list) {
        const ids = list.filter(c => c.id).map(c => c.id);
        S.contacts = S.contacts.filter(c => !list.includes(c));
        S.look.favorites = S.look.favorites.filter(id => !ids.map(String).includes(id));
        saveLook();
        if (ids.length) post('contacts', { del: ids });
    }

    function renderContact(view) {
        const c = findContact(S.route.key);
        if (!c) return go({ page: 'contacts' });
        const fav = isFav(c);
        setTop({
            kicker: 'Address Book', heading: c.name, back: () => go({ page: 'contacts' }),
            tools: [
                c.id ? h('button', {
                    class: 'chip' + (fav ? ' on' : ''), type: 'button', on: {
                        click: () => {
                            const id = String(c.id);
                            S.look.favorites = fav ? S.look.favorites.filter(x => x !== id) : S.look.favorites.concat(id).slice(-500);
                            saveLook(); renderView();
                        },
                    },
                }, icon('star'), fav ? 'Unstar' : 'Star') : null,
                h('button', { class: 'btn small', type: 'button', on: { click: () => go({ page: 'contactForm', key: contactKey(c) }) } }, icon('edit'), 'Edit'),
                h('button', {
                    class: 'btn small danger', type: 'button', on: {
                        click: async () => {
                            if (!c.id) return toast('That contact is still being saved. Try again in a moment.', true);
                            if (!await confirmBox('Delete contact', `Delete ${c.name} from your address book?`, 'Delete', true)) return;
                            removeContacts([c]);
                            go({ page: 'contacts' });
                        },
                    },
                }, icon('trash'), 'Delete'),
            ],
        });
        const raw = String(c.poBox || '').trim();
        const numeric = U.isBoxNumber(raw);
        const fromCount = numeric ? S.letters.p.filter(l => !l.anon && l.from === raw && !isSent(l) && l.folder !== 'Trash').length : 0;
        const first = c.name.trim().split(/\s+/)[0] || c.name;
        view.appendChild(h('div', { class: 'card' },
            h('div', { class: 'monogram' }, U.initials(c.name)),
            h('div', { class: 'card-name' }, c.name),
            h('div', { class: 'card-box' }, boxLabel(c)),
            raw ? null : h('div', { class: 'notice' }, 'Add a PO box to this contact before writing to them.'),
            h('div', { class: 'card-notes' + (c.notes ? '' : ' muted') }, c.notes || 'Nothing written down'),
            h('div', { class: 'card-actions' },
                h('button', {
                    class: 'btn primary', type: 'button', on: {
                        click: () => {
                            S.draft = { to: [contactChip(c)], subject: '', body: '', anon: false, asBiz: false };
                            go({ page: 'compose' });
                        },
                    },
                }, icon('pen'), 'Write a letter'),
                raw && (numeric || handleToJob(raw)) ? h('button', {
                    class: 'btn', type: 'button', on: { click: () => messageTarget(raw) },
                }, icon('chat'), 'Message') : null,
                numeric ? h('button', {
                    class: 'btn' + (blocked(raw) ? '' : ' danger'), type: 'button', on: { click: () => toggleBlock(Number(raw)) },
                }, blocked(raw) ? 'Unblock' : 'Block') : null,
                numeric ? h('button', {
                    class: 'btn', type: 'button',
                    on: { click: () => { S.view = 'p'; go({ page: 'list', folder: 'Inbox', from: raw, contactKey: contactKey(c) }); } },
                }, `Letters from ${first} (${fromCount})`) : null)));
    }

    function contactBoxError(v) {
        if (!v) return null;
        if (U.isBoxNumber(v)) return null;
        if (handleToJob(v)) return null;
        return 'That is not a PO box number or a known business handle';
    }

    function renderContactForm(view) {
        const r = S.route;
        const c = r.key ? findContact(r.key) : null;
        if (r.key && !c) return go({ page: 'contacts' });
        const pre = r.prefill || {};
        const backTo = () => go(r.back || (c ? { page: 'contact', key: contactKey(c) } : { page: 'contacts' }));
        setTop({ kicker: 'Address Book', heading: c ? 'Edit contact' : 'New contact', back: backTo });
        const name = h('input', { class: 'field', type: 'text', maxLength: lim('contactName'), value: c ? c.name : (pre.name || '') });
        const box = h('input', { class: 'field', type: 'text', maxLength: lim('contactBox'), value: c ? c.poBox : (pre.poBox || '') });
        const notes = h('textarea', { class: 'field', maxLength: lim('contactNotes'), value: c ? c.notes : '' });
        notes.value = c ? c.notes : '';
        const save = () => {
            const n = name.value.trim(), b = box.value.trim(), t = notes.value;
            if (!n) { shake(name); return toast('A contact needs a name', true); }
            const err = contactBoxError(b);
            if (err) { shake(box); return toast(err, true); }
            if (c) {
                if (!c.id) return toast('That contact is still being saved. Try again in a moment.', true);
                c.name = n; c.poBox = b; c.notes = t;
                post('contacts', { edit: [{ id: c.id, name: n, poBox: b, notes: t }] });
                toast('Contact saved');
                go({ page: 'contact', key: contactKey(c) });
            } else {
                const ref = 'c' + (++S.refSeq);
                const nc = { id: null, ref, name: n, poBox: b, notes: t };
                S.contacts.push(nc);
                busy(true);
                post('contacts', { add: [{ ref, name: n, poBox: b, notes: t }] });
                go({ page: 'contact', key: ref });
            }
        };
        view.appendChild(h('div', { class: 'form' },
            h('label', { class: 'lbl' }, h('span', null, 'Name'), name),
            h('label', { class: 'lbl' }, h('span', null, 'PO box or business handle'), box),
            h('label', { class: 'lbl' }, h('span', null, 'Notes'), notes),
            h('div', { class: 'form-actions' },
                h('button', { class: 'btn', type: 'button', on: { click: backTo } }, 'Cancel'),
                h('button', { class: 'btn primary', type: 'button', on: { click: save } }, 'Save'))));
        setTimeout(() => name.focus(), 30);
    }

    function onContactAdded(ref, id, server) {
        busy(false);
        const c = S.contacts.find(x => x.ref === ref);
        if (!id) {
            // refused (address book full): the page does not keep it
            if (c) {
                S.contacts = S.contacts.filter(x => x !== c);
                if (S.route.page === 'contact' && S.route.key === ref) S.route = { page: 'contacts' };
            }
        } else if (c) {
            c.id = id; delete c.ref;
            if (S.route.page === 'contact' && S.route.key === ref) S.route.key = contactKey(c);
            toast(`${c.name} added to your address book`);
        } else if (server && !S.contacts.some(x => x.id === id)) {
            S.contacts.push({ id, name: String(server.name || ''), poBox: String(server.poBox || ''), notes: String(server.notes || '') });
        }
        if (S.open) render();
    }

    /* ---------------------------------------------------------------- chats */

    const chatOp = (op, data) => post('chat', { op, data: data || {} });
    const meBox = () => Number(S.box) || 0;
    const CHAT_MIN = 2;

    /* names: only box numbers, or the name the viewer saved for that box */
    function boxName(box) {
        box = Number(box);
        if (!box) return 'Someone';
        if (box === meBox()) return 'You';
        const c = contactForBox(String(box));
        return c ? c.name : 'PO Box ' + box;
    }
    const isSavedBox = box => !!contactForBox(String(box));
    const blocked = box => S.chat.blocks.includes(Number(box));
    const arr = v => (Array.isArray(v) ? v : []);

    function normReacts(list) {
        return arr(list).map(r => ({
            e: String(r.e || ''), n: Number(r.n) || 0, mine: !!r.mine, biz: !!r.biz, by: arr(r.by).map(Number).filter(Boolean),
        })).filter(r => r.e && r.n > 0);
    }
    function normMsg(m) {
        return {
            id: Number(m.id) || 0, box: m.box !== undefined && m.box !== null ? Number(m.box) : null,
            asJob: m.asJob ? String(m.asJob) : null, text: String(m.text || ''), date: String(m.date || ''), hidden: !!m.hidden,
            parentId: Number(m.parentId) || 0, replies: Number(m.replies) || 0, lastReply: Number(m.lastReply) || 0,
            lastReplyDate: m.lastReplyDate ? String(m.lastReplyDate) : '', reactions: normReacts(m.reactions),
        };
    }
    function normInfo(c) {
        return {
            id: Number(c.id) || 0, kind: String(c.kind || 'group'), title: String(c.title || ''), owner: Number(c.owner) || 0,
            handled: !!c.handled, bizRead: Number(c.bizRead) || 0, muted: !!c.muted, pinned: !!c.pinned,
            job: c.job ? String(c.job) : null, handle: c.handle ? String(c.handle) : null, name: c.name ? String(c.name) : null,
            members: arr(c.members).map(x => ({ box: Number(x.box) || 0, lastRead: Number(x.lastRead) || 0 })),
        };
    }
    function normConv(c) {
        const o = normInfo(c);
        o.unread = Number(c.unread) || 0;
        o.last = c.last ? normMsg(c.last) : null;
        return o;
    }

    function otherBox(c) { const m = c.members.find(x => x.box !== meBox()); return m ? m.box : null; }
    function customerBox(c) { const m = c.members[0]; return m ? m.box : null; }
    function bizName(c) { return c.name || (c.job && S.directory[c.job] && S.directory[c.job].name) || c.handle || 'Business'; }

    function convTitle(c, view) {
        if (c.kind === 'group') return c.title || 'Group';
        if (c.kind === 'business') return view === 'b' ? boxName(customerBox(c)) : bizName(c);
        return boxName(otherBox(c));
    }
    function convSub(c, view) {
        if (c.kind === 'group') return `${c.members.length} member${c.members.length === 1 ? '' : 's'} · group`;
        if (c.kind === 'business') {
            if (view !== 'b') return 'Business' + (c.handle ? ' · ' + c.handle : '');
            const b = customerBox(c);
            return `PO Box ${b}${isSavedBox(b) ? ' · saved as ' + boxName(b) : ''} · ${c.handled ? 'handled' : 'open'}`;
        }
        const b = otherBox(c);
        if (!b) return '';
        return isSavedBox(b) ? `PO Box ${b} · saved contact` : `PO Box ${b} · not in your address book`;
    }
    function convAvatar(c, view) {
        if (c.kind === 'group') return h('div', { class: 'ch-av grp' }, U.initials(c.title));
        if (c.kind === 'business' && view !== 'b') return h('div', { class: 'ch-av biz' }, U.initials(bizName(c)));
        const b = c.kind === 'business' ? customerBox(c) : otherBox(c);
        if (b && isSavedBox(b)) return h('div', { class: 'ch-av' }, U.initials(boxName(b)));
        return h('div', { class: 'ch-av box' }, b ? String(b) : '?');
    }

    // on the business side your own messages are the ones written for the business
    const isOwn = (m, view) => (view === 'b' ? !!m.asJob : (!m.asJob && m.box === meBox()));

    function authorLabel(m, c, view) {
        if (view === 'b') return m.asJob ? (m.box ? 'Sent by ' + boxName(m.box) : bizName(c)) : boxName(m.box);
        return m.asJob ? bizName(c) : boxName(m.box);
    }

    // the mark on your own messages: sealed (on its way), delivered, opened
    function markOf(m, t) {
        if (m.pending) return { cls: 'sealed', text: 'Sealed' };
        const info = t.info;
        if (info.kind === 'business') {
            const read = t.view === 'b' ? ((info.members[0] || {}).lastRead || 0) : info.bizRead;
            return read >= m.id ? { cls: 'opened', text: 'Opened' } : { cls: 'delivered', text: 'Delivered' };
        }
        const others = info.members.filter(x => x.box !== meBox());
        const n = others.filter(x => x.lastRead >= m.id).length;
        if (!n) return { cls: 'delivered', text: 'Delivered' };
        if (info.kind === 'direct' || n >= others.length) return { cls: 'opened', text: info.kind === 'direct' ? 'Opened' : 'Opened by all' };
        return { cls: 'opened', text: `Opened by ${n} of ${others.length}` };
    }

    function previewOf(c, view) {
        const m = c.last;
        if (!m) return c.kind === 'group' ? 'Nothing said yet' : 'No messages yet';
        if (m.hidden) return 'A message from a box you blocked';
        const who = isOwn(m, view) ? 'You: ' : (c.kind === 'group' ? boxName(m.box) + ': ' : '');
        return (m.parentId ? '↳ ' : '') + who + m.text.replace(/\s+/g, ' ');
    }

    function recountBadge(view) {
        const st = S.chat[view];
        st.badge = st.list.reduce((n, c) => n + (c.muted ? 0 : (c.unread || 0)), 0);
    }
    const findConv = (view, id) => S.chat[view].list.find(c => c.id === id) || null;
    const isOpen = (view, id) => !!(S.chat.open && S.chat.open.view === view && S.chat.open.id === id);
    const viewingChat = (view, id) => S.open && S.route.page === 'chats' && S.view === view && isOpen(view, id);
    const threadFor = (view, id) => (S.chat.thread && S.chat.thread.view === view && S.chat.thread.info.id === id ? S.chat.thread : null);
    /** Is a reply thread open in this chat (and, given a parent id, under that message)? */
    const sideOn = (view, id, pid) => !!(S.chat.side && S.chat.side.view === view && S.chat.side.convId === id && (pid === undefined || S.chat.side.parentId === pid));
    const draftKey = (view, id, pid) => view + ':' + id + (pid ? ':t' + pid : '');

    /** Run fn on every copy of one message the page holds: the main feed, the thread's top message and its replies. */
    function eachCopy(view, id, mid, fn) {
        if (!mid) return;
        const t = threadFor(view, id);
        if (t) t.messages.forEach(m => { if (m.id === mid) fn(m); });
        if (sideOn(view, id)) {
            const sd = S.chat.side;
            if (sd.parent && sd.parent.id === mid) fn(sd.parent);
            sd.replies.forEach(m => { if (m.id === mid) fn(m); });
        }
    }

    /* reactions */

    function toggleReact(v, info, mid, e) {
        let had = false;
        eachCopy(v, info.id, mid, m => { const r = m.reactions.find(x => x.e === e); if (r && r.mine) had = true; });
        const on = !had;
        // shown at once; the server's answer then sets the real counts for everyone
        eachCopy(v, info.id, mid, m => {
            let r = m.reactions.find(x => x.e === e);
            if (on) {
                if (!r) { r = { e, n: 0, mine: false, biz: false, by: [] }; m.reactions.push(r); }
                r.n += 1; r.mine = true;
                if (v === 'b') r.biz = true; else r.by.push(meBox());
            } else if (r) {
                r.n -= 1; r.mine = false;
                if (v === 'b') r.biz = false; else r.by = r.by.filter(b => b !== meBox());
                if (r.n <= 0) m.reactions = m.reactions.filter(x => x !== r);
            }
        });
        chatOp('react', { id: info.id, view: v, msg: mid, emoji: e, on });
        redrawChats();
    }

    function reactWho(r, info) {
        const names = r.by.map(b => boxName(b));
        if (r.biz) names.unshift(info.kind === 'business' ? bizName(info) : 'The business');
        return names.length ? names.join(', ') : r.e;
    }

    /** One message, in the main feed or in a reply thread (inSide). */
    function msgNode(m, t, v, inSide) {
        const info = t.info;
        const own = isOwn(m, v);
        const showAuthor = info.kind === 'group' ? !own : (v === 'b' && !!m.asJob);
        const mark = own ? markOf(m, t) : null;
        const live = !!m.id && !m.pending && !m.hidden;
        const acts = [];
        if (live && S.chat.threads && S.cfg.reactions.length) {
            const b = h('button', { class: 'ch-act', type: 'button', title: 'React' }, h('span', { class: 'emo' }, '🙂'), h('span', { class: 'ch-act-plus' }, '+'));
            b.addEventListener('click', () => EMOJI.quick(b, S.cfg.reactions, e => toggleReact(v, info, m.id, e)));
            acts.push(b);
        }
        if (live && !inSide && S.chat.threads) {
            acts.push(h('button', { class: 'ch-act', type: 'button', title: 'Reply in a thread', on: { click: () => openSide(v, info.id, m) } }, icon('reply')));
        }
        const reacts = m.reactions.length ? h('div', { class: 'ch-reacts' }, m.reactions.map(r => h('button', {
            class: 'ch-react' + (r.mine ? ' mine' : ''), type: 'button', title: reactWho(r, info), disabled: !live,
            on: { click: () => toggleReact(v, info, m.id, r.e) },
        }, h('span', { class: 'emo' }, r.e), h('span', { class: 'n' }, String(r.n))))) : null;
        let thread = null;
        if (!inSide && m.replies > 0) {
            const seen = Math.max(S.chat.seen[v + ':' + info.id] || 0, m.seenReply || 0);
            const isNew = m.lastReply > seen;
            thread = h('button', {
                class: 'ch-thread' + (isNew ? ' new' : '') + (sideOn(v, info.id, m.id) ? ' on' : ''), type: 'button',
                title: 'Open the thread', on: { click: () => openSide(v, info.id, m) },
            }, icon('chat'), `${m.replies} ${m.replies === 1 ? 'reply' : 'replies'}`,
            m.lastReplyDate ? h('span', { class: 'ch-thread-when' }, 'last ' + U.shortDate(m.lastReplyDate)) : null);
        }
        const node = h('div', { class: 'ch-msg' + (own ? ' own' : '') + (m.fresh ? ' fresh' : '') + (!inSide && sideOn(v, info.id, m.id) ? ' threaded' : '') },
            showAuthor ? h('div', { class: 'ch-author' }, authorLabel(m, info, v)) : null,
            h('div', { class: 'ch-line' },
                h('div', { class: 'ch-bubble' + (m.hidden ? ' hidden-msg' : '') }, m.hidden ? 'A message from a box you blocked' : m.text),
                acts.length ? h('div', { class: 'ch-acts' }, acts) : null),
            reacts, thread,
            // a thread has no day separators: an older reply also says which day
            h('div', { class: 'ch-stamp' }, (inSide && m.date && U.dayKey(m.date) !== U.dayKey(new Date().toISOString()) ? U.shortDate(m.date) + ' ' : '') + (U.clock(m.date) || 'now'), mark ? [' · ', h('span', { class: 'ch-seal ' + mark.cls }), ' ' + mark.text] : null));
        m.fresh = false;
        return node;
    }

    /* reply threads */

    function openSide(v, convId, m) {
        EMOJI.close();
        if (sideOn(v, convId, m.id)) return closeSide();
        S.chat.side = { view: v, convId, parentId: m.id, parent: Object.assign({}, m, { reactions: m.reactions.slice() }), replies: [], hasMore: false, loading: true };
        m.seenReply = m.lastReply || 0;
        chatOp('replies', { id: convId, view: v, parent: m.id });
        redrawChats();
        setTimeout(() => { const n = document.querySelector('.ch-tinput'); if (n) n.focus(); }, 0);
    }

    function closeSide() {
        S.chat.side = null;
        EMOJI.close();
        redrawChats();
    }

    /** The typing box with its emoji button; parentId set = it writes into that reply thread. */
    function composer(v, info, parentId) {
        const k = draftKey(v, info.id, parentId);
        const max = lim('groupMessage');
        const input = h('textarea', {
            class: 'ch-input' + (parentId ? ' ch-tinput' : ''), maxLength: max, data: { k: parentId ? 'ch-tinput' : 'ch-input' },
            placeholder: parentId ? 'Reply in the thread' : (info.kind === 'group' ? 'Write to the group' : 'Write a message'),
        });
        input.value = S.chat.drafts[k] || '';
        const count = h('span', null, `${input.value.length} / ${max}`);
        const sendBtn = h('button', { class: 'btn primary', type: 'button', title: 'Send', disabled: !input.value.trim(), on: { click: () => sendChat(v, info, input, parentId) } }, icon('send'), parentId ? null : 'Send');
        const grow = () => { input.style.height = 'auto'; input.style.height = Math.min(120, Math.max(40, input.scrollHeight)) + 'px'; };
        input.addEventListener('input', () => {
            S.chat.drafts[k] = input.value;
            count.textContent = `${input.value.length} / ${max}`;
            sendBtn.disabled = !input.value.trim();
            grow();
            const now = Date.now();
            if (input.value.trim() && now - S.chat.lastTyping > 3000) { S.chat.lastTyping = now; chatOp('typing', { id: info.id, view: v }); }
        });
        input.addEventListener('keydown', e => {
            if (e.key !== 'Enter') return;
            const sends = S.look.enterSends ? !e.shiftKey : (e.ctrlKey || e.metaKey);
            if (sends) { e.preventDefault(); sendChat(v, info, input, parentId); }
        });
        setTimeout(grow, 0);
        return h('div', { class: 'ch-compose' + (parentId ? ' side' : '') },
            v === 'b' ? h('div', { class: 'ch-as' }, `Replying as ${S.business.name}${S.business.handle ? ' (' + S.business.handle + ')' : ''}`) : null,
            h('div', { class: 'ch-send-row' }, input, EMOJI.buttonFor(input), sendBtn),
            h('div', { class: 'ch-hint' }, h('span', null, S.look.enterSends ? 'Enter sends · Shift+Enter for a new line' : 'Ctrl+Enter sends'), count));
    }

    function renderSide(v, t) {
        const sd = S.chat.side;
        const info = t.info;
        const side = h('aside', { class: 'ch-side' });
        side.appendChild(h('div', { class: 'ch-head ch-side-head' },
            h('button', { class: 'mini ch-back', type: 'button', title: 'Back to the chat', on: { click: closeSide } }, icon('back')),
            h('div', { class: 'ch-titles' }, h('div', { class: 'ch-title' }, 'Thread'), h('div', { class: 'ch-sub' }, convTitle(info, v))),
            h('button', { class: 'mini', type: 'button', title: 'Close the thread', on: { click: closeSide } }, icon('close'))));
        const feed = h('div', { class: 'ch-tfeed' });
        feed.appendChild(msgNode(sd.parent, t, v, true));
        const n = Math.max(sd.parent.replies || 0, sd.replies.filter(x => x.id).length);
        feed.appendChild(h('div', { class: 'ch-tsep' }, sd.loading ? 'Fetching replies…' : (n ? `${n} ${n === 1 ? 'reply' : 'replies'}` : 'No replies yet. Start the thread.')));
        if (sd.hasMore) {
            feed.appendChild(h('button', {
                class: 'ch-older', type: 'button',
                on: { click: e => { e.currentTarget.disabled = true; const first = sd.replies.find(x => x.id); chatOp('replies', { id: info.id, view: v, parent: sd.parentId, before: first ? first.id : 0 }); } },
            }, 'Load older replies'));
        }
        sd.replies.forEach(m => feed.appendChild(msgNode(m, t, v, true)));
        side.appendChild(feed);
        const other = info.kind === 'direct' ? otherBox(info) : null;
        if (!(v === 'p' && other && blocked(other))) side.appendChild(composer(v, info, sd.parentId));
        return side;
    }

    /** Redraw the chat page, keeping the typing box focused and the feed where it was. */
    function redrawChats() {
        if (!S.open) return;
        const a = document.activeElement;
        const key = a && a.dataset ? a.dataset.k : null;
        const sel = key && typeof a.selectionStart === 'number' ? [a.selectionStart, a.selectionEnd] : null;
        // the main feed and the reply thread each keep their place (or stay at the bottom)
        const keep = ['.ch-feed', '.ch-tfeed'].map(sel => {
            const f = document.querySelector(sel);
            return { sel, fromBottom: f ? f.scrollHeight - f.scrollTop : 0, atBottom: f ? f.scrollHeight - f.scrollTop - f.clientHeight < 60 : true };
        });
        renderRail();
        if (S.route.page !== 'chats') return;
        renderView();
        keep.forEach(k => {
            const nf = document.querySelector(k.sel);
            if (nf) nf.scrollTop = k.atBottom ? nf.scrollHeight : nf.scrollHeight - k.fromBottom;
        });
        if (key) {
            const n = document.querySelector(`[data-k="${key}"]`);
            if (n) { n.focus(); if (sel && n.setSelectionRange) n.setSelectionRange(sel[0], sel[1]); }
        }
    }

    function openChat(view, id) {
        S.view = view;
        S.chat.open = { id, view };
        S.chat.thread = null;
        S.chat.side = null;
        EMOJI.close();
        const c = findConv(view, id);
        if (c && c.unread) { c.unread = 0; recountBadge(view); renderHud(); }
        chatOp('open', { id, view });
        go({ page: 'chats' });
    }

    function drawTyping() {
        const el = document.querySelector('.ch-writing');
        if (!el || !S.chat.open) return;
        const t = S.chat.typing[S.chat.open.view + ':' + S.chat.open.id];
        el.textContent = t && t.until > Date.now() ? `${t.label} is writing…` : '';
    }

    function onChat(d) {
        const view = d.view === 'b' ? 'b' : 'p';
        const st = S.chat[view];
        const id = Number(d.id) || 0;
        switch (d.type) {
            case 'list': {
                st.list = arr(d.list).map(normConv);
                if (Array.isArray(d.blocks)) S.chat.blocks = d.blocks.map(Number);
                if (S.chat.open && S.chat.open.view === view && viewingChat(view, S.chat.open.id)) {
                    const c = findConv(view, S.chat.open.id);
                    if (c) c.unread = 0;
                }
                recountBadge(view);
                renderHud(st.badge > 0);
                redrawChats();
                break;
            }
            case 'thread': {
                const info = d.info ? normInfo(d.info) : null;
                if (!info || !isOpen(view, info.id)) return;
                const msgs = arr(d.messages).map(normMsg);
                const t = threadFor(view, info.id);
                if (d.older && t) {
                    t.messages = msgs.filter(m => !t.messages.some(x => x.id === m.id)).concat(t.messages);
                    t.hasMore = !!d.hasMore;
                    t.info = info;
                } else {
                    const pending = t ? t.messages.filter(x => x.pending) : [];
                    // a reload keeps what this page already knew about threads it opened
                    if (t) msgs.forEach(m => { const o = t.messages.find(x => x.id === m.id); if (o && o.seenReply) m.seenReply = o.seenReply; });
                    S.chat.thread = { info, messages: msgs.concat(pending), hasMore: !!d.hasMore, view };
                    S.chat.threads = !!d.threads;
                    if (!t) S.chat.seen[view + ':' + info.id] = Number(d.seen) || 0;
                }
                const c = findConv(view, info.id);
                if (c) { Object.assign(c, { muted: info.muted, pinned: info.pinned, handled: info.handled, title: info.title, members: info.members, bizRead: info.bizRead, unread: 0 }); recountBadge(view); renderHud(); }
                redrawChats();
                if (!d.older && S.route.page === 'chats') { const n = document.querySelector('.ch-input'); if (n && !(document.activeElement && document.activeElement.dataset && document.activeElement.dataset.k === 'ch-search')) n.focus(); }
                break;
            }
            case 'msg': {
                const m = normMsg(d.message || {});
                if (!m.id) return;
                const c = findConv(view, id);
                if (!c) { chatOp('list', { view }); return; }
                c.last = m;
                const t = threadFor(view, id);
                const viewing = viewingChat(view, id) && !!t;
                if (m.parentId) {
                    // a thread reply: it counts under its message, and joins the thread if that is open
                    const par = t ? t.messages.find(x => x.id === m.parentId) : null;
                    if (par) { par.replies = (par.replies || 0) + 1; par.lastReply = m.id; par.lastReplyDate = m.date; }
                    const sd = sideOn(view, id, m.parentId) ? S.chat.side : null;
                    if (sd) {
                        if (!sd.replies.some(x => x.id === m.id)) { m.fresh = viewing; sd.replies.push(m); }
                        sd.parent.replies = (sd.parent.replies || 0) + 1; sd.parent.lastReply = m.id; sd.parent.lastReplyDate = m.date;
                        if (par && viewing) par.seenReply = m.id;
                    }
                } else if (t && !t.messages.some(x => x.id === m.id)) {
                    m.fresh = viewing;
                    t.messages.push(m);
                }
                if (viewing) {
                    chatOp('read', { id, view, upTo: m.id });
                    delete S.chat.typing[view + ':' + id];
                } else {
                    c.unread = (c.unread || 0) + 1;
                    if (S.open && !c.muted) toast(`${convTitle(c, view)}: ${m.parentId ? '↳ ' : ''}${U.preview(m.text, 60)}`);
                }
                st.list = [c].concat(st.list.filter(x => x !== c));
                recountBadge(view);
                renderHud(!c.muted && c.unread > 0);
                redrawChats();
                break;
            }
            case 'posted': {
                const t = threadFor(view, id);
                const sd = S.chat.side && S.chat.side.view === view && S.chat.side.convId === id ? S.chat.side : null;
                let p = t ? t.messages.find(x => x.ref && x.ref === d.ref) : null;
                let inSide = false;
                if (!p && sd) { p = sd.replies.find(x => x.ref && x.ref === d.ref) || null; inSide = !!p; }
                if (d.ok && d.message) {
                    const m = normMsg(d.message);
                    if (p) { Object.assign(p, m); p.pending = false; delete p.ref; }
                    if (m.parentId) {
                        // the server sends no 'msg' back to the writer, so the count goes up here
                        const par = t ? t.messages.find(x => x.id === m.parentId) : null;
                        if (par) { par.replies = (par.replies || 0) + 1; par.lastReply = m.id; par.lastReplyDate = m.date; par.seenReply = m.id; }
                        if (sd && sd.parentId === m.parentId) { sd.parent.replies = (sd.parent.replies || 0) + 1; sd.parent.lastReply = m.id; sd.parent.lastReplyDate = m.date; }
                    }
                    const c = findConv(view, id);
                    if (c) { c.last = m; st.list = [c].concat(st.list.filter(x => x !== c)); } else chatOp('list', { view });
                } else if (p) {
                    // refused: the bubble goes and the words go back into the box
                    if (inSide) sd.replies = sd.replies.filter(x => x !== p);
                    else t.messages = t.messages.filter(x => x !== p);
                    const k = draftKey(view, id, p.parentId);
                    if (!S.chat.drafts[k]) S.chat.drafts[k] = p.text;
                    if (d.reason) toast(d.reason, true);
                }
                redrawChats();
                break;
            }
            case 'replies': {
                const sd = S.chat.side;
                const pid = Number(d.parent) || 0;
                if (!sd || sd.view !== view || sd.convId !== id || sd.parentId !== pid) return;
                if (d.missing) {
                    S.chat.side = null;
                    if (S.open) toast('That message is no longer there', true);
                    redrawChats();
                    break;
                }
                const reps = arr(d.replies).map(normMsg);
                if (d.older) sd.replies = reps.filter(m => !sd.replies.some(x => x.id === m.id)).concat(sd.replies);
                else sd.replies = reps.concat(sd.replies.filter(x => x.pending));
                sd.hasMore = !!d.hasMore;
                sd.loading = false;
                if (d.message) {
                    const pm = normMsg(d.message);
                    sd.parent = pm;
                    const t = threadFor(view, id);
                    const par = t ? t.messages.find(x => x.id === pid) : null;
                    if (par) Object.assign(par, { replies: pm.replies, lastReply: pm.lastReply, lastReplyDate: pm.lastReplyDate, reactions: pm.reactions, seenReply: pm.lastReply });
                }
                redrawChats();
                break;
            }
            case 'bizblocks': {
                S.chat.bizBlocks = arr(d.list).map(x => ({ box: Number(x.box) || 0, date: String(x.date || '') })).filter(x => x.box);
                if (bizBlocksRedraw) bizBlocksRedraw();
                break;
            }
            case 'react': {
                const mid = Number(d.msg) || 0;
                const list = normReacts(d.reactions);
                eachCopy(view, id, mid, m => { m.reactions = list.map(r => Object.assign({}, r, { by: r.by.slice() })); });
                if (viewingChat(view, id)) redrawChats();
                break;
            }
            case 'read': {
                const upTo = Number(d.upTo) || 0;
                const apply = info => {
                    if (!info) return;
                    if (d.biz) info.bizRead = Math.max(info.bizRead || 0, upTo);
                    else info.members.forEach(x => { if (x.box === Number(d.box)) x.lastRead = Math.max(x.lastRead, upTo); });
                };
                apply(findConv(view, id));
                const t = threadFor(view, id);
                if (t) apply(t.info);
                if (viewingChat(view, id)) redrawChats();
                break;
            }
            case 'typing': {
                const c = findConv(view, id);
                const label = d.biz ? (c ? bizName(c) : 'The business') : boxName(d.box);
                const k = view + ':' + id;
                S.chat.typing[k] = { label, until: Date.now() + 4500 };
                if (viewingChat(view, id)) drawTyping();
                setTimeout(() => {
                    const t = S.chat.typing[k];
                    if (t && t.until <= Date.now()) { delete S.chat.typing[k]; if (viewingChat(view, id)) drawTyping(); }
                }, 4700);
                break;
            }
            case 'started': {
                if (d.ref && S.chat.starting === d.ref) {
                    S.chat.starting = null;
                    busy(false);
                    if (d.id) openChat('p', Number(d.id));
                }
                break;
            }
            case 'changed': {
                chatOp('list', { view });
                if (isOpen(view, id)) chatOp('open', { id, view });
                if (sideOn(view, id)) chatOp('replies', { id, view, parent: S.chat.side.parentId });
                break;
            }
            case 'gone': {
                st.list = st.list.filter(c => c.id !== id);
                recountBadge(view);
                renderHud();
                if (sideOn(view, id)) S.chat.side = null;
                if (isOpen(view, id)) {
                    S.chat.open = null; S.chat.thread = null;
                    if (!d.quiet && S.open) toast('That chat is gone');
                }
                redrawChats();
                break;
            }
            default: break;
        }
    }

    /* the chat page */

    function renderChats(view) {
        const v = S.view === 'b' && canSendBiz() ? 'b' : 'p';
        if (S.view === 'b' && v === 'p') S.view = 'p';
        const st = S.chat[v];
        setTop({
            kicker: v === 'b' ? S.business.name : (S.box ? 'PO Box ' + S.box : ''),
            heading: v === 'b' ? 'Customers' : 'Chats',
            tools: v === 'p' ? [
                h('button', { class: 'btn primary small', type: 'button', on: { click: () => newChatDialog('direct') } }, icon('plus'), 'New chat'),
                h('button', { class: 'btn small', type: 'button', on: { click: () => newChatDialog('group') } }, icon('people'), 'New group'),
            ] : [
                h('button', { class: 'btn small', type: 'button', title: 'Customers this business blocked', on: { click: bizBlocksDialog } }, icon('bellOff'), 'Blocked'),
            ],
        });
        const open = S.chat.open && S.chat.open.view === v ? S.chat.open : null;
        const openT = open ? threadFor(v, open.id) : null;
        const withSide = !!(openT && sideOn(v, open.id));
        const wrap = h('div', { class: 'ch-wrap' + (open ? ' has-open' : '') + (withSide ? ' has-side' : '') });

        const search = h('input', { class: 'field', type: 'search', placeholder: 'Search names, boxes and messages', value: S.chat.search, data: { k: 'ch-search' } });
        const rows = h('div', { class: 'ch-rows' });
        const filters = v === 'b' ? [['all', 'All'], ['open', 'Open'], ['unread', 'Unread']] : [['all', 'All'], ['unread', 'Unread'], ['groups', 'Groups']];
        const chips = h('div', { class: 'ch-filters' }, filters.map(([k, l]) => h('button', {
            class: 'chip' + (S.chat.filter[v] === k ? ' on' : ''), type: 'button', on: { click: () => { S.chat.filter[v] = k; renderView(); } },
        }, l)));

        const drawRows = () => {
            U.clear(rows);
            const q = S.chat.search.trim().toLowerCase();
            const f = S.chat.filter[v];
            let list = st.list.slice();
            if (f === 'unread') list = list.filter(c => c.unread > 0);
            if (f === 'groups') list = list.filter(c => c.kind === 'group');
            if (f === 'open') list = list.filter(c => !c.handled);
            if (q) list = list.filter(c => [convTitle(c, v), convSub(c, v), c.last && !c.last.hidden ? c.last.text : ''].join(' ').toLowerCase().includes(q));
            list.sort((a, b) => (b.pinned - a.pinned) || ((b.last ? b.last.id : 0) - (a.last ? a.last.id : 0)) || (b.id - a.id));
            if (!list.length) {
                rows.appendChild(h('div', { class: 'empty small' }, st.list.length ? 'No chats match' : (v === 'b' ? 'No customer has written yet' : 'No chats yet')));
                return;
            }
            list.forEach(c => {
                const m = c.last;
                rows.appendChild(h('button', {
                    class: 'ch-row' + (open && open.id === c.id ? ' on' : '') + (c.unread ? ' unread' : ''), type: 'button',
                    on: { click: () => openChat(v, c.id) },
                },
                convAvatar(c, v),
                h('div', { class: 'ch-text' },
                    h('div', { class: 'ch-name' }, h('span', null, convTitle(c, v)), c.pinned ? icon('pin', 'ch-tiny') : null, c.muted ? icon('bellOff', 'ch-tiny') : null),
                    h('div', { class: 'ch-prev' }, previewOf(c, v))),
                h('div', { class: 'ch-meta' }, h('span', null, m ? U.shortDate(m.date) : ''),
                    c.unread ? h('span', { class: 'badge' + (c.muted ? ' muted' : (v === 'b' ? ' blue' : ' red')) }, U.count(c.unread))
                        : (v === 'b' && c.handled ? h('span', { class: 'ch-tag' }, 'handled') : null))));
            });
        };
        search.addEventListener('input', () => { S.chat.search = search.value; drawRows(); });
        drawRows();

        wrap.appendChild(h('aside', { class: 'ch-list' }, h('div', { class: 'ch-tools' }, h('span', { class: 'search-wrap' }, icon('search'), search), chips), rows));
        wrap.appendChild(renderChatPane(v, open));
        if (withSide) wrap.appendChild(renderSide(v, openT));
        view.appendChild(wrap);
    }

    function renderChatPane(v, open) {
        const pane = h('section', { class: 'ch-pane' });
        if (!open) {
            pane.appendChild(h('div', { class: 'ch-empty' },
                h('p', null, v === 'b' ? 'Pick a customer to answer.' : 'Pick a chat, or start a new one.'),
                v === 'p' ? h('button', { class: 'btn primary', type: 'button', on: { click: () => newChatDialog('direct') } }, icon('plus'), 'New chat') : null));
            return pane;
        }
        const t = threadFor(v, open.id);
        const back = h('button', { class: 'mini ch-back', type: 'button', title: 'Back to the list', on: { click: () => { S.chat.open = null; S.chat.thread = null; S.chat.side = null; EMOJI.close(); renderView(); } } }, icon('back'));
        if (!t) {
            const c = findConv(v, open.id);
            pane.appendChild(h('div', { class: 'ch-head' }, back, h('div', { class: 'ch-titles' }, h('div', { class: 'ch-title' }, c ? convTitle(c, v) : 'Opening…'))));
            pane.appendChild(h('div', { class: 'ch-empty' }, 'Fetching the conversation…'));
            return pane;
        }
        const info = t.info;

        const tools = [];
        if (v === 'b') {
            tools.push(h('button', {
                class: 'mini' + (info.handled ? ' on' : ''), type: 'button', title: info.handled ? 'Mark as open' : 'Mark as handled for all staff',
                on: { click: () => { info.handled = !info.handled; chatOp('handled', { id: info.id, view: 'b', on: info.handled }); toast(info.handled ? 'Marked as handled for all staff' : 'Marked as open'); redrawChats(); } },
            }, icon('check')));
        } else {
            tools.push(h('button', {
                class: 'mini' + (info.pinned ? ' on' : ''), type: 'button', title: info.pinned ? 'Unpin' : 'Pin to the top',
                on: { click: () => { info.pinned = !info.pinned; const c = findConv(v, info.id); if (c) c.pinned = info.pinned; chatOp('pin', { id: info.id, on: info.pinned }); redrawChats(); } },
            }, icon('pin')));
            tools.push(h('button', {
                class: 'mini' + (info.muted ? ' on' : ''), type: 'button', title: info.muted ? 'Unmute' : 'Mute',
                on: {
                    click: () => {
                        info.muted = !info.muted;
                        const c = findConv(v, info.id); if (c) c.muted = info.muted;
                        recountBadge(v); renderHud();
                        chatOp('mute', { id: info.id, on: info.muted });
                        toast(info.muted ? 'Muted: it no longer counts on your envelope' : 'Unmuted');
                        redrawChats();
                    },
                },
            }, icon(info.muted ? 'bellOff' : 'bell')));
        }
        tools.push(h('button', { class: 'mini', type: 'button', title: 'Details', on: { click: () => chatDetails(v, info) } }, icon('info')));
        pane.appendChild(h('div', { class: 'ch-head' }, back, convAvatar(info, v),
            h('div', { class: 'ch-titles' }, h('div', { class: 'ch-title' }, convTitle(info, v)), h('div', { class: 'ch-sub' }, convSub(info, v))),
            tools));

        const feed = h('div', { class: 'ch-feed' });
        if (t.hasMore) {
            feed.appendChild(h('button', {
                class: 'ch-older', type: 'button',
                on: { click: e => { e.currentTarget.disabled = true; const first = t.messages.find(x => x.id); chatOp('open', { id: info.id, view: v, before: first ? first.id : 0 }); } },
            }, 'Load older messages'));
        }
        let lastDay = '';
        t.messages.forEach(m => {
            const k = U.dayKey(m.date);
            if (k !== lastDay) { lastDay = k; feed.appendChild(h('div', { class: 'ch-day' }, U.dayLabel(m.date))); }
            feed.appendChild(msgNode(m, t, v, false));
        });
        if (!t.messages.length) feed.appendChild(h('div', { class: 'ch-sys' }, info.kind === 'group' ? 'Nothing said yet. Say hello.' : 'No messages yet. Write the first one.'));
        pane.appendChild(feed);
        pane.appendChild(h('div', { class: 'ch-writing' }));

        const other = info.kind === 'direct' ? otherBox(info) : null;
        if (v === 'p' && other && blocked(other)) {
            pane.appendChild(h('div', { class: 'ch-blocked' }, `You blocked PO Box ${other}. Their messages are hidden from you.`,
                h('button', { class: 'btn small', type: 'button', on: { click: () => setBlock(other, false) } }, 'Unblock')));
        } else {
            pane.appendChild(composer(v, info, 0));
        }
        setTimeout(drawTyping, 0);
        return pane;
    }

    /** Send what is in a typing box: into the main chat, or (parentId) into that reply thread. */
    function sendChat(v, info, input, parentId) {
        const text = input.value.trim();
        if (!text) return;
        if ([...text].length < CHAT_MIN) { shake(input); return toast('Write a little more than that.', true); }
        if (U.utf8Length(text) > lim('groupMessage')) { shake(input); return toast('That message is too long', true); }
        const ref = 'm' + (++S.refSeq);
        const pending = {
            id: 0, ref, box: meBox(), asJob: v === 'b' ? S.business.job : null, text, date: new Date().toISOString(), pending: true, fresh: true,
            parentId: parentId || 0, replies: 0, lastReply: 0, lastReplyDate: '', reactions: [],
        };
        const where = () => {
            if (parentId) return sideOn(v, info.id, parentId) ? S.chat.side.replies : null;
            const t = threadFor(v, info.id);
            return t ? t.messages : null;
        };
        const list = where();
        if (list) list.push(pending);
        S.chat.drafts[draftKey(v, info.id, parentId)] = '';
        input.value = '';
        const data = { id: info.id, view: v, text, ref };
        if (parentId) data.parent = parentId;
        chatOp('post', data);
        setTimeout(() => {
            // no answer at all: the server dropped it
            const l = where();
            const i = l ? l.findIndex(x => x.ref === ref && x.pending) : -1;
            if (i < 0) return;
            l.splice(i, 1);
            toast('That message did not go through', true);
            redrawChats();
        }, SEND_TIMEOUT);
        redrawChats();
    }

    /* starting chats */

    function findExistingChat(target) {
        const t = String(target || '').trim();
        if (U.isBoxNumber(t)) return S.chat.p.list.find(c => c.kind === 'direct' && otherBox(c) === Number(t)) || null;
        const job = handleToJob(t);
        return job ? (S.chat.p.list.find(c => c.kind === 'business' && c.job === job) || null) : null;
    }

    function startPending(op, data) {
        const ref = 's' + (++S.refSeq);
        S.chat.starting = ref;
        busy(true);
        chatOp(op, Object.assign({ ref }, data));
        setTimeout(() => { if (S.chat.starting === ref) { S.chat.starting = null; busy(false); } }, 6000);
    }

    /** Message a box number or a business address: opens the chat, or starts one. */
    function messageTarget(target) {
        const t = String(target || '').trim();
        if (!t) return;
        if (U.isBoxNumber(t) && Number(t) === meBox()) return toast('That is your own PO box', true);
        if (U.isBoxNumber(t) && blocked(t)) return toast('You blocked that box. Unblock it in your address book first.', true);
        if (!U.isBoxNumber(t)) {
            const job = handleToJob(t);
            if (!job) return toast('No business uses that address', true);
            if (S.business && S.business.job === job) return toast('That is your own business', true);
        }
        S.view = 'p';
        const existing = findExistingChat(t);
        if (existing) return openChat('p', existing.id);
        go({ page: 'chats' });
        startPending('start', { target: t });
    }

    function newChatDialog(kind) {
        if (!S.box) return toast('You need a PO box of your own first', true);
        let mode = kind;
        const target = h('input', { class: 'field', type: 'text', maxLength: 24, placeholder: 'For example 1187 or val556' });
        const title = h('input', { class: 'field', type: 'text', maxLength: lim('groupTitle'), placeholder: 'For example Heartlands Freight' });
        const titleRow = h('label', { class: 'lbl' }, h('span', null, 'Group name'), title);
        const targetLbl = h('span');
        const tabs = h('div', { class: 'seg ch-tabs' });
        const picks = h('div', { class: 'pick-list' });
        const submit = () => {
            const t = target.value.trim();
            if (mode === 'group') {
                const name = title.value.trim();
                if (!name) { shake(title); toast('Give the group a name', true); return false; }
                if (t && !U.isBoxNumber(t)) { shake(target); toast('Group members are added by PO box number', true); return false; }
                if (t && Number(t) === meBox()) { shake(target); toast('You are in the group already', true); return false; }
                S.view = 'p';
                go({ page: 'chats' });
                startPending('create', { title: name, target: t });
                return true;
            }
            if (!t) { shake(target); toast('Type a PO box number or a business address', true); return false; }
            if (!U.isBoxNumber(t) && !handleToJob(t)) { shake(target); toast('No business uses that address', true); return false; }
            messageTarget(t);
            return true;
        };
        const draw = () => {
            U.clear(tabs);
            [['direct', 'Direct'], ['group', 'Group']].forEach(([m, l]) => tabs.appendChild(h('button', {
                class: 'seg-btn' + (mode === m ? ' on' : ''), type: 'button', on: { click: () => { mode = m; draw(); } },
            }, l)));
            titleRow.classList.toggle('hidden', mode !== 'group');
            targetLbl.textContent = mode === 'group' ? 'First member: PO box number (optional)' : 'PO box number or business address';
            U.clear(picks);
            const list = S.contacts.filter(c => c.id && (U.isBoxNumber(c.poBox) || (mode === 'direct' && handleToJob(c.poBox))))
                .sort((a, b) => U.nameCompare(a.name, b.name));
            if (!list.length) picks.appendChild(h('div', { class: 'empty small' }, 'None of your saved contacts has a PO box yet'));
            list.forEach(c => picks.appendChild(h('button', {
                class: 'pick', type: 'button',
                on: { click: () => { target.value = String(c.poBox).trim(); if (mode === 'direct' && submit() && modalClose) modalClose(); } },
            }, h('span', { class: 'pick-name' }, c.name), h('small', null, boxLabel(c)))));
        };
        target.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); if (submit() && modalClose) modalClose(); } });
        draw();
        modal({
            title: 'New chat', wide: true,
            body: [tabs, titleRow, h('label', { class: 'lbl' }, targetLbl, target), h('div', { class: 'lbl' }, h('span', null, 'Or pick from your address book')), picks],
            actions: [{ label: 'Cancel' }, { label: 'Start', kind: 'primary', onClick: submit }],
        });
    }

    /* details, groups and blocking */

    function setBlock(box, on) {
        box = Number(box);
        if (!box) return;
        S.chat.blocks = S.chat.blocks.filter(b => b !== box);
        if (on) S.chat.blocks.push(box);
        chatOp('block', { box, on });
        toast(on ? `Blocked PO Box ${box}. Their messages are hidden from you.` : `Unblocked PO Box ${box}`);
        if (S.open) render();
    }

    async function toggleBlock(box) {
        if (blocked(box)) return setBlock(box, false);
        if (!await confirmBox('Block this box', `Block PO Box ${box}? Their messages are hidden from you in every chat, and they cannot start a chat you will see.`, 'Block', true)) return;
        setBlock(box, true);
    }

    function addGroupMember(info) {
        const input = h('input', { class: 'field', type: 'text', placeholder: 'PO box number', maxLength: 10 });
        const withBox = S.contacts.filter(c => U.isBoxNumber(c.poBox)).sort((a, b) => U.nameCompare(a.name, b.name));
        const already = new Set(info.members.map(m => String(m.box)));
        const add = box => { chatOp('add', { id: info.id, target: String(box).trim() }); if (modalClose) modalClose(); };
        const list = h('div', { class: 'pick-list' });
        if (!withBox.length) list.appendChild(h('div', { class: 'empty small' }, 'None of your saved contacts has a PO box number yet'));
        withBox.forEach(c => {
            const b = String(c.poBox).trim();
            list.appendChild(h('button', { class: 'pick', type: 'button', disabled: already.has(b), on: { click: () => add(b) } },
                h('span', { class: 'pick-name' }, c.name), h('small', null, already.has(b) ? 'in the group' : 'PO Box ' + b)));
        });
        input.addEventListener('keydown', e => { if (e.key === 'Enter' && input.value.trim()) { e.preventDefault(); add(input.value); } });
        modal({
            title: 'Add someone', wide: true,
            body: [h('label', { class: 'lbl' }, h('span', null, 'By PO box number'), input), h('div', { class: 'lbl' }, h('span', null, 'Or from your address book')), list],
            actions: [{ label: 'Cancel' }, {
                label: 'Add', kind: 'primary', onClick: () => {
                    if (!U.isBoxNumber(input.value)) { shake(input); toast('Type a PO box number', true); return false; }
                    chatOp('add', { id: info.id, target: input.value.trim() });
                    return true;
                },
            }],
        });
    }

    // a second dialog opens only after the first has closed
    const later = fn => () => { setTimeout(fn, 0); };

    /* business blocks: the boxes this business no longer takes messages from */
    let bizBlocksRedraw = null;
    function bizBlocksDialog() {
        if (!canSendBiz()) return;
        const list = h('div', { class: 'pick-list' });
        const draw = () => {
            U.clear(list);
            if (!S.chat.bizBlocks.length) { list.appendChild(h('div', { class: 'empty small' }, 'Nobody is blocked')); return; }
            S.chat.bizBlocks.forEach(b => list.appendChild(h('div', { class: 'pick' },
                h('span', { class: 'pick-name' }, boxName(b.box) + (isSavedBox(b.box) ? ` (${b.box})` : '')),
                h('small', null, b.date ? 'since ' + U.shortDate(b.date) : ''),
                h('button', {
                    class: 'btn small', type: 'button',
                    on: { click: () => { S.chat.bizBlocks = S.chat.bizBlocks.filter(x => x.box !== b.box); chatOp('bizblock', { view: 'b', box: b.box, on: false }); draw(); } },
                }, 'Unblock'))));
        };
        draw();
        bizBlocksRedraw = draw;
        chatOp('bizblocks', { view: 'b' });
        const close = modal({
            title: `Blocked by ${S.business.name}`, wide: true,
            body: [h('p', null, 'These PO boxes cannot write to the business. Unblock one to let them write again.'), list],
            actions: [{ label: 'Close', kind: 'primary' }],
        });
        // stop redrawing once the dialog is gone
        const prev = modalClose;
        modalClose = () => { bizBlocksRedraw = null; prev(); };
        return close;
    }

    function chatDetails(v, info) {
        const body = [];
        const actions = [];
        if (info.kind === 'group') {
            const ownerMe = info.owner === meBox();
            body.push(h('p', null, `${info.members.length} member${info.members.length === 1 ? '' : 's'}. Everyone shows as their PO box number unless you saved a name for it.`));
            body.push(h('div', { class: 'ch-members' }, info.members.map(m => {
                const named = m.box === meBox() || isSavedBox(m.box);
                return h('div', { class: 'ch-member' },
                    h('div', { class: 'ch-av' + (named ? '' : ' box') }, named ? U.initials(boxName(m.box)) : String(m.box)),
                    h('span', { class: 'pick-name' }, boxName(m.box) + (named && m.box !== meBox() ? ` (${m.box})` : '')),
                    m.box === info.owner ? h('span', { class: 'ch-tag' }, 'owner') : null,
                    ownerMe && m.box !== meBox() ? h('button', {
                        class: 'btn small danger', type: 'button', on: {
                            click: async () => {
                                if (modalClose) modalClose();
                                if (await confirmBox('Remove member', `Remove ${boxName(m.box)} from the group?`, 'Remove', true)) chatOp('remove', { id: info.id, target: m.box });
                            },
                        },
                    }, 'Remove') : null);
            })));
            if (ownerMe) {
                actions.push({ label: 'Add someone', onClick: later(() => addGroupMember(info)) });
                actions.push({
                    label: 'Rename', onClick: later(async () => {
                        const t = await promptBox('Rename group', 'Group name', info.title, lim('groupTitle'), 'Rename', x => (x ? null : 'Give the group a name'));
                        if (t && t !== info.title) chatOp('rename', { id: info.id, title: t });
                    }),
                });
                actions.push({
                    label: 'Disband', kind: 'danger', onClick: later(async () => {
                        const word = await promptBox('Disband group', 'Type DISBAND to delete the group and everything said in it', '', 16, 'Disband');
                        if (word === null) return;
                        if (word.trim().toUpperCase() !== 'DISBAND') return toast('Nothing disbanded: the word did not match', true);
                        chatOp('disband', { id: info.id });
                    }),
                });
            }
            actions.push({
                label: 'Leave', kind: 'danger', onClick: later(async () => {
                    const text = ownerMe ? 'Leave this group? The group passes to the longest-standing member.' : 'Leave this group? You will stop getting its messages.';
                    if (await confirmBox('Leave group', text, 'Leave', true)) chatOp('leave', { id: info.id });
                }),
            });
        } else if (info.kind === 'business' && v === 'p') {
            body.push(h('p', null, `${bizName(info)}${info.handle ? ' · PO address ' + info.handle : ''}`));
            body.push(h('p', null, 'Staff of this business who may write letters for it can read and answer this chat. You never see which one of them wrote.'));
        } else {
            const box = info.kind === 'business' ? customerBox(info) : otherBox(info);
            if (box) {
                body.push(h('p', null, `PO Box ${box}${isSavedBox(box) ? ' · saved as ' + boxName(box) : ' · not in your address book'}`));
                const c = contactForBox(String(box));
                actions.push({
                    label: c ? 'Edit contact' : 'Save contact',
                    onClick: later(() => go(c ? { page: 'contactForm', key: contactKey(c), back: { page: 'chats' } } : { page: 'contactForm', key: null, prefill: { poBox: String(box) }, back: { page: 'chats' } })),
                });
                if (v === 'p') actions.push({ label: blocked(box) ? 'Unblock' : 'Block', kind: 'danger', onClick: later(() => toggleBlock(box)) });
                if (v === 'b' && info.kind === 'business') {
                    actions.push({
                        label: 'Block customer', kind: 'danger', onClick: later(async () => {
                            const text = `Block PO Box ${box} for ${S.business.name}? They can no longer write to the business, and this chat closes for all staff. Unblock them any time under Blocked.`;
                            if (await confirmBox('Block customer', text, 'Block', true)) chatOp('bizblock', { view: 'b', box, on: true });
                        }),
                    });
                }
            }
        }
        actions.push({ label: 'Close', kind: 'primary' });
        modal({ title: convTitle(info, v), wide: info.kind === 'group', body, actions });
    }


    /* ---------------------------------------------------------------- settings */

    function renderSettings(view) {
        setTop({ kicker: 'Your Mailbox', heading: 'Settings' });
        const s = S.look;
        const b = S.cfg.branding || {};
        const change = (fn, relayout) => { fn(); S.eff = LOOK.apply(S.look, b); if (relayout) layoutWindow(); saveLook(); renderView(); };

        const section = (title, ...kids) => h('section', { class: 'set-sec' }, h('h3', null, title), kids);
        const field = (label, control, note) => h('div', { class: 'set-row' }, h('div', { class: 'set-lbl' }, label, note ? h('small', null, note) : null), h('div', { class: 'set-ctl' }, control));
        const select = (value, options, fn) => {
            const sel = h('select', { class: 'field' }, options.map(([v, t]) => h('option', { value: v }, t)));
            sel.value = value;
            sel.addEventListener('change', () => change(() => fn(sel.value)));
            return sel;
        };
        const slider = (value, lo, hi, fn, relayout) => {
            const out = h('span', { class: 'slider-val' }, value + '%');
            const r = h('input', { type: 'range', min: lo, max: hi, step: 1, value });
            r.value = value;
            r.addEventListener('input', () => { out.textContent = r.value + '%'; fn(Number(r.value)); S.eff = LOOK.apply(S.look, b); if (relayout) layoutWindow(); saveLook(); });
            return h('div', { class: 'slider' }, r, out);
        };
        const seg = (value, options, fn, relayout) => h('div', { class: 'seg' }, options.map(([v, t]) => h('button', {
            class: 'seg-btn' + (value === v ? ' on' : ''), type: 'button', on: { click: () => change(() => fn(v), relayout) },
        }, t)));
        const sw = (key, label, serverOff, extraOff) => {
            const off = serverOff || extraOff;
            const cb = h('input', { type: 'checkbox', checked: s[key] && !off, disabled: !!off });
            cb.addEventListener('change', () => change(() => { s[key] = cb.checked; }));
            return h('label', { class: 'toggle' + (off ? ' disabled' : '') }, cb, h('span', { class: 'tg-ui' }),
                h('span', { class: 'tg-text' }, h('b', null, label), serverOff ? h('small', null, 'Turned off by this server') : (extraOff ? h('small', null, extraOff) : null)));
        };

        const themes = h('div', { class: 'themes' }, LOOK.THEMES.map(t => h('button', {
            class: 'theme-card' + (s.theme === t.id ? ' on' : ''), type: 'button',
            on: { click: () => change(() => { s.theme = t.id; }) },
        }, h('span', { class: 'swatches' }, [t.c[1], t.c[3], t.c[4], t.c[7]].map(c => h('i', { style: { background: c } }))),
            h('b', null, t.label), h('small', null, t.note))));

        const hex = h('input', { class: 'field hex', type: 'text', maxLength: 7, placeholder: '#rrggbb', value: s.accent });
        hex.addEventListener('change', () => {
            const v = hex.value.trim();
            if (v === '' || /^#[0-9a-f]{6}$/i.test(v)) change(() => { s.accent = v.toLowerCase(); });
            else { shake(hex); toast('Use a colour like #c9a24d', true); }
        });
        const accents = h('div', { class: 'accents' },
            h('button', { class: 'acc-btn def' + (!s.accent ? ' on' : ''), type: 'button', title: 'Theme default', on: { click: () => change(() => { s.accent = ''; }) } }, 'Theme'),
            LOOK.ACCENTS.map(c => h('button', { class: 'acc-btn' + (s.accent === c ? ' on' : ''), type: 'button', title: c, style: { background: c }, on: { click: () => change(() => { s.accent = c; }) } })),
            hex);

        const papers = [['', 'Server default']].concat(LOOK.PAPERS.map(p => [p.id, p.label]));

        // a small sample letter
        const sampleBox = S.box || 1042;
        // the same business letter players receive: letterhead, company stamp, envelope says "Business"
        const sample = h('div', { class: 'sample paper-stack biz' },
            envelope(h('div', { class: 'env-who' }, h('div', { class: 'who-name' }, 'Blackwater Mercantile'), h('div', { class: 'who-sub' }, 'Business')),
                h('div', { class: 'env-who' }, h('div', { class: 'who-name' }, `You (PO Box ${sampleBox})`)), new Date().toISOString()),
            sheet({
                letterhead: letterhead('Blackwater Mercantile', 'bwm120'),
                date: U.fullDate(new Date().toISOString()),
                subject: h('div', { class: 'sheet-subject' }, 'Your order has arrived'),
                body: h('div', { class: 'body-text plain' }, 'Your parcel came in on the morning train and is waiting behind the counter. Call in whenever suits you.'),
                signoff: bizStamp('Blackwater Mercantile', 'bwm120'),
            }));

        view.appendChild(h('div', { class: 'settings' },
            h('div', { class: 'set-cols' },
                h('div', { class: 'set-col' },
                    section('Appearance',
                        field('Theme', themes),
                        field('Accent colour', accents),
                        field('Interface font', select(s.uiFont, LOOK.UI_FONTS.map(f => [f.id, f.label]), v => { s.uiFont = v; }))),
                    section('Chats',
                        field('Bubble paper', seg(s.bubble, LOOK.BUBBLES.map(x => [x.id, x.label]), v => { s.bubble = v; }), 'How other people\'s messages look'),
                        field('Enter key', seg(s.enterSends ? 'send' : 'line', [['send', 'Sends'], ['line', 'New line']], v => { s.enterSends = v === 'send'; }), 'Shift+Enter always adds a line')),
                    section('Letters',
                        field('Paper', select(s.paper, papers, v => { s.paper = v; })),
                        field('Handwriting', select(s.letterFont, LOOK.FONTS.map(f => [f.id, f.label]), v => { s.letterFont = v; }))),
                    section('Layout',
                        field('Window size', slider(s.scale, 75, 130, v => { s.scale = v; }, true)),
                        field('Text size', slider(s.textSize, 85, 130, v => { s.textSize = v; }, true)),
                        field('Layout', seg(s.layout, [['expanded', 'Expanded'], ['compact', 'Compact']], v => { s.layout = v; }, true)),
                        field('Density', seg(s.density, [['comfortable', 'Comfortable'], ['compact', 'Compact']], v => { s.density = v; })),
                        field('Position', h('div', { class: 'pos' },
                            seg(s.anchor, [['left', 'Left'], ['center', 'Centre'], ['right', 'Right']], v => { s.anchor = v; }, true),
                            h('button', { class: 'btn small', type: 'button', on: { click: () => { change(() => { s.dx = 0; s.dy = 0; }, true); toast('Window back in its place'); } } }, 'Re-centre')))),
                    section('Effects',
                        field('Window opacity', slider(s.opacity, 60, 100, v => { s.opacity = v; })),
                        field('Darken the game behind', slider(s.dim, 0, 80, v => { s.dim = v; })),
                        field('Animation', seg(s.motion, [['full', 'Full'], ['reduced', 'Reduced'], ['off', 'Off']], v => { s.motion = v; })),
                        h('div', { class: 'toggles' },
                            sw('seal', 'Wax seal', b.seal === false),
                            sw('watermark', 'Watermark', b.watermark === false, !b.logo ? 'Needs a server logo' : null),
                            sw('ornaments', 'Ornaments', b.ornaments === false),
                            sw('texture', 'Leather grain', false))),
                    h('div', { class: 'set-foot' },
                        h('button', {
                            class: 'btn danger', type: 'button', on: {
                                click: async () => {
                                    if (!await confirmBox('Restore defaults', 'Put every setting back to how it started? Your starred contacts stay.', 'Restore', true)) return;
                                    const fav = S.look.favorites;
                                    S.look = LOOK.validate(Object.assign({}, LOOK.DEFAULTS, { favorites: fav }));
                                    applyLook(); saveLook(); renderView();
                                    toast('Defaults restored');
                                },
                            },
                        }, 'Restore defaults'),
                        h('small', null, 'Saved on this machine and restored every time you open your mail.'))),
                h('div', { class: 'set-col preview' }, h('h3', null, 'Preview'), sample))));
    }

    /* ================================================================ keyboard and start-up */

    document.addEventListener('keydown', e => {
        if (e.key !== 'Escape' || !S.open) return;
        e.preventDefault();
        if (modalClose) { modalClose(); return; }
        if (closeSuggest()) return;
        if (EMOJI.close()) return;
        if (S.chat.side && S.route.page === 'chats') { closeSide(); return; }
        hideWindow(true);
    });

    function boot() {
        $('closeBtn').addEventListener('click', () => hideWindow(true));
        $('closeBtn').appendChild(icon('close'));
        $('back').insertBefore(icon('back'), $('back').firstChild);
        $('modal').addEventListener('mousedown', e => { if (e.target === $('modal') && modalClose) modalClose(); });
        setupDrag();
        applyLook();
        renderHud();
        post('boot');
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
})();
