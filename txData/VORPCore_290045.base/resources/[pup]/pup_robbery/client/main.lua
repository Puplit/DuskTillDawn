-- pup_robbery | client clean-up when the resource stops

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    pcall(Walk.cleanup)
    pcall(Hst.cleanup)
    pcall(LawBlips.cleanup)
    pcall(FenceClient_cleanup)
    pcall(Dev_cleanup)
    pcall(Guards.clearRemote)
    pcall(Guards.clear)
end)
