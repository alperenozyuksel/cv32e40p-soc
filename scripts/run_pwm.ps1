param([string]$VivadoBin = 'C:/Xilinx/2025.1/Vivado/bin')
$ErrorActionPreference = 'Stop'
$repo = (Split-Path $PSScriptRoot -Parent).Replace('\','/')
$build = Join-Path $repo 'build/pwm'
New-Item -ItemType Directory -Force -Path $build | Out-Null
Push-Location $build
try {
    & (Join-Path $VivadoBin 'xvlog.bat') --sv "$repo/rtl/peripherals/pwm.sv" "$repo/tb/tb_pwm.sv" *> compile.log
    if ($LASTEXITCODE -ne 0) { throw 'PWM compile failed; see build/pwm/compile.log' }
    & (Join-Path $VivadoBin 'xelab.bat') --debug all work.tb_pwm -s pwm *> elaborate.log
    if ($LASTEXITCODE -ne 0) { throw 'PWM elaboration failed; see build/pwm/elaborate.log' }
    & (Join-Path $VivadoBin 'xsim.bat') pwm -wdb pwm.wdb -tclbatch "$repo/scripts/pwm_wave.tcl" *> simulate.log
    $log = Get-Content simulate.log -Raw
    if ($LASTEXITCODE -ne 0 -or $log -match 'Fatal:|FATAL:|ERROR:|Error:' -or $log -notmatch 'PASS tb_pwm') {
        throw 'PWM test failed; see build/pwm/simulate.log'
    }
    Get-Content simulate.log | Select-String 'PASS'
} finally { Pop-Location }
