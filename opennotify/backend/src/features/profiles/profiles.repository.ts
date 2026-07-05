import { Injectable } from '@nestjs/common';
import { MonitoredProfile } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';

@Injectable()
export class ProfilesRepository {
  constructor(private readonly prisma: PrismaService) {}

  findAllByUser(userId: string, search?: string): Promise<MonitoredProfile[]> {
    return this.prisma.monitoredProfile.findMany({
      where: {
        userId,
        ...(search && { username: { contains: search, mode: 'insensitive' } }),
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  findByIdForUser(id: string, userId: string): Promise<MonitoredProfile | null> {
    return this.prisma.monitoredProfile.findFirst({ where: { id, userId } });
  }

  countByUser(userId: string): Promise<number> {
    return this.prisma.monitoredProfile.count({ where: { userId } });
  }

  create(userId: string, username: string): Promise<MonitoredProfile> {
    return this.prisma.monitoredProfile.create({ data: { userId, username } });
  }

  setMonitoring(id: string, enabled: boolean): Promise<MonitoredProfile> {
    return this.prisma.monitoredProfile.update({
      where: { id },
      data: { monitoringEnabled: enabled },
    });
  }

  delete(id: string): Promise<MonitoredProfile> {
    return this.prisma.monitoredProfile.delete({ where: { id } });
  }

  history(profileId: string) {
    return this.prisma.statusChange.findMany({
      where: { profileId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }
}
