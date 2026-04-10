$baseDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceRoot = Join-Path $baseDir "frame_groups"
$outputRoot = Join-Path $baseDir "gifs"
$framerate  = 12

# Leave empty "" to keep PNGs as-is
# Example: "crop=360:120:0:41"
$extraFilter = "crop=280:120:40:41"

if (!(Test-Path $sourceRoot)) {
    Write-Error "Source folder not found: $sourceRoot"
    exit 1
}

if (!(Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error "ffmpeg is not available in PATH."
    exit 1
}

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

$folders = Get-ChildItem -Path $sourceRoot -Directory | Sort-Object Name

foreach ($folder in $folders) {
    $pngFiles = Get-ChildItem -Path $folder.FullName -Filter "*.png" | Sort-Object Name

    if ($pngFiles.Count -eq 0) {
        Write-Warning "Skipping empty folder: $($folder.Name)"
        continue
    }

    $firstFile = $pngFiles[0].Name
    if ($firstFile -notmatch '^frame_(\d{6})\.png$') {
        Write-Warning "Skipping folder with unexpected filename format: $($folder.Name)"
        continue
    }

    $startNumber = [int]$matches[1]
    $frameCount  = $pngFiles.Count

    $palettePath = Join-Path $folder.FullName "palette.png"
    $outputGif   = Join-Path $outputRoot ($folder.Name + ".gif")

    if ([string]::IsNullOrWhiteSpace($extraFilter)) {
        $paletteFilter = "palettegen"
        $gifFilter     = "paletteuse"
    } else {
        $paletteFilter = "$extraFilter,palettegen"
        $gifFilter     = "$extraFilter [x]; [x][1:v] paletteuse"
    }

    Write-Host "Creating GIF for $($folder.Name) ($frameCount frames)..."

    Push-Location $folder.FullName
    try {
        ffmpeg -y `
            -framerate $framerate `
            -start_number $startNumber `
            -i "frame_%06d.png" `
            -frames:v $frameCount `
            -vf $paletteFilter `
            $palettePath

        ffmpeg -y `
            -framerate $framerate `
            -start_number $startNumber `
            -i "frame_%06d.png" `
            -i $palettePath `
            -frames:v $frameCount `
            -lavfi $gifFilter `
            $outputGif
    }
    finally {
        if (Test-Path $palettePath) {
            Remove-Item $palettePath -Force
        }
        Pop-Location
    }
}

Write-Host ""
Write-Host "Done. GIFs created in: $outputRoot"