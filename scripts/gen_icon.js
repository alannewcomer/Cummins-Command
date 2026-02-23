#!/usr/bin/env node
/**
 * Generates the Cummins Command app icon (1024×1024 PNG).
 * Uses only Node.js built-ins — no npm packages required.
 * Design: speedometer gauge on dark background.
 *   - #07070F background
 *   - #FF6B00 (Cummins orange) thick gauge arc, 300° span
 *   - White needle at ~11 o'clock (high-performance reading)
 *   - Orange hub cap + white center
 */

'use strict';
const zlib = require('zlib');
const fs   = require('fs');

const W = 1024, H = 1024;
const img = Buffer.alloc(W * H * 3); // RGB

// ── Palette ──────────────────────────────────────────────────────────────────
const BG   = [0x07, 0x07, 0x0F]; // Near-black
const OG   = [0xFF, 0x6B, 0x00]; // Cummins orange
const OG2  = [0xFF, 0x90, 0x30]; // Orange highlight
const WH   = [0xFF, 0xFF, 0xFF]; // White
const FACE = [0x0D, 0x0D, 0x1A]; // Gauge face (slightly lighter than BG)

// Fill background
for (let i = 0; i < img.length; i += 3) {
  img[i] = BG[0]; img[i+1] = BG[1]; img[i+2] = BG[2];
}

const CX = 512, CY = 512; // Icon center

// ── Primitives ────────────────────────────────────────────────────────────────

function setPixel(x, y, c) {
  x = Math.round(x);
  y = Math.round(y);
  if (x < 0 || x >= W || y < 0 || y >= H) return;
  const i = (y * W + x) * 3;
  img[i] = c[0]; img[i+1] = c[1]; img[i+2] = c[2];
}

function setPixelBlend(x, y, c, a) {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || x >= W || y < 0 || y >= H) return;
  const i = (y * W + x) * 3;
  img[i]   = img[i]   * (1-a) + c[0] * a | 0;
  img[i+1] = img[i+1] * (1-a) + c[1] * a | 0;
  img[i+2] = img[i+2] * (1-a) + c[2] * a | 0;
}

function fillDisc(pcx, pcy, r, c) {
  const r2 = r * r;
  for (let y = Math.floor(pcy - r); y <= Math.ceil(pcy + r); y++) {
    for (let x = Math.floor(pcx - r); x <= Math.ceil(pcx + r); x++) {
      const d2 = (x-pcx)**2 + (y-pcy)**2;
      if (d2 <= r2) {
        setPixel(x, y, c);
      } else if (d2 <= (r+1.2)**2) {
        // Soft edge AA
        setPixelBlend(x, y, c, 1 - (Math.sqrt(d2) - r) / 1.2);
      }
    }
  }
}

// Angle in degrees: 0=top, 90=right, 180=bottom, 270=left (CW from top)
function pixelAngleDeg(x, y) {
  let a = Math.atan2(x - CX, -(y - CY)) * 180 / Math.PI;
  return a < 0 ? a + 360 : a;
}

// Fill annular arc sector. arcStart→arcEnd going CW from top.
// gap is from arcEnd to arcStart (the short way when start > end).
function fillArc(r1, r2, arcStart, arcEnd, c) {
  for (let y = Math.floor(CY - r2 - 2); y <= Math.ceil(CY + r2 + 2); y++) {
    for (let x = Math.floor(CX - r2 - 2); x <= Math.ceil(CX + r2 + 2); x++) {
      const dx = x - CX, dy = y - CY;
      const d = Math.sqrt(dx*dx + dy*dy);
      if (d < r1 || d > r2) continue;
      const a = pixelAngleDeg(x, y);
      const inArc = arcStart > arcEnd
        ? (a >= arcStart || a <= arcEnd)   // wraps through 0°
        : (a >= arcStart && a <= arcEnd);
      if (inArc) setPixel(x, y, c);
    }
  }
}

// Draw line with round caps
function drawLine(x1, y1, x2, y2, r, c) {
  const dx = x2-x1, dy = y2-y1;
  const len = Math.sqrt(dx*dx + dy*dy);
  const steps = Math.ceil(len * 2);
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    fillDisc(x1 + t*dx, y1 + t*dy, r, c);
  }
}

// Convert angle (CW from top) to (dx, dy) unit vector in screen coords
function vec(deg) {
  const r = deg * Math.PI / 180;
  return [Math.sin(r), -Math.cos(r)];
}

// ── Icon Design ───────────────────────────────────────────────────────────────

