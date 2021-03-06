#!/usr/bin/env lua

local cli = require "cliargs"
local utils = require "kong.tools.utils"
local Migrations = require "kong.tools.migrations"

cli:set_name("db.lua")
cli:add_argument("COMMAND", "<create|migrate|rollback|reset|seed|drop>")
cli:add_option("-n, --name=NAME", "If <create>, sets a name to the migration", "new_migration")
cli:add_flag("-r, --random", "If seeding, also seed random entities (1000 for each collection by default)")
cli:add_flag("-s, --silent", "No output")
cli:optarg("CONFIGURATION", "configuration path", "config.dev/kong.yml")

local args = cli:parse(arg)
if not args then
  os.exit(1)
end

local logger = utils.logger:new(args.silent)
local configuration, dao = utils.load_configuration_and_dao(args.CONFIGURATION)

if args.COMMAND == "create" then

  Migrations.create(configuration, args.name, function(interface, file_path, file_name)
    os.execute("mkdir -p "..file_path)

    local file = file_path.."/"..file_name..".lua"
    utils.write_to_file(file, interface)
    logger:success("New migration: "..file)
  end)

elseif args.COMMAND == "migrate" then

  logger:log("Migrating "..utils.yellow(dao.type))

  dao:migrate(function(migration, err)
    if err then
      logger:error(err)
    else
      logger:success("Migrated up to: "..utils.yellow(migration.name))
    end
  end)

elseif args.COMMAND == "rollback" then

  logger:log("Rolling back "..utils.yellow(dao.type))

  dao:rollback(function(migration, err)
    if err then
      logger:error(err)
    else
      logger:success("Rollbacked to: "..utils.yellow(migration.name))
    end
  end)

elseif args.COMMAND == "reset" then

  logger:log("Resetting "..utils.yellow(dao.type))

  dao:reset(function(migration, err)
    if err then
      logger:error(err)
    else
      logger:success("Rollbacked: "..utils.yellow(migration.name))
    end
  end)

elseif args.COMMAND == "seed" then

  -- Drop if exists
  local err = dao:drop()
  if err then
    logger:error(err)
  end

  local err = dao:prepare()
  if err then
    logger:error(err)
  end

  dao:seed(args.random)
  logger:success("Populated")

elseif args.COMMAND == "drop" then

  dao:drop()
  logger:success("Dropped")

else
  print("Invalid command: "..args.COMMAND)
end
