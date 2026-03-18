#!/bin/bash

BASE="/root/recon/ywh"

DOMAINS="$BASE/domains.txt"
KNOWN="$BASE/known.txt"
LATEST="$BASE/latest.txt"
NEW="$BASE/new.txt"

NEW_FINDINGS="$BASE/new_nuclei.txt"
KNOWN_FINDINGS="$BASE/known_nuclei.txt"

SUBFINDER="/root/go/bin/subfinder"
NUCLEI="/root/.go/bin/nuclei"
NOTIFY="/root/.go/bin/notify"

mkdir -p "$BASE"
touch "$DOMAINS"
touch "$KNOWN"

if [ ! -s "$DOMAINS" ]; then
  echo "domains.txt is empty"
  exit 1
fi

> "$LATEST"

while IFS= read -r domain; do
  [ -n "$domain" ] || continue
  "$SUBFINDER" -d "$domain" -silent
done < "$DOMAINS" | sort -u > "$LATEST"

if [ ! -s "$KNOWN" ]; then
  cp "$LATEST" "$KNOWN"
  echo "First run completed. Baseline saved to known.txt"
  exit 0
fi

comm -13 "$KNOWN" "$LATEST" > "$NEW"

if [ -s "$NEW" ]; then
  {
    echo "New subdomains discovered:"
    echo
    cat "$NEW"
  } | "$NOTIFY" -provider discord -id "your channel name"

  cat "$NEW" >> "$KNOWN"
  sort -u "$KNOWN" -o "$KNOWN"

  "$NUCLEI" \
    -l "$NEW" \
    -silent \
    -severity low,medium,high,critical \
    -tags exposure,misconfig,tech,panel \
    -o "$NEW_FINDINGS"

  if [ -s "$NEW_FINDINGS" ]; then
    {
      echo "Findings on newly discovered subdomains:"
      echo
      cat "$NEW_FINDINGS"
    } | "$NOTIFY" -provider discord -id "your channel name"
  fi

  rm -f "$NEW"
fi

"$NUCLEI" \
  -l "$KNOWN" \
  -silent \
  -severity low,medium,high,critical \
  -tags exposure,misconfig,tech,panel \
  -o "$KNOWN_FINDINGS"

if [ -s "$KNOWN_FINDINGS" ]; then
  {
    echo "Findings from known subdomains scan:"
    echo
    cat "$KNOWN_FINDINGS"
  } | "$NOTIFY" -provider discord -id hacking
fi