// 1. Gauge face: large dark disc
fillDisc(CX, CY, 455, FACE);

// 2. Gauge arc: 300° span, gap at bottom (150°→210° is the gap)
//    Arc goes from 210° (7 o'clock) → clockwise through 0° (top) → 150° (5 o'clock)
const R1 = 370, R2 = 450; // inner/outer radius
fillArc(R1, R2, 210, 150, OG);

// Round the arc endpoints with caps
const RMID = (R1 + R2) / 2;
const RCAP = (R2 - R1) / 2;
const [sdx, sdy] = vec(210); // start cap (7 o'clock)
const [edx, edy] = vec(150); // end cap (5 o'clock)
fillDisc(CX + sdx * RMID, CY + sdy * RMID, RCAP, OG);
fillDisc(CX + edx * RMID, CY + edy * RMID, RCAP, OG);

// 3. Tick marks — major at every 50° within the arc
//    Arc goes: 210 → 260 → 310 → 360/0 → 50 → 100 → 150
const TICK_ANGLES = [210, 260, 310, 0, 50, 100, 150];
for (const deg of TICK_ANGLES) {
  const [tx, ty] = vec(deg);
  // Major tick: just outside the arc
  drawLine(
    CX + tx * (R2 + 8),  CY + ty * (R2 + 8),
    CX + tx * (R2 + 36), CY + ty * (R2 + 36),
    7, OG
  );
  // Inner tick: inside the arc
  drawLine(
    CX + tx * (R1 - 8),  CY + ty * (R1 - 8),
    CX + tx * (R1 - 28), CY + ty * (R1 - 28),
    5, OG
  );
}

// Minor ticks between majors (every 25°)
const MINOR_TICK_ANGLES = [235, 285, 335, 25, 75, 125];
for (const deg of MINOR_TICK_ANGLES) {
  const [tx, ty] = vec(deg);
  drawLine(
    CX + tx * (R2 + 8),  CY + ty * (R2 + 8),
    CX + tx * (R2 + 20), CY + ty * (R2 + 20),
    4, OG2
  );
}

// 4. Needle — pointing to 330° (upper-left, ~11 o'clock = "high" reading)
const NEEDLE_DEG = 330;
const [nx, ny] = vec(NEEDLE_DEG);
const [bx, by] = vec(NEEDLE_DEG + 180); // opposite direction
const TIP_R   = 305;
const BACK_R  = 65;
drawLine(
  CX + bx * BACK_R, CY + by * BACK_R,
  CX + nx * TIP_R,  CY + ny * TIP_R,
  11, WH
);
// Needle tip glow
fillDisc(CX + nx * TIP_R, CY + ny * TIP_R, 16, WH);

// 5. Center hub: orange disc + white screw
fillDisc(CX, CY, 54, OG);
fillDisc(CX, CY, 32, WH);
fillDisc(CX, CY, 10, FACE); // dark center dot

// ── PNG Encoding ─────────────────────────────────────────────────────────────

const crcTable = new Uint32Array(256);
for (let i = 0; i < 256; i++) {
  let c = i;
  for (let j = 0; j < 8; j++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
  crcTable[i] = c;
}
function crc32(buf) {
  let c = 0xFFFFFFFF;
  for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}
function pngChunk(type, data) {
  const tb = Buffer.from(type, 'ascii');
  const lb = Buffer.alloc(4);
  const cb = Buffer.alloc(4);
  lb.writeUInt32BE(data.length, 0);
  cb.writeUInt32BE(crc32(Buffer.concat([tb, data])), 0);
  return Buffer.concat([lb, tb, data, cb]);
}

const stride  = W * 3;
const rawRows = Buffer.alloc(H * (stride + 1));
for (let y = 0; y < H; y++) {
  rawRows[y * (stride + 1)] = 0; // filter: None
  img.copy(rawRows, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
}

const compressed = zlib.deflateSync(rawRows, { level: 6 });

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(W, 0);
ihdr.writeUInt32BE(H, 4);
ihdr[8]  = 8; // 8-bit depth
ihdr[9]  = 2; // RGB color type
ihdr[10] = 0; // deflate compression
ihdr[11] = 0; // adaptive filter
ihdr[12] = 0; // no interlace

const outPath = process.argv[2] || 'icon.png';
fs.writeFileSync(outPath, Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
  pngChunk('IHDR', ihdr),
  pngChunk('IDAT', compressed),
  pngChunk('IEND', Buffer.alloc(0)),
]));
console.log(`✓ ${outPath} (${fs.statSync(outPath).size.toLocaleString()} bytes)`);
