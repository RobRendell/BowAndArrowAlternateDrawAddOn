
local function doAlternateDrawAlterations()
    if not MandelaBowAndArrow.Client.altDrawOriginalAttackHook then
        MandelaBowAndArrow.Client.altDrawOriginalAttackHook = MandelaBowAndArrow.Client.attackHook
        MandelaBowAndArrow.Client.altDrawOriginalSetUpBow = MandelaBowAndArrow.Client.setUpBow
    end

    MandelaBowAndArrow.Client.Sounds.HitHead = 'HeadHit'
    MandelaBowAndArrow.Client.Sounds.HitBody = 'FleshHit'

    -- Override setUpBow so that a player doesn't draw their bow by simply aiming.
    MandelaBowAndArrow.Client.setUpBow = function(player, bow)
        -- Change from the official MandelaArrowWoodDucttapeIronAttachment type to MandelaArrowWoodDucttapeIron, since
        -- MandelaArrowWoodDucttapeIronAttachment doesn't work for the Weapon Condition Mod's ammo count anyway.
        bow:setAmmoType("Base.MandelaArrowWoodDucttapeIron")
        -- Change the subcategory of bows so they're not considered firearms.
        bow:setSubCategory("Bow");
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

    local Client = MandelaBowAndArrow.Client;
    local Shared = MandelaBowAndArrow.Shared;

    Client.onPlayerUpdateWrapper = function (player)
        Client.onPlayerUpdate(player)
    end
    Events.OnPlayerUpdate.Remove(Client.onPlayerUpdate);
    Events.OnPlayerUpdate.Remove(Client.onPlayerUpdateWrapper);
    Events.OnPlayerUpdate.Add(Client.onPlayerUpdateWrapper);

    --More copy-pasta :(
    local function StrReplace(thisString, findThis, replaceWithThis)
        return string.gsub(thisString, "("..findThis..")", replaceWithThis);
    end

    local function IsIn(big,small)
        local temp = StrReplace(big,small,"");
        if(temp == big) then
            return false
        else
            return true;
        end
    end

    -- Make the arrows pass over low obstacles.  Massive copy-paste of massive function :-(
    Client.onPlayerUpdate = function(player)
        --if not player:isGhostMode() then player:setGhostMode(true) end
        local weapon = player:getPrimaryHandItem();
        if weapon ~= nil then
            if Client.Bows[weapon:getFullType()] ~= nil then
                Client.setUpBow(player,weapon);
            end
        end
        if player:isLocalPlayer() then
            if Client.localPlayerObj == nil then Client.localPlayerObj = player end
            local modData = Shared.getModData(player);
            if modData.DistanceFlown == nil then Client.OnLoad(player); end
            if modData.MandelaBowAndArrowArrowNumber > 0 then
                local ArrowNumber = modData.MandelaBowAndArrowArrowNumber;

                for i=1,ArrowNumber do
                    local ArrowItem = nil;
                    local ArrowWorldItem = nil;
                    if modData.MandelaBowAndArrowArrowItem == nil or modData.MandelaBowAndArrowArrowZSpeed == nil then
                        ArrowItem = nil;
                    else
                        ArrowItem = modData.MandelaBowAndArrowArrowItem[i];
                    end
                    if ArrowItem == nil then
                        print("ArrowItem is nil");
                        --player:Say("ArrowItem is nil");
                        modData.MandelaBowAndArrowQueuedForRemoval[i] = true;
                    else
                        local Collision = false;

                        local ArrowX = modData.MandelaBowAndArrowArrowX[i];
                        local ArrowY = modData.MandelaBowAndArrowArrowY[i];
                        local ArrowZ = modData.MandelaBowAndArrowArrowZ[i];
                        local ArrowCellZ = math.floor(ArrowZ);
                        local ArrowXSpeed = modData.MandelaBowAndArrowArrowXSpeed[i];
                        local ArrowYSpeed = modData.MandelaBowAndArrowArrowYSpeed[i];
                        local ArrowZSpeed = modData.MandelaBowAndArrowArrowZSpeed[i];

                        local gravity = 0.003;

                        local divisions = 2;
                        for i2=1,divisions do
                            if Collision == false then
                                --ArrowZSpeed = ArrowZSpeed * ( 1 - 0.02);

                                do
                                    local beforeX, beforeY, beforeZ = ArrowX, ArrowY, ArrowZ;
                                    ArrowX = ArrowX + (ArrowXSpeed/divisions);
                                    ArrowY = ArrowY + (ArrowYSpeed/divisions);
                                    ArrowZ = ArrowZ + ((ArrowZSpeed/2)/divisions);
                                    if (tostring(beforeX) ~= Shared.nan and tostring(beforeY) ~= Shared.nan and tostring(beforeZ) ~= Shared.nan) and (tostring(ArrowX) == Shared.nan or tostring(ArrowY) == Shared.nan or tostring(ArrowZ) == Shared.nan) then
                                        print("caught a number becoming nan");
                                        print(beforeX, beforeY, beforeZ);
                                        print(ArrowX, ArrowY, ArrowZ);
                                        print(ArrowXSpeed, ArrowYSpeed, ArrowZSpeed);
                                        print(i, ArrowNumber, i2);
                                    end
                                end

                                local can_damage = true;
                                if ArrowItem:getRecoilpad() and Client.ArrowPartData[ArrowItem:getRecoilpad():getFullType()] ~= nil and Client.ArrowPartData[ArrowItem:getRecoilpad():getFullType()].fluflu == true then
                                    modData.DistanceFlown[i] = modData.DistanceFlown[i] + math.sqrt(ArrowXSpeed^2 + ArrowYSpeed^2)
                                    if modData.DistanceFlown[i] > 8 then
                                        can_damage = false
                                        ArrowXSpeed = ArrowXSpeed * ( 1 - (0.01 / divisions));
                                        ArrowYSpeed = ArrowYSpeed * ( 1 - (0.01 / divisions));
                                    end
                                end

                                ArrowZSpeed = ArrowZSpeed - (gravity / divisions);

                                --local Cell = IsoMetaGrid:

                                local Cell = getWorld():getCell();
                                local Square = Cell:getOrCreateGridSquare(ArrowX,ArrowY,ArrowZ);

                                local arrowCondition = ArrowItem:getCondition();
                                if ArrowItem:getWorldItem() ~= nil then
                                    ArrowItem:getWorldItem():getSquare():transmitRemoveItemFromSquare(ArrowItem:getWorldItem());
                                    ArrowItem:getWorldItem():removeFromSquare();
                                end

                                local targetCell = nil;
                                if modData.MandelaBowAndArrowTarget[i] ~= nil then
                                    targetCell = modData.MandelaBowAndArrowTarget[i]:getCell();
                                end
                                local upSquare = Cell:getOrCreateGridSquare(ArrowX,ArrowY,ArrowZ+1);
                                if Square == nil and targetCell ~= nil then
                                    Square = targetCell:getOrCreateGridSquare(ArrowX,ArrowY,ArrowZ);
                                    upSquare = targetCell:getOrCreateGridSquare(ArrowX,ArrowY,ArrowCellZ+1);
                                end
                                local sideSquare = Cell:getOrCreateGridSquare(ArrowX+1,ArrowY,ArrowZ);
                                if sideSquare == nil and targetCell ~= nil then
                                    sideSquare = targetCell:getOrCreateGridSquare(ArrowX+1,ArrowY,ArrowZ);
                                end
                                local backSquare = Cell:getOrCreateGridSquare(ArrowX,ArrowY+1,ArrowZ);
                                if backSquare == nil and targetCell ~= nil then
                                    backSquare = targetCell:getOrCreateGridSquare(ArrowX,ArrowY+1,ArrowZ);
                                end
                                local otherSideSquare = Cell:getOrCreateGridSquare(ArrowX-1,ArrowY,ArrowZ);
                                if otherSideSquare == nil and targetCell ~= nil then
                                    otherSideSquare = targetCell:getOrCreateGridSquare(ArrowX-1,ArrowY,ArrowZ);
                                end
                                local otherBackSquare = Cell:getOrCreateGridSquare(ArrowX,ArrowY-1,ArrowZ);
                                if otherBackSquare == nil and targetCell ~= nil then
                                    otherBackSquare = targetCell:getOrCreateGridSquare(ArrowX,ArrowY-1,ArrowZ);
                                end

                                local lastSquare = modData.MandelaBowAndArrowSquare[i];

                                if Square ~= nil then
                                    if ArrowZ < ArrowCellZ then
                                        local Square2 = getWorld():getCell():getOrCreateGridSquare(ArrowX,ArrowY,ArrowCellZ);
                                        if Square2 == nil and targetCell ~= nil then
                                            Square2 = targetCell:getOrCreateGridSquare(ArrowX,ArrowY,ArrowCellZ);
                                        end
                                        if Square2 ~= nil then
                                            if Square2:isSolidFloor() then Collision = true; end
                                        end
                                    end

                                    lastXoff = ArrowX - math.floor(ArrowX);
                                    lastYoff = ArrowY - math.floor(ArrowY);
                                    lastZoff = ArrowZ - math.floor(ArrowZ);
                                    if ArrowZ < 0.001 then lastZoff = 0; end

                                    if ArrowZ < 0 then
                                        ArrowZ = 0;
                                        Collision = true;
                                    else
                                        local movingObjects = Square:getObjects();
                                        for ii=0, movingObjects:size()-1 do
                                            if(player:getZ() < 3) then
                                                local collision = false;
                                                local wall = false;
                                                if (IsIn(tostring(movingObjects:get(ii):getType()),"stair")) then collision = true; end
                                                if (movingObjects:get(ii):getObjectName() == "Tree") and lastXoff > 0.25 and lastXoff < 0.75 and lastYoff > 0.25 and lastYoff < 0.75 then collision = true; end
                                                if (((tostring(movingObjects:get(ii):getType()) == "wall") and (not movingObjects:get(ii):isHoppable() or lastZoff < 0.4))
                                                        or (movingObjects:get(ii):getObjectName() == "Door")
                                                        or (movingObjects:get(ii):getObjectName() == "Window")) then
                                                    --if movingObjects:get(ii):isHoppable() and lastZoff < 0.4 then
                                                    --end
                                                    if (
                                                            (
                                                                    (Square ~= lastSquare) and (((lastXoff < 0.15/divisions) or (lastYoff < 0.15/divisions)) and lastSquare:isBlockedTo(Square))
                                                            )
                                                                    or (
                                                                    (Square == lastSquare) and
                                                                            (
                                                                                    ((lastXoff < 0.15/divisions) and (lastSquare:isBlockedTo(otherSideSquare)))
                                                                                            or ((lastYoff < 0.15/divisions) and (lastSquare:isBlockedTo(otherBackSquare)))
                                                                            )
                                                            )
                                                    ) then collision = true; wall = true; end
                                                end
                                                if collision then
                                                    --player:Say("Square collision " .. tostring(movingObjects:get(ii):isHoppable()));
                                                    CObject = movingObjects:get(ii);
                                                    Collision = true;
                                                    Square:playSound(Client.Sounds.HitTile);
                                                    addSound(player, ArrowX, ArrowY, ArrowZ, 10, 2);

                                                    if wall and ArrowXSpeed > 0 and lastXoff < 0.15/divisions and ArrowXSpeed^2 > ArrowYSpeed^2 and otherSideSquare ~= nil then
                                                        Square = otherSideSquare;
                                                        ArrowX = math.floor(ArrowX) - 0.05;
                                                        lastXoff = ArrowX - math.floor(ArrowX);
                                                        --player:Say("Adjusting on X");
                                                    end
                                                    if wall and ArrowYSpeed > 0 and lastYoff < 0.15/divisions and ArrowYSpeed^2 > ArrowXSpeed^2 and otherBackSquare ~= nil then
                                                        Square = otherBackSquare;
                                                        ArrowY = math.floor(ArrowY) - 0.05;
                                                        lastYoff = ArrowY - math.floor(ArrowY);
                                                        --player:Say("Adjusting on Y");
                                                    end
                                                end
                                            end
                                        end
                                        if sideSquare ~= nil then
                                            movingObjects = sideSquare:getObjects();
                                            for ii=0, movingObjects:size()-1 do
                                                if(player:getZ() < 3) then
                                                    local collision = false;
                                                    if (((tostring(movingObjects:get(ii):getType()) == "wall") and (not movingObjects:get(ii):isHoppable() or lastZoff < 0.4))
                                                            or (movingObjects:get(ii):getObjectName() == "Door")
                                                            or (movingObjects:get(ii):getObjectName() == "Window")) then
                                                        if (lastXoff > 1-(0.15/divisions)) and ((lastSquare ~= Square and lastSquare:isBlockedTo(Square)) or Square:isBlockedTo(sideSquare)) then collision = true; end
                                                    end
                                                    if collision then
                                                        --player:Say("sideSquare collision " .. tostring(movingObjects:get(ii):isHoppable()));
                                                        CObject = movingObjects:get(ii);
                                                        Collision = true;
                                                        Square:playSound(Client.Sounds.HitTile);
                                                        addSound(player, ArrowX, ArrowY, ArrowZ, 10, 2);

                                                        if ArrowXSpeed < 0 and lastXoff > 1-(0.15/divisions) and ArrowXSpeed^2 > ArrowYSpeed^2 then
                                                            Square = sideSquare;
                                                            ArrowX = math.floor(ArrowX) + 1.05;
                                                            lastXoff = ArrowX - math.floor(ArrowX);
                                                            --player:Say("Adjusting on X 2");
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                        if backSquare ~= nil then
                                            movingObjects = backSquare:getObjects();
                                            for ii=0, movingObjects:size()-1 do
                                                if(player:getZ() < 3) then
                                                    local collision = false;
                                                    if (((tostring(movingObjects:get(ii):getType()) == "wall") and (not movingObjects:get(ii):isHoppable() or lastZoff < 0.4))
                                                            or (movingObjects:get(ii):getObjectName() == "Door")
                                                            or (movingObjects:get(ii):getObjectName() == "Window")) then
                                                        if (lastYoff > 1-(0.15/divisions)) and ((lastSquare ~= Square and lastSquare:isBlockedTo(Square)) or Square:isBlockedTo(backSquare)) then collision = true; end
                                                    end
                                                    if collision then
                                                        --player:Say("backSquare collision " .. tostring(movingObjects:get(ii):isHoppable()));
                                                        CObject = movingObjects:get(ii);
                                                        Collision = true;
                                                        Square:playSound(Client.Sounds.HitTile);
                                                        addSound(player, ArrowX, ArrowY, ArrowZ, 10, 2);

                                                        if ArrowYSpeed < 0 and lastYoff > 1-(0.15/divisions) and ArrowYSpeed^2 > ArrowXSpeed^2 then
                                                            Square = backSquare;
                                                            ArrowY = math.floor(ArrowY) + 1.05;
                                                            lastYoff = ArrowY - math.floor(ArrowY);
                                                            --player:Say("Adjusting on Y 2");
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    if not Collision then
                                        if ArrowZ - math.floor(ArrowZ) <= 0.595 then
                                            Client.ArrowHitZombie(ArrowX-0.33,ArrowY-0.33,ArrowZ,player,ArrowItem,i,modData,ArrowX,ArrowY,ArrowZ,can_damage);
                                            Client.ArrowHitZombie(ArrowX,ArrowY,ArrowZ,player,ArrowItem,i,modData,ArrowX,ArrowY,ArrowZ,can_damage);
                                            Client.ArrowHitZombie(ArrowX+0.33,ArrowY+0.33,ArrowZ,player,ArrowItem,i,modData,ArrowX,ArrowY,ArrowZ,can_damage);
                                            Client.ArrowHitZombie(ArrowX+0.33,ArrowY,ArrowZ,player,ArrowItem,i,modData,ArrowX,ArrowY,ArrowZ,can_damage);
                                            Client.ArrowHitZombie(ArrowX,ArrowY+0.33,ArrowZ,player,ArrowItem,i,modData,ArrowX,ArrowY,ArrowZ,can_damage);
                                            Client.ArrowHitZombie(ArrowX-0.33,ArrowY,ArrowZ,player,ArrowItem,i,modData,ArrowX,ArrowY,ArrowZ,can_damage);
                                            Client.ArrowHitZombie(ArrowX,ArrowY-0.33,ArrowZ,player,ArrowItem,i,modData,ArrowX,ArrowY,ArrowZ,can_damage);
                                            Client.ArrowHitZombie(ArrowX+0.33,ArrowY-0.33,ArrowZ,player,ArrowItem,i,modData,ArrowX,ArrowY,ArrowZ,can_damage);
                                            Client.ArrowHitZombie(ArrowX-0.33,ArrowY+0.33,ArrowZ,player,ArrowItem,i,modData,ArrowX,ArrowY,ArrowZ,can_damage);
                                        end
                                    end

                                    if not modData.MandelaBowAndArrowInZombieAsAttachment[i] then
                                        if ArrowZ < ArrowCellZ then
                                            if upSquare ~= nil then
                                                ArrowWorldItem = upSquare:AddWorldInventoryItem(ArrowItem,lastXoff,lastYoff,lastZoff-1,false);
                                            else
                                                local groundSquare = Cell:getOrCreateGridSquare(ArrowX,ArrowY,0);
                                                if Square == nil and targetCell ~= nil then
                                                    groundSquare = targetCell:getOrCreateGridSquare(ArrowX,ArrowY,0);
                                                end
                                                ArrowWorldItem = groundSquare:AddWorldInventoryItem(ArrowItem,lastXoff,lastYoff,ArrowZ,false);
                                                --[[
                                                local scanning = true;
                                                for i=0,math.floor(ArrowZ+1) do
                                                    if scanning then
                                                        local scanZ = math.floor(ArrowZ+1) - i;
                                                        local scanSquare = Cell:getGridSquare(ArrowX,ArrowY,scanZ);
                                                        if scanSquare == nil and targetCell ~= nil then
                                                            scanSquare = targetCell:getGridSquare(ArrowX,ArrowY,scanZ);
                                                        end
                                                        if scanSquare ~= nil then
                                                            scanning = false;
                                                            scanSquare:AddWorldInventoryItem(ArrowItem,lastXoff,lastYoff,lastZoff-i);
                                                        end
                                                    end
                                                end]]--
                                            end
                                        else
                                            ArrowWorldItem = Square:AddWorldInventoryItem(ArrowItem,lastXoff,lastYoff,lastZoff,false);
                                        end
                                    end
                                else
                                    --modData.MandelaBowAndArrowQueuedForRemoval[i] = true;
                                    print("Bow and Arrow mod Error: Square is nil (2) ", i, i2);
                                    print("ArrowX, ArrowY, ArrowZ: ", ArrowX, ArrowY, ArrowZ);
                                    print("player:getX(), player:getY(), player:getZ(): ", player:getX(), player:getY(), player:getZ());
                                    print("Cell, targetCell", Cell, targetCell);
                                    if Cell then print("Cell:getGridSquare(ArrowX,ArrowY,ArrowZ)", Cell:getGridSquare(ArrowX,ArrowY,ArrowZ)) end
                                    if targetCell then print("targetCell:getGridSquare(ArrowX,ArrowY,ArrowZ)", targetCell:getGridSquare(ArrowX,ArrowY,ArrowZ)) end
                                    --player:Say("Square is nil");
                                    if tostring(modData.MandelaBowAndArrowArrowX[i]) == Shared.nan then
                                        modData.MandelaBowAndArrowQueuedForRemoval[i] = true;
                                        print("Removing glitched arrow");
                                        player:Say("Removing glitched arrow. The debug log may have details.");
                                    end
                                end

                                if Collision then
                                    modData.MandelaBowAndArrowLeavingArrow[i] = true;
                                    modData.MandelaBowAndArrowQueuedForRemoval[i] = true;
                                else
                                    modData.MandelaBowAndArrowArrowX[i] = ArrowX;
                                    modData.MandelaBowAndArrowArrowY[i] = ArrowY;
                                    modData.MandelaBowAndArrowArrowZ[i] = ArrowZ;
                                    modData.MandelaBowAndArrowArrowXSpeed[i] = ArrowXSpeed;
                                    modData.MandelaBowAndArrowArrowYSpeed[i] = ArrowYSpeed;
                                    modData.MandelaBowAndArrowArrowZSpeed[i] = ArrowZSpeed;
                                    modData.MandelaBowAndArrowSquare[i] = Square;
                                end
                            end

                            if (ArrowWorldItem ~= nil) and (not modData.MandelaBowAndArrowQueuedForRemoval[i]) then
                                ArrowWorldItem:setWorldZRotation(math.deg(math.atan2(ArrowYSpeed, ArrowXSpeed)));
                            end
                        end
                    end
                end

                for i=ArrowNumber, 1, -1 do
                    if modData.MandelaBowAndArrowQueuedForRemoval[i] == true then
                        --print("removal queue: " .. tostring(i));
                        --modData.MandelaBowAndArrowQueuedForRemoval[i] = false;
                        local ArrowX = modData.MandelaBowAndArrowArrowX[i];
                        local ArrowY = modData.MandelaBowAndArrowArrowY[i];
                        local ArrowZ = modData.MandelaBowAndArrowArrowZ[i];
                        --local Square = getWorld():getCell():getGridSquare(ArrowX,ArrowY,ArrowZ);
                        local Square = modData.MandelaBowAndArrowSquare[i];
                        Client.removeShotArrow(player,i,Square,ArrowX,ArrowY,ArrowZ);
                    end
                end
            end
        end
    end

end

if not MandelaBowAndArrow.Client.altDrawOriginalAttackHook then
    -- The first time we run this code, hook the OnGameStart event.
    Events.OnGameStart.Add(doAlternateDrawAlterations)
else
    -- If we reload the script, we want to re-run the override function immediately.
    doAlternateDrawAlterations()
end
