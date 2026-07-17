import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "lambda" / "reconcile_msk_broker_targets.py"
SPEC = importlib.util.spec_from_file_location("reconcile_msk_broker_targets", MODULE_PATH)
RECONCILER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RECONCILER)


def broker_node(broker_id, ip, host):
    return {
        "BrokerNodeInfo": {
            "BrokerId": broker_id,
            "ClientVpcIpAddress": ip,
            "Endpoints": [host],
        }
    }


class FakeKafka:
    def __init__(self, pages):
        self.pages = pages
        self.calls = []

    def list_nodes(self, **request):
        self.calls.append(request)
        page = len(self.calls) - 1
        response = {"NodeInfoList": self.pages[page]}
        if page < len(self.pages) - 1:
            response["NextToken"] = f"page-{page + 1}"
        return response


class FakeElbv2:
    def __init__(self, health):
        self.health = health
        self.registered = []
        self.deregistered = []

    def describe_target_health(self, TargetGroupArn):
        return {
            "TargetHealthDescriptions": [
                {
                    "Target": {"Id": target_id, "Port": port},
                    "TargetHealth": {"State": state},
                }
                for (target_id, port), state in self.health[TargetGroupArn].items()
            ]
        }

    def register_targets(self, TargetGroupArn, Targets):
        self.registered.append((TargetGroupArn, Targets))
        for target in Targets:
            self.health[TargetGroupArn][(target["Id"], target["Port"])] = "initial"

    def deregister_targets(self, TargetGroupArn, Targets):
        self.deregistered.append((TargetGroupArn, Targets))
        for target in Targets:
            self.health[TargetGroupArn].pop((target["Id"], target["Port"]), None)


