if not MandelaBowAndArrow.Client.altDrawOriginalTooltipRender then
    -- Take a copy of the original functions, in such a way that the script can be reloaded in the debugger and we
    -- still keep a reference to the originals.
    MandelaBowAndArrow.Client.altDrawOriginalTooltipPrerender = ISToolTipInv.prerender
    MandelaBowAndArrow.Client.altDrawOriginalDrawItemDetails = ISInventoryPane.drawItemDetails
end

-- Bow strings in the base mod are now of type MandelaBowString2, but right now it hasn't updated its tooltip code
-- from when they used to be of type MandelaBowString.  Do a switcheroo and make their tooltip code think that it's
-- showing details for a MandelaBowString.
function ISToolTipInv:prerender()
    -- Since the base mode overriders ISToolTipInv:render in the prerender, we have to do the same.
    MandelaBowAndArrow.Client.altDrawOriginalTooltipPrerender(self)
    local baseModOverriddenRender = ISToolTipInv.render
    function ISToolTipInv:render()
        if self.item:getType() == 'MandelaBowString2' then
            self.item:setType('MandelaBowString')
            baseModOverriddenRender(self)
            self.item:setType('MandelaBowString2')
        else
            baseModOverriddenRender(self)
        end
    end
    ISToolTipInv.prerender = MandelaBowAndArrow.Client.altDrawOriginalTooltipPrerender
end

-- Show the item condition of bow strings when expanding a stack in the inventory panel.  Include the previous
-- MandelaBowString too, because why not?
function ISInventoryPane:drawItemDetails(item, y, xoff, yoff, red)
    if item:getType() == 'MandelaBowString' or item:getType() == 'MandelaBowString2' then
        local top = self.headerHgt + y * self.itemHgt + yoff
        local hc = getCore():getGoodHighlitedColor()
        local fgBar = {r=hc:getR(), g=hc:getG(), b=hc:getB(), a=1}
        local fgText = {r=0.6, g=0.8, b=0.5, a=0.6}
        local text = getText("IGUI_invpanel_Condition") .. ":"
        local modData = MandelaBowAndArrow.Shared.getModData(item);
        local condition = modData.condition or 1
        self:drawTextAndProgressBar(text, condition, xoff, top, fgText, fgBar)
    else
        MandelaBowAndArrow.Client.altDrawOriginalDrawItemDetails(self, item, y, xoff, yoff, red)
    end
end