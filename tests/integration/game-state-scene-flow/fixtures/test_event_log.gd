## Shared lifecycle event log for integration test fixtures.
## Cleared in before_test(); checked after a swap to verify call ordering.
class_name TestEventLog
extends RefCounted

static var events: Array[String] = []
