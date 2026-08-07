package pr2.level;

import haxe.crypto.Md5;
import openfl.utils.ByteArray;

interface ArtTileStore {
	public var enabled(get, never):Bool;
	public function prepareGroup(groupKey:String, levelId:String):Void;
	public function get(groupKey:String, tileKey:String, callback:Null<ByteArray>->Void):Void;
	public function put(groupKey:String, levelId:String, tileKey:String, bytes:ByteArray, callback:Bool->Void):Void;
	public function dispose():Void;
}

class ArtTileStoreFactory {
	public static function create():ArtTileStore {
		#if pr2_test
		return new NoopArtTileStore();
		#elseif html5
		return new IndexedDbArtTileStore();
		#elseif sys
		return new NativeArtTileStore();
		#else
		return new NoopArtTileStore();
		#end
	}
}

class NoopArtTileStore implements ArtTileStore {
	public var enabled(get, never):Bool;
	private inline function get_enabled():Bool return false;

	public function new() {}
	public function prepareGroup(groupKey:String, levelId:String):Void {}
	public function get(groupKey:String, tileKey:String, callback:Null<ByteArray>->Void):Void callback(null);
	public function put(groupKey:String, levelId:String, tileKey:String, bytes:ByteArray, callback:Bool->Void):Void callback(false);
	public function dispose():Void {}
}

#if (sys && !pr2_test && !html5)
private typedef NativeCacheGroup = {
	var directory:String;
	var levelId:String;
	var bytes:Float;
	var lastAccess:Float;
}

class NativeArtTileStore implements ArtTileStore {
	private static inline var CACHE_DIRECTORY:String = "art-tile-cache-v1";
	private static inline var META_FILE:String = "meta.json";
	private static inline var SOFT_LIMIT_BYTES:Float = 256 * 1024 * 1024;
	private final root:String;
	private var activeGroup:String = "";
	private var disposed:Bool = false;

	public var enabled(get, never):Bool;
	private inline function get_enabled():Bool return !disposed;

	public function new() {
		root = haxe.io.Path.join([lime.system.System.applicationStorageDirectory, CACHE_DIRECTORY]);
		try ensureDirectory(root) catch (_:Dynamic) disposed = true;
	}

	public function prepareGroup(groupKey:String, levelId:String):Void {
		if (disposed) return;
		activeGroup = groupKey;
		try {
			ensureDirectory(groupDirectory(groupKey));
			for (group in readGroups()) {
				if (group.levelId == levelId && group.directory != groupDirectory(groupKey)) deleteDirectory(group.directory);
			}
			var group = readGroup(groupDirectory(groupKey));
			if (group == null) group = {directory: groupDirectory(groupKey), levelId: levelId, bytes: 0, lastAccess: now()};
			group.levelId = levelId;
			group.lastAccess = now();
			writeGroup(group);
			prune();
		} catch (_:Dynamic) {
			disposed = true;
		}
	}

	public function get(groupKey:String, tileKey:String, callback:Null<ByteArray>->Void):Void {
		if (disposed) {
			callback(null);
			return;
		}
		try {
			var path = tilePath(groupKey, tileKey);
			callback(sys.FileSystem.exists(path) ? ByteArray.fromBytes(sys.io.File.getBytes(path)) : null);
		} catch (_:Dynamic) callback(null);
	}

	public function put(groupKey:String, levelId:String, tileKey:String, bytes:ByteArray, callback:Bool->Void):Void {
		if (disposed) {
			callback(false);
			return;
		}
		try {
			var directory = groupDirectory(groupKey);
			ensureDirectory(directory);
			var path = tilePath(groupKey, tileKey);
			var oldSize:Float = sys.FileSystem.exists(path) ? sys.FileSystem.stat(path).size : 0;
			var data:haxe.io.Bytes = cast bytes;
			sys.io.File.saveBytes(path, data);
			var group = readGroup(directory);
			if (group == null) group = {directory: directory, levelId: levelId, bytes: 0, lastAccess: now()};
			group.bytes = Math.max(0, group.bytes - oldSize + data.length);
			group.lastAccess = now();
			writeGroup(group);
			prune();
			callback(true);
		} catch (_:Dynamic) callback(false);
	}

	public function dispose():Void disposed = true;

	private function prune():Void {
		var groups = readGroups();
		var total:Float = 0;
		for (group in groups) total += group.bytes;
		if (total <= SOFT_LIMIT_BYTES) return;
		groups.sort(function(a, b) return a.lastAccess < b.lastAccess ? -1 : a.lastAccess > b.lastAccess ? 1 : 0);
		for (group in groups) {
			if (total <= SOFT_LIMIT_BYTES) break;
			if (group.directory == groupDirectory(activeGroup)) continue;
			deleteDirectory(group.directory);
			total -= group.bytes;
		}
	}

