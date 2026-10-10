param(
    [string]$VivadoBin = 'C:/Xilinx/2025.1/Vivado/bin',
    [string[]]$Tests = @('tb_imem_8kb','tb_soc','tb_peripherals','tb_axi','tb_bridge','tb_adapter','tb_soc_axi','tb_pwm','tb_soc_pwm')
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$build = Join-Path $repo 'build/verification'
New-Item -ItemType Directory -Force -Path $build | Out-Null
$rtl = @('rtl/interconnect/axi_lite_pkg.sv',
    'rtl/interconnect/obi_to_axi_lite.sv','rtl/interconnect/axi_lite_interconnect.sv',
    'rtl/interconnect/axi_lite_to_local.sv','rtl/memory/imem_8kb.sv',
    'rtl/memory/dmem_8kb.sv','rtl/peripherals/gpio.sv','rtl/peripherals/timer.sv','rtl/peripherals/pwm.sv','rtl/peripherals/pwm_regs.sv','rtl/soc_top.sv')
$sources = @(Get-Content (Join-Path $repo 'scripts/core_sources.flist')) + $rtl
$lines = @($sources | ForEach-Object { 'sv xil_defaultlib "' + (Join-Path $repo $_).Replace('\','/') + '"' })
$lines += @(Get-ChildItem (Join-Path $repo 'tb') -Filter *.sv | Sort-Object Name |
    ForEach-Object { 'sv xil_defaultlib "' + $_.FullName.Replace('\','/') + '"' })
[IO.File]::WriteAllLines((Join-Path $build 'compile.prj'), $lines)
Copy-Item (Join-Path $repo 'sw/tests/basic/program.hex') (Join-Path $build 'program.hex') -Force
if (Test-Path (Join-Path $repo 'sw/tests/axi/axi_program.hex')) {
    Copy-Item (Join-Path $repo 'sw/tests/axi/axi_program.hex') (Join-Path $build 'axi_program.hex') -Force
}
Copy-Item (Join-Path $repo 'sw/tests/pwm/pwm_program.hex') (Join-Path $build 'pwm_program.hex') -Force
Copy-Item (Join-Path $repo 'sw/tests/pwm/pwm_24k_program.hex') (Join-Path $build 'pwm_24k_program.hex') -Force
Push-Location $build
try {
    & (Join-Path $VivadoBin 'xvlog.bat') --sv -i "$repo/third_party/cv32e40p/rtl/include" -prj compile.prj *> compile.log
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed: build/verification/compile.log' }
    $summary = @()
    foreach ($test in $Tests) {
        & (Join-Path $VivadoBin 'xelab.bat') --debug typical --relax --mt 2 "xil_defaultlib.$test" -s $test *> "$test.elab.log"
        if ($LASTEXITCODE -ne 0) { throw "Elaboration failed: $test.elab.log" }
        if ($test -in @('tb_soc_pwm','tb_soc_pwm_24k')) {
            $waveName = $test.Substring(3)
            $waveScript = (Join-Path $repo "scripts/${waveName}_wave.tcl").Replace('\','/')
            if ($test -eq 'tb_soc_pwm_24k') { $waveName = 'soc_pwm_48m_24k' }
            & (Join-Path $VivadoBin 'xsim.bat') $test -wdb "$waveName.wdb" -tclbatch $waveScript *> "$test.run.log"
        } else {
            & (Join-Path $VivadoBin 'xsim.bat') $test -runall *> "$test.run.log"
        }
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $test.run.log" }
        $log = Get-Content "$test.run.log" -Raw
        if ($log -match 'Fatal:|FATAL:|Error:|ERROR:' -or $log -notmatch 'PASS') {
            throw "Test did not pass: $test.run.log"
        }
        $pass = @(Get-Content "$test.run.log" | Select-String 'PASS' | ForEach-Object { $_.Line })
        $summary += $pass
        $pass | Write-Output
    }
    $summary | Set-Content summary.txt
} finally { Pop-Location }
