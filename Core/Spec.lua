local _, ns = ...

--Key of the player's spec when it is a healer spec the addon supports
function ns:GetPlayerSpecKey()
    local specId
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        local index = C_SpecializationInfo.GetSpecialization()
        specId = index and C_SpecializationInfo.GetSpecializationInfo(index)
    else
        local index = GetSpecialization()
        specId = index and GetSpecializationInfo(index)
    end
    return ns.specs[specId] and ns.specs[specId].key
end

--Haste can be secret during encounters, so the last readable value is kept and used instead
function ns:GetPlayerHaste()
    local haste = GetHaste()
    if ns:IsSecret(haste) then
        return ns.lastKnownHaste or 0
    end
    ns.lastKnownHaste = haste
    return haste
end
