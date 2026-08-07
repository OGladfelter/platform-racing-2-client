package pr2.level;

import haxe.Timer;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.PNGEncoderOptions;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;
import pr2.level.ArtTileStorage.ArtTileStore;
import pr2.level.Level.LevelDrawAction;

/** Tile-based stroke indexing, rasterization, culling, and resource budgeting. */
class ArtStrokeTileSet {
	public final keys:Array<String> = [];
	public final tileXs:Array<Int> = [];
	public final tileYs:Array<Int> = [];
	private final seen:Map<String, Bool> = new Map();
	public var minTileX:Int = 0;
	public var maxTileX:Int = 0;
	public var minTileY:Int = 0;
	public var maxTileY:Int = 0;

	public function new() {}

	public function add(key:String, tileX:Int, tileY:Int):Void {
		if (seen.exists(key)) return;
		seen.set(key, true);
		keys.push(key);
		tileXs.push(tileX);
		tileYs.push(tileY);
		if (keys.length == 1) {
			minTileX = maxTileX = tileX;
			minTileY = maxTileY = tileY;
			return;
		}
		if (tileX < minTileX) minTileX = tileX;
		if (tileX > maxTileX) maxTileX = tileX;
		if (tileY < minTileY) minTileY = tileY;
		if (tileY > maxTileY) maxTileY = tileY;
	}

	public function tileSpanX():Int return keys.length == 0 ? 0 : Std.int((maxTileX - minTileX) / LevelRenderer.ART_RASTER_TILE_SIZE) + 1;
	public function tileSpanY():Int return keys.length == 0 ? 0 : Std.int((maxTileY - minTileY) / LevelRenderer.ART_RASTER_TILE_SIZE) + 1;
}

class ArtRasterBudget {
	public final limit:Int;
	public var tileCount(default, null):Int = 0;
	public var stopped(default, null):Bool = false;
	private final onStopped:Void->Void;

	public function new(limit:Int, onStopped:Void->Void) {
		this.limit = limit;
		this.onStopped = onStopped;
	}

	public function reserveTile():Bool {
		if (limit < 0) {
			tileCount++;
			return true;
		}
		if (tileCount >= limit) {
			if (!stopped) {
				stopped = true;
				onStopped();
			}
			return false;
		}
		tileCount++;
		return true;
	}
}

typedef ArtTileCacheContext = {
	var store:ArtTileStore;
	var groupKey:String;
	var levelId:String;
	var layerIndex:Int;
	@:optional var encode:BitmapData->Null<ByteArray>;
}

private class ArtResolvedStroke {
	public final values:Array<Float>;
	public final color:Int;
	public final size:Float;
	public final erase:Bool;

	public function new(action:LevelDrawAction, color:Int, size:Float, erase:Bool) {
		this.values = action.values.copy();
		this.color = color;
		this.size = size;
		this.erase = erase;
	}
}

private class ArtTileRecipe {
	public final key:String;
	public final tileX:Int;
	public final tileY:Int;
	public final strokes:Array<ArtResolvedStroke> = [];
	public var bitmap:Null<Bitmap>;
	public var revision:Int = 0;
	public var bakedRevision:Int = -1;
	public var renderedRevision:Int = -1;
	public var savedRevision:Int = -1;
	public var saveFailedRevision:Int = -1;
	public var cacheChecked:Bool = false;
	public var loadPending:Bool = false;
	public var savePending:Bool = false;
	public var pendingBitmapData:Null<BitmapData>;
	#if html5
	public var pendingSaveCanvas:Null<js.html.CanvasElement>;
	#end
	public var generation:Int = 0;

	public function new(key:String, tileX:Int, tileY:Int) {
		this.key = key;
		this.tileX = tileX;
		this.tileY = tileY;
	}
}

private class PendingStrokeRecipeOperation {
	public final stroke:ArtResolvedStroke;
	public final tiles:ArtStrokeTileSet;
	public var tileIndex:Int = 0;

	public function new(stroke:ArtResolvedStroke, tiles:ArtStrokeTileSet) {
		this.stroke = stroke;
		this.tiles = tiles;
	}
}

