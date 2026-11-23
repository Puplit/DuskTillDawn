/* pup_ranchero | the collecting minigame page.
   Lua sends: { action: 'start', art, label, cfg, theme } | { action: 'stop' } | { action: 'hide' }
   The page answers once per round: POST gameDone { clicks, spawned }. */
'use strict';

(function () {
    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pup_ranchero';
    const game = document.getElementById('game');
    const field = document.getElementById('field');
    const hudCount = document.getElementById('hud-count');
    const hudTime = document.getElementById('hud-time');
    const hudLabel = document.getElementById('hud-label');

    let round = null;
    let themeApplied = false;

    function post(name, body) {
        return fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).catch(() => {});
    }

    /* pup-ui's theme: colours checked by the browser, fonts only as plain file names from pup-ui/html/fonts */
    function applyTheme(theme) {
        if (themeApplied || !theme || typeof theme !== 'object') return;
        themeApplied = true;
        const root = document.documentElement.style;
        const colors = theme.colors || {};
        const map = { text: '--rg-text', textDim: '--rg-dim', accent: '--rg-accent', danger: '--rg-danger' };
        Object.keys(map).forEach((k) => {
            const v = colors[k];
            if (typeof v === 'string' && window.CSS && CSS.supports('color', v)) root.setProperty(map[k], v);
        });
        const fonts = theme.fonts || {};
        const load = (file, family, cssVar) => {
            if (typeof file !== 'string' || !/^[\w.-]+\.(ttf|otf)$/i.test(file) || typeof FontFace !== 'function') return;
            const face = new FontFace(family, `url(nui://pup-ui/html/fonts/${file})`);
            face.load().then((f) => {
                document.fonts.add(f);
                root.setProperty(cssVar, `'${family}', Georgia, serif`);
            }).catch(() => {});
        };
        load(fonts.title, 'RanchTitle', '--rg-title');
        load(fonts.body, 'RanchBody', '--rg-body');
    }

    function num(v, d, lo, hi) {
        const n = Number(v);
        if (!Number.isFinite(n)) return d;
        return Math.min(hi, Math.max(lo, n));
    }

    function drawHud() {
        if (!round) return;
        const left = Math.max(0, Math.ceil((round.endsAt - performance.now()) / 1000));
        hudCount.textContent = `Collected: ${round.clicks}`;
        hudTime.textContent = String(left);
        hudTime.classList.toggle('low', left <= 5);
    }

    function spawnItem() {
        if (!round || !round.art) return;
        const now = performance.now();
        const progress = Math.min(1, (now - round.startedAt) / round.durationMs);
        const el = document.createElement('div');
        el.className = 'item';
        el.innerHTML = round.art; /* static art from art.js only */
        field.appendChild(el);
        const w = el.offsetWidth || 100;
        const h = el.offsetHeight || 120;
        const maxLeft = Math.max(0, window.innerWidth - w);
        el.style.left = `${Math.random() * maxLeft}px`;
        const rise = (round.cfg.riseMin + Math.random() * (round.cfg.riseMax - round.cfg.riseMin)) * (1 - round.cfg.speedUp * progress);
        const travel = window.innerHeight + h * 2;
        el.style.transitionDuration = `${rise}s`;
        round.spawned += 1;
        const thisRound = round;
        el.addEventListener('mousedown', (ev) => {
            ev.preventDefault();
            if (round !== thisRound || el.classList.contains('got')) return;
            const t = getComputedStyle(el).transform;
            el.style.transform = t === 'none' ? '' : t;
            el.classList.add('got');
            thisRound.clicks += 1;
            drawHud();
            setTimeout(() => el.remove(), 260);
        });
        requestAnimationFrame(() => {
            requestAnimationFrame(() => { el.style.transform = `translateY(-${travel}px)`; });
        });
        setTimeout(() => { if (!el.classList.contains('got')) el.remove(); }, rise * 1000 + 300);
    }

    function scheduleSpawn() {
        if (!round) return;
        const progress = Math.min(1, (performance.now() - round.startedAt) / round.durationMs);
        const interval = round.cfg.spawnMs * (1 - (1 - round.cfg.spawnShrink) * progress);
        round.spawnTimer = setTimeout(() => {
            if (!round) return;
            spawnItem();
            scheduleSpawn();
        }, interval);
    }

    function clearField() {
        while (field.firstChild) field.removeChild(field.firstChild);
    }

    function endRound() {
        if (!round) return;
        const r = round;
        round = null;
        clearTimeout(r.spawnTimer);
        clearInterval(r.hudTimer);
        clearTimeout(r.endTimer);
        clearField();
        game.classList.add('hidden');
        post('gameDone', { clicks: r.clicks, spawned: r.spawned });
    }

    function start(data) {
        if (round) endRound();
        applyTheme(data.theme);
        const cfg = data.cfg || {};
        const seconds = num(cfg.seconds, 30, 5, 120);
        round = {
            art: (window.RANCH_ART || {})[String(data.art)] || '',
            cfg: {
                spawnMs: num(cfg.spawnMs, 700, 150, 5000),
                riseMin: num(cfg.riseMin, 1.8, 0.3, 20),
                riseMax: num(cfg.riseMax, 4.2, 0.3, 20),
                speedUp: num(cfg.speedUp, 0.3, 0, 0.9),
                spawnShrink: num(cfg.spawnShrink, 0.65, 0.1, 1),
            },
            durationMs: seconds * 1000,
            startedAt: performance.now(),
            endsAt: performance.now() + seconds * 1000,
            clicks: 0,
            spawned: 0,
        };
        if (round.cfg.riseMax < round.cfg.riseMin) round.cfg.riseMax = round.cfg.riseMin;
        clearField();
        hudLabel.textContent = typeof data.label === 'string' ? data.label : '';
        game.classList.remove('hidden');
        drawHud();
        round.hudTimer = setInterval(drawHud, 200);
        round.endTimer = setTimeout(endRound, round.durationMs);
        spawnItem();
        scheduleSpawn();
    }

    window.addEventListener('message', (ev) => {
        const d = ev.data;
        if (!d || typeof d !== 'object') return;
        if (d.action === 'start') start(d);
        else if (d.action === 'stop') endRound();
        else if (d.action === 'hide') {
            if (round) { const r = round; round = null; clearTimeout(r.spawnTimer); clearInterval(r.hudTimer); clearTimeout(r.endTimer); }
            clearField();
            game.classList.add('hidden');
        }
    });
}());
