#!/usr/bin/env python3
import base64
import json
import os

import requests
from google.cloud import firestore

PREFIX = "https://console.cloud.google.com/security/command-center/findings"

# These labels correspond to the columns that the Jira issues will move to when a
# finding notification is triggered. If the finding is active and the corresponding
# existing issue is in the `STATUS_DONE` column, this script will move it back to
# `STATUS_OPEN`. Likewise, if the finding is inactive and the existing issue
# corresponding to it is in the `STATUS_OPEN` column, then this script will move it to
# the `STATUS_DONE` column. If the existing issue is in any other column, this script
# will do nothing.
STATUS_OPEN = os.environ["STATUS_OPEN"]
STATUS_DONE = os.environ["STATUS_DONE"]

def get_finding_detail_page_link(finding_name):
    """Constructs a direct link to the finding detail page."""
    org_id = finding_name.split("/")[1]
    return f"{PREFIX}?organizationId={org_id}&resourceId={finding_name}"


def finding_jira_doc_ref(finding):
    name = finding["name"].replace("/", "-")
    db = firestore.Client()
    return db.collection("scc-findings").document(name)


def put_finding_jira_doc(finding, jira_key):
    """Save the finding name and Jira issue key to Firestore."""
    ref = finding_jira_doc_ref(finding)
    ref.set({"state": finding["state"], "jira_key": jira_key})


def get_finding_jira_doc(finding):
    """Retrieve the Jira issue key from Firestore."""
    ref = finding_jira_doc_ref(finding)
    return ref.get().to_dict()


def get_jira_issue(jira_key):
    """Retrieve the Jira issue for jira_key or None if it doesn't exist."""
    domain = os.environ["DOMAIN"]
    user_id = os.environ["USER_ID"]
    api_token = os.environ.get('ATLASSIAN_API_TOKEN', 'Specified environment variable is not set.')

    resp = requests.get(
        f"https://{domain}.atlassian.net/rest/api/3/issue/{jira_key}",
        auth=(user_id, api_token),
    )

    if resp.status_code == 404:
        return None

    resp.raise_for_status()
    return resp.json()


def get_jira_transition_id(jira_key, status):
    """Retrieve the Jira transition ID for the given status."""
    domain = os.environ["DOMAIN"]
    user_id = os.environ["USER_ID"]
    api_token = os.environ.get('ATLASSIAN_API_TOKEN', 'Specified environment variable is not set.')

    resp = requests.get(
        f"https://{domain}.atlassian.net/rest/api/3/issue/{jira_key}/transitions",
        auth=(user_id, api_token),
    )
    resp.raise_for_status()
    transitions = resp.json()["transitions"]
    return [t for t in transitions if t["name"] == status][0]["id"]


def transition_jira_issue(jira_key, status):
    """Move a Jira issue to the given status."""
    domain = os.environ["DOMAIN"]
    user_id = os.environ["USER_ID"]
    api_token = os.environ.get('ATLASSIAN_API_TOKEN', 'Specified environment variable is not set.')

    resp = requests.post(
        f"https://{domain}.atlassian.net/rest/api/3/issue/{jira_key}/transitions",
        json={"transition": {"id": get_jira_transition_id(jira_key, status)}},
        auth=(user_id, api_token),
    )
    resp.raise_for_status()
    return resp


def create_open_jira_issue(finding):
    """Create a new Jira issue in the default status."""
    domain = os.environ["DOMAIN"]
    user_id = os.environ["USER_ID"]
    api_token = os.environ.get('ATLASSIAN_API_TOKEN', 'Specified environment variable is not set.')
    project_key = os.environ["JIRA_PROJECT_KEY"]

    content = [
        {
            "type": "paragraph",
            "content": [
                {
                    "type": "text",
                    "text": "Link to finding in Security Command Center",
                    "marks": [
                        {
                            "type": "link",
                            "attrs": {
                                "href": get_finding_detail_page_link(finding["name"])
                            },
                        }
                    ],
                }
            ],
        },
    ]

    resp = requests.post(
        f"https://{domain}.atlassian.net/rest/api/3/issue/",
        json={
            "update": {},
            "fields": {
                "summary": f"{finding['severity']} severity {finding['category']} finding",
                "project": {"key": project_key},
                "issuetype": {"name": os.environ["ISSUE_TYPE"]},
                "description": {
                    "type": "doc",
                    "version": 1,
                    "content": content,
                },
            },
        },
        auth=(user_id, api_token),
    )

    resp.raise_for_status()
    return resp.json()


def process_resolved_finding(finding):
    """Handle a finding that has been resolved."""
    doc = get_finding_jira_doc(finding)

    if doc is not None:
        # Jira issue exists - close it.
        jira_key = doc["jira_key"]
        issue = get_jira_issue(jira_key)
        if issue is not None and issue["fields"]["status"]["name"] == STATUS_OPEN:
            transition_jira_issue(jira_key, STATUS_DONE)
            print(f"Closed Jira issue: {jira_key} - {finding['name']}")


def process_active_finding(finding):
    """Handle a finding that is active."""
    doc = get_finding_jira_doc(finding)

    if doc is not None:
        # Jira issue already exists - update existing one.
        jira_key = doc["jira_key"]
        issue = get_jira_issue(jira_key)
        if issue is not None:
            if issue["fields"]["status"]["name"] == STATUS_DONE:
                # Issue was closed - reopen it.
                transition_jira_issue(jira_key, STATUS_OPEN)
                print(f"Reopened Jira issue: {jira_key} - {finding['name']}")
            return
        # Existing issue was deleted - need to recreate it.

    # Jira issue doesn't exist - create a new one.
    jira_resp = create_open_jira_issue(finding)
    jira_key = jira_resp["key"]
    put_finding_jira_doc(finding, jira_key)
    print(f"Created new Jira issue: {jira_key} - {finding['name']}")


def process_finding(finding):
    """Handle a finding notification."""
    if finding["state"] == "ACTIVE":
        process_active_finding(finding)
    else:
        process_resolved_finding(finding)


def decode_finding(data):
    """Decode the finding from the data payload."""
    pubsub_message = base64.b64decode(data).decode("utf-8")
    return json.loads(pubsub_message)["finding"]


def process_notification(event, context):
    """Process the finding notification."""
    try:
        process_finding(decode_finding(event["data"]))
    except requests.exceptions.HTTPError as err:
        print(err.response.text)
        raise err