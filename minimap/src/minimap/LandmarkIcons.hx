package minimap;

import minimap.GameAccess as G;

/** Local pixel geometry, retained by the marker pool across refreshes. */
class LandmarkIcons {
    public static inline var RIFT_ALERT_COLOR:Int = 0xc94a9f;
    public static inline var SPARKLING_COLOR:Int = 0xffdc42;

    public static function draw(graphics:Dynamic, kind:String, radius:Float):Void {
        if (kind == "obelisk") obelisk(graphics, radius);
        else if (kind == "dungeon") dungeon(graphics, radius);
        else if (kind == "soulstone") soulstone(graphics, radius);
        else if (kind == "secretOrb") secretOrb(graphics, radius);
        else if (kind == "targetDummy") targetDummy(graphics, radius);
        else if (kind == "riftPortal") riftPortal(graphics, radius);
        else if (kind == "upcomingRift") upcomingRift(graphics, radius);
        else if (kind == "nextRift") inactiveRift(graphics, radius, true);
        else if (kind == "inactiveRift") inactiveRift(graphics, radius);
        else if (kind == "glory") gloryToken(graphics, radius);
        else if (kind == "infusion") infusionCrucible(graphics, radius);
        else if (kind == "craft") craftingStation(graphics, radius);
        else if (kind == "upgrade") upgradeStation(graphics, radius);
        else if (kind == "recycler") recycling(graphics, radius);
    }

    static function recycling(g:Dynamic, r:Float):Void {
        // Folded ribbons with rounded returns, like the classic recycling loop.
        // Sample the curves into retained geometry; leave the centre transparent.
        var arrow = [-0.64, -0.43, -0.24, -0.2, 0.025, -0.66,
            0.19, -0.47, 0.04, -0.38, 0.47, -0.38, 0.75, -0.82,
            0.56, -0.7, 0.43, -0.91, 0.39, -0.97, 0.34, -1.01,
            0.28, -1.04, 0.22, -1.055, 0.16, -1.06, -0.22, -1.06,
            -0.28, -1.05, -0.34, -1.025, -0.395, -0.985,
            -0.445, -0.925, -0.48, -0.86];
        var fold = [-0.64, -0.43, -0.24, -0.2, 0.025, -0.66,
            -0.015, -0.735, -0.055, -0.8, -0.095, -0.85,
            -0.14, -0.89, -0.19, -0.915, -0.24, -0.92,
            -0.29, -0.91, -0.34, -0.885, -0.38, -0.845];
        G.call("h2d.Graphics", "lineStyle", g, [0.8, 0x203b34, 1.]);
        for (i in 0...3) {
            var angle = i * Math.PI * 2 / 3;
            var c = Math.cos(angle), s = Math.sin(angle);
            for (part in [arrow, fold]) {
                var coords:Array<Float> = [];
                for (j in 0...Std.int(part.length / 2)) {
                    var x = part[j * 2], y = part[j * 2 + 1];
                    coords.push(x * c - y * s);
                    coords.push(x * s + y * c);
                }
                fill(g, part == arrow ? 0x86eed4 : 0x58bfa8);
                polygon(g, r * 0.92, coords);
                end(g);
            }
        }
        G.call("h2d.Graphics", "lineStyle", g, [0., 0, 0.]);
    }

