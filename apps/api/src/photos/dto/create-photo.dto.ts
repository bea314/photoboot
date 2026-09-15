import { IsDateString, IsString, Length } from 'class-validator';

export class CreatePhotoDto {
  @IsString()
  @Length(8, 80)
  eventId: string;

  @IsString()
  @Length(8, 80)
  clientPhotoId: string;

  @IsDateString()
  takenAt: string;
}
