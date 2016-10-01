fs = require "fs"
l = require("log4js").getLogger "modloader"

modules = {}

load = (e) ->
	fs.readdir "#{__dirname}/../modules/", (err, files) ->
		if err
			l.error "There was a problem reading the module directory."
			l.error err
			return

		files.forEach (file) ->
			try
				mod = require "../modules/#{file}"
			catch err
				l.error "Module file #{file} threw an error during the require call!"
				l.error err
				return

			unless mod.name
				l.error "Module file #{file} has no name!"
				return

			unless mod.init
				l.error "Module #{mod.name} has no init function!"
				return

			try
				mod.init e

				modules["../modules/#{file}"] = mod

				l.info "Loaded #{mod.name}."
			catch err
				l.error "Module #{mod.name} threw an error while initializing!"
				l.error err
			finally
				if mod.exposed
					module.exports[mod.name] = mod.exposed

reload = (e) ->
	Object.keys(modules).forEach (n) ->
		name = require.find n

		unless name
			return

		delete require.cache[require.resolve(name).id];

	load(e)

module.exports =
	"load": load
	"reload": reload
