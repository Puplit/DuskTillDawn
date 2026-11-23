// Game styles
const skill_circle_styles = {
    ['default']: {
        icon: {
            type: 'fa-solid fa-crosshairs'
        },
        audio: { // Audio sounds are optional simply replace the sound with undefined and no sound will play. e.g. downloaded: undefined,
            success: 'assets/audio/beep.ogg', // Sound played for success
            perfect: 'assets/audio/glitchy.ogg', // Sound played when icon is in perfect area
            failed: 'assets/audio/system_fault.ogg', // Sound played when failed
            volume: 0.3 // Volume to play sounds 
        },
    }
     // You can add more style templates here..
}

// Game class
class SkillCircle {
    constructor() {
        this.style = skill_circle_styles['default'];
        this.current_key = '';
        this.radius = 100;
        this.circle_width = 300;
        this.circle_height = 300;
        this.icon_angle = 0;
        this.target_zone_angle = 0;
        this.speed = 0.01;
        this.area_size = Math.PI / 3;
        this.perfect_zone_angle = 0;
        this.perfect_zone_size = Math.PI / 18;
        this.game_active = true;
        this.icon_direction = null;

        // a stylesheet cannot reach a canvas, so the ring colours are read from the
        // same CSS variables css/root.css uses for the rest of the pack
        this.colors = {
            track:   this.css_var('--rdr-wood', '#0a0a0a'),
            rim:     'rgba(255, 255, 255, 0.14)',
            target:  'rgba(255, 255, 255, 0.22)',   // matches .skill_bar_target_area
            perfect: this.css_var('--rdr-red', '#a83232'),
        };
    }

    // read a themed colour, falling back to the pup-ui value if the variable
    // is missing (a stock install, or root.css failing to load)
    css_var(name, fallback) {
        try {
            const v = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
            return v || fallback;
        } catch (e) {
            return fallback;
        }
    }

    // Function to init game
    init(data) {
        // the icon lives on the instance: writing into this.style would change the
        // shared template for the next caller
        const template = skill_circle_styles[data.style] || skill_circle_styles['default'];
        this.style = template;
        this.icon_type = data.icon || template.icon.type;
        this.speed = data.speed || this.speed;
        this.area_size = Math.PI / data.area_size || this.area_size;
        this.icon_angle = Math.random() * Math.PI * 2;
        this.target_zone_angle = Math.random() * Math.PI * 2;
        this.perfect_zone_angle = this.target_zone_angle + this.area_size / 2 - this.perfect_zone_size / 2;
        this.build_ui();
        this.animate();
        this.choose_random_key();
        this.bind_key_events();
    }

    // Function to build ui
    build_ui() {
        const icon_html = `<i class="${this.icon_type}" aria-hidden="true"></i>`;
        const content = `
            <div class="skill_circle_container">
                <canvas id="skill_circle_canvas" width="${this.circle_width}" height="${this.circle_height}"></canvas>
                <div class="skill_circle_icon">${icon_html}</div>
                <div class="current_key_display"></div>
            </div>
        `;
        $('#main_container').html(content);
        this.canvas = document.getElementById('skill_circle_canvas');
        this.ctx = this.canvas.getContext('2d');
    }

    // Function to choose a random key to press
    choose_random_key() {
        const keys = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
        this.current_key = keys[Math.floor(Math.random() * keys.length)];
        $('.current_key_display').text(`${this.current_key}`);
    }

    // Function to draw circle
    draw_circle() {
        const cx = this.circle_width / 2;
        const cy = this.circle_height / 2;
        const band = 40;
        this.ctx.clearRect(0, 0, this.circle_width, this.circle_height);

        // the track: near-black, dropped on a real shadow so it reads against
        // a lit wall as well as a dark one
        this.ctx.save();
        this.ctx.shadowColor = 'rgba(0, 0, 0, 0.65)';
        this.ctx.shadowBlur = 10;
        this.ctx.beginPath();
        this.ctx.lineWidth = band;
        this.ctx.strokeStyle = this.colors.track;
        this.ctx.arc(cx, cy, this.radius, 0, Math.PI * 2);
        this.ctx.stroke();
        this.ctx.restore();

        // hairline rims, the same 10% white edge pup-ui puts on its cards
        this.ctx.lineWidth = 1;
        this.ctx.strokeStyle = this.colors.rim;
        for (const r of [this.radius - band / 2, this.radius + band / 2]) {
            this.ctx.beginPath();
            this.ctx.arc(cx, cy, r, 0, Math.PI * 2);
            this.ctx.stroke();
        }

        // the target band
        const start = this.target_zone_angle;
        this.ctx.beginPath();
        this.ctx.lineWidth = band;
        this.ctx.strokeStyle = this.colors.target;
        this.ctx.arc(cx, cy, this.radius, start, start + this.area_size);
        this.ctx.stroke();

        // the perfect band, blood red, centred in the target: an arc the width of
        // the zone it represents
        const centre = start + this.area_size / 2;
        const half = this.perfect_zone_size / 2;
        this.ctx.beginPath();
        this.ctx.lineWidth = band;
        this.ctx.strokeStyle = this.colors.perfect;
        this.ctx.arc(cx, cy, this.radius, centre - half, centre + half);
        this.ctx.stroke();

        this.set_icon_position();
    }
    