    static function craftingStation(g:Dynamic, r:Float):Void {
        // Boat-shaped workbench, hanging rune sign, scroll and cyan bottles.
        fill(g, 0x302524);
        polygon(g, r, [-0.96, 0.22, -0.65, 0.03, 0.69, 0.02, 0.99, 0.21,
            0.75, 0.67, 0.37, 0.84, -0.41, 0.84, -0.82, 0.65]);
        polygon(g, r, [0.25, -1, 0.44, -1, 0.61, 0.24, 0.38, 0.28]);
        polygon(g, r, [-0.94, -0.98, 0.53, -0.92, 0.53, -0.75, -0.94, -0.82]);
        polygon(g, r, [-0.76, -0.74, -0.04, -0.7, -0.06, -0.27, -0.38, -0.09, -0.73, -0.28]);
        polygon(g, r, [-0.65, 0.61, -0.48, 0.66, -0.56, 1, -0.72, 1]);
        polygon(g, r, [0.52, 0.6, 0.7, 0.58, 0.74, 0.98, 0.58, 0.98]);
        end(g);
        fill(g, 0x876047);
        polygon(g, r, [-0.85, -0.93, 0.48, -0.87, 0.48, -0.81, -0.85, -0.86]);
        polygon(g, r, [0.3, -0.94, 0.39, -0.94, 0.55, 0.27, 0.44, 0.29]);
        end(g);
        fill(g, 0xb57d3b);
        polygon(g, r, [-0.7, -0.67, -0.1, -0.63, -0.11, -0.31, -0.38, -0.17, -0.66, -0.31]);
        end(g);
        fill(g, 0xd1c3ef);
        polygon(g, r, [-0.42, -0.62, -0.24, -0.49, -0.48, -0.28, -0.57, -0.38,
            -0.33, -0.49, -0.45, -0.55, -0.52, -0.46, -0.6, -0.49]);
        end(g);
        fill(g, 0xb88244);
        polygon(g, r, [-0.92, 0.26, -0.66, 0.1, 0.66, 0.09, 0.93, 0.24,
            0.65, 0.49, -0.55, 0.6, -0.8, 0.49]);
        end(g);
        fill(g, 0x684435);
        polygon(g, r, [-0.77, 0.49, -0.5, 0.59, 0.66, 0.46, 0.86, 0.34,
            0.67, 0.62, 0.34, 0.75, -0.4, 0.75, -0.76, 0.59]);
        end(g);
        fill(g, 0x54352c);
        ellipse(g, r, -0.05, 0.28, 0.68, 0.16);
        end(g);
        fill(g, 0xbccab5);
        polygon(g, r, [0.4, -0.25, 0.52, -0.26, 0.56, -0.04, 0.43, -0.01]);
        end(g);
        fill(g, 0x62d7e8);
        circle(g, -0.17 * r, 0.08 * r, 0.17 * r);
        circle(g, 0.34 * r, 0.27 * r, 0.13 * r);
        polygon(g, r, [-0.22, -0.15, -0.11, -0.15, -0.11, 0.03, -0.22, 0.03]);
        polygon(g, r, [0.29, 0.06, 0.38, 0.06, 0.38, 0.22, 0.29, 0.22]);
        end(g);
        fill(g, 0xd5f9ef);
        circle(g, -0.22 * r, 0.02 * r, 0.07 * r);
        end(g);
        fill(g, 0xdfd2b6);
        polygon(g, r, [-0.58, 0.34, 0.06, 0.43, 0.03, 0.57, -0.62, 0.48]);
        end(g);
    }

    static function upgradeStation(g:Dynamic, r:Float):Void {
        // Grey arched forge with gold studs and a bright multicoloured plume.
        fill(g, 0x302b32);
        ellipse(g, r, 0, 0.8, 0.99, 0.22);
        var body = [-0.56, -0.37, 0.56, -0.37, 0.76, -0.06, 0.57, 0.35,
            0.51, 0.79, 0.25, 0.88, -0.43, 0.84, -0.57, 0.34, -0.76, -0.06];
        polygon(g, r + 1, body);
        polygon(g, r, [-0.23, -0.33, -0.26, -0.8, -0.09, -1.02, 0.04, -0.84,
            0.19, -1.05, 0.23, -0.73, 0.15, -0.33]);
        end(g);
        fill(g, 0xc08a46);
        ellipse(g, r, 0, 0.8, 0.93, 0.16);
        end(g);
        fill(g, 0x71828a);
        polygon(g, r, body);
        end(g);
        fill(g, 0x98a9aa);
        polygon(g, r, [-0.54, -0.29, -0.18, -0.32, -0.31, 0.03, -0.39, 0.7,
            -0.23, 0.8, -0.46, 0.75, -0.5, 0.28, -0.68, -0.04]);
        end(g);
        fill(g, 0x4f646f);
        polygon(g, r, [0.36, -0.26, 0.56, -0.31, 0.68, -0.04, 0.5, 0.3,
            0.45, 0.75, 0.22, 0.8, 0.32, 0.24]);
        end(g);
        fill(g, 0x27353c);
        ellipse(g, r, 0, -0.31, 0.48, 0.11);
        ellipse(g, r, 0, 0.25, 0.3, 0.41);
        end(g);
        fill(g, 0xf424ee);
        polygon(g, r, [-0.18, -0.34, -0.22, -0.76, -0.08, -0.95, 0.02, -0.76,
            0.14, -0.99, 0.17, -0.73, 0.11, -0.34]);
        ellipse(g, r, 0, 0.22, 0.24, 0.32);
        end(g);
        fill(g, 0x28fff2);
        polygon(g, r, [0.03, -0.34, 0.01, -0.63, 0.14, -0.99, 0.17, -0.73, 0.11, -0.34]);
        polygon(g, r, [0.12, -0.02, 0.24, 0.19, 0.14, 0.48, -0.04, 0.54,
            -0.17, 0.36, 0.05, 0.36, 0.15, 0.18]);
        end(g);
        fill(g, 0xffffc3);
        polygon(g, r, [-0.08, -0.34, -0.12, -0.69, -0.04, -0.88, 0.04, -0.71, 0.02, -0.34]);
        ellipse(g, r, -0.04, 0.14, 0.13, 0.2);
        end(g);
        fill(g, 0xbf7633);
        for (side in [-1, 1]) circle(g, side * 0.44 * r, -0.18 * r, 0.11 * r);
        polygon(g, r, [-0.23, 0.55, 0.24, 0.55, 0.24, 0.71, -0.23, 0.71]);
        end(g);
        fill(g, 0xffce71);
        for (side in [-1, 1]) circle(g, (side * 0.44 - 0.02) * r, -0.22 * r, 0.05 * r);
        end(g);
    }

