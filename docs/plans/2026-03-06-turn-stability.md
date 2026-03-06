# Turn Stability Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Preserve strong body-bend turning while substantially reducing fold-like distortion during wall avoidance arcs and sharp retarget turns.

**Architecture:** Rework turn flex from a single global inward push into a propagated, locally-oriented bend signal with rate limiting. Restore boundary velocity correction and strengthen mesh curvature guards so the spine can bend hard without visual self-folding.

**Tech Stack:** Swift, SpriteKit, CoreGraphics, custom Verlet spine physics, xcodebuild, standalone Swift verification scripts

---

### Task 1: Add red tests for turn stability invariants

**Files:**
- Create: `Tests/TurnStabilitySpec.swift`
- Test harness inputs: `Goldfish/Core/Constants.swift`, `Goldfish/Physics/VerletParticle.swift`, `Goldfish/Physics/DistanceConstraint.swift`, `Goldfish/Physics/SpineChain.swift`, `Goldfish/Fish/FishMotionDriver.swift`, `Goldfish/Steering/SteeringAgent.swift`

**Step 1: Write the failing test**

Add a standalone Swift spec that asserts:
- boundary clamping removes inward velocity
- propagated turn bend peaks in the mid-body
- reversing turn direction does not instantly flip bend sign at full strength

**Step 2: Run test to verify it fails**

Run:

```bash
swiftc Goldfish/Core/Constants.swift Goldfish/Physics/VerletParticle.swift Goldfish/Physics/DistanceConstraint.swift Goldfish/Physics/SpineChain.swift Goldfish/Fish/FishMotionDriver.swift Goldfish/Steering/SteeringAgent.swift Tests/TurnStabilitySpec.swift -o /tmp/turn-stability-spec && /tmp/turn-stability-spec
```

Expected: FAIL because the current implementation still applies global turn flex and lacks propagation/rate limiting helpers.

**Step 3: Write minimal implementation**

Introduce the new turn bend controller and the smallest production hooks necessary to make the spec pass.

**Step 4: Run test to verify it passes**

Re-run the same `swiftc ... && /tmp/turn-stability-spec` command.

**Step 5: Commit**

```bash
git add Tests/TurnStabilitySpec.swift Goldfish
git commit -m "fix: stabilize fish turning bend"
```

### Task 2: Rework turn flex into a propagated controller

**Files:**
- Create: `Goldfish/Fish/TurnBendController.swift`
- Modify: `Goldfish/Fish/GoldfishEntity.swift`
- Modify: `Goldfish/Fish/FishMotionDriver.swift`
- Modify: `Goldfish.xcodeproj/project.pbxproj`

**Step 1: Write the failing test**

Extend the spec with explicit checks for:
- mid-body force peak
- neck stiffness
- tail lag on turn entry

**Step 2: Run test to verify it fails**

Run the standalone spec command and capture the failing assertion.

**Step 3: Write minimal implementation**

Implement a turn bend controller that:
- smooths `angularVelocity`
- rate-limits intensity growth/decay
- computes per-particle bend weights
- uses local lateral directions instead of a single head lateral direction

**Step 4: Run test to verify it passes**

Run the standalone spec again until green.

**Step 5: Commit**

```bash
git add Goldfish/Fish/TurnBendController.swift Goldfish/Fish/GoldfishEntity.swift Goldfish/Fish/FishMotionDriver.swift Goldfish.xcodeproj/project.pbxproj Tests/TurnStabilitySpec.swift
git commit -m "fix: propagate turn bend through spine"
```

### Task 3: Restore wall-contact stability

**Files:**
- Modify: `Goldfish/Fish/GoldfishEntity.swift`
- Test: `Tests/TurnStabilitySpec.swift`

**Step 1: Write the failing test**

Add an assertion that wall-clamped motion zeros only the inward velocity component and preserves tangential motion.

**Step 2: Run test to verify it fails**

Run the standalone spec and confirm the clamp assertion fails.

**Step 3: Write minimal implementation**

Update `clampAgentToBounds()` accordingly.

**Step 4: Run test to verify it passes**

Re-run the standalone spec.

**Step 5: Commit**

```bash
git add Goldfish/Fish/GoldfishEntity.swift Tests/TurnStabilitySpec.swift
git commit -m "fix: stabilize wall turn contact"
```

### Task 4: Strengthen mesh fold guards

**Files:**
- Modify: `Goldfish/Rendering/MeshDeformer.swift`
- Test: `Tests/TurnStabilitySpec.swift` or a dedicated lightweight mesh spec if needed

**Step 1: Write the failing test**

Add a curvature-based assertion that high-bend samples narrow more aggressively than moderate bends.

**Step 2: Run test to verify it fails**

Run the standalone spec and capture the width guard failure.

**Step 3: Write minimal implementation**

Tighten curvature reduction for high-bend regions without flattening normal turns.

**Step 4: Run test to verify it passes**

Run the standalone spec and verify green.

**Step 5: Commit**

```bash
git add Goldfish/Rendering/MeshDeformer.swift Tests/TurnStabilitySpec.swift
git commit -m "fix: guard mesh during sharp turns"
```

### Task 5: Full verification

**Files:**
- Verify existing project sources

**Step 1: Run targeted verification**

Run:

```bash
swiftc Goldfish/Core/Constants.swift Goldfish/Physics/VerletParticle.swift Goldfish/Physics/DistanceConstraint.swift Goldfish/Physics/SpineChain.swift Goldfish/Fish/FishMotionDriver.swift Goldfish/Steering/SteeringAgent.swift Tests/TurnStabilitySpec.swift -o /tmp/turn-stability-spec && /tmp/turn-stability-spec
xcodebuild -project Goldfish.xcodeproj -scheme Goldfish -configuration Debug -sdk iphonesimulator build
```

Expected: standalone spec PASS, app build succeeds.

**Step 2: Commit**

```bash
git add Goldfish Tests docs/plans
git commit -m "fix: improve turning body stability"
```
