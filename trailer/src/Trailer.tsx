import React from "react";
import {
  AbsoluteFill,
  Easing,
  Img,
  Sequence,
  interpolate,
  random,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Audio } from "@remotion/media";
import { loadFont as loadBebas } from "@remotion/google-fonts/BebasNeue";
import { loadFont as loadInter } from "@remotion/google-fonts/Inter";

const { fontFamily: bebas } = loadBebas();
const { fontFamily: inter } = loadInter("normal", {
  weights: ["400", "600"],
});

const ORANGE = "#ff8c1a";
const HOT = "#ffe8c7";
const GREEN = "#7ddf3a";

const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
const overshoot = Easing.bezier(0.34, 1.56, 0.64, 1);

// ---------- atmosphere ----------

const Embers: React.FC<{ count?: number; seed?: string }> = ({
  count = 32,
  seed = "embers",
}) => {
  const frame = useCurrentFrame();
  const { height, width } = useVideoConfig();
  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      {Array.from({ length: count }).map((_, i) => {
        const rx = random(`${seed}-x-${i}`);
        const ry = random(`${seed}-y-${i}`);
        const rs = random(`${seed}-s-${i}`);
        const speed = 0.6 + rs * 1.6;
        const y = ((ry * height + frame * speed) % (height + 40)) - 20;
        const x =
          rx * width + Math.sin((frame + i * 37) / (22 + rs * 18)) * 30;
        const size = 2 + rs * 4;
        const flicker =
          0.25 + 0.55 * Math.abs(Math.sin((frame + i * 13) / (9 + rs * 7)));
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: x,
              top: height - y,
              width: size,
              height: size,
              borderRadius: "50%",
              backgroundColor: ORANGE,
              boxShadow: `0 0 ${6 + rs * 8}px ${ORANGE}`,
              opacity: flicker,
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};

const Vignette: React.FC<{ strength?: number; color?: string }> = ({
  strength = 0.75,
  color = "10,3,0",
}) => (
  <AbsoluteFill
    style={{
      background: `radial-gradient(ellipse at center, rgba(0,0,0,0) 45%, rgba(${color},${strength}) 100%)`,
    }}
  />
);

const HeatHaze: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        opacity: 0.35,
        translate: `${Math.sin(frame / 40) * 40}px 0px`,
        background:
          "radial-gradient(ellipse 60% 40% at 30% 20%, rgba(255,140,26,0.35), transparent 70%), radial-gradient(ellipse 50% 35% at 75% 60%, rgba(255,90,10,0.25), transparent 70%)",
        mixBlendMode: "screen",
      }}
    />
  );
};

const Letterbox: React.FC = () => {
  const frame = useCurrentFrame();
  const h = interpolate(frame, [0, 45], [0, 84], {
    extrapolateRight: "clamp",
    easing: easeOut,
  });
  const bar: React.CSSProperties = {
    position: "absolute",
    left: 0,
    right: 0,
    height: h,
    backgroundColor: "#000",
    zIndex: 40,
  };
  return (
    <>
      <div style={{ ...bar, top: 0 }} />
      <div style={{ ...bar, bottom: 0 }} />
    </>
  );
};

const CutFlash: React.FC<{ color?: string; peak?: number }> = ({
  color = "#ffdcb0",
  peak = 0.85,
}) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        backgroundColor: color,
        opacity: interpolate(frame, [0, 7], [peak, 0], {
          extrapolateRight: "clamp",
        }),
        zIndex: 30,
      }}
    />
  );
};

// ---------- camera ----------

type KenBurnsProps = {
  src: string;
  from: number;
  to: number;
  duration: number;
  driftX?: [number, number];
  driftY?: [number, number];
  shake?: number;
  shakeGrow?: boolean;
  whipFrom?: number;
  darken?: number;
  punch?: boolean;
};

