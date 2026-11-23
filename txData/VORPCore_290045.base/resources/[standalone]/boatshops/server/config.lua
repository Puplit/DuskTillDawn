-- boatshops | server-only settings: Discord logs. Never sent to clients.
-- A blank webhook on sell, give or upgrade falls back to the buy webhook.
-- A blank buy webhook turns that log off.

BoatLogs = {
    buy = {
        webhook = '',
        title = 'Boat Bought',
        colour = 3066993,
        logo = '',
        footerIcon = '',
        avatar = '',
        name = 'Dusk Till Dawn',
    },
    sell = {
        webhook = '',
        title = 'Boat Sold to Store',
        colour = 15158332,
        logo = '',
        footerIcon = '',
        avatar = '',
        name = 'Dusk Till Dawn',
    },
    give = {
        webhook = '',
        title = 'Boat Transferred',
        colour = 15844367,
        logo = '',
        footerIcon = '',
        avatar = '',
        name = 'Dusk Till Dawn',
    },
    upgrade = {
        webhook = '',
        title = 'Boat Modified',
        colour = 3447003,
        logo = '',
        footerIcon = '',
        avatar = '',
        name = 'Dusk Till Dawn',
    },
}
