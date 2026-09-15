import { IsEnum, IsOptional, IsString } from 'class-validator';
import { PrintJobStatus } from '@prisma/client';

export class UpdatePrintJobDto {
  @IsEnum(PrintJobStatus)
  localStatus!: PrintJobStatus;

  @IsOptional()
  @IsString()
  error?: string;
}