class ArtRasterTiles {
	public final rasterCanvas:Sprite;
	public final rasterScale:Float;
	public var lastProfilePath(default, null):String = "";
	public var lastProfileMode(default, null):String = "";
	public var lastProfileTileCount(default, null):Int = 0;
	public var lastProfileTileSpanX(default, null):Int = 0;
	public var lastProfileTileSpanY(default, null):Int = 0;
	private final budget:Null<ArtRasterBudget>;
	private final cache:Null<ArtTileCacheContext>;
	private final onWorkAvailable:Null<Void->Void>;
	private final recipes:Map<String, ArtTileRecipe> = new Map();
	private final recipeOrder:Array<ArtTileRecipe> = [];
	private var pendingStroke:Null<PendingStrokeRecipeOperation>;
	private var indexingComplete:Bool = false;
	private var disposed:Bool = false;
	private var viewInitialized:Bool = false;
	private var hotMinTileX:Int = 0;
	private var hotMaxTileX:Int = 0;
	private var hotMinTileY:Int = 0;
	private var hotMaxTileY:Int = 0;
	private var warmMinTileX:Int = 0;
	private var warmMaxTileX:Int = 0;
	private var warmMinTileY:Int = 0;
	private var warmMaxTileY:Int = 0;
	private var color:Int = 0x000000;
	private var size:Float = LevelRenderer.DEFAULT_ART_BRUSH_SIZE;
	private var mode:String = "draw";

	public function new(rasterCanvas:Sprite, ?budget:ArtRasterBudget, rasterScale:Float = 1, ?cache:ArtTileCacheContext,
			?onWorkAvailable:Void->Void) {
		this.rasterCanvas = rasterCanvas;
		this.budget = budget;
		this.rasterScale = rasterScale > 1 ? rasterScale : 1;
		this.cache = cache;
		this.onWorkAvailable = onWorkAvailable;
	}

	public function hasPersistentCache():Bool return cache != null && cache.store.enabled;

	public function dispose():Void {
		disposed = true;
		for (recipe in recipeOrder) {
			recipe.generation++;
			if (recipe.pendingBitmapData != null) recipe.pendingBitmapData.dispose();
			recipe.pendingBitmapData = null;
			disposePixels(recipe);
		}
		recipes.clear();
		recipeOrder.resize(0);
		pendingStroke = null;
	}

	public function applyAll(actions:Array<LevelDrawAction>):Void {
		for (action in actions) while (!apply(action, true)) {}
		flush();
		finishIndexing();
	}

	public function apply(action:LevelDrawAction, batch:Bool = false, ?deadline:Null<Float>):Bool {
		if (pendingStroke != null) return continuePendingStroke(deadline);
		switch (action.kind) {
			case "c":
				if (action.values.length > 0) color = Std.int(action.values[0]);
				setControlProfile("color");
			case "t":
				if (action.values.length > 0) size = action.values[0];
				setControlProfile("size");
			case "m":
				mode = action.text;
				setControlProfile("mode");
			case "d":
				if (action.values.length < 2) return true;
				var radius = Math.max(0.5, size / 2);
				var tiles = collectStrokeTiles(action, radius);
				setStrokeTileProfile(tiles, mode == "erase" ? "eraseRecipe" : "recipe");
				pendingStroke = new PendingStrokeRecipeOperation(new ArtResolvedStroke(action, color, size, mode == "erase"), tiles);
				return continuePendingStroke(deadline);
			default:
				setControlProfile("unknown");
		}
		return true;
	}

	public function flush():Void {
		lastProfilePath = "recipeFlush";
		lastProfileMode = mode;
	}

	public function finishIndexing():Void {
		indexingComplete = true;
		updateTiles(0);
		notifyWork();
	}

	public function finishIndexingAfterFailure():Void {
		pendingStroke = null;
		finishIndexing();
	}

	public function hasPendingRasterWork():Bool return pendingStroke != null;

	private function continuePendingStroke(?deadline:Null<Float>):Bool {
		var operation = pendingStroke;
		if (operation == null) return true;
		var processed = 0;
		while (operation.tileIndex < operation.tiles.keys.length && (processed == 0 || deadline == null || Timer.stamp() < deadline)) {
			appendStrokeToTile(operation, operation.tileIndex);
			operation.tileIndex++;
			processed++;
		}
		if (operation.tileIndex >= operation.tiles.keys.length) {
			pendingStroke = null;
			notifyWork();
			return true;
		}
		return false;
	}

	private function appendStrokeToTile(operation:PendingStrokeRecipeOperation, index:Int):Void {
		var key = operation.tiles.keys[index];
		var recipe = recipes.get(key);
		if (recipe == null) {
			if (operation.stroke.erase) return;
			if (budget != null && !budget.reserveTile()) return;
			recipe = new ArtTileRecipe(key, operation.tiles.tileXs[index], operation.tiles.tileYs[index]);
			recipes.set(key, recipe);
			recipeOrder.push(recipe);
		}
		recipe.strokes.push(operation.stroke);
		recipe.revision++;
		recipe.cacheChecked = false;
	}

