param (
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile
)

function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
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
    }
}

Write-Output "Parsing $ConfigFile"
$json = Get-Content -Path $ConfigFile | Out-String
$config = ConvertFrom-Json $json
Write-Output $config

$clipFolder = Split-Path -Path $config.outputVideo

$clipCounter = 0

# Store list of clip files
$clipFiles = @()

# Get base name assuming this is all normal
$outputFileBaseName = $($config.outputVideo).split('\.')[-2]

# Track series scores
$team1Score = 0
$team2Score = 0

foreach ($clip in $config.clips)
{
    Write-Output $clip
    $clipFileName = "$($outputFileBaseName)_clip$clipCounter.mp4"
    $clipFilePath = Join-Path -Path $clipFolder -ChildPath $clipFileName

    # Append clip to list
    $clipFiles += $clipFilePath

    # Clip and render text
    if ($config.showSeriesScore)
    {
        # Overlay score
        # We overlay with score - team name.  That's just to align easily.
        # I'll happily take a fix for team name - score with alignment :)
        $text = "$team1Score - $($config.team1)`r`n$team2Score - $($config.team2)"
        $textParams = "font=arial: text='$text': fontsize=36: fontcolor=white: x=(w-text_w)/16: y=(h-text_h)/16"
        ffmpeg -i $config.inputVideo `
               -ss $clip.start `
               -to $clip.end `
               -vf drawtext=$textParams `
               -c copy $clipFilePath -y 

        if ($clip.winner -eq $config.team1)
        {
            $team1Score += 1
        }
        elseif ($clip.winner -eq $config.team2)
        {
            $team2Score += 1
        }
        else
        {
            Write-Warning "Winner $($clip.winner) wasn't a recognized team."
        }
    }
    else
    {
        # Export clip
        ffmpeg -i $config.inputVideo -ss $clip.start `
            -to $clip.end -c copy $clipFilePath -y
    }

    $clipCounter += 1
}

$files = Get-ChildItem "$clipFolder\*" -Include *.mp4
Write-Output $clipFiles

# Pad games in the final video so video length doesn't give away 
if ($config.padSeriesLength)
{
    if ($clipCounter -lt $config.padSeriesLength)
    {
        $clipPadCount = $config.padSeriesLength - $clipCounter
        Write-Output "Clip count of $clipCounter is < padSeriesLength of $($config.padSeriesLength)"

        # Pad clip concat list
        while ($clipPadCount -gt 0)
        {
            $clipPadCount -= 1
            $padClipFile = $clipFiles[$clipPadCount]
            $clipFiles += $padClipFile
            Write-Output "Padded $padClipFile"
        }

        # Maybe drawtext explaining?
    }
    else
    {
        Write-Output "Clip count is >= padSeriesLength.  No games to pad."
    }
}

$concatList = ""
foreach ($clipFile in $clipFiles)
{
    $concatList += "file '$clipFile'`n"
}

$concatListFilePath = Join-Path -Path $clipFolder -ChildPath "concatListFile.txt"
$concatList | Out-File $concatListFilePath -Force -Confirm:$false -Encoding ASCII

# Perform concatenation
ffmpeg -f concat -safe 0 -i $concatListFilePath `
       -c copy $config.outputVideo -y

# Remove temporary files
if (-not $config.saveIndividualClips)
{
    foreach ($clipFile in $clipFiles)
    {
        Remove-Item $clipFile -Force -Confirm:$false
    }
}

Remove-Item $concatListFilePath

Write-Host "Finished editing Rocket League"