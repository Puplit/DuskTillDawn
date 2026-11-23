-- pup-bank | branches
-- Every key is a separate account and the name players see. The key also names the
-- balance column in bank_users: lower-cased, " bank" and spaces dropped, plus "_money"
-- ("Saint Denis Bank" -> saintdenis_money). pup_realestate reads these keys from this file.
--   town    : the town the branch serves (shown nowhere; for your own reference)
--   counter : where the teller window is; the prompt shows within 1.5 m of it
--   blip    : optional map icon for this branch (default Config.BankBlip)

Config.BankBlip = -2128054417

Config.Banks = {
    ["Valentine Bank"]   = { town = "Valentine",   counter = vector3(-308.50, 776.24, 118.75) },
    ["Blackwater Bank"]  = { town = "Blackwater",  counter = vector3(-813.09, -1277.34, 43.34) },
    ["Saint Denis Bank"] = { town = "Saint Denis", counter = vector3(2644.08, -1292.21, 52.29) },
    ["Rhodes Bank"]      = { town = "Rhodes",      counter = vector3(1293.10, -1301.00, 77.00) },
    ["Strawberry Bank"]  = { town = "Strawberry",  counter = vector3(-1764.91, -384.22, 157.49) },
    ["Armadillo Bank"]   = { town = "Armadillo",   counter = vector3(-3666.00, -2626.67, -13.84) },
    ["Annesburg Bank"]   = { town = "Annesburg",   counter = vector3(2931.68, 1283.04, 44.65) },
}
