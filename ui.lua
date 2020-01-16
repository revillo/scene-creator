-- Start / stop

function Client:startUi()
    self.componentSectionOpens = setmetatable({}, { __mode = 'k' }) -- `actor` -> `behaviorId` of open component section
end


-- UI

function Client:uiToolbar()
    ui.button('toggle performing', {
        icon = 'play',
        iconFamily = 'FontAwesome',
        hideLabel = true,
        selected = self.performing,
        onClick = function()
            self:send('setPerforming', not self.performing)
        end,
    })

    ui.box('spacer', { flex = 1 }, function() end)

    -- Tools
    if next(self.selectedActorIds) then
        local order = {}
        for _, tool in pairs(self.applicableTools) do
            table.insert(order, tool)
        end
        table.sort(order, function(tool1, tool2)
            return tool1.behaviorId < tool2.behaviorId
        end)
        for _, tool in ipairs(order) do
            ui.button(tool.name, {
                icon = tool.tool.icon,
                iconFamily = tool.tool.iconFamily,
                hideLabel = true,
                selected = self.activeToolBehaviorId == tool.behaviorId,
                onClick = function()
                    self:setActiveTool(tool.behaviorId)
                end,
            })
        end
    end

    -- Duplicate
    if next(self.selectedActorIds) then
        ui.button('duplicate actor', {
            icon = 'copy',
            iconFamily = 'FontAwesome5',
            hideLabel = true,
            onClick = function()
                local duplicateActorIds = {}

                -- Use blueprints to duplicate. Nudge position a little bit.
                for actorId in pairs(self.selectedActorIds) do
                    local bp = self:blueprintActor(actorId)
                    if bp.Body then
                        bp.Body.x, bp.Body.y = bp.Body.x + 64, bp.Body.y + 64
                    end
                    local actor = self.actors[actorId]
                    duplicateActorIds[self:sendAddActor(bp, actor.parentEntryId)] = true
                end

                -- Select new actors
                self:deselectAllActors()
                for actorId in pairs(duplicateActorIds) do
                    self:selectActor(actorId)
                end
            end,
        })
    end

    -- Delete
    if next(self.selectedActorIds) then
        ui.button('remove actor', {
            icon = 'trash-alt',
            iconFamily = 'FontAwesome5',
            hideLabel = true,
            onClick = function()
                for actorId in pairs(self.selectedActorIds) do
                    self:deselectActor(actorId)
                    self:send('removeActor', self.clientId, actorId)
                end
            end,
        })
    end
end

