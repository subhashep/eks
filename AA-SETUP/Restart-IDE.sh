#!/bin/bash
set -e

# -------- PARAMETERS --------
INSTANCE_ID="i-0208c4627861b6802"    # <-- Replace with your EC2 instance ID
DIST_ID="EOLHOY8Q1246A"             # <-- Replace with your CloudFront Distribution ID
# ----------------------------

echo "🔍 Checking EC2 instance state..."
STATE=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].State.Name" \
  --output text)

if [[ "$STATE" == "stopped" ]]; then
  echo "🚀 Starting EC2 instance $INSTANCE_ID..."
  aws ec2 start-instances --instance-ids "$INSTANCE_ID" >/dev/null
else
  echo "✅ Instance is already in '$STATE' state"
fi

echo "⏳ Waiting 90 seconds for EC2 boot and DNS propagation..."
sleep 90

NEW_DNS=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicDnsName" \
  --output text)

if [[ -z "$NEW_DNS" ]]; then
  echo "❌ Failed to retrieve public DNS."
  exit 1
fi

echo "🌐 New EC2 Public DNS: $NEW_DNS"

echo "🔍 Retrieving CloudFront distribution config..."
DIST_JSON=$(aws cloudfront get-distribution-config --id "$DIST_ID")
ETAG=$(echo "$DIST_JSON" | jq -r '.ETag')
CONFIG=$(echo "$DIST_JSON" | jq '.DistributionConfig')

ORIGIN_COUNT=$(echo "$CONFIG" | jq '.Origins.Items | length')

if [[ "$ORIGIN_COUNT" -eq 0 ]]; then
  echo "❌ No origin found in distribution. Cannot proceed."
  exit 1
fi

ORIGIN_ID=$(echo "$CONFIG" | jq -r '.Origins.Items[0].Id')
echo "🆔 Found OriginId: $ORIGIN_ID"

echo "🛠️ Updating origin domain to $NEW_DNS..."

UPDATED_CONFIG=$(echo "$CONFIG" | jq --arg newdns "$NEW_DNS" '
  .Origins.Items[0].DomainName = $newdns
')

aws cloudfront update-distribution \
  --id "$DIST_ID" \
  --if-match "$ETAG" \
  --distribution-config "$UPDATED_CONFIG"

echo "✅ CloudFront origin updated successfully."
echo "🕒 Please wait 3–5 minutes for the distribution to propagate."
