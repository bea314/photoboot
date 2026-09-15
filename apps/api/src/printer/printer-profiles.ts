export type PrinterProfileId = 'thermal_80' | 'epson_l8050_4x6';

export interface PrinterProfile {
  id: PrinterProfileId;
  label: string;
  kind: 'thermal' | 'epson';
  /** Target frame width / height for center-crop preview. */
  aspectRatio: number;
  /** Human-readable frame size. */
  frameLabel: string;
  /** Thermal paper width in mm (thermal only). */
  paperWidthMm?: number;
  /** Target print DPI hint (Epson). */
  targetDpi?: number;
  /** Printable width in dots for ESC/POS raster (thermal). */
  thermalDotsWidth?: number;
}

export const PRINTER_PROFILES: PrinterProfile[] = [
  {
    id: 'thermal_80',
    label: 'Térmica 80 mm',
    kind: 'thermal',
    // Slightly taller ticket frame vs 10×15 — crops differently.
    aspectRatio: 80 / 100,
    frameLabel: '80 × 100 mm (ticket)',
    paperWidthMm: 80,
    thermalDotsWidth: 576,
  },
  {
    id: 'epson_l8050_4x6',
    label: 'Epson L8050 10×15',
    kind: 'epson',
    aspectRatio: 10 / 15,
    frameLabel: '10 × 15 cm (4×6")',
    targetDpi: 300,
  },
];

export function getPrinterProfile(id: string): PrinterProfile | undefined {
  return PRINTER_PROFILES.find((p) => p.id === id);
}
