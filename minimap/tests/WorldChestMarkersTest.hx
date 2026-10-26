import minimap.MinimapMarkers;
import minimap.GameAccess as G;

@:access(BigMapTest)
@:access(minimap.MinimapMarkers)
class WorldChestMarkersTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, label:String):Void {
        checks++;
        if (actual != expected) throw label + ': expected $expected, got $actual';
    }
    static function definition(id:String):Dynamic {
        var def = BigMapTest.definition(id, 9000., 7000., 5., 2);
        def.inf.states = [{state:'None', flags:0}, {state:'Opened', flags:8},
            {state:'Hidden', flags:32}, {state:'Disabled', flags:1}, {state:'Locked', flags:2}];
        def.inf.zoneBaked = 'known';
        return def;
    }
    static function main():Void {
        var chest = definition('chest'), recipe = definition('recipe'), vault = definition('vault');
        recipe.inf.inherit = 'Recipe_Chest_Root'; vault.inf.inherit = 'VaultChest';
        var hidden = definition('hidden'); hidden.inf.props.interactible = {hidden:true};
        var disabled = definition('disabled'); disabled.inf.props.enabled = false;
        var unreleased = definition('unreleased'); unreleased.inf.props.releaseStatus = 0;
        var otherMap = definition('other'); otherMap.mapId = 'World/Other';
        var decoration = definition('decoration'); decoration.inf.type = 1;
        var activity = definition('activity'); activity.prefab.parent = {parent:{type:'object',cdbType:'activity'}};
        var heroic = definition('heroic'); heroic.inf.props.heroic = true;
        var respawn = definition('respawn'); respawn.inf.props.resetTimer = 1;
        var event = definition('event'); event.inf.props.event = 'Festival';
        var invisible = definition('invisible'); invisible.inf.states = [{state:'None',flags:32}];
        var personal = definition('personal'); personal.inf.props.flags = 2;
        G.globals['HElement.allElements'] = new Map<String,Dynamic>();
        G.globals['elements'] = [chest, recipe, vault, hidden, disabled, unreleased, otherMap,
            decoration, activity, heroic, respawn, event, invisible, personal];
        var states:Map<String,Dynamic> = ['respawn'=>{completed:100.}];
        var personalStates:Map<String,Dynamic> = ['personal'=>'Opened'];
        var progress:Dynamic = {chests:states};
        var player:Dynamic = {progress:progress,playerContext:{elements:personalStates}};
        var layer:Dynamic = {units:[],interactibles:[],time:{serverNow:200.},
            worldEvents:{disabled:'event'},world:{level:'World/W1_Siagarta'}};
        var hero:Dynamic = {player:player,layer:layer,posx:0.,posy:0.,posz:5.,rotationZ:0.};
        var markers = new MinimapMarkers({}, {}, {}, 'World/W1_Siagarta');
        var settings = BigMapTest.config();
        var radius = 20000.;
        var rifts = new minimap.RiftMarkers('World/W1_Siagarta');
        function sample():String {
            markers.nextRefresh = 0;
            markers.update(hero, settings, 0, 0, radius, 1, 0, rifts);
            eq(markers.healthy, true, 'Collector stays healthy');
            var ids = [for (p in markers.points) G.text(G.field(p.inf == null ? G.field(p.entity,'inf') : p.inf,'id'))];
            ids.sort(Reflect.compare); return ids.join(',');
        }
        eq(sample(), 'chest,recipe,vault', 'Distant world chests appear without entities; unavailable rewards do not');
        var kinds = [for (p in markers.points) p.kind]; kinds.sort(Reflect.compare);
        eq(kinds.join(','), 'chest,recipeChest,vaultChest', 'World chests retain native families');
        var reads = G.prefabReads, scans = G.elementScans;
        eq(sample(), 'chest,recipe,vault', 'Stable refresh');
        eq(G.prefabReads, reads, 'No repeated prefab transforms');
        eq(G.elementScans, scans, 'No repeated definition scans');
        states['chest'] = {completed:100.};
        eq(sample(), 'recipe,vault', 'Opening a chest removes its marker');
        layer.time.serverNow = Math.NaN;
        eq(sample(), 'recipe,vault', 'Unknown server time does not invent a respawn');
        layer.time.serverNow = 25299.;
        eq(sample(), 'recipe,vault', 'Respawn is hidden just before seven-hour boundary');
        layer.time.serverNow = 25300.;
        eq(sample(), 'recipe,respawn,vault', 'Respawning chest reappears at native seven-hour boundary');
        personalStates['personal'] = 'Hidden';
        eq(sample(), 'recipe,respawn,vault', 'Personal hidden state suppresses marker');
        personalStates['personal'] = 'Disabled';
        eq(sample(), 'recipe,respawn,vault', 'Personal disabled state suppresses marker');
        personalStates['personal'] = 'Locked';
        eq(sample(), 'personal,recipe,respawn,vault', 'Locked chests still have a location marker');
        states['personal'] = {completed:100.};
        eq(sample(), 'personal,recipe,respawn,vault', 'Explicit personal context takes precedence over permanent progress');
        personalStates.remove('personal');
        eq(sample(), 'recipe,respawn,vault', 'Completion resumes when personal context ends');
        layer.worldEvents.disabled = null;
        eq(sample(), 'event,recipe,respawn,vault', 'Event chest appears when enabled');
        layer.config = {difficulty:2};
        eq(sample(), 'event,heroic,recipe,respawn,vault', 'Heroic-only chest matches current difficulty');
        layer.config = null;
        layer.worldEvents = null;
        eq(sample(), 'recipe,respawn,vault', 'Missing event state does not advertise event chest');
        radius = 100.;
        eq(sample(), '', 'Minimap still clips to visible distance');
        radius = 20000.; progress.lockedZone = 'known';
        eq(sample(), '', 'Map discovery remains authoritative');
        progress.lockedZone = null;
        settings = BigMapTest.change(settings,'showChests',false);
        eq(sample(), '', 'Chest filter hides all distant chests');
        settings = BigMapTest.change(settings,'showChests',true);
        var live:Dynamic = {family:'chest',kind:'vault',inf:vault.inf,enabled:true,
            state:0,posx:100.,posy:200.,posz:5.};
        layer.interactibles = [live];
        eq(sample(), 'recipe,respawn,vault', 'Live chest replaces definition without duplicate');
        var point = markers.points.filter(p -> p.entity == live)[0];
        eq(point.x,100.,'Live chest uses actual position');
        live.state = 8;
        eq(sample(), 'recipe,respawn', 'Live opened state overrides cached definition');
        live.state = 0; live.enabled = false;
        eq(sample(), 'recipe,respawn', 'Live disabled state overrides cached definition');
        live.enabled = true; live.hidden = true;
        eq(sample(), 'recipe,respawn', 'Live hidden state overrides cached definition');
        live.hidden = false; live.posx = 90000.;
        eq(sample(), 'recipe,respawn', 'Live position outside view suppresses old prefab position');
        layer.interactibles = [];
        player.progress = {chests:new Map<String,Dynamic>()};
        eq(sample(), 'chest,personal,recipe,respawn,vault', 'Completion is resampled after character change');
        player.progress = null;
        eq(sample(), '', 'No speculative unopened markers before progress is loaded');
        player.progress = progress;
        // An already-spawned prefab can be cleared from HElement before indexing.
        var observed = definition('observed'); observed.prefab = null;
        var seen:Dynamic = {family:'chest',kind:'observed',inf:observed.inf,enabled:true,
            state:0,posx:100.,posy:200.,posz:5.};
        layer.interactibles = [seen];
        eq(sample(), 'observed,recipe,respawn,vault', 'Already-loaded chest still renders');
        var reward:Dynamic = {family:'chest',kind:'activity',inf:activity.inf,enabled:true,
            state:0,posx:110.,posy:200.,posz:5.,activity:{}};
        layer.interactibles = [seen,reward];
        eq(sample(), 'observed,recipe,respawn,vault', 'Live activity rewards are excluded from chest markers');
        reward.activity = null;
        eq(sample(), 'observed,recipe,respawn,vault', 'Prefab activity ownership also excludes a loaded reward');
        layer.interactibles = [];
        eq(sample(), 'observed,recipe,respawn,vault', 'Observed world chest remains after streaming out');
        states['observed'] = {completed:100.};
        eq(sample(), 'recipe,respawn,vault', 'Observed chest also respects completion');
        // A chest can arrive without its prefab ancestry and only reveal its
        // activity ownership through the live native State hierarchy.
        var ancient = definition('ancient'); ancient.inf.texts = {name:'Ancient Chest'};
        var camp = definition('camp'); camp.inf.texts = {name:'Camp Chest'};
        G.globals['elements'] = [ancient,camp]; G.globals['HElement.allElements'] = new Map<String,Dynamic>();
        eq(sample(), 'ancient,camp', 'Unknown activity association can initially be indexed');
        var ancientLive:Dynamic = {family:'chest',kind:'ancient',inf:ancient.inf,enabled:true,
            state:16,posx:100.,posy:200.,posz:5.,activity:{kind:'AncientChestActivity'}};
        var campLive:Dynamic = {family:'chest',kind:'camp',inf:camp.inf,enabled:true,
            state:0,posx:120.,posy:200.,posz:5.,activity:{kind:'CampActivity'}};
        layer.interactibles = [ancientLive,campLive];
        eq(sample(), '', 'Ancient and camp activity rewards never count as chests, completed or unopened');
        layer.interactibles = [];
        eq(sample(), '', 'Activity rewards cannot return from the distant chest cache');
        // The activity itself continues to use the activity filters/completion.
        G.globals['HActivity.allActivities'] = new Map<String,Dynamic>();
        G.globals['activities'] = [{inf:{id:'CampActivity'},prefab:{},position:{x:120.,y:200.,z:5.}}];
        eq(sample(), 'CampActivity', 'The activity marker is retained without its reward chest');
        progress.completed = 'CampActivity';
        eq(sample(), '', 'Completed activity follows the existing hide-completed setting');
        settings = BigMapTest.change(settings,'hideCompletedActivities',false);
        eq(sample(), 'CampActivity', 'Show-completed activities does not restore their chest markers');
        settings = BigMapTest.change(settings,'hideCompletedActivities',true);
        G.globals['activities'] = []; G.globals['HActivity.allActivities'] = new Map<String,Dynamic>();
        // Classification follows native ownership, never an English display name.
        G.globals['elements'] = [ancient,camp]; G.globals['HElement.allElements'] = new Map<String,Dynamic>();
        eq(sample(), 'ancient,camp', 'A fresh world clears ownership exclusions; names alone are not a filter');
        states['ancient'] = {completed:100.}; states['camp'] = {completed:100.};
        eq(sample(), '', 'All ordinary world chests completed leaves no chest markers');
        G.globals['elements'] = []; G.globals['HElement.allElements'] = new Map<String,Dynamic>();
        eq(sample(), '', 'Changing world definitions discards old chest cache');
        Sys.println('World chest markers: $checks checks passed.');
    }
}
