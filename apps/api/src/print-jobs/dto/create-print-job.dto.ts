import {
  ArrayUnique,
  IsArray,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
  MinLength,
} from 'class-validator';
import { PrintJobStatus, PrintJobType } from '@prisma/client';

export class CreatePrintJobDto {
  @IsString()
  @MinLength(1)
  eventId!: string;

  @IsString()
  @MinLength(1)
  printerProfile!: string;

  @IsOptional()
  @IsEnum(PrintJobType)
  type?: PrintJobType;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(50)
  copies?: number;

  /** Required when type is photo (default). Optional for type=test. */
  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  photoIds?: string[];

  @IsOptional()
  @IsEnum(PrintJobStatus)
  localStatus?: PrintJobStatus;

  @IsOptional()
  @IsString()
  error?: string;
}
