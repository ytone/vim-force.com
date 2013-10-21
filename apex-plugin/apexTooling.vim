" File: apexTooling.vim
" This file is part of vim-force.com plugin
"   https://github.com/neowit/vim-force.com
" Author: Andrey Gavrikov 
" Version: 0.1
" Last Modified: 2013-10-21
" Copyright: Copyright (C) 2010-2013 Andrey Gavrikov
"            Permission is hereby granted to use and distribute this code,
"            with or without modifications, provided that this copyright
"            notice is copied with it. Like anything else that's free,
"            this plugin is provided *as is* and comes with no warranty of any
"            kind, either expressed or implied. In no event will the copyright
"            holder be liable for any damages resulting from the use of this
"            software.
"
" apexTooling.vim - main methods dealing with Tooling API

" Part of vim/force.com plugin
"

if !exists("g:apex_tooling_api_enable") || 0 == g:apex_tooling_api_enable
  finish
endif
if exists("g:loaded_apexTooling") || &compatible
  finish
endif
let g:loaded_apexTooling = 1

" check that required global variables are defined
let s:requiredVariables = ["g:apex_java_cmd", "g:apex_tooling_force_com_jar"]
for varName in s:requiredVariables
	if !exists(varName)
		echoerr "Please define ".varName." See :help force.com-settings"
	endif
endfor	

function! s:getToolingCmd()
	let l:debugLevel = 'info'
	if exists("g:apex_tooling_debug_level")
		echo "switch debug level to " . g:apex_tooling_debug_level
		let l:debugLevel = g:apex_tooling_debug_level
	endif
	let l:cmd = g:apex_java_cmd . ' -Dorg.apache.commons.logging.simplelog.defaultlog=' . l:debugLevel . ' -jar ' . g:apex_tooling_force_com_jar 
	return l:cmd

endfunction	

function! apexTooling#refreshProject(filePath)
	let projectPair = apex#getSFDCProjectPathAndName(a:filePath)
	let responseFilePath = apexTooling#execute("refresh", projectPair.path, projectPair.name, {'tooling.resourcePath': projectPair.path})
	" process response results
	call s:processResponse(responseFilePath)
endfunction

function! apexTooling#refreshFile(filePath)
	let projectPair = apex#getSFDCProjectPathAndName(a:filePath)
	let responseFilePath = apexTooling#execute("refresh", projectPair.path, projectPair.name, {'tooling.resourcePath': a:filePath})
	" process response results
	call s:processResponse(responseFilePath)
endfunction

function! apexTooling#saveProject(filePath)
	let projectPair = apex#getSFDCProjectPathAndName(a:filePath)
	let srcPath = apex#getApexProjectSrcPath(a:filePath)

	let responseFilePath = apexTooling#execute("save", projectPair.path, projectPair.name, {'tooling.resourcePath': srcPath})
	" process response results
	call s:processResponse(responseFilePath)
endfunction

function! apexTooling#saveFile(filePath)
	let projectPair = apex#getSFDCProjectPathAndName(a:filePath)
	let responseFilePath = apexTooling#execute("save", projectPair.path, projectPair.name, {'tooling.resourcePath': a:filePath})
	" process response results
	call s:processResponse(responseFilePath)
endfunction

function! s:processResponse(responseFilePath)
	let prettyErrorList = []

	for line in readfile(a:responseFilePath, '')
		"if line =~ 'Date' | echo line | endif
		if line =~ '^MESSAGE: '
			let valueStr = strpart(line, len('MESSAGE:'))
			if !empty(valueStr)
				" parse
				let valueDict = eval(valueStr)
				let errLine = {}
				if has_key(valueDict, 'lnum') && valueDict.lnum >=0
					let errLine.lnum = valueDict.lnum
				endif
				if has_key(valueDict, 'col') && valueDict.col >=0
					let errLine.col = valueDict.col
				endif
				let errLine.text = valueDict.msg
				if has_key(valueDict, 'fPath')
					let errLine.filename = valueDict.fPath
				endif
				call add(prettyErrorList, errLine)
			endif
		endif
	endfor
	call setqflist(prettyErrorList)
	if len(prettyErrorList) > 0
		copen
	else
		cclose
	endif
	"return len(prettyErrorList)

endfunction

function! apexTooling#execute(action, projectPath, projectName, params)
	let propertiesFolder = apexOs#removeTrailingPathSeparator(g:apex_properties_folder)
	let projectPath = apexOs#removeTrailingPathSeparator(a:projectPath)
	let projectName = a:projectName

	" --action refresh --config "/Volumes/TRUECRYPT1/SForce (vim-force.com).properties" 
	"  --tooling.resourcePath "/Users/andrey/eclipse.workspace/Sforce - SFDC Experiments/SForce (vim-force.com)/src" 
	"  --tooling.cacheFolderPath "/Users/andrey/eclipse.workspace/Sforce - SFDC Experiments/SForce (vim-force.com)/.vim-force.com"'
	let toolingCommand = s:getToolingCmd() . ' --action ' . a:action
	let toolingCommand = toolingCommand . ' --config ' . shellescape(apex#getPropertiesFilePath(projectName))
	"let toolingCommand = toolingCommand . ' --tooling.resourcePath ' . shellescape(a:resourcePath)
	let toolingCommand = toolingCommand . ' --tooling.cacheFolderPath ' . shellescape(apex#getCacheFolderPath(projectPath))
	let responseFilePath = apexOs#joinPath(apex#getCacheFolderPath(projectPath), 'response_' . a:action . '.txt')
	let toolingCommand = toolingCommand . ' --responseFilePath ' . shellescape(responseFilePath)
	" check if extra parameters have been provided
	for key in keys(a:params)
		let toolingCommand = toolingCommand . ' --'.key . ' ' .shellescape(a:params[key])
	endfor



	"echo toolingCommand
	call apexOs#exe(toolingCommand, 'M') "disable --more--	
	return responseFilePath
endfunction