    static function gloryToken(g:Dynamic, r:Float):Void {
        // Tilted copper token with a broad gold bevel and an embossed rune.
        var edge = [-0.57, -0.8, 0.57, -0.8, 0.76, -0.6, 0.76, 0.6,
            0.57, 0.8, -0.57, 0.8, -0.76, 0.6, -0.76, -0.6];
        fill(g, 0x513122);
        tokenPolygon(g, r + 1, edge);
        end(g);
        fill(g, 0xf5be68);
        tokenPolygon(g, r, edge);
        end(g);
        fill(g, 0xb96c36);
        tokenPolygon(g, r, [0.57, -0.8, 0.76, -0.6, 0.76, 0.6, 0.57, 0.8,
            -0.57, 0.8, -0.76, 0.6, -0.52, 0.54, 0.5, 0.54, 0.52, -0.59]);
        end(g);
        fill(g, 0x99532c);
        tokenPolygon(g, r * 0.8, edge);
        end(g);
        fill(g, 0xde9550);
        tokenPolygon(g, r * 0.69, edge);
        end(g);
        fill(g, 0xad632f);
        tokenPolygon(g, r, [-0.42, 0.35, -0.42, -0.22, -0.05, -0.22,
            0.35, 0.32, 0.15, 0.39, -0.12, -0.01, -0.23, -0.01, -0.23, 0.35]);
        tokenPolygon(g, r, [0.1, -0.43, 0.44, -0.43, 0.44, -0.23,
            0.28, -0.23, 0.28, -0.06, 0.1, -0.2]);
        end(g);
        fill(g, 0xffca76);
        tokenPolygon(g, r, [-0.44, 0.29, -0.44, -0.28, -0.08, -0.28,
            0.29, 0.25, 0.13, 0.25, -0.16, -0.12, -0.3, -0.12, -0.3, 0.29]);
        tokenPolygon(g, r, [0.07, -0.47, 0.41, -0.47, 0.41, -0.34,
            0.2, -0.34, 0.2, -0.15, 0.07, -0.24]);
        end(g);
    }

    static function tokenPolygon(g:Dynamic, r:Float, coords:Array<Float>):Void {
        var rotated:Array<Float> = [];
        var c = Math.cos(0.36), s = Math.sin(0.36);
        for (i in 0...Std.int(coords.length / 2)) {
            var x = coords[i * 2], y = coords[i * 2 + 1];
            rotated.push(x * c - y * s);
            rotated.push(x * s + y * c);
        }
        polygon(g, r, rotated);
    }

