// Game styles
const wire_cut_styles = {
    ['default']: {
        audio: {
            success: 'assets/audio/succeeded.ogg', // Sound played when the game is won
            failed: 'assets/audio/system_fault.ogg', // Sound played when the game is lost
            volume: 0.2, // Volume to play sounds
        },
    }
};

class WireCut {
    constructor() {
        this.style = wire_cut_styles['default'];
        this.difficulty = null;
        this.correct_wire = null;
        this.canvas = null;
        this.ctx = null;
        // DECOYS. The whole game is "cut the odd wire out", so none of these may
        // read as gold - the correct wire is the only gold one on the board.
        this.wire_colors = [
            'rgb(120, 40, 20)',   // brick
            'rgb(60, 80, 40)',    // olive
            'rgb(70, 48, 22)',    // dark brown
            'rgb(60, 62, 88)',    // slate blue
            'rgb(90, 50, 50)',    // maroon
            'rgb(50, 70, 60)'     // dull teal
        ];
        this.correct_wire_colors = [
            'rgb(201, 168, 76)',
            'rgb(220, 180, 100)',
            'rgb(190, 150, 60)',
            'rgb(210, 170, 80)',
            'rgb(200, 160, 70)',
            'rgb(215, 175, 90)'
        ];
        this.wire_paths = [];
        this.wires_cut = [];
        this.timer = null;
        this.is_game_active = false;
    }

    // Function to init game
    init(data) {
        this.style = wire_cut_styles[data.style];
        this.timer = data.timer / 1000 || 60000 / 1000;
        this.build_ui();
        this.start_timer();
    }

    // Function to build main ui
    build_ui() {
        const canvas_html = `
            <div class="wire_cut_container">
                <canvas id="wire_cut_canvas" width="300" height="265"></canvas>
                <div class="wire_cut_timer_container">
                    <div id="timer_display">${this.format_time(this.timer)}</div>
                </div>
            </div>
        `;
        $('#main_container').html(canvas_html);
        this.canvas = document.getElementById('wire_cut_canvas');
        this.ctx = this.canvas.getContext('2d');
        this.build_game_area();
    }

    // Function to start game timer
    start_timer() {
        // main.js builds a BRAND NEW WireCut on every start, so an interval left
        // running by an aborted game would keep ticking and write to the same
        // #timer_display as this one - the number would jump between two
        // countdowns every second. Only one wire-cut may own the clock.
        if (window.__wire_cut_interval) clearInterval(window.__wire_cut_interval);
        this.is_game_active = true;
        this.timer_interval = setInterval(() => {
            if(this.timer > 0) {
                this.timer--;
                $('#timer_display').text(this.format_time(this.timer));
            } else {
                this.game_end(false);
            }
        }, 1000);
        window.__wire_cut_interval = this.timer_interval;
    }

    // M:SS, clamped and floored
    format_time(seconds) {
        let s = Math.max(0, Math.floor(Number(seconds) || 0));
        const minutes = Math.floor(s / 60);
        s = s % 60;
        return `${minutes}:${s < 10 ? '0' + s : s}`;
    }

    // Function to stop game timer
    stop_timer() {
        clearInterval(this.timer_interval);
        if (window.__wire_cut_interval === this.timer_interval) {
            window.__wire_cut_interval = null;
        }
        this.is_game_active = false;
    }

