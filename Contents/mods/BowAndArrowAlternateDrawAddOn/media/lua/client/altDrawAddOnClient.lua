
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
        if player:isAiming() then
            playerModData.aiming = true
        else
            MandelaBowAndArrow.Client.altDrawOriginalSetUpBow(player, bow)
        end
    end

    local attackDataForCharacter = {}

    MandelaBowAndArrow.Client.altDrawLooseArrow = function(character)
        local attackData = attackDataForCharacter[character:getPlayerNum()]
        if attackData and attackData.weapon then
            if character:isAiming() and attackData.bowDrawnFrames >= attackData.drawTime then
                if attackData.weapon:getCurrentAmmoCount() == 0 then
                    -- Dry-firing the bow damages it.
                    character:Say('No arrow!')
                    character:playSound("ArrowHit");
                    attackData.weapon:setCondition(attackData.weapon:getCondition() - 2);
                else
                    -- Override the bow's attack sound.
                    attackData.weapon:setSwingSound("BowFire")
                    -- Let the base mod's code handle it from here.
                    MandelaBowAndArrow.Client.altDrawOriginalAttackHook(character, 1, attackData.weapon)
                end
            end
            attackData.bowDrawnFrames = 0
            attackData.weapon = nil
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
            attackData.releaseCount = 2
            -- Rather than detecting mouseUp, which won't work for players on controllers or who have remapped the melee
            -- button, register an onTick callback to detect when they stop attacking by detecting when releaseCount is
            -- no longer being reset every tick.
            local releaseBowClosure
            releaseBowClosure = function ()
                attackData.releaseCount = attackData.releaseCount - 1
                if attackData.releaseCount <= 0 then
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
