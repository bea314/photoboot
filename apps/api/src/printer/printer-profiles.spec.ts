import { PRINTER_PROFILES, getPrinterProfile } from './printer-profiles';

describe('printer profiles', () => {
  it('exposes thermal_80 and epson_l8050_4x6 with distinct crops', () => {
    const thermal = getPrinterProfile('thermal_80');
    const epson = getPrinterProfile('epson_l8050_4x6');
    expect(thermal).toBeDefined();
    expect(epson).toBeDefined();
    expect(thermal!.aspectRatio).not.toBeCloseTo(epson!.aspectRatio);
    expect(PRINTER_PROFILES).toHaveLength(2);
  });
});