    static function infusionCrucible(g:Dynamic, r:Float):Void {
        // Wide stone basin, turquoise liquid, copper rim, and floating pink orb.
        var base = [-0.84, 0.05, -0.67, -0.04, 0.67, -0.04, 0.84, 0.05,
            0.78, 0.61, 0.96, 0.79, 0.59, 0.95, -0.59, 0.95, -0.96, 0.79, -0.78, 0.61];
        fill(g, 0x293f3d);
        polygon(g, r + 1, base);
        end(g);
        fill(g, 0x718980);
        polygon(g, r, base);
        end(g);
        fill(g, 0x9caf9f);
        polygon(g, r, [-0.8, 0.13, -0.53, 0.21, -0.4, 0.69, -0.6, 0.89, -0.78, 0.61]);
        polygon(g, r, [0.53, 0.21, 0.8, 0.13, 0.78, 0.61, 0.6, 0.89, 0.4, 0.69]);
        end(g);
        fill(g, 0x4e6862);
        polygon(g, r, [-0.5, 0.26, 0.5, 0.26, 0.39, 0.74, 0, 0.9, -0.39, 0.74]);
        end(g);
        fill(g, 0x7d432c);
        ellipse(g, r, 0, 0.11, 0.88, 0.34);
        polygon(g, r, [-0.13, 0.45, 0.13, 0.45, 0.2, 0.73, 0.1, 0.87,
            -0.1, 0.87, -0.2, 0.73]);
        end(g);
        fill(g, 0xffb65e);
        ellipse(g, r, 0, 0.06, 0.83, 0.29);
        polygon(g, r, [-0.1, 0.47, -0.06, 0.72, 0.06, 0.72, 0.1, 0.47,
            0.16, 0.72, 0.06, 0.81, -0.06, 0.81, -0.16, 0.72]);
        end(g);
        fill(g, 0x18c6c2);
        ellipse(g, r, 0, 0.06, 0.66, 0.21);
        end(g);
        fill(g, 0x99fff0);
        polygon(g, r, [-0.51, 0.03, -0.28, -0.08, 0.18, -0.08, 0.37, -0.02,
            0.03, -0.02, -0.2, 0.06, -0.23, 0.15, -0.4, 0.12]);
        end(g);
        fill(g, 0x672467);
        circle(g, 0, -0.68 * r, 0.35 * r);
        end(g);
        fill(g, 0xf330f4);
        circle(g, 0, -0.69 * r, 0.29 * r);
        end(g);
        fill(g, 0xffb7ff);
        circle(g, -0.07 * r, -0.76 * r, 0.11 * r);
        end(g);
    }

    static function ellipse(g:Dynamic, r:Float, x:Float, y:Float, rx:Float, ry:Float):Void {
        var coords:Array<Float> = [];
        for (i in 0...20) {
            var angle = i * Math.PI / 10;
            coords.push(x + Math.cos(angle) * rx);
            coords.push(y + Math.sin(angle) * ry);
        }
        polygon(g, r, coords);
    }

    static function inactiveRift(g:Dynamic, r:Float, next:Bool = false):Void {
        // Next Rift reuses the closed fissure, with the energy ball's palette.
        var outline = next ? 0x32103f : 0x29272c;
        var body = next ? 0x9620ad : 0x929295;
        var highlight = next ? 0xcf169b : 0xc7c7ca;
        // Broad, tapered cracks remain readable at the default minimap scale.
        var branches:Array<Array<Float>> = [
            [-0.08, -0.3, -0.38, -0.43, -0.46, -0.65, -0.78, -0.59,
                -0.55, -0.46, -0.49, -0.25, -0.17, -0.12],
            [0.16, -0.3, 0.44, -0.4, 0.49, -0.66, 0.75, -0.59,
                0.62, -0.44, 0.59, -0.23, 0.27, -0.08],
            [0.14, 0.15, 0.48, 0.1, 0.66, -0.08, 0.92, 0.03,
                0.71, 0.12, 0.59, 0.27, 0.12, 0.31],
            [-0.12, 0.13, -0.44, 0.29, -0.71, 0.18, -0.62, 0.43,
                -0.78, 0.58, -0.5, 0.55, -0.32, 0.47, -0.17, 0.42],
            [0.12, 0.42, 0.34, 0.49, 0.38, 0.71, 0.65, 0.67,
                0.49, 0.55, 0.5, 0.35, 0.28, 0.27]
        ];
        fill(g, outline);
        for (branch in branches) polygon(g, r + 1, branch);
        end(g);
        fill(g, body);
        for (branch in branches) polygon(g, r, branch);
        end(g);
        fill(g, highlight);
        polygon(g, r, [-0.16, -0.24, -0.43, -0.34, -0.49, -0.55,
            -0.64, -0.58, -0.44, -0.61, -0.36, -0.41]);
        polygon(g, r, [0.2, -0.19, 0.51, -0.32, 0.53, -0.56,
            0.65, -0.56, 0.55, -0.4, 0.53, -0.27]);
        polygon(g, r, [-0.2, 0.27, -0.43, 0.39, -0.59, 0.32,
            -0.54, 0.45, -0.42, 0.46, -0.2, 0.34]);
        end(g);
        var seam = [0.1, -1., 0.28, -0.54, 0.15, -0.25, 0.29, 0.0,
            0.15, 0.23, 0.43, 0.14, 0.2, 0.5, -0.04, 1., -0.24, 0.45,
            -0.14, 0.15, -0.31, -0.03, -0.16, -0.33, -0.39, -0.55,
            -0.1, -0.41, -0.06, -0.73];
        fill(g, outline);
        polygon(g, r + 1, seam);
        end(g);
        fill(g, body);
        polygon(g, r, seam);
        end(g);
        fill(g, highlight);
        polygon(g, r, [0.07, -0.8, 0.15, -0.51, -0.02, -0.13, 0.09, 0.12,
            -0.06, 0.45, -0.04, 0.79, -0.14, 0.44, -0.01, 0.13, -0.12, -0.13, 0.07, -0.53]);
        end(g);
        fill(g, outline);
        polygon(g, r, [0.15, -0.51, 0.0, -0.13, 0.12, 0.12, -0.02, 0.45,
            -0.04, 0.79, -0.06, 0.45, 0.04, 0.13, -0.07, -0.13, 0.1, -0.52]);
        end(g);
    }