	public function setVisibleWorldWindow(minX:Float, maxX:Float, minY:Float, maxY:Float, force:Bool):Void {
		var tile = LevelRenderer.ART_RASTER_TILE_SIZE;
		var hotMargin = LevelRenderer.ART_RASTER_HOT_MARGIN_TILES * tile;
		var nextHotMinX = tileOrigin(Std.int(Math.floor(minX * rasterScale))) - hotMargin;
		var nextHotMaxX = tileOrigin(Std.int(Math.floor(maxX * rasterScale))) + hotMargin;
		var nextHotMinY = tileOrigin(Std.int(Math.floor(minY * rasterScale))) - hotMargin;
		var nextHotMaxY = tileOrigin(Std.int(Math.floor(maxY * rasterScale))) + hotMargin;
		if (!force && viewInitialized
			&& nextHotMinX == hotMinTileX
			&& nextHotMaxX == hotMaxTileX
			&& nextHotMinY == hotMinTileY
			&& nextHotMaxY == hotMaxTileY) return;
		hotMinTileX = nextHotMinX;
		hotMaxTileX = nextHotMaxX;
		hotMinTileY = nextHotMinY;
		hotMaxTileY = nextHotMaxY;
		var warmExtraMargin = (LevelRenderer.ART_RASTER_WARM_MARGIN_TILES - LevelRenderer.ART_RASTER_HOT_MARGIN_TILES) * tile;
		warmMinTileX = hotMinTileX - warmExtraMargin;
		warmMaxTileX = hotMaxTileX + warmExtraMargin;
		warmMinTileY = hotMinTileY - warmExtraMargin;
		warmMaxTileY = hotMaxTileY + warmExtraMargin;
		viewInitialized = true;
		updateTiles(0);
		notifyWork();
	}

	/** Applies the current hot/warm/cold state immediately, then starts a bounded
		 number of persistent-cache saves. The save limit is shared across layers by
		 LevelArtRenderCoordinator. */
	public function updateTiles(saveLimit:Int):Int {
		if (disposed || !indexingComplete) return 0;
		for (recipe in recipeOrder) reconcileRecipe(recipe);
		return startPendingSaves(saveLimit);
	}

	private function reconcileRecipe(recipe:ArtTileRecipe):Void {
		var pending = recipe.pendingBitmapData;
		if (pending != null) {
			recipe.pendingBitmapData = null;
			if (isWarm(recipe)) {
				installPixels(recipe, pending);
				recipe.renderedRevision = recipe.revision;
			} else {
				pending.dispose();
			}
		}
		if (recipe.loadPending) return;
		if (recipe.bitmap == null) {
			if (recipe.bakedRevision != recipe.revision) {
				if (hasPersistentCache() && !recipe.cacheChecked) {
					startCacheLoad(recipe);
					return;
				}
				startRecipeRender(recipe);
			} else if (isWarm(recipe)) {
				if (hasPersistentCache() && recipe.savedRevision == recipe.revision) {
					startCacheLoad(recipe);
					return;
				}
				recipe.bakedRevision = -1;
				startRecipeRender(recipe);
			}
		} else if (recipe.renderedRevision != recipe.revision) {
			startRecipeRender(recipe);
		}
		var bitmap = recipe.bitmap;
		if (bitmap == null) return;
		if (isHot(recipe)) {
			if (bitmap.parent != rasterCanvas) setTileAttached(recipe, true);
		} else if (bitmap.parent == rasterCanvas) {
			setTileAttached(recipe, false);
		}
		if (!isWarm(recipe) && !recipe.savePending
			&& (recipe.savedRevision == recipe.revision || recipe.saveFailedRevision == recipe.revision || !hasPersistentCache())) {
			disposePixels(recipe);
		}
	}

	private function startPendingSaves(limit:Int):Int {
		if (limit <= 0 || !hasPersistentCache()) return 0;
		var started = 0;
		for (recipe in recipeOrder) {
			if (started >= limit) break;
			if (startPendingSave(recipe)) started++;
		}
		return started;
	}

	private function startPendingSave(recipe:ArtTileRecipe):Bool {
		if (recipe.bitmap == null || recipe.renderedRevision != recipe.revision || recipe.savedRevision == recipe.revision
			|| recipe.saveFailedRevision == recipe.revision || recipe.savePending) return false;
		#if html5
		var canvas = recipe.pendingSaveCanvas;
		if (canvas == null) return false;
		recipe.pendingSaveCanvas = null;
		startCanvasSave(recipe, canvas, recipe.revision);
		return true;
		#else
		return maybeSave(recipe);
		#end
	}

