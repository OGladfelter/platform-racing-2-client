package pr2;

/** Runtime switch used to keep the default deterministic run broad and fast. */
class DeterministicTestMode {
	private static inline var MAX_TEST_MILLISECONDS:Float = 250;
	private static var cachedSmoke:Null<Bool>;
	private static var cachedTimings:Null<Bool>;
	private static var cachedGroups:Null<Array<String>>;
	private static var selectedSuites:Int = 0;
	private static var timedTests:Int = 0;
	private static var slowTests:Array<String> = [];

	public static function isSmoke():Bool {
		if (cachedSmoke == null) {
			cachedSmoke = Sys.getEnv("PR2_TEST_MODE") == "smoke";
		}
		return cachedSmoke;
	}

	public static function finishSmokeSuite(name:String):Bool {
		if (!isSmoke()) return false;
		trace('$name passed its smoke test');
		return true;
	}

	public static function runSuite(name:String, tags:Array<String>, callback:Void->Void):Void {
		var requested = groups();
		if (requested.length > 0) {
			var matches = false;
			for (tag in tags) {
				if (requested.indexOf(tag) >= 0) {
					matches = true;
					break;
				}
			}
			if (!matches) return;
		}
		selectedSuites++;
		var testsBeforeSuite = timedTests;
		var startedAt = haxe.Timer.stamp();
		callback();
		if (timedTests == testsBeforeSuite) {
			reportTestTime('$name.main', haxe.Timer.stamp() - startedAt);
		}
	}

	public static function runTest(name:String, callback:Void->Void):Void {
		var startedAt = haxe.Timer.stamp();
		callback();
		reportTestTime(name, haxe.Timer.stamp() - startedAt);
	}

	private static function reportTestTime(name:String, elapsedSeconds:Float):Void {
		timedTests++;
		var elapsedMilliseconds = elapsedSeconds * 1000;
		var formattedMilliseconds = formatMilliseconds(elapsedMilliseconds);
		if (timingsEnabled()) {
			Sys.println('TEST_TIME\t$name\t$formattedMilliseconds ms');
		}
		if (elapsedMilliseconds > MAX_TEST_MILLISECONDS) {
			slowTests.push('$name took $formattedMilliseconds ms');
		}
	}

	private static function timingsEnabled():Bool {
		if (cachedTimings == null) {
			cachedTimings = Sys.getEnv("PR2_TEST_TIMINGS") == "true";
		}
		return cachedTimings;
	}

	public static function failIfTestsAreTooSlow():Void {
		if (slowTests.length == 0) return;
		throw 'Tests exceeded the ${MAX_TEST_MILLISECONDS} ms limit:\n- ${slowTests.join("\n- ")}\n'
			+ "Slow coverage may be better suited to on-demand end-to-end (E2E) tests.";
	}

	private static function formatMilliseconds(value:Float):String {
		return Std.string(Math.round(value * 1000) / 1000);
	}

	public static function hasGroupSelection():Bool {
		return groups().length > 0;
	}

	public static function selectedSuiteCount():Int {
		return selectedSuites;
	}

	public static function selectionSummary():String {
		return groups().join(", ") + ': $selectedSuites suites';
	}

	private static function groups():Array<String> {
		if (cachedGroups == null) {
			var raw = Sys.getEnv("PR2_TEST_GROUPS");
			cachedGroups = raw == null || raw == "" ? [] : raw.split(",");
		}
		return cachedGroups;
	}
}
