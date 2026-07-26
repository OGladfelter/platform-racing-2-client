package pr2.runtime;

class FrameRateFallbackPolicyTest {
	private static var assertions:Int = 0;

	public static function main():Void {
		testWarmupAndSustainedThreshold();
		if (pr2.DeterministicTestMode.finishSmokeSuite("FrameRateFallbackPolicyTest")) return;
		testHealthyWindowResetsSlowStreak();
		testUnsupportedStateIsSessionSticky();
		trace('FrameRateFallbackPolicyTest passed $assertions assertions');
	}

	private static function testWarmupAndSustainedThreshold():Void {
		var policy = new FrameRateFallbackPolicy();
		assertEquals(false, policy.observeWindow(40, 1000), "first slow window is warm-up");
		assertEquals(false, policy.observeWindow(40, 1000), "second slow window is warm-up");
		assertEquals(false, policy.observeWindow(50, 1000), "first measured 20 ms window starts streak");
		assertEquals(false, policy.observeWindow(49, 1000), "second measured slow window continues streak");
		assertEquals(true, policy.observeWindow(50, 1000), "third consecutive slow window declares unsupported");
		assertEquals(3, policy.consecutiveSlowWindows, "threshold records the full sustained streak");
	}

	private static function testHealthyWindowResetsSlowStreak():Void {
		var policy = new FrameRateFallbackPolicy();
		policy.observeWindow(60, 1000);
		policy.observeWindow(60, 1000);
		policy.observeWindow(49, 1000);
		assertEquals(1, policy.consecutiveSlowWindows, "slow measured window starts streak");
		policy.observeWindow(51, 1000);
		assertEquals(0, policy.consecutiveSlowWindows, "healthy measured window resets streak");
		assertEquals(false, policy.unsupported, "non-consecutive slow windows do not disable smooth mode");
	}

	private static function testUnsupportedStateIsSessionSticky():Void {
		var policy = new FrameRateFallbackPolicy();
		for (_ in 0...5) policy.observeWindow(40, 1000);
		assertEquals(true, policy.unsupported, "fixture reaches unsupported state");
		assertEquals(true, policy.observeWindow(60, 1000), "healthy later window cannot re-enable this session");
		assertEquals(true, policy.unsupported, "unsupported state remains sticky");
	}

	private static function assertEquals(expected:Dynamic, actual:Dynamic, message:String):Void {
		assertions++;
		if (expected != actual) throw '$message: expected $expected, got $actual';
	}
}
