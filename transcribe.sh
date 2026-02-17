#!/usr/bin/env bash
set -euo pipefail

# Audio Transcribe using Amazon Transcribe
# Usage: bash transcribe.sh <path-to-audio-file>

AUDIO_FILE="$1"
REGION="${TRANSCRIBE_REGION:-us-east-1}"
BUCKET="${TRANSCRIBE_S3_BUCKET:-}"

# --- Validate input ---
if [[ -z "$AUDIO_FILE" ]]; then
  echo "Error: No audio file path provided." >&2
  exit 1
fi

if [[ ! -f "$AUDIO_FILE" ]]; then
  echo "Error: File not found: $AUDIO_FILE" >&2
  exit 1
fi

# Get file extension (lowercase)
EXT="${AUDIO_FILE##*.}"
EXT="$(echo "$EXT" | tr '[:upper:]' '[:lower:]')"

SUPPORTED_FORMATS="mp3 mp4 wav flac ogg webm m4a amr"
if ! echo "$SUPPORTED_FORMATS" | grep -qw "$EXT"; then
  echo "Error: Unsupported format '.$EXT'. Supported: $SUPPORTED_FORMATS" >&2
  exit 1
fi

# Map extensions to Amazon Transcribe media formats
case "$EXT" in
  mp3) MEDIA_FORMAT="mp3" ;;
  mp4|m4a) MEDIA_FORMAT="mp4" ;;
  wav) MEDIA_FORMAT="wav" ;;
  flac) MEDIA_FORMAT="flac" ;;
  ogg) MEDIA_FORMAT="ogg" ;;
  webm) MEDIA_FORMAT="webm" ;;
  amr) MEDIA_FORMAT="amr" ;;
  *) MEDIA_FORMAT="$EXT" ;;
esac

# --- Check AWS CLI ---
if ! command -v aws &>/dev/null; then
  echo "Error: AWS CLI is not installed. See setup.md for instructions." >&2
  exit 1
fi

# --- Determine S3 bucket ---
if [[ -z "$BUCKET" ]]; then
  # Try to find an existing bucket with our prefix
  BUCKET=$(aws s3 ls --region "$REGION" 2>/dev/null | awk '{print $3}' | grep "^claude-audio-transcribe" | head -1 || true)
  if [[ -z "$BUCKET" ]]; then
    BUCKET="claude-audio-transcribe-$(date +%s)"
    echo "Creating S3 bucket: $BUCKET ..." >&2
    if [[ "$REGION" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" 2>/dev/null
    else
      aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null
    fi
  fi
fi

# --- Upload to S3 ---
FILENAME="$(basename "$AUDIO_FILE")"
S3_KEY="transcribe-input/${FILENAME}-$(date +%s).${EXT}"
S3_URI="s3://${BUCKET}/${S3_KEY}"

echo "Uploading audio to S3..." >&2
aws s3 cp "$AUDIO_FILE" "$S3_URI" --region "$REGION" --quiet

# --- Start transcription job ---
JOB_NAME="claude-transcribe-$(date +%s%N | head -c 16)"

echo "Starting transcription job: $JOB_NAME ..." >&2
aws transcribe start-transcription-job \
  --region "$REGION" \
  --transcription-job-name "$JOB_NAME" \
  --media "MediaFileUri=$S3_URI" \
  --media-format "$MEDIA_FORMAT" \
  --identify-language \
  --language-options '["en-US","ar-SA"]' \
  --output-key "transcribe-output/${JOB_NAME}.json" \
  --output-bucket-name "$BUCKET" \
  >/dev/null

# --- Poll for completion ---
echo "Waiting for transcription to complete..." >&2
while true; do
  STATUS=$(aws transcribe get-transcription-job \
    --region "$REGION" \
    --transcription-job-name "$JOB_NAME" \
    --query 'TranscriptionJob.TranscriptionJobStatus' \
    --output text 2>/dev/null)

  case "$STATUS" in
    COMPLETED)
      echo "Transcription completed." >&2
      break
      ;;
    FAILED)
      REASON=$(aws transcribe get-transcription-job \
        --region "$REGION" \
        --transcription-job-name "$JOB_NAME" \
        --query 'TranscriptionJob.FailureReason' \
        --output text 2>/dev/null)
      echo "Error: Transcription failed — $REASON" >&2
      # Cleanup
      aws s3 rm "$S3_URI" --region "$REGION" --quiet 2>/dev/null || true
      aws transcribe delete-transcription-job --region "$REGION" --transcription-job-name "$JOB_NAME" 2>/dev/null || true
      exit 1
      ;;
    *)
      sleep 5
      ;;
  esac
done

# --- Extract transcript ---
RESULT_S3="s3://${BUCKET}/transcribe-output/${JOB_NAME}.json"

TRANSCRIPT=$(aws s3 cp "$RESULT_S3" - --region "$REGION" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['results']['transcripts'][0]['transcript'])
" 2>/dev/null)

if [[ -z "$TRANSCRIPT" ]]; then
  echo "Error: Failed to extract transcript from results." >&2
else
  echo "$TRANSCRIPT"
fi

# --- Detect language ---
LANG_CODE=$(aws transcribe get-transcription-job \
  --region "$REGION" \
  --transcription-job-name "$JOB_NAME" \
  --query 'TranscriptionJob.LanguageCode' \
  --output text 2>/dev/null || true)
if [[ -n "$LANG_CODE" ]]; then
  echo "" >&2
  echo "[Detected language: $LANG_CODE]" >&2
fi

# --- Cleanup ---
echo "Cleaning up AWS resources..." >&2
aws s3 rm "$S3_URI" --region "$REGION" --quiet 2>/dev/null || true
aws s3 rm "$RESULT_S3" --region "$REGION" --quiet 2>/dev/null || true
aws transcribe delete-transcription-job --region "$REGION" --transcription-job-name "$JOB_NAME" 2>/dev/null || true
echo "Done." >&2
