
local function doAlternateDrawAlterations()
    if not MandelaBowAndArrow.Client.altDrawOriginalAttackHook then
        MandelaBowAndArrow.Client.altDrawOriginalAttackHook = MandelaBowAndArrow.Client.attackHook
    end

    MandelaBowAndArrow.Client.Sounds.HitHead = 'HeadHit'
    MandelaBowAndArrow.Client.Sounds.HitBody = 'FleshHit'

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
                    MandelaBowAndArrow.Shared.getModData(character).isDrawn = true
                    -- Let the base mod's code handle it from here.
                    MandelaBowAndArrow.Client.altDrawOriginalAttackHook(attackData.character, 1, attackData.weapon)
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
                bowDrawnFrames = 0,
                character = character
            }
            attackDataForCharacter[character:getPlayerNum()] = attackData
        end
        if attackData.bowDrawnFrames == 0 then
            weapon:setSwingSound("BowFire")
            attackData.weapon = weapon
            attackData.drawSoundId = character:playSound("BowDraw")
            attackData.drawTime = 40 - 3 * MandelaBowAndArrow.Client.getArcherySkill(character)
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
        attackData.bowDrawnFrames = attackData.bowDrawnFrames + 1
        if attackData.bowDrawnFrames == attackData.drawTime then
            -- Stop playing the sound of the bow being drawn, as an audio cue to the player that it's ready to fire.
            character:getEmitter():stopOrTriggerSound(attackData.drawSoundId)
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