	private function readGroups():Array<NativeCacheGroup> {
		var result:Array<NativeCacheGroup> = [];
		if (!sys.FileSystem.exists(root)) return result;
		for (entry in sys.FileSystem.readDirectory(root)) {
			var directory = haxe.io.Path.join([root, entry]);
			if (!sys.FileSystem.isDirectory(directory)) continue;
			var group = readGroup(directory);
			if (group != null) result.push(group);
		}
		return result;
	}

	private function readGroup(directory:String):Null<NativeCacheGroup> {
		var path = haxe.io.Path.join([directory, META_FILE]);
		if (!sys.FileSystem.exists(path)) return null;
		try {
			var value:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
			return {
				directory: directory,
				levelId: Std.string(value.levelId),
				bytes: Std.parseFloat(Std.string(value.bytes)),
				lastAccess: Std.parseFloat(Std.string(value.lastAccess))
			};
		} catch (_:Dynamic) return null;
	}

	private function writeGroup(group:NativeCacheGroup):Void {
		var value = {levelId: group.levelId, bytes: group.bytes, lastAccess: group.lastAccess};
		sys.io.File.saveContent(haxe.io.Path.join([group.directory, META_FILE]), haxe.Json.stringify(value));
	}

	private function deleteDirectory(directory:String):Void {
		if (!sys.FileSystem.exists(directory) || !sys.FileSystem.isDirectory(directory)) return;
		for (entry in sys.FileSystem.readDirectory(directory)) {
			var path = haxe.io.Path.join([directory, entry]);
			if (sys.FileSystem.isDirectory(path)) deleteDirectory(path) else sys.FileSystem.deleteFile(path);
		}
		sys.FileSystem.deleteDirectory(directory);
	}

	private function ensureDirectory(path:String):Void {
		if (!sys.FileSystem.exists(path)) sys.FileSystem.createDirectory(path);
	}

	private inline function groupDirectory(groupKey:String):String return haxe.io.Path.join([root, Md5.encode(groupKey)]);
	private inline function tilePath(groupKey:String, tileKey:String):String return haxe.io.Path.join([groupDirectory(groupKey), Md5.encode(tileKey) + ".png"]);
	private static inline function now():Float return Date.now().getTime();
}
#end

#if html5
class IndexedDbArtTileStore implements ArtTileStore {
	private static inline var DATABASE_NAME:String = "pr2-art-tile-cache";
	private static inline var DATABASE_VERSION:Int = 1;
	private static inline var SOFT_LIMIT_BYTES:Float = 256 * 1024 * 1024;
	private var database:Null<js.html.idb.Database>;
	private var pending:Array<Void->Void> = [];
	private var failed:Bool = false;
	private var disposed:Bool = false;
	private var activeGroup:String = "";
	private var writesSincePrune:Int = 0;

	public var enabled(get, never):Bool;
	private inline function get_enabled():Bool return !failed && !disposed;

	public function new() {
		try {
			var request = js.Browser.window.indexedDB.open(DATABASE_NAME, DATABASE_VERSION);
			request.onupgradeneeded = function(_:Dynamic):Void {
				var db:js.html.idb.Database = request.result;
				if (!db.objectStoreNames.contains("tiles")) {
					var tiles = db.createObjectStore("tiles", {keyPath: "id"});
					tiles.createIndex("group", "group", {unique: false});
				}
				if (!db.objectStoreNames.contains("groups")) {
					var groups = db.createObjectStore("groups", {keyPath: "id"});
					groups.createIndex("levelId", "levelId", {unique: false});
				}
			};
			request.onsuccess = function(_:Dynamic):Void {
				database = request.result;
				database.onversionchange = function(_:Dynamic):Void database.close();
				drainPending();
			};
			request.onerror = function(_:Dynamic):Void fail();
		} catch (_:Dynamic) fail();
	}

	public function prepareGroup(groupKey:String, levelId:String):Void {
		activeGroup = groupKey;
		whenReady(function():Void {
			if (database == null) return;
			var tx = database.transaction(["groups", "tiles"], READWRITE);
			var groups = tx.objectStore("groups");
			var activeBytes:Float = 0;
			var request = groups.index("levelId").openCursor(js.html.idb.KeyRange.only(levelId));
			request.onsuccess = function(_:Dynamic):Void {
				var cursor:js.html.idb.CursorWithValue = request.result;
				if (cursor == null) {
					groups.put({id: groupKey, levelId: levelId, bytes: activeBytes, lastAccess: now()});
					return;
				}
				var oldId:String = cursor.value.id;
				if (oldId != groupKey) {
					cursor.delete();
					deleteTilesForGroup(tx.objectStore("tiles"), oldId);
				} else activeBytes = cursor.value.bytes;
				cursor.continue_();
			};
			tx.oncomplete = function(_:Dynamic):Void prune(false);
		});
	}

