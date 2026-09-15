import { Module } from '@nestjs/common';
import { PrinterController } from './printer.controller';

@Module({
  controllers: [PrinterController],
})
export class PrinterModule {}
