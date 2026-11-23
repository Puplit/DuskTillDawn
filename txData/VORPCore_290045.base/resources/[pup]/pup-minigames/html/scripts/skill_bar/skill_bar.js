// Game styles
const skill_bar_styles = {
    ['default']: {
        icon: {
            type: 'fa-solid fa-crosshairs'
        },
        /* sounds are off: the bar is used by many jobs. undefined = silent. */
        audio: {
            success: undefined,
            perfect: undefined,
            failed: undefined,
            volume: 0.2
        },
    }
     // You can add more style templates here..
}

// Game class
class SkillBar {
    constructor() {
        this.style = skill_bar_styles['default'];
        this.area_size = null;
        this.perfect_area_size = null;
        this.speed = null;
        this.target_area_position = 0;
        this.moving_forward = true;
        this.game_active = true;
        this.icon_position = 0;
        this.orientation = null;
        this.moving_icon = null;
        this.icon_speed = null;
        this.end_delay = null;
    }

    // Function to init game
    init(data) {
        const template = skill_bar_styles[data.style] || skill_bar_styles['default'];
        this.style = template;
        this.icon_type = data.icon || template.icon.type;
        this.area_size = data.area_size || 10;
        this.perfect_area_size = data.perfect_area_size || 5;
        this.speed = data.speed || 1;
        this.orientation = data.orientation || 1;
        this.moving_icon = data.moving_icon || false;
        this.icon_speed = data.icon_speed || 0.02;
        // how long the result sits on screen before the bar hands control back (default 1500)
        this.end_delay = (typeof data.end_delay === 'number') ? data.end_delay : 1500;
        // per-call draw size: the CSS bar is 25% x 3% with a 1.3rem icon; scale shrinks or grows all three together
        this.scale = (typeof data.scale === 'number' && data.scale > 0) ? data.scale : 1;
        /* on-screen hint inside the panel, shown for as long as the bar is.
              Pass hint: false to suppress it, or a string to override the wording. */
        this.hint = (data.hint === false) ? null
            : (typeof data.hint === 'string' ? data.hint : 'Press SPACE inside the lit zone');
        this.build_ui();
        this.start_moving_target_area();
        if (this.moving_icon) {
            this.start_moving_icon();
        }
        this.bind_key_events();
    }

    // Function to build main ui
    build_ui() {
        const orientation_style = this.orientation === 2 ? 'transform: rotate(-90deg); top: 0%; left: 30%;' : '';
        const size_style = this.scale !== 1
            ? `width: ${(25 * this.scale).toFixed(2)}%; height: ${(3 * this.scale).toFixed(2)}%;`
            : '';
        const icon_orientation = this.orientation === 2 ? 'fa-rotate-90' : '';
        const icon_size = this.scale !== 1 ? ` style="font-size: ${(1.3 * this.scale).toFixed(2)}rem;"` : '';
        const icon_html = `<i class="${this.icon_type} ${icon_orientation}" aria-hidden="true"></i>`;
        const perfect_area = (this.area_size - this.perfect_area_size) / 2;
        /* Sibling of the bar, not a child: in vertical mode (orientation 2) the
           container is rotated -90deg, and anything inside it turns with it.
           Inline styles so this does not depend on skill_bar.css. */
        const hint_html = this.hint
            ? `<div class="skill_bar_hint" style="
                   position:fixed; left:0; right:0; bottom:22%;
                   text-align:center; pointer-events:none;
                   font-family:inherit; font-size:17px; letter-spacing:.04em;
                   color:#f3e6d0; text-shadow:0 2px 6px rgba(0,0,0,.9);
               ">${this.hint}</div>`
            : '';

        const content = `
            ${hint_html}
            <div class="skill_bar_container" style="${orientation_style}${size_style}">
                <div class="skill_bar_icon"${icon_size}>${icon_html}</div>
                <div class="skill_bar_target_area" style="width: ${this.area_size}%; left: 0;">
                    <div class="skill_bar_perfect_area" style="left: ${perfect_area}%; width: ${this.perfect_area_size}%"></div>
                </div>
            </div>
        `;
        $('#main_container').html(content);
        this.target_area = $('.skill_bar_target_area');
        this.randomise_positions();
    }
    
    // Function to randomise positioning
    randomise_positions() {
        const span = 100 - this.area_size;
        this.target_area_position = Math.floor(Math.random() * span);

        /* keep the icon off the extreme ends: the target sweeps between 0 and `span`
              and reverses at each end, so an icon hard against an edge is only reachable
              as the sweep turns. Confining it to the middle keeps every attempt equally hard. */
        const margin = span * 0.25;
        this.icon_position = Math.floor(margin + Math.random() * (span - margin * 2));

        $('.skill_bar_icon').css('left', this.icon_position + '%');
        this.target_area.css('left', this.target_area_position + '%');
    }

