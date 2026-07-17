import json
import logging
import os
import time


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def _endpoint_host(endpoints, port):
    matches = []
    for endpoint in endpoints:
        host, separator, endpoint_port = endpoint.rpartition(":")
        if not separator:
            matches.append(endpoint)
        elif endpoint_port == str(port):
            matches.append(host)
    if not matches:
        raise ValueError(f"no broker endpoint found for port {port}")
    return sorted(matches)[0]


def _broker_id(value):
    if isinstance(value, bool):
        raise ValueError(f"invalid MSK broker ID {value}")
    if isinstance(value, (int, float)):
        if float(value).is_integer():
            return str(int(value))
        raise ValueError(f"non-integral MSK broker ID {value}")
    return str(value)


def _list_brokers(kafka, cluster_arn, port):
    brokers = {}
    next_token = None

    while True:
        request = {"ClusterArn": cluster_arn}
        if next_token:
            request["NextToken"] = next_token
        response = kafka.list_nodes(**request)

        for node in response.get("NodeInfoList", []):
            broker = node.get("BrokerNodeInfo")
            if not broker:
                continue
            broker_id = _broker_id(broker["BrokerId"])
            if broker_id in brokers:
                raise ValueError(f"duplicate MSK broker ID {broker_id}")
            brokers[broker_id] = {
                "ip": broker["ClientVpcIpAddress"],
                "host": _endpoint_host(broker.get("Endpoints", []), port),
            }

        next_token = response.get("NextToken")
        if not next_token:
            return brokers


def _target_key(target):
    return target["Id"], int(target["Port"])


def _target_health(elbv2, target_group_arn):
    response = elbv2.describe_target_health(TargetGroupArn=target_group_arn)
    return {
        _target_key(description["Target"]): description["TargetHealth"]["State"]
        for description in response.get("TargetHealthDescriptions", [])
    }


def reconcile(kafka, elbv2, cluster_arn, target_groups, expected_hosts, port, wait_seconds=0, sleep=time.sleep):
    brokers = _list_brokers(kafka, cluster_arn, port)
    configured_ids = set(target_groups)
    discovered_ids = set(brokers)
    if configured_ids != discovered_ids:
        raise ValueError(
            "configured broker IDs do not match MSK: "
            f"configured={sorted(configured_ids)}, discovered={sorted(discovered_ids)}"
        )

    host_mismatches = {
        broker_id: {"expected": expected_hosts[broker_id], "discovered": broker["host"]}
        for broker_id, broker in brokers.items()
        if expected_hosts.get(broker_id) != broker["host"]
    }
    if host_mismatches:
        raise ValueError(f"broker hostnames changed; Terraform apply required: {host_mismatches}")

    health_by_broker = {}
    registered = []
    registered_broker_ids = set()
    for broker_id, target_group_arn in target_groups.items():
        expected_target = {"Id": brokers[broker_id]["ip"], "Port": port}
        health = _target_health(elbv2, target_group_arn)
        health_by_broker[broker_id] = health
        if _target_key(expected_target) not in health:
            elbv2.register_targets(TargetGroupArn=target_group_arn, Targets=[expected_target])
            registered.append({"broker_id": broker_id, "ip": expected_target["Id"]})
            registered_broker_ids.add(broker_id)

    deadline = time.monotonic() + wait_seconds
    while wait_seconds > 0:
        pending = []
        for broker_id, target_group_arn in target_groups.items():
            health_by_broker[broker_id] = _target_health(elbv2, target_group_arn)
            expected_key = (brokers[broker_id]["ip"], port)
            if health_by_broker[broker_id].get(expected_key) != "healthy":
                pending.append(broker_id)
        if not pending or time.monotonic() >= deadline:
            break
        sleep(min(5, max(0, deadline - time.monotonic())))

    deregistered = []
    unresolved = []
    for broker_id, target_group_arn in target_groups.items():
        expected_key = (brokers[broker_id]["ip"], port)
        health = health_by_broker[broker_id]
        expected_state = health.get(expected_key)
        if expected_state != "healthy":
            unresolved.append(
                {"broker_id": broker_id, "ip": expected_key[0], "state": expected_state or "registering"}
            )
            continue

        stale_targets = [
            {"Id": target_id, "Port": target_port}
            for (target_id, target_port), state in health.items()
            if (target_id, target_port) != expected_key and state != "draining"
        ]
        if stale_targets:
            elbv2.deregister_targets(TargetGroupArn=target_group_arn, Targets=stale_targets)
            deregistered.extend(
                {"broker_id": broker_id, "ip": target["Id"]} for target in stale_targets
            )

    result = {
        "registered": registered,
        "deregistered": deregistered,
        "unresolved": unresolved,
    }
    LOGGER.info(json.dumps(result, sort_keys=True))
    failures = [
        target
        for target in unresolved
        if wait_seconds > 0 or target["broker_id"] not in registered_broker_ids
    ]
    if failures:
        raise RuntimeError(f"broker targets are not healthy: {json.dumps(failures, sort_keys=True)}")
    return result


def handler(event, context):
    import boto3

    return reconcile(
        kafka=boto3.client("kafka"),
        elbv2=boto3.client("elbv2"),
        cluster_arn=os.environ["MSK_CLUSTER_ARN"],
        target_groups=json.loads(os.environ["BROKER_TARGET_GROUPS"]),
        expected_hosts=json.loads(os.environ["BROKER_HOSTS"]),
        port=int(os.environ["KAFKA_PORT"]),
        wait_seconds=int(event.get("wait_for_healthy_seconds", 0)),
    )
