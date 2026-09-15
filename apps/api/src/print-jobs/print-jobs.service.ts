import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrintJobStatus, PrintJobType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { getPrinterProfile } from '../printer/printer-profiles';
import { CreatePrintJobDto } from './dto/create-print-job.dto';
import { UpdatePrintJobDto } from './dto/update-print-job.dto';

@Injectable()
export class PrintJobsService {
  constructor(private readonly prisma: PrismaService) {}

  private toResponse(job: {
    id: string;
    eventId: string;
    printerProfile: string;
    type: PrintJobType;
    copies: number;
    status: PrintJobStatus;
    error: string | null;
    createdAt: Date;
    items: { id: string; photoId: string | null }[];
  }) {
    return {
      id: job.id,
      eventId: job.eventId,
      printerProfile: job.printerProfile,
      type: job.type,
      copies: job.copies,
      status: job.status,
      error: job.error,
      createdAt: job.createdAt,
      photoIds: job.items
        .map((i) => i.photoId)
        .filter((id): id is string => id != null),
      items: job.items,
    };
  }

  async create(dto: CreatePrintJobDto) {
    const type = dto.type ?? PrintJobType.photo;
    const copies = dto.copies ?? 1;
    const status = dto.localStatus ?? PrintJobStatus.queued;
    const photoIds = dto.photoIds ?? [];

    if (!getPrinterProfile(dto.printerProfile)) {
      throw new BadRequestException(
        `Unknown printerProfile: ${dto.printerProfile}`,
      );
    }

    const event = await this.prisma.event.findUnique({
      where: { id: dto.eventId },
    });
    if (!event) {
      throw new NotFoundException('Event not found');
    }

    if (type === PrintJobType.photo) {
      if (photoIds.length === 0) {
        throw new BadRequestException(
          'photoIds is required for type=photo jobs',
        );
      }
      const photos = await this.prisma.photo.findMany({
        where: {
          id: { in: photoIds },
          eventId: dto.eventId,
          deletedAt: null,
        },
      });
      if (photos.length !== photoIds.length) {
        throw new BadRequestException(
          'One or more photoIds are invalid for this event',
        );
      }
    } else if (photoIds.length > 0) {
      // Test jobs may optionally reference photos; validate if present.
      const photos = await this.prisma.photo.findMany({
        where: {
          id: { in: photoIds },
          eventId: dto.eventId,
          deletedAt: null,
        },
      });
      if (photos.length !== photoIds.length) {
        throw new BadRequestException(
          'One or more photoIds are invalid for this event',
        );
      }
    }

    const job = await this.prisma.printJob.create({
      data: {
        eventId: dto.eventId,
        printerProfile: dto.printerProfile,
        type,
        copies,
        status,
        error: dto.error ?? null,
        items: {
          create:
            photoIds.length > 0
              ? photoIds.map((photoId) => ({ photoId }))
              : type === PrintJobType.test
                ? [{ photoId: null }]
                : [],
        },
      },
      include: { items: true },
    });

    if (status === PrintJobStatus.printed && photoIds.length > 0) {
      await this.markPhotosPrinted(photoIds);
    }

    return this.toResponse(job);
  }

  async update(id: string, dto: UpdatePrintJobDto) {
    const existing = await this.prisma.printJob.findUnique({
      where: { id },
      include: { items: true },
    });
    if (!existing) {
      throw new NotFoundException('Print job not found');
    }

    if (
      dto.localStatus !== PrintJobStatus.printed &&
      dto.localStatus !== PrintJobStatus.failed &&
      dto.localStatus !== PrintJobStatus.queued
    ) {
      throw new BadRequestException('Invalid localStatus');
    }

    const job = await this.prisma.printJob.update({
      where: { id },
      data: {
        status: dto.localStatus,
        error:
          dto.localStatus === PrintJobStatus.failed
            ? (dto.error ?? existing.error)
            : dto.localStatus === PrintJobStatus.printed
              ? null
              : (dto.error ?? existing.error),
      },
      include: { items: true },
    });

    if (dto.localStatus === PrintJobStatus.printed) {
      const photoIds = job.items
        .map((i) => i.photoId)
        .filter((pid): pid is string => pid != null);
      if (photoIds.length > 0) {
        await this.markPhotosPrinted(photoIds);
      }
    }

    return this.toResponse(job);
  }

  /** Sets printedAt on first successful print only. */
  private async markPhotosPrinted(photoIds: string[]) {
    await this.prisma.photo.updateMany({
      where: {
        id: { in: photoIds },
        printedAt: null,
      },
      data: { printedAt: new Date() },
    });
  }
}
