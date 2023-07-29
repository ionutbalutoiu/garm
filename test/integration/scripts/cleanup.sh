#!/usr/bin/env bash

ORG="test-garm-org"
REPO="test-garm-repo"

echo "Cleaning up leftover runners from org: ${ORG}"
for runner_id in `gh api /orgs/${ORG}/actions/runners | jq -r ".runners[] | .id"`; do
    gh api --method DELETE /orgs/${ORG}/actions/runners/${runner_id}
done

echo "Cleaning up leftover runners from repo: ${ORG}/${REPO}"
for runner_id in `gh api /repos/${ORG}/${REPO}/actions/runners | jq -r ".runners[] | .id"`; do
    gh api --method DELETE /repos/${ORG}/${REPO}/actions/runners/${runner_id}
done
