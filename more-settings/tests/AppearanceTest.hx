import moresettings.AppearanceDraft;
import moresettings.AppearanceCamera;
import moresettings.AppearancePortraits;
import moresettings.AppearanceUi;
import moresettings.AppearanceSwatches;
import moresettings.AppearanceWindow;
import moresettings.GameAccess as G;

@:access(moresettings.AppearanceWindow)
class AppearanceTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, message:String):Void {
        checks++;
        if (a != b) throw message + ': expected $b, got $a';
    }
    static function rejects(action:Void->Void, message:String):Void {
        var failed = false;
        try action() catch (_:Dynamic) failed = true;
        eq(failed, true, message);
    }
    static function hero():Dynamic return {
        ownerPlayer: {isMe: true}, layer: {}, removed: false, unitView: {}, model: 1,
        skinData: {template: 1, skinColor: "Skin1", hair: "Hair1", hairColor: "Red", hairColorSecondary: "Gold",
            shapes: [{name: "BS_Nose1", val: 1.0}, {name: "BS_Face1", val: 0.0}]}
    };

    static function main():Void {
        var h = hero(), original:Dynamic = h.skinData;
        var d = new AppearanceDraft(h);
        eq(d.skin != original, true, "The editor gets a private skin object");
        eq(d.skin.shapes != original.shapes, true, "Shape arrays are private");
        eq(d.skin.shapes[0] != original.shapes[0], true, "Nested shape records are private");
        d.skin.template = 2; d.skin.hair = "Hair2"; d.skin.shapes[0].val = 0.5;
        eq(h.skinData.template, 1, "Body edits cannot change the live character");
        eq(h.skinData.hair, "Hair1", "Part edits cannot change the live character");
        eq(h.skinData.shapes[0].val, 1.0, "Shape edits cannot change the live character");
        eq(G.writes, 0, "Preview does not dirty replicated state");
        eq(G.bodyWrites, 0, "Preview does not change the live model index");
        d = null; // Cancel/close only discards the draft; there is no rollback setter.
        eq(h.skinData == original, true, "Cancel keeps the exact original object");
        eq(new AppearanceDraft(h).skin.hair, "Hair1", "Reopen reads saved appearance");

        d = new AppearanceDraft(h); d.skin.hair = "Hair2"; d.skin.template = 2;
        G.failCopy = true;
        rejects(() -> d.commit(h), "Preparation failure is not a partial save");
        eq(h.skinData == original, true, "Failed preparation leaves original intact");
        eq(d.committed, false, "Failed save can be retried");
        G.failCopy = false; G.ignoreWrite = true;
        rejects(() -> d.commit(h), "A rejected native setter cannot report success");
        eq(d.committed, false, "Rejected setter leaves draft open");
        G.ignoreWrite = false; d.commit(h);
        eq(G.writes, 1, "Save uses the native replicated property exactly once");
        eq(h.skinData.hair, "Hair2", "Save applies the draft");
        eq(h.skinData.hairColorSecondary, "Gold", "Untouched secondary hair color is preserved");
        eq(h.skinData != d.skin, true, "Saved state is detached from the preview");
        AppearanceDraft.refreshHero(h);
        eq(h.skin, 2, "Apply the saved body through the native model setter");
        eq(G.bodyWrites, 1, "Body setter runs only after Save");
        eq(G.refreshes, 1, "Save immediately refreshes visible customization");
        eq(G.skinDisplays, 0, "Changed body is rebuilt only by the native setter");
        AppearanceDraft.refreshHero(h);
        eq(G.refreshes, 2, "Same-model edits also refresh; native updateSkin alone would skip them");
        eq(G.skinDisplays, 1, "Same-body edits follow the native skinData refresh path");
        d.skin.shapes[0].val = 0.2;
        eq(h.skinData.shapes[0].val, 1.0, "Late preview changes cannot mutate saved shapes");
        eq(d.valid(h), false, "A committed editor is closed");
        rejects(() -> d.commit(h), "Double activation cannot save twice");

        h = hero(); d = new AppearanceDraft(h);
        rejects(() -> d.commit(hero()), "Switching character cancels the session");
        h.layer = {}; eq(d.valid(h), false, "Changing worlds invalidates the draft");
        h = hero(); d = new AppearanceDraft(h); h.ownerPlayer = {isMe: true};
        eq(d.valid(h), false, "Replacing the player invalidates the draft");
        h = hero(); d = new AppearanceDraft(h); h.removed = true;
        rejects(() -> d.commit(h), "A removed hero cannot be updated");
        h = hero(); d = new AppearanceDraft(h); h.skinData.hair = "External";
        rejects(() -> d.commit(h), "Concurrent appearance edits cannot be overwritten");
        h = hero(); d = new AppearanceDraft(h); h.skinData.shapes[0].val = 0.25;
        rejects(() -> d.commit(h), "Concurrent nested shape edits are detected");
        h = hero(); d = new AppearanceDraft(h); h.skinData = AppearanceDraft.copy(h.skinData);
        rejects(() -> d.commit(h), "Replacing the skin invalidates an old draft");
        eq(G.writes, 1, "Rejected sessions perform no writes");
        rejects(() -> new AppearanceDraft(null), "Menu with no hero is handled");
        h = hero(); h.ownerPlayer.isMe = false;
        rejects(() -> new AppearanceDraft(h), "Another player's appearance is never editable");
        h = hero(); h.skinData.shapes = null; d = new AppearanceDraft(h); d.commit(h);
        eq(h.skinData.shapes, null, "Characters without explicit shapes can be saved");

        var parts:Array<Dynamic> = [{id: "Hair", type: 0, flags: 1}, {id: "NPC", type: 0, flags: 0},
            {id: "Brow", type: 2, flags: 3}, {id: "Beard", type: 3, flags: 1}];
        eq(AppearanceDraft.parts(parts, 0).length, 1, "NPC-only hair is excluded");
        eq(AppearanceDraft.parts(parts, 2)[0].id, "Brow", "Player flag accepts additional flags");
        eq(AppearanceDraft.parts(parts, 3)[0].id, "Beard", "Facial hair uses creation type");
        var colors:Array<Dynamic> = [{id: "Skin", bodyParts: 4, playerCustomization: true},
            {id: "HairEye", bodyParts: 3, playerCustomization: true},
            {id: "NPC", bodyParts: 7, playerCustomization: false}, {id: "Unset", bodyParts: 7}];
        eq(AppearanceDraft.colors(colors, 4).length, 1, "Only player-enabled skin gradients");
        eq(AppearanceDraft.colors(colors, 1)[0].id, "HairEye", "Hair color mask");
        eq(AppearanceDraft.colors(colors, 2)[0].id, "HairEye", "Eye color mask");

        var format:Dynamic = haxe.Json.parse(sys.io.File.getContent("configFormats.json"));
        var categories:Array<String> = [], action:Dynamic = null;
        for (entry in (cast format.configs:Array<Dynamic>)) {
            if (entry.type == "title") categories.push(entry.label);
            if (entry.key == "changeAppearance") action = entry;
        }
        eq(categories.slice(0, 4).join(","), "General,Combat,Nameplates,Social", "Custom Nameplates stay between Combat and Social after moving appearance into the character UI");
        eq(action, null, "Appearance editor is accessed through the native Barbershop button");

        // Go through the actual component factory, including the stub's XML
        // parser, so this fails if escaping is omitted or moved after creation.
        for (text in ["<", ">", "Save", "A & B", "<b>literal</b>", "[literal] $value"]) {
            var args:Array<Dynamic> = [text];
            var button = AppearanceUi.node("button", {}, args, "regressionArrow");
            eq(button.obj.text, text, "Formatted button renders literal text");
            eq(args[0], text, "Escaping does not alter the caller's arguments");
        }
        var error = "Could not parse < (haxe.xml.XmlParserException: Unexpected end at line 1 char 1)";
        var windows:Array<Dynamic> = [{}];
        AppearanceUi.message({windows: windows}, "Appearance <error>", error);
        eq(G.dialogTitle, "Appearance <error>", "Dialog title is literal");
        eq(G.dialogText, error, "The original parser error can be displayed without a second parse failure");
        eq(G.dialogButton.text, "OK", "Error dialog can finish construction");
        eq(windows.length, 1, "Dialog descriptors do not mutate the native window list");

        var texture:Dynamic = {filter: "Linear", disposed: false};
        var atlasTile:Dynamic = {innerTex: texture, x: 96.0, y: 64.0, width: 16.0, height: 8.0};
        var gradient:Dynamic = {id: "Skin1", ref: {tile: atlasTile}};
        var swatch:Dynamic = {};
        AppearanceSwatches.paint(swatch, gradient, false);
        var bitmap:Dynamic = G.swatchBitmaps[0];
        eq(bitmap.parent, swatch, "Color drawable belongs to its button");
        eq(bitmap.tile != atlasTile, true, "Use a private sub-tile descriptor");
        eq(bitmap.tile.innerTex, texture, "Sample the existing atlas without allocating a texture");
        eq(bitmap.tile.x, 96.0, "Sample the first gradient pixel at its atlas X offset");
        eq(bitmap.tile.y, 64.0, "Sample the first gradient pixel at its atlas Y offset");
        eq(bitmap.tile.width, 1.0, "Swatch uses one texel, matching native colors");
        eq(bitmap.tile.height, 1.0, "One texel vertically");
        eq(bitmap.width, 26.0, "Enlarge the sample inside the button border");
        eq(bitmap.height, 26.0, "Square swatch");
        eq(bitmap.smooth, false, "Disable interpolation on the drawable only");
        eq(bitmap.flowProperties.isAbsolute, true, "Swatch cannot change button layout");
        eq(G.swatchBorders.length, 0, "Unselected colors have no selection frame");
        AppearanceSwatches.paint(swatch, gradient, true);
        eq(G.swatchBorders.length, 1, "Selected color gets a visible frame");
        eq(G.swatchBorders[0].parent, swatch, "Frame belongs to the same button");
        eq(texture.filter, "Linear", "Shared atlas filtering is preserved");
        eq(texture.disposed, false, "Shared texture is not disposed");
        eq(atlasTile.width, 16.0, "Shared atlas region is unchanged");
        rejects(() -> AppearanceSwatches.paint(swatch, {ref: {tile: null}}, false), "Missing color texture fails before drawing");
        var emptyTile:Dynamic = {width: 0.0, height: 1.0};
        rejects(() -> AppearanceSwatches.paint(swatch, {ref: {tile: emptyTile}}, false), "Empty texture cannot reach the renderer");
        // The native preview's clip range was valid for its full-body distance.
        // Close-ups must preserve that distance and use projection zoom instead.
        var camera:Dynamic = {pos: {x: 0.0, y: -10.0, z: 1.0}, target: {x: 0.0, y: 0.0, z: 1.0},
            zoom: 1.2, zNear: 8.0, zFar: 100.0};
        var preview:Dynamic = {needFit: 2, preAnimBounds: {zMin: 0.0, zMax: 2.0},
            unitScene: {s3d: {camera: camera}}, unitView: {head: {matrix: {_43: 180.0}}}};
        var zoom = new AppearanceCamera();
        zoom.update(preview, true);
        eq(camera.pos.y, -10.0, "Wait for native fitting before zooming");
        eq(camera.zoom, 1.2, "Loading leaves native projection intact");
        preview.needFit = -1; zoom.update(preview, true);
        eq(camera.pos.y, -10.0, "Face/Hair keep the camera outside the near plane");
        eq(camera.target.z, 1.76, "Focus uses fitted body dimensions, not mismatched joint coordinates");
        eq(camera.pos.z - camera.target.z, 0.0, "Shift the camera and target together");
        eq(Math.abs(camera.zoom - 1.2 / 0.38) < 0.0001, true, "Optical zoom magnifies Face/Hair");
        eq(camera.zNear, 8.0, "Close-up preserves the native near plane");
        eq(camera.zFar, 100.0, "Close-up preserves the native far plane");
        for (i in 0...20) zoom.update(preview, true);
        eq(Math.abs(camera.zoom - 1.2 / 0.38) < 0.0001, true, "Zoom never compounds across frames");
        zoom.update(preview, false);
        eq(camera.pos.y, -10.0, "Body restores original distance");
        eq(camera.target.z, 1.0, "Body restores original target");
        eq(camera.pos.z, 1.0, "Body restores original camera height");
        eq(camera.zoom, 1.2, "Body restores original magnification");
        zoom.update(preview, true);
        zoom.invalidate(); preview.needFit = 1; zoom.update(preview, true);
        eq(camera.zoom, 1.2, "Reset close-up magnification before a native refit");
        camera.pos.y = -20.0; camera.pos.z = 3.0; camera.target.z = 3.0;
        preview.preAnimBounds = {zMin: 0.0, zMax: 6.0};
        preview.needFit = -1; zoom.update(preview, true);
        eq(camera.pos.y, -20.0, "A model refit replaces the distance baseline");
        eq(Math.abs(camera.target.z - 5.28) < 0.0001, true, "Larger bodies use their own fitted height");
        eq(Math.abs(camera.zoom - 1.2 / 0.38) < 0.0001, true, "Refitting cannot multiply previous zoom");
        zoom.update(preview, false);
        eq(camera.pos.z, 3.0, "Return to the new body baseline after a refit");
        eq(camera.zoom, 1.2, "Refitted Body still has its original magnification");

        var source:Dynamic = {template: 1, hair: "Hair1", facialHair: "Beard1", shapes: null};
        var sourceSignature = haxe.Json.stringify(source);
        var previousScene:Dynamic = {disposed: false}, previousPrefab:Dynamic = {};
        G.portraitScene = previousScene; G.portraitPrefab = previousPrefab;
        var portraits = new AppearancePortraits({windows: []}, source, {});
        var renderView = G.portraitViews[0];
        eq(renderView.skin != source, true, "Thumbnails have a second private skin");
        portraits.add({}, "blend-shape-pick-button", {category: "Face", name: null}, 0, 0, 92, true, () -> true, () -> {});
        portraits.add({}, "body-part-pick-button", {type: 0, id: "Hair2"}, 0, 0, 92, false, () -> true, () -> {});
        renderView.ready = false; portraits.update(source);
        eq(G.portraitInputs.length, 0, "Wait for thumbnail renderer readiness");
        renderView.ready = true; portraits.update(source);
        eq(G.portraitInputs.length, 1, "Render at most one thumbnail each frame");
        eq(G.portraitInputs[0].hair, null, "Hide hair so face details remain visible");
        eq(G.portraitInputs[0].facialHair, null, "Hide beard on face shape thumbnails");
        eq(G.array(G.portraitInputs[0].shapes).length, 0, "Default shape has an empty array");
        portraits.update(source);
        eq(G.portraitInputs[1].hair, "Hair1", "Reset temporary skin changes before the next thumbnail");
        eq(G.array(G.portraitInputs[1].shapes).length, 0, "Reset temporary shape changes too");
        eq(haxe.Json.stringify(source), sourceSignature, "Thumbnail generation never changes the draft");
        eq(G.portraitScene, previousScene, "Restore the game's portrait scene");
        eq(G.portraitPrefab, previousPrefab, "Restore the game's portrait prefab");
        eq(previousScene.disposed, false, "Never dispose an existing game portrait scene");
        eq(renderView.parent, null, "Detach private view before disposing the temporary scene");
        eq(G.portraitButtons[0].icon.width, 84.0, "Thumbnail fits inside its frame");
        // A hover restyles the DOM bitmap. This reproduces the old 84->64
        // shrink unless dimensions are registered with DOMKit as inline styles.
        for (i in 0...3) {
            G.reflowPortrait(G.portraitButtons[0]);
            eq(G.portraitButtons[0].icon.width, 84.0, "Hover/selection preserve thumbnail width");
            eq(G.portraitButtons[0].icon.height, 84.0, "Hover/selection preserve thumbnail height");
            eq(G.portraitButtons[0].icon.x, 0.0, "Hover preserves thumbnail X position");
            eq(G.portraitButtons[0].icon.y, 0.0, "Hover preserves thumbnail Y position");
        }
        var texture = G.portraitButtons[0].tex;
        portraits.prepare(source, {});
        eq(texture.disposed, true, "Rebuilding pages disposes owned thumbnail textures");
        eq(texture.realloc, null, "Disposed thumbnails release native reallocation closures");
        eq(G.portraitButtons[0].icon.tile, null, "Retired drawables cannot reference freed GPU textures");
        eq(G.portraitButtons[0].icon.visible, false, "Retired thumbnails cannot be drawn");
        portraits.update(source);
        eq(G.portraitInputs.length, 2, "Old pages have no pending renders after rebuild");
        portraits.add({}, "template-pick-button", 1, 0, 0, 122, true, () -> true, () -> {});
        G.reflowPortrait(G.portraitButtons[2]);
        eq(G.portraitButtons[2].icon.width, 114.0, "First body preview has fixed width before initial layout/capture");
        eq(G.portraitButtons[2].icon.height, 114.0, "Initial layout preserves body preview height");
        G.failPortrait = true;
        rejects(() -> portraits.update(source), "Capture errors propagate after cleanup");
        eq(G.portraitScene, previousScene, "Restore global scene after a capture error");
        eq(G.portraitPrefab, previousPrefab, "Restore global prefab after a capture error");
        eq(renderView.parent, null, "Failed capture also detaches the view");
        eq(haxe.Json.stringify(source), sourceSignature, "Failed capture cannot mutate the draft");
        portraits.dispose();
        eq(G.portraitButtons[2].tex, null, "Closing releases the last thumbnail");
        G.failPortrait = false;
        // Paging hair must preserve both already-rendered and still-pending
        // thumbnails in the beard/eyes rows. Rapid paging drops stale work only
        // in the changed row, without resetting the shared private renderer.
        var paged = new AppearancePortraits({windows: []}, source, {});
        var hairRow:Dynamic = {}, beardRow:Dynamic = {}, eyeRow:Dynamic = {};
        var add = (row:Dynamic, id:String, type:Int) -> {
            paged.add(row, "body-part-pick-button", {id: id, type: type}, 0, 0, 92, false, () -> true, () -> {});
            return G.portraitButtons[G.portraitButtons.length - 1];
        };
        var renderStart = G.portraitRenders.length;
        var setupCount = G.portraitSetups;
        var beard = add(beardRow, "Beard1", 3), oldHair = add(hairRow, "Hair1", 0), eyes = add(eyeRow, "Eyes1", 2);
        var beardTexture = beard.tex, oldHairTexture = oldHair.tex, eyeTexture = eyes.tex;
        paged.update(source);
        eq(G.portraitRenders[renderStart], beard, "First row is already rendered before paging another");
        paged.clear(hairRow);
        eq(oldHairTexture.disposed, true, "Paging disposes only the old hair thumbnail");
        eq(oldHairTexture.realloc, null, "Retired page releases its reallocation callback");
        eq(beard.tex, beardTexture, "An unchanged row keeps the same texture");
        eq(beardTexture.disposed, false, "Already-rendered beard texture stays alive");
        eq(eyeTexture.disposed, false, "Pending thumbnails in other groups stay alive");
        var nextHair = add(hairRow, "Hair2", 0);
        paged.update(source); paged.update(source);
        eq(G.portraitRenders[renderStart + 1], eyes, "Unchanged row keeps its pending capture");
        eq(G.portraitRenders[renderStart + 2], nextHair, "Only the replacement hair page is newly queued");
        eq(G.portraitRenders.indexOf(oldHair), -1, "Retired page can never render later");
        eq(G.portraitRenders.length, renderStart + 3, "Rendered sibling rows are not queued again");
        eq(G.portraitSetups, setupCount, "Pagination does not rebuild the private UnitView");
        paged.clear(hairRow);
        var skipped = add(hairRow, "Hair3", 0), skippedTexture = skipped.tex;
        paged.clear(hairRow);
        var latest = add(hairRow, "Hair4", 0);
        paged.update(source); paged.update(source);
        eq(skippedTexture.disposed, true, "Rapid paging disposes skipped options");
        eq(G.portraitRenders.indexOf(skipped), -1, "Rapid paging cancels skipped captures");
        eq(G.portraitRenders[renderStart + 3], latest, "Rapid paging renders the latest page");
        eq(G.portraitRenders.length, renderStart + 4, "Other rows remain rendered just once");
        eq(haxe.Json.stringify(source), sourceSignature, "Page browsing leaves the appearance draft unchanged");
        paged.prepare(source, {});
        eq(beardTexture.disposed, true, "Full draft/tab rebuild still retires all groups");
        eq(eyeTexture.disposed, true, "Full rebuild also retires retained eye thumbnails");
        paged.dispose();

        // Exercise the actual window callbacks and update boundary. Native UI
        // traversal can still hold button/preview references after onClick.
        var makeWindow = (hero:Dynamic) -> {
            var window = new AppearanceWindow();
            window.ui = {};
            window.window = {parent: {}, allocated: true, visible: true};
            window.container = {parent: {}};
            window.body = {obj: {optionsList: {container: window.container}}};
            window.draft = new AppearanceDraft(hero);
            window.ready = true;
            window.portraits = new AppearancePortraits({windows: []}, window.draft.skin, {});
            window.portraits.add({}, "template-pick-button", 1, 0, 0, 122, true, () -> true, () -> {});
            return window;
        };
        h = hero(); var window = makeWindow(h);
        var savedDraft = window.draft;
        savedDraft.skin.hair = "Hair2";
        var nativeWindow = window.window;
        var thumbnail = G.portraitButtons[G.portraitButtons.length - 1];
        var thumbnailTexture = thumbnail.tex;
        var initialWrites = G.writes, initialRefreshes = G.refreshes;
        G.lifecycle = [];
        window.save(); window.save();
        eq(G.writes, initialWrites, "Save callback never mutates replicated state during UI traversal");
        eq(thumbnailTexture.disposed, false, "Save callback leaves current-frame GPU resources alive");
        eq(nativeWindow.parent != null, true, "Save callback does not mutate the UI being traversed");
        eq(window.update(window.ui, h), false, "Queued save closes at the next update boundary");
        eq(G.writes, initialWrites + 1, "Repeated Save clicks produce one commit");
        eq(h.skinData.hair, "Hair2", "Deferred save still persists the selected appearance");
        eq(G.refreshes, initialRefreshes + 1, "Deferred save refreshes the live model once");
        eq(G.lifecycle.join(","), "window detached,texture disposed,skin refreshed", "Detach, release, then refresh in order");
        eq(savedDraft.committed, true, "Save marks its draft committed");
        window.dispose();
        eq(G.lifecycle.length, 3, "Editor cleanup after Save is idempotent");

        h = hero(); window = makeWindow(h); initialWrites = G.writes;
        window.save(); window.requestClose();
        eq(window.update(window.ui, h), false, "Cancel wins over a queued Save");
        window.dispose(); eq(G.writes, initialWrites, "Cancel cannot commit a queued appearance");
        h = hero(); window = makeWindow(h); window.save(); h.layer = {};
        eq(window.update(window.ui, h), false, "Changing worlds cancels a queued save");
        window.dispose(); eq(G.writes, initialWrites, "Queued save revalidates the character before writing");

        h = hero(); window = makeWindow(h); window.save(); G.failCopy = true;
        eq(window.update(window.ui, h), true, "Commit failure keeps the editor open for retry");
        G.failCopy = false;
        eq(window.window.visible, true, "Commit failure does not tear down the preview");
        window.save(); eq(window.update(window.ui, h), false, "Retry succeeds after a failed deferred save");
        window.dispose();
        Sys.println('Appearance tests passed ($checks checks)');
    }
}
