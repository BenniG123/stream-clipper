param (
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile
)
function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = "Select json-formatted config file."
    $openFileDialog.Filter = "JSON (*.JSON)|*.JSON|All files (*.*)|*.*"
    $openFileDialog.ShowDialog() | Out-Null
    return $openFileDialog.FileName
}

if (-not (Test-Path -Path $ConfigFile))
{
    Write-Output "Select config file"
    $ConfigFile = Get-FileName -initialDirectory "~"
    if (-not (Test-Path -Path $ConfigFile))
    {
        Write-Error "Couldn't find $ConfigFile"
        return
    }
}

Write-Warning "This script tested with ffmpeg version 4.1.1"
if (-not (Get-Command "ffmpeg.exe" -ErrorAction SilentlyContinue))
{
    Write-Error "Can't find ffmpeg.  Make sure the latest release is installed and added to your Path.  If you just did this, you may have to refresh your powershell window."
    return
}

Write-Output "Parsing $ConfigFile"
$json = Get-Content -Path $ConfigFile | Out-String
$config = ConvertFrom-Json $json
Write-Output $config

$clipFolder = Split-Path -Path $config.outputVideo

$clipCounter = 0

# Store list of intermediate clip files
$clipFiles = @()

# Get base name assuming this is a filename with no period (.) characters
$outputFileBaseName = $($config.outputVideo).split('\.')[-2]

# Track series scores
$team1Score = 0
$team2Score = 0

# Create ffmpeg video splitting command
$clipCommand = ""
foreach ($clip in $config.clips)
{
    Write-Output $clip
    $clipFileName = "$($outputFileBaseName)_clip$clipCounter.mp4"
    $clipFilePath = Join-Path -Path $clipFolder -ChildPath $clipFileName

    # Append clip to list
    $clipFiles += $clipFilePath

    $clipCommand += " -ss $($clip.start) -to $($clip.end) -c copy ""$clipFilePath"""
    $clipCounter += 1
}

# Export clips in one shot - massive speed up
Invoke-Expression "ffmpeg -i ""$($config.inputVideo)"" $clipCommand -y"

if ($config.showSeriesScore)
{
    # Track score for overlay
    $scoreCounter = 0

    # Store filenames for overlay
    $clipOverlayFiles = @()

    foreach ($clipFilePath in $clipFiles)
    {
        # Overlay score
        # We overlay with score - team name.  That's just to align easily.
        # I'll happily take a fix for team name - score with alignment :)
        $text = "$team1Score - $($config.team1)`r`n$team2Score - $($config.team2)"
        $textParams = "font=arial: text=`'$text`': fontsize=36: fontcolor=white: x=(w-text_w)/16: y=(h-text_h)/16"

        # Create new clip file path
        $clipBaseName = (Get-Item $clipFilePath).BaseName
        $overlayBaseName = $clipBaseName + "_overlay"
        $clipPath = Split-Path -Path $clipFilePath
        $clipOverlayFilePath = Join-Path -Path $clipPath -ChildPath "$overlayBaseName.mp4"

        # Overlay clip with text.  Running these in parrallel doesn't speed things up.
        # ffmpeg does a good job of using all of the available CPU.
        Invoke-Expression "ffmpeg -i ""$clipFilePath"" -vf drawtext=""$textParams"" ""$clipOverlayFilePath"" -y"

        $clipOverlayFiles += $clipOverlayFilePath

        $winner = $config.clips[$scoreCounter].winner
        if ($winner -eq $config.team1)
        {
            $team1Score += 1
        }
        elseif ($winner -eq $config.team2)
        {
            $team2Score += 1
        }
        else
        {
            Write-Warning "Winner $winner wasn't a recognized team."
        }

        $scoreCounter += 1
    }

    # Overwrite clip files
    foreach ($clipFile in $clipFiles)
    {
        Remove-Item $clipFile -Force -Confirm:$false
    }
    $clipFiles = $clipOverlayFiles
}

# Pad games in the final video so video length doesn't give away who won the series
if ($config.padSeriesLength)
{
    if ($clipCounter -lt $config.padSeriesLength)
    {
        $clipPadCount = $config.padSeriesLength - $clipCounter
        Write-Output "Clip count of $clipCounter is < padSeriesLength of $($config.padSeriesLength)"

        $clipPadIndex = 0
        $firstPadClip = $clipFiles[$clipPadIndex]

        # Create new clip file path
        $clipBaseName = (Get-Item $firstPadClip).BaseName
        $overlayBaseName = $clipBaseName + "_pad_overlay"
        $clipPath = Split-Path -Path $clipFilePath
        $clipOverlayFilePath = Join-Path -Path $clipPath -ChildPath "$overlayBaseName.mp4"

        # Draw text explaining what's happening on the first padded clip
        $text = "Padding the video to avoid giving away the winner"
        $textParams = "enable='between(t,0,6)': font=arial: text=`'$text`': fontsize=36: fontcolor=white: x=(w-text_w)/2:y=(h-text_h)/2"
        Invoke-Expression "ffmpeg -i ""$firstPadClip"" -vf drawtext=""$textParams"" ""$clipOverlayFilePath"" -y"

        $clipFiles += $clipOverlayFilePath
        $clipPadIndex += 1

        # Pad clip concat list with unmodified videos
        while ($clipPadIndex -gt $clipPadCount)
        {
            $padClipFile = $clipFiles[$clipPadIndex]
            $clipFiles += $padClipFile
            Write-Output "Padded $padClipFile"
            $clipPadIndex += 1
        }

    }
    else
    {
        Write-Output "Clip count is >= padSeriesLength.  No games to pad."
    }
}

# Build a list of intermediate files to build the final video
$concatList = ""
foreach ($clipFile in $clipFiles)
{
    $concatList += "file '$clipFile'`n"
}
$concatListFilePath = Join-Path -Path $clipFolder -ChildPath "concatListFile.txt"
$concatList | Out-File $concatListFilePath -Force -Confirm:$false -Encoding ASCII

# Perform video concatenation
Invoke-Expression "ffmpeg -f concat -safe 0 -i ""$concatListFilePath"" -c copy ""$($config.outputVideo)"" -y"

# Remove temporary files
if (-not $config.saveIndividualClips)
{
    foreach ($clipFile in $clipFiles)
    {
        Remove-Item $clipFile -Force -Confirm:$false
    }
}
Remove-Item $concatListFilePath

Write-Host "Finished creating $($config.outputVideo)"