	private function startCacheLoad(recipe:ArtTileRecipe):Void {
		if (cache == null) return;
		recipe.loadPending = true;
		var generation = ++recipe.generation;
		cache.store.get(cache.groupKey, persistentTileKey(recipe), function(bytes:Null<ByteArray>):Void {
			if (disposed || generation != recipe.generation) return;
			recipe.cacheChecked = true;
			if (bytes == null) {
				recipe.loadPending = false;
				if (recipe.savedRevision == recipe.revision) {
					recipe.savedRevision = -1;
					recipe.bakedRevision = -1;
				}
				notifyWork();
				return;
			}
			recipe.bakedRevision = recipe.revision;
			recipe.savedRevision = recipe.revision;
			if (!isWarm(recipe)) {
				recipe.loadPending = false;
				notifyWork();
				return;
			}
			BitmapData.loadFromBytes(bytes).onComplete(function(data:BitmapData):Void {
				recipe.loadPending = false;
				if (disposed || generation != recipe.generation || data == null) {
					if (data != null) data.dispose();
					if (!disposed && generation == recipe.generation) recipe.cacheChecked = false;
					return;
				}
				if (recipe.pendingBitmapData != null) recipe.pendingBitmapData.dispose();
				recipe.pendingBitmapData = data;
				notifyWork();
			}).onError(function(_:Dynamic):Void {
				if (disposed || generation != recipe.generation) return;
				recipe.loadPending = false;
				recipe.bakedRevision = -1;
				recipe.savedRevision = -1;
				notifyWork();
			});
		});
	}

	private function maybeSave(recipe:ArtTileRecipe):Bool {
		if (cache == null || !cache.store.enabled || !indexingComplete || recipe.bitmap == null
			|| recipe.renderedRevision != recipe.revision || recipe.savedRevision == recipe.revision
			|| recipe.saveFailedRevision == recipe.revision || recipe.savePending) return false;
		var bytes:Null<ByteArray> = null;
		try {
			bytes = cache.encode == null ? recipe.bitmap.bitmapData.encode(recipe.bitmap.bitmapData.rect, new PNGEncoderOptions(true))
				: cache.encode(recipe.bitmap.bitmapData);
		} catch (_:Dynamic) {}
		if (bytes == null) {
			recipe.saveFailedRevision = recipe.revision;
			return false;
		}
		startSaveBytes(recipe, bytes, recipe.revision);
		return true;
	}

	private function startSaveBytes(recipe:ArtTileRecipe, bytes:ByteArray, revision:Int):Void {
		if (cache == null || !cache.store.enabled) {
			recipe.saveFailedRevision = revision;
			return;
		}
		recipe.savePending = true;
		putSaveBytes(recipe, bytes, revision);
	}

	private function putSaveBytes(recipe:ArtTileRecipe, bytes:ByteArray, revision:Int):Void {
		if (cache == null || !cache.store.enabled) {
			finishSave(recipe, revision, false);
			return;
		}
		cache.store.put(cache.groupKey, cache.levelId, persistentTileKey(recipe), bytes, function(saved:Bool):Void {
			if (disposed) return;
			finishSave(recipe, revision, saved);
		});
	}

	private function finishSave(recipe:ArtTileRecipe, revision:Int, saved:Bool):Void {
		recipe.savePending = false;
		if (saved) recipe.savedRevision = revision else recipe.saveFailedRevision = revision;
		notifyWork();
	}

	public function hasPendingTileWork():Bool {
		if (disposed) return false;
		for (recipe in recipeOrder) {
			if (!indexingComplete || recipe.loadPending || recipe.savePending || recipe.pendingBitmapData != null
				|| recipe.bakedRevision != recipe.revision) return true;
			if (hasPersistentCache() && recipe.savedRevision != recipe.revision && recipe.saveFailedRevision != recipe.revision) return true;
			if (isWarm(recipe)) {
				if (recipe.bitmap == null || recipe.renderedRevision != recipe.revision) return true;
				if (isHot(recipe) && recipe.bitmap.parent != rasterCanvas) return true;
				if (!isHot(recipe) && recipe.bitmap.parent == rasterCanvas) return true;
			} else if (recipe.bitmap != null || recipe.pendingBitmapData != null) return true;
		}
		return false;
	}

