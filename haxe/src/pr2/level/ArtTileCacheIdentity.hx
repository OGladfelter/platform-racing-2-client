package pr2.level;

import haxe.crypto.Md5;
import pr2.level.Level.LevelArtLayer;

class ArtTileCacheIdentity {
	public static inline var RASTERIZER_VERSION:Int = 1;

	public static function groupKey(level:Level, rasterScale:Float):String {
		var source = new StringBuf();
		source.add("art-tiles-v");
		source.add(RASTERIZER_VERSION);
		source.add("|");
		source.add(level.id);
		source.add("|");
		source.add(rasterScale);
		for (layer in level.artLayers) appendLayer(source, layer);
		return "art-tiles-v" + RASTERIZER_VERSION + "-" + Md5.encode(source.toString());
	}

	private static function appendLayer(source:StringBuf, layer:LevelArtLayer):Void {
		source.add("|layer|");
		source.add(layer.scale);
		for (action in layer.drawActions) {
			source.add("|");
			source.add(action.kind);
			source.add(":");
			source.add(action.text);
			for (value in action.values) {
				source.add(";");
				source.add(value);
			}
		}
	}
}
