import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('admin1234', 10);

  const admin = await prisma.user.upsert({
    where: { email: 'admin@fotoboot.local' },
    update: { passwordHash },
    create: {
      email: 'admin@fotoboot.local',
      passwordHash,
    },
  });

  const event = await prisma.event.upsert({
    where: { slug: 'demo' },
    update: {
      name: 'Evento demo',
      isActive: true,
    },
    create: {
      name: 'Evento demo',
      slug: 'demo',
      isActive: true,
      startsAt: new Date(),
    },
  });

  console.log('Seed OK');
  console.log(`  admin: ${admin.email} / admin1234`);
  console.log(`  event: ${event.slug} (id=${event.id})`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
