// Game styles
const button_mash_styles = {
    ['default']: {
        audio: { // Audio sounds are optional simply replace the sound with undefined and no sound will play. e.g. success: undefined,
            success: 'assets/audio/glitchy.ogg', // Sound played when the game is won
            failed: 'assets/audio/system_fault.ogg', // Sound played when the game is lost
            volume: 0.1, // Volume to play sounds
        },
    }
};

// Game class
class ButtonMash {
    constructor() {
        this.style = button_mash_styles['default'];
        this.canvas = null;
        this.ctx = null;
        this.center = { x: 0, y: 0 };
        this.current_key = '';
        this.notch_length = 0;
        this.target_notch_length = Math.PI * 2;
        this.difficulty = null;
        this.notch_increment = null;
        this.notch_decrement = null;
        this.decrement_interval = null;
        this.is_key_active = null;
        this.game_active = true;
        this.time_limit_ms = 50000;
        this.time_limit_timer = null;
        this.time_limit_tick = null;
        this.deadline = 0;
    }

    // Function to init game
    init(data) {
        this.style = button_mash_styles[data.style];
        this.difficulty = data.difficulty;
        this.notch_increment = this.calculate_notch_increment(this.difficulty);
        this.notch_decrement = this.notch_increment / 2.5;
        if (data.time_limit) { this.time_limit_ms = data.time_limit * 1000; }
        this.build_ui();
        this.bind_key_press_events();
        this.choose_random_key();
        this.start_time_limit();
    }

    // hard time limit: the decay only starts on the first keypress, so without
    // this a player who never pressed anything would hold NUI focus forever
    start_time_limit() {
        this.deadline = Date.now() + this.time_limit_ms;
        this.render_timer();
        this.time_limit_tick = setInterval(() => this.render_timer(), 200);
        this.time_limit_timer = setTimeout(() => {
            if (this.game_active) { this.game_end(false); }
        }, this.time_limit_ms);
    }

    // countdown the player can actually see, so the limit is a rule and not an
    // ambush - ticks red for the last ten seconds
    render_timer() {
        if (!this.game_active) { return; }
        const left = Math.max(0, this.deadline - Date.now());
        const secs = Math.ceil(left / 1000);
        const el = $('.button_mash_timer');
        el.text(`${secs}s`);
        el.toggleClass('button_mash_timer_low', secs <= 10);
    }

    // Function to calculate notch increments based on difficulty
    calculate_notch_increment(difficulty) {
        const base_increment = Math.PI / 10;
        return base_increment / difficulty;
    }

    // Function to build main ui
    build_ui() {
        const content = `
            <div class="button_mash_container">
                <canvas id="button_mash_canvas" width="300" height="300"></canvas>
                <span class="button_mash_info">TAP</span>
                <div class="current_key_display"></div>
                <div class="button_mash_timer"></div>
            </div>
        `;
        $('#main_container').html(content);
        this.canvas = document.getElementById('button_mash_canvas');
        this.ctx = this.canvas.getContext('2d');
        this.center = { x: this.canvas.width / 2, y: this.canvas.height / 2 };
        this.draw_ring();
    }

    // Function to bind key presses
    bind_key_press_events() {
        document.addEventListener('keyup', (e) => {
            if (e.key.toUpperCase() === this.current_key) {
                if (!this.is_key_active) {
                    this.is_key_active = true;
                    clearInterval(this.decrement_interval);
                }
                this.increase_notch();
            }
        });
        document.addEventListener('keyup', (e) => {
            if (e.key.toUpperCase() === this.current_key) {
                this.is_key_active = false;
                this.start_decrement_interval();
            }
        });
    }

    // Function to start decrement so notch returns to start
    start_decrement_interval() {
        this.decrement_interval = setInterval(() => {
            if (!this.is_key_active) {
                this.decrease_notch();
                if (this.notch_length <= 0) {
                    clearInterval(this.decrement_interval);
                    this.game_end(false);
                }
            }
        }, 100);
    }

    // Function to choose a random key to mash on start
    choose_random_key() {
        const keys = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
        this.current_key = keys[Math.floor(Math.random() * keys.length)];
        $('.current_key_display').text(`${this.current_key}`);
    }

    // Function to draw the rings 
    draw_ring() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        this.ctx.beginPath();
        this.ctx.arc(this.center.x, this.center.y, 100, 0, Math.PI * 2);
        this.ctx.strokeStyle = 'transparent';
        this.ctx.lineWidth = 35;
        this.ctx.stroke();
        const gradient = this.ctx.createConicGradient(0, this.center.x, this.center.y);
        gradient.addColorStop(0, "rgba(139, 26, 26, 1)");
        gradient.addColorStop(0.33, "rgba(139, 90, 43, 1)");
        gradient.addColorStop(0.66, "rgba(201, 168, 76, 1)");
        gradient.addColorStop(1, "rgba(45, 90, 39, 1)");
        this.ctx.beginPath();
        this.ctx.arc(this.center.x, this.center.y, 100, 0, this.notch_length);
        this.ctx.strokeStyle = gradient;
        this.ctx.lineWidth = 35;
        this.ctx.shadowColor = "rgba(0, 0, 0, 1)";
        this.ctx.shadowBlur = 3;
        this.ctx.stroke();
    }

    // Function to increase notch size on key press
    increase_notch() {
        if (this.game_active && this.notch_length < this.target_notch_length) {
            this.notch_length += this.notch_increment;
            this.draw_ring();
            if (this.notch_length >= this.target_notch_length) {
                this.game_end(true);
            }
        }
    }

    // Function to decrease notch size on decrement interval
    decrease_notch() {
        if (this.game_active && this.notch_length > 0) {
            this.notch_length -= this.notch_decrement;
            this.notch_length = Math.max(this.notch_length, 0);
            this.draw_ring();
            if (this.notch_length <= 0) {
                this.game_end(false);
            }
        }
    }

    // Function to handle game end
    game_end(success) {
        if (this.game_active) {
            this.game_active = false;
            clearInterval(this.decrement_interval);
            clearTimeout(this.time_limit_timer);
            clearInterval(this.time_limit_tick);
            if (success) {
                this.play_sound('success');
            } else {
                this.play_sound('failed');
            }
            setTimeout(() => {
                $('#main_container').empty();
                $.post(`https://${GetParentResourceName()}/button_mash_end`, JSON.stringify({ 'success': success }));
            }, 1500);
        }
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
// Uncomment this test data if you want to preview the UI live in a web browser
let game_test_data = {
    style: 'default', // Style template
    difficulty: 3 // Difficulty; increasing the difficulty decreases the amount the notch increments on each keypress making the game harder to complete
}
start_minigame('button_mash', game_test_data)
*/