    // Function to build game area
    build_game_area() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        const circle_radius = 5;
        const left_x = 30;
        const right_x = 270;
        const circle_dist = 38;
        const start_y = circle_dist;
        const adjusted_start_x = left_x + circle_radius;
        const adjusted_end_x = right_x - circle_radius;
        let right_circles = this.generate_right_circles();
        this.correct_wire = Math.floor(Math.random() * this.wire_colors.length);
        this.correct_wire_color = this.correct_wire_colors[Math.floor(Math.random() * this.correct_wire_colors.length)];
        this.wire_paths = [];
        for (let i = 0; i < 6; i++) {
            const left_y = start_y + i * circle_dist;
            const right_y = start_y + right_circles[i] * circle_dist;
            const color = i === this.correct_wire ? this.correct_wire_color : this.wire_colors[i];
            const wire_path = this.create_wire_path(adjusted_start_x, left_y, adjusted_end_x, right_y);
            this.wire_paths.push({ path: wire_path, index: i, color });
            this.draw_wire(wire_path, color);
        }
        for (let i = 0; i < 6; i++) {
            this.draw_circle(left_x, start_y + i * circle_dist, circle_radius + 3);
            this.draw_circle(right_x, start_y + i * circle_dist, circle_radius + 3);
        }
        this.canvas.addEventListener('click', (event) => this.check_wire_click(event));
    }
    
    // Function to sort right circle and block index 0 left and 6 right so top circles do not connect this is purely for visual reasons with overlap
    generate_right_circles() {
        let indices = [1, 2, 3, 4, 5];
        indices = indices.sort(() => Math.random() - 0.5);
        let position = Math.floor(Math.random() * (indices.length - 1)) + 1;
        indices.splice(position, 0, 0);
        return indices;
    }
    
    // Function to create the bezier curve "wire"
    create_wire_path(start_x, start_y, end_x, end_y) {
        const control_x1 = start_x + (end_x - start_x) / 2;
        const control_y1 = start_y - 50;
        const control_x2 = control_x1;
        const control_y2 = end_y - 50;
        const wire_path = new Path2D();
        wire_path.moveTo(start_x, start_y);
        wire_path.bezierCurveTo(control_x1, control_y1, control_x2, control_y2, end_x, end_y);
        return wire_path;
    }

    // Function to draw the wires
    draw_wire(wire_path, color) {
        this.ctx.save();
        this.ctx.beginPath();
        this.ctx.strokeStyle = color;
        this.ctx.lineWidth = 6;
        this.ctx.shadowColor = 'rgba(0, 0, 0, 1)';
        this.ctx.shadowBlur = 5;
        this.ctx.stroke(wire_path);
        this.ctx.restore();
    }
    
    // Function to draw the circles
    draw_circle(x, y, radius) {
        let gradient = this.ctx.createRadialGradient(x, y, radius * 0.1, x, y, radius);
        gradient.addColorStop(0, 'rgba(201, 168, 76, 1)');
        gradient.addColorStop(0.5, 'rgba(139, 94, 60, 1)');
        gradient.addColorStop(1, 'rgba(62, 36, 21, 1)');
        this.ctx.save();
        this.ctx.beginPath();
        this.ctx.arc(x, y, radius, 0, 2 * Math.PI);
        this.ctx.fillStyle = gradient;
        this.ctx.shadowColor = 'rgba(0, 0, 0, 0.5)';
        this.ctx.shadowBlur = 4;
        this.ctx.shadowOffsetX = 2;
        this.ctx.shadowOffsetY = 2;
        this.ctx.fill();
        this.ctx.restore();
    }
    
    // Function to check wire clicks for correct wire
    check_wire_click(event) {
        const rect = this.canvas.getBoundingClientRect();
        const x = event.clientX - rect.left;
        const y = event.clientY - rect.top;
        for (const { path, index } of this.wire_paths) {
            if (this.ctx.isPointInPath(path, x, y) && !this.wires_cut.includes(index)) {
                this.wire_cut(index);
                if (index === this.correct_wire) {
                    this.game_end(true);
                } else {
                    this.game_end(false);
                }
                break;
            }
        }
    }

    // Function to cut wire
    wire_cut(wire_index) {
        this.wires_cut.push(wire_index);
        this.redraw_game_area();
    }

    // Function to redraw game area with the cut wire missing
    redraw_game_area() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        for (let wire of this.wire_paths) {
            if (!this.wires_cut.includes(wire.index)) {
                this.draw_wire(wire.path, wire.color);
            }
        }
        for (let i = 0; i < 6; i++) {
            const circle_y = 38 + i * 38;
            this.draw_circle(30, circle_y, 8);
            this.draw_circle(270, circle_y, 8);
        }
    }

    // Function to handle game end
    game_end(success) {
        if (success) {
            console.log('Success! Bomb defused.');
        } else {
            console.log('Failed! The bomb exploded.');
        }
        this.stop_timer();
        this.play_sound(success ? 'success' : 'failed');
        setTimeout(() => {
            $('#main_container').empty();
            $.post(`https://${GetParentResourceName()}/wire_cut_end`, JSON.stringify({ 'success': success }));
        }, 2000);
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
    style: 'default',
    difficulty: 3,
    timer: 60000
};
start_minigame('wire_cut', game_test_data);
*/