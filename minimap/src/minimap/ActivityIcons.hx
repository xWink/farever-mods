package minimap;

import minimap.GameAccess as G;

/** Scalable counterparts of the game's white-bordered activity diamonds. */
class ActivityIcons {
    public static function draw(g:Dynamic, kind:String, r:Float):Void {
        var color = switch kind {
            case "quest": 0x439b27;
            case "orbRace": 0x0754ef;
            case "battle": 0xb52b28;
            case "orbChest": 0xbc7537;
            default: 0xf57821;
        };
        polygon(g, r, 0x493b34, [0,-1.28,1.28,0,0,1.28,-1.28,0]);
        polygon(g, r, 0xfffcf5, [0,-1.22,1.22,0,0,1.22,-1.22,0]);
        polygon(g, r, color, [0,-0.98,0.98,0,0,0.98,-0.98,0]);
        polygon(g, r, switch kind {
            case "quest": 0x68bf36;
            case "orbRace": 0x148eff;
            case "battle": 0xda4540;
            case "orbChest": 0xd99c59;
            default: 0xff953c;
        }, [0,-0.98,0.98,0,0,0.12,-0.98,0]);
        switch kind {
            case "boss":
                circle(g,r,0xfffcf5,0,-0.16,0.42);
                polygon(g,r,0xfffcf5,[-0.28,0,0.28,0,0.22,0.38,-0.22,0.38]);
                for (x in [-0.17,0.17]) circle(g,r,color,x,-0.16,0.105);
                polygon(g,r,color,[0,0.04,0.07,0.17,-0.07,0.17]);
                for (x in [-0.09,0.09]) polygon(g,r,color,[x-0.025,0.26,x+0.025,0.26,x+0.025,0.39,x-0.025,0.39]);
            case "quest":
                polygon(g,r,0xfffcf5,[-0.12,-0.58,0.12,-0.58,0.09,0.18,-0.09,0.18]);
                circle(g,r,0xfffcf5,0,0.39,0.115);
            case "orbRace":
                circle(g,r,0x0630b1,0,0,0.57);
                circle(g,r,0xf5ffff,0,0,0.45);
                circle(g,r,0x199fff,0,0,0.32);
                circle(g,r,0x67dfff,-0.06,-0.06,0.22);
                circle(g,r,0xd5ffff,-0.12,-0.13,0.09);
            case "battle":
                for (side in [-1,1]) {
                    polygon(g,r,0xfffcf5,[-0.48,0.37,-0.36,0.49,0.48,-0.35,0.5,-0.52,0.32,-0.5],side);
                    polygon(g,r,0xfffcf5,[-0.5,0.1,-0.1,0.5,-0.2,0.6,-0.6,0.2],side);
                }
            case "orbChest", "ambushChest":
                polygon(g,r,0xfffcf5,[-0.49,-0.12,-0.38,-0.34,0.38,-0.34,0.49,-0.12,0.44,0.4,-0.44,0.4]);
                polygon(g,r,color,[-0.35,-0.14,0.35,-0.14,0.35,-0.04,-0.35,-0.04]);
                if (kind == "orbChest") {
                    circle(g,r,color,0,0.13,0.19);
                    circle(g,r,0xfffcf5,0,0.13,0.1);
                    for (side in [-1,1]) polygon(g,r,0xfffcf5,[0.58,-0.1,0.69,0,0.58,0.1,0.48,0],side);
                } else {
                    polygon(g,r,color,[-0.065,-0.02,0.065,-0.02,0.05,0.18,-0.05,0.18]);
                    circle(g,r,color,0,0.29,0.06);
                    polygon(g,r,0xfffcf5,[-0.23,-0.49,0,-0.7,0.23,-0.49]);
                }
            default:
        }
    }

    static function circle(g:Dynamic,r:Float,color:Int,x:Float,y:Float,radius:Float):Void {
        G.call("h2d.Graphics","beginFill",g,[color,1.]);
        G.call("h2d.Graphics","drawCircle",g,[x*r,y*r,radius*r,32]);
        G.call("h2d.Graphics","endFill",g);
    }

    static function polygon(g:Dynamic,r:Float,color:Int,xy:Array<Float>,side:Float=1):Void {
        G.call("h2d.Graphics","beginFill",g,[color,1.]);
        G.call("h2d.Graphics","moveTo",g,[xy[0]*r*side,xy[1]*r]);
        for (i in 1...Std.int(xy.length/2))
            G.call("h2d.Graphics","lineTo",g,[xy[i*2]*r*side,xy[i*2+1]*r]);
        G.call("h2d.Graphics","lineTo",g,[xy[0]*r*side,xy[1]*r]);
        G.call("h2d.Graphics","endFill",g);
    }
}
