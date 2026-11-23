/* The tile pyramid and the world transform are vorp_admin's, so a pin here
   lands exactly where the admin live map puts the same coordinate. */
const WM = { radius: 16000, xOff: 8515, yOff: 10850, w: 11820, h: 8660 };
const IMG_W = 7200, IMG_H = 5400, TILE_MAX_Z = 5;

/* The tileset is mostly empty parchment around the edges. Framing the land
   itself instead of the whole sheet roughly doubles how big the map reads. */
/* Framed with room around the outermost towns, not tight to the land. Tumbleweed
   sits at the western extreme and Annesburg at the eastern one, so a crop that
   stops at the land left both of them pinned against an edge and dimmed by the
   falloff. There is still map either side of this, so no blank border shows. */
const CROP = { x0: 950, y0: 630, x1: 6650, y1: 4683 };

/* How far back to stand. 1.0 frames the land tightly; higher zooms out but
   immediately shows the blank parchment border, because CROP is already the
   exact edge of the land. Leave it at 1.0 unless you want that border. */
const PULL_BACK = 1.0;

/* Standing back without widening the frame. 1.0 fills the screen exactly;
   above that the map shrinks and the margin falls to BLACK rather than to the
   sheet's parchment border, which the edge gradient then swallows. 1.11 is the
   ceiling before that border outgrows the gradient; 1.0 is as far IN as it
   goes, where the view sits exactly on the edges of the territory. */
const ZOOM_OUT = 1.0;

const VIEW = (() => {
    const cx = (CROP.x0 + CROP.x1) / 2;
    const cy = (CROP.y0 + CROP.y1) / 2;
    const hw = ((CROP.x1 - CROP.x0) / 2) * PULL_BACK;
    const hh = ((CROP.y1 - CROP.y0) / 2) * PULL_BACK;
    return {
        x0: Math.max(0, cx - hw), x1: Math.min(IMG_W, cx + hw),
        y0: Math.max(0, cy - hh), y1: Math.min(IMG_H, cy + hh),
    };
})();

// true prints the measured view and zoom to F8, for when the framing is off
const DEBUG = false;

const wrap = document.getElementById('wrap');
const timerEl = document.getElementById('timer');
const confirmBtn = document.getElementById('confirm');
const panel = document.getElementById('panel');
const panelArea = document.getElementById('panel-area');
const panelName = document.getElementById('panel-name');
const panelBlurb = document.getElementById('panel-blurb');

let map = null;
let mapBounds = null;
let markers = [];
let spawnList = [];
let chosen = null;
let picking = false;
let countdown = null;

function post(name, data) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

const worldToPx = (x, y) => [
    (x + WM.radius - WM.xOff) / WM.w * IMG_W,
    IMG_H - (y + WM.radius - WM.yOff) / WM.h * IMG_H,
];

const toLatLng = (x, y) => {
    const [px, py] = worldToPx(x, y);
    return map.unproject([px, py], TILE_MAX_Z);
};

function buildMap() {
    if (map) return;
    // Static on purpose. Every pin is always on screen, so zoom and pan only
    // ever created ways to get lost.
    map = L.map('map', {
        crs: L.CRS.Simple,
        zoomSnap: 0,
        zoomControl: false, attributionControl: false,
        dragging: false, scrollWheelZoom: false, doubleClickZoom: false,
        boxZoom: false, keyboard: false, touchZoom: false, tap: false,
        inertia: false,
    });
    const sw = map.unproject([CROP.x0, CROP.y1], TILE_MAX_Z);
    const ne = map.unproject([CROP.x1, CROP.y0], TILE_MAX_Z);
    mapBounds = L.latLngBounds(sw, ne);

    /* bounded to the whole sheet, not to CROP: standing back shows a little
       beyond the land, and a tile cut off at the crop edge would leave bare
       background there. The edge gradient covers the small band it exposes. */
    const sheet = L.latLngBounds(
        map.unproject([0, IMG_H], TILE_MAX_Z),
        map.unproject([IMG_W, 0], TILE_MAX_Z));

    /* kibook/webmap's rdr3 map, from its public GitHub URL (not shipped: no
       licence). If it cannot load, the sheet stays plain parchment and the
       spawn pins still work. */
    L.imageOverlay('https://raw.githubusercontent.com/kibook/webmap/master/http/rdr3/map.jpg', sheet, { interactive: false })
        .addTo(map);

    // watch #wrap, NOT #mapwrap: fitMap sizes #mapwrap, which would loop
    if (window.ResizeObserver) {
        let pending = null;
        new ResizeObserver(() => {
            clearTimeout(pending);
            pending = setTimeout(fitMap, 60);
        }).observe(document.getElementById('wrap'));
    }
}

