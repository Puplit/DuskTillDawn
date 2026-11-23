document.addEventListener('DOMContentLoaded', function () {


    const MAX_SIZE = 30;
    const MIN_SIZE = 20;
    const MAX_DISTANCE = 50;

    /**
     * calculate the player icon size based on distance
     * @param {number} distance 
     * @returns {number} 
     */
    function calculateSize(distance) {
        let size = MAX_SIZE - (distance / MAX_DISTANCE) * (MAX_SIZE - MIN_SIZE);
        return Math.max(MIN_SIZE, size);
    }


    /**
    * initialize selection 
    * @param {Object} data id, x, y, distance
    * @returns {void}  
    */
    function initSelector(data) {

        // pup: clear any leftover container BEFORE building a new one.
        //
        // updateSelector and cancelSelector both use querySelector, which only
        // ever finds the FIRST container - so a leftover div would be the one
        // that moves while the live set sits frozen on screen.
        removeSelector();

        const players = document.createElement('div');
        players.className = 'players-selected';
        document.body.appendChild(players);

        for (const player of data) {
            const { id, x, y, distance } = player;

            const playerDiv = document.createElement('div');
            playerDiv.className = 'player';

            const playerImg = document.createElement('img');
            playerImg.src = 'assets/icon.png';
            playerImg.alt = `Player ${id}`;
            let size = calculateSize(distance);
            playerImg.style.width = `${size}px`;
            playerImg.style.height = `${size}px`;

            playerDiv.appendChild(playerImg);

            playerDiv.style.position = 'absolute';
            playerDiv.style.left = `${x * 100}vw`;
            playerDiv.style.top = `${y * 100}vh`;


            playerDiv.addEventListener('click', function () {
                fetch(`https://vorp_lib/selector`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({ id })

                });
                players.remove();
            });

            playerDiv.addEventListener('mouseover', function () {
                fetch(`https://vorp_lib/selectorSound`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({})
                });
            });

            players.appendChild(playerDiv);
        }
    }

    /**
     * update player selection
     * @param {Object} data id, x, y, distance
     * @returns {void}
     **/
    function updateSelector(data) {
        const playersContainer = document.querySelector('.players-selected');
        if (!playersContainer) return;

        for (const player of data) {
            const { id, x, y, distance } = player;
            const playerDiv = playersContainer.querySelector(`.player img[alt="Player ${id}"]`);
            if (playerDiv) {
                let size = calculateSize(distance);
                playerDiv.style.width = `${size}px`;
                playerDiv.style.height = `${size}px`;
                playerDiv.parentElement.style.left = `${x * 100}vw`;
                playerDiv.parentElement.style.top = `${y * 100}vh`;
            }
        }

    }

    /**
     * pup: wipe every selector icon off the screen.
     *
     * querySelectorAll, not querySelector: if anything ever did leak a
     * container this clears the lot rather than peeling off one layer.
     * Idempotent, so it is safe to call on any exit path.
     * @returns {void}
     */
    function removeSelector() {
        document.querySelectorAll('.players-selected').forEach(el => el.remove());
    }

    /**
     * cancel player selection
     * @returns {void}
     * */
    async function cancelSelector() {
        const playersContainer = document.querySelector('.players-selected');
        if (!playersContainer) return;

        removeSelector();
        fetch(`https://vorp_lib/selector`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({ id: -1 })
        });

    }

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') cancelSelector();
    });

    window.addEventListener('message', function (event) {
        const { data } = event.data;
        if (!data || !data.type) return;

        if (data.type === 'select')
            initSelector(data.players);

        if (data.type === 'update')
            updateSelector(data.players);

        // pup: clicking an icon or pressing Escape clears the page here. Every
        // other way a selection ends - the target walking out of range, the
        // target disconnecting, the user dying mid-pick - happens in Lua, which
        // sends 'cancel' on every exit path (client/main/selector.lua) so no
        // icon is left painted on screen with nothing behind it.
        if (data.type === 'cancel')
            removeSelector();
    });
});
