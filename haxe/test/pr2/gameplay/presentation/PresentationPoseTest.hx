package pr2.gameplay.presentation;

class PresentationPoseTest {
	private static var assertions:Int = 0;

	public static function main():Void {
		pr2.DeterministicTestMode.runTest("PresentationPoseTest.testConstantMotion", testConstantMotion);
		if (pr2.DeterministicTestMode.finishSmokeSuite("PresentationPoseTest")) return;
		pr2.DeterministicTestMode.runTest("PresentationPoseTest.testFractionalAndNegativeMotion", testFractionalAndNegativeMotion);
		pr2.DeterministicTestMode.runTest("PresentationPoseTest.testStoppedMotion", testStoppedMotion);
		pr2.DeterministicTestMode.runTest("PresentationPoseTest.testDirectionReversal", testDirectionReversal);
		pr2.DeterministicTestMode.runTest("PresentationPoseTest.testEverySnapCondition", testEverySnapCondition);
		pr2.DeterministicTestMode.runTest("PresentationPoseTest.testSampleLifecycle", testSampleLifecycle);
		trace('PresentationPoseTest passed $assertions assertions');
	}

	private static function testConstantMotion():Void {
		var pose = poseFromMotion(10, 20, 14, 26);
		assertClose(16, pose.extrapolatedX(0.5), "constant x motion extrapolates one half-step");
		assertClose(29, pose.extrapolatedY(0.5), "constant y motion extrapolates one half-step");
		assertEquals(false, pose.discontinuity, "second continuous sample is eligible for extrapolation");
	}

	private static function testFractionalAndNegativeMotion():Void {
		var fractional = poseFromMotion(1.25, -3.5, 1.75, -2.75);
		assertClose(2, fractional.extrapolatedX(0.5), "fractional positive movement remains fractional");
		assertClose(-2.375, fractional.extrapolatedY(0.5), "fractional negative coordinate extrapolates exactly");

		var negative = poseFromMotion(-2, 4, -5, -2);
		assertClose(-6.5, negative.extrapolatedX(0.5), "negative x movement extrapolates in the same direction");
		assertClose(-5, negative.extrapolatedY(0.5), "negative y movement extrapolates in the same direction");
	}

	private static function testStoppedMotion():Void {
		var pose = poseFromMotion(7.125, -9.25, 7.125, -9.25);
		assertClose(7.125, pose.extrapolatedX(0.5), "stopped x does not drift");
		assertClose(-9.25, pose.extrapolatedY(0.5), "stopped y does not drift");
	}

	private static function testDirectionReversal():Void {
		assertEquals(true, PresentationPose.velocityReversed(2, -0.5), "positive-to-negative horizontal reversal snaps");
		assertEquals(true, PresentationPose.velocityReversed(-3, 1), "negative-to-positive vertical reversal snaps");
		assertEquals(false, PresentationPose.velocityReversed(0, -2), "starting motion is not a reversal");
		assertEquals(false, PresentationPose.velocityReversed(2, 0), "stopping without a collision is not a reversal");
		assertEquals(false, PresentationPose.velocityReversed(-2, -1), "same-direction motion is safe");
	}

	private static function testEverySnapCondition():Void {
		assertEquals(false, snapReason(-1), "continuous motion has no snap reason");
		assertEquals(true, snapReason(0), "spawn requests a lifecycle snap");
		assertEquals(true, snapReason(0), "removal requests a lifecycle snap");
		assertEquals(true, snapReason(0), "finish requests a lifecycle snap");
		assertEquals(true, snapReason(0), "spectate change requests a lifecycle snap");
		assertEquals(true, snapReason(1), "teleport movement discontinuity snaps");
		assertEquals(true, snapReason(1), "respawn movement discontinuity snaps");
		assertEquals(true, snapReason(2), "wall or ceiling collision snaps");
		assertEquals(true, snapReason(3), "committed course rotation snaps");
		assertEquals(true, snapReason(4), "front/back layer change snaps");
		assertEquals(true, snapReason(5), "landing snaps");
		assertEquals(true, snapReason(6), "horizontal reversal snaps");
		assertEquals(true, snapReason(7), "vertical reversal snaps");
		assertEquals(true, snapReason(8), "unusually large movement snaps");
		assertEquals(false, PresentationPose.movementTooLarge(60, 0, 60), "exact movement threshold remains eligible");
		assertEquals(true, PresentationPose.movementTooLarge(-60.01, 0, 60), "negative movement beyond threshold snaps");
	}

	private static function testSampleLifecycle():Void {
		var pose = new PresentationPose();
		pose.beginSimulationTick(4, 5, 10, -1, CharacterPresentationLayer.Back);
		pose.finishSimulationTick(6, 7, 12, -1, CharacterPresentationLayer.Back);
		assertEquals(true, pose.discontinuity, "first sample pair snaps as spawn initialization");
		pose.beginSimulationTick(6, 7, 12, -1, CharacterPresentationLayer.Back);
		pose.finishSimulationTick(8, 9, 14, -1, CharacterPresentationLayer.Back);
		pose.markDiscontinuity();
		assertEquals(true, pose.discontinuity, "explicit lifecycle marker suppresses prediction");
		assertClose(8, pose.extrapolatedX(0), "zero extrapolation factor renders current authoritative x");
		pose.clear();
		assertEquals(false, pose.hasSamples, "clear invalidates both samples");
		assertClose(0, pose.previousX, "clear zeros previous sample");
		assertClose(0, pose.currentX, "clear zeros current sample");
		assertEquals(CharacterPresentationLayer.Front, pose.previousLayer, "clear restores previous layer default");
		assertEquals(CharacterPresentationLayer.Front, pose.currentLayer, "clear restores current layer default");
	}

	private static function poseFromMotion(previousX:Float, previousY:Float, currentX:Float, currentY:Float):PresentationPose {
		var pose = new PresentationPose();
		pose.beginSimulationTick(previousX, previousY, 0, 1, CharacterPresentationLayer.Front);
		pose.finishSimulationTick(previousX, previousY, 0, 1, CharacterPresentationLayer.Front);
		pose.beginSimulationTick(previousX, previousY, 0, 1, CharacterPresentationLayer.Front);
		pose.finishSimulationTick(currentX, currentY, 0, 1, CharacterPresentationLayer.Front);
		return pose;
	}

	private static function snapReason(reason:Int):Bool {
		var flags = [for (_ in 0...9) false];
		if (reason >= 0) flags[reason] = true;
		return PresentationPose.shouldSnap(
			flags[0],
			flags[1],
			flags[2],
			flags[3],
			flags[4],
			flags[5],
			flags[6],
			flags[7],
			flags[8]
		);
	}

	private static function assertEquals(expected:Dynamic, actual:Dynamic, message:String):Void {
		assertions++;
		if (expected != actual) throw '$message: expected $expected, got $actual';
	}

	private static function assertClose(expected:Float, actual:Float, message:String):Void {
		assertions++;
		if (Math.abs(expected - actual) > 0.000001) throw '$message: expected $expected, got $actual';
	}
}
