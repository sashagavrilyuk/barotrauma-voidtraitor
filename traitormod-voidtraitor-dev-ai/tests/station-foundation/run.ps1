param([string]$GamePath = 'D:/SteamLibrary/steamapps/common/Barotrauma')
$ErrorActionPreference = 'Stop'
[void][Reflection.Assembly]::LoadFrom((Join-Path $GamePath 'MoonSharp.Interpreter.dll'))
$stationMod = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
foreach ($stationTest in @('foundation-mode.lua', 'foundation-shop.lua', 'foundation-voting.lua', 'idconsole.lua', 'idconsole-selection.lua')) {
    $stationScript = [MoonSharp.Interpreter.Script]::new()
    $stationScript.Globals['modpath'] = $stationMod.Replace('\', '/')
    try {
        $stationResult = $stationScript.DoString([IO.File]::ReadAllText((Join-Path $PSScriptRoot $stationTest)))
        Write-Output $stationResult.String
    } catch {
        throw $_.Exception.InnerException.DecoratedMessage
    }
}
foreach ($stationRoot in @((Join-Path $stationMod 'Lua'), (Join-Path (Split-Path $stationMod) 'Void traitor pack/Lua'))) {
    foreach ($stationFile in (Get-ChildItem -LiteralPath $stationRoot -Recurse -File -Filter '*.lua' | Where-Object Name -ne 'config.lua')) {
        $stationScript = [MoonSharp.Interpreter.Script]::new()
        [void]$stationScript.LoadString([IO.File]::ReadAllText($stationFile.FullName))
    }
}
Write-Output 'PASS Lua syntax'