	public function isBakeComplete():Bool {
		if (disposed || !indexingComplete || pendingStroke != null) return false;
		for (recipe in recipeOrder) {
			if (recipe.loadPending || recipe.savePending || recipe.pendingBitmapData != null || recipe.bakedRevision != recipe.revision) return false;
			if (hasPersistentCache() && recipe.savedRevision != recipe.revision && recipe.saveFailedRevision != recipe.revision) return false;
			if (isHot(recipe) && (recipe.bitmap == null || recipe.bitmap.parent != rasterCanvas)) return false;
			if (!isHot(recipe) && recipe.bitmap != null && recipe.bitmap.parent == rasterCanvas) return false;
			if (!isWarm(recipe) && recipe.bitmap != null) return false;
		}
		return true;
	}

	public function renderHotTilesNow():Void {
		updateTiles(0);
		notifyWork();
	}

	public function hotTileCount():Int return countTiles(function(recipe) return isHot(recipe) && recipe.bitmap != null);
	public function warmTileCount():Int return countTiles(function(recipe) return isWarm(recipe) && !isHot(recipe) && recipe.bitmap != null);
	public function coldTileCount():Int return countTiles(function(recipe) return !isWarm(recipe) && recipe.bitmap == null && recipe.bakedRevision == recipe.revision);
	public function unbakedTileCount():Int return countTiles(function(recipe) return recipe.bakedRevision != recipe.revision);

	private function countTiles(test:ArtTileRecipe->Bool):Int {
		var count = 0;
		for (recipe in recipeOrder) if (test(recipe)) count++;
		return count;
	}

	private function startRecipeRender(recipe:ArtTileRecipe):Void {
		renderRecipe(recipe);
		notifyWork();
	}

	private function renderRecipe(recipe:ArtTileRecipe):Void {
		var data = rasterizeRecipe(recipe);
		installPixels(recipe, data);
		recipe.bakedRevision = recipe.revision;
		recipe.renderedRevision = recipe.revision;
		if (!hasPersistentCache()) recipe.saveFailedRevision = recipe.revision;
	}


	private function rasterizeRecipe(recipe:ArtTileRecipe):BitmapData {
		#if html5
		return rasterizeCanvasRecipe(recipe);
		#elseif (sys && lime_cairo && !pr2_test)
		return rasterizeCairoRecipe(recipe);
		#elseif pr2_test
		return rasterizeOpenFlRecipe(recipe);
		#else
		return rasterizeDisplayListRecipe(recipe);
		#end
	}

	#if html5
	private function rasterizeCanvasRecipe(recipe:ArtTileRecipe):BitmapData {
		var tileSize = LevelRenderer.ART_RASTER_TILE_SIZE + 1;
		var canvas = js.Browser.document.createCanvasElement();
		canvas.width = canvas.height = tileSize;
		var context:Dynamic = canvas.getContext2d();
		context.lineCap = "round";
		context.lineJoin = "round";
		for (stroke in recipe.strokes) {
			context.globalCompositeOperation = stroke.erase ? "destination-out" : "source-over";
			context.strokeStyle = stroke.erase ? "#ffffff" : "#" + StringTools.hex(stroke.color & 0xFFFFFF, 6);
			context.lineWidth = stroke.size * rasterScale;
			appendCanvasStroke(context, stroke.values, recipe);
			context.stroke();
		}
		var data = BitmapData.fromCanvas(canvas);
		if (hasPersistentCache()) recipe.pendingSaveCanvas = canvas;
		return data;
	}

	private function startCanvasSave(recipe:ArtTileRecipe, canvas:js.html.CanvasElement, revision:Int):Void {
		if (cache == null || !cache.store.enabled || !indexingComplete || recipe.savedRevision == revision
			|| recipe.saveFailedRevision == revision || recipe.savePending) return;
		recipe.savePending = true;
		try {
			canvas.toBlob(function(blob:js.html.Blob):Void {
				if (disposed) return;
				if (blob == null) {
					finishSave(recipe, revision, false);
					return;
				}
				var reader = new js.html.FileReader();
				reader.onload = function(_:Dynamic):Void {
					if (disposed) return;
					if (recipe.revision != revision || reader.result == null) {
						finishSave(recipe, revision, false);
						return;
					}
					putSaveBytes(recipe, ByteArray.fromArrayBuffer(cast reader.result), revision);
				};
				reader.onerror = function(_:Dynamic):Void {
					if (!disposed) finishSave(recipe, revision, false);
				};
				reader.readAsArrayBuffer(blob);
			}, "image/png");
		} catch (_:Dynamic) finishSave(recipe, revision, false);
	}

