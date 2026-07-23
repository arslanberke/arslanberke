import { PrismaClient, Plan, ProfileStatus, Role } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const password = await bcrypt.hash('Password123!', 10);

  const admin = await prisma.user.upsert({
    where: { email: 'admin@opennotify.app' },
    update: {},
    create: {
      email: 'admin@opennotify.app',
      name: 'Admin',
      passwordHash: password,
      role: Role.ADMIN,
      emailVerifiedAt: new Date(),
      subscription: { create: { plan: Plan.BUSINESS } },
    },
  });

  const demo = await prisma.user.upsert({
    where: { email: 'demo@opennotify.app' },
    update: {},
    create: {
      email: 'demo@opennotify.app',
      name: 'Demo User',
      passwordHash: password,
      emailVerifiedAt: new Date(),
      subscription: { create: { plan: Plan.FREE } },
    },
  });

  const usernames = ['natgeo', 'nasa', 'openai'];
  for (const username of usernames) {
    const profile = await prisma.monitoredProfile.upsert({
      where: { userId_username: { userId: demo.id, username } },
      update: {},
      create: {
        userId: demo.id,
        username,
        currentStatus: ProfileStatus.PUBLIC,
        lastCheckedAt: new Date(),
        lastChangedAt: new Date(Date.now() - 86400000),
      },
    });
    await prisma.statusChange.createMany({
      data: [
        {
          profileId: profile.id,
          oldStatus: ProfileStatus.UNKNOWN,
          newStatus: ProfileStatus.PUBLIC,
          createdAt: new Date(Date.now() - 86400000 * 3),
        },
        {
          profileId: profile.id,
          oldStatus: ProfileStatus.PUBLIC,
          newStatus: ProfileStatus.PRIVATE,
          createdAt: new Date(Date.now() - 86400000 * 2),
        },
        {
          profileId: profile.id,
          oldStatus: ProfileStatus.PRIVATE,
          newStatus: ProfileStatus.PUBLIC,
          createdAt: new Date(Date.now() - 86400000),
        },
      ],
    });
  }

  await prisma.notification.createMany({
    data: [
      {
        userId: demo.id,
        channel: 'IN_APP',
        title: 'Profile status changed',
        body: '@natgeo became public.',
      },
      {
        userId: demo.id,
        channel: 'IN_APP',
        title: 'Profile status changed',
        body: '@nasa became private.',
      },
    ],
  });

  console.log('Seeded:', { admin: admin.email, demo: demo.email });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
