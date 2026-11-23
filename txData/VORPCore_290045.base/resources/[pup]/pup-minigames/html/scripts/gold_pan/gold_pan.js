//------------------------------\\
//---\\  GOLD PAN  //---\\
//------------------------------\\
//
// Swirl the pan. Water carries the light gravel over the lip, heavy gold sinks
// and stays. Swirl too gently and the silt never clears; too hard and the gold
// goes over the side with it.
//
// Speed is measured as NET angular travel over a short window, so shaking the
// mouse back and forth nets ~0 and gets you nowhere. Only real circles count.

const gold_pan_styles = {
    // no audio: panning is a quiet job
    ['default']: {}
};

class GoldPan {
    constructor() {
        this.style = gold_pan_styles['default'];

        // tuning (all overridable from Lua)
        this.duration = 15000;   // ms before the pan is called done
        this.target_min = 2.2;   // rad/s: below this the wash is weak
        this.target_max = 5.0;   // rad/s: above this you start losing gold
        this.silt_rate = 16;     // silt % cleared per second at full wash
        this.gold_rate = 9;      // gold % lost per second per rad/s of overshoot
        this.hint = 'Swirl the pan in circles · ENTER to tip it out';
        // live coaching, because the gauge alone does not explain WHY you are losing gold
        this.slow_text = 'Too gentle — the gravel is not shifting';
        this.good_text = 'That is the pace — keep it steady';
        this.fast_text = 'Too hard — you are washing the gold out';
        this.state = null;

        // state
        this.silt = 100;
        this.gold = 100;
        this.speed = 0;
        this.rotation = 0;
        this.samples = [];       // { t, d, dist } signed turn of the travel direction
        this.window_ms = 400;
        this.last_pos = null;
        this.last_dir = null;
        this.min_step = 2;       // px: below this the direction is noise, not a swirl
        this.ref_radius = 55;    // px: the circle size the pace is judged against
        this.last_frame = 0;
        this.started = 0;
        this.game_active = true;
        this.size = 360;

        this.colors = {
            pan:     '#2b2b2b',
            pan_rim: 'rgba(255,255,255,0.14)',
            riffle:  'rgba(255,255,255,0.06)',
            water:   'rgba(120,170,200,0.16)',
            silt:    '#4a3a28',
            silt_lt: '#6b5438',
            gold:    '#d8b34a',
            gold_lt: '#f2d98a',
            band:    'rgba(255,255,255,0.22)',
            ok:      '#ffffff',
            slow:    'rgba(255,255,255,0.45)',
            fast:    '#a83232',
        };
    }

    css_var(name, fallback) {
        try {
            const v = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
            return v || fallback;
        } catch (e) {
            return fallback;
        }
    }

    init(data) {
        data = data || {};
        const template = gold_pan_styles[data.style] || gold_pan_styles['default'];
        this.style = template;

        if (data.duration   !== undefined) this.duration   = data.duration;
        if (data.target_min !== undefined) this.target_min = data.target_min;
        if (data.target_max !== undefined) this.target_max = data.target_max;
        if (data.silt_rate  !== undefined) this.silt_rate  = data.silt_rate;
        if (data.gold_rate  !== undefined) this.gold_rate  = data.gold_rate;
        if (data.hint       !== undefined) this.hint       = data.hint;
        if (data.slow_text  !== undefined) this.slow_text  = data.slow_text;
        if (data.good_text  !== undefined) this.good_text  = data.good_text;
        if (data.fast_text  !== undefined) this.fast_text  = data.fast_text;

        this.colors.fast = this.css_var('--rdr-red', this.colors.fast);

        // fixed particle field, drawn down to the current fill level
        this.silt_bits = [];
        for (let i = 0; i < 90; i++) {
            this.silt_bits.push({
                a: Math.random() * Math.PI * 2,
                r: 0.30 + Math.random() * 0.62,   // fraction of pan radius
                s: 1.4 + Math.random() * 2.6,
                light: Math.random() < 0.35
            });
        }
        this.gold_bits = [];
        for (let i = 0; i < 26; i++) {
            this.gold_bits.push({
                a: Math.random() * Math.PI * 2,
                r: 0.52 + Math.random() * 0.26,   // gold rides the outer crease
                s: 1.2 + Math.random() * 1.8,
                light: Math.random() < 0.45
            });
        }

        this.build_ui();
        this.bind_events();
        this.started = performance.now();
        this.last_frame = this.started;
        requestAnimationFrame((t) => this.loop(t));
    }

