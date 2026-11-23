-- pup-hotel | room lookups shared by client and server. Hotel data lives in config/hotels.lua.

-- ---------------------------------------------------------------- lookups

--- Add a room at load time; config/rooms_custom.lua is only calls to this.
function HotelAddRoom(hotelId, room)
    local hotel = Config.Hotels[hotelId]
    if not hotel or type(room) ~= 'table' or not room.id then
        return print(('^1[pup-hotel]^7 cannot add room to unknown hotel "%s"'):format(tostring(hotelId)))
    end
    hotel.rooms = hotel.rooms or {}
    for _, existing in ipairs(hotel.rooms) do
        if existing.id == room.id then
            return print(('^3[pup-hotel]^7 room "%s" is already in %s - the generated one was ignored')
                :format(room.id, hotelId))
        end
    end
    hotel.rooms[#hotel.rooms + 1] = room
end

function HotelById(hotelId)
    return Config.Hotels[hotelId]
end

function RoomById(hotelId, roomId)
    local hotel = Config.Hotels[hotelId]
    if not hotel then return nil end
    for _, room in ipairs(hotel.rooms or {}) do
        if room.id == roomId then return room end
    end
    return nil
end

function TierOf(room)
    if not room then return nil end
    return Config.Tiers[room.tier or ''] or nil
end

function RoomPrice(room)
    local tier = TierOf(room)
    return math.max(0, math.floor(tonumber(tier and tier.price) or 0))
end

function TierLabel(room)
    local tier = TierOf(room)
    return (tier and tier.label) or (room and room.tier) or Locale.roomFallback
end