const KenBurns: React.FC<KenBurnsProps> = ({
  src,
  from,
  to,
  duration,
  driftX = [0, 0],
  driftY = [0, 0],
  shake = 0,
  shakeGrow = false,
  whipFrom = 0,
  darken = 0,
  punch = true,
}) => {
  const frame = useCurrentFrame();
  const amp = shakeGrow ? shake * Math.min(1, frame / 25) : shake;
  const sx =
    amp > 0 ? Math.sin(frame * 2.1) * amp + Math.sin(frame * 5.3) * amp * 0.5 : 0;
  const sy = amp > 0 ? Math.cos(frame * 2.7) * amp : 0;
  const whip =
    whipFrom !== 0
      ? interpolate(frame, [0, 6], [whipFrom, 0], {
          extrapolateRight: "clamp",
          easing: easeOut,
        })
      : 0;
  const punchScale = punch
    ? interpolate(frame, [0, 7], [1.05, 1], {
        extrapolateRight: "clamp",
        easing: easeOut,
      })
    : 1;
  return (
    <AbsoluteFill style={{ backgroundColor: "#0d0502", overflow: "hidden" }}>
      <Img
        src={staticFile(src)}
        style={{
          position: "absolute",
          left: "50%",
          top: "50%",
          width: "115%",
          translate: `calc(-50% + ${
            interpolate(frame, [0, duration], driftX) + sx + whip
          }px) calc(-50% + ${interpolate(frame, [0, duration], driftY) + sy}px)`,
          scale: String(
            interpolate(frame, [0, duration], [from, to], { easing: easeOut }) *
              punchScale
          ),
          filter:
            whipFrom !== 0
              ? `blur(${interpolate(frame, [0, 6], [7, 0], {
                  extrapolateRight: "clamp",
                })}px)`
              : undefined,
        }}
      />
      {darken > 0 ? (
        <AbsoluteFill style={{ backgroundColor: `rgba(8,3,0,${darken})` }} />
      ) : null}
    </AbsoluteFill>
  );
};

// pulsing green mutation glow over the frog
const PulsingFrogGlow: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(ellipse 40% 35% at 50% 52%, rgba(125,223,58,0.22), transparent 70%)",
        mixBlendMode: "screen",
        opacity: 0.75 + 0.25 * Math.sin(frame / 5),
      }}
    />
  );
};

const BottomScrim: React.FC = () => (
  <AbsoluteFill
    style={{
      background:
        "linear-gradient(to top, rgba(5,2,0,0.85) 0%, rgba(5,2,0,0.4) 18%, transparent 40%)",
    }}
  />
);

// ---------- text ----------

const LowerLine: React.FC<{
  children: React.ReactNode;
  at: number;
  until?: number;
  color?: string;
  size?: number;
}> = ({ children, at, until, color = HOT, size = 92 }) => {
  const frame = useCurrentFrame();
  const out =
    until === undefined
      ? 1
      : interpolate(frame, [until, until + 8], [1, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });
  return (
    <AbsoluteFill
      style={{
        justifyContent: "flex-end",
        alignItems: "center",
        paddingBottom: 170,
        zIndex: 20,
      }}
    >
      <div
        style={{
          fontFamily: bebas,
          fontSize: size,
          color,
          letterSpacing: "0.08em",
          textAlign: "center",
          textShadow: "0 4px 50px rgba(0,0,0,0.9), 0 2px 12px rgba(0,0,0,0.8)",
          opacity:
            interpolate(frame, [at, at + 10], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: easeOut,
            }) * out,
          translate: `0px ${interpolate(frame, [at, at + 12], [40, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: easeOut,
          })}px`,
        }}
      >
        {children}
      </div>
    </AbsoluteFill>
  );
};

// staggered word reveal on black
const StaggerText: React.FC<{
  words: string[];
  duration: number;
  size?: number;
  color?: string;
  step?: number;
  start?: number;
}> = ({ words, duration, size = 118, color = "#ffb066", step = 11, start = 6 }) => {
  const frame = useCurrentFrame();
  const out = interpolate(frame, [duration - 12, duration - 2], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill
      style={{
        justifyContent: "center",
        alignItems: "center",
        flexDirection: "row",
        flexWrap: "wrap",
        alignContent: "center",
        gap: "0.45em",
        rowGap: "0.15em",
        fontSize: size,
        paddingLeft: 140,
        paddingRight: 140,
        textAlign: "center",
      }}
    >
      {words.map((w, i) => {
        const at = start + i * step;
        return (
          <span
            key={i}
            style={{
              fontFamily: bebas,
              color,
              letterSpacing: "0.14em",
              opacity:
                interpolate(frame, [at, at + 7], [0, 1], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                }) * out,
              scale: String(
                interpolate(frame, [at, at + 9], [1.25, 1], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                  easing: easeOut,
                })
              ),
              display: "inline-block",
            }}
          >
            {w}
          </span>
        );
      })}
    </AbsoluteFill>
  );
};