class ReconcilerTest(unittest.TestCase):
    def test_endpoint_host_accepts_host_only_and_matching_port(self):
        self.assertEqual(RECONCILER._endpoint_host(["b-1.example"], 9098), "b-1.example")
        self.assertEqual(RECONCILER._endpoint_host(["b-1.example:9098"], 9098), "b-1.example")

    def test_broker_id_normalizes_integral_floats(self):
        self.assertEqual(RECONCILER._broker_id(1.0), "1")
        self.assertEqual(RECONCILER._broker_id(2), "2")

    def test_healthy_current_target_requires_no_changes(self):
        kafka = FakeKafka([[broker_node(1, "10.0.1.10", "b-1.example")]])
        elbv2 = FakeElbv2({"tg-1": {("10.0.1.10", 9098): "healthy"}})

        result = RECONCILER.reconcile(
            kafka,
            elbv2,
            "cluster-arn",
            {"1": "tg-1"},
            {"1": "b-1.example"},
            9098,
        )

        self.assertEqual(result, {"registered": [], "deregistered": [], "unresolved": []})
        self.assertEqual(elbv2.registered, [])
        self.assertEqual(elbv2.deregistered, [])

    def test_registers_new_ip_but_retains_stale_target_until_healthy(self):
        kafka = FakeKafka([[broker_node(1, "10.0.1.20", "b-1.example")]])
        elbv2 = FakeElbv2({"tg-1": {("10.0.1.10", 9098): "healthy"}})

        result = RECONCILER.reconcile(
            kafka,
            elbv2,
            "cluster-arn",
            {"1": "tg-1"},
            {"1": "b-1.example"},
            9098,
        )

        self.assertEqual(elbv2.registered[0][1], [{"Id": "10.0.1.20", "Port": 9098}])
        self.assertEqual(elbv2.deregistered, [])
        self.assertIn(("10.0.1.10", 9098), elbv2.health["tg-1"])
        self.assertEqual(result["unresolved"][0]["state"], "registering")

        elbv2.health["tg-1"][("10.0.1.20", 9098)] = "healthy"
        result = RECONCILER.reconcile(
            FakeKafka([[broker_node(1, "10.0.1.20", "b-1.example")]]),
            elbv2,
            "cluster-arn",
            {"1": "tg-1"},
            {"1": "b-1.example"},
            9098,
        )

        self.assertEqual(result["deregistered"], [{"broker_id": "1", "ip": "10.0.1.10"}])
        self.assertNotIn(("10.0.1.10", 9098), elbv2.health["tg-1"])

    def test_existing_unhealthy_current_target_fails_reconciliation(self):
        kafka = FakeKafka([[broker_node(1, "10.0.1.20", "b-1.example")]])
        elbv2 = FakeElbv2(
            {
                "tg-1": {
                    ("10.0.1.10", 9098): "healthy",
                    ("10.0.1.20", 9098): "initial",
                }
            }
        )

        with self.assertRaisesRegex(RuntimeError, "not healthy"):
            RECONCILER.reconcile(
                kafka,
                elbv2,
                "cluster-arn",
                {"1": "tg-1"},
                {"1": "b-1.example"},
                9098,
            )

        self.assertEqual(elbv2.deregistered, [])

    def test_does_not_deregister_stale_target_that_is_already_draining(self):
        kafka = FakeKafka([[broker_node(1, "10.0.1.20", "b-1.example")]])
        elbv2 = FakeElbv2(
            {
                "tg-1": {
                    ("10.0.1.10", 9098): "draining",
                    ("10.0.1.20", 9098): "healthy",
                }
            }
        )

        result = RECONCILER.reconcile(
            kafka,
            elbv2,
            "cluster-arn",
            {"1": "tg-1"},
            {"1": "b-1.example"},
            9098,
        )

        self.assertEqual(result["deregistered"], [])
        self.assertEqual(elbv2.deregistered, [])

    def test_initial_reconciliation_waits_for_all_targets(self):
        kafka = FakeKafka(
            [[
                broker_node(1, "10.0.1.10", "b-1.example"),
                broker_node(2, "10.0.2.10", "b-2.example"),
            ]]
        )
        elbv2 = FakeElbv2({"tg-1": {}, "tg-2": {}})

        def mark_healthy(_):
            for health in elbv2.health.values():
                for target in health:
                    health[target] = "healthy"

        result = RECONCILER.reconcile(
            kafka,
            elbv2,
            "cluster-arn",
            {"1": "tg-1", "2": "tg-2"},
            {"1": "b-1.example", "2": "b-2.example"},
            9098,
            wait_seconds=10,
            sleep=mark_healthy,
        )

        self.assertEqual(len(result["registered"]), 2)
        self.assertEqual(result["unresolved"], [])

    def test_paginates_list_nodes(self):
        kafka = FakeKafka(
            [
                [broker_node(1, "10.0.1.10", "b-1.example")],
                [broker_node(2, "10.0.2.10", "b-2.example")],
            ]
        )
        elbv2 = FakeElbv2(
            {
                "tg-1": {("10.0.1.10", 9098): "healthy"},
                "tg-2": {("10.0.2.10", 9098): "healthy"},
            }
        )

        RECONCILER.reconcile(
            kafka,
            elbv2,
            "cluster-arn",
            {"1": "tg-1", "2": "tg-2"},
            {"1": "b-1.example", "2": "b-2.example"},
            9098,
        )

        self.assertEqual(kafka.calls[1]["NextToken"], "page-1")

    def test_identity_mismatch_aborts_before_target_changes(self):
        kafka = FakeKafka([[broker_node(2, "10.0.2.10", "b-2.example")]])
        elbv2 = FakeElbv2({"tg-1": {}})

        with self.assertRaisesRegex(ValueError, "broker IDs do not match"):
            RECONCILER.reconcile(
                kafka,
                elbv2,
                "cluster-arn",
                {"1": "tg-1"},
                {"1": "b-1.example"},
                9098,
            )

        self.assertEqual(elbv2.registered, [])

    def test_hostname_change_aborts_before_target_changes(self):
        kafka = FakeKafka([[broker_node(1, "10.0.1.10", "new-b-1.example")]])
        elbv2 = FakeElbv2({"tg-1": {}})

        with self.assertRaisesRegex(ValueError, "hostnames changed"):
            RECONCILER.reconcile(
                kafka,
                elbv2,
                "cluster-arn",
                {"1": "tg-1"},
                {"1": "b-1.example"},
                9098,
            )

        self.assertEqual(elbv2.registered, [])


if __name__ == "__main__":
    unittest.main()
