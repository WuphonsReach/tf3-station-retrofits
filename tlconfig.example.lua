return {
	include_dir = {
		-- ensure to set proper paths for the definitions for the base game
		"<tf3_install_folder>api/tealdef",
		"<tf3_install_folder>base/tealdef",

		-- this mod's own definitions (the shared levels module), for type checking only
		"types",
	},
	global_env_def = "all_def"
}