    // Function to set icon position
    set_icon_position() {
        const iconX = this.circle_width / 2 + this.radius * Math.cos(this.icon_angle);
        const iconY = this.circle_height / 2 + this.radius * Math.sin(this.icon_angle);
        $('.skill_circle_icon').css({ left: `${iconX}px`, top: `${iconY}px` });
    }

    // Function to bind key events
    bind_key_events() {
        $(document).off('keydown').on('keydown', (e) => {
            if (e.key.toUpperCase() === this.current_key && this.game_active) {
                this.game_active = false;
                this.check_position();
            }
        });
    }

    // Function to check position
    //
    // Wrap-safe: the zone rotates and wraps at 2*PI, so everything is measured as a
    // FORWARD distance from the zone start, which has no seam anywhere on the circle.
    check_position() {
        const TWO_PI = Math.PI * 2;
        const norm = (a) => ((a % TWO_PI) + TWO_PI) % TWO_PI;
        const tolerance_radians = 1.0 * (Math.PI / 180);

        // shifted by the tolerance so being a hair BEFORE the start still counts
        const from_start = norm(this.icon_angle - this.target_zone_angle + tolerance_radians);
        const in_target = from_start <= this.area_size + (tolerance_radians * 2);

        // the perfect band is centred in the zone, so measure off that centre
        const from_centre = norm(this.icon_angle - (this.target_zone_angle + this.area_size / 2));
        const half_perfect = (this.perfect_zone_size / 2) + tolerance_radians;
        const in_perfect = from_centre <= half_perfect || from_centre >= TWO_PI - half_perfect;

        if (in_perfect) {
            this.game_end('perfect');
        } else if (in_target) {
            this.game_end('success');
        } else {
            this.game_end('failed');
        }
    }

    // Function to handle game end
    game_end(result) {
        switch (result) {
            case 'perfect':
                this.play_sound(result);
                setTimeout(() => {
                    $('#main_container').empty();
                    $.post(`https://${GetParentResourceName()}/skill_circle_end`, JSON.stringify({ 'success': result }));
                }, 1500);
                break;
            case 'success':
                this.play_sound(result);
                setTimeout(() => {
                    $('#main_container').empty();
                    $.post(`https://${GetParentResourceName()}/skill_circle_end`, JSON.stringify({ 'success': result }));
                }, 1500);
                break;
            case 'failed':
                this.play_sound(result);
                setTimeout(() => {
                    $('#main_container').empty();
                    $.post(`https://${GetParentResourceName()}/skill_circle_end`, JSON.stringify({ 'success': result }));
                }, 1500);
                break;
            default: break;
        }
    }

    play_sound(sound_key) {
        if (this.style.audio[sound_key]) {
            let sound = new Audio(this.style.audio[sound_key]);
            sound.volume = this.style.audio.volume;
            sound.play();
        }
    }

    animate() {
        if (!this.game_active) return;
        this.target_zone_angle += this.speed;
        if (this.target_zone_angle > Math.PI * 2) {
            this.target_zone_angle -= Math.PI * 2;
        }
        this.draw_circle();
        requestAnimationFrame(() => this.animate());
    }
}

/*
let game_test_data = {
    style: 'default', // Style template
    icon: 'fa-solid fa-gear', // Any font-awesome icon; will use template icon if none is provided
    speed: 0.02, // Speed of target zone movement
    area_size: Math.PI / 4, // Size of target zone
};

start_minigame('skill_circle', game_test_data)
*/