const MontageWord: React.FC<{
  word: string;
  color?: string;
}> = ({ word, color = HOT }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{ justifyContent: "center", alignItems: "center", zIndex: 20 }}
    >
      <div
        style={{
          fontFamily: bebas,
          fontSize: 220,
          color,
          letterSpacing: "0.06em",
          textShadow: "0 6px 60px rgba(0,0,0,0.95)",
          scale: String(
            interpolate(frame, [0, 7], [1.4, 1], {
              extrapolateRight: "clamp",
              easing: easeOut,
            })
          ),
          opacity: interpolate(frame, [0, 3], [0, 1], {
            extrapolateRight: "clamp",
          }),
        }}
      >
        {word}
      </div>
    </AbsoluteFill>
  );
};

// ---------- scenes ----------

const ColdOpen: React.FC<{ duration: number }> = ({ duration }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0402" }}>
      {/* faint sun glow breathing behind the words */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse 45% 38% at 50% 50%, rgba(255,110,10,0.22), transparent 70%)",
          opacity: 0.6 + 0.4 * Math.sin(frame / 9),
        }}
      />
      <Embers count={18} seed="cold" />
      <AbsoluteFill
        style={{
          scale: String(
            interpolate(frame, [0, duration], [1, 1.06], {
              easing: Easing.linear,
            })
          ),
        }}
      >
        <StaggerText
          words={["THE", "SUN", "TOOK", "EVERYTHING."]}
          duration={duration}
        />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

const WormScene: React.FC<{ duration: number }> = ({ duration }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill>
      <KenBurns
        src="worm.png"
        from={1.12}
        to={1.42}
        duration={duration}
        driftY={[30, -35]}
        shake={5}
        shakeGrow
      />
      {/* hot red danger pulse at the edges */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at center, rgba(0,0,0,0) 55%, rgba(140,20,0,0.55) 100%)",
          opacity: 0.5 + 0.5 * Math.abs(Math.sin(frame / 6)),
        }}
      />
      <BottomScrim />
      <LowerLine at={8} size={100}>
        AND THE WASTELAND HUNTS.
      </LowerLine>
      <Vignette />
      <CutFlash color="#ffb98a" peak={0.95} />
    </AbsoluteFill>
  );
};

const HeatwaveScene: React.FC<{ duration: number }> = ({ duration }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill>
      <KenBurns
        src="heatwave.png"
        from={1.1}
        to={1.38}
        duration={duration}
        driftY={[-160, 140]}
        shake={4.5}
        shakeGrow
      />
      {/* searing white-orange pulse rolling in */}
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(to bottom, rgba(255,150,40,0.35), transparent 55%)",
          opacity: 0.5 + 0.5 * Math.abs(Math.sin(frame / 5)),
          mixBlendMode: "screen",
        }}
      />
      <BottomScrim />
      <LowerLine at={8} size={96}>
        AND THE HEAT COMES IN WAVES.
      </LowerLine>
      <Vignette />
      <CutFlash color="#ffd9a8" peak={0.95} />
    </AbsoluteFill>
  );
};

