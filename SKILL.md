---
name: audio-transcribe
description: Transcribe audio files (Arabic/English) to text using AWS Transcribe. Use when the user wants to transcribe, convert speech to text, or extract text from audio/voice files.
argument-hint: <path-to-audio-file>
---

# Audio Transcribe Skill

Transcribe audio files to text using Amazon Transcribe. Supports Arabic and English.

## Instructions

When invoked with `$ARGUMENTS`:

1. **Validate the input file**:
   - The argument `$ARGUMENTS` should be a path to an audio file
   - Verify the file exists using `ls -la "$ARGUMENTS"`
   - Supported formats: mp3, mp4, wav, flac, ogg, webm, m4a, amr
   - If the file doesn't exist or format is unsupported, tell the user and stop

2. **Run the transcription script**:
   - Execute the helper script located at `~/.claude/skills/audio-transcribe/transcribe.sh`
   - Run: `bash ~/.claude/skills/audio-transcribe/transcribe.sh "$ARGUMENTS"`
   - The script handles: S3 upload, transcription job, polling, result extraction, and cleanup

3. **Handle the result**:
   - If the script succeeds, it outputs the transcript text to stdout
   - Present the transcript to the user in a clean format
   - If the script fails, show the error and suggest the user check `~/.claude/skills/audio-transcribe/setup.md` for AWS setup instructions

4. **Optionally save**: Ask the user if they want to save the transcript to a `.txt` file next to the original audio file

## First-time setup

If the script fails with AWS credential or bucket errors, tell the user to read the AWS Setup section in the README:
`~/.claude/skills/audio-transcribe/README.md`

## Configuration

The script reads these environment variables (with defaults):
- `TRANSCRIBE_S3_BUCKET` — S3 bucket name (default: auto-created `claude-audio-transcribe-{timestamp}`)
- `TRANSCRIBE_REGION` — AWS region (default: `us-east-1`)
