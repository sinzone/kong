local constants = require "kong.constants"
local schemas = require "kong.dao.schemas"
local BaseDao = require "kong.dao.cassandra.base_dao"
local cjson = require "cjson"

local error_types = constants.DATABASE_ERROR_TYPES

local SCHEMA = {
  id = { type = "id" },
  api_id = { type = "id", required = true, foreign = true, queryable = true },
  application_id = { type = "id", foreign = true, queryable = true },
  name = { required = true, queryable = true, immutable = true },
  value = { type = "table", required = true },
  enabled = { type = "boolean", default = true },
  created_at = { type = "timestamp" }
}

local Plugins = BaseDao:extend()

function Plugins:new(properties)
  self._schema = SCHEMA
  self._queries = {
    insert = {
      params = { "id", "api_id", "application_id", "name", "value", "enabled", "created_at" },
      query = [[ INSERT INTO plugins(id, api_id, application_id, name, value, enabled, created_at)
                  VALUES(?, ?, ?, ?, ?, ?, ?); ]]
    },
    update = {
      params = { "api_id", "application_id", "value", "enabled", "created_at", "id", "name" },
      query = [[ UPDATE plugins SET api_id = ?, application_id = ?, value = ?, enabled = ?, created_at = ? WHERE id = ? AND name = ?; ]]
    },
    select = {
      query = [[ SELECT * FROM plugins %s; ]]
    },
    select_one = {
      params = { "id" },
      query = [[ SELECT * FROM plugins WHERE id = ?; ]]
    },
    delete = {
      params = { "id" },
      query = [[ DELETE FROM plugins WHERE id = ?; ]]
    },
    __custom_checks = {
      unique = {
        params = { "api_id", "application_id", "name" },
        query = [[ SELECT * FROM plugins WHERE api_id = ? AND application_id = ? AND name = ? ALLOW FILTERING; ]]
      }
    },
    __foreign = {
      api_id = {
        params = { "api_id" },
        query = [[ SELECT id FROM apis WHERE id = ?; ]]
      },
      application_id = {
        params = { "application_id" },
        query = [[ SELECT id FROM applications WHERE id = ?; ]]
      }
    }
  }

  Plugins.super.new(self, properties)
end

function Plugins:_check_value_schema(t)
  local status, plugin_schema = pcall(require, "kong.plugins."..t.name..".schema")
  if not status then
    return false, self:_build_error(error_types.SCHEMA, "Plugin \""..object.name.."\" not found")
  end

  local valid, errors = schemas.validate(t.value, plugin_schema)
  if not valid then
    return false, self:_build_error(error_types.SCHEMA, errors)
  else
    return true
  end
end

function Plugins:_check_unicity(t, is_updating)
  local unique, err = self:_check_unique(self._statements.__custom_checks.unique, t, is_updating)
  if err then
    return false, err
  elseif not unique then
    return false, self:_build_error(error_types.UNIQUE, "Plugin already exists")
  else
    return true
  end
end

-- @override
function Plugins:_unmarshall(rows)
  for _, row in ipairs(rows) do
    -- deserialize values (tables)
    for k, v in pairs(row) do
      if self._schema[k].type == "table" then
        row[k] = cjson.decode(v)
      end
    end
    -- remove application_id if null uuid
    if row.application_id == constants.DATABASE_NULL_ID then
      row.application_id = nil
    end
  end

  return rows
end

-- @override
function Plugins:insert(t)
  if t.application_id == nil then
    t.application_id = constants.DATABASE_NULL_ID
  end

  local valid_schema, err = schemas.validate(t, self._schema)
  if not valid_schema then
    return nil, self:_build_error(error_types.SCHEMA, err)
  end

  -- Checking plugin unicity
  local ok, err = self:_check_unicity(t)
  if not ok then
    return nil, err
  end

  -- Checking value schema validation
  local ok, err = self:_check_value_schema(t)
  if not ok then
    return nil, err
  end

  return Plugins.super.insert(self, t)
end

-- @override
function Plugins:update(t)
  if t.application_id == nil then
    t.application_id = constants.DATABASE_NULL_ID
  end

  local valid_schema, err = schemas.validate(t, self._schema, true)
  if not valid_schema then
    return nil, self:_build_error(error_types.SCHEMA, err)
  end

  -- Checking plugin unicity
  local ok, err = self:_check_unicity(t, true)
  if not ok then
    return nil, err
  end

  -- Checking value schema validation
  local ok, err = self:_check_value_schema(t)
  if not ok then
    return nil, err
  end

  return Plugins.super.update(self, t)
end

return Plugins