const CreditCard: React.FC<{
  kicker: string;
  big: string;
  sub: string;
  duration: number;
  seed: string;
  times?: [number, number, number];
}> = ({ kicker, big, sub, duration, seed, times = [4, 12, 26] }) => {
  const fr = useCurrentFrame();
  const out = interpolate(fr, [duration - 12, duration - 2], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const reveal = (at: number) =>
    interpolate(fr, [at, at + 12], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: easeOut,
    }) * out;
  return (
    <AbsoluteFill style={{ backgroundColor: "#050201" }}>
      <Embers count={12} seed={seed} />
      <AbsoluteFill
        style={{
          justifyContent: "center",
          alignItems: "center",
          flexDirection: "column",
          gap: 30,
          scale: String(
            interpolate(fr, [0, duration], [1, 1.045], { easing: Easing.linear })
          ),
        }}
      >
        <div
          style={{
            fontFamily: inter,
            fontWeight: 600,
            fontSize: 34,
            letterSpacing: "0.55em",
            color: "rgba(255,232,199,0.55)",
            opacity: reveal(4),
          }}
        >
          {kicker}
        </div>
        <div
          style={{
            fontFamily: bebas,
            fontSize: 140,
            letterSpacing: "0.06em",
            textAlign: "center",
            backgroundImage:
              "linear-gradient(180deg, #fff6e8 0%, #ff8c1a 78%, #d94f00 100%)",
            backgroundClip: "text",
            WebkitBackgroundClip: "text",
            color: "transparent",
            opacity: reveal(12),
            scale: String(
              interpolate(fr, [12, 26], [1.1, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
                easing: easeOut,
              })
            ),
          }}
        >
          {big}
        </div>
        <div
          style={{
            fontFamily: inter,
            fontSize: 38,
            color: "rgba(255,232,199,0.6)",
            letterSpacing: "0.04em",
            opacity: reveal(26),
          }}
        >
          {sub}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// set to e.g. "qr.png" (in public/) once the itch.io QR exists — it replaces the CTA line
const QR_SRC: string | null = null;

const EditionPanel: React.FC<{
  name: string;
  price: React.ReactNode;
  bullets: string[];
  at: number;
  gold?: boolean;
}> = ({ name, price, bullets, at, gold = false }) => {
  const fr = useCurrentFrame();
  const accent = gold ? "rgba(255,200,80,0.8)" : "rgba(255,140,26,0.35)";
  return (
    <div
      style={{
        width: 600,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 14,
        padding: "40px 48px",
        borderRadius: 14,
        border: `2px solid ${accent}`,
        backgroundColor: "rgba(22,9,2,0.85)",
        boxShadow: gold
          ? `0 0 ${40 + 12 * Math.sin(fr / 8)}px rgba(255,180,60,0.25)`
          : "none",
        position: "relative",
        opacity: interpolate(fr, [at, at + 10], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: easeOut,
        }),
        translate: `0px ${interpolate(fr, [at, at + 12], [55, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: easeOut,
        })}px`,
      }}
    >
      {gold ? (
        <div
          style={{
            position: "absolute",
            top: -20,
            fontFamily: inter,
            fontWeight: 600,
            fontSize: 24,
            letterSpacing: "0.18em",
            color: "#1a0a00",
            backgroundColor: "#ffc850",
            padding: "6px 18px",
            borderRadius: 999,
          }}
        >
          BEST VALUE
        </div>
      ) : null}
      <div
        style={{
          fontFamily: bebas,
          fontSize: 54,
          letterSpacing: "0.1em",
          color: gold ? "#ffc850" : HOT,
        }}
      >
        {name}
      </div>
      <div
        style={{
          fontFamily: bebas,
          fontSize: 104,
          lineHeight: 1,
          color: gold ? "#ffc850" : HOT,
          scale: String(
            interpolate(fr, [at + 10, at + 18], [1.35, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: easeOut,
            })
          ),
          opacity: interpolate(fr, [at + 10, at + 14], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        {price}
      </div>
      <div
        style={{
          fontFamily: inter,
          fontSize: 29,
          lineHeight: 1.65,
          color: "rgba(255,232,199,0.75)",
          textAlign: "center",
        }}
      >
        {bullets.map((b) => (
          <div key={b}>{b}</div>
        ))}
      </div>
    </div>
  );
};

const PricingCard: React.FC<{ duration: number }> = ({ duration }) => {
  const frame = useCurrentFrame();
  const out = interpolate(frame, [duration - 14, duration - 4], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill style={{ backgroundColor: "#050201" }}>
      <Embers count={14} seed="pricing" />
      <AbsoluteFill
        style={{
          justifyContent: "center",
          alignItems: "center",
          flexDirection: "column",
          gap: 44,
          opacity: out,
        }}
      >
        <div
          style={{
            fontFamily: bebas,
            fontSize: 96,
            letterSpacing: "0.1em",
            color: HOT,
            scale: String(
              interpolate(frame, [4, 16], [1.3, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
                easing: easeOut,
              })
            ),
            opacity: interpolate(frame, [4, 10], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          PRE-ORDER NOW
        </div>
        <div style={{ display: "flex", flexDirection: "row", gap: 56 }}>
          <EditionPanel
            name="STANDARD EDITION"
            price="$149.99"
            bullets={["the game", "one (1) robot", "one (1) mutated frog"]}
            at={18}
          />
          <EditionPanel
            name="ULTIMATE EDITION"
            price="$189.99"
            bullets={[
              "everything in standard",
              "golden frog skin",
              "24-hour early access",
            ]}
            at={30}
            gold
          />
        </div>
        {QR_SRC ? (
          <Img
            src={staticFile(QR_SRC)}
            style={{
              width: 170,
              height: 170,
              borderRadius: 12,
              opacity: interpolate(frame, [56, 70], [0, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              }),
            }}
          />
        ) : (
          <div
            style={{
              fontFamily: inter,
              fontWeight: 600,
              fontSize: 36,
              color: "rgba(255,232,199,0.7)",
              letterSpacing: "0.06em",
              opacity: interpolate(frame, [56, 70], [0, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
                easing: easeOut,
              }),
            }}
          >
            coming this summer.
          </div>
        )}
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// final screen: QR + link, holds static until the video ends (no fade-out)
const FinalQR: React.FC = () => {
  const frame = useCurrentFrame();
  const reveal = (at: number) =>
    interpolate(frame, [at, at + 10], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: easeOut,
    });
  return (
    <AbsoluteFill style={{ backgroundColor: "#050201" }}>
      <Embers count={14} seed="finalqr" />
      <AbsoluteFill
        style={{
          justifyContent: "center",
          alignItems: "center",
          flexDirection: "column",
          gap: 36,
        }}
      >
        <div
          style={{
            fontFamily: bebas,
            fontSize: 84,
            letterSpacing: "0.1em",
            color: HOT,
            opacity: reveal(2),
          }}
        >
          DON&rsquo;T OPEN THIS URL
        </div>
        <div
          style={{
            backgroundColor: "#fff",
            borderRadius: 18,
            padding: 22,
            opacity: reveal(8),
          }}
        >
          <Img src={staticFile("qr.png")} style={{ width: 330, height: 330 }} />
        </div>
        <div
          style={{
            fontFamily: inter,
            fontWeight: 600,
            fontSize: 46,
            letterSpacing: "0.04em",
            color: ORANGE,
            opacity: reveal(14),
          }}
        >
          summer.mark.vin
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

const ProtectBeat: React.FC<{ duration: number }> = ({ duration }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ backgroundColor: "#050201" }}>
      <Embers count={20} seed="protect" />
      {/* heartbeat pulse closing in from the edges */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at center, rgba(0,0,0,0) 55%, rgba(150,30,0,0.4) 100%)",
          opacity: 0.4 + 0.6 * Math.pow(Math.abs(Math.sin(frame / 11)), 3),
        }}
      />
      <AbsoluteFill
        style={{
          justifyContent: "center",
          alignItems: "center",
          flexDirection: "column",
          gap: 18,
          scale: String(1 + 0.012 * Math.sin(frame / 7)),
        }}
      >
        <StaggerText
          words={["PROTECT", "THE", "LAST", "LIFE", "ON", "EARTH."]}
          duration={duration}
          size={132}
          color={HOT}
          step={6}
          start={4}
        />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

const TitleCard: React.FC<{ duration: number }> = ({ duration }) => {
  const frame = useCurrentFrame();
  const fadeOut = interpolate(frame, [duration - 50, duration - 15], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  // camera impact when the title lands
  const imp = frame >= 23 ? 15 * Math.exp(-(frame - 23) / 6) : 0;
  const titleGradient =
    "linear-gradient(180deg, #fff6e8 0%, #ff8c1a 78%, #d94f00 100%)";
  const shineX = interpolate(frame, [30, 75], [-130, 130], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const titleText: React.CSSProperties = {
    fontFamily: bebas,
    fontSize: 300,
    lineHeight: 1,
    letterSpacing: "0.04em",
    textAlign: "center",
  };
  return (
    <AbsoluteFill>
      <AbsoluteFill
        style={{
          opacity: fadeOut,
          translate: `${Math.sin(frame * 3.9) * imp}px ${
            Math.cos(frame * 3.1) * imp
          }px`,
        }}
      >
        <KenBurns
          src="robot-frog.png"
          from={1.06}
          to={1.16}
          duration={duration}
          driftY={[0, -30]}
          darken={0.5}
          punch={false}
        />
        <HeatHaze />
        <Embers count={26} seed="title" />
        <AbsoluteFill
          style={{
            justifyContent: "center",
            alignItems: "center",
            flexDirection: "column",
            gap: 28,
            zIndex: 20,
          }}
        >
          <div
            style={{
              position: "relative",
              scale: String(
                interpolate(frame, [8, 24], [2.4, 1], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                  easing: overshoot,
                })
              ),
              opacity: interpolate(frame, [8, 14], [0, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              }),
              filter: "drop-shadow(0 8px 60px rgba(0,0,0,0.9))",
            }}
          >
            <div
              style={{
                ...titleText,
                backgroundImage: titleGradient,
                backgroundClip: "text",
                WebkitBackgroundClip: "text",
                color: "transparent",
              }}
            >
              BEAT THE HEAT
            </div>
            {/* shine sweep */}
            <div
              style={{
                ...titleText,
                position: "absolute",
                inset: 0,
                backgroundImage:
                  "linear-gradient(105deg, transparent 42%, rgba(255,255,255,0.9) 50%, transparent 58%)",
                backgroundSize: "250% 100%",
                backgroundPosition: `${shineX}% 0%`,
                backgroundClip: "text",
                WebkitBackgroundClip: "text",
                color: "transparent",
              }}
            >
              BEAT THE HEAT
            </div>
          </div>
          <div
            style={{
              fontFamily: bebas,
              fontSize: 74,
              color: GREEN,
              letterSpacing: "0.14em",
              textShadow: "0 4px 40px rgba(0,0,0,0.9)",
              opacity: interpolate(frame, [34, 48], [0, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
                easing: easeOut,
              }),
              translate: `0px ${interpolate(frame, [34, 50], [26, 0], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
                easing: easeOut,
              })}px`,
            }}
          >
            THE FATE OF THE WORLD DEPENDS ON YOU
          </div>
          <div
            style={{
              fontFamily: inter,
              fontWeight: 600,
              fontSize: 40,
              color: "rgba(255,232,199,0.85)",
              letterSpacing: "0.06em",
              opacity: interpolate(frame, [54, 70], [0, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
                easing: easeOut,
              }),
            }}
          >
            Run far. Stay in the shade. Don&rsquo;t dry out.
          </div>
        </AbsoluteFill>
        <Vignette strength={0.85} />
      </AbsoluteFill>
      <CutFlash color="#fff3df" />
    </AbsoluteFill>
  );
};

// ---------- main ----------

export const Trailer: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: "#000" }}>
      <Audio
        src={staticFile("music.mp3")}
        volume={(f) =>
          interpolate(f, [0, 20], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })
        }
      />

      {/* 0–2.4s: cold open — the hook comes first */}
      <Sequence durationInFrames={72}>
        <ColdOpen duration={72} />
      </Sequence>

      {/* 2.4–5.4s: the burned world */}
      <Sequence from={72} durationInFrames={90}>
        <KenBurns
          src="sun-wasteland.png"
          from={1.02}
          to={1.2}
          duration={90}
          driftY={[20, -35]}
        />
        <HeatHaze />
        <Embers count={24} seed="sun" />
        <BottomScrim />
        <LowerLine at={8} size={86}>
          NOW IT CIRCLES THE SKY LIKE A VULTURE.
        </LowerLine>
        <Vignette />
        <CutFlash />
      </Sequence>

      {/* 5.4–7.3s: quick studio card — a breath of black */}
      <Sequence from={162} durationInFrames={58}>
        <CreditCard
          kicker="BUILT WITH"
          big="SUMMER ENGINE"
          sub="where the summer never ends."
          duration={58}
          seed="credit-b"
          times={[2, 10, 22]}
        />
      </Sequence>

      {/* 7.3–10.1s: the robot */}
      <Sequence from={220} durationInFrames={82}>
        <KenBurns
          src="robot-run.png"
          from={1.1}
          to={1.32}
          duration={82}
          driftX={[25, -40]}
          shake={2.5}
        />
        <HeatHaze />
        <BottomScrim />
        <LowerLine at={6}>BUT ONE MACHINE STILL STANDS.</LowerLine>
        <Vignette />
        <CutFlash />
      </Sequence>

      {/* 10.1–12s: second card, right after its hero */}
      <Sequence from={302} durationInFrames={58}>
        <CreditCard
          kicker="FEATURING"
          big="A REAL ARDUINO CONTROLLER"
          sub="the robot runs on one too."
          duration={58}
          seed="credit-a"
          times={[2, 10, 22]}
        />
      </Sequence>

      {/* 12–15.7s: the frog (emotional core — the one slow moment) */}
      <Sequence from={360} durationInFrames={112}>
        <KenBurns
          src="frog-hands.png"
          from={1.04}
          to={1.2}
          duration={112}
          driftY={[15, -15]}
        />
        <PulsingFrogGlow />
        <BottomScrim />
        <LowerLine at={6} until={50} color={GREEN} size={86}>
          CARRYING THE LAST FROG ON EARTH.
        </LowerLine>
        <LowerLine at={58} color={GREEN} size={80}>
          MUTATED &mdash; THE ONE THING THE SUN CAN&rsquo;T KILL.
        </LowerLine>
        <Vignette />
        <CutFlash />
      </Sequence>

      {/* 15.7–17.9s: the worm */}
      <Sequence from={472} durationInFrames={64}>
        <WormScene duration={64} />
      </Sequence>

      {/* 17.9–20s: the heatwave */}
      <Sequence from={536} durationInFrames={64}>
        <HeatwaveScene duration={64} />
      </Sequence>

      {/* 20–22.8s: montage — the mission, one fresh shot per word */}
      <Sequence from={600} durationInFrames={24}>
        <KenBurns
          src="sprint.png"
          from={1.35}
          to={1.2}
          duration={24}
          driftX={[-35, 35]}
          whipFrom={140}
          shake={3}
        />
        <MontageWord word="RUN." />
        <Vignette />
      </Sequence>
      <Sequence from={624} durationInFrames={24}>
        <KenBurns
          src="shade.png"
          from={1.15}
          to={1.32}
          duration={24}
          driftX={[20, -20]}
          whipFrom={-140}
          shake={2}
        />
        <MontageWord word="CHASE THE SHADE." />
        <Vignette />
      </Sequence>
      <Sequence from={648} durationInFrames={36}>
        <KenBurns
          src="shield.png"
          from={1.2}
          to={1.4}
          duration={36}
          driftY={[15, -20]}
          whipFrom={140}
          shake={3}
        />
        <MontageWord word="KEEP IT ALIVE." color={GREEN} />
        <Vignette />
      </Sequence>

      {/* 22.8–25.2s: the mission statement on black */}
      <Sequence from={684} durationInFrames={72}>
        <ProtectBeat duration={72} />
      </Sequence>

      {/* 25.2–30.2s: title card, riding the music's final hit and ring-out */}
      <Sequence from={756} durationInFrames={149}>
        <TitleCard duration={149} />
      </Sequence>

      {/* 30.2–34.8s: the editions gag, in the quiet after the music */}
      <Sequence from={905} durationInFrames={140}>
        <PricingCard duration={140} />
      </Sequence>

      {/* 34.8s–end: QR + link, held static for ~5s */}
      <Sequence from={1045}>
        <FinalQR />
      </Sequence>

      <Letterbox />
    </AbsoluteFill>
  );
};
