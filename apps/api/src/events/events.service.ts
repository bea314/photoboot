import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateEventDto } from './dto/update-event.dto';

@Injectable()
export class EventsService {
  constructor(private readonly prisma: PrismaService) {}

  private publicBaseUrl() {
    return (process.env.PUBLIC_BASE_URL ?? 'http://localhost:3000').replace(
      /\/$/,
      '',
    );
  }

  private toResponse(event: {
    id: string;
    name: string;
    slug: string;
    publicToken: string | null;
    startsAt: Date | null;
    isActive: boolean;
    createdAt: Date;
  }) {
    const base = this.publicBaseUrl();
    const publicUrl = event.publicToken
      ? `${base}/e/${event.slug}?k=${event.publicToken}`
      : `${base}/e/${event.slug}`;

    return {
      id: event.id,
      name: event.name,
      slug: event.slug,
      publicToken: event.publicToken,
      startsAt: event.startsAt,
      isActive: event.isActive,
      createdAt: event.createdAt,
      publicUrl,
    };
  }

  async getCurrent() {
    const event = await this.prisma.event.findFirst({
      where: { isActive: true },
      orderBy: { createdAt: 'desc' },
    });
    if (!event) {
      throw new NotFoundException('No active event');
    }
    return this.toResponse(event);
  }

  async update(id: string, dto: UpdateEventDto) {
    const existing = await this.prisma.event.findUnique({ where: { id } });
    if (!existing) {
      throw new NotFoundException('Event not found');
    }

    if (dto.slug && dto.slug !== existing.slug) {
      const clash = await this.prisma.event.findUnique({
        where: { slug: dto.slug },
      });
      if (clash) {
        throw new ConflictException('Slug already in use');
      }
    }

    if (dto.isActive === true) {
      await this.prisma.event.updateMany({
        where: { isActive: true, NOT: { id } },
        data: { isActive: false },
      });
    }

    const event = await this.prisma.event.update({
      where: { id },
      data: {
        name: dto.name,
        slug: dto.slug,
        isActive: dto.isActive,
      },
    });

    return this.toResponse(event);
  }
}
