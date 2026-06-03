---
paths:
  - "tests/**"
---

# Test Standards

- Test naming: `test_[system]_[scenario]_[expected_result]` pattern
- Every test must have a clear arrange/act/assert structure
- Unit tests must not depend on external state (filesystem, network, database)
- Integration tests must clean up after themselves
- Performance tests must specify acceptable thresholds and fail if exceeded
- Test data must be defined in the test or in dedicated fixtures, never shared mutable state
- Mock external dependencies — tests should be fast and deterministic
- Every bug fix must have a regression test that would have caught the original bug

## Node Teardown in Headless Tests (Godot — GdUnit4)

**Rule**: Use `node.free()` (not `node.queue_free()`) to tear down nodes created in unit tests
that are NOT added to the scene tree.

`queue_free()` defers deletion to the end of the current frame via the SceneTree's deletion queue.
In headless GdUnit4 tests, nodes created with `.new()` and never added to the scene tree have no
SceneTree processing their deletion queue. This leaves the node alive as an **orphan**, which GdUnit4
counts and reports as a test cleanup failure (exit code 101).

**Pattern**:
```gdscript
func test_something() -> void:
    var node := MyNode.new()          # not added to scene tree

    # ... test code ...

    node.free()                       # ✅ immediate — no SceneTree needed
    # node.queue_free()              # ❌ deferred — orphan in headless tests
```

**Exception**: If the test adds the node to the tree via `add_child_autofree(node)`, GdUnit4 handles
cleanup automatically — do not call `free()` or `queue_free()` manually in that case.

**When `queue_free()` is correct**: In integration tests that run with a full scene tree, or when
testing `queue_free()` behavior itself. The `add_child_autofree()` GdUnit4 helper uses `queue_free()`
internally and is the right choice for tree-attached nodes.

## Examples

**Correct** (proper naming + Arrange/Act/Assert):

```gdscript
func test_health_system_take_damage_reduces_health() -> void:
    # Arrange
    var health := HealthComponent.new()
    health.max_health = 100
    health.current_health = 100

    # Act
    health.take_damage(25)

    # Assert
    assert_eq(health.current_health, 75)
```

**Incorrect**:

```gdscript
func test1() -> void:  # VIOLATION: no descriptive name
    var h := HealthComponent.new()
    h.take_damage(25)  # VIOLATION: no arrange step, no clear assert
    assert_true(h.current_health < 100)  # VIOLATION: imprecise assertion
```
