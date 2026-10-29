"""Native Windows backend for the three existing capture shell helpers.

No Bash/WSL is required. Uses the same AWS CLI operations and AppSpec semantics.
Only the three explicitly supported project commands are accepted.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]


def command(args: list[str], env: dict[str, str]) -> str:
    result = subprocess.run(args, cwd=ROOT, env=env, text=True,
                            capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {args[0:3]}\n{result.stderr}")
    return result.stdout.strip()


def aws(args: list[str], env: dict[str, str]) -> str:
    return command(["aws", *args, "--no-cli-pager"], env)


def parse_request(text: str) -> tuple[dict[str, str], str, list[str]]:
    parts = shlex.split(text)
    values = dict(os.environ)
    allowed = {"AWS_REGION", "ARTIFACT_BUCKET", "FUNCTION_NAME", "ALIAS_NAME",
               "CODEDEPLOY_APP", "CODEDEPLOY_GROUP", "RUN_ID", "DEPLOYMENT_ID", "PROJECT"}
    while parts and "=" in parts[0]:
        key, value = parts.pop(0).split("=", 1)
        if key not in allowed:
            raise ValueError(f"Unsupported environment override: {key}")
        values[key] = value
    if not parts or parts[0] not in {
        "scripts/deploy.sh", "scripts/collect-evidence.sh", "scripts/verify-teardown.sh"
    }:
        raise ValueError("Only the three existing capture helpers are supported")
    return values, parts[0], parts[1:]


def deploy(env: dict[str, str], args: list[str]) -> None:
    if not args or args[0] not in {"baseline", "healthy", "faulty"} or args[1:] not in ([], ["--wait"]):
        raise ValueError("Expected baseline|healthy|faulty [--wait]")
    release = args[0]
    fn = env.get("FUNCTION_NAME", "aws-lambda-safe-releases")
    alias = env.get("ALIAS_NAME", "live")
    region = env.get("AWS_REGION", "eu-west-2")
    bucket = env["ARTIFACT_BUCKET"]
    artifact = command([sys.executable, "scripts/build.py", release], env)
    key = f"releases/{release}.zip"
    aws(["s3", "cp", artifact, f"s3://{bucket}/{key}", "--region", region], env)
    current = aws(["lambda", "get-alias", "--function-name", fn, "--name", alias,
                   "--region", region, "--query", "FunctionVersion", "--output", "text"], env)
    target = aws(["lambda", "update-function-code", "--function-name", fn,
                  "--s3-bucket", bucket, "--s3-key", key, "--publish", "--region", region,
                  "--query", "Version", "--output", "text"], env)
    aws(["lambda", "wait", "function-updated-v2", "--function-name", fn, "--region", region], env)
    appspec = (f"version: 0.0\nResources:\n  - myLambdaFunction:\n"
               f"      Type: AWS::Lambda::Function\n      Properties:\n"
               f'        Name: "{fn}"\n        Alias: "{alias}"\n'
               f'        CurrentVersion: "{current}"\n        TargetVersion: "{target}"\n')
    revision = {"revisionType": "AppSpecContent", "appSpecContent": {"content": appspec}}
    request = {
        "applicationName": env.get("CODEDEPLOY_APP", fn),
        "deploymentGroupName": env.get("CODEDEPLOY_GROUP", fn + "-canary"),
        "deploymentConfigName": "CodeDeployDefault.LambdaCanary10Percent10Minutes"
        if release == "faulty" else "CodeDeployDefault.LambdaAllAtOnce",
        "revision": revision,
    }
    request_path = ROOT / "build" / f"native-deployment-{release}.json"
    request_path.write_text(json.dumps(request), encoding="utf-8")
    deployment = json.loads(aws(["deploy", "create-deployment", "--cli-input-json",
                                 f"file://{request_path.as_posix()}", "--region", region], env))
    dep_id = deployment["deploymentId"]
    print(f"current_version={current}\ntarget_version={target}\ndeployment_id={dep_id}", flush=True)
    if "--wait" in args:
        aws(["deploy", "wait", "deployment-successful", "--deployment-id", dep_id, "--region", region], env)
        print("deployment succeeded", flush=True)


def collect(env: dict[str, str]) -> None:
    fn = env.get("FUNCTION_NAME", "aws-lambda-safe-releases")
    region = env.get("AWS_REGION", "eu-west-2")
    alias = env.get("ALIAS_NAME", "live")
    out = ROOT / "evidence/raw" / env["RUN_ID"]
    out.mkdir(parents=True, exist_ok=True)
    calls = {
        "lambda-function": ["lambda", "get-function", "--function-name", fn],
        "lambda-alias": ["lambda", "get-alias", "--function-name", fn, "--name", alias],
        "lambda-versions": ["lambda", "list-versions-by-function", "--function-name", fn],
        "codedeploy-app": ["deploy", "get-application", "--application-name", fn],
        "codedeploy-group": ["deploy", "get-deployment-group", "--application-name", fn,
                             "--deployment-group-name", env.get("CODEDEPLOY_GROUP", fn + "-canary")],
        "codedeploy-deployments": ["deploy", "list-deployments", "--application-name", fn,
                                   "--deployment-group-name", env.get("CODEDEPLOY_GROUP", fn + "-canary")],
        "alarms": ["cloudwatch", "describe-alarms", "--alarm-names", fn + "-live-errors"],
        "apis": ["apigatewayv2", "get-apis"],
        "log-groups": ["logs", "describe-log-groups", "--log-group-name-prefix", "/aws/lambda/" + fn],
    }
    if env.get("DEPLOYMENT_ID"):
        calls["deployment"] = ["deploy", "get-deployment", "--deployment-id", env["DEPLOYMENT_ID"]]
    for name, call in calls.items():
        (out / (name + ".json")).write_text(aws(call + ["--region", region, "--output", "json"], env), encoding="utf-8")
    print(f"wrote {out}")


def verify(env: dict[str, str]) -> None:
    project = env.get("PROJECT", "aws-lambda-safe-releases")
    region = env.get("AWS_REGION", "eu-west-2")
    calls = {
        "Lambda functions": ["lambda", "list-functions", "--region", region, "--query", f"Functions[?starts_with(FunctionName, '{project}')].FunctionName"],
        "CodeDeploy applications": ["deploy", "list-applications", "--region", region, "--query", f"applications[?starts_with(@, '{project}')]"],
        "CloudWatch alarms": ["cloudwatch", "describe-alarms", "--region", region, "--query", f"MetricAlarms[?starts_with(AlarmName, '{project}')].AlarmName"],
        "API Gateway APIs": ["apigatewayv2", "get-apis", "--region", region, "--query", f"Items[?starts_with(Name, '{project}')].Name"],
        "IAM policies": ["iam", "list-policies", "--scope", "Local", "--query", f"Policies[?starts_with(PolicyName, '{project}')].PolicyName"],
        "Log groups": ["logs", "describe-log-groups", "--region", region, "--log-group-name-prefix", "/aws/lambda/" + project, "--query", "logGroups[].logGroupName"],
        "S3 buckets": ["s3api", "list-buckets", "--query", f"Buckets[?starts_with(Name, '{project}')].Name"],
        "IAM roles": ["iam", "list-roles", "--query", f"Roles[?starts_with(RoleName, '{project}')].RoleName"],
    }
    results = {}
    for name, call in calls.items():
        results[name] = {"command": ["aws", *call], "exit_code": 0,
                         "remaining": json.loads(aws(call + ["--output", "json"], env))}
    payload = {"checked_utc": datetime.now(timezone.utc).isoformat(), "region": region,
               "retained_exception": "Tag-scoped budget intentionally retained; verified separately",
               "checks": results, "all_clear": all(not v["remaining"] for v in results.values())}
    if env.get("RUN_ID"):
        out = ROOT / "evidence/raw" / env["RUN_ID"]
        out.mkdir(parents=True, exist_ok=True)
        (out / "cleanup-verification.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(json.dumps(payload, indent=2))
    if not payload["all_clear"]:
        raise RuntimeError("Demo resource leftovers detected")


def main() -> None:
    env, script, args = parse_request(sys.argv[1])
    if script.endswith("deploy.sh"):
        deploy(env, args)
    elif script.endswith("collect-evidence.sh"):
        collect(env)
    else:
        verify(env)


if __name__ == "__main__":
    main()