	public function get(groupKey:String, tileKey:String, callback:Null<ByteArray>->Void):Void {
		whenReady(function():Void {
			if (database == null) {
				callback(null);
				return;
			}
			try {
				var request = database.transaction("tiles").objectStore("tiles").get(recordId(groupKey, tileKey));
				request.onsuccess = function(_:Dynamic):Void {
					var value:Dynamic = request.result;
					if (value == null || value.bytes == null) callback(null) else callback(ByteArray.fromArrayBuffer(value.bytes));
				};
				request.onerror = function(_:Dynamic):Void callback(null);
			} catch (_:Dynamic) callback(null);
		});
	}

	public function put(groupKey:String, levelId:String, tileKey:String, bytes:ByteArray, callback:Bool->Void):Void {
		putAttempt(groupKey, levelId, tileKey, bytes, callback, true);
	}

	private function putAttempt(groupKey:String, levelId:String, tileKey:String, bytes:ByteArray, callback:Bool->Void, retry:Bool):Void {
		whenReady(function():Void {
			if (database == null) {
				callback(false);
				return;
			}
			try {
				var tx = database.transaction(["tiles", "groups"], READWRITE);
				var tiles = tx.objectStore("tiles");
				var groups = tx.objectStore("groups");
				var id = recordId(groupKey, tileKey);
				var oldRequest = tiles.get(id);
				oldRequest.onsuccess = function(_:Dynamic):Void {
					var old:Dynamic = oldRequest.result;
					var oldSize:Float = old == null ? 0 : old.size;
					var buffer:lime.utils.ArrayBuffer = bytes;
					tiles.put({id: id, group: groupKey, key: tileKey, size: bytes.length, bytes: buffer});
					var groupRequest = groups.get(groupKey);
					groupRequest.onsuccess = function(_:Dynamic):Void {
						var group:Dynamic = groupRequest.result;
						var total:Float = group == null ? 0 : group.bytes;
						groups.put({id: groupKey, levelId: levelId, bytes: Math.max(0, total - oldSize + bytes.length), lastAccess: now()});
					};
				};
				tx.oncomplete = function(_:Dynamic):Void {
					callback(true);
					writesSincePrune++;
					if (writesSincePrune >= 16) {
						writesSincePrune = 0;
						prune(false);
					}
				};
				tx.onabort = function(_:Dynamic):Void {
					if (retry && tx.error != null && tx.error.name == "QuotaExceededError") {
						prune(true, function():Void putAttempt(groupKey, levelId, tileKey, bytes, callback, false));
					} else callback(false);
				};
			} catch (_:Dynamic) callback(false);
		});
	}

	private function prune(emergency:Bool, ?complete:Void->Void):Void {
		if (database == null) {
			if (complete != null) complete();
			return;
		}
		var request = database.transaction("groups").objectStore("groups").getAll();
		request.onsuccess = function(_:Dynamic):Void {
			var groups:Array<Dynamic> = request.result;
			var total:Float = 0;
			for (group in groups) total += group.bytes;
			groups.sort(function(a, b) return a.lastAccess < b.lastAccess ? -1 : a.lastAccess > b.lastAccess ? 1 : 0);
			var target = emergency ? SOFT_LIMIT_BYTES * 0.75 : SOFT_LIMIT_BYTES;
			var remove:Array<String> = [];
			for (group in groups) {
				if (total <= target) break;
				if (group.id == activeGroup) continue;
				remove.push(group.id);
				total -= group.bytes;
			}
			if (remove.length == 0) {
				if (complete != null) complete();
				return;
			}
			var tx = database.transaction(["groups", "tiles"], READWRITE);
			for (groupId in remove) {
				tx.objectStore("groups").delete(groupId);
				deleteTilesForGroup(tx.objectStore("tiles"), groupId);
			}
			if (complete != null) tx.oncomplete = function(_:Dynamic):Void complete();
		};
		request.onerror = function(_:Dynamic):Void if (complete != null) complete();
	}

	private function deleteTilesForGroup(tiles:js.html.idb.ObjectStore, groupKey:String):Void {
		var request = tiles.index("group").openCursor(js.html.idb.KeyRange.only(groupKey));
		request.onsuccess = function(_:Dynamic):Void {
			var cursor:js.html.idb.CursorWithValue = request.result;
			if (cursor == null) return;
			cursor.delete();
			cursor.continue_();
		};
	}

	public function dispose():Void {
		disposed = true;
		pending = [];
		if (database != null) database.close();
		database = null;
	}

	private function whenReady(operation:Void->Void):Void {
		if (disposed || failed) {
			operation();
			return;
		}
		if (database != null) operation() else pending.push(operation);
	}

	private function drainPending():Void {
		var operations = pending;
		pending = [];
		for (operation in operations) operation();
	}

	private function fail():Void {
		failed = true;
		drainPending();
	}

	private static inline function recordId(groupKey:String, tileKey:String):String return groupKey + ":" + tileKey;
	private static inline function now():Float return Date.now().getTime();
}
#end
