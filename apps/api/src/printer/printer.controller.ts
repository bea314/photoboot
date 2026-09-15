import { Controller, Get } from '@nestjs/common';
import { PRINTER_PROFILES } from './printer-profiles';

@Controller('printer')
export class PrinterController {
  @Get('profiles')
  listProfiles() {
    return {
      profiles: PRINTER_PROFILES,
      defaultProfileId: 'thermal_80',
    };
  }
}