    static function riftPortal(g:Dynamic, r:Float):Void {
        // A jagged pink tear with a dark interior, like the open world portal.
        var tear = [-0.92, 0.71, -0.35, 0.14, -0.32, -0.36, -0.04, -0.67,
            0.2, -1., 0.27, -0.45, 0.78, -0.87, 0.54, -0.24,
            0.84, -0.12, 0.43, 0.12, 0.54, 0.8, 0.12, 0.64, -0.3, 0.82];
        fill(g, 0x32132e);
        polygon(g, r + 1, tear);
        end(g);
        fill(g, 0xf52e9c);
        polygon(g, r, tear);
        end(g);
        fill(g, 0xffa5df);
        polygon(g, r * 0.82, tear);
        end(g);
        fill(g, 0x25132b);
        polygon(g, r * 0.66, tear);
        end(g);
        fill(g, 0xffb5e5);
        polygon(g, r, [-0.74, -0.4, -0.58, -0.54, -0.52, -0.27]);
        polygon(g, r, [0.7, 0.36, 0.94, 0.48, 0.73, 0.61]);
        end(g);
    }

    static function upcomingRift(g:Dynamic, r:Float):Void {
        // A filled magenta-purple energy ball, not an open portal. Curved
        // wisps, a subdued swirling core and four sparks match the reference.
        // This geometry is built only when a pooled icon changes appearance.
        for (i in 0...3) {
            var angle = -2.9 + i * Math.PI * 2 / 3;
            var wisp = riftRibbon(0.95, 0.72, 0.16, angle, 1.65);
            fill(g, 0x32103f);
            polygon(g, r + 1, wisp);
            end(g);
            fill(g, 0xcf169b);
            polygon(g, r, wisp);
            end(g);
            fill(g, 0x90209f);
            polygon(g, r, riftRibbon(0.9, 0.7, 0.07, angle + 0.14, 1.5));
            end(g);
        }
        fill(g, 0x32103f);
        circle(g, 0, 0, r * 0.67);
        end(g);
        fill(g, 0x9620ad);
        circle(g, 0, 0, r * 0.59);
        end(g);
        fill(g, 0xb52eb6);
        circle(g, 0, 0, r * 0.46);
        end(g);
        for (i in 0...3) {
            var angle = -2.3 + i * Math.PI * 2 / 3;
            fill(g, 0x702091);
            polygon(g, r, riftRibbon(0.59, 0.16, 0.13, angle, 1.8));
            end(g);
        }
        fill(g, 0xb663ca);
        polygon(g, r, riftRibbon(0.54, 0.39, 0.04, -1.7, 0.85));
        end(g);
        for (i in 0...4) {
            var angle = -2.05 + i * Math.PI / 2;
            var x = Math.cos(angle) * 0.96, y = Math.sin(angle) * 0.96;
            fill(g, 0x32103f);
            polygon(g, r, [x, y - 0.16, x + 0.12, y, x, y + 0.16, x - 0.12, y]);
            end(g);
            fill(g, 0xcf169b);
            polygon(g, r, [x, y - 0.1, x + 0.07, y, x, y + 0.1, x - 0.07, y]);
            end(g);
        }
    }

    static function riftRibbon(start:Float, finish:Float, width:Float, angle:Float, sweep:Float):Array<Float> {
        var vertices:Array<Float> = [];
        // Follow both edges of a curved, tapered ribbon without a hole.
        // Do not repeat the shared tip vertices when returning along the inner edge.
        for (side in [1, -1]) for (i in 0...(side == 1 ? 13 : 11)) {
            var t = (side == 1 ? i : 11 - i) / 12;
            var a = angle + sweep * t;
            var radius = start + (finish - start) * t + side * width * Math.sin(Math.PI * t);
            vertices.push(Math.cos(a) * radius);
            vertices.push(Math.sin(a) * radius);
        }
        return vertices;
    }

