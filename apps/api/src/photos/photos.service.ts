import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { createReadStream, promises as fs } from 'fs';
import { join } from 'path';
import sharp from 'sharp';
import { PrismaService } from '../prisma/prisma.service';

const THUMB_WIDTH = 480;

export type PhotoFileVariant = 'original' | 'thumb';

@Injectable()
export class PhotosService {
  constructor(private readonly prisma: PrismaService) {}

  private filesRoot() {
    return process.env.FILES_ROOT ?? './data';
  }

  private publicBaseUrl() {
    return (process.env.PUBLIC_BASE_URL ?? 'http://localhost:3000').replace(
      /\/$/,
      '',
    );
  }

  private eventDir(eventId: string) {
    return join(this.filesRoot(), 'events', eventId);
  }

  private originalPath(eventId: string, photoId: string) {
    return join(this.eventDir(eventId), 'originals', `${photoId}.jpg`);
  }

  private thumbPath(eventId: string, photoId: string) {
    return join(this.eventDir(eventId), 'thumbs', `${photoId}.jpg`);
  }

  private toResponse(photo: {
    id: string;
    eventId: string;
    clientPhotoId: string;
    takenAt: Date;
    printedAt: Date | null;
    deletedAt: Date | null;
    createdAt: Date;
  }) {
    const base = this.publicBaseUrl();
    return {
      id: photo.id,
      eventId: photo.eventId,
      clientPhotoId: photo.clientPhotoId,
      takenAt: photo.takenAt,
      printedAt: photo.printedAt,
      createdAt: photo.createdAt,
      thumbUrl: `${base}/v1/photos/${photo.id}/file?variant=thumb`,
      originalUrl: `${base}/v1/photos/${photo.id}/file?variant=original`,
    };
  }

  async create(dto: {
    eventId: string;
    clientPhotoId: string;
    takenAt: string;
    file: { buffer: Buffer; mimetype: string; originalname: string };
  }) {
    const event = await this.prisma.event.findUnique({
      where: { id: dto.eventId },
    });
    if (!event) {
      throw new NotFoundException('Event not found');
    }

    const existing = await this.prisma.photo.findUnique({
      where: {
        eventId_clientPhotoId: {
          eventId: dto.eventId,
          clientPhotoId: dto.clientPhotoId,
        },
      },
    });

    if (existing && !existing.deletedAt) {
      return { photo: this.toResponse(existing), created: false };
    }

    if (!dto.file?.buffer?.length) {
      throw new BadRequestException('file is required');
    }

    const mime = dto.file.mimetype ?? '';
    const allowedMime =
      /^image\/(jpeg|jpg|png|webp)$/i.test(mime) ||
      mime === 'application/octet-stream' ||
      mime === '';
    if (!allowedMime) {
      throw new BadRequestException('Only JPEG, PNG or WebP images are allowed');
    }

    let original: Buffer;
    let thumb: Buffer;
    try {
      const pipeline = sharp(dto.file.buffer).rotate();
      await pipeline.clone().metadata();
      original = await pipeline.clone().jpeg({ quality: 88 }).toBuffer();
      thumb = await pipeline
        .clone()
        .resize({ width: THUMB_WIDTH, withoutEnlargement: true })
        .jpeg({ quality: 72 })
        .toBuffer();
    } catch {
      throw new BadRequestException('Invalid image file');
    }

    const takenAt = new Date(dto.takenAt);
    if (Number.isNaN(takenAt.getTime())) {
      throw new BadRequestException('Invalid takenAt');
    }

    const photo = existing
      ? await this.prisma.photo.update({
          where: { id: existing.id },
          data: {
            takenAt,
            deletedAt: null,
          },
        })
      : await this.prisma.photo.create({
          data: {
            eventId: dto.eventId,
            clientPhotoId: dto.clientPhotoId,
            originalPath: '',
            thumbPath: '',
            takenAt,
          },
        });

    const originalDisk = this.originalPath(dto.eventId, photo.id);
    const thumbDisk = this.thumbPath(dto.eventId, photo.id);

    await fs.mkdir(join(this.eventDir(dto.eventId), 'originals'), {
      recursive: true,
    });
    await fs.mkdir(join(this.eventDir(dto.eventId), 'thumbs'), {
      recursive: true,
    });
    await fs.writeFile(originalDisk, original);
    await fs.writeFile(thumbDisk, thumb);

    const saved = await this.prisma.photo.update({
      where: { id: photo.id },
      data: {
        originalPath: originalDisk,
        thumbPath: thumbDisk,
      },
    });

    return { photo: this.toResponse(saved), created: !existing };
  }

  async list(eventId: string) {
    if (!eventId) {
      throw new BadRequestException('eventId is required');
    }

    const photos = await this.prisma.photo.findMany({
      where: { eventId, deletedAt: null },
      orderBy: { takenAt: 'desc' },
    });

    return photos.map((photo) => this.toResponse(photo));
  }

  async getOne(id: string) {
    const photo = await this.prisma.photo.findUnique({ where: { id } });
    if (!photo || photo.deletedAt) {
      throw new NotFoundException('Photo not found');
    }
    return this.toResponse(photo);
  }

  async remove(id: string) {
    const photo = await this.prisma.photo.findUnique({ where: { id } });
    if (!photo || photo.deletedAt) {
      throw new NotFoundException('Photo not found');
    }

    await this.prisma.photo.update({
      where: { id },
      data: { deletedAt: new Date() },
    });

    await Promise.allSettled([
      fs.unlink(photo.originalPath),
      fs.unlink(photo.thumbPath),
    ]);
  }

  async getFile(id: string, variant: PhotoFileVariant) {
    const photo = await this.prisma.photo.findUnique({ where: { id } });
    if (!photo || photo.deletedAt) {
      throw new NotFoundException('Photo not found');
    }

    const path = variant === 'original' ? photo.originalPath : photo.thumbPath;
    try {
      await fs.access(path);
    } catch {
      throw new NotFoundException('Photo file missing');
    }

    return {
      stream: createReadStream(path),
      filename: `${id}-${variant}.jpg`,
    };
  }
}
