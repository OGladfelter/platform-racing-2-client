package pr2.audio;

import haxe.Timer;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.media.SoundTransform;
import openfl.net.URLRequest;
import pr2.lobby.account.Settings;
import pr2.net.ServerConfig;
import pr2.ui.MuteButton;
import pr2.audio.MusicCatalog.MusicTrack;

/** Runtime counterpart of GameSound; selection is separate from UI so the
	level editor and authored race dropdown can share identical playback rules. */
class GameMusic {
	public static inline var BASE_PATH:String = "/music/new";

	/** Music streams from the same host as the level/API endpoints (Flash used
		`Main.baseURL + "/music/new"`). Routing through `ServerConfig.getHost()`
		means an `?apiHost=/api` dev proxy forwards the request to pr2hub.com,
		instead of the bare path 404ing against the local static server. */
	public var selected(default, null):MusicTrack;
	private var channel:Null<SoundChannel>;
	private var sound:Null<Sound>;
	private var settingsTimer:Timer;
	private final createSound:Void->Sound;
	private var removed:Bool = false;

	public function new(?createSound:Void->Sound) {
		selected = {id: "0", label: "None", file: ""};
		this.createSound = createSound == null ? function():Sound return new Sound() : createSound;
		settingsTimer = new Timer(500);
		settingsTimer.run = refresh;
	}

	public function setSong(song:MusicTrack):Void {
		selected = song;
		if (removed) return;
		restart();
	}

	public static function streamUrl(song:MusicTrack):String {
		return ServerConfig.getHost() + BASE_PATH + "/" + song.file;
	}

	public function refresh():Void {
		if (removed) return;
		if (channel == null && sound == null && canPlay()) restart();
		else if (channel != null) channel.soundTransform = new SoundTransform(Settings.musicLevel / 100);
	}

	public function stop():Void {
		if (channel != null) {
			channel.removeEventListener(Event.SOUND_COMPLETE, onComplete);
			channel.stop();
			channel = null;
		}
		if (sound != null) {
			sound.removeEventListener(Event.COMPLETE, onLoadComplete);
			sound.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
			sound.close();
			sound = null;
		}
	}

	public function remove():Void {
		if (removed) return;
		removed = true;
		settingsTimer.stop();
		stop();
	}

	private function restart():Void {
		stop();
		if (removed || !canPlay()) return;
		sound = createSound();
		sound.addEventListener(Event.COMPLETE, onLoadComplete);
		sound.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		sound.load(new URLRequest(streamUrl(selected)));
	}

	private function onLoadComplete(event:Event):Void {
		var loaded = Std.downcast(event.currentTarget, Sound);
		if (loaded == null || loaded != sound || removed) return;
		loaded.removeEventListener(Event.COMPLETE, onLoadComplete);
		loaded.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		channel = loaded.play(0, 9999, new SoundTransform(Settings.musicLevel / 100));
		if (channel != null) {
			channel.addEventListener(Event.SOUND_COMPLETE, onComplete);
		} else {
			loaded.close();
			sound = null;
		}
	}

	private function onLoadError(event:IOErrorEvent):Void {
		var failed = Std.downcast(event.currentTarget, Sound);
		if (failed == null || failed != sound) return;
		failed.removeEventListener(Event.COMPLETE, onLoadComplete);
		failed.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		failed.close();
		sound = null;
	}

	private function canPlay():Bool return Settings.musicLevel > 0 && !MuteButton.muted && selected.id != "0" && selected.file != "";
	private function onComplete(_:Event):Void restart();
}
