# claude-audio-transcribe

A Claude Code skill for transcribing audio files to text using Amazon Transcribe. Supports Arabic and English with automatic language detection.

## Installation

Clone this repo into your Claude Code skills directory:

```bash
git clone https://github.com/opensourcehustle/claude-audio-transcribe.git ~/.claude/skills/audio-transcribe
```

## Usage

In Claude Code, run:

```
/audio-transcribe path/to/audio-file.mp3
```

Claude will upload the file to S3, run Amazon Transcribe, and return the extracted text.

### Supported Formats

mp3, mp4, wav, flac, ogg, webm, m4a, amr

### Supported Languages

- English (`en-US`)
- Arabic (`ar-SA`)

Language is detected automatically — no need to specify it.

## Prerequisites

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- Python 3 (used to parse JSON results)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

## AWS Setup

### 1. Configure credentials

```bash
aws configure
```

Enter your Access Key, Secret Key, region `us-east-1`, and output format `json`.

### 2. IAM permissions

Your IAM user/role needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "transcribe:StartTranscriptionJob",
        "transcribe:GetTranscriptionJob",
        "transcribe:DeleteTranscriptionJob"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:ListAllMyBuckets"
      ],
      "Resource": [
        "arn:aws:s3:::claude-audio-transcribe-*",
        "arn:aws:s3:::claude-audio-transcribe-*/*"
      ]
    }
  ]
}
```

### 3. S3 bucket (optional)

The script auto-creates a bucket on first use. To use a specific bucket:

```bash
export TRANSCRIBE_S3_BUCKET=my-bucket-name
```

### 4. Verify setup

```bash
aws sts get-caller-identity
aws transcribe list-transcription-jobs --region us-east-1 --max-results 1
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TRANSCRIBE_S3_BUCKET` | Auto-created `claude-audio-transcribe-*` | S3 bucket for temporary audio storage |
| `TRANSCRIBE_REGION` | `us-east-1` | AWS region for Transcribe and S3 |

## How It Works

1. Uploads the audio file to an S3 bucket
2. Starts an Amazon Transcribe job with automatic language detection
3. Polls until the job completes
4. Extracts the transcript text from the result
5. Cleans up all temporary resources (S3 objects + transcription job)

## Troubleshooting

- **"AccessDenied"** — Check IAM permissions above
- **"NoSuchBucket"** — Set `TRANSCRIBE_S3_BUCKET` or let the script auto-create one
- **"Could not connect"** — Run `aws configure` and verify credentials
- **Transcription fails** — Ensure the audio file is not corrupted and is in a supported format

## License

MIT
