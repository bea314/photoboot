import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';

describe('Auth + Events + PrintJobs (e2e)', () => {
  let app: INestApplication<App>;
  let accessToken: string;
  let eventId: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: true,
      }),
    );
    await app.init();

    const login = await request(app.getHttpServer())
      .post('/v1/auth/login')
      .send({ email: 'admin@fotoboot.local', password: 'admin1234' })
      .expect(201);

    accessToken = login.body.accessToken as string;

    const event = await request(app.getHttpServer())
      .get('/v1/events/current')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    eventId = event.body.id as string;
  });

  afterAll(async () => {
    await app.close();
  });

  it('/health (GET)', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect({ ok: true });
  });

  it('rejects protected routes without token', async () => {
    await request(app.getHttpServer()).get('/v1/events/current').expect(401);
    await request(app.getHttpServer()).post('/v1/print-jobs').expect(401);
    await request(app.getHttpServer()).get('/v1/printer/profiles').expect(401);
  });

  it('lists printer profiles', async () => {
    const res = await request(app.getHttpServer())
      .get('/v1/printer/profiles')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    expect(res.body.defaultProfileId).toBe('thermal_80');
    expect(res.body.profiles.map((p: { id: string }) => p.id)).toEqual(
      expect.arrayContaining(['thermal_80', 'epson_l8050_4x6']),
    );
    const thermal = res.body.profiles.find(
      (p: { id: string }) => p.id === 'thermal_80',
    );
    const epson = res.body.profiles.find(
      (p: { id: string }) => p.id === 'epson_l8050_4x6',
    );
    expect(thermal.aspectRatio).not.toBeCloseTo(epson.aspectRatio);
  });

  it('creates a test print job without photoIds', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/print-jobs')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        eventId,
        printerProfile: 'thermal_80',
        type: 'test',
        copies: 1,
        localStatus: 'printed',
      })
      .expect(201);

    expect(res.body.id).toBeTruthy();
    expect(res.body.type).toBe('test');
    expect(res.body.status).toBe('printed');
    expect(res.body.photoIds).toEqual([]);
  });

  it('rejects photo jobs without photoIds', async () => {
    await request(app.getHttpServer())
      .post('/v1/print-jobs')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        eventId,
        printerProfile: 'thermal_80',
        type: 'photo',
        localStatus: 'queued',
      })
      .expect(400);
  });

  it('patches a queued test job to failed', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/print-jobs')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        eventId,
        printerProfile: 'thermal_80',
        type: 'test',
        localStatus: 'queued',
      })
      .expect(201);

    const updated = await request(app.getHttpServer())
      .patch(`/v1/print-jobs/${created.body.id}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ localStatus: 'failed', error: 'timeout' })
      .expect(200);

    expect(updated.body.status).toBe('failed');
    expect(updated.body.error).toBe('timeout');
  });
});
