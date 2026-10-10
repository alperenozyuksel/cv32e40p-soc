param()
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$build=Join-Path $repo 'build/pwm'
$rows=Import-Csv (Join-Path $build 'pwm_samples.csv')
Add-Type -AssemblyName System.Drawing
$bmp=[Drawing.Bitmap]::new(1280,760)
$g=[Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([Drawing.ColorTranslator]::FromHtml('#101820'))
$font=[Drawing.Font]::new('Consolas',14)
$small=[Drawing.Font]::new('Consolas',11)
$title=[Drawing.Font]::new('Segoe UI',22,[Drawing.FontStyle]::Bold)
$white=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#e5eff5'))
$muted=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#adc2d0'))
$green=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#65edab'),2)
$grid=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#2e4555'),1)
$g.DrawString('PWM | XSim waveform capture',$title,$white,30,20)
$g.DrawString('100 MHz clock / 100 cycles per period / 1 MHz PWM',$font,$muted,30,65)
$metrics=@()
foreach($id in 1..4) {
    $selected=@($rows | Where-Object {$_.case_id -eq "$id" -and $_.enable -eq '1' -and $_.reset_n -eq '1'})
    $start=0
    while($selected[$start].period_start -ne '1') {$start++}
    $samples=@($selected[$start..($start+299)])
    $t0=[double]$samples[0].time_ns
    $periodNs=[double]$samples[100].time_ns-$t0
    $highCount=@($samples[0..99] | Where-Object {$_.pwm -eq '1'}).Count
    $pct=$highCount
    $metrics += [pscustomobject]@{Duty_percent=$pct;Period_ns=$periodNs;High_ns=$highCount*10;Frequency_Hz=1e9/$periodNs}
    $y=150+($id-1)*145
    $g.DrawString("PWM $pct%",$font,$white,30,$y)
    $g.DrawString("HIGH: $($highCount*10) ns",$small,$muted,30,($y+28))
    $g.DrawString('1',$small,$muted,190,($y-10))
    $g.DrawString('0',$small,$muted,190,($y+36))
    for($k=0;$k -le 6;$k++) {
        $x=230+$k*165
        $g.DrawLine($grid,$x,$y-12,$x,$y+64)
        $g.DrawString(('{0:0.0}' -f ($k*0.5)),$small,$muted,($x-12),($y+68))
    }
    $prevY=$y+48
    for($n=0;$n -lt 300;$n++) {
        $x1=[single](230+$n*3.3)
        $x2=[single](230+($n+1)*3.3)
        $py=[single]($y+48-48*[int]$samples[$n].pwm)
        if($n -gt 0) {$g.DrawLine($green,$x1,[single]$prevY,$x1,$py)}
        $g.DrawLine($green,$x1,$py,$x2,$py)
        $prevY=$py
    }
}
$g.DrawString('Relative time (us) | each row starts at its recorded period boundary',$small,$muted,230,735)
$bmp.Save((Join-Path $build 'pwm_waveform.png'),[Drawing.Imaging.ImageFormat]::Png)
$metrics | Export-Csv (Join-Path $build 'pwm_measurements.csv') -NoTypeInformation
$g.Dispose();$bmp.Dispose();$font.Dispose();$small.Dispose();$title.Dispose()
$white.Dispose();$muted.Dispose();$green.Dispose();$grid.Dispose()
$metrics | Format-Table
