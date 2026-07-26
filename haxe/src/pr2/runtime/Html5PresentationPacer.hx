package pr2.runtime;

import openfl.display.Stage;
import pr2.Constants;

#if (js && html5)
import lime.app.Application;
#end

/**
	Keeps the experimental HTML5 presentation clock at its requested rate.

	Lime 8.3.2 treats a Stage frame rate of 60 or greater as "use every
	requestAnimationFrame callback". On high-refresh displays that makes a
	requested 60 FPS stage run at 120 Hz or faster. Smooth presentation targets
	at most one visual-only frame between 28-30 Hz simulation ticks, so opt it
	back into Lime's elapsed-time limiter after setting the public Stage rate.
**/
final class Html5PresentationPacer {
	public static function apply(stage:Stage, requestedFrameRate:Float, smooth60Enabled:Bool):Void {
		stage.frameRate = requestedFrameRate;

		#if (js && html5)
		if (shouldCapNativeRefresh(smooth60Enabled, requestedFrameRate) && Application.current != null) {
			@:privateAccess Application.current.__backend.framePeriod = framePeriodMs(requestedFrameRate);
		}
		#end
	}

	public static inline function shouldCapNativeRefresh(smooth60Enabled:Bool, requestedFrameRate:Float):Bool {
		return smooth60Enabled && requestedFrameRate == Constants.SMOOTH_PRESENTATION_FRAME_RATE;
	}

	public static inline function framePeriodMs(requestedFrameRate:Float):Float {
		return 1000.0 / requestedFrameRate;
	}

	private function new() {}
}
