/* vorp_character - character select + spawn picker.
   Lua (client/client.lua, client/menu.lua) sends: cs:open, cs:close, sp:open, sp:close.
   This page posts: cs_look, cs_play, cs_create, cs_delete, sp_pick. */

(() => {
    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'vorp_character';
    const post = (name, body) => fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body || {}),
    }).catch(() => {});

    const $ = (id) => document.getElementById(id);
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g,
        (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    /* ---------------------------------------------------- character select */

    let chars = [];        // real characters
    let slots = [];        // chars + empty "create" slots
    let cur = 0;           // index into slots
    let showGold = false;
    let canDelete = false;
    let csOpen = false;
    let lastLook = -1;     // don't re-fire the camera for the slot we're already on

    const money = (n) => {
        const v = Number(n);
        return '$' + (isFinite(v) ? v : 0).toLocaleString('en-US', {
            minimumFractionDigits: 2, maximumFractionDigits: 2,
        });
    };

    /* "4h ago", "3 days ago" - the card wants a glance, not a timestamp */
    const sinceText = (epoch) => {
        const t = Number(epoch);
        if (!isFinite(t) || t <= 0) return 'Never';
        const secs = Math.floor(Date.now() / 1000) - t;
        if (secs < 120) return 'Just now';
        const mins = Math.floor(secs / 60);
        if (mins < 60) return `${mins} min ago`;
        const hrs = Math.floor(mins / 60);
        if (hrs < 24) return `${hrs}h ago`;
        const days = Math.floor(hrs / 24);
        if (days < 31) return days === 1 ? 'Yesterday' : `${days} days ago`;
        const months = Math.floor(days / 30);
        if (months < 12) return months === 1 ? 'A month ago' : `${months} months ago`;
        const years = Math.floor(days / 365);
        return years <= 1 ? 'A year ago' : `${years} years ago`;
    };

    /* 95 -> "1h 35m", so a long sentence does not read as a wall of minutes */
    const jailText = (mins) => {
        const m = Math.max(0, Math.floor(Number(mins) || 0));
        if (m < 60) return `${m} min left`;
        const h = Math.floor(m / 60), r = m % 60;
        return r ? `${h}h ${r}m left` : `${h}h left`;
    };

    function renderInfo(c) {
        const box = $('csInfo');
        if (!c) { box.innerHTML = ''; return; }
        const rows = [];
        if (c.job) rows.push(['Job', c.job, '']);
        rows.push(['Cash', money(c.money), 'coin']);
        if (showGold) rows.push(['Gold', Number(c.gold || 0).toFixed(2), 'coin']);
        if (c.where) rows.push(['Last seen', c.where, '']);
        rows.push(['Last played', sinceText(c.lastPlayed), '']);
        if (c.charId != null) rows.push(['Character ID', `#${c.charId}`, 'dim']);
        box.innerHTML = rows.map(([k, v, cls]) =>
            `<div class="cs-row"><span class="k">${esc(k)}</span><span class="v ${cls}">${esc(v)}</span></div>`).join('');
    }

    function renderDetail() {
        const s = slots[cur];
        const isNew = !s || s.create;
        $('csName').innerHTML = isNew ? 'New Character' : esc(`${s.firstname} ${s.lastname}`);

        let sub = '';
        if (isNew) {
            sub = 'An empty slot';
        } else {
            // gender only - the group is always "USER" and reads as noise
            sub = s.gender || ' '
        }
        $('csSub').textContent = sub;

        // both can be true at once: downed in a cell is a real state
        let badges = '';
        if (!isNew) {
            if (s.isDead) badges += '<span class="cs-badge">Down</span>';
            if (s.jail) badges += `<span class="cs-badge jail">In jail &middot; ${esc(jailText(s.jail))}</span>`;
        }
        $('csBadgeWrap').innerHTML = badges;

        renderInfo(isNew ? null : s);

        // no Play button: Enter (or a double-click) does it, so the hint carries
        // the wording instead of a button that repeats the same action
        $('csHint').innerHTML = isNew
            ? '<b>W/S</b> or <b>&uarr;&darr;</b> to look &middot; <b>Enter</b> to create'
            : '<b>W/S</b> or <b>&uarr;&darr;</b> to look &middot; <b>Enter</b> to play';
        $('csDelete').classList.toggle('hidden', isNew || !canDelete);
        resetHold();
    }

    function renderList() {
        const box = $('csList');
        box.innerHTML = slots.map((s, i) => {
            const sel = i === cur ? ' sel' : '';
            if (s.create) {
                return `<div class="cs-slot empty${sel}" data-i="${i}">` +
                       `<span class="num">${i + 1}</span><span class="nm">New Character</span>` +
                       `<span class="tag">Empty</span></div>`;
            }
            const dead = s.isDead ? ' dead' : '';
            // jail outranks down in the list: it is the one with time attached
            const tag = s.jail ? 'In jail' : (s.isDead ? 'Down' : '');
            const tagCls = s.jail ? ' jail' : '';
            return `<div class="cs-slot${dead}${sel}" data-i="${i}">` +
                   `<span class="num">${i + 1}</span>` +
                   `<span class="nm">${esc(`${s.firstname} ${s.lastname}`)}</span>` +
                   `<span class="tag${tagCls}">${tag}</span></div>`;
        }).join('');

        Array.from(box.children).forEach((el) => {
            el.addEventListener('click', () => select(Number(el.dataset.i)));
            el.addEventListener('dblclick', confirmSlot);
        });

        const total = slots.length;
        $('csCount').textContent = `Characters — ${chars.length} of ${total}`;
        const el = box.children[cur];
        if (el) el.scrollIntoView({ block: 'nearest' });
    }

    function select(i, silent) {
        if (!slots.length) return;
        cur = (i + slots.length) % slots.length;
        renderList();
        renderDetail();
        // only swing the camera for a real character, and never twice for the same one
        const s = slots[cur];
        if (!silent && s && !s.create && lastLook !== cur) {
            lastLook = cur;
            post('cs_look', { index: s.index });
        }
    }

    function confirmSlot() {
        const s = slots[cur];
        if (!s) return;
        csOpen = false;
        if (s.create) post('cs_create');
        else post('cs_play', { index: s.index });
    }

    /* hold-to-delete: no accidental wipes from a stray Enter */
    let holdTimer = null, holdStart = 0;
    const HOLD_MS = 1400;

    function resetHold() {
        if (holdTimer) { cancelAnimationFrame(holdTimer); holdTimer = null; }
        const f = $('csDelete').querySelector('.fill');
        if (f) f.style.width = '0%';
        const l = $('csDelete').querySelector('.lbl');
        if (l) l.textContent = 'Hold to delete';
    }

    function holdStep() {
        const pct = Math.min(1, (performance.now() - holdStart) / HOLD_MS);
        $('csDelete').querySelector('.fill').style.width = `${pct * 100}%`;
        if (pct >= 1) {
            const s = slots[cur];
            resetHold();
            if (s && !s.create) { csOpen = false; post('cs_delete', { index: s.index }); }
            return;
        }
        holdTimer = requestAnimationFrame(holdStep);
    }

    function beginHold() {
        const s = slots[cur];
        if (!s || s.create || !canDelete) return;
        resetHold();
        $('csDelete').querySelector('.lbl').textContent = 'Keep holding…';
        holdStart = performance.now();
        holdTimer = requestAnimationFrame(holdStep);
    }

    function openCS(d) {
        chars = d.characters || [];
        showGold = !!d.showGold;
        canDelete = !!d.canDelete;
        const max = Number(d.max || chars.length) || chars.length;

        slots = chars.map((c) => ({ ...c, create: false }));
        for (let i = chars.length; i < max; i++) slots.push({ create: true });
        if (!slots.length) slots.push({ create: true });

        cur = 0;
        lastLook = -1;
        $('csTitle').textContent = (d.title || 'Characters').toUpperCase();
        $('CharSelect').classList.remove('hidden');
        $('CharSelect').classList.add('cs-fade');
        csOpen = true;
        // silent: Lua already framed the first character when the scene opened
        select(0, true);
        lastLook = slots[0] && !slots[0].create ? 0 : -1;
    }

    function closeCS() {
        csOpen = false;
        resetHold();
        $('CharSelect').classList.add('hidden');
        $('CharSelect').classList.remove('cs-fade');
    }

    /* -------------------------------------------------------- spawn picker */

    let towns = [], spCur = 0, spOpen = false;

    function renderSpawn() {
        const t = towns[spCur] || {};
        $('spTown').textContent = t.label || '';
        $('spLore').textContent = t.desc || '';
        $('spDots').innerHTML = towns.map((_, i) =>
            `<span class="sp-dot${i === spCur ? ' on' : ''}" data-i="${i}"></span>`).join('');
        Array.from($('spDots').children).forEach((el) => {
            el.addEventListener('click', () => { spCur = Number(el.dataset.i); renderSpawn(); });
        });
    }

    const spStep = (d) => { if (towns.length) { spCur = (spCur + d + towns.length) % towns.length; renderSpawn(); } };

    function openSP(d) {
        towns = d.towns || [];
        spCur = 0;
        if (d.kicker) $('spKicker').textContent = d.kicker;
        renderSpawn();
        $('SpawnPick').classList.remove('hidden');
        $('SpawnPick').classList.add('cs-fade');
        spOpen = true;
    }

    function closeSP() {
        spOpen = false;
        $('SpawnPick').classList.add('hidden');
        $('SpawnPick').classList.remove('cs-fade');
    }

    // index is 1-based for Lua; null = let the server roll for one
    const pickSpawn = (idx) => { closeSP(); post('sp_pick', { index: idx }); };

    /* ---------------------------------------------------------------- wire */

    document.addEventListener('DOMContentLoaded', () => {
        const del = $('csDelete');
        del.addEventListener('mousedown', beginHold);
        del.addEventListener('mouseup', resetHold);
        del.addEventListener('mouseleave', resetHold);

        $('spPrev').addEventListener('click', () => spStep(-1));
        $('spNext').addEventListener('click', () => spStep(1));
        $('spConfirm').addEventListener('click', () => pickSpawn(spCur + 1));
        $('spRandom').addEventListener('click', () => pickSpawn(null));
    });

    window.addEventListener('message', (ev) => {
        const d = ev.data || {};
        switch (d.type) {
            case 'cs:open':  openCS(d);  break;
            case 'cs:close': closeCS();  break;
            case 'sp:open':  openSP(d);  break;
            case 'sp:close': closeSP();  break;
        }
    });

    document.addEventListener('keydown', (e) => {
        if (spOpen) {
            if (e.key === 'ArrowLeft'  || e.key === 'a' || e.key === 'A') { spStep(-1); e.preventDefault(); }
            if (e.key === 'ArrowRight' || e.key === 'd' || e.key === 'D') { spStep(1);  e.preventDefault(); }
            if (e.key === 'Enter') { pickSpawn(spCur + 1); e.preventDefault(); }
            return;
        }
        if (!csOpen) return;
        if (e.key === 'ArrowUp'   || e.key === 'w' || e.key === 'W') { select(cur - 1); e.preventDefault(); }
        if (e.key === 'ArrowDown' || e.key === 's' || e.key === 'S') { select(cur + 1); e.preventDefault(); }
        if (e.key === 'Enter') { confirmSlot(); e.preventDefault(); }
        // Delete still has to be held, so the key repeat drives the same fill
        if (e.key === 'Delete' && !holdTimer) { beginHold(); e.preventDefault(); }
    });

    document.addEventListener('keyup', (e) => {
        if (e.key === 'Delete') resetHold();
    });
})();
