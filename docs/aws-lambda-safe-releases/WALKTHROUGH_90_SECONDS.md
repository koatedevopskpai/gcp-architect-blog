# 90-second walkthrough — script, not a recording

Status: ready to record. No video has been recorded or claimed.

0–15s: “I built a small AWS Lambda release lab to test automatic rollback. The primary run sent 3,601 requests and recorded 120 HTTP 500s.” Show article opening.

15–35s: Show the diagram and handler. “The faulty version raises an exception, so the Lambda Errors metric sees an invocation failure. A count alarm watches the live alias in two consecutive one-minute periods.”

35–50s: Show the actual canary image. “This screenshot is from the separately labelled capture run: healthy version 6 receives 90%, faulty version 7 receives 10%. The primary measured run used versions 1, 2 and 3.”

50–70s: Open primary deployment.json, then lambda-alias.json. “The primary record shows ALARM_ACTIVE and links the automatic rollback. The saved alias is back on healthy version 2 with weights cleared.”

70–90s: Show clean plan and dated cleanup. “Terraform reported no changes. I destroyed the lab and rechecked the inventory. This was a resumed synthetic run, not production-scale evidence. The article links every claim to the saved records.”

Record from the rendered article and public redacted evidence only. Do not show AWS account menus, credentials, local tfvars or private raw logs. Export a real screen recording before attaching video to LinkedIn; the text post can ship without video.