/* CONTAIN: the whole territory on screen. It does not fill a wide window, but
   the page behind it is the same parchment as the sheet, so the leftover space
   reads as more paper rather than as dead bars. */
function fitMap() {
    if (!map) return;
    map.invalidateSize({ animate: false });

    const s = map.getSize();
    if (s.x < 40 || s.y < 40) return;

    map.setMinZoom(-8);
    map.setMaxZoom(TILE_MAX_Z);

    const cropW = VIEW.x1 - VIEW.x0;
    const cropH = VIEW.y1 - VIEW.y0;
    const z = Math.min(Math.log2(s.x / cropW), Math.log2(s.y / cropH))
        + TILE_MAX_Z - Math.log2(ZOOM_OUT);

    // centred: the margin is black on both sides now, not the sheet's border
    const centre = map.unproject(
        [(VIEW.x0 + VIEW.x1) / 2, (VIEW.y0 + VIEW.y1) / 2], TILE_MAX_Z);

    map.setView(centre, z, { animate: false });
    map.setMinZoom(z);
    map.setMaxZoom(z);
    relayLabels();

    if (DEBUG) console.log(`[spawnselect] view ${s.x}x${s.y} zoom ${z.toFixed(3)}`);
}

// the clamp depends on the container size, so it is redone on every refit
function relayLabels() {
    markers.forEach((m) => {
        if (!m) return;
        const el = m.getElement();
        const d = m._label || {};
        if (el) layLabel(el, m.getLatLng(), d.tag, d.angle, d.dist);
    });
}

// one pick only: a second confirm while the game is fading would double-teleport
function confirmChoice() {
    if (picking || chosen === null) return;
    picking = true;
    if (countdown) clearInterval(countdown);
    confirmBtn.disabled = true;
    post('select', { index: chosen + 1 });
}

function select(i) {
    if (picking) return;
    chosen = i;
    const s = spawnList[i] || {};

    markers.forEach((m, n) => {
        const el = m && m.getElement();
        if (el) el.classList.toggle('selected', n === i);
    });

    // a quick fade so the panel changes instead of snapping
    panel.classList.remove('show');
    setTimeout(() => {
        panelArea.textContent = s.area || '';
        panelName.textContent = s.label || '';
        panelBlurb.textContent = s.blurb || '';

        const img = document.getElementById('panel-img');
        if (s.image) {
            img.style.backgroundImage = `url("${s.image}")`;
            img.classList.remove('hidden');
        } else {
            img.classList.add('hidden');
        }
        panel.classList.add('show');
    }, 90);

    confirmBtn.disabled = false;
    confirmBtn.textContent = 'Spawn Here';
}

/* Labels sit off the point on a leader line, pushed outward from the middle of
   the map, which is how the game's own map keeps its names off the terrain. */
