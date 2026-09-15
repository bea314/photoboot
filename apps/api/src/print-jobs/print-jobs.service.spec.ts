import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PrintJobStatus, PrintJobType } from '@prisma/client';
import { PrintJobsService } from './print-jobs.service';

describe('PrintJobsService', () => {
  const prisma = {
    event: { findUnique: jest.fn() },
    photo: { findMany: jest.fn(), updateMany: jest.fn() },
    printJob: { create: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
  };

  const service = new PrintJobsService(prisma as never);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('creates a photo job and marks printedAt when localStatus=printed', async () => {
    prisma.event.findUnique.mockResolvedValue({ id: 'evt1' });
    prisma.photo.findMany.mockResolvedValue([{ id: 'ph1' }, { id: 'ph2' }]);
    prisma.printJob.create.mockResolvedValue({
      id: 'job1',
      eventId: 'evt1',
      printerProfile: 'thermal_80',
      type: PrintJobType.photo,
      copies: 1,
      status: PrintJobStatus.printed,
      error: null,
      createdAt: new Date('2026-01-01'),
      items: [
        { id: 'i1', photoId: 'ph1' },
        { id: 'i2', photoId: 'ph2' },
      ],
    });
    prisma.photo.updateMany.mockResolvedValue({ count: 2 });

    const result = await service.create({
      eventId: 'evt1',
      printerProfile: 'thermal_80',
      photoIds: ['ph1', 'ph2'],
      localStatus: PrintJobStatus.printed,
    });

    expect(result.id).toBe('job1');
    expect(result.photoIds).toEqual(['ph1', 'ph2']);
    expect(prisma.photo.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['ph1', 'ph2'] }, printedAt: null },
      data: { printedAt: expect.any(Date) },
    });
  });

  it('allows test jobs without photoIds', async () => {
    prisma.event.findUnique.mockResolvedValue({ id: 'evt1' });
    prisma.printJob.create.mockResolvedValue({
      id: 'job-test',
      eventId: 'evt1',
      printerProfile: 'thermal_80',
      type: PrintJobType.test,
      copies: 1,
      status: PrintJobStatus.queued,
      error: null,
      createdAt: new Date('2026-01-01'),
      items: [{ id: 'i1', photoId: null }],
    });

    const result = await service.create({
      eventId: 'evt1',
      printerProfile: 'thermal_80',
      type: PrintJobType.test,
      localStatus: PrintJobStatus.queued,
    });

    expect(result.type).toBe('test');
    expect(result.photoIds).toEqual([]);
    expect(prisma.photo.findMany).not.toHaveBeenCalled();
    expect(prisma.photo.updateMany).not.toHaveBeenCalled();
  });

  it('rejects unknown printer profiles', async () => {
    await expect(
      service.create({
        eventId: 'evt1',
        printerProfile: 'nope',
        photoIds: ['ph1'],
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects photo jobs without photoIds', async () => {
    prisma.event.findUnique.mockResolvedValue({ id: 'evt1' });
    await expect(
      service.create({
        eventId: 'evt1',
        printerProfile: 'thermal_80',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('patches status to printed and sets printedAt', async () => {
    prisma.printJob.findUnique.mockResolvedValue({
      id: 'job1',
      eventId: 'evt1',
      printerProfile: 'thermal_80',
      type: PrintJobType.photo,
      copies: 1,
      status: PrintJobStatus.queued,
      error: null,
      createdAt: new Date('2026-01-01'),
      items: [{ id: 'i1', photoId: 'ph1' }],
    });
    prisma.printJob.update.mockResolvedValue({
      id: 'job1',
      eventId: 'evt1',
      printerProfile: 'thermal_80',
      type: PrintJobType.photo,
      copies: 1,
      status: PrintJobStatus.printed,
      error: null,
      createdAt: new Date('2026-01-01'),
      items: [{ id: 'i1', photoId: 'ph1' }],
    });
    prisma.photo.updateMany.mockResolvedValue({ count: 1 });

    const result = await service.update('job1', {
      localStatus: PrintJobStatus.printed,
    });

    expect(result.status).toBe('printed');
    expect(prisma.photo.updateMany).toHaveBeenCalled();
  });

  it('throws when updating missing job', async () => {
    prisma.printJob.findUnique.mockResolvedValue(null);
    await expect(
      service.update('missing', { localStatus: PrintJobStatus.failed }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
