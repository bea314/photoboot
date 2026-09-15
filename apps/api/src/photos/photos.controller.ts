import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  StreamableFile,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { CreatePhotoDto } from './dto/create-photo.dto';
import { PhotoFileVariant, PhotosService } from './photos.service';

@Controller('photos')
export class PhotosController {
  constructor(private readonly photosService: PhotosService) {}

  @Get()
  list(@Query('eventId') eventId: string) {
    return this.photosService.list(eventId);
  }

  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: 20 * 1024 * 1024 },
    }),
  )
  async create(
    @Body() dto: CreatePhotoDto,
    @UploadedFile()
    file: { buffer: Buffer; mimetype: string; originalname: string },
  ) {
    const { photo, created } = await this.photosService.create({
      ...dto,
      file,
    });
    return { ...photo, created };
  }

  @Get(':id/file')
  async file(
    @Param('id') id: string,
    @Query('variant') variant?: string,
  ) {
    const kind: PhotoFileVariant =
      variant === 'original' ? 'original' : 'thumb';
    const { stream, filename } = await this.photosService.getFile(id, kind);
    return new StreamableFile(stream, {
      type: 'image/jpeg',
      disposition: `inline; filename="${filename}"`,
    });
  }

  @Get(':id')
  getOne(@Param('id') id: string) {
    return this.photosService.getOne(id);
  }

  @Delete(':id')
  @HttpCode(204)
  remove(@Param('id') id: string) {
    return this.photosService.remove(id);
  }
}