    static function targetDummy(g:Dynamic, r:Float):Void {
        // Flat sack head and padded torso on a wooden cross, with a red target.
        fill(g, 0x38291f);
        dummyShape(g, r + 1);
        end(g);
        fill(g, 0x96704b);
        dummyShape(g, r);
        end(g);
        fill(g, 0xd5ac76);
        circle(g, 0, -0.7 * r, 0.26 * r);
        polygon(g, r, [-0.52, -0.36, 0.52, -0.36, 0.57, 0.18, 0.38, 0.52,
            -0.38, 0.52, -0.57, 0.18]);
        for (side in [-1, 1])
            polygon(g, r, [0.61, -0.3, 0.83, -0.3, 0.83, 0.11, 0.61, 0.11], side);
        end(g);
        fill(g, 0xb82e34);
        circle(g, 0, 0.07 * r, 0.34 * r);
        end(g);
        fill(g, 0xe4bc87);
        circle(g, 0, 0.07 * r, 0.23 * r);
        end(g);
        fill(g, 0xb82e34);
        circle(g, 0, 0.07 * r, 0.12 * r);
        end(g);
    }

    static function dummyShape(g:Dynamic, r:Float):Void {
        circle(g, 0, -0.7 * r, 0.3 * r);
        polygon(g, r, [-1, -0.23, 1, -0.23, 1, 0.06, -1, 0.06]);
        polygon(g, r, [-0.16, -0.5, 0.16, -0.5, 0.16, 1, -0.16, 1]);
        polygon(g, r, [-0.57, -0.4, 0.57, -0.4, 0.62, 0.18, 0.42, 0.56,
            -0.42, 0.56, -0.62, 0.18]);
        for (side in [-1, 1])
            polygon(g, r, [0.58, -0.34, 0.87, -0.34, 0.87, 0.15, 0.58, 0.15], side);
    }

    static function secretOrb(g:Dynamic, r:Float):Void {
        // The in-world orb has a warm gold centre and broken lavender orbits.
        // Flat bands and solid colours keep that silhouette readable at 16 px.
        for (i in 0...3) {
            var angle = -2.9 + i * Math.PI * 2 / 3;
            fill(g, 0x35283e);
            arc(g, r + 0.7, 2.5, angle - 0.05, 1.52);
            end(g);
            fill(g, 0xc594ec);
            arc(g, r, 1.25, angle, 1.42);
            end(g);
            fill(g, 0x9b6fc6);
            arc(g, r * 0.77, 0.8, angle + 0.55, 0.92);
            end(g);
        }
        fill(g, 0x655132);
        circle(g, 0, 0, r * 0.57);
        end(g);
        fill(g, 0xf2be4f);
        circle(g, 0, 0, r * 0.49);
        polygon(g, r, [-0.13, -0.65, 0.13, -0.65, 0.1, -0.39, -0.1, -0.39]);
        for (side in [-1, 1])
            polygon(g, r, [0.39, -0.1, 0.66, -0.14, 0.66, 0.14, 0.39, 0.1], side);
        polygon(g, r, [-0.1, 0.39, 0.1, 0.39, 0.13, 0.65, -0.13, 0.65]);
        end(g);
        fill(g, 0xffe778);
        circle(g, 0, 0, r * 0.35);
        end(g);
        fill(g, 0xfff8c8);
        circle(g, -r * 0.06, -r * 0.06, r * 0.22);
        end(g);
    }

    public static function alertArrow(g:Dynamic, radius:Float, color:Int):Void {
        // A long shaft and triangular head distinguish alerts from player arrows.
        // Point along +X so the existing destination rotation still applies.
        fill(g, 0x201b1b);
        alertArrowShape(g, radius, 0.75);
        end(g);
        fill(g, color);
        alertArrowShape(g, radius, 0);
        end(g);
    }

    static function alertArrowShape(g:Dynamic, r:Float, padding:Float):Void {
        var tail = -0.9 * r - padding, shoulder = 0.4 * r;
        var shaft = 0.23 * r + padding;
        // Offset each triangle edge perpendicularly by the same padding as
        // the shaft. Adding padding to X/Y alone thins the two slanted edges.
        var slope = 0.45 / 0.6;
        var normalLength = Math.sqrt(1 + slope * slope);
        var tip = r + padding * normalLength / slope;
        var head = 0.45 * r + padding * (normalLength + slope);
        // Two convex fills avoid a concave junction and keep the outline intact
        // where the shaft meets the head. Padding stays inside the alert bounds.
        polygon(g, 1, [tail, -shaft, shoulder, -shaft, shoulder, shaft, tail, shaft]);
        polygon(g, 1, [tip, 0, shoulder - padding, head, shoulder - padding, -head]);
    }