	private function appendCanvasStroke(context:Dynamic, values:Array<Float>, recipe:ArtTileRecipe):Void {
		var x = values[0];
		var y = values[1];
		context.beginPath();
		context.moveTo(localX(x, recipe), localY(y, recipe));
		context.lineTo(localX(x - 0.15, recipe), localY(y, recipe));
		context.moveTo(localX(x, recipe), localY(y, recipe));
		var index = 2;
		while (index + 1 < values.length) {
			x += values[index];
			y += values[index + 1];
			context.lineTo(localX(x, recipe), localY(y, recipe));
			index += 2;
		}
	}
	#end

	#if (sys && lime_cairo && !pr2_test)
	private function rasterizeCairoRecipe(recipe:ArtTileRecipe):BitmapData {
		var tileSize = LevelRenderer.ART_RASTER_TILE_SIZE + 1;
		var buffer = new lime.graphics.ImageBuffer(new lime.utils.UInt8Array(tileSize * tileSize * 4), tileSize, tileSize);
		buffer.format = lime.graphics.PixelFormat.BGRA32;
		buffer.premultiplied = true;
		var image = new lime.graphics.Image(buffer, 0, 0, tileSize, tileSize);
		var surface = lime.graphics.cairo.CairoImageSurface.fromImage(image);
		var cairo = new lime.graphics.cairo.Cairo(surface);
		cairo.lineCap = lime.graphics.cairo.CairoLineCap.ROUND;
		cairo.lineJoin = lime.graphics.cairo.CairoLineJoin.ROUND;
		for (stroke in recipe.strokes) {
			cairo.setOperator(stroke.erase ? lime.graphics.cairo.CairoOperator.DEST_OUT : lime.graphics.cairo.CairoOperator.OVER);
			if (stroke.erase) cairo.setSourceRGBA(1, 1, 1, 1) else {
				cairo.setSourceRGBA(((stroke.color >> 16) & 0xFF) / 255, ((stroke.color >> 8) & 0xFF) / 255, (stroke.color & 0xFF) / 255, 1);
			}
			cairo.lineWidth = stroke.size * rasterScale;
			appendCairoStroke(cairo, stroke.values, recipe);
			cairo.stroke();
		}
		surface.flush();
		return BitmapData.fromImage(image);
	}

	private function appendCairoStroke(cairo:lime.graphics.cairo.Cairo, values:Array<Float>, recipe:ArtTileRecipe):Void {
		var x = values[0];
		var y = values[1];
		cairo.moveTo(localX(x, recipe), localY(y, recipe));
		cairo.lineTo(localX(x - 0.15, recipe), localY(y, recipe));
		cairo.moveTo(localX(x, recipe), localY(y, recipe));
		var index = 2;
		while (index + 1 < values.length) {
			x += values[index];
			y += values[index + 1];
			cairo.lineTo(localX(x, recipe), localY(y, recipe));
			index += 2;
		}
	}
	#end

	private function rasterizeDisplayListRecipe(recipe:ArtTileRecipe):BitmapData {
		var data = new BitmapData(LevelRenderer.ART_RASTER_TILE_SIZE + 1, LevelRenderer.ART_RASTER_TILE_SIZE + 1, true, 0);
		var drawing = new Sprite();
		drawing.blendMode = BlendMode.LAYER;
		for (stroke in recipe.strokes) {
			var shape = new Shape();
			shape.graphics.lineStyle(stroke.size, stroke.erase ? 0xFFFFFF : stroke.color);
			appendStrokeToGraphics(shape, stroke.values);
			shape.blendMode = stroke.erase ? BlendMode.ERASE : BlendMode.NORMAL;
			drawing.addChild(shape);
		}
		var matrix = new Matrix();
		matrix.scale(rasterScale, rasterScale);
		matrix.translate(-recipe.tileX, -recipe.tileY);
		data.draw(drawing, matrix, null, BlendMode.NORMAL, null, true);
		return data;
	}

	#if pr2_test
	private function rasterizeOpenFlRecipe(recipe:ArtTileRecipe):BitmapData {
		var data = new BitmapData(LevelRenderer.ART_RASTER_TILE_SIZE + 1, LevelRenderer.ART_RASTER_TILE_SIZE + 1, true, 0);
		var start = 0;
		while (start < recipe.strokes.length) {
			var first = recipe.strokes[start];
			var end = start + 1;
			while (end < recipe.strokes.length && sameBatch(first, recipe.strokes[end])) end++;
			drawOpenFlStrokeBatch(data, recipe, start, end);
			start = end;
		}
		return data;
	}

