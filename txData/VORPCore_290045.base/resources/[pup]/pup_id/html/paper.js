// pup_id | identity paper page
// Every value from the game goes in through textContent. The page never takes focus; the game
// tells it when to show and when to hide, and it reports back once a paper has faded out.
// The fonts are bundled in html/fonts, so the theme fonts sent with the setup are not used.
(function () {
    'use strict';

    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pup_id';
    const FADE_MS = 320;
    const SVG_NS = 'http://www.w3.org/2000/svg';

    const paper = document.getElementById('paper');
    const el = {
        number: document.getElementById('f-number'),
        serial: document.getElementById('f-serial'),
        name: document.getElementById('f-name'),
        occupation: document.getElementById('f-occupation'),
        issued: document.getElementById('f-issued'),
        signature: document.getElementById('f-signature'),
    };

    let currentSeq = 0;
    let hideTimer = null;

    function post(name, body) {
        return fetch('https://' + RES + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).then(function (r) { return r.json(); }).catch(function () { return null; });
    }

    function str(v) {
        return v === undefined || v === null ? '' : String(v);
    }

    function titleCase(s) {
        return str(s).split(/(\s+)/).map(function (w) {
            return w.charAt(0).toUpperCase() + w.slice(1);
        }).join('');
    }

    // --- drawing: guilloche rosette, thumbprint and the wax seal's edge ---

    function addPath(parent, d, attrs) {
        const p = document.createElementNS(SVG_NS, 'path');
        p.setAttribute('d', d);
        if (attrs) Object.keys(attrs).forEach(function (k) { p.setAttribute(k, attrs[k]); });
        parent.appendChild(p);
        return p;
    }

    // Closed path through points of f(t) for t in [0, span].
    function curve(f, span, steps) {
        let d = '';
        for (let i = 0; i <= steps; i++) {
            const pt = f(span * i / steps);
            d += (i ? 'L' : 'M') + pt[0].toFixed(2) + ' ' + pt[1].toFixed(2);
        }
        return d + 'Z';
    }

    function polar(r, t) {
        return [r * Math.cos(t), r * Math.sin(t)];
    }

    function drawRosette() {
        const g = document.getElementById('rosette');
        if (!g) return;
        const TAU = Math.PI * 2;
        // outer band: interlaced waves
        for (let i = 0; i < 5; i++) {
            const ph = i * TAU / 5;
            addPath(g, curve(function (t) {
                return polar(198 + 11 * Math.sin(24 * t + ph), t);
            }, TAU, 1200));
        }
        // middle band
        for (let i = 0; i < 4; i++) {
            const ph = i * TAU / 4;
            addPath(g, curve(function (t) {
                return polar(150 + 16 * Math.sin(16 * t + ph), t);
            }, TAU, 1000));
        }
        // inner hypotrochoid flower
        [[96, 36, 62], [96, 36, 48]].forEach(function (k) {
            const R = k[0], r = k[1], d = k[2];
            addPath(g, curve(function (t) {
                return [
                    (R - r) * Math.cos(t) + d * Math.cos((R - r) / r * t),
                    (R - r) * Math.sin(t) - d * Math.sin((R - r) / r * t),
                ];
            }, TAU * 3, 1400));
        });
        // fine looping ring between the flower and the middle band
        addPath(g, curve(function (t) {
            const a = 118 + 6 * Math.cos(40 * t);
            return [a * Math.cos(t) + 4 * Math.cos(41 * t), a * Math.sin(t) + 4 * Math.sin(41 * t)];
        }, TAU, 2400));
    }

    function drawThumb() {
        const svg = document.getElementById('thumb');
        if (!svg) return;
        // a whorl: nested, slightly wavy loops, each broken by a short gap like a real ridge
        for (let i = 1; i <= 15; i++) {
            const rx = 2.2 + i * 2.25;
            const ry = 3.2 + i * 2.95;
            const gapAt = 0.6 + i * 0.83;
            const gap = 0.32 + (i % 3) * 0.1;
            let d = '';
            const steps = 90;
            for (let s = 0; s <= steps; s++) {
                const t = gapAt + gap + (Math.PI * 2 - gap) * s / steps;
                const wob = 1 + 0.035 * Math.sin(t * 5 + i) + 0.02 * Math.sin(t * 9 - i * 0.7);
                const x = rx * wob * Math.cos(t);
                const y = ry * wob * Math.sin(t) + 2;
                d += (s ? 'L' : 'M') + x.toFixed(2) + ' ' + y.toFixed(2);
            }
            addPath(svg, d);
        }
    }

    function drawSealEdge() {
        const blob = document.getElementById('seal-blob');
        if (!blob) return;
        blob.setAttribute('d', curve(function (t) {
            const r = 48 + 2.6 * Math.sin(7 * t) + 1.9 * Math.sin(11 * t + 1.3) + 1.3 * Math.sin(19 * t + 2.1)
                + (Math.cos(t - 0.9) > 0.96 ? 5 * (Math.cos(t - 0.9) - 0.96) / 0.04 : 0);
            return polar(r, t);
        }, Math.PI * 2, 360));
    }

    drawRosette();
    drawThumb();
    drawSealEdge();

    // --- filling in ---

    // Shrinks a one-line field until its text fits, starting from the stylesheet size.
    function fit(node) {
        node.style.fontSize = '';
        let size = parseFloat(window.getComputedStyle(node).fontSize) || 16;
        const floor = Math.max(6, size * 0.35);
        while (node.scrollWidth > node.clientWidth + 1 && size > floor) {
            size -= 0.5;
            node.style.fontSize = size + 'px';
        }
    }

    function fitAll() {
        fit(el.name);
        fit(el.occupation);
        fit(el.signature);
        fit(el.issued);
        fit(el.serial);
    }

    function setWords(words) {
        if (!words || typeof words !== 'object') return;
        document.querySelectorAll('[data-word]').forEach(function (node) {
            const key = node.getAttribute('data-word');
            if (typeof words[key] === 'string') node.textContent = words[key];
        });
    }

    function show(seq, data) {
        if (!data || typeof data !== 'object') return;
        currentSeq = seq;
        if (hideTimer) { clearTimeout(hideTimer); hideTimer = null; }

        const name = str(data.name).trim();
        el.number.textContent = str(data.number);
        el.name.textContent = name;
        el.signature.textContent = name;
        el.occupation.textContent = titleCase(data.occupation);
        el.issued.textContent = str(data.issued);

        paper.classList.add('present');
        fitAll();
        // fit again once every web font has arrived
        if (document.fonts && document.fonts.ready) document.fonts.ready.then(fitAll);
        requestAnimationFrame(function () {
            requestAnimationFrame(function () { paper.classList.add('shown'); });
        });
    }

    function hide() {
        const seq = currentSeq;
        paper.classList.remove('shown');
        if (hideTimer) clearTimeout(hideTimer);
        const reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        hideTimer = setTimeout(function () {
            hideTimer = null;
            paper.classList.remove('present');
            post('closed', { seq: seq });
        }, reduced ? 0 : FADE_MS + 40);
    }

    window.addEventListener('message', function (event) {
        const msg = event.data;
        if (!msg || typeof msg !== 'object') return;
        if (msg.action === 'show') {
            if (msg.setup && typeof msg.setup === 'object') applySetup(msg.setup);
            show(Number(msg.seq) || 0, msg.paper);
        } else if (msg.action === 'hide') hide();
    });

    let setupDone = false;
    function applySetup(setup) {
        if (setupDone) return;
        setupDone = true;
        setWords(setup.words);
        if (paper.classList.contains('present')) fitAll();
    }

    // The client script may not have registered its callback yet when the page loads: retry a while.
    let readyTries = 0;
    function askReady() {
        if (setupDone) return;
        readyTries++;
        post('ready', {}).then(function (setup) {
            if (setup && typeof setup === 'object') applySetup(setup);
            else if (readyTries < 30) setTimeout(askReady, 1000);
        });
    }
    askReady();
})();
