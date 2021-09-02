
#utility variables
$color_info = 'green'
$color_warning = 'yellow'
$color_error = 'red'
$color_important = 'magenta'
function wh($value = "", $color = $color_info, $newLine = 1) {
    if ([string]::IsNullOrEmpty($value)) {
        Write-Host
        return
    }

    #add invocation function info
    $callStacks = @(Get-PSCallStack)
    $spaces = ""
    for ($i = 0; $i -lt $callStacks.Length; $i++) {
        $spaces = $spaces + " "
    }

    if ($color -eq $color_warning) {
        $value = " $spaces[!] " + $value
    }
    if ($color -eq $color_error) {
        $value = " $spaces[x] " + $value
    }
    if ($color -eq $color_info) {
        $value = "---> " + $value
    }
    if ($newLine -eq 1) {
        Write-Host $value -ForegroundColor $color
    }
    else {
        Write-Host $value -ForegroundColor $color -NoNewline
    }
}