	private function drawOpenFlStrokeBatch(target:BitmapData, recipe:ArtTileRecipe, start:Int, end:Int):Void {
		var first = recipe.strokes[start];
		var shape = new Shape();
		shape.graphics.lineStyle(first.size, first.erase ? 0xFFFFFF : first.color);
		var bounds = strokeValuesBounds(first.values, first.size / 2);
		for (index in start...end) {
			appendStrokeToGraphics(shape, recipe.strokes[index].values);
			if (index > start) bounds = bounds.union(strokeValuesBounds(recipe.strokes[index].values, first.size / 2));
		}
		var matrix = new Matrix();
		matrix.scale(rasterScale, rasterScale);
		matrix.translate(-recipe.tileX, -recipe.tileY);
		if (!first.erase) {
			target.draw(shape, matrix, null, BlendMode.NORMAL, null, true);
			return;
		}
		var tileSize = LevelRenderer.ART_RASTER_TILE_SIZE + 1;
		var rectX = Std.int(Math.max(0, Math.floor(bounds.x * rasterScale - recipe.tileX)));
		var rectY = Std.int(Math.max(0, Math.floor(bounds.y * rasterScale - recipe.tileY)));
		var rectRight = Std.int(Math.min(tileSize, Math.ceil(bounds.right * rasterScale - recipe.tileX)));
		var rectBottom = Std.int(Math.min(tileSize, Math.ceil(bounds.bottom * rasterScale - recipe.tileY)));
		if (rectRight <= rectX || rectBottom <= rectY) return;
		var targetRect = new Rectangle(rectX, rectY, rectRight - rectX, rectBottom - rectY);
		var mask = new BitmapData(Std.int(targetRect.width), Std.int(targetRect.height), true, 0);
		matrix.translate(-rectX, -rectY);
		mask.draw(shape, matrix, null, BlendMode.NORMAL, null, true);
		clearMaskedPixels(target, targetRect, mask);
		mask.dispose();
	}
	#end

	private function installPixels(recipe:ArtTileRecipe, data:BitmapData):Void {
		if (recipe.bitmap == null) {
			var bitmap = new Bitmap(data);
			bitmap.smoothing = true;
			bitmap.scaleX = bitmap.scaleY = 1 / rasterScale;
			bitmap.x = recipe.tileX / rasterScale;
			bitmap.y = recipe.tileY / rasterScale;
			recipe.bitmap = bitmap;
		} else {
			if (recipe.bitmap.bitmapData != null) recipe.bitmap.bitmapData.dispose();
			recipe.bitmap.bitmapData = data;
		}
	}

	private function disposePixels(recipe:ArtTileRecipe):Void {
		if (recipe.bitmap == null) return;
		if (recipe.bitmap.parent != null) recipe.bitmap.parent.removeChild(recipe.bitmap);
		if (recipe.bitmap.bitmapData != null) recipe.bitmap.bitmapData.dispose();
		recipe.bitmap = null;
		recipe.renderedRevision = -1;
	}

	private function setTileAttached(recipe:ArtTileRecipe, attach:Bool):Void {
		var bitmap = recipe.bitmap;
		if (bitmap == null) return;
		if (attach) {
			if (bitmap.parent != rasterCanvas) rasterCanvas.addChild(bitmap);
		} else if (bitmap.parent == rasterCanvas) rasterCanvas.removeChild(bitmap);
	}

	private function collectStrokeTiles(action:LevelDrawAction, radius:Float):ArtStrokeTileSet {
		var tiles = new ArtStrokeTileSet();
		var x = action.values[0];
		var y = action.values[1];
		addTilesForBounds(tiles, x - radius - 1, y - radius - 1, x + radius + 1, y + radius + 1);
		var index = 2;
		while (index + 1 < action.values.length) {
			var nextX = x + action.values[index];
			var nextY = y + action.values[index + 1];
			addTilesForBounds(tiles, Math.min(x, nextX) - radius - 1, Math.min(y, nextY) - radius - 1,
				Math.max(x, nextX) + radius + 1, Math.max(y, nextY) + radius + 1);
			x = nextX;
			y = nextY;
			index += 2;
		}
		return tiles;
	}