function layLabel(el, latlng, tagged, angle, forced) {
    let dx, dy;

    if (typeof angle === 'number') {
        /* Set in config for the few places where the automatic direction puts
           the plate on top of the name already printed on the map. Degrees,
           screen space: 0 east, -90 north, 90 south, 180 west. */
        const d = forced || (tagged ? 112 : 100);
        const r = angle * Math.PI / 180;
        dx = Math.cos(r) * d;
        dy = Math.sin(r) * d;
    } else {
        const c = map.getCenter();
        let ax = latlng.lng - c.lng;
        let ay = latlng.lat - c.lat;

        const len = Math.hypot(ax, ay);
        if (len < 0.0001) { ax = 0; ay = -1; } else { ax /= len; ay /= len; }

        /* Yours are swung well off the outward line. Stand on a town and the
           two pins share a coordinate, so the same direction would stack the
           plates exactly on each other. */
        const turn = tagged ? 1.15 : 0;
        const a = Math.atan2(-ay, ax) + turn;   // latitude climbs as screen falls
        const dist = tagged ? 118 : 100;
        dx = Math.cos(a) * dist;
        dy = Math.sin(a) * dist;
    }

    /* A plate pushed past the edge of the sheet gets clipped, so any component
       that would run off is flipped back inward. A configured angle is left
       alone: flipping it would undo the very placement that was asked for. */
    if (typeof angle !== 'number') {
        const size = map.getSize();
        const p = map.latLngToContainerPoint(latlng);
        const padX = 125;           // half a plate, near enough
        const padY = 34;

        if (p.x + dx > size.x - padX) dx = -Math.abs(dx);
        else if (p.x + dx < padX)     dx = Math.abs(dx);
        if (p.y + dy > size.y - padY) dy = -Math.abs(dy);
        else if (p.y + dy < padY)     dy = Math.abs(dy);
    }

    el.style.setProperty('--lx', dx.toFixed(1) + 'px');
    el.style.setProperty('--ly', dy.toFixed(1) + 'px');
    el.style.setProperty('--len', Math.hypot(dx, dy).toFixed(1) + 'px');
    el.style.setProperty('--ang', (Math.atan2(dy, dx) * 180 / Math.PI).toFixed(1) + 'deg');
}

function build(spawns) {
    markers.forEach((m) => m && map.removeLayer(m));
    markers = [];
    spawnList = spawns;
    chosen = null;
    confirmBtn.disabled = true;
    panel.classList.remove('show');

    spawns.forEach((s, i) => {
        if (typeof s.x !== 'number' || typeof s.y !== 'number') {
            markers.push(null);
            return;
        }
        const latlng = toLatLng(s.x, s.y);
        const marker = L.marker(latlng, {
            icon: L.divIcon({
                className: 'pin' + (s.tag ? ' tagged' : ''),
                html: '<i class="pin-dot"></i><i class="pin-lead"></i><b class="pin-name"></b>',
                iconSize: [14, 14],
                iconAnchor: [7, 7],
            }),
            keyboard: false,
            riseOnHover: true,
        }).addTo(map);

        const el = marker.getElement();
        if (el) {
            const name = el.querySelector('.pin-name');
            // the short form keeps long names off their neighbours
            if (name) name.textContent = s.short || s.label || '';
            el.style.animationDelay = (i * 45) + 'ms';
            // kept on the marker so a refit lays it out the same way
            marker._label = { tag: s.tag, angle: s.labelAngle, dist: s.labelDist };
            layLabel(el, latlng, s.tag, s.labelAngle, s.labelDist);
        }
        marker.on('click', () => select(i));
        marker.on('dblclick', () => { select(i); confirmChoice(); });
        markers.push(marker);
    });

    if (spawns.length) select(0);
}

function startTimer(seconds) {
    if (!seconds || seconds <= 0) { timerEl.textContent = ''; return; }
    let left = seconds;
    timerEl.textContent = `${left}s`;
    countdown = setInterval(() => {
        left -= 1;
        timerEl.textContent = `${left}s`;
        if (left <= 0) { clearInterval(countdown); confirmChoice(); }
    }, 1000);
}

confirmBtn.addEventListener('click', confirmChoice);

window.addEventListener('message', (event) => {
    const d = event.data || {};

    if (d.action === 'open') {
        picking = false;
        if (countdown) clearInterval(countdown);
        document.documentElement.style.setProperty('--gold', d.accent || '#c9a227');
        document.getElementById('title').textContent = d.title || '';
        document.getElementById('subtitle').textContent = d.subtitle || '';
        wrap.classList.remove('hidden');
        buildMap();
        requestAnimationFrame(() => {
            fitMap();
            build(d.spawns || []);
            startTimer(d.timeout);
        });
    }

    if (d.action === 'close') {
        if (countdown) clearInterval(countdown);
        wrap.classList.add('hidden');
    }
});