    public static function partyPlayer(g:Dynamic, radius:Float):Void {
        // Trace only the arrow's outside contour, including its rear notch.
        // Draw the blue fill last so the outline preserves the ordinary arrow.
        // Start midway along an edge so the stroke joins at every corner,
        // especially the tip, rather than leaving two end caps there.
        var contour:Array<Float> = [0.1, 0.35, -0.8, 0.7, -0.45, 0, -0.8, -0.7, 1, 0];
        G.call("h2d.Graphics", "lineStyle", g, [3.0, 0x201b1b, 1.0]);
        polygon(g, radius, contour);
        G.call("h2d.Graphics", "lineStyle", g, [2.0, SPARKLING_COLOR, 1.0]);
        polygon(g, radius, contour);
        G.call("h2d.Graphics", "lineStyle", g, [0.0, 0, 0.0]);
        // The same two solid triangles as the ordinary blue player arrow.
        fill(g, 0x70d8ff);
        polygon(g, radius, [1, 0, -0.45, 0, -0.8, -0.7]);
        polygon(g, radius, [1, 0, -0.8, 0.7, -0.45, 0]);
        end(g);
    }

    public static function sparklingRing(g:Dynamic, radius:Float):Void {
        // Stroke the ring instead of filling disks: its centre stays transparent.
        // Retain thin dark edges for contrast, then reset stroke state for icons.
        G.call("h2d.Graphics", "lineStyle", g, [4.5, 0x201b1b, 1.0]);
        G.call("h2d.Graphics", "drawCircle", g, [0., 0., radius - 2.25, 32]);
        G.call("h2d.Graphics", "lineStyle", g, [2.5, SPARKLING_COLOR, 1.0]);
        G.call("h2d.Graphics", "drawCircle", g, [0., 0., radius - 2.25, 32]);
        G.call("h2d.Graphics", "lineStyle", g, [0., 0, 0.0]);
    }

    static function arc(g:Dynamic, radius:Float, width:Float, angle:Float, sweep:Float):Void {
        // Separate convex quads avoid a concave ring polygon's triangulation.
        var inner = radius - width;
        for (i in 0...10) {
            var a = angle + sweep * i / 10, b = angle + sweep * (i + 1) / 10;
            polygon(g, 1, [Math.cos(a) * radius, Math.sin(a) * radius, Math.cos(b) * radius, Math.sin(b) * radius,
                Math.cos(b) * inner, Math.sin(b) * inner, Math.cos(a) * inner, Math.sin(a) * inner]);
        }
    }

    static function soulstone(g:Dynamic, r:Float):Void {
        // A runic summoning ring around a faceted soulstone, distinct from portals.
        fill(g, 0x251c32);
        circle(g, 0, 0, r + 1);
        end(g);
        fill(g, 0xc5a0e6);
        circle(g, 0, 0, r);
        end(g);
        fill(g, 0x473458);
        circle(g, 0, 0, r * 0.73);
        end(g);
        fill(g, 0xeee0ff);
        polygon(g, r, [-0.12, -1, 0.12, -1, 0.12, -0.64, -0.12, -0.64]);
        for (side in [-1, 1])
            polygon(g, r, [0.64, -0.12, 1, -0.12, 1, 0.12, 0.64, 0.12], side);
        polygon(g, r, [-0.12, 0.64, 0.12, 0.64, 0.12, 1, -0.12, 1]);
        end(g);
        fill(g, 0x211829);
        polygon(g, r, [0, -0.67, 0.43, -0.12, 0.32, 0.43, 0, 0.65, -0.32, 0.43, -0.43, -0.12]);
        end(g);
        fill(g, 0xf28fc8);
        polygon(g, r, [0, -0.52, 0.3, -0.1, 0.22, 0.33, 0, 0.49, -0.22, 0.33, -0.3, -0.1]);
        end(g);
        fill(g, 0xa74596);
        polygon(g, r, [0, -0.52, 0.3, -0.1, 0.22, 0.33, 0, 0.49]);
        end(g);
        fill(g, 0xffdbf0);
        polygon(g, r, [0, -0.52, 0, 0.12, -0.3, -0.1]);
        end(g);
    }