    build_ui() {
        const content = `
            <div class="gold_pan_container">
                <canvas id="gold_pan_canvas" width="${this.size}" height="${this.size}"></canvas>
                <div class="gold_pan_meters">
                    <div class="gp_meter">
                        <span class="gp_label">Silt</span>
                        <div class="gp_track"><div class="gp_fill gp_silt" id="gp_silt_fill"></div></div>
                    </div>
                    <div class="gp_meter">
                        <span class="gp_label">Gold</span>
                        <div class="gp_track"><div class="gp_fill gp_gold" id="gp_gold_fill"></div></div>
                    </div>
                </div>
                <div class="gold_pan_status" id="gp_status"></div>
                <div class="gold_pan_hint" id="gp_hint">${this.hint === false ? '' : this.hint}</div>
            </div>
        `;
        $('#main_container').html(content);
        this.canvas = document.getElementById('gold_pan_canvas');
        this.ctx = this.canvas.getContext('2d');
    }

    bind_events() {
        // Measures how fast the DIRECTION OF TRAVEL turns, not the angle around the
        // pan, so a circle counts wherever it is drawn and whatever size it is, and
        // the screen edges are no trap.
        $(document).off('mousemove.goldpan').on('mousemove.goldpan', (e) => {
            if (!this.game_active) return;
            const x = e.clientX, y = e.clientY;

            if (!this.last_pos) { this.last_pos = { x: x, y: y }; return; }

            const dx = x - this.last_pos.x, dy = y - this.last_pos.y;
            const dist = Math.sqrt(dx * dx + dy * dy);
            if (dist < this.min_step) return;   // jitter: its direction means nothing

            const dir = Math.atan2(dy, dx);
            if (this.last_dir !== null) {
                let d = dir - this.last_dir;
                // shortest way round, so the -PI/PI seam is not a huge fake jump
                while (d > Math.PI) d -= Math.PI * 2;
                while (d < -Math.PI) d += Math.PI * 2;
                this.samples.push({ t: performance.now(), d: d, dist: dist });
            }
            this.last_dir = dir;
            this.last_pos = { x: x, y: y };
        });

        $(document).off('keydown.goldpan').on('keydown.goldpan', (e) => {
            if (!this.game_active) return;
            if (e.key === 'Enter' || e.key === 'Escape') this.finish();
        });
    }

    // Net turn over the window. Back-and-forth cancels out, so wiggling gets nowhere.
    current_speed(now) {
        const cutoff = now - this.window_ms;
        while (this.samples.length && this.samples[0].t < cutoff) this.samples.shift();

        let net = 0, dist = 0;
        for (let i = 0; i < this.samples.length; i++) {
            net += this.samples[i].d;
            dist += this.samples[i].dist;
        }
        const secs = this.window_ms / 1000;
        const turn = Math.abs(net) / secs;            // how fast the direction turns
        const travel = dist / secs;                   // px/s the hand actually moved

        // Both have to be present. A three-pixel twitch spun fast is not a swirl, and
        // neither is a long straight drag. Whichever is smaller sets the reading.
        return Math.min(turn, travel / this.ref_radius);
    }

    loop(now) {
        if (!this.game_active) return;
        const dt = Math.min(0.1, (now - this.last_frame) / 1000);
        this.last_frame = now;

        const raw = this.current_speed(now);
        // smooth so the needle does not twitch on every mouse event
        this.speed += (raw - this.speed) * Math.min(1, dt * 12);

        // how well the wash is working
        let eff;
        if (this.speed < this.target_min) {
            const f = this.target_min > 0 ? (this.speed / this.target_min) : 0;
            eff = f * f;                 // gentle swirling is much weaker, not just slower
        } else {
            eff = 1;
        }
        this.silt = Math.max(0, this.silt - this.silt_rate * eff * dt);

        // over the top and the gold goes with the gravel
        if (this.speed > this.target_max) {
            this.gold = Math.max(0, this.gold - (this.speed - this.target_max) * this.gold_rate * dt);
        }

        this.rotation += this.speed * dt;

        this.draw();
        $('#gp_silt_fill').css('width', this.silt + '%');
        $('#gp_gold_fill').css('width', this.gold + '%');

        // only touch the DOM when the verdict actually changes
        let state = 'good';
        if (this.speed > this.target_max) state = 'fast';
        else if (this.speed < this.target_min) state = 'slow';
        if (state !== this.state) {
            this.state = state;
            const text = state === 'fast' ? this.fast_text
                       : state === 'slow' ? this.slow_text
                       : this.good_text;
            $('#gp_status').text(text).attr('class', 'gold_pan_status gp_' + state);
        }

        if (this.silt <= 0 || this.gold <= 0 || (now - this.started) >= this.duration) {
            return this.finish();
        }
        requestAnimationFrame((t) => this.loop(t));
    }

