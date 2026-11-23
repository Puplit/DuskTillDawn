Config = Config or {}

-- hash = the game's water zone name; type picks Config.Panning.TypeRichness
Config.WaterTypes = {
    { hash = 'WATER_AURORA_BASIN',        name = 'Aurora Basin',        type = 'lake' },
    { hash = 'WATER_BARROW_LAGOON',       name = 'Barrow Lagoon',       type = 'lake' },
    { hash = 'WATER_CALMUT_RAVINE',       name = 'Calmut Ravine',       type = 'lake' },
    { hash = 'WATER_ELYSIAN_POOL',        name = 'Elysian Pool',        type = 'lake' },
    { hash = 'WATER_FLAT_IRON_LAKE',      name = 'Flat Iron Lake',      type = 'lake' },
    { hash = 'WATER_HEARTLANDS_OVERFLOW', name = 'Heartlands Overflow', type = 'lake' },
    { hash = 'WATER_LAKE_DON_JULIO',      name = 'Don Julio Lake',      type = 'lake' },
    { hash = 'WATER_LAKE_ISABELLA',       name = 'Lake Isabella',       type = 'lake' },
    { hash = 'WATER_O_CREAGHS_RUN',       name = "O'Creagh's Run",      type = 'lake' },
    { hash = 'WATER_OWANJILA',            name = 'Owanjila',            type = 'lake' },
    { hash = 'WATER_SEA_OF_CORONADO',     name = 'Sea of Coronado',     type = 'lake' },

    { hash = 'WATER_ARROYO_DE_LA_VIBORA', name = 'Arroyo de la Vibora', type = 'river' },
    { hash = 'WATER_BEARTOOTH_BECK',      name = 'Beartooth Beck',      type = 'river' },
    { hash = 'WATER_DAKOTA_RIVER',        name = 'Dakota River',        type = 'river' },
    { hash = 'WATER_KAMASSA_RIVER',       name = 'Kamassa River',       type = 'river' },
    { hash = 'WATER_LANNAHECHEE_RIVER',   name = 'Lannahechee River',   type = 'river' },
    { hash = 'WATER_LITTLE_CREEK_RIVER',  name = 'Little Creek River',  type = 'river' },
    { hash = 'WATER_LOWER_MONTANA_RIVER', name = 'Lower Montana River', type = 'river' },
    { hash = 'WATER_SAN_LUIS_RIVER',      name = 'San Luis River',      type = 'river' },
    { hash = 'WATER_UPPER_MONTANA_RIVER', name = 'Upper Montana River', type = 'river' },

    { hash = 'WATER_BAYOU_NWA',           name = 'Bayou Nwa',           type = 'swamp' },

    { hash = 'WATER_DEADBOOT_CREEK',      name = 'Deadboot Creek',      type = 'creek' },
    { hash = 'WATER_DEWBERRY_CREEK',      name = 'Dewberry Creek',      type = 'creek' },
    { hash = 'WATER_HAWKS_EYE_CREEK',     name = "Hawk's Eye Creek",    type = 'creek' },
    { hash = 'WATER_RINGNECK_CREEK',      name = 'Ringneck Creek',      type = 'creek' },
    { hash = 'WATER_SPIDER_GORGE',        name = 'Spider Gorge',        type = 'creek' },
    { hash = 'WATER_STILLWATER_CREEK',    name = 'Stillwater Creek',    type = 'creek' },
    { hash = 'WATER_WHINYARD_STRAIT',     name = 'Whinyard Strait',     type = 'creek' },

    { hash = 'WATER_CAIRN_LAKE',          name = 'Cairn Lake',          type = 'pond' },
    { hash = 'WATER_CATTIAL_POND',        name = 'Cattail Pond',        type = 'pond' }, -- game spelling
    { hash = 'WATER_HOT_SPRINGS',         name = 'Hot Springs',         type = 'pond' },
    { hash = 'WATER_MATTLOCK_POND',       name = 'Mattlock Pond',       type = 'pond' },
    { hash = 'WATER_MOONSTONE_POND',      name = 'Moonstone Pond',      type = 'pond' },
    { hash = 'WATER_SOUTHFIELD_FLATS',    name = 'Southfield Flats',    type = 'pond' },
}