    static function obelisk(g:Dynamic, r:Float):Void {
        fill(g, 0x282828);
        obeliskShape(g, r + 1);
        end(g);
        fill(g, 0x999999);
        obeliskShape(g, r);
        end(g);

        // The idol's gold spine and four round inlays below its split crown.
        fill(g, 0xd8aa50);
        polygon(g, r, [-0.16, -0.35, 0.16, -0.35, 0.16, 0.9, -0.16, 0.9]);
        for (side in [-1, 1]) {
            circle(g, side * 0.74 * r, -0.65 * r, 0.145 * r);
            circle(g, side * 0.42 * r, -0.54 * r, 0.145 * r);
        }
        end(g);
        // Keep the split crown's center entirely gold, like the spine below.
        fill(g, 0xe2b85f);
        polygon(g, r, [-0.065, -0.94, 0.065, -0.94, 0.1, -0.24, -0.1, -0.24]);
        end(g);
        // A broad stone foot gives the thicker column a substantial base.
        fill(g, 0x636363);
        polygon(g, r, [-0.62, 0.78, 0.62, 0.78, 0.62, 1, -0.62, 1]);
        end(g);

        // Broader hands and shoulders remain legible at the default icon size.
        fill(g, 0x555555);
        polygon(g, r, [-0.72, -0.14, 0.72, -0.14, 0.61, 0.21, -0.61, 0.21]);
        end(g);
        fill(g, 0xbfbfbf);
        polygon(g, r, [-0.68, -0.14, 0.68, -0.14, 0.61, 0.02, -0.61, 0.02]);
        end(g);
    }

    static function obeliskShape(g:Dynamic, r:Float):Void {
        polygon(g, r, [-0.58, -0.35, 0.58, -0.35, 0.62, 1, -0.62, 1]);
        // Separate convex pieces preserve the open split when triangulated.
        for (side in [-1, 1])
            polygon(g, r, [-1, -0.83, -0.24, -1, -0.19, -0.8,
                -0.25, -0.22, -0.84, -0.22, -1, -0.43], side);
    }

    static function dungeon(g:Dynamic, r:Float):Void {
        fill(g, 0x201b2e);
        doorway(g, r + 1);
        end(g);
        fill(g, 0xc2bdad);
        doorway(g, r);
        end(g);
        // An inset opening leaves a thick stone arch and two door posts.
        fill(g, 0x38315f);
        polygon(g, r, [-0.51, 0.78, -0.51, -0.31, -0.32, -0.6,
            0, -0.73, 0.32, -0.6, 0.51, -0.31, 0.51, 0.78]);
        end(g);
        fill(g, 0x8559df);
        polygon(g, r, [-0.37, 0.73, -0.42, -0.2, -0.24, -0.48,
            0.04, -0.59, 0.35, -0.25, 0.38, 0.73]);
        end(g);
        // A curved cyan ribbon reads as a portal at the default 16 px size.
        fill(g, 0x55dfff);
        polygon(g, r, [0.08, -0.5, 0.28, -0.25, 0.29, 0.16, 0.08, 0.08]);
        polygon(g, r, [0.29, 0.16, 0.12, 0.44, -0.05, 0.27, 0.08, 0.08]);
        polygon(g, r, [-0.05, 0.27, 0.12, 0.44, -0.14, 0.65, -0.31, 0.49]);
        end(g);
        fill(g, 0xe0fcff);
        circle(g, 0.12 * r, -0.13 * r, 0.09 * r);
        end(g);
        fill(g, 0x777b86);
        polygon(g, r, [-0.8, 0.79, 0.8, 0.79, 0.8, 0.97, -0.8, 0.97]);
        end(g);
    }

    static function doorway(g:Dynamic, r:Float):Void {
        polygon(g, r, [-0.8, 1, -0.8, -0.38, -0.5, -0.82, 0, -1,
            0.5, -0.82, 0.8, -0.38, 0.8, 1]);
    }

    static function fill(g:Dynamic, color:Int):Void
        G.call("h2d.Graphics", "beginFill", g, [color, 1.0]);

    static function end(g:Dynamic):Void
        G.call("h2d.Graphics", "endFill", g);

    static function circle(g:Dynamic, x:Float, y:Float, r:Float):Void
        G.call("h2d.Graphics", "drawCircle", g, [x, y, r, 16]);

    static function polygon(g:Dynamic, r:Float, vertices:Array<Float>, side:Int = 1):Void {
        var count = Std.int(vertices.length / 2);
        for (i in 0...count + 1) {
            // Reverse mirrored vertices to retain the same winding.
            var j = (side < 0 ? (count - i) % count : i % count) * 2;
            G.call("h2d.Graphics", i == 0 ? "moveTo" : "lineTo", g, [side * vertices[j] * r, vertices[j + 1] * r]);
        }
    }
}
