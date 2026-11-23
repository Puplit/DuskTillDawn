/* pup-stable menu page. Driven entirely by messages from client/nui.lua; it only ever reports
   close / action / preview / rotate back, and the client runs actions from a fixed allow-list. */
(() => {
    'use strict';

    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pup-stable';
    const post = (name, data) => fetch(`https://${RES}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}),
    }).catch(() => {});

    const $ = (id) => document.getElementById(id);
    const panel = $('panel'), list = $('list'), sliders = $('sliders'), desc = $('desc'), stats = $('stats');
    const actions = $('actions'), hints = $('hints');

    const S = { menus: {}, stack: [], sel: {}, slider: {}, lang: {}, open: false, hold: null };

    const t = (s, raw) => (raw || typeof s !== 'string') ? (s == null ? '' : String(s)) : (S.lang[s] !== undefined ? String(S.lang[s]) : s);

    /* ---- self-drawn icons (simple strokes) ---- */
    const ICONS = {
        star: 'M12 3 L14.6 9 L21 9.5 L16 13.6 L17.6 20 L12 16.6 L6.4 20 L8 13.6 L3 9.5 L9.4 9 Z',
        lock: 'M7 11 V8 a5 5 0 0 1 10 0 V11 M5 11 H19 V21 H5 Z',
        tick: 'M4 12 L10 18 L20 6',
        plus: 'M12 4 V20 M4 12 H20',
        dollar: 'M16 6 H10 a3 3 0 0 0 0 6 H14 a3 3 0 0 1 0 6 H8 M12 3 V21',
        palette: 'M12 3 a9 9 0 1 0 0 18 c1.5 0 2-1 2-2 s-1-2 0-3 h3 a4 4 0 0 0 4-4 C21 7 17 3 12 3 Z M7.5 11 h.01 M10 7 h.01 M15 7 h.01',
        male: 'M10 14 m-5 0 a5 5 0 1 0 10 0 a5 5 0 1 0 -10 0 M13.5 10.5 L20 4 M15 4 H20 V9',
        female: 'M12 9 m-5 0 a5 5 0 1 0 10 0 a5 5 0 1 0 -10 0 M12 14 V21 M9 18 H15',
        book: 'M4 5 a2 2 0 0 1 2-2 H20 V19 H6 a2 2 0 0 0 -2 2 Z M4 21 V5',
        wagon: 'M3 14 H21 L19 7 H5 Z M7 18 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0 M17 18 m-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0',
        wheel: 'M12 12 m-8 0 a8 8 0 1 0 16 0 a8 8 0 1 0 -16 0 M12 4 V20 M4 12 H20 M6.3 6.3 L17.7 17.7 M17.7 6.3 L6.3 17.7',
        horse: 'M5 20 C6 13 9 9 14 7 L16 3 L18 7 C20 9 21 12 20 15 L17 14 C16 11 15 10 13 10 C11 13 10 16 10 20 Z',
        heart: 'M12 20 C5 14 3 11 3 8 a4.5 4.5 0 0 1 9-1 a4.5 4.5 0 0 1 9 1 c0 3-2 6-9 12 Z',
        bolt: 'M13 2 L4 14 H11 L10 22 L20 9 H13 Z',
        saddle: 'M3 12 C6 9 9 9 12 11 C15 9 18 9 21 12 L19 15 H5 Z M12 11 V7',
        horseshoe: 'M6 4 V12 a6 6 0 0 0 12 0 V4',
        lantern: 'M9 4 H15 M10 4 V6 M14 4 V6 M8 6 H16 V18 H8 Z M12 10 V14',
        bag: 'M5 8 H19 L18 20 H6 Z M9 8 V6 a3 3 0 0 1 6 0 V8',
        grave: 'M7 21 V10 a5 5 0 0 1 10 0 V21 Z M12 11 V16 M10 13 H14',
        swap: 'M4 8 H18 L14 4 M20 16 H6 L10 20',
        pencil: 'M4 20 L5 15 L16 4 L20 8 L9 19 Z',
        cross: 'M5 5 L19 19 M19 5 L5 19',
        door: 'M6 21 V3 H18 V21 M14 12 h.01',
        list: 'M8 6 H20 M8 12 H20 M8 18 H20 M4 6 h.01 M4 12 h.01 M4 18 h.01',
    };
    const svg = (name, cls) => {
        const ns = 'http://www.w3.org/2000/svg';
        const el = document.createElementNS(ns, 'svg');
        el.setAttribute('viewBox', '0 0 24 24');
        el.setAttribute('class', cls || 'ico');
        const p = document.createElementNS(ns, 'path');
        p.setAttribute('d', ICONS[name] || ICONS.list);
        el.appendChild(p);
        return el;
    };

    /* ---- limited safe HTML for descriptions ---- */
    const ALLOWED = new Set(['B', 'BR', 'SPAN', 'I', 'STRONG', 'EM', 'H2']);
    const STYLE_OK = /^\s*(color|font-weight|font-style|opacity)\s*:\s*[#\w\s.,%()-]+\s*$/i;
    function safeHtml(target, html) {
        target.textContent = '';
        if (html == null) return;
        const doc = new DOMParser().parseFromString(`<div>${String(html)}</div>`, 'text/html');
        const walk = (src, dst) => {
            src.childNodes.forEach((n) => {
                if (n.nodeType === 3) { dst.appendChild(document.createTextNode(n.textContent)); return; }
                if (n.nodeType !== 1) return;
                if (!ALLOWED.has(n.tagName)) { dst.appendChild(document.createTextNode(n.textContent)); return; }
                const el = document.createElement(n.tagName);
                if (n.hasAttribute('class')) el.className = n.getAttribute('class').replace(/[^\w\s-]/g, '');
                if (n.hasAttribute('data-palette')) el.dataset.palette = n.getAttribute('data-palette').replace(/[^\w-]/g, '');
                const st = n.getAttribute('style');
                if (st) st.split(';').filter((d) => STYLE_OK.test(d)).forEach((d) => {
                    const [k, v] = d.split(':');
                    el.style.setProperty(k.trim(), v.trim());
                });
                walk(n, el);
                dst.appendChild(el);
            });
        };
        walk(doc.body.firstChild, target);
    }

    /* ---- helpers ---- */
    const cur = () => S.menus[S.stack[S.stack.length - 1]];
    const visibleItems = (m) => (m ? m.items.filter((i) => !i.hidden) : []);
    const selIndex = (m) => {
        const items = visibleItems(m);
        let i = S.sel[m.id] || 0;
        if (i >= items.length) i = Math.max(0, items.length - 1);
        S.sel[m.id] = i;
        return i;
    };
    const selItem = () => { const m = cur(); if (!m) return null; return visibleItems(m)[selIndex(m)] || null; };
    const money = (n) => {
        const v = Number(n) || 0;
        return '$' + (Number.isInteger(v) ? v.toLocaleString('en-US') : v.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }));
    };
    const sliderValues = (item) => (item && item.sliders ? item.sliders.map((s) => s.index) : []);

    function preview() {
        const m = cur(), it = selItem();
        if (m && it) post('preview', { menu: m.id, item: it.id, sliders: sliderValues(it) });
    }

    /* ---- rendering ---- */
    function renderHeader() {
        const m = cur();
        $('menu-title').textContent = m ? t(m.title, m.raw) : '';
        const items = visibleItems(m);
        $('counter').textContent = items.length ? `${selIndex(m) + 1} / ${items.length}` : '';
        $('back-btn').style.visibility = S.stack.length > 1 ? 'visible' : 'hidden';
    }

    function renderList() {
        const m = cur();
        list.textContent = '';
        if (!m) return;
        const items = visibleItems(m);
        const rows = m.rows || 8;
        const sel = selIndex(m);
        let start = Math.max(0, Math.min(sel - Math.floor(rows / 2), items.length - rows));
        if (start < 0) start = 0;
        $('up-hint').classList.toggle('on', start > 0);
        $('down-hint').classList.toggle('on', start + rows < items.length);
        items.slice(start, start + rows).forEach((it, k) => {
            const idx = start + k;
            const li = document.createElement('li');
            li.setAttribute('role', 'option');
            if (idx === sel) li.classList.add('sel');
            if (it.disabled) li.classList.add('disabled');
            if (it.prefix) li.appendChild(svg(it.prefix, 'pre'));
            if (it.icon) li.appendChild(svg(it.icon));
            const tt = document.createElement('span');
            tt.className = 't';
            tt.textContent = t(it.title, it.raw);
            if (it.tone) tt.classList.add(it.tone === 'red' ? 'red' : 'goldtxt');
            li.appendChild(tt);
            if (it.sub) { const a = document.createElement('span'); a.className = 'alt'; a.textContent = t(it.sub, true); li.appendChild(a); }
            if (it.priceAlt) { const a = document.createElement('span'); a.className = 'alt'; a.textContent = t(it.priceAlt); li.appendChild(a); }
            if (it.price !== undefined && it.price !== null) {
                const p = document.createElement('span');
                p.className = 'price' + (Number(it.price) === 0 ? ' free' : '');
                p.textContent = Number(it.price) === 0 ? t('free') : money(it.price);
                li.appendChild(p);
            }
            if (it.gold) { const g = document.createElement('span'); g.className = 'gold'; g.textContent = `${it.gold} G`; li.appendChild(g); }
            if (it.equipped) { const d = document.createElement('span'); d.className = 'dot'; li.appendChild(d); }
            if (it.right) li.appendChild(svg(it.right));
            if (it.child) { const a = document.createElement('span'); a.className = 'arrow'; a.textContent = '›'; li.appendChild(a); }
            li.addEventListener('click', () => {
                if (S.sel[m.id] === idx) { activate(); return; }
                S.sel[m.id] = idx; S.slider[m.id] = 0; render(); preview();
            });
            list.appendChild(li);
        });
    }

    function renderSliders(it) {
        sliders.textContent = '';
        if (!it || !it.sliders || !it.sliders.length) return;
        const m = cur();
        const active = Math.min(S.slider[m.id] || 0, it.sliders.length - 1);
        it.sliders.forEach((s, i) => {
            const row = document.createElement('div');
            row.className = 'slider' + (i === active ? ' active' : '');
            const lbl = document.createElement('span'); lbl.className = 'lbl'; lbl.textContent = t(s.label, s.raw); row.appendChild(lbl);
            const left = document.createElement('button'); left.className = 'arr'; left.type = 'button'; left.textContent = '‹';
            left.addEventListener('click', () => { S.slider[m.id] = i; adjust(-1); });
            row.appendChild(left);
            const max = s.type === 'palette' ? (s.max || 1) : (s.values ? s.values.length : 1);
            if (s.type === 'palette') {
                const strip = document.createElement('div');
                strip.className = 'strip pal-' + String(s.palette || '').replace(/[^\w]/g, '');
                const c = document.createElement('div');
                c.className = 'cursor';
                c.style.left = `${max > 1 ? (s.index / (max - 1)) * 100 : 0}%`;
                strip.appendChild(c);
                row.appendChild(strip);
            } else {
                const v = document.createElement('span'); v.className = 'val';
                const lv = s.values ? s.values[s.index] : s.index;
                v.textContent = t(lv, s.rawValues);
                row.appendChild(v);
            }
            const right = document.createElement('button'); right.className = 'arr'; right.type = 'button'; right.textContent = '›';
            right.addEventListener('click', () => { S.slider[m.id] = i; adjust(1); });
            row.appendChild(right);
            const num = document.createElement('span'); num.className = 'num'; num.textContent = `${s.index + (s.zero ? 0 : 1)}/${max}`;
            row.appendChild(num);
            sliders.appendChild(row);
        });
    }

    function renderStats(it) {
        stats.textContent = '';
        if (!it || !it.stats) return;
        it.stats.forEach((s) => {
            const row = document.createElement('div'); row.className = 'row';
            const k = document.createElement('span'); k.className = 'k'; k.textContent = t(s.label, s.raw); row.appendChild(k);
            if (s.kind === 'bar') {
                const bar = document.createElement('div'); bar.className = 'bar';
                (s.cells || []).forEach((c) => { const d = document.createElement('i'); d.className = 'cell ' + String(c || '').replace(/[^\w]/g, ''); bar.appendChild(d); });
                row.appendChild(bar);
            } else if (s.kind === 'icons') {
                const box = document.createElement('div'); box.className = 'icons';
                for (let i = 0; i < (s.max || 0); i++) {
                    const ic = svg(s.icon || 'heart', i < (s.count || 0) ? '' : 'off');
                    box.appendChild(ic);
                }
                row.appendChild(box);
            } else if (s.kind === 'fraction') {
                const f = document.createElement('div'); f.className = 'frac';
                const fill = document.createElement('i');
                fill.style.width = `${Math.max(0, Math.min(100, ((s.cur || 0) / (s.max || 1)) * 100))}%`;
                f.appendChild(fill); row.appendChild(f);
                const n = document.createElement('span'); n.className = 'fracnum'; n.textContent = `${s.cur}/${s.max}`; row.appendChild(n);
            } else {
                const v = document.createElement('span'); v.className = 'v'; v.textContent = t(s.value, s.rawValue !== false); row.appendChild(v);
            }
            stats.appendChild(row);
        });
    }

    const KEY_LABEL = { Enter: 'Enter', Backspace: 'Back' };
    function renderActions(it) {
        actions.textContent = '';
        const m = cur();
        const acts = (it && it.actions) || (m && m.actions) || [];
        acts.forEach((a) => {
            const el = document.createElement('div');
            el.className = 'act' + (a.danger ? ' danger' : '');
            el.dataset.key = a.key;
            const key = document.createElement('span'); key.className = 'key';
            key.textContent = KEY_LABEL[a.key] || a.key;
            const fill = document.createElement('span'); fill.className = 'fill'; key.appendChild(fill);
            el.appendChild(key);
            const lbl = document.createElement('span'); lbl.textContent = t(a.label, a.raw); el.appendChild(lbl);
            el.addEventListener('click', () => { if (!a.hold) fire(a); });
            actions.appendChild(el);
        });
        hints.textContent = '';
        const h = [['↑↓', 'navigate']];
        if (it && it.sliders && it.sliders.length) h.push(['←→', 'adjust']);
        if (it && it.sliders && it.sliders.length > 1) h.push(['Tab', 'nextSlider']);
        if (m && m.rotate) h.push(['A/D', 'rotate']);
        h.push(['Esc', 'back']);
        h.forEach(([k, l]) => {
            const s = document.createElement('span');
            const b = document.createElement('b');
            b.textContent = k;
            if (/[←-↓]/.test(k)) b.className = 'k-sym'; // arrows need a face that has them
            s.appendChild(b);
            s.appendChild(document.createTextNode(` ${t(l)}`));
            hints.appendChild(s);
        });
    }

    function render() {
        if (!S.open) return;
        renderHeader();
        renderList();
        const it = selItem();
        renderSliders(it);
        safeHtml(desc, it ? it.desc : '');
        renderStats(it);
        renderActions(it);
    }

    /* ---- input ---- */
    function move(d) {
        const m = cur(); if (!m) return;
        const items = visibleItems(m); if (!items.length) return;
        let i = selIndex(m);
        for (let n = 0; n < items.length; n++) {
            i = (i + d + items.length) % items.length;
            if (!items[i].skip) break;
        }
        S.sel[m.id] = i; S.slider[m.id] = 0;
        render(); preview();
    }

    function adjust(d) {
        const m = cur(), it = selItem();
        if (!it || !it.sliders || !it.sliders.length) return;
        const s = it.sliders[Math.min(S.slider[m.id] || 0, it.sliders.length - 1)];
        const max = s.type === 'palette' ? (s.max || 1) : (s.values ? s.values.length : 1);
        s.index = (s.index + d + max) % max;
        render(); preview();
    }

    function back() {
        if (S.stack.length > 1) { S.stack.pop(); render(); preview(); post('back', { menu: cur().id }); return; }
        post('close', {});
    }

    function fire(a) {
        const m = cur(), it = selItem();
        if (!m || !it || it.disabled && a.act !== 'back') return;
        post('action', { menu: m.id, item: it.id, act: a.act, sliders: sliderValues(it) });
    }

    function activate() {
        const m = cur(), it = selItem();
        if (!m || !it || it.disabled) return;
        const acts = it.actions || m.actions || [];
        const enter = acts.find((a) => a.key === 'Enter');
        if (enter) { if (!enter.hold) fire(enter); return; }
        if (it.child || it.open) post('action', { menu: m.id, item: it.id, act: 'open', sliders: sliderValues(it) });
    }

    const keyName = (e) => {
        if (e.key === 'Enter') return 'Enter';
        if (e.key === ' ') return 'Space';
        return e.key.length === 1 ? e.key.toUpperCase() : e.key;
    };

    function findAction(k) {
        const m = cur(), it = selItem();
        const acts = (it && it.actions) || (m && m.actions) || [];
        return acts.find((a) => a.key === k);
    }

    function startHold(k, a) {
        const el = actions.querySelector(`.act[data-key="${CSS.escape(k)}"] .fill`);
        const started = performance.now();
        S.hold = { k, a, raf: 0 };
        const tick = () => {
            if (!S.hold || S.hold.k !== k) return;
            const p = Math.min(1, (performance.now() - started) / a.hold);
            if (el) el.style.height = `${p * 100}%`;
            if (p >= 1) { S.hold = null; if (el) el.style.height = '0'; fire(a); return; }
            S.hold.raf = requestAnimationFrame(tick);
        };
        S.hold.raf = requestAnimationFrame(tick);
    }

    function cancelHold() {
        if (!S.hold) return;
        cancelAnimationFrame(S.hold.raf);
        const el = actions.querySelector(`.act[data-key="${CSS.escape(S.hold.k)}"] .fill`);
        if (el) el.style.height = '0';
        S.hold = null;
    }

    window.addEventListener('keydown', (e) => {
        if (!S.open || e.repeat && !['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.key)) return;
        const k = keyName(e);
        if (k === 'ArrowUp') { e.preventDefault(); move(-1); return; }
        if (k === 'ArrowDown') { e.preventDefault(); move(1); return; }
        if (k === 'ArrowLeft') { adjust(-1); return; }
        if (k === 'ArrowRight') { adjust(1); return; }
        if (k === 'Tab') {
            e.preventDefault();
            const m = cur(), it = selItem();
            if (it && it.sliders && it.sliders.length > 1) { S.slider[m.id] = ((S.slider[m.id] || 0) + 1) % it.sliders.length; render(); }
            return;
        }
        if (k === 'Escape' || k === 'Backspace') { cancelHold(); back(); return; }
        if ((k === 'A' || k === 'D') && cur() && cur().rotate && !findAction(k)) { post('rotate', { dir: k === 'A' ? -1 : 1 }); return; }
        const a = findAction(k);
        if (a) {
            const it = selItem();
            if (!it || it.disabled) return;
            if (a.hold) startHold(k, a); else fire(a);
            return;
        }
        if (k === 'Enter') activate();
    });
    window.addEventListener('keyup', (e) => { if (S.hold && keyName(e) === S.hold.k) cancelHold(); });
    window.addEventListener('wheel', (e) => { if (S.open) move(e.deltaY > 0 ? 1 : -1); });
    window.addEventListener('contextmenu', (e) => { e.preventDefault(); if (S.open) back(); });
    $('back-btn').addEventListener('click', back);

    /* ---- messages from the client ---- */
    const H = {
        lang: (d) => { S.lang = d.table || {}; render(); },
        // the page uses pup-ui's fixed menu art, so the theme message is accepted and ignored
        theme: () => {},
        show: (d) => {
            S.open = !!d.on;
            if (S.open) { panel.classList.remove('hidden', 'fading'); render(); preview(); return; }
            cancelHold();
            if (d.instant) { panel.classList.add('hidden'); return; }
            panel.classList.add('fading');
            setTimeout(() => { if (!S.open) panel.classList.add('hidden'); }, 180);
        },
        menu: (d) => { if (d.menu && d.menu.id) { S.menus[d.menu.id] = d.menu; if (S.stack.includes(d.menu.id)) render(); } },
        root: (d) => { S.stack = [d.id]; render(); },
        go: (d) => {
            if (!S.menus[d.id]) return;
            const at = S.stack.indexOf(d.id);
            if (at >= 0) S.stack = S.stack.slice(0, at + 1); else S.stack.push(d.id);
            if (d.reset) { S.sel[d.id] = 0; S.slider[d.id] = 0; }
            if (typeof d.select === 'number') S.sel[d.id] = d.select;
            render(); preview();
        },
        reset: (d) => { if (d.id) { S.sel[d.id] = 0; S.slider[d.id] = 0; } else { S.sel = {}; S.slider = {}; } render(); },
        header: (d) => { $('store-title').textContent = t(d.title, d.raw); },
        cash: (d) => {
            $('cash-money').textContent = money(d.money);
            $('cash-gold').textContent = d.gold !== undefined && d.gold !== null ? `${Number(d.gold) || 0} G` : '';
        },
        equipped: (d) => {
            const m = S.menus[d.menu]; if (!m) return;
            m.items.forEach((i) => { i.equipped = i.id === d.item; if (i.equipped && i.sliders && i.sliders[0] && typeof d.variation === 'number') i.sliders[0].index = d.variation; });
            render();
        },
        visible: (d) => { const m = S.menus[d.menu]; const i = m && m.items.find((x) => x.id === d.item); if (i) { i.hidden = !d.on; render(); } },
        item: (d) => {
            const m = S.menus[d.menu]; const i = m && m.items.find((x) => x.id === d.item); if (!i) return;
            Object.keys(d.fields || {}).forEach((k) => {
                if (k === 'sliders' && Array.isArray(d.fields.sliders) && i.sliders) {
                    d.fields.sliders.forEach((s, n) => { if (s && i.sliders[n]) Object.assign(i.sliders[n], s); });
                } else i[k] = d.fields[k];
            });
            render();
        },
        menuMerge: (d) => { const m = S.menus[d.menu]; if (m) { Object.assign(m, d.fields || {}); render(); } },
        back: () => { if (S.stack.length > 1) { S.stack.pop(); render(); preview(); } },
        repreview: () => preview(),
        sound: () => {},
        bought: (d) => { const m = S.menus[d.menu]; const i = m && m.items.find((x) => x.id === d.item); if (i) { i.right = 'tick'; render(); } },
        // the player's menu side (fred_hud /hud -> pup-ui), the same as every pup-ui menu
        menuSide: (d) => { document.body.classList.toggle('menu-right', d.side === 'right'); },
    };

    window.addEventListener('message', (e) => {
        const d = e.data;
        if (!d || typeof d.type !== 'string' || !Object.prototype.hasOwnProperty.call(H, d.type)) return;
        try { H[d.type](d); } catch (err) { console.error('pup-stable page', err); }
    });

    post('ready', {});
})();