    draw() {
        const ctx = this.ctx;
        const S = this.size;
        const cx = S / 2, cy = S / 2;
        const R = S * 0.38;

        ctx.clearRect(0, 0, S, S);

        // pan body
        ctx.save();
        ctx.shadowColor = 'rgba(0,0,0,0.65)';
        ctx.shadowBlur = 14;
        ctx.beginPath();
        ctx.fillStyle = this.colors.pan;
        ctx.arc(cx, cy, R, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();

        // riffle rings
        ctx.lineWidth = 1;
        ctx.strokeStyle = this.colors.riffle;
        for (const f of [0.45, 0.66, 0.85]) {
            ctx.beginPath();
            ctx.arc(cx, cy, R * f, 0, Math.PI * 2);
            ctx.stroke();
        }
        ctx.lineWidth = 2;
        ctx.strokeStyle = this.colors.pan_rim;
        ctx.beginPath();
        ctx.arc(cx, cy, R, 0, Math.PI * 2);
        ctx.stroke();

        // the slick of water, leaning the way you are swirling
        const lean = Math.min(1, this.speed / Math.max(0.001, this.target_max));
        ctx.save();
        ctx.beginPath();
        ctx.arc(cx, cy, R * 0.94, 0, Math.PI * 2);
        ctx.clip();
        ctx.beginPath();
        ctx.fillStyle = this.colors.water;
        ctx.ellipse(
            cx + Math.cos(this.rotation) * R * 0.20 * lean,
            cy + Math.sin(this.rotation) * R * 0.20 * lean,
            R * 0.92, R * 0.92, 0, 0, Math.PI * 2
        );
        ctx.fill();
        ctx.restore();

        // silt, thinning out as it washes over the lip
        const silt_n = Math.ceil(this.silt_bits.length * (this.silt / 100));
        for (let i = 0; i < silt_n; i++) {
            const b = this.silt_bits[i];
            const a = b.a + this.rotation;
            ctx.beginPath();
            ctx.fillStyle = b.light ? this.colors.silt_lt : this.colors.silt;
            ctx.arc(cx + Math.cos(a) * R * b.r, cy + Math.sin(a) * R * b.r, b.s, 0, Math.PI * 2);
            ctx.fill();
        }

        // gold, riding the crease
        const gold_n = Math.ceil(this.gold_bits.length * (this.gold / 100));
        ctx.save();
        ctx.shadowColor = 'rgba(216,179,74,0.85)';
        ctx.shadowBlur = 6;
        for (let i = 0; i < gold_n; i++) {
            const b = this.gold_bits[i];
            const a = b.a + this.rotation * 0.55;   // heavier, lags the gravel
            ctx.beginPath();
            ctx.fillStyle = b.light ? this.colors.gold_lt : this.colors.gold;
            ctx.arc(cx + Math.cos(a) * R * b.r, cy + Math.sin(a) * R * b.r, b.s, 0, Math.PI * 2);
            ctx.fill();
        }
        ctx.restore();

        this.draw_gauge(cx, cy, S * 0.455);
    }

    // ring round the pan: where you are, and where you should be
    draw_gauge(cx, cy, radius) {
        const ctx = this.ctx;
        const START = Math.PI * 0.75;      // 270 degrees of sweep, gap at the bottom
        const SWEEP = Math.PI * 1.5;
        const MAX = this.target_max * 1.6;
        const at = (v) => START + SWEEP * Math.min(1, Math.max(0, v / MAX));

        ctx.lineWidth = 8;
        ctx.strokeStyle = 'rgba(255,255,255,0.07)';
        ctx.beginPath();
        ctx.arc(cx, cy, radius, START, START + SWEEP);
        ctx.stroke();

        // the good band
        ctx.strokeStyle = this.colors.band;
        ctx.beginPath();
        ctx.arc(cx, cy, radius, at(this.target_min), at(this.target_max));
        ctx.stroke();

        // needle
        let col = this.colors.slow;
        if (this.speed > this.target_max) col = this.colors.fast;
        else if (this.speed >= this.target_min) col = this.colors.ok;

        const a = at(this.speed);
        ctx.strokeStyle = col;
        ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.arc(cx, cy, radius, a - 0.02, a + 0.02);
        ctx.stroke();

        ctx.save();
        ctx.shadowColor = col;
        ctx.shadowBlur = 8;
        ctx.beginPath();
        ctx.fillStyle = col;
        ctx.arc(cx + Math.cos(a) * radius, cy + Math.sin(a) * radius, 5, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }

    finish() {
        if (!this.game_active) return;
        this.game_active = false;
        $(document).off('mousemove.goldpan').off('keydown.goldpan');

        // what you kept, scaled by how much of the pan you actually worked through
        const cleared = 1 - (this.silt / 100);
        const score = Math.max(0, Math.min(1, (this.gold / 100) * cleared));

        const verdict = score >= 0.75 ? 'A good clean pan'
                      : score >= 0.35 ? 'Some colour left in it'
                      : 'Not much to show';
        $('#gp_status').text(verdict).attr('class', 'gold_pan_status gp_' + (score >= 0.75 ? 'good' : score >= 0.35 ? 'slow' : 'fast'));
        $('#gp_hint').text('');

        setTimeout(() => {
            $('#main_container').empty();
            $.post(`https://${GetParentResourceName()}/gold_pan_end`, JSON.stringify({ score: score }));
        }, 900);
    }
}