	private function addTilesForBounds(tiles:ArtStrokeTileSet, minX:Float, minY:Float, maxX:Float, maxY:Float):Void {
		var tile = LevelRenderer.ART_RASTER_TILE_SIZE;
		var tileY = tileOrigin(Std.int(Math.floor(minY * rasterScale)));
		var endY = tileOrigin(Std.int(Math.floor(maxY * rasterScale)));
		while (tileY <= endY) {
			var tileX = tileOrigin(Std.int(Math.floor(minX * rasterScale)));
			var endX = tileOrigin(Std.int(Math.floor(maxX * rasterScale)));
			while (tileX <= endX) {
				tiles.add(tileKey(tileX, tileY), tileX, tileY);
				tileX += tile;
			}
			tileY += tile;
		}
	}

	private function appendStrokeToGraphics(shape:Shape, values:Array<Float>):Void {
		var x = values[0];
		var y = values[1];
		shape.graphics.moveTo(x, y);
		shape.graphics.lineTo(x - 0.15, y);
		shape.graphics.moveTo(x, y);
		var index = 2;
		while (index + 1 < values.length) {
			x += values[index];
			y += values[index + 1];
			shape.graphics.lineTo(x, y);
			index += 2;
		}
	}

	#if pr2_test
	private function strokeValuesBounds(values:Array<Float>, radius:Float):Rectangle {
		var x = values[0];
		var y = values[1];
		var minX = x - radius - 1;
		var minY = y - radius - 1;
		var maxX = x + radius + 1;
		var maxY = y + radius + 1;
		var index = 2;
		while (index + 1 < values.length) {
			x += values[index];
			y += values[index + 1];
			minX = Math.min(minX, x - radius - 1);
			minY = Math.min(minY, y - radius - 1);
			maxX = Math.max(maxX, x + radius + 1);
			maxY = Math.max(maxY, y + radius + 1);
			index += 2;
		}
		return new Rectangle(minX, minY, maxX - minX, maxY - minY);
	}

	private function clearMaskedPixels(target:BitmapData, targetRect:Rectangle, mask:BitmapData):Void {
		var maskPixels = mask.getPixels(mask.rect);
		if (maskPixels == null) return;
		var width = Std.int(targetRect.width);
		var height = Std.int(targetRect.height);
		var targetX = Std.int(targetRect.x);
		var targetY = Std.int(targetRect.y);
		maskPixels.position = 0;
		target.lock();
		for (y in 0...height) {
			for (x in 0...width) if (maskPixels.readUnsignedInt() != 0) target.setPixel32(targetX + x, targetY + y, 0);
		}
		target.unlock(targetRect);
	}
	#end

	private function setControlProfile(path:String):Void {
		lastProfilePath = path;
		lastProfileMode = mode;
		lastProfileTileCount = 0;
		lastProfileTileSpanX = 0;
		lastProfileTileSpanY = 0;
	}

	private function setStrokeTileProfile(tiles:ArtStrokeTileSet, path:String):Void {
		lastProfilePath = path;
		lastProfileMode = mode;
		lastProfileTileCount = tiles.keys.length;
		lastProfileTileSpanX = tiles.tileSpanX();
		lastProfileTileSpanY = tiles.tileSpanY();
	}

	private function sameBatch(a:ArtResolvedStroke, b:ArtResolvedStroke):Bool {
		return a.erase == b.erase && a.size == b.size && (a.erase || a.color == b.color);
	}

	private function isHot(recipe:ArtTileRecipe):Bool {
		return !viewInitialized || (recipe.tileX >= hotMinTileX && recipe.tileX <= hotMaxTileX
			&& recipe.tileY >= hotMinTileY && recipe.tileY <= hotMaxTileY);
	}

	private function isWarm(recipe:ArtTileRecipe):Bool {
		return !viewInitialized || (recipe.tileX >= warmMinTileX && recipe.tileX <= warmMaxTileX
			&& recipe.tileY >= warmMinTileY && recipe.tileY <= warmMaxTileY);
	}

	private function notifyWork():Void if (onWorkAvailable != null) onWorkAvailable();
	private inline function localX(value:Float, recipe:ArtTileRecipe):Float return value * rasterScale - recipe.tileX;
	private inline function localY(value:Float, recipe:ArtTileRecipe):Float return value * rasterScale - recipe.tileY;
	private inline function persistentTileKey(recipe:ArtTileRecipe):String return cache.layerIndex + "/" + recipe.key;
	private static inline function tileOrigin(pixel:Int):Int return Std.int(Math.floor(pixel / LevelRenderer.ART_RASTER_TILE_SIZE)) * LevelRenderer.ART_RASTER_TILE_SIZE;
	private static inline function tileKey(tileX:Int, tileY:Int):String return tileX + "," + tileY;
}