function Client:uiProperties()
    ui.scrollBox('scrollBox1', {
        padding = 2,
        margin = 2,
        flex = 1,
    }, function()
        local actorId = next(self.selectedActorIds)
        if actorId then
            local actor = self.actors[actorId]

            -- Sort by `behaviorId`
            local order = {}
            for behaviorId, component in pairs(actor.components) do
                local behavior = self.behaviors[behaviorId]
                if not behavior.tool and behavior.handlers.uiComponent then
                    table.insert(order, component)
                end
            end
            table.sort(order, function (component1, component2)
                return component1.behaviorId < component2.behaviorId
            end)

            -- Sections for each component
            for _, component in ipairs(order) do
                local behavior = self.behaviors[component.behaviorId]

                local uiName = behavior:getUiName()
                local newOpen = ui.section(uiName, {
                    id = actorId .. '-' .. component.behaviorId,
                    open = self.componentSectionOpens[actor] == component.behaviorId,
                }, function()
                    behavior:callHandler('uiComponent', component, {})
                end)

                -- Track open section
                if newOpen then
                    self.componentSectionOpens[actor] = component.behaviorId
                elseif self.componentSectionOpens[actor] == component.behaviorId then
                    self.componentSectionOpens[actor] = 'none' -- Sentinel to mark none as open
                end
            end

            -- Add component
            ui.box('spacer', { height = 16 }, function() end)
            local order = {}
            for behaviorId, behavior in pairs(self.behaviors) do
                if not actor.components[behaviorId] and not behavior.tool then
                    table.insert(order, behavior)
                end
            end
            table.sort(order, function (behavior1, behavior2)
                return behavior1.behaviorId < behavior2.behaviorId
            end)
            local uiNameOrder = {}
            local behaviorsByUiName = {}
            for _, behavior in ipairs(order) do
                local uiName = behavior:getUiName()
                table.insert(uiNameOrder, uiName)
                behaviorsByUiName[uiName] = behavior
            end
            ui.dropdown('add component', 'add component...', uiNameOrder, {
                hideLabel = true,
                onChange = function(addUiName)
                    local behavior = behaviorsByUiName[addUiName]
                    if behavior then
                        self:send('addComponent', self.clientId, actorId, behavior.behaviorId, {})
                    end
                end,
            })

            --local actorId = next(self.selectedActorIds)
            --if actorId then
            --    ui.button('add to library', {
            --        popoverAllowed = true,
            --        popover = function()
            --            self.addToLibraryTitle = ui.textInput('title', self.addToLibraryTitle)
            --
            --            self.addToLibraryDescription = ui.textInput('description', self.addToLibraryDescription)
            --
            --            if ui.button('save') then
            --                local entryId = util.uuid()
            --
            --                local actorBlueprint = self:blueprintActor(actorId)
            --
            --                print(serpent.block(actorBlueprint))
            --
            --                self:send('addLibraryEntry', entryId, {
            --                    entryType = 'actorBlueprint',
            --                    title = self.addToLibraryTitle,
            --                    description = self.addToLibraryDescription,
            --                    actorBlueprint = actorBlueprint,
            --                })
            --                self.addToLibraryTitle = ''
            --                self.addToLibraryDescription = ''
            --            end
            --        end,
            --    })
            --end
        end
    end)
end

function Client:uiupdate()
    if not castle.system.isMobile() then
        ui.markdown('# Hello!\nThis prototype is meant for mobile. :O')
        return
    end

    -- Refresh tools first to make sure selections / applicable tool set / etc. are valid
    self:refreshTools() 

    -- Toolbar
    ui.pane('toolbar', {
        customLayout = true,
        flexDirection = 'row',
        padding = 2,
    }, function()
        self:uiToolbar()
    end)

    -- Panel
    ui.pane('default', { customLayout = true }, function()
        ui.tabs('tabs', {
            containerStyle = { flex = 1, margin = 0 },
            contentStyle = { flex = 1 },
        }, function()
            -- Blueprints tab
            ui.tab('blueprints', function()
                self:uiLibrary({
                    filterType = 'actorBlueprint',
                    buttons = function(entry)
                        ui.button('add to scene', {
                            flex = 1,
                            icon = 'plus',
                            iconFamily = 'FontAwesome5',
                            onClick = function()
                                -- Stop performing
                                self:send('setPerforming', false)

                                -- Add the actor, initializing some values in the blueprint
                                local actorBp = util.deepCopyTable(entry.actorBlueprint)
                                if actorBp.Body then -- Has a `Body`? Position at center of window.
                                    local windowWidth, windowHeight = love.graphics.getDimensions()
                                    actorBp.Body.x, actorBp.Body.y = 0.5 * windowWidth, 0.5 * windowHeight
                                end
                                local actorId = self:sendAddActor(actorBp, entry.entryId)

                                -- Select the actor. If it has a `Body`, switch to the `Grab` tool.
                                if actorBp.Body then
                                    self:setActiveTool(nil)
                                end
                                self:deselectAllActors()
                                self:selectActor(actorId)
                                self:refreshTools()
                                if actorBp.Body then
                                    self:setActiveTool(self.behaviorsByName.Grab.behaviorId)
                                end
                            end
                        })
                    end,
                })
            end)

            -- Properties tab
            ui.tab('properties', function()
                self:uiProperties()
            end)
        end)
    end)
end