    // Function to handle moving icon
    start_moving_icon() {
        let next_position = Math.random() * (100 - this.area_size);
        const update_icon_position = () => {
            if (!this.game_active) return;
            let distance = next_position - this.icon_position;
            this.icon_position += distance * this.icon_speed / 100;
            $('.skill_bar_icon').css('left', `${this.icon_position}%`);
            if (Math.abs(distance) < 0.1) {
                next_position = Math.random() * (100 - this.area_size);
            }
            requestAnimationFrame(update_icon_position);
        };
        requestAnimationFrame(update_icon_position);
    }

    // Function to handle moving target area
    start_moving_target_area() {
        const update_target_area = () => {
            if (!this.game_active) return;
            this.target_area_position += this.moving_forward ? this.speed : -this.speed;
            if (this.target_area_position > 100 - this.area_size) {
                this.target_area_position = 100 - this.area_size;
                this.moving_forward = false;
            } else if (this.target_area_position < 0) {
                this.target_area_position = 0;
                this.moving_forward = true;
            }
            this.target_area.css('left', this.target_area_position + '%');
            requestAnimationFrame(update_target_area);
        };
        requestAnimationFrame(update_target_area);
    }

    // Function to bind key events
    bind_key_events() {
        $(document).off('keydown').on('keydown', (event) => {
            if (event.key === ' ' && this.game_active) {
                this.game_active = false;
                clearInterval(this.movement_interval);
                clearInterval(this.moving_icon_interval);
                this.check_position();
            }
        });
    }

    // Function to check positions
    // Measures the rendered boxes: the icon is judged by its CENTRE, and the
    // perfect band is a % of the target area (as drawn), not of the container.
    // Vertical (orientation 2) compares on Y, since the container is rotated -90deg.
    check_position() {
        const icon_el = document.querySelector('.skill_bar_icon');
        const target_el = this.target_area && this.target_area[0];
        if (!icon_el || !target_el) return this.game_end('failed');

        const vertical = this.orientation === 2;
        const tolerance = 2; // px of grace, so a pixel-perfect edge still counts
        const icon_r = icon_el.getBoundingClientRect();
        const target_r = target_el.getBoundingClientRect();

        const icon_centre = vertical
            ? icon_r.top + icon_r.height / 2
            : icon_r.left + icon_r.width / 2;

        const perfect_el = document.querySelector('.skill_bar_perfect_area');
        if (perfect_el) {
            const p = perfect_el.getBoundingClientRect();
            const p_start = vertical ? p.top : p.left;
            const p_end = vertical ? p.bottom : p.right;
            if (icon_centre >= p_start - tolerance && icon_centre <= p_end + tolerance) {
                return this.game_end('perfect');
            }
        }

        const t_start = vertical ? target_r.top : target_r.left;
        const t_end = vertical ? target_r.bottom : target_r.right;
        if (icon_centre >= t_start - tolerance && icon_centre <= t_end + tolerance) {
            return this.game_end('success');
        }
        return this.game_end('failed');
    }

    // Function to handle game end
    game_end(result) {
        if (result !== 'perfect' && result !== 'success' && result !== 'failed') return;
        this.play_sound(result);
        setTimeout(() => {
            $('#main_container').empty();
            $.post(`https://${GetParentResourceName()}/skill_bar_end`, JSON.stringify({ 'success': result }));
        }, this.end_delay);
    }

    // Function to play sounds
    play_sound(sound_key) {
        if (this.style.audio[sound_key]) {
            let sound = new Audio(this.style.audio[sound_key]);
            sound.volume = this.style.audio.volume;
            sound.play();
        }
    }
}

/*
// Example usage:
let game_test_data = { 
    style: 'default', // Style template
    icon: 'fa-solid fa-fish', // Any font-awesome icon; will use template icon if none is provided
    orientation: 2, // Orientation of the bar; 1 = horizontal centre, 2 = vertical right.
    area_size: 20, // Size of the target area in %
    perfect_area_size: 5, // Size of the perfect area in %
    speed: 0.5, // Speed the target area moves
    moving_icon: true, // Toggle icon movement; true = icon will move randomly, false = icon will stay in a static position
    icon_speed: 3, // Speed to move the icon if icon movement enabled
};
start_minigame('skill_bar', game_test_data)
*/