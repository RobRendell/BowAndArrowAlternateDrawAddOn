
local function doAlternateDrawAlterations()
    if not MandelaBowAndArrow.Client.altDrawOriginalAttackHook then
        MandelaBowAndArrow.Client.altDrawOriginalAttackHook = MandelaBowAndArrow.Client.attackHook
        MandelaBowAndArrow.Client.altDrawOriginalSetUpBow = MandelaBowAndArrow.Client.setUpBow
    end

    MandelaBowAndArrow.Client.Sounds.HitHead = 'HeadHit'
    MandelaBowAndArrow.Client.Sounds.HitBody = 'FleshHit'

    -- Override setUpBow so that a player doesn't draw their bow by simply aiming.
    MandelaBowAndArrow.Client.setUpBow = function(player, bow)
        local playerModData = MandelaBowAndArrow.Shared.getModData(player);
        if not player:isAiming() then
            MandelaBowAndArrow.Client.altDrawOriginalSetUpBow(player, bow)
        elseif not playerModData.aiming then
            playerModData.aiming = true
            MandelaBowAndArrow.Client.SetBowAndArrowModel(player, bow, 1);
        end
    end

    local attackDataForCharacter = {}

    MandelaBowAndArrow.Client.altDrawLooseArrow = function(character)
        local attackData = attackDataForCharacter[character:getPlayerNum()]
        if isDebugEnabled() then
            print("AltDrawAddOn debug: altDrawLooseArrow got attackData for player ", character:getPlayerNum(),
                    ": ", serialize(attackData))
        end
        if attackData and attackData.weapon then
            if character:isAiming() and attackData.bowDrawnFrames >= attackData.drawTime then
                if attackData.weapon:getCurrentAmmoCount() == 0 then
                    -- Dry-firing the bow damages it.
                    character:Say(getText("UI_no_arrow"))
                    character:playSound("ArrowHit");
                    attackData.weapon:setCondition(attackData.weapon:getCondition() - 2);
                    MandelaBowAndArrow.Client.SetBowAndArrowModel(character, attackData.weapon, 1);
                else
                    -- Override the bow's attack sound.
                    attackData.weapon:setSwingSound("BowFire")
                    -- Let the base mod's code handle it from here.
                    if isDebugEnabled() then
                        print("AltDrawAddOn debug: calling original Bow and Arrow attackHook to handle firing.")
                    end
                    MandelaBowAndArrow.Client.altDrawOriginalAttackHook(character, 1, attackData.weapon)
                end
            else
                -- Stop playing the sound of the bow being drawn.
                character:getEmitter():stopOrTriggerSound(attackData.drawSoundId)
                if isDebugEnabled() then
                    print("AltDrawAddOn debug: released while not aiming or before bow fully drawn.")
                end
            end
            attackData.bowDrawnFrames = 0
            attackData.weapon = nil
        elseif isDebugEnabled() then
            print("AltDrawAddOn debug: no attackData or attackData.weapon for player")
        end
    end

    MandelaBowAndArrow.Client.attackHook = function(character, chargeDelta, weapon)
        if not MandelaBowAndArrow.Client.isMandelaBow(weapon:getFullType()) or character:isDoShove() then
            return MandelaBowAndArrow.Client.altDrawOriginalAttackHook(character, chargeDelta, weapon)
        end
        -- Else they're trying to fire a bow
        ISTimedActionQueue.clear(character)
        local attackData = attackDataForCharacter[character:getPlayerNum()]
        if not attackData then
            attackData = {
                bowDrawnFrames = 0
            }
            attackDataForCharacter[character:getPlayerNum()] = attackData
        end
        if attackData.bowDrawnFrames == 0 then
            attackData.weapon = weapon
            attackData.drawSoundId = character:playSound("BowDraw")
            -- drawTime starts at 50 at skill 0, and rapidly drops for the first few levels.
            attackData.drawTime = 5 + 90 / (2 + MandelaBowAndArrow.Client.getArcherySkill(character))
            if isDebugEnabled() then
                print("AltDrawAddOn debug: setting attackData.releaseCount for player ", character:getPlayerNum(),
                        " from ", attackData.releaseCount, " to 2")
            end
            attackData.releaseCount = 2
            -- Rather than detecting mouseUp, which won't work for players on controllers or who have remapped the melee
            -- button, register an onTick callback to detect when they stop attacking by detecting when releaseCount is
            -- no longer being reset every tick.
            local releaseBowClosure
            releaseBowClosure = function ()
                if isDebugEnabled() then
                    print("AltDrawAddOn debug: releaseBowClosure decreasing attackData.releaseCount for player ", character:getPlayerNum(),
                            " from ", attackData.releaseCount, " to ", attackData.releaseCount - 1)
                end
                attackData.releaseCount = attackData.releaseCount - 1
                if attackData.releaseCount <= 0 then
                    if isDebugEnabled() then
                        print("AltDrawAddOn debug: attackData.releaseCount <= 0, loosing arrow!")
                    end
                    -- They've stopped holding down the attack key/button, so loose the arrow!
                    MandelaBowAndArrow.Client.altDrawLooseArrow(character)
                    Events.OnTick.Remove(releaseBowClosure)
                end
            end
            Events.OnTick.Add(releaseBowClosure)
        end
        attackData.bowDrawnFrames = attackData.bowDrawnFrames + getGameTime():getMultiplier()
        local weaponModData = MandelaBowAndArrow.Shared.getModData(attackData.weapon)
        if attackData.bowDrawnFrames >= attackData.drawTime and not weaponModData.isDrawn then
            -- Stop playing the sound of the bow being drawn, as an audio cue to the player that it's ready to fire.
            character:getEmitter():stopOrTriggerSound(attackData.drawSoundId)
            -- Show the bow fully drawn
            MandelaBowAndArrow.Client.SetBowAndArrowModel(character, attackData.weapon, 2);
            weaponModData.isDrawn = true
        end
        attackData.releaseCount = 2
        return true
    end

end

if not MandelaBowAndArrow.Client.altDrawOriginalAttackHook then
    -- The first time we run this code, hook the OnGameStart event.
    Events.OnGameStart.Add(doAlternateDrawAlterations)
else
    -- If we reload the script, we want to re-run the override function immediately.
    doAlternateDrawAlterations()
end
