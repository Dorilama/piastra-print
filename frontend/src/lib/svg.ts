// The single seam for SVG generation. The rest of the app treats this function
// as the source of truth for the produced markup. When the user's real
// zero-dependency drawing library is dropped in, only this body changes.
export function generateSvg(width: number, height: number): string {
  const w = Math.max(1, Math.round(width));
  const h = Math.max(1, Math.round(height));
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">` +
    `<rect x="0" y="0" width="${w}" height="${h}" fill="#111827"/></svg>`
  );
}
