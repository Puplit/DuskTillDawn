'use strict';
// pup_tailor dye book. Every piece of player text goes in through textContent.
(function () {
  const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pup_tailor';
  const $ = (id) => document.getElementById(id);

  const st = {
    open: false,
    palettes: [],
    names: {},
    channels: ['Primary', 'Secondary', 'Trim'],
    text: {},
    materials: { flat: [], perGarment: [] },
    items: [],
    item: null,      // { id, label, rows: [{slot,label}], edits: { slot: {palette,c1,c2,c3,edited} } }
    sel: 0,
    clip: null,
    lastSave: 0,
    holdSlot: null,
  };

  function post(name, data) {
    return fetch('https://' + RES + '/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(() => {});
  }

  function stripMarkup(s) {
    return String(s == null ? '' : s).replace(/<[^>]*>/g, '');
  }

  function fmt(tpl, value) {
    return String(tpl || '').replace(/%[sd]/, String(value));
  }

  // ---------------------------------------------------------------- theme
  function applyTheme(theme) {
    if (!theme || typeof theme !== 'object') return;
    const c = theme.colors || {};
    const map = { background: '--bg', text: '--text', textDim: '--dim', accent: '--accent', selected: '--sel', danger: '--danger', good: '--good', border: '--border' };
    const root = document.documentElement.style;
    Object.keys(map).forEach((k) => { if (typeof c[k] === 'string') root.setProperty(map[k], c[k]); });
    const f = theme.fonts || {};
    const safe = (v) => typeof v === 'string' && /^[\w.\-]+\.[ot]tf$/.test(v);
    let css = '';
    if (safe(f.title)) { css += "@font-face{font-family:'TailorTitle';src:url('nui://pup-ui/html/fonts/" + f.title + "');}"; root.setProperty('--title-font', "'TailorTitle', Georgia, serif"); }
    if (safe(f.body)) { css += "@font-face{font-family:'TailorBody';src:url('nui://pup-ui/html/fonts/" + f.body + "');}"; root.setProperty('--body-font', "'TailorBody', Georgia, serif"); }
    if (css) {
      let tag = document.getElementById('theme-fonts');
      if (!tag) { tag = document.createElement('style'); tag.id = 'theme-fonts'; document.head.appendChild(tag); }
      tag.textContent = css;
    }
  }

  // ---------------------------------------------------------------- toast
  let toastTimer = null;
  function toast(text, bad) {
    const el = $('toast');
    el.textContent = stripMarkup(text);
    el.classList.toggle('bad', !!bad);
    el.classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.add('hidden'), 6000);
  }

  // ---------------------------------------------------------------- helpers
  function paletteName(hash) {
    const key = String(hash);
    if (st.names && typeof st.names[key] === 'string' && st.names[key] !== '') return st.names[key];
    const idx = st.palettes.indexOf(hash);
    return fmt(st.text.palette || 'Palette %d', idx + 1);
  }

  function current() {
    if (!st.item || !st.item.rows.length) return null;
    const row = st.item.rows[st.sel];
    return row ? { row: row, edit: st.item.edits[row.slot] } : null;
  }

  function editedSlots() {
    if (!st.item) return [];
    return st.item.rows.filter((r) => st.item.edits[r.slot].edited).map((r) => r.slot);
  }

  function costText(n) {
    if (n <= 0) return '';
    const flat = st.materials.flat || [];
    const per = st.materials.perGarment || [];
    if (!flat.length && !per.length) return st.text.free || 'Free';
    const order = [];
    const by = {};
    const add = (m, mult) => {
      const cnt = (Number(m.count) || 0) * mult;
      if (cnt <= 0) return;
      if (!by[m.name]) { by[m.name] = { label: m.label || m.name, count: 0 }; order.push(by[m.name]); }
      by[m.name].count += cnt;
    };
    flat.forEach((m) => add(m, 1));
    per.forEach((m) => add(m, n));
    return order.map((e) => e.count + 'x ' + e.label).join(', ');
  }

  function sendTint(slot, e) {
    post('tint', { slot: slot, palette: e.palette, c1: e.c1, c2: e.c2, c3: e.c3 });
  }

  // ---------------------------------------------------------------- screens
  function showList() {
    $('scr-edit').classList.add('hidden');
    $('scr-list').classList.remove('hidden');
    // the camera keys move the mannequin, which only stands there once an outfit is picked
    $('bk-keys').classList.add('hidden');
    $('bk-sub').textContent = st.text.pick || '';
    const box = $('list-items');
    box.textContent = '';
    st.items.forEach((it) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'item-btn';
      const l = document.createElement('span');
      l.className = 'lbl';
      l.textContent = String(it.label || '');
      const d = document.createElement('span');
      d.className = 'dsc';
      d.textContent = String(it.description || '');
      b.appendChild(l);
      b.appendChild(d);
      b.addEventListener('click', () => {
        st.pendingLabel = String(it.label || '');
        post('pick', { id: it.id });
      });
      box.appendChild(b);
    });
    const empty = $('list-empty');
    empty.textContent = st.text.empty || '';
    empty.classList.toggle('hidden', st.items.length > 0);
  }

  function showEdit() {
    $('scr-list').classList.add('hidden');
    $('scr-edit').classList.remove('hidden');
    $('bk-keys').classList.remove('hidden');
    $('bk-sub').textContent = st.item ? st.item.label : '';
    renderGarments();
    renderTools();
  }

  function renderGarments() {
    const ul = $('ed-garments');
    ul.textContent = '';
    if (!st.item) return;
    st.item.rows.forEach((r, i) => {
      const li = document.createElement('li');
      li.setAttribute('role', 'option');
      if (i === st.sel) li.classList.add('sel');
      if (st.item.edits[r.slot].edited) li.classList.add('edited');
      const dot = document.createElement('span');
      dot.className = 'dot';
      const t = document.createElement('span');
      t.textContent = String(r.label || r.slot);
      li.appendChild(dot);
      li.appendChild(t);
      li.addEventListener('click', () => { st.sel = i; renderGarments(); renderTools(); });
      ul.appendChild(li);
    });
  }

  function renderTools() {
    const cur = current();
    const grid = $('ed-grid');
    grid.textContent = '';
    st.palettes.forEach((h, i) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = String(i + 1);
      b.title = paletteName(h);
      if (cur && cur.edit.palette === h) b.classList.add('on');
      b.addEventListener('click', () => {
        const c = current();
        if (!c) return;
        c.edit.palette = h;
        c.edit.edited = true;
        sendTint(c.row.slot, c.edit);
        renderGarments(); renderTools();
      });
      grid.appendChild(b);
    });
    $('pal-name').textContent = cur ? paletteName(cur.edit.palette) : '';

    const box = $('ed-sliders');
    box.textContent = '';
    ['c1', 'c2', 'c3'].forEach((k, i) => {
      const wrap = document.createElement('label');
      wrap.className = 'sl';
      const name = document.createElement('span');
      name.textContent = String(st.channels[i] || '');
      const input = document.createElement('input');
      input.type = 'range'; input.min = '0'; input.max = '255'; input.step = '1';
      input.value = cur ? String(cur.edit[k]) : '0';
      input.disabled = !cur;
      const val = document.createElement('span');
      val.className = 'val';
      val.textContent = input.value;
      input.addEventListener('input', () => {
        const c = current();
        if (!c) return;
        c.edit[k] = Math.max(0, Math.min(255, parseInt(input.value, 10) || 0));
        c.edit.edited = true;
        val.textContent = String(c.edit[k]);
        sendTint(c.row.slot, c.edit);
        markRow();
        $('ed-cost').textContent = costLine();
      });
      wrap.appendChild(name); wrap.appendChild(input); wrap.appendChild(val);
      box.appendChild(wrap);
    });
    $('ed-cost').textContent = costLine();
  }

  function markRow() {
    const lis = $('ed-garments').children;
    if (!st.item) return;
    st.item.rows.forEach((r, i) => {
      if (lis[i]) lis[i].classList.toggle('edited', st.item.edits[r.slot].edited);
    });
  }

  function costLine() {
    const n = editedSlots().length;
    const t = costText(n);
    return t ? fmt(st.text.cost || '%s', t) : '';
  }

  function moveSel(d) {
    if (!st.item || !st.item.rows.length) return;
    const n = st.item.rows.length;
    st.sel = (st.sel + d + n) % n;
    renderGarments(); renderTools();
  }

  // ---------------------------------------------------------------- buttons
  $('bk-close').addEventListener('click', () => post('close'));
  $('ed-back').addEventListener('click', () => {
    st.item = null;
    post('back');
    showList();
  });
  $('pal-btn').addEventListener('click', () => {
    const cur = current();
    if (!cur) return;
    const input = $('pal-input');
    const name = input.value.slice(0, 24);
    input.value = '';
    post('name', { palette: cur.edit.palette, name: name });
  });
  $('ed-copy').addEventListener('click', () => {
    const cur = current();
    if (cur) st.clip = { palette: cur.edit.palette, c1: cur.edit.c1, c2: cur.edit.c2, c3: cur.edit.c3 };
  });
  $('ed-paste').addEventListener('click', () => {
    const cur = current();
    if (!cur || !st.clip) return;
    Object.assign(cur.edit, st.clip, { edited: true });
    sendTint(cur.row.slot, cur.edit);
    renderGarments(); renderTools();
  });
  $('ed-undye').addEventListener('click', () => {
    const cur = current();
    if (!cur) return;
    cur.edit.palette = st.palettes[0];
    cur.edit.c1 = 0; cur.edit.c2 = 0; cur.edit.c3 = 0;
    cur.edit.edited = false;
    post('undye', { slot: cur.row.slot });
    renderGarments(); renderTools();
  });
  $('ed-before').addEventListener('mousedown', () => {
    const cur = current();
    if (!cur) return;
    st.holdSlot = cur.row.slot;
    post('before', { slot: cur.row.slot, down: true });
  });
  window.addEventListener('mouseup', () => {
    if (!st.holdSlot || !st.item) { st.holdSlot = null; return; }
    const slot = st.holdSlot;
    st.holdSlot = null;
    const e = st.item.edits[slot];
    post('before', { slot: slot, down: false, edit: e && e.edited ? { palette: e.palette, c1: e.c1, c2: e.c2, c3: e.c3 } : null });
  });
  $('ed-save').addEventListener('click', () => {
    if (!st.item) return;
    if (st.preview) { toast(st.text.onlyTailor, true); return; }
    const slots = editedSlots();
    if (!slots.length) { toast(st.text.colourFirst, true); return; }
    const now = Date.now();
    if (now - st.lastSave < 3000) return;
    st.lastSave = now;
    const colours = {};
    slots.forEach((s) => {
      const e = st.item.edits[s];
      colours[s] = { palette: e.palette, color1: e.c1, color2: e.c2, color3: e.c3 };
    });
    post('save', { colours: colours });
  });

  // ---------------------------------------------------------------- keys
  const camKeys = { q: 'left', e: 'right', shift: 'zoomIn', control: 'zoomOut', ' ': 'up', alt: 'down', x: 'reset' };
  window.addEventListener('keydown', (ev) => {
    if (!st.open) return;
    const typing = document.activeElement && document.activeElement.tagName === 'INPUT' && document.activeElement.type === 'text';
    if (ev.key === 'Escape') {
      ev.preventDefault();
      if (typing) { document.activeElement.blur(); return; }
      post('close');
      return;
    }
    if (typing) return;
    const k = ev.key.toLowerCase();
    if (k === 'w') { ev.preventDefault(); moveSel(-1); return; }
    if (k === 's') { ev.preventDefault(); moveSel(1); return; }
    if (camKeys[k]) { ev.preventDefault(); post('cam', { action: camKeys[k] }); }
  });

  // ---------------------------------------------------------------- messages from the game
  function setText() {
    const t = st.text;
    $('bk-title').textContent = t.title || '';
    $('ed-back').textContent = t.back || '';
    $('pal-input').placeholder = t.namePlaceholder || '';
    $('pal-btn').textContent = t.nameBtn || '';
    $('ed-copy').textContent = t.copy || '';
    $('ed-paste').textContent = t.paste || '';
    $('ed-undye').textContent = t.undye || '';
    $('ed-before').textContent = t.before || '';
    $('ed-save').textContent = t.save || '';
    $('bk-keys').textContent = t.keys || '';
  }

  const handlers = {
    open(d) {
      st.open = true;
      st.palettes = Array.isArray(d.palettes) ? d.palettes.map(Number) : [];
      st.names = d.names && typeof d.names === 'object' ? d.names : {};
      st.channels = Array.isArray(d.channels) ? d.channels : st.channels;
      st.text = d.text || {};
      st.materials = d.materials || { flat: [], perGarment: [] };
      st.preview = !!d.preview;
      st.items = Array.isArray(d.items) ? d.items : [];
      st.item = null; st.sel = 0; st.lastSave = 0; st.holdSlot = null;
      applyTheme(d.theme);
      // the player's menu side; the mannequin is framed on the other side
      document.body.classList.toggle('menu-right', d.side === 'right');
      setText();
      showList();
      $('toast').classList.add('hidden');
      $('book').classList.remove('hidden');
      post('ready');
    },
    close() {
      st.open = false;
      st.item = null;
      $('book').classList.add('hidden');
      $('toast').classList.add('hidden');
    },
    names(d) {
      st.names = d && typeof d === 'object' ? d : {};
      if (st.item) renderTools();
    },
    item(d) {
      const rows = Array.isArray(d.rows) ? d.rows : [];
      const edits = {};
      rows.forEach((r) => { edits[r.slot] = { palette: st.palettes[0], c1: 0, c2: 0, c3: 0, edited: false }; });
      st.item = { id: d.id, label: st.pendingLabel || '', rows: rows, edits: edits };
      st.sel = 0;
      showEdit();
    },
    toast(d) { toast(d.text, d.bad); },
    saved(d) {
      st.item = null;
      st.items = Array.isArray(d.items) ? d.items : [];
      showList();
      toast(d.message, false);
    },
  };

  window.addEventListener('message', (ev) => {
    const m = ev.data;
    if (!m || typeof m.action !== 'string' || !handlers[m.action]) return;
    handlers[m.action](m.data || {});
  });
})();
