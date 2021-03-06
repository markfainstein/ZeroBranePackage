-- Implements MCServer interpreter description and interface for ZBStudio.
-- MCServer executable can have a postfix depending on the compilation mode (debug / release).

local function MakeMCServerInterpreter(a_InterpreterPostfix, a_ExePostfix)
	assert(type(a_InterpreterPostfix) == "string")
	assert(type(a_ExePostfix) == "string")

	return
	{
		name = "MCServer" .. a_InterpreterPostfix,
		description = "MCServer - the custom C++ minecraft server",
		api = {"baselib", "mcserver_api"},

		frun = function(self, wfilename, withdebug)
			-- MCServer plugins are always in a "Plugins/<PluginName>" subfolder located at the executable level
			-- Get to the executable by removing the last two dirs:
			local ExePath = wx.wxFileName(wfilename)
			ExePath:RemoveLastDir()
			ExePath:RemoveLastDir()
			ExePath:ClearExt()
			ExePath:SetName("")
			local ExeName = wx.wxFileName(ExePath)

			-- The executable name depends on the debug / non-debug build mode, it can have a postfix
			ExeName:SetName("MCServer" .. a_ExePostfix)

			-- Executable has a .exe ext on Windows
			if (ide.osname == 'Windows') then
				ExeName:SetExt("exe")
			end

			-- Start the debugger server:
			if withdebug then
				DebuggerAttachDefault({
					runstart = (ide.config.debugger.runonstart == true),
					basedir = ExePath:GetFullPath(),
				})
			end

			-- Add a "nooutbuf" cmdline param to the server, causing it to call setvbuf to disable output buffering:
			local Cmd = ExeName:GetFullPath() .. " nooutbuf"

			-- Force ZBS not to hide MCS window, save and restore previous state:
			local SavedUnhideConsoleWindow = ide.config.unhidewindow.ConsoleWindowClass
			ide.config.unhidewindow.ConsoleWindowClass = 1  -- show if hidden
			
			-- Create the @EnableMobDebug.lua file so that the MCS plugin starts the debugging session, when loaded:
			local EnablerPath = wx.wxFileName(wfilename)
			EnablerPath:SetName("@EnableMobDebug")
			EnablerPath:SetExt("lua")
			local f = io.open(EnablerPath:GetFullPath(), "w")
			if (f ~= nil) then
				f:write([[require("mobdebug").start()]])
				f:close()
			end
			
			-- Create the closure to call upon debugging finish:
			local OnFinished = function()
				-- Restore the Unhide status:
				ide.config.unhidewindow.ConsoleWindowClass = SavedUnhideConsoleWindow
			
				-- Remove the @EnableMobDebug.lua file:
				os.remove(EnablerPath:GetFullPath())
			end

			-- Run the server:
			local pid = CommandLineRun(
				Cmd,                    -- Command to run
				ExePath:GetFullPath(),  -- Working directory for the debuggee
				false,                  -- Redirect debuggee output to Output pane? (NOTE: This force-hides the MCS window, not desirable!)
				true,                   -- Add a no-hide flag to WX
				nil,                    -- StringCallback, whatever that is
				nil,                    -- UID to identify this running program; nil to auto-assign
				OnFinished              -- Callback to call once the debuggee terminates
			)
		end,

		hasdebugger = true,
	}
end





return {
	name = "MCServer integration",
	description = "Integration with MCServer - the custom C++ minecraft server.",
	author = "Mattes D (https://github.com/madmaxoft)",
	version = 0.2,

	onRegister = function(self)
		ide:AddInterpreter("mcserver_debug", MakeMCServerInterpreter(" - debug mode", "_debug"))
		ide:AddInterpreter("mcserver_release", MakeMCServerInterpreter(" - release mode", ""))
	end,

	onUnRegister = function(self)
		ide:RemoveInterpreter("mcserver_debug")
		ide:RemoveInterpreter("mcserver_release")
	end,
}




