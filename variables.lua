-- Start / stop

function Common:startVariables()
    self.variables = {}
end

-- Message kind definitions

function Common:defineVariablesMessageKinds()
    -- From anyone to all
    self:defineMessageKind("updateVariables", self.sendOpts.reliableToAll)
end

-- Message receivers

function Common.receivers:updateVariables(time, variables)
    for i = 1, #variables do
        if not variables[i].value then
            variables[i].value = variables[i].initialValue
        end
    end

    self.variables = variables
    self._initialVariables = util.deepCopyTable(variables or {})
end

-- Utils

function Common:variablesReset()
    if self._initialVariables then
        self:send("updateVariables", self._initialVariables)
    end
end

function Common:variablesNames()
    local names = {}
    for i = 1, #self.variables do
        names[i] = self.variables[i].name
    end
    return names
end

function Common:variableNameToId(name)
    for i = 1, #self.variables do
        if self.variables[i].name == name then
            return self.variables[i].id
        end
    end

    return nil
end

function Common:variableIdToName(id)
    for i = 1, #self.variables do
        if self.variables[i].id == id then
            return self.variables[i].name
        end
    end

    return "(none)"
end

local function fireVariableTriggers(self, variableId, newValue)
    jsEvents.send(
        "GHOST_MESSAGE",
        {
            messageType = "CHANGE_DECK_STATE",
            data = {
                variables = self.variables
            }
        }
    )

    for actorId, actor in pairs(self.actors) do
        self.behaviorsByName.Rules:fireTrigger(
            "variable changes",
            actorId,
            {},
            {
                filter = function(params)
                    return params.variableId == variableId
                end
            }
        )

        self.behaviorsByName.Rules:fireTrigger(
            "variable reaches value",
            actorId,
            {},
            {
                filter = function(params)
                    if params.variableId ~= variableId then
                        return false
                    end

                    if params.comparison == "equal" and newValue == params.value then
                        return true
                    end
                    if params.comparison == "less or equal" and newValue <= params.value then
                        return true
                    end
                    if params.comparison == "greater or equal" and newValue >= params.value then
                        return true
                    end
                    return false
                end
            }
        )
    end
end

function Common:variableSetToValue(variableId, value)
    for i = 1, #self.variables do
        if self.variables[i].id == variableId then
            self.variables[i].value = value

            fireVariableTriggers(self, variableId, self.variables[i].value)
        end
    end
end

function Common:variableChangeByValue(variableId, changeBy)
    for i = 1, #self.variables do
        if self.variables[i].id == variableId then
            self.variables[i].value = self.variables[i].value + changeBy

            fireVariableTriggers(self, variableId, self.variables[i].value)
        end
    end
end
