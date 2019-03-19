# Stream Clipper
**Stream Clipper** is a simple tool for condensing long gameplay videos. It takes in a gameplay video and json config file, and outputs an edited youtube-ready video file.  It was originally made for clipping and editing [Rocket League best-of-X show matches](#Rocket-League-Best-of-X-example).

## Dependencies
[ffmpeg](https://www.ffmpeg.org/download.html)

## Running the tool
Specify config file:
```powershell
.\stream-clipper.ps1 <config.json>
```

Use file picker dialog to select config:
```powershell
.\stream-clipper.ps1
```

To run the script with an example config file
```powershell
.\stream-clipper.ps1 .\rocket-league-showmatch-example-config.json
```

You may need to change your execution policy to run this unsigned script:
```powershell
Set-ExecutionPolicy unrestricted
```

## Making a config file
The config file should specify, at minimum, an input video, an output video, and one or more clips in an array.
```json
{  
   "inputVideo":"Path:\\To\\Raw\\Stream.mp4",
   "outputVideo":"Path:\\To\\Edited\\Video.mp4",
   "clips":[  
      {  
         "start":"00:05:00",
         "end":"00:06:01"
      }
  ]
}
```

A clip should have "start" and "end" timestamp strings in the format of "hh:MM:ss" or "hh:MM:ss.mmm".
```json
{  
   "start":"00:01:23",
   "end":"00:07:01"
}
```

### Rocket League Best-of-X example
Overlay the series score by setting "showSeriesScore" to true.  You must specify a "winner" for each clip, which must match one of the two team names.

If "padSeriesLength" is set, the script will append earlier matches to the end of the video if the series ends early.  This is done so the video length doesn't give away the winner partway through the series.

Config file for a rocket league series:
```json
{  
   "inputVideo":"Path:\\To\\Raw\\Stream.mp4",
   "outputVideo":"Path:\\To\\Edited\\Video.mp4",
   "showSeriesScore": true,
   "saveIndividualClips": false,
   "padSeriesLength": 5,
   "team1": "teamA",
   "team2": "teamB",
   "clips":[  
      {  
         "start":"00:01:23",
         "end":"00:07:01",
         "winner":"teamA"
      },
      {  
         "start":"00:15:15",
         "end":"00:22:21",
         "winner":"teamB"
      },
      {  
         "start":"00:23:13",
         "end":"00:30:20",
         "winner":"teamA"
      },
      {  
         "start":"00:42:35",
         "end":"00:49:15",
         "winner":"teamA"
      }
   ]
}